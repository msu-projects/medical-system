-- ============================================================================
-- 07_audit.sql
-- School Clinic Management System — Audit Logging (Trigger-Based, MySQL)
-- ============================================================================
-- Run AFTER 06_grants.sql:
--   mysql -u root -p < 07_audit.sql
-- ============================================================================
-- AUDIT TRAIL captures every INSERT, UPDATE, and DELETE on clinical tables.
--
-- Design:
--   - Single generic audit table in a separate 'school_clinic_audit' database
--   - JSON columns for old_data/new_data — works for any table schema
--   - Triggers on each table log changes automatically
--   - Records app-level user identity (from session variable) + DB user
--
-- Security:
--   - Only clinic_admin can SELECT from the audit table
--   - NO role can UPDATE or DELETE audit records (append-only)
--   - Audit table in separate database prevents accidental access
-- ============================================================================

-- ============================================================================
-- 1. AUDIT TABLE
-- ============================================================================

USE school_clinic_audit;

CREATE TABLE IF NOT EXISTS activity_log (
    log_id         BIGINT       AUTO_INCREMENT PRIMARY KEY,
    table_schema   VARCHAR(64)  NOT NULL,
    table_name     VARCHAR(64)  NOT NULL,
    operation      ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_data       JSON         DEFAULT NULL,
    new_data       JSON         DEFAULT NULL,
    changed_fields TEXT         DEFAULT NULL,
    app_user_id    VARCHAR(20)  DEFAULT NULL,
    db_user        VARCHAR(100) NOT NULL DEFAULT (CURRENT_USER()),
    client_ip      VARCHAR(45)  DEFAULT NULL,
    changed_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_table     (table_schema, table_name),
    INDEX idx_audit_operation (operation),
    INDEX idx_audit_user      (app_user_id),
    INDEX idx_audit_timestamp (changed_at),
    INDEX idx_audit_composite (table_name, changed_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 2. AUDIT TRIGGER FUNCTIONS
-- ============================================================================
-- MySQL does not support generic trigger functions like PostgreSQL.
-- We create individual triggers per table. Each trigger captures the
-- operation, old/new row data as JSON, and the app session context.

USE school_clinic;

DELIMITER //

-- -------------------------------------------------------
-- clinic.users — Audit Triggers
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_users_insert
    AFTER INSERT ON users
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'users', 'INSERT',
        JSON_OBJECT(
            'user_id', NEW.user_id, 'username', NEW.username,
            'email', NEW.email,
            'first_name', NEW.first_name, 'last_name', NEW.last_name,
            'role', NEW.role, 'is_active', NEW.is_active
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_users_update
    AFTER UPDATE ON users
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'users', 'UPDATE',
        JSON_OBJECT(
            'user_id', OLD.user_id, 'username', OLD.username,
            'email', OLD.email,
            'first_name', OLD.first_name, 'last_name', OLD.last_name,
            'role', OLD.role, 'is_active', OLD.is_active
        ),
        JSON_OBJECT(
            'user_id', NEW.user_id, 'username', NEW.username,
            'email', NEW.email,
            'first_name', NEW.first_name, 'last_name', NEW.last_name,
            'role', NEW.role, 'is_active', NEW.is_active
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_users_delete
    AFTER DELETE ON users
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'users', 'DELETE',
        JSON_OBJECT(
            'user_id', OLD.user_id, 'username', OLD.username,
            'email', OLD.email,
            'first_name', OLD.first_name, 'last_name', OLD.last_name,
            'role', OLD.role, 'is_active', OLD.is_active
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

-- -------------------------------------------------------
-- clinic.students — Audit Triggers
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_students_insert
    AFTER INSERT ON students
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'students', 'INSERT',
        JSON_OBJECT(
            'student_id', NEW.student_id, 'user_id', NEW.user_id,
            'student_number', NEW.student_number,
            'first_name', NEW.first_name, 'last_name', NEW.last_name,
            'year_level', NEW.year_level, 'section', NEW.section
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_students_update
    AFTER UPDATE ON students
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'students', 'UPDATE',
        JSON_OBJECT(
            'student_id', OLD.student_id, 'user_id', OLD.user_id,
            'student_number', OLD.student_number,
            'first_name', OLD.first_name, 'last_name', OLD.last_name,
            'year_level', OLD.year_level, 'section', OLD.section
        ),
        JSON_OBJECT(
            'student_id', NEW.student_id, 'user_id', NEW.user_id,
            'student_number', NEW.student_number,
            'first_name', NEW.first_name, 'last_name', NEW.last_name,
            'year_level', NEW.year_level, 'section', NEW.section
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_students_delete
    AFTER DELETE ON students
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'students', 'DELETE',
        JSON_OBJECT(
            'student_id', OLD.student_id, 'user_id', OLD.user_id,
            'student_number', OLD.student_number,
            'first_name', OLD.first_name, 'last_name', OLD.last_name
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

-- -------------------------------------------------------
-- clinic.qr_codes — Audit Triggers
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_qr_codes_insert
    AFTER INSERT ON qr_codes
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'qr_codes', 'INSERT',
        JSON_OBJECT('qr_id', NEW.qr_id, 'student_id', NEW.student_id, 'qr_token', NEW.qr_token, 'is_active', NEW.is_active),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_qr_codes_update
    AFTER UPDATE ON qr_codes
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'qr_codes', 'UPDATE',
        JSON_OBJECT('qr_id', OLD.qr_id, 'student_id', OLD.student_id, 'qr_token', OLD.qr_token, 'is_active', OLD.is_active),
        JSON_OBJECT('qr_id', NEW.qr_id, 'student_id', NEW.student_id, 'qr_token', NEW.qr_token, 'is_active', NEW.is_active),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_qr_codes_delete
    AFTER DELETE ON qr_codes
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'qr_codes', 'DELETE',
        JSON_OBJECT('qr_id', OLD.qr_id, 'student_id', OLD.student_id, 'qr_token', OLD.qr_token),
        @app_current_user_id, CURRENT_USER()
    );
END //

-- -------------------------------------------------------
-- clinic.consultations — Audit Triggers
-- -------------------------------------------------------
-- NOTE: encrypted BLOB columns (diagnosis, treatment_notes) are stored
-- as '[ENCRYPTED]' in the audit log to avoid logging raw ciphertext.
CREATE TRIGGER trg_audit_consultations_insert
    AFTER INSERT ON consultations
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'consultations', 'INSERT',
        JSON_OBJECT(
            'consultation_id', NEW.consultation_id, 'student_id', NEW.student_id,
            'attended_by', NEW.attended_by, 'chief_complaint', NEW.chief_complaint,
            'diagnosis', '[ENCRYPTED]', 'treatment_notes', '[ENCRYPTED]',
            'vitals_bp', NEW.vitals_bp, 'vitals_temp', NEW.vitals_temp,
            'status', NEW.status
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_consultations_update
    AFTER UPDATE ON consultations
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'consultations', 'UPDATE',
        JSON_OBJECT(
            'consultation_id', OLD.consultation_id, 'student_id', OLD.student_id,
            'attended_by', OLD.attended_by, 'chief_complaint', OLD.chief_complaint,
            'diagnosis', '[ENCRYPTED]', 'treatment_notes', '[ENCRYPTED]',
            'status', OLD.status
        ),
        JSON_OBJECT(
            'consultation_id', NEW.consultation_id, 'student_id', NEW.student_id,
            'attended_by', NEW.attended_by, 'chief_complaint', NEW.chief_complaint,
            'diagnosis', '[ENCRYPTED]', 'treatment_notes', '[ENCRYPTED]',
            'status', NEW.status
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_consultations_delete
    AFTER DELETE ON consultations
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'consultations', 'DELETE',
        JSON_OBJECT(
            'consultation_id', OLD.consultation_id, 'student_id', OLD.student_id,
            'attended_by', OLD.attended_by, 'status', OLD.status
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

-- -------------------------------------------------------
-- clinic.prescriptions — Audit Triggers
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_prescriptions_insert
    AFTER INSERT ON prescriptions
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'prescriptions', 'INSERT',
        JSON_OBJECT(
            'prescription_id', NEW.prescription_id, 'consultation_id', NEW.consultation_id,
            'prescribed_by', NEW.prescribed_by,
            'prescription_details', '[ENCRYPTED]', 'notes', '[ENCRYPTED]'
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_prescriptions_update
    AFTER UPDATE ON prescriptions
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'prescriptions', 'UPDATE',
        JSON_OBJECT(
            'prescription_id', OLD.prescription_id, 'consultation_id', OLD.consultation_id,
            'prescribed_by', OLD.prescribed_by,
            'prescription_details', '[ENCRYPTED]', 'notes', '[ENCRYPTED]'
        ),
        JSON_OBJECT(
            'prescription_id', NEW.prescription_id, 'consultation_id', NEW.consultation_id,
            'prescribed_by', NEW.prescribed_by,
            'prescription_details', '[ENCRYPTED]', 'notes', '[ENCRYPTED]'
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_prescriptions_delete
    AFTER DELETE ON prescriptions
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'prescriptions', 'DELETE',
        JSON_OBJECT(
            'prescription_id', OLD.prescription_id, 'consultation_id', OLD.consultation_id,
            'prescribed_by', OLD.prescribed_by
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

-- -------------------------------------------------------
-- clinic.medicines — Audit Triggers
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_medicines_insert
    AFTER INSERT ON medicines
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'medicines', 'INSERT',
        JSON_OBJECT('medicine_id', NEW.medicine_id, 'name', NEW.name, 'unit', NEW.unit, 'is_available', NEW.is_available),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_medicines_update
    AFTER UPDATE ON medicines
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'medicines', 'UPDATE',
        JSON_OBJECT('medicine_id', OLD.medicine_id, 'name', OLD.name, 'unit', OLD.unit, 'is_available', OLD.is_available),
        JSON_OBJECT('medicine_id', NEW.medicine_id, 'name', NEW.name, 'unit', NEW.unit, 'is_available', NEW.is_available),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_medicines_delete
    AFTER DELETE ON medicines
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'medicines', 'DELETE',
        JSON_OBJECT('medicine_id', OLD.medicine_id, 'name', OLD.name),
        @app_current_user_id, CURRENT_USER()
    );
END //

-- -------------------------------------------------------
-- clinic.consultation_medicines — Audit Triggers
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_consult_med_insert
    AFTER INSERT ON consultation_medicines
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'consultation_medicines', 'INSERT',
        JSON_OBJECT('id', NEW.id, 'consultation_id', NEW.consultation_id, 'medicine_id', NEW.medicine_id, 'quantity_given', NEW.quantity_given, 'dispensed_by', NEW.dispensed_by),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_consult_med_update
    AFTER UPDATE ON consultation_medicines
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'consultation_medicines', 'UPDATE',
        JSON_OBJECT('id', OLD.id, 'consultation_id', OLD.consultation_id, 'medicine_id', OLD.medicine_id, 'quantity_given', OLD.quantity_given, 'dispensed_by', OLD.dispensed_by),
        JSON_OBJECT('id', NEW.id, 'consultation_id', NEW.consultation_id, 'medicine_id', NEW.medicine_id, 'quantity_given', NEW.quantity_given, 'dispensed_by', NEW.dispensed_by),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_consult_med_delete
    AFTER DELETE ON consultation_medicines
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'consultation_medicines', 'DELETE',
        JSON_OBJECT('id', OLD.id, 'consultation_id', OLD.consultation_id, 'medicine_id', OLD.medicine_id),
        @app_current_user_id, CURRENT_USER()
    );
END //

-- -------------------------------------------------------
-- clinic.health_clearances — Audit Triggers
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_clearances_insert
    AFTER INSERT ON health_clearances
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'health_clearances', 'INSERT',
        JSON_OBJECT(
            'clearance_id', NEW.clearance_id, 'student_id', NEW.student_id,
            'purpose', NEW.purpose, 'status', NEW.status,
            'issued_by', NEW.issued_by, 'requested_by', NEW.requested_by
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_clearances_update
    AFTER UPDATE ON health_clearances
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, new_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'health_clearances', 'UPDATE',
        JSON_OBJECT(
            'clearance_id', OLD.clearance_id, 'student_id', OLD.student_id,
            'purpose', OLD.purpose, 'status', OLD.status,
            'issued_by', OLD.issued_by, 'requested_by', OLD.requested_by
        ),
        JSON_OBJECT(
            'clearance_id', NEW.clearance_id, 'student_id', NEW.student_id,
            'purpose', NEW.purpose, 'status', NEW.status,
            'issued_by', NEW.issued_by, 'requested_by', NEW.requested_by
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

CREATE TRIGGER trg_audit_clearances_delete
    AFTER DELETE ON health_clearances
    FOR EACH ROW
BEGIN
    INSERT INTO school_clinic_audit.activity_log
        (table_schema, table_name, operation, old_data, app_user_id, db_user)
    VALUES (
        'school_clinic', 'health_clearances', 'DELETE',
        JSON_OBJECT(
            'clearance_id', OLD.clearance_id, 'student_id', OLD.student_id,
            'purpose', OLD.purpose, 'status', OLD.status
        ),
        @app_current_user_id, CURRENT_USER()
    );
END //

DELIMITER ;

-- ============================================================================
-- 3. AUDIT TABLE SECURITY
-- ============================================================================
-- Only clinic_admin can read the audit log. No role can modify or delete records.

REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_doctor'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_nurse'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_student'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_faculty'@'%';

-- Admin: read-only access to audit log
GRANT SELECT ON school_clinic_audit.activity_log TO 'clinic_admin'@'%';

-- The clinic_app account needs INSERT on audit (triggers run as definer,
-- but if connecting as clinic_app, the trigger's DEFINER context handles it)
GRANT INSERT ON school_clinic_audit.activity_log TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic_audit.activity_log TO 'clinic_app'@'%';

FLUSH PRIVILEGES;

-- ============================================================================
-- 4. HELPER VIEWS FOR AUDIT QUERIES
-- ============================================================================

USE school_clinic_audit;

-- Recent activity view — admin-only
CREATE OR REPLACE VIEW v_recent_activity AS
SELECT
    log_id,
    table_name,
    operation,
    app_user_id,
    db_user,
    changed_fields,
    changed_at,
    client_ip
FROM
    activity_log
ORDER BY
    changed_at DESC
LIMIT 100;

-- Medical record access log
CREATE OR REPLACE VIEW v_medical_record_access AS
SELECT
    log_id,
    table_name,
    operation,
    app_user_id,
    db_user,
    CASE
        WHEN operation = 'INSERT' THEN JSON_UNQUOTE(JSON_EXTRACT(new_data, '$.student_id'))
        WHEN operation = 'DELETE' THEN JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.student_id'))
        ELSE COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(new_data, '$.student_id')),
            JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.student_id'))
        )
    END AS affected_student_id,
    changed_fields,
    changed_at,
    client_ip
FROM
    activity_log
WHERE
    table_name IN ('consultations', 'prescriptions', 'consultation_medicines', 'health_clearances')
ORDER BY
    changed_at DESC;

GRANT SELECT ON school_clinic_audit.v_recent_activity TO 'clinic_admin'@'%';
GRANT SELECT ON school_clinic_audit.v_medical_record_access TO 'clinic_admin'@'%';

FLUSH PRIVILEGES;

-- ============================================================================
-- Verification
-- ============================================================================
-- 1. Make a change and check the audit log:
--
--   USE school_clinic;
--   SET @app_current_user_id = 1;
--   UPDATE users SET is_active = FALSE WHERE user_id = 99;
--   SELECT * FROM school_clinic_audit.activity_log ORDER BY log_id DESC LIMIT 5;
--
-- 2. Verify immutability (as clinic_nurse):
--   -- mysql -u clinic_nurse -p
--   DELETE FROM school_clinic_audit.activity_log WHERE log_id = 1;  -- ERROR
--   UPDATE school_clinic_audit.activity_log SET operation = 'INSERT';  -- ERROR
--
-- 3. Verify admin can read:
--   -- mysql -u clinic_admin -p
--   SELECT * FROM school_clinic_audit.v_recent_activity;
--   SELECT * FROM school_clinic_audit.v_medical_record_access;
-- ============================================================================
