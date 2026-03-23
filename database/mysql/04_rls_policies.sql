-- ============================================================================
-- 04_rls_policies.sql
-- School Clinic Management System — Row-Level Security Simulation (MySQL)
-- ============================================================================
-- Run AFTER 03_encryption.sql:
--   mysql -u root -p school_clinic < 04_rls_policies.sql
-- ============================================================================
-- MySQL does NOT have native Row-Level Security (RLS) like PostgreSQL.
--
-- Instead, we simulate RLS using:
--   1. Session variables (@app_current_user_id, @app_current_role)
--   2. Secure views with WHERE clauses that filter rows per role
--   3. Stored procedures for INSERT/UPDATE that validate ownership
--   4. Table-level grants that prevent direct table access
--
-- The application MUST set these session variables per-request:
--   SET @app_current_user_id = <user_id>;
--   SET @app_current_role = '<role_name>';
--
-- IMPORTANT: In MySQL, the security boundary is enforced by:
--   - Revoking direct SELECT on base tables from restricted roles
--   - Granting SELECT only on filtered views
--   - Using SQL SECURITY DEFINER on views/procedures
-- ============================================================================

USE school_clinic;

-- ============================================================================
-- HELPER FUNCTIONS: Get current session context
-- ============================================================================

DELIMITER //

CREATE FUNCTION current_app_user_id()
RETURNS INT
NOT DETERMINISTIC
NO SQL
SQL SECURITY DEFINER
COMMENT 'Returns the current application user_id from @app_current_user_id session variable.'
BEGIN
    RETURN @app_current_user_id;
END //

CREATE FUNCTION current_app_role()
RETURNS VARCHAR(20)
NOT DETERMINISTIC
NO SQL
SQL SECURITY DEFINER
COMMENT 'Returns the current application role from @app_current_role session variable.'
BEGIN
    RETURN @app_current_role;
END //

CREATE FUNCTION current_student_id()
RETURNS INT
READS SQL DATA
SQL SECURITY DEFINER
COMMENT 'Returns the student_id for the current session user, or NULL if not a student.'
BEGIN
    DECLARE sid INT DEFAULT NULL;
    SELECT student_id INTO sid
    FROM students
    WHERE user_id = @app_current_user_id
    LIMIT 1;
    RETURN sid;
END //

-- ============================================================================
-- SECURE PROCEDURES: Enforce row-level write access
-- ============================================================================
-- These procedures validate that the caller is authorized to modify data.

-- Insert consultation (only nurses / admin can create; must be the attendee)
CREATE PROCEDURE secure_create_consultation(
    IN p_student_id      INT,
    IN p_chief_complaint TEXT,
    IN p_diagnosis       TEXT,
    IN p_treatment_notes TEXT,
    IN p_vitals_bp       VARCHAR(10),
    IN p_vitals_temp     DECIMAL(4,1),
    IN p_vitals_pulse    INT,
    IN p_vitals_weight   DECIMAL(5,1),
    OUT p_consultation_id INT
)
SQL SECURITY DEFINER
COMMENT 'Creates a consultation with role and ownership validation.'
BEGIN
    DECLARE v_role VARCHAR(20);
    SET v_role = @app_current_role;

    IF v_role NOT IN ('admin', 'nurse') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Access denied: only admin and nurse roles can create consultations.';
    END IF;

    IF @app_current_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Session user not set. Run: SET @app_current_user_id = <id>;';
    END IF;

    SET SESSION block_encryption_mode = 'aes-256-cbc';

    INSERT INTO consultations (
        student_id, attended_by, chief_complaint,
        diagnosis, treatment_notes,
        vitals_bp, vitals_temp, vitals_pulse, vitals_weight
    ) VALUES (
        p_student_id,
        @app_current_user_id,
        p_chief_complaint,
        encrypt_data(p_diagnosis),
        encrypt_data(p_treatment_notes),
        p_vitals_bp, p_vitals_temp, p_vitals_pulse, p_vitals_weight
    );

    SET p_consultation_id = LAST_INSERT_ID();
END //

