-- ============================================================================
-- 03_encryption.sql
-- School Clinic Management System — Encryption Helper Functions
-- ============================================================================
-- Run AFTER 02_tables.sql:
--   psql -U postgres -d school_clinic_db -f 03_encryption.sql
-- ============================================================================
-- SECURITY MODEL:
--   - Sensitive medical data (diagnosis, prescriptions, treatment notes) is
--     encrypted at rest using AES-256 via pgcrypto's PGP symmetric encryption.
--   - The encryption key is NEVER stored in the database.
--   - The application sets the key per-session/transaction:
--       SELECT set_config('app.encryption_key', 'your-secret-key', true);
--     The third parameter (true) makes it transaction-local, so the key is
--     automatically cleared when the transaction ends — critical for
--     connection-pooled environments.
--   - These helper functions wrap pgp_sym_encrypt/decrypt for convenience
--     and enforce AES-256 cipher algorithm consistently.
-- ============================================================================

SET search_path TO clinic, public;

-- --------------------------------------------------------
-- 1. Encrypt text → BYTEA (AES-256)
-- --------------------------------------------------------
-- Usage: clinic.encrypt_data('sensitive text')
-- Requires: app.encryption_key session variable to be set

CREATE OR REPLACE FUNCTION clinic.encrypt_data(plain_text TEXT)
RETURNS BYTEA AS $$
DECLARE
    enc_key TEXT;
