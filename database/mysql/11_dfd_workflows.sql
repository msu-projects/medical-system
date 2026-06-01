-- ============================================================================
-- 11_dfd_workflows.sql
-- School Clinic Management System - DFD Level 1 Workflow Views & Procedures
-- ============================================================================
-- Run AFTER 10_auth_helpers.sql:
--   mysql -u root -p school_clinic < 11_dfd_workflows.sql
-- ============================================================================
-- These helpers map the Level 1 DFD processes to database-facing workflows.
-- Password checking remains in the application layer. Medical text still uses
-- encrypt_data/decrypt_data and requires @app_encryption_key to be set.
-- ============================================================================

USE school_clinic;

-- ============================================================================
-- Workflow Views
-- ============================================================================

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_account_details AS
SELECT
    u.user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    CONCAT(u.first_name, ' ', u.last_name) AS full_name,
    u.role,
    u.is_active,
    u.last_login,
    u.created_at AS account_created_at,
    u.updated_at AS account_updated_at,
    s.student_number,
    s.year_of_enrollment,
    s.date_of_birth,
    s.sex,
    s.contact_number,
    s.emergency_contact_name,
    s.emergency_contact_number,
    s.year_level,
    s.section,
    s.blood_type,
    s.allergies,
    q.qr_token,
    q.is_active AS qr_active,
    q.generated_at AS qr_generated_at
FROM users u
LEFT JOIN students s ON s.user_id = u.user_id
LEFT JOIN qr_codes q ON q.student_number = s.student_number;

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_qr_checkin_context AS
SELECT
    q.qr_token,
    q.is_active AS qr_active,
    s.student_number,
    s.user_id AS student_user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS student_name,
    s.date_of_birth,
    s.sex,
    s.contact_number,
    s.emergency_contact_name,
    s.emergency_contact_number,
    s.year_level,
    s.section,
    s.blood_type,
    s.allergies
FROM qr_codes q
JOIN students s ON s.student_number = q.student_number
JOIN users u ON u.user_id = s.user_id
WHERE q.is_active = TRUE
  AND u.is_active = TRUE;

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_consultation_context AS
SELECT
    c.consultation_id,
    c.student_number,
    CONCAT(su.first_name, ' ', su.last_name) AS student_name,
    s.year_level,
    s.section,
    c.attended_by,
    CONCAT(au.first_name, ' ', au.last_name) AS attended_by_name,
    c.check_in_time,
    c.chief_complaint,
    decrypt_data(c.diagnosis) AS diagnosis,
    decrypt_data(c.treatment_notes) AS treatment_notes,
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status,
    c.updated_at
FROM consultations c
JOIN students s ON s.student_number = c.student_number
JOIN users su ON su.user_id = s.user_id
JOIN users au ON au.user_id = c.attended_by;

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_prescription_context AS
SELECT
    p.prescription_id,
    p.consultation_id,
    c.student_number,
    CONCAT(su.first_name, ' ', su.last_name) AS student_name,
    p.prescribed_by,
    CONCAT(du.first_name, ' ', du.last_name) AS prescribed_by_name,
    decrypt_data(p.prescription_details) AS prescription_details,
    decrypt_data(p.notes) AS notes,
    p.issued_at
FROM prescriptions p
JOIN consultations c ON c.consultation_id = p.consultation_id
JOIN students s ON s.student_number = c.student_number
JOIN users su ON su.user_id = s.user_id
JOIN users du ON du.user_id = p.prescribed_by;

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_dispense_context AS
SELECT
    cm.id AS dispense_id,
    cm.consultation_id,
    c.student_number,
    m.medicine_id,
    m.name AS medicine_name,
    m.unit,
    cm.quantity_given,
    m.available_quantity,
    cm.dispensed_by,
    CONCAT(u.first_name, ' ', u.last_name) AS dispensed_by_name,
    cm.dispensed_at
