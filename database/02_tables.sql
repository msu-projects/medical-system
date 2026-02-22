-- ============================================================================
-- 02_tables.sql
-- School Clinic Management System — Table Definitions
-- ============================================================================
-- Run AFTER 01_init.sql:
--   psql -U postgres -d school_clinic_db -f 02_tables.sql
-- ============================================================================

SET search_path TO clinic, public;

-- --------------------------------------------------------
-- 1. Users — Authentication & Role Assignment
-- --------------------------------------------------------
-- All system users (admin, doctors, nurses, students, faculty)
-- Passwords are bcrypt-hashed in the application layer, stored here as text.

CREATE TABLE clinic.users (
    user_id       SERIAL       PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email         VARCHAR(100),
    full_name     VARCHAR(100) NOT NULL,
    role          VARCHAR(20)  NOT NULL
                    CHECK (role IN ('admin', 'nurse', 'doctor', 'student', 'faculty')),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_role      ON clinic.users (role);
CREATE INDEX idx_users_username  ON clinic.users (username);
CREATE INDEX idx_users_is_active ON clinic.users (is_active);

COMMENT ON TABLE  clinic.users               IS 'All system users across all roles';
COMMENT ON COLUMN clinic.users.password_hash  IS 'bcrypt hash — generated in the application layer, NOT in the database';
COMMENT ON COLUMN clinic.users.role           IS 'Application role: admin, nurse, doctor, student, faculty';

-- --------------------------------------------------------
-- 2. Students — Extended Student Profile
-- --------------------------------------------------------
-- One-to-one with users (only users with role='student').
-- Contains demographic and medical baseline data.

CREATE TABLE clinic.students (
    student_id               SERIAL       PRIMARY KEY,
    user_id                  INT          NOT NULL UNIQUE
                               REFERENCES clinic.users(user_id) ON DELETE CASCADE,
    student_number           VARCHAR(20)  NOT NULL UNIQUE,
    first_name               VARCHAR(50)  NOT NULL,
    last_name                VARCHAR(50)  NOT NULL,
    date_of_birth            DATE,
    sex                      VARCHAR(10)  CHECK (sex IN ('Male', 'Female', 'Other')),
    contact_number           VARCHAR(20),
    emergency_contact_name   VARCHAR(100),
    emergency_contact_number VARCHAR(20),
    year_level               VARCHAR(20),
    section                  VARCHAR(20),
    blood_type               VARCHAR(5)   CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    allergies                TEXT,
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_students_student_number ON clinic.students (student_number);
CREATE INDEX idx_students_last_name      ON clinic.students (last_name);
CREATE INDEX idx_students_year_section   ON clinic.students (year_level, section);

COMMENT ON TABLE  clinic.students                IS 'Extended profile for student users — demographics & medical baseline';
COMMENT ON COLUMN clinic.students.student_number  IS 'School-issued student ID number';
COMMENT ON COLUMN clinic.students.allergies       IS 'Known allergies — free text';

-- --------------------------------------------------------
-- 3. QR Codes — Unique Scannable Tokens per Student
-- --------------------------------------------------------
-- Each student gets a UUID-based QR token for fast clinic check-in.
-- The QR code image encodes this UUID — never the student_id.

CREATE TABLE clinic.qr_codes (
    qr_id        SERIAL      PRIMARY KEY,
    student_id   INT         NOT NULL UNIQUE
                   REFERENCES clinic.students(student_id) ON DELETE CASCADE,
    qr_token     UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_qr_codes_token ON clinic.qr_codes (qr_token) WHERE is_active = TRUE;

COMMENT ON TABLE  clinic.qr_codes           IS 'QR code tokens for fast student check-in at the clinic';
COMMENT ON COLUMN clinic.qr_codes.qr_token  IS 'UUID encoded into the physical QR code — prevents ID enumeration';

-- --------------------------------------------------------
-- 4. Consultations — Core Medical Records
-- --------------------------------------------------------
-- Each visit to the clinic creates a consultation record.
-- SECURITY: diagnosis and treatment_notes are AES-256 encrypted at rest
-- using pgcrypto pgp_sym_encrypt(). They are stored as BYTEA.

CREATE TABLE clinic.consultations (
    consultation_id SERIAL       PRIMARY KEY,
    student_id      INT          NOT NULL
                      REFERENCES clinic.students(student_id) ON DELETE RESTRICT,
    attended_by     INT          NOT NULL
                      REFERENCES clinic.users(user_id) ON DELETE RESTRICT,
    check_in_time   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    chief_complaint TEXT,
    -- !! ENCRYPTED COLUMNS — stored as BYTEA, decrypted via pgp_sym_decrypt() !!
    diagnosis       BYTEA        NOT NULL,
    treatment_notes BYTEA,
    -- Vital signs (not encrypted — not considered highly sensitive)
    vitals_bp       VARCHAR(10),
    vitals_temp     DECIMAL(4,1),
    vitals_pulse    INT,
    vitals_weight   DECIMAL(5,1),
    status          VARCHAR(20)  NOT NULL DEFAULT 'ongoing'
                      CHECK (status IN ('ongoing', 'completed', 'referred')),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_consultations_student    ON clinic.consultations (student_id);
CREATE INDEX idx_consultations_attended   ON clinic.consultations (attended_by);
CREATE INDEX idx_consultations_date       ON clinic.consultations (check_in_time);
CREATE INDEX idx_consultations_status     ON clinic.consultations (status);

COMMENT ON TABLE  clinic.consultations                IS 'Medical consultation records — one per clinic visit';
COMMENT ON COLUMN clinic.consultations.diagnosis       IS 'ENCRYPTED (AES-256 via pgcrypto) — decrypt with pgp_sym_decrypt(diagnosis, key)';
COMMENT ON COLUMN clinic.consultations.treatment_notes IS 'ENCRYPTED (AES-256 via pgcrypto) — internal clinical notes, hidden from students';
COMMENT ON COLUMN clinic.consultations.chief_complaint IS 'Patient-reported symptoms (plain text)';

-- --------------------------------------------------------
-- 5. Prescriptions — Doctor-Issued Medication Orders
-- --------------------------------------------------------
-- Only doctors can create prescriptions.
-- SECURITY: prescription_details and notes are AES-256 encrypted.

CREATE TABLE clinic.prescriptions (
    prescription_id      SERIAL      PRIMARY KEY,
    consultation_id      INT         NOT NULL
                           REFERENCES clinic.consultations(consultation_id) ON DELETE CASCADE,
    prescribed_by        INT         NOT NULL
                           REFERENCES clinic.users(user_id) ON DELETE RESTRICT,
    -- !! ENCRYPTED COLUMNS !!
    prescription_details BYTEA       NOT NULL,
    notes                BYTEA,
    issued_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_prescriptions_consultation ON clinic.prescriptions (consultation_id);
CREATE INDEX idx_prescriptions_doctor       ON clinic.prescriptions (prescribed_by);

COMMENT ON TABLE  clinic.prescriptions                      IS 'Doctor-issued prescriptions linked to consultations';
COMMENT ON COLUMN clinic.prescriptions.prescription_details IS 'ENCRYPTED (AES-256) — medication name, dosage, frequency, duration';
COMMENT ON COLUMN clinic.prescriptions.notes                IS 'ENCRYPTED (AES-256) — additional doctor notes';

-- --------------------------------------------------------
-- 6. Medicines — Basic Medicine Catalog
-- --------------------------------------------------------

CREATE TABLE clinic.medicines (
    medicine_id  SERIAL       PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    description  TEXT,
    unit         VARCHAR(20)  NOT NULL DEFAULT 'tablet',
    is_available BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_medicines_name ON clinic.medicines (name);

COMMENT ON TABLE clinic.medicines IS 'Basic medicine catalog — names and units (no full inventory tracking)';

-- --------------------------------------------------------
-- 7. Consultation Medicines — What Was Dispensed
-- --------------------------------------------------------
-- Tracks medicines given to a student during a consultation.

CREATE TABLE clinic.consultation_medicines (
    id              SERIAL      PRIMARY KEY,
    consultation_id INT         NOT NULL
                      REFERENCES clinic.consultations(consultation_id) ON DELETE CASCADE,
    medicine_id     INT         NOT NULL
                      REFERENCES clinic.medicines(medicine_id) ON DELETE RESTRICT,
    quantity_given  INT         NOT NULL CHECK (quantity_given > 0),
    dispensed_by    INT
                      REFERENCES clinic.users(user_id) ON DELETE SET NULL,
    dispensed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_consult_med_consultation ON clinic.consultation_medicines (consultation_id);
CREATE INDEX idx_consult_med_medicine     ON clinic.consultation_medicines (medicine_id);

COMMENT ON TABLE clinic.consultation_medicines IS 'Medicines dispensed per consultation — basic tracking (name + quantity)';

-- --------------------------------------------------------
-- 8. Health Clearances — Medical Certificates & Clearance Status
-- --------------------------------------------------------

CREATE TABLE clinic.health_clearances (
    clearance_id SERIAL       PRIMARY KEY,
    student_id   INT          NOT NULL
                   REFERENCES clinic.students(student_id) ON DELETE CASCADE,
    issued_by    INT
                   REFERENCES clinic.users(user_id) ON DELETE SET NULL,
    purpose      VARCHAR(100),
    remarks      TEXT,
    status       VARCHAR(20)  NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'cleared', 'not_cleared')),
    valid_until  DATE,
    requested_by INT
                   REFERENCES clinic.users(user_id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clearances_student  ON clinic.health_clearances (student_id);
CREATE INDEX idx_clearances_status   ON clinic.health_clearances (status);

COMMENT ON TABLE  clinic.health_clearances              IS 'Health clearances and medical certificates for students';
COMMENT ON COLUMN clinic.health_clearances.requested_by IS 'Faculty member who requested the clearance (if applicable)';
COMMENT ON COLUMN clinic.health_clearances.issued_by    IS 'Doctor or nurse who issued/evaluated the clearance';

-- --------------------------------------------------------
-- 9. Updated_at Trigger — Auto-update timestamps
-- --------------------------------------------------------

CREATE OR REPLACE FUNCTION clinic.fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to all tables with updated_at columns
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON clinic.users
    FOR EACH ROW EXECUTE FUNCTION clinic.fn_update_timestamp();

CREATE TRIGGER trg_students_updated_at
    BEFORE UPDATE ON clinic.students
    FOR EACH ROW EXECUTE FUNCTION clinic.fn_update_timestamp();

CREATE TRIGGER trg_consultations_updated_at
    BEFORE UPDATE ON clinic.consultations
    FOR EACH ROW EXECUTE FUNCTION clinic.fn_update_timestamp();

CREATE TRIGGER trg_clearances_updated_at
    BEFORE UPDATE ON clinic.health_clearances
    FOR EACH ROW EXECUTE FUNCTION clinic.fn_update_timestamp();

-- ============================================================================
-- Verification
-- ============================================================================
-- \dt clinic.*          -- List all tables in clinic schema
-- \d clinic.users       -- Describe users table
-- \di clinic.*          -- List all indexes
-- ============================================================================