BEGIN
    -- Retrieve encryption key from session variable
    enc_key := current_setting('app.encryption_key', true);

    IF enc_key IS NULL OR enc_key = '' THEN
        RAISE EXCEPTION 'Encryption key not set. Call: SELECT set_config(''app.encryption_key'', ''your-key'', true);';
    END IF;

    IF plain_text IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN public.pgp_sym_encrypt(
        plain_text,
        enc_key,
        'cipher-algo=aes256, compress-algo=0'
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION clinic.encrypt_data(TEXT) IS
    'Encrypts text using AES-256 PGP symmetric encryption. Reads key from app.encryption_key session variable.';

-- --------------------------------------------------------
-- 2. Decrypt BYTEA → TEXT
-- --------------------------------------------------------
-- Usage: clinic.decrypt_data(encrypted_column)
-- Requires: app.encryption_key session variable to be set
-- Returns NULL if decryption fails (wrong key) rather than raising an error.

CREATE OR REPLACE FUNCTION clinic.decrypt_data(cipher_data BYTEA)
RETURNS TEXT AS $$
DECLARE
    enc_key TEXT;
    decrypted TEXT;
BEGIN
    -- Retrieve encryption key from session variable
    enc_key := current_setting('app.encryption_key', true);

    IF enc_key IS NULL OR enc_key = '' THEN
        RAISE EXCEPTION 'Encryption key not set. Call: SELECT set_config(''app.encryption_key'', ''your-key'', true);';
    END IF;

    IF cipher_data IS NULL THEN
        RETURN NULL;
    END IF;

    BEGIN
        decrypted := public.pgp_sym_decrypt(cipher_data, enc_key);
        RETURN decrypted;
    EXCEPTION
        WHEN external_routine_invocation_exception THEN
            -- Wrong key or corrupted data — return placeholder
            RAISE WARNING 'Decryption failed — possible key mismatch';
            RETURN '[DECRYPTION FAILED]';
    END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION clinic.decrypt_data(BYTEA) IS
    'Decrypts AES-256 PGP encrypted data. Reads key from app.encryption_key session variable. Returns [DECRYPTION FAILED] on key mismatch.';

-- --------------------------------------------------------
-- 3. Convenience: Encrypt & insert a consultation
-- --------------------------------------------------------
-- Wraps encryption so the caller doesn't need to remember the encrypt syntax.
-- Usage:
--   SELECT clinic.create_consultation(
--       p_student_number := 2000-1000,
--       p_attended_by := 2,
--       p_chief_complaint := 'Headache and fever',
--       p_diagnosis := 'Acute viral upper respiratory infection',
--       p_treatment_notes := 'Advised rest, given paracetamol',
--       p_vitals_bp := '120/80',
--       p_vitals_temp := 38.2,
--       p_vitals_pulse := 88,
--       p_vitals_weight := 65.0
--   );

CREATE OR REPLACE FUNCTION clinic.create_consultation(
    p_student_number  VARCHAR(20),
    p_attended_by     INT,
    p_chief_complaint TEXT DEFAULT NULL,
    p_diagnosis       TEXT DEFAULT '',
    p_treatment_notes TEXT DEFAULT NULL,
    p_vitals_bp       VARCHAR(10) DEFAULT NULL,
    p_vitals_temp     DECIMAL(4,1) DEFAULT NULL,
    p_vitals_pulse    INT DEFAULT NULL,
    p_vitals_weight   DECIMAL(5,1) DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    new_id INT;
BEGIN
    INSERT INTO clinic.consultations (
        student_number, attended_by, chief_complaint,
        diagnosis, treatment_notes,
        vitals_bp, vitals_temp, vitals_pulse, vitals_weight
    ) VALUES (
        p_student_number,
        p_attended_by,
        p_chief_complaint,
        clinic.encrypt_data(p_diagnosis),
        clinic.encrypt_data(p_treatment_notes),
        p_vitals_bp,
        p_vitals_temp,
        p_vitals_pulse,
        p_vitals_weight
    )
    RETURNING consultation_id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION clinic.create_consultation IS
    'Creates a consultation with auto-encrypted diagnosis and treatment notes.';

-- --------------------------------------------------------
-- 4. Convenience: Create a prescription (encrypted)
-- --------------------------------------------------------

CREATE OR REPLACE FUNCTION clinic.create_prescription(
    p_consultation_id      INT,
    p_prescribed_by        INT,
    p_prescription_details TEXT,
    p_notes                TEXT DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    new_id INT;
BEGIN
    INSERT INTO clinic.prescriptions (
        consultation_id, prescribed_by,
        prescription_details, notes
    ) VALUES (
        p_consultation_id,
        p_prescribed_by,
        clinic.encrypt_data(p_prescription_details),
        clinic.encrypt_data(p_notes)
    )
    RETURNING prescription_id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION clinic.create_prescription IS
    'Creates a prescription with auto-encrypted details and notes.';

-- ============================================================================
-- HOW THE APPLICATION SHOULD USE ENCRYPTION
-- ============================================================================
--
-- 1. At the start of each database transaction, the application sets:
--
--      SELECT set_config('app.encryption_key', 'your-256-bit-secret-key', true);
--      SELECT set_config('app.current_user_id', '42', true);
--
--    The 'true' parameter makes these transaction-local (auto-cleared on commit/rollback).
--
-- 2. To INSERT encrypted data, use the helper functions:
--
--      SELECT clinic.create_consultation(
--          p_student_number := 2000-2000,
--          p_attended_by := 2,
--          p_diagnosis := 'Migraine',
--          p_treatment_notes := 'Given ibuprofen 200mg'
--      );
--
--    Or manually:
--      INSERT INTO clinic.consultations (student_number, attended_by, diagnosis)
--      VALUES (1, 2, clinic.encrypt_data('Migraine'));
--
-- 3. To READ decrypted data:
--
--      SELECT consultation_id,
--             clinic.decrypt_data(diagnosis) AS diagnosis,
--             clinic.decrypt_data(treatment_notes) AS treatment_notes
--      FROM clinic.consultations
--      WHERE student_number = '2000-2000';
--
--    Or use the pre-built views (05_views.sql) which auto-decrypt.
--
-- 4. KEY MANAGEMENT:
--    - Store the encryption key in your application's secrets manager
--      (e.g., environment variable, HashiCorp Vault, AWS Secrets Manager)
--    - NEVER hardcode the key in SQL files or application source code
--    - Rotate keys periodically: decrypt all data with old key, re-encrypt with new key
--    - ALWAYS use SSL/TLS connections — the key travels in plaintext between app and DB
--
-- ============================================================================