FROM consultation_medicines cm
JOIN consultations c ON c.consultation_id = cm.consultation_id
JOIN medicines m ON m.medicine_id = cm.medicine_id
LEFT JOIN users u ON u.user_id = cm.dispensed_by;

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_clearance_context AS
SELECT
    hc.clearance_id,
    hc.student_number,
    CONCAT(su.first_name, ' ', su.last_name) AS student_name,
    s.year_level,
    s.section,
    hc.purpose,
    hc.remarks,
    hc.status,
    hc.valid_until,
    hc.requested_by,
    CONCAT(fu.first_name, ' ', fu.last_name) AS requested_by_name,
    hc.issued_by,
    CONCAT(iu.first_name, ' ', iu.last_name) AS issued_by_name,
    hc.created_at,
    hc.updated_at
FROM health_clearances hc
JOIN students s ON s.student_number = hc.student_number
JOIN users su ON su.user_id = s.user_id
LEFT JOIN users fu ON fu.user_id = hc.requested_by
LEFT JOIN users iu ON iu.user_id = hc.issued_by;

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_active_sessions AS
SELECT
    s.session_id,
    s.user_id,
    u.username,
    CONCAT(u.first_name, ' ', u.last_name) AS full_name,
    s.role,
    s.issued_at,
    s.expires_at,
    s.last_seen_at,
    s.ip_address,
    s.user_agent
FROM user_session s
JOIN users u ON u.user_id = s.user_id
WHERE s.revoked_at IS NULL
  AND s.expires_at > CURRENT_TIMESTAMP
  AND u.is_active = TRUE;

DELIMITER //

-- ============================================================================
-- 1.0 Manage Accounts
-- ============================================================================

