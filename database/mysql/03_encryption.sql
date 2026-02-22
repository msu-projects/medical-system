-- ============================================================================
-- 03_encryption.sql
-- School Clinic Management System — Encryption Helper Functions (MySQL)
-- ============================================================================
-- Run AFTER 02_tables.sql:
--   mysql -u root -p school_clinic < 03_encryption.sql
-- ============================================================================
-- SECURITY MODEL:
--   - Sensitive medical data (diagnosis, prescriptions, treatment notes) is
--     encrypted at rest using AES-256 via MySQL's built-in AES_ENCRYPT/DECRYPT.
--   - The encryption key is NEVER stored in the database.
--   - The application sets the key per-session using a user variable:
--       SET @app_encryption_key = 'your-secret-key';
--   - These helper functions wrap AES_ENCRYPT/DECRYPT for convenience
--     and enforce AES-256 cipher consistently.
--
-- IMPORTANT: MySQL must be configured with:
--   SET GLOBAL block_encryption_mode = 'aes-256-cbc';
-- or set it in my.cnf:
--   [mysqld]
--   block_encryption_mode = aes-256-cbc
-- ============================================================================

USE school_clinic;

-- --------------------------------------------------------
-- 0. Set encryption mode for this session
-- --------------------------------------------------------
-- AES-256-CBC requires a 32-byte key and uses a random IV for each encryption.
-- The IV is prepended to the ciphertext for decryption.

SET SESSION block_encryption_mode = 'aes-256-cbc';

-- --------------------------------------------------------
-- 1. Encrypt text → BLOB (AES-256-CBC)
-- --------------------------------------------------------
-- Usage: SELECT encrypt_data('sensitive text');
-- Requires: @app_encryption_key session variable to be set
-- The IV is randomly generated and prepended to the ciphertext.

DELIMITER //

CREATE FUNCTION encrypt_data(plain_text TEXT)
RETURNS BLOB
DETERMINISTIC
SQL SECURITY DEFINER
COMMENT 'Encrypts text using AES-256-CBC. Reads key from @app_encryption_key session variable. IV is prepended to ciphertext.'
BEGIN
    DECLARE enc_key TEXT;
    DECLARE iv BINARY(16);

    SET enc_key = @app_encryption_key;

    IF enc_key IS NULL OR enc_key = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Encryption key not set. Run: SET @app_encryption_key = ''your-key'';';
    END IF;

    IF plain_text IS NULL THEN
        RETURN NULL;
    END IF;

    -- Generate a random 16-byte IV
    SET iv = RANDOM_BYTES(16);

    -- Return IV + ciphertext (IV is needed for decryption)
    RETURN CONCAT(iv, AES_ENCRYPT(plain_text, enc_key, iv));
END //

-- --------------------------------------------------------
-- 2. Decrypt BLOB → TEXT
-- --------------------------------------------------------
-- Usage: SELECT decrypt_data(encrypted_column);
-- Requires: @app_encryption_key session variable to be set
-- Extracts the prepended IV and uses it for decryption.

CREATE FUNCTION decrypt_data(cipher_data BLOB)
RETURNS TEXT
DETERMINISTIC
SQL SECURITY DEFINER
COMMENT 'Decrypts AES-256-CBC encrypted data. Reads key from @app_encryption_key session variable. Expects IV prepended to ciphertext.'
BEGIN
    DECLARE enc_key TEXT;
    DECLARE iv BINARY(16);
    DECLARE encrypted_part BLOB;
    DECLARE decrypted TEXT;

    SET enc_key = @app_encryption_key;

    IF enc_key IS NULL OR enc_key = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Encryption key not set. Run: SET @app_encryption_key = ''your-key'';';
    END IF;

    IF cipher_data IS NULL THEN
        RETURN NULL;
    END IF;

    -- Extract IV (first 16 bytes) and ciphertext (remaining bytes)
    SET iv = LEFT(cipher_data, 16);
    SET encrypted_part = SUBSTRING(cipher_data, 17);

    SET decrypted = AES_DECRYPT(encrypted_part, enc_key, iv);

    IF decrypted IS NULL THEN
        RETURN '[DECRYPTION FAILED]';
    END IF;

    RETURN decrypted;
