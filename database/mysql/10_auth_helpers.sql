-- ============================================================================
-- 10_auth_helpers.sql
-- School Clinic Management System — Login & Session Helper Procedures (MySQL)
-- ============================================================================
-- Run AFTER 06_grants.sql:
--   mysql -u root -p school_clinic < 10_auth_helpers.sql
-- ============================================================================
-- Password verification stays in the application layer because password_hash
-- contains bcrypt output. These helpers only expose active login metadata,
-- create/revoke hashed-token sessions, and set per-connection app context.
-- Raw session tokens/JWTs must never be passed here; pass SHA-256 hashes only.
-- ============================================================================

USE school_clinic;

DELIMITER //

DROP PROCEDURE IF EXISTS auth_get_login_user //
CREATE PROCEDURE auth_get_login_user(
    IN p_username VARCHAR(50)
)
SQL SECURITY DEFINER
COMMENT 'Returns active user login metadata, including password_hash for application bcrypt verification.'
BEGIN
    SELECT
        user_id,
        username,
        password_hash,
        email,
        first_name,
        last_name,
        role,
        last_login
    FROM users
    WHERE username = p_username
      AND is_active = TRUE
    LIMIT 1;
END //

DROP PROCEDURE IF EXISTS auth_create_session //
CREATE PROCEDURE auth_create_session(
    IN p_user_id INT,
    IN p_session_token_hash CHAR(64),
    IN p_expires_at TIMESTAMP,
    IN p_ip_address VARCHAR(45),
    IN p_user_agent VARCHAR(255)
)
SQL SECURITY DEFINER
COMMENT 'Creates a login session after successful application password verification and sets app session context.'
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_session_id BIGINT;

    SELECT role INTO v_role
    FROM users
    WHERE user_id = p_user_id
      AND is_active = TRUE
    LIMIT 1;

    IF v_role IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot create session for missing or inactive user.';
    END IF;

    INSERT INTO user_session (
        user_id,
        session_token_hash,
        role,
        expires_at,
        last_seen_at,
        ip_address,
        user_agent
    )
    VALUES (
        p_user_id,
        p_session_token_hash,
        v_role,
        p_expires_at,
        CURRENT_TIMESTAMP,
        p_ip_address,
        p_user_agent
    );

    SET v_session_id = LAST_INSERT_ID();

    UPDATE users
    SET last_login = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;

    SET @app_current_user_id = p_user_id;
    SET @app_current_role = v_role;

    SELECT
        v_session_id AS session_id,
        p_user_id AS user_id,
        v_role AS role,
        p_expires_at AS expires_at;
END //

DROP PROCEDURE IF EXISTS auth_touch_session //
CREATE PROCEDURE auth_touch_session(
    IN p_session_token_hash CHAR(64)
)
SQL SECURITY DEFINER
COMMENT 'Validates a non-revoked session, updates last_seen_at, sets app context, and returns user metadata.'
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
        u.email,
        u.first_name,
        u.last_name,
        u.role,
        s.session_id,
        s.expires_at,
        s.last_seen_at
    FROM user_session s
    JOIN users u ON u.user_id = s.user_id
    WHERE s.session_token_hash = p_session_token_hash
    LIMIT 1;
END //

DROP PROCEDURE IF EXISTS auth_revoke_session //
CREATE PROCEDURE auth_revoke_session(
    IN p_session_token_hash CHAR(64)
)
SQL SECURITY DEFINER
COMMENT 'Revokes one active session by hashed token and clears app context when it belongs to current session user.'
BEGIN
    UPDATE user_session
    SET revoked_at = COALESCE(revoked_at, CURRENT_TIMESTAMP)
    WHERE session_token_hash = p_session_token_hash;

    SET @app_current_user_id = NULL;
    SET @app_current_role = NULL;

    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;

GRANT EXECUTE ON PROCEDURE school_clinic.auth_get_login_user TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.auth_create_session TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.auth_touch_session TO 'clinic_app'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.auth_revoke_session TO 'clinic_app'@'%';

-- ============================================================================
-- Suggested login flow:
--   1. CALL auth_get_login_user('alice');             -- app verifies bcrypt
--   2. CALL auth_create_session(...);                 -- app stores raw token client-side only
--   3. CALL auth_touch_session(SHA2(raw_token, 256)); -- each request
--   4. CALL auth_revoke_session(SHA2(raw_token, 256));-- logout
-- ============================================================================