DROP PROCEDURE IF EXISTS add_account //
CREATE PROCEDURE add_account(
    IN p_username VARCHAR(50),
    IN p_password_hash VARCHAR(255),
    IN p_email VARCHAR(100),
    IN p_first_name VARCHAR(100),
    IN p_last_name VARCHAR(100),
    IN p_role VARCHAR(20),
    IN p_student_number VARCHAR(10),
    IN p_year_of_enrollment SMALLINT,
    IN p_date_of_birth DATE,
    IN p_sex VARCHAR(10),
    IN p_contact_number VARCHAR(20),
    IN p_emergency_contact_name VARCHAR(100),
    IN p_emergency_contact_number VARCHAR(20),
    IN p_year_level VARCHAR(20),
    IN p_section VARCHAR(20),
    IN p_blood_type VARCHAR(5),
    IN p_allergies TEXT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_student_number VARCHAR(10);
    DECLARE v_qr_token CHAR(36);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO users (username, password_hash, email, first_name, last_name, role)
    VALUES (p_username, p_password_hash, p_email, p_first_name, p_last_name, p_role);

    SET v_user_id = LAST_INSERT_ID();

    IF p_role = 'student' THEN
        IF p_year_of_enrollment IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'year_of_enrollment is required when role=student';
        END IF;

        INSERT INTO students (
            student_number, user_id, year_of_enrollment, date_of_birth, sex,
            contact_number, emergency_contact_name, emergency_contact_number,
            year_level, section, blood_type, allergies
        )
        VALUES (
            COALESCE(p_student_number, ''), v_user_id, p_year_of_enrollment, p_date_of_birth, p_sex,
            p_contact_number, p_emergency_contact_name, p_emergency_contact_number,
            p_year_level, p_section, p_blood_type, p_allergies
        );

        SELECT student_number INTO v_student_number
        FROM students
        WHERE user_id = v_user_id;

        INSERT INTO qr_codes (student_number)
        VALUES (v_student_number);

        SELECT qr_token INTO v_qr_token
        FROM qr_codes
        WHERE student_number = v_student_number
        ORDER BY generated_at DESC
        LIMIT 1;
    END IF;

    COMMIT;

    SELECT v_user_id AS user_id,
           v_student_number AS student_number,
           v_qr_token AS qr_token,
           'account_created' AS result;
END //

DROP PROCEDURE IF EXISTS update_account //
CREATE PROCEDURE update_account(
    IN p_user_id INT,
    IN p_email VARCHAR(100),
    IN p_first_name VARCHAR(100),
    IN p_last_name VARCHAR(100),
    IN p_is_active BOOLEAN,
    IN p_date_of_birth DATE,
    IN p_sex VARCHAR(10),
    IN p_contact_number VARCHAR(20),
    IN p_emergency_contact_name VARCHAR(100),
    IN p_emergency_contact_number VARCHAR(20),
    IN p_year_level VARCHAR(20),
    IN p_section VARCHAR(20),
    IN p_blood_type VARCHAR(5),
    IN p_allergies TEXT,
    IN p_qr_active BOOLEAN
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_student_number VARCHAR(10);

    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User does not exist';
    END IF;

    UPDATE users
    SET email = COALESCE(p_email, email),
        first_name = COALESCE(p_first_name, first_name),
        last_name = COALESCE(p_last_name, last_name),
        is_active = COALESCE(p_is_active, is_active)
    WHERE user_id = p_user_id;

    SELECT student_number INTO v_student_number
    FROM students
    WHERE user_id = p_user_id
    LIMIT 1;

    IF v_student_number IS NOT NULL THEN
        UPDATE students
        SET date_of_birth = COALESCE(p_date_of_birth, date_of_birth),
            sex = COALESCE(p_sex, sex),
            contact_number = COALESCE(p_contact_number, contact_number),
            emergency_contact_name = COALESCE(p_emergency_contact_name, emergency_contact_name),
            emergency_contact_number = COALESCE(p_emergency_contact_number, emergency_contact_number),
            year_level = COALESCE(p_year_level, year_level),
            section = COALESCE(p_section, section),
            blood_type = COALESCE(p_blood_type, blood_type),
            allergies = COALESCE(p_allergies, allergies)
        WHERE student_number = v_student_number;

        IF p_qr_active IS NOT NULL THEN
            UPDATE qr_codes
            SET is_active = p_qr_active
            WHERE student_number = v_student_number;
        END IF;
    END IF;

    SELECT p_user_id AS user_id,
           v_student_number AS student_number,
           'account_updated' AS result;
END //

DROP PROCEDURE IF EXISTS deactivate_account //
CREATE PROCEDURE deactivate_account(IN p_user_id INT)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_student_number VARCHAR(10);

    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User does not exist';
    END IF;

    UPDATE users
    SET is_active = FALSE
    WHERE user_id = p_user_id;

    SELECT student_number INTO v_student_number
    FROM students
    WHERE user_id = p_user_id
    LIMIT 1;

    IF v_student_number IS NOT NULL THEN
        UPDATE qr_codes
        SET is_active = FALSE
        WHERE student_number = v_student_number;
    END IF;

    UPDATE user_session
    SET revoked_at = COALESCE(revoked_at, CURRENT_TIMESTAMP)
    WHERE user_id = p_user_id
      AND revoked_at IS NULL;

    SELECT p_user_id AS user_id,
           v_student_number AS student_number,
           'account_deactivated' AS result;
END //

-- ============================================================================
-- 2.0 Check In Student (QR)
-- ============================================================================

DROP PROCEDURE IF EXISTS check_in_qr //
CREATE PROCEDURE check_in_qr(IN p_qr_token CHAR(36))
SQL SECURITY DEFINER
BEGIN
    SELECT *
    FROM v_qr_checkin_context
    WHERE qr_token = p_qr_token;
END //



-- ============================================================================
-- 5.0 Dispense Medicine
-- ============================================================================

DROP PROCEDURE IF EXISTS dispense_medicine //
CREATE PROCEDURE dispense_medicine(
    IN p_consultation_id INT,
    IN p_medicine_id INT,
    IN p_quantity_given INT,
    IN p_dispensed_by INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_available INT;
    DECLARE v_dispense_id INT;
    DECLARE v_remaining INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity_given <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'quantity_given must be greater than zero';
    END IF;

    START TRANSACTION;

    SELECT available_quantity INTO v_available
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF v_available IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Medicine does not exist';
    END IF;

    IF v_available < p_quantity_given THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient medicine quantity';
    END IF;

    INSERT INTO consultation_medicines (
        consultation_id, medicine_id, quantity_given, dispensed_by
    )
    VALUES (p_consultation_id, p_medicine_id, p_quantity_given, p_dispensed_by);

    SET v_dispense_id = LAST_INSERT_ID();

    UPDATE medicines
    SET available_quantity = available_quantity - p_quantity_given
    WHERE medicine_id = p_medicine_id;

    SELECT available_quantity INTO v_remaining
    FROM medicines
    WHERE medicine_id = p_medicine_id;

    COMMIT;

    SELECT v_dispense_id AS dispense_id,
           v_remaining AS remaining_quantity,
           'medicine_dispensed' AS result;
END //

-- ============================================================================
-- 6.0 Manage Health Clearance
-- ============================================================================

DROP PROCEDURE IF EXISTS request_clearance //
CREATE PROCEDURE request_clearance(
    IN p_student_number VARCHAR(10),
    IN p_requested_by INT,
    IN p_purpose VARCHAR(100)
)
SQL SECURITY DEFINER
BEGIN
    INSERT INTO health_clearances (student_number, requested_by, purpose, status)
    VALUES (p_student_number, p_requested_by, p_purpose, 'pending');

    SELECT LAST_INSERT_ID() AS clearance_id;
END //

DROP PROCEDURE IF EXISTS decide_clearance //
CREATE PROCEDURE decide_clearance(
    IN p_clearance_id INT,
    IN p_issued_by INT,
    IN p_status VARCHAR(20),
    IN p_remarks TEXT,
    IN p_valid_until DATE
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (SELECT 1 FROM health_clearances WHERE clearance_id = p_clearance_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Clearance does not exist';
    END IF;

    IF p_status NOT IN ('cleared', 'not_cleared', 'pending') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid clearance status';
    END IF;

    UPDATE health_clearances
    SET issued_by = p_issued_by,
        status = p_status,
        remarks = p_remarks,
        valid_until = p_valid_until
    WHERE clearance_id = p_clearance_id;

    SELECT p_clearance_id AS clearance_id,
           p_status AS status,
           'clearance_recorded' AS result;
END //

-- ============================================================================
-- 7.0 View Medical History
-- ============================================================================

DROP PROCEDURE IF EXISTS student_medical_history //
CREATE PROCEDURE student_medical_history()
SQL SECURITY DEFINER
BEGIN
    SELECT *
    FROM v_student_medical_history;
END //

-- ============================================================================
-- 8.0 Authentication & Portal Access
-- ============================================================================

DROP PROCEDURE IF EXISTS route_user_portal //
CREATE PROCEDURE route_user_portal(IN p_session_token_hash CHAR(64))
SQL SECURITY DEFINER
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_role VARCHAR(20);

    SELECT s.user_id, s.role
      INTO v_user_id, v_role
    FROM user_session s
    JOIN users u ON u.user_id = s.user_id
    WHERE s.session_token_hash = p_session_token_hash
      AND s.revoked_at IS NULL
      AND s.expires_at > CURRENT_TIMESTAMP
      AND u.is_active = TRUE
    LIMIT 1;

    IF v_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid, expired, revoked, or inactive session.';
    END IF;

    UPDATE user_session
    SET last_seen_at = CURRENT_TIMESTAMP
    WHERE session_token_hash = p_session_token_hash;

    SET @app_current_user_id = v_user_id;
    SET @app_current_role = v_role;

    SELECT
        u.user_id,
        u.username,
        u.role,
        CASE u.role
            WHEN 'admin' THEN 'admin_portal'
            WHEN 'nurse' THEN 'clinic_staff_portal'
            WHEN 'doctor' THEN 'doctor_portal'
            WHEN 'faculty' THEN 'faculty_portal'
            WHEN 'student' THEN 'student_portal'
        END AS portal,
        s.session_id,
        s.expires_at
    FROM user_session s
    JOIN users u ON u.user_id = s.user_id
    WHERE s.session_token_hash = p_session_token_hash
      AND s.revoked_at IS NULL
      AND s.expires_at > CURRENT_TIMESTAMP
    LIMIT 1;
END //

DELIMITER ;

GRANT SELECT ON school_clinic.v_account_details TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic.v_qr_checkin_context TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic.v_consultation_context TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic.v_prescription_context TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic.v_dispense_context TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic.v_clearance_context TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic.v_active_sessions TO 'clinic_app'@'%';

GRANT EXECUTE ON PROCEDURE school_clinic.add_account TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.update_account TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.deactivate_account TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.check_in_qr TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.save_consultation TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.issue_prescription TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.dispense_medicine TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.request_clearance TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.decide_clearance TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.student_medical_history TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.route_user_portal TO 'clinic_app'@'%';
