-- ============================================================================
-- 02_tables.sql
-- School Clinic Management System — Table Definitions (MySQL)
-- ============================================================================
-- Run AFTER 01_init.sql:
--   mysql -u root -p school_clinic < 02_tables.sql
-- ============================================================================

USE school_clinic;

-- --------------------------------------------------------
-- 1. Users — Authentication & Role Assignment
-- --------------------------------------------------------
-- All system users (admin, doctors, nurses, students, faculty)
-- Passwords are bcrypt-hashed in the application layer, stored here as text.

CREATE TABLE users (
    user_id       INT          AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email         VARCHAR(100) DEFAULT NULL,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    role          ENUM('admin', 'nurse', 'doctor', 'student', 'faculty') NOT NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login    TIMESTAMP    NULL DEFAULT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_role      (role),
    INDEX idx_users_username  (username),
    INDEX idx_users_last_name (last_name),
    INDEX idx_users_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 2. Students — Extended Student Profile
-- --------------------------------------------------------
-- One-to-one with users (only users with role='student').
-- Contains demographic and medical baseline data.

CREATE TABLE students (
    student_id               INT      AUTO_INCREMENT PRIMARY KEY,
    user_id                  INT      NOT NULL UNIQUE,
    year_of_enrollment       SMALLINT NOT NULL
                               CHECK (year_of_enrollment BETWEEN 2000 AND 9999),
    student_number           VARCHAR(20) UNIQUE,
    date_of_birth            DATE         DEFAULT NULL,
    sex                      ENUM('Male', 'Female', 'Other') DEFAULT NULL,
    contact_number           VARCHAR(20)  DEFAULT NULL,
    emergency_contact_name   VARCHAR(100) DEFAULT NULL,
    emergency_contact_number VARCHAR(20)  DEFAULT NULL,
    year_level               VARCHAR(20)  DEFAULT NULL,
    section                  VARCHAR(20)  DEFAULT NULL,
    blood_type               ENUM('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-') DEFAULT NULL,
    allergies                TEXT         DEFAULT NULL,
    created_at               TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_students_student_number_format
        CHECK (student_number IS NULL OR student_number REGEXP '^[0-9]{4}-[0-9]{4,}$'),
    INDEX idx_students_student_number (student_number),
    INDEX idx_students_year_section   (year_level, section),
    CONSTRAINT fk_students_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 3. QR Codes — Unique Scannable Tokens per Student
-- --------------------------------------------------------
-- Each student gets a UUID-based QR token for fast clinic check-in.
-- The QR code image encodes this UUID — never the student_id.

-- student_id IS the primary key — one QR code per student (shared PK / 1:1 pattern)
CREATE TABLE qr_codes (
    student_id   INT       NOT NULL PRIMARY KEY,
    qr_token     CHAR(36)  NOT NULL UNIQUE DEFAULT (UUID()),
    is_active    BOOLEAN   NOT NULL DEFAULT TRUE,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_qr_codes_token (qr_token),
    CONSTRAINT fk_qr_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 4. Consultations — Core Medical Records
-- --------------------------------------------------------
-- Each visit to the clinic creates a consultation record.
-- SECURITY: diagnosis and treatment_notes are AES-256 encrypted at rest.
-- They are stored as VARBINARY/BLOB.

CREATE TABLE consultations (
    consultation_id INT          AUTO_INCREMENT PRIMARY KEY,
    student_id      INT          NOT NULL,
    attended_by     INT          NOT NULL,
    check_in_time   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    chief_complaint TEXT         DEFAULT NULL,
    -- !! ENCRYPTED COLUMNS — stored as BLOB, decrypted via AES_DECRYPT() !!
    diagnosis       BLOB         NOT NULL,
    treatment_notes BLOB         DEFAULT NULL,
    -- Vital signs (not encrypted — not considered highly sensitive)
    vitals_bp       VARCHAR(10)  DEFAULT NULL,
    vitals_temp     DECIMAL(4,1) DEFAULT NULL,
    vitals_pulse    INT          DEFAULT NULL,
    vitals_weight   DECIMAL(5,1) DEFAULT NULL,
    status          ENUM('ongoing', 'completed', 'referred') NOT NULL DEFAULT 'ongoing',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_consultations_student  (student_id),
    INDEX idx_consultations_attended (attended_by),
    INDEX idx_consultations_date     (check_in_time),
    INDEX idx_consultations_status   (status),
    CONSTRAINT fk_consult_student  FOREIGN KEY (student_id)  REFERENCES students(student_id)  ON DELETE RESTRICT,
    CONSTRAINT fk_consult_attendee FOREIGN KEY (attended_by) REFERENCES users(user_id)        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 5. Prescriptions — Doctor-Issued Medication Orders
-- --------------------------------------------------------
-- Only doctors can create prescriptions.
-- SECURITY: prescription_details and notes are AES-256 encrypted.

CREATE TABLE prescriptions (
    prescription_id      INT       AUTO_INCREMENT PRIMARY KEY,
    consultation_id      INT       NOT NULL,
    prescribed_by        INT       NOT NULL,
    -- !! ENCRYPTED COLUMNS !!
    prescription_details BLOB      NOT NULL,
    notes                BLOB      DEFAULT NULL,
    issued_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_prescriptions_consultation (consultation_id),
    INDEX idx_prescriptions_doctor       (prescribed_by),
    CONSTRAINT fk_presc_consultation FOREIGN KEY (consultation_id) REFERENCES consultations(consultation_id) ON DELETE CASCADE,
    CONSTRAINT fk_presc_doctor       FOREIGN KEY (prescribed_by)   REFERENCES users(user_id)                ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 6. Medicines — Basic Medicine Catalog
-- --------------------------------------------------------

CREATE TABLE medicines (
    medicine_id  INT          AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    description  TEXT         DEFAULT NULL,
    unit         VARCHAR(20)  NOT NULL DEFAULT 'tablet',
    is_available BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_medicines_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 7. Consultation Medicines — What Was Dispensed
-- --------------------------------------------------------
-- Tracks medicines given to a student during a consultation.

CREATE TABLE consultation_medicines (
    id              INT       AUTO_INCREMENT PRIMARY KEY,
    consultation_id INT       NOT NULL,
    medicine_id     INT       NOT NULL,
    quantity_given  INT       NOT NULL,
    dispensed_by    INT       DEFAULT NULL,
    dispensed_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_consult_med_consultation (consultation_id),
    INDEX idx_consult_med_medicine     (medicine_id),
    CONSTRAINT fk_cm_consultation FOREIGN KEY (consultation_id) REFERENCES consultations(consultation_id) ON DELETE CASCADE,
    CONSTRAINT fk_cm_medicine     FOREIGN KEY (medicine_id)     REFERENCES medicines(medicine_id)         ON DELETE RESTRICT,
    CONSTRAINT fk_cm_dispensed_by FOREIGN KEY (dispensed_by)    REFERENCES users(user_id)                 ON DELETE SET NULL,
    CONSTRAINT chk_quantity_positive CHECK (quantity_given > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 8. Health Clearances — Medical Certificates & Clearance Status
-- --------------------------------------------------------

CREATE TABLE health_clearances (
    clearance_id INT          AUTO_INCREMENT PRIMARY KEY,
    student_id   INT          NOT NULL,
    issued_by    INT          DEFAULT NULL,
    purpose      VARCHAR(100) DEFAULT NULL,
    remarks      TEXT         DEFAULT NULL,
    status       ENUM('pending', 'cleared', 'not_cleared') NOT NULL DEFAULT 'pending',
    valid_until  DATE         DEFAULT NULL,
    requested_by INT          DEFAULT NULL,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_clearances_student (student_id),
    INDEX idx_clearances_status  (status),
    CONSTRAINT fk_clearance_student   FOREIGN KEY (student_id)   REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_clearance_issuer    FOREIGN KEY (issued_by)    REFERENCES users(user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_clearance_requester FOREIGN KEY (requested_by) REFERENCES users(user_id)       ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Note: MySQL handles updated_at automatically via ON UPDATE CURRENT_TIMESTAMP
-- so no trigger is needed (unlike PostgreSQL).
-- ============================================================================

-- --------------------------------------------------------
-- 9. Student Number Counter — Auto-Generation Support
-- --------------------------------------------------------
-- Tracks the last issued student-number suffix per enrollment year.
-- Used by trg_students_before_insert to auto-assign YYYY-NNNN numbers.

CREATE TABLE student_number_counters (
    enrollment_year SMALLINT NOT NULL PRIMARY KEY
        CHECK (enrollment_year BETWEEN 2000 AND 9999),
    last_value      INT      NOT NULL DEFAULT 0
        CHECK (last_value >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 10. Business Logic Triggers
-- --------------------------------------------------------
-- Mirrors PostgreSQL's fn_assign_student_number and fn_enforce_user_role.

DELIMITER //

-- Validate student user role and auto-assign student_number on INSERT
CREATE TRIGGER trg_students_before_insert
    BEFORE INSERT ON students
    FOR EACH ROW
BEGIN
    DECLARE v_role   VARCHAR(20);
    DECLARE v_next   INT;
    DECLARE v_yr     SMALLINT;
    DECLARE v_suffix INT;

    -- Enforce role: only users with role='student' can be in students table
    SELECT role INTO v_role FROM users WHERE user_id = NEW.user_id;
    IF v_role IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'students.user_id references a non-existent user';
    END IF;
    IF v_role <> 'student' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'students.user_id must reference a user with role=student';
    END IF;

    -- Auto-assign or validate student_number
    IF NEW.student_number IS NULL OR NEW.student_number = '' THEN
        -- Atomically increment counter and retrieve new value
        INSERT INTO student_number_counters (enrollment_year, last_value)
        VALUES (NEW.year_of_enrollment, 1)
        ON DUPLICATE KEY UPDATE last_value = last_value + 1;

        SELECT last_value INTO v_next
        FROM student_number_counters
        WHERE enrollment_year = NEW.year_of_enrollment;

        SET NEW.student_number = CONCAT(NEW.year_of_enrollment, '-',
                                        LPAD(CAST(v_next AS CHAR), 4, '0'));
    ELSE
        -- Validate supplied format
        IF NEW.student_number NOT REGEXP '^[0-9]{4}-[0-9]{4,}$' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'student_number must use the format YYYY-NNNN';
        END IF;

        SET v_yr     = CAST(SUBSTRING_INDEX(NEW.student_number, '-', 1)  AS UNSIGNED);
        SET v_suffix = CAST(SUBSTRING_INDEX(NEW.student_number, '-', -1) AS UNSIGNED);

        IF v_yr <> NEW.year_of_enrollment THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'student_number year prefix must match year_of_enrollment';
        END IF;

        -- Update counter if supplied suffix exceeds current last value
        INSERT INTO student_number_counters (enrollment_year, last_value)
        VALUES (NEW.year_of_enrollment, v_suffix)
        ON DUPLICATE KEY UPDATE last_value = GREATEST(last_value, v_suffix);
    END IF;
END //

-- Re-validate user role and student_number consistency on UPDATE
CREATE TRIGGER trg_students_before_update
    BEFORE UPDATE ON students
    FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    IF NEW.user_id <> OLD.user_id THEN
        SELECT role INTO v_role FROM users WHERE user_id = NEW.user_id;
        IF v_role IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'students.user_id references a non-existent user';
        END IF;
        IF v_role <> 'student' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'students.user_id must reference a user with role=student';
        END IF;
    END IF;

    IF NEW.student_number IS NOT NULL AND NEW.student_number <> '' AND
       (NEW.student_number <> OLD.student_number OR
        NEW.year_of_enrollment <> OLD.year_of_enrollment) THEN
        IF NEW.student_number NOT REGEXP '^[0-9]{4}-[0-9]{4,}$' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'student_number must use the format YYYY-NNNN';
        END IF;
        IF CAST(SUBSTRING_INDEX(NEW.student_number, '-', 1) AS UNSIGNED) <>
           NEW.year_of_enrollment THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'student_number year prefix must match year_of_enrollment';
        END IF;
    END IF;
END //

-- Enforce doctor/nurse role for consultations.attended_by on INSERT
CREATE TRIGGER trg_consultations_require_staff_role
    BEFORE INSERT ON consultations
    FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT role INTO v_role FROM users WHERE user_id = NEW.attended_by;
    IF v_role IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'consultations.attended_by references a non-existent user';
    END IF;
    IF v_role NOT IN ('doctor', 'nurse') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'consultations.attended_by must be a doctor or nurse';
    END IF;
END //

-- Enforce doctor/nurse role for consultations.attended_by on UPDATE
CREATE TRIGGER trg_consultations_require_staff_role_upd
    BEFORE UPDATE ON consultations
    FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    IF NEW.attended_by <> OLD.attended_by THEN
        SELECT role INTO v_role FROM users WHERE user_id = NEW.attended_by;
        IF v_role IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'consultations.attended_by references a non-existent user';
        END IF;
        IF v_role NOT IN ('doctor', 'nurse') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'consultations.attended_by must be a doctor or nurse';
        END IF;
    END IF;
END //

-- Enforce doctor role for prescriptions.prescribed_by on INSERT
CREATE TRIGGER trg_prescriptions_require_doctor_role
    BEFORE INSERT ON prescriptions
    FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT role INTO v_role FROM users WHERE user_id = NEW.prescribed_by;
    IF v_role IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'prescriptions.prescribed_by references a non-existent user';
    END IF;
    IF v_role <> 'doctor' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'prescriptions.prescribed_by must be a doctor';
    END IF;
END //

-- Enforce doctor role for prescriptions.prescribed_by on UPDATE
CREATE TRIGGER trg_prescriptions_require_doctor_role_upd
    BEFORE UPDATE ON prescriptions
    FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    IF NEW.prescribed_by <> OLD.prescribed_by THEN
        SELECT role INTO v_role FROM users WHERE user_id = NEW.prescribed_by;
        IF v_role IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'prescriptions.prescribed_by references a non-existent user';
        END IF;
        IF v_role <> 'doctor' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'prescriptions.prescribed_by must be a doctor';
        END IF;
    END IF;
END //

-- Enforce issued_by (doctor/nurse) and requested_by (faculty) on health_clearances INSERT
CREATE TRIGGER trg_clearances_before_insert
    BEFORE INSERT ON health_clearances
    FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    IF NEW.issued_by IS NOT NULL THEN
        SELECT role INTO v_role FROM users WHERE user_id = NEW.issued_by;
        IF v_role IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'health_clearances.issued_by references a non-existent user';
        END IF;
        IF v_role NOT IN ('doctor', 'nurse') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'health_clearances.issued_by must be a doctor or nurse';
        END IF;
    END IF;

    IF NEW.requested_by IS NOT NULL THEN
        SELECT role INTO v_role FROM users WHERE user_id = NEW.requested_by;
        IF v_role IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'health_clearances.requested_by references a non-existent user';
        END IF;
        IF v_role <> 'faculty' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'health_clearances.requested_by must be faculty';
        END IF;
    END IF;
END //

-- Enforce issued_by (doctor/nurse) on health_clearances UPDATE
CREATE TRIGGER trg_clearances_before_update
    BEFORE UPDATE ON health_clearances
    FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    IF NEW.issued_by IS NOT NULL AND
       (OLD.issued_by IS NULL OR NEW.issued_by <> OLD.issued_by) THEN
        SELECT role INTO v_role FROM users WHERE user_id = NEW.issued_by;
        IF v_role IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'health_clearances.issued_by references a non-existent user';
        END IF;
        IF v_role NOT IN ('doctor', 'nurse') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'health_clearances.issued_by must be a doctor or nurse';
        END IF;
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- Verification
-- ============================================================================
-- SHOW TABLES;
-- DESCRIBE users;       -- first_name, last_name (no full_name)
-- DESCRIBE students;    -- year_of_enrollment, no first_name/last_name
-- DESCRIBE qr_codes;    -- student_id is the PRIMARY KEY (no qr_id)
-- SHOW TRIGGERS;
-- ============================================================================