-- Update consultation (only the attendee can update, or admin)
CREATE PROCEDURE secure_update_consultation(
    IN p_consultation_id INT,
    IN p_diagnosis       TEXT,
    IN p_treatment_notes TEXT,
    IN p_status          VARCHAR(20)
)
SQL SECURITY DEFINER
COMMENT 'Updates a consultation with ownership validation.'
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_attended_by INT;

    SET v_role = @app_current_role;

    SELECT attended_by INTO v_attended_by
    FROM consultations
    WHERE consultation_id = p_consultation_id;

    IF v_role = 'admin' OR
       (v_role IN ('nurse', 'doctor') AND v_attended_by = @app_current_user_id) THEN

        SET SESSION block_encryption_mode = 'aes-256-cbc';

        UPDATE consultations SET
            diagnosis       = IF(p_diagnosis IS NOT NULL, encrypt_data(p_diagnosis), diagnosis),
            treatment_notes = IF(p_treatment_notes IS NOT NULL, encrypt_data(p_treatment_notes), treatment_notes),
            status          = IFNULL(p_status, status)
        WHERE consultation_id = p_consultation_id;
    ELSE
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Access denied: you can only update consultations you attended.';
    END IF;
END //

-- Insert prescription (only doctors / admin)
CREATE PROCEDURE secure_create_prescription(
    IN p_consultation_id      INT,
    IN p_prescription_details TEXT,
    IN p_notes                TEXT,
    OUT p_prescription_id     INT
)
SQL SECURITY DEFINER
COMMENT 'Creates a prescription with role validation.'
BEGIN
    DECLARE v_role VARCHAR(20);
    SET v_role = @app_current_role;

    IF v_role NOT IN ('admin', 'doctor') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Access denied: only admin and doctor roles can create prescriptions.';
    END IF;

    SET SESSION block_encryption_mode = 'aes-256-cbc';

    INSERT INTO prescriptions (
        consultation_id, prescribed_by,
        prescription_details, notes
    ) VALUES (
        p_consultation_id,
        @app_current_user_id,
        encrypt_data(p_prescription_details),
        encrypt_data(p_notes)
    );

    SET p_prescription_id = LAST_INSERT_ID();
END //

-- Request a health clearance (faculty / admin)
CREATE PROCEDURE secure_request_clearance(
    IN p_student_id INT,
    IN p_purpose    VARCHAR(100),
    OUT p_clearance_id INT
)
SQL SECURITY DEFINER
COMMENT 'Faculty requests a health clearance for a student.'
BEGIN
    DECLARE v_role VARCHAR(20);
    SET v_role = @app_current_role;

    IF v_role NOT IN ('admin', 'faculty') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Access denied: only admin and faculty roles can request clearances.';
    END IF;

    INSERT INTO health_clearances (student_id, purpose, requested_by)
    VALUES (p_student_id, p_purpose, @app_current_user_id);

    SET p_clearance_id = LAST_INSERT_ID();
END //

-- Update clearance status (doctor / nurse / admin)
CREATE PROCEDURE secure_update_clearance(
    IN p_clearance_id INT,
    IN p_status       VARCHAR(20),
    IN p_remarks      TEXT,
    IN p_valid_until  DATE
)
SQL SECURITY DEFINER
COMMENT 'Doctor or nurse updates a clearance status.'
BEGIN
    DECLARE v_role VARCHAR(20);
    SET v_role = @app_current_role;

    IF v_role NOT IN ('admin', 'doctor', 'nurse') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Access denied: only clinical staff can update clearance status.';
    END IF;

    UPDATE health_clearances SET
        status      = p_status,
        issued_by   = @app_current_user_id,
        remarks     = p_remarks,
        valid_until = p_valid_until
    WHERE clearance_id = p_clearance_id;
END //

DELIMITER ;

-- ============================================================================
-- NOTE ON MYSQL RLS SIMULATION
-- ============================================================================
-- In the PostgreSQL version, RLS policies transparently filter SELECT queries
-- at the engine level. MySQL cannot do this natively.
--
-- The MySQL approach enforces access control through:
--   1. Views (05_views.sql) — each role gets filtered, column-masked views
--   2. Procedures (above) — write operations validate role + ownership
--   3. Grants (06_grants.sql) — base table access revoked from restricted users
--
-- The application API layer MUST:
--   a) SET @app_current_user_id and @app_current_role on every connection
--   b) Use views for SELECT and procedures for INSERT/UPDATE
--   c) NEVER expose direct table access to end users
-- ============================================================================
