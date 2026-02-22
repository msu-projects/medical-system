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
    full_name     VARCHAR(100) NOT NULL,
    role          ENUM('admin', 'nurse', 'doctor', 'student', 'faculty') NOT NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login    TIMESTAMP    NULL DEFAULT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_role      (role),
    INDEX idx_users_username  (username),
    INDEX idx_users_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 2. Students — Extended Student Profile
-- --------------------------------------------------------
-- One-to-one with users (only users with role='student').
-- Contains demographic and medical baseline data.

CREATE TABLE students (
    student_id               INT          AUTO_INCREMENT PRIMARY KEY,
    user_id                  INT          NOT NULL UNIQUE,
    student_number           VARCHAR(20)  NOT NULL UNIQUE,
    first_name               VARCHAR(50)  NOT NULL,
    last_name                VARCHAR(50)  NOT NULL,
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
    INDEX idx_students_student_number (student_number),
    INDEX idx_students_last_name      (last_name),
    INDEX idx_students_year_section   (year_level, section),
    CONSTRAINT fk_students_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 3. QR Codes — Unique Scannable Tokens per Student
-- --------------------------------------------------------
-- Each student gets a UUID-based QR token for fast clinic check-in.
-- The QR code image encodes this UUID — never the student_id.

CREATE TABLE qr_codes (
    qr_id        INT          AUTO_INCREMENT PRIMARY KEY,
    student_id   INT          NOT NULL UNIQUE,
    qr_token     CHAR(36)     NOT NULL UNIQUE DEFAULT (UUID()),
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
    generated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_qr_codes_active_token ((CAST(is_active AS UNSIGNED)), qr_token),
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

-- ============================================================================
-- Verification
-- ============================================================================
-- SHOW TABLES;
-- DESCRIBE users;
-- SHOW INDEX FROM consultations;
-- ============================================================================