END //

-- --------------------------------------------------------
-- 3. Convenience: Encrypt & insert a consultation
-- --------------------------------------------------------
-- Wraps encryption so the caller doesn't need to remember the encrypt syntax.

CREATE PROCEDURE create_consultation(
    IN p_student_id      INT,
    IN p_attended_by     INT,
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
COMMENT 'Creates a consultation with auto-encrypted diagnosis and treatment notes.'
BEGIN
    SET SESSION block_encryption_mode = 'aes-256-cbc';

    INSERT INTO consultations (
        student_id, attended_by, chief_complaint,
        diagnosis, treatment_notes,
        vitals_bp, vitals_temp, vitals_pulse, vitals_weight
    ) VALUES (
        p_student_id,
        p_attended_by,
        p_chief_complaint,
        encrypt_data(p_diagnosis),
        encrypt_data(p_treatment_notes),
        p_vitals_bp,
        p_vitals_temp,
        p_vitals_pulse,
        p_vitals_weight
    );

    SET p_consultation_id = LAST_INSERT_ID();
END //

-- --------------------------------------------------------
-- 4. Convenience: Create a prescription (encrypted)
-- --------------------------------------------------------

CREATE PROCEDURE create_prescription(
    IN p_consultation_id      INT,
    IN p_prescribed_by        INT,
    IN p_prescription_details TEXT,
    IN p_notes                TEXT,
    OUT p_prescription_id     INT
)
SQL SECURITY DEFINER
COMMENT 'Creates a prescription with auto-encrypted details and notes.'
BEGIN
    SET SESSION block_encryption_mode = 'aes-256-cbc';

    INSERT INTO prescriptions (
        consultation_id, prescribed_by,
        prescription_details, notes
    ) VALUES (
        p_consultation_id,
        p_prescribed_by,
        encrypt_data(p_prescription_details),
        encrypt_data(p_notes)
    );

    SET p_prescription_id = LAST_INSERT_ID();
END //

DELIMITER ;

-- ============================================================================
-- HOW THE APPLICATION SHOULD USE ENCRYPTION
-- ============================================================================
--
-- 1. At the start of each database session/request, the application sets:
--
--      SET @app_encryption_key = 'your-256-bit-secret-key';
--      SET @app_current_user_id = 42;
--      SET @app_current_role = 'nurse';
--      SET SESSION block_encryption_mode = 'aes-256-cbc';
--
-- 2. To INSERT encrypted data, use the helper procedures:
--
--      CALL create_consultation(
--          1, 2,
--          'Headache and fever',
--          'Acute viral upper respiratory infection',
--          'Given Paracetamol 500mg. Advised rest.',
--          '120/80', 38.2, 88, 65.0,
--          @new_id
--      );
--      SELECT @new_id;
--
--    Or manually:
--      INSERT INTO consultations (student_id, attended_by, diagnosis)
--      VALUES (1, 2, encrypt_data('Migraine'));
--
-- 3. To READ decrypted data:
--
--      SELECT consultation_id,
--             decrypt_data(diagnosis)       AS diagnosis,
--             decrypt_data(treatment_notes) AS treatment_notes
--      FROM consultations
--      WHERE student_id = 1;
--
--    Or use the pre-built views (05_views.sql) which auto-decrypt.
--
-- 4. KEY MANAGEMENT:
--    - Store the encryption key in your application's secrets manager
--    - NEVER hardcode the key in SQL files or application source code
--    - Rotate keys periodically: decrypt all data with old key, re-encrypt with new
--    - ALWAYS use SSL/TLS connections — the key travels in plaintext between app and DB
--
-- ============================================================================
