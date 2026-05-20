-- ============================================================================
-- 10_auth_helpers.sql
-- School Clinic Management System — Login & Session Helper Functions (PostgreSQL)
-- ============================================================================
-- Run AFTER 06_grants.sql:
--   psql -U postgres -d school_clinic_db -f 10_auth_helpers.sql
-- ============================================================================
-- Password verification stays in the application layer because password_hash
-- contains bcrypt output. These helpers only expose active login metadata,
-- create/revoke hashed-token sessions, and set per-connection app context.
-- Raw session tokens/JWTs must never be passed here; pass SHA-256 hashes only.
-- ============================================================================

SET search_path TO clinic, public;

CREATE OR REPLACE FUNCTION clinic.auth_get_login_user(p_username VARCHAR(50))
RETURNS TABLE (
    user_id INT,
    username VARCHAR(50),
    password_hash VARCHAR(255),
    email VARCHAR(100),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(20),
    last_login TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
    SELECT
        u.user_id,
        u.username,
        u.password_hash,
        u.email,
        u.first_name,
        u.last_name,
        u.role,
        u.last_login
    FROM clinic.users u
    WHERE u.username = p_username
      AND u.is_active = TRUE
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION clinic.auth_create_session(
    p_user_id INT,
    p_session_token_hash CHAR(64),
    p_expires_at TIMESTAMPTZ,
    p_ip_address INET DEFAULT NULL,
    p_user_agent VARCHAR(255) DEFAULT NULL
)
RETURNS TABLE (
    session_id BIGINT,
    user_id INT,
    role VARCHAR(20),
    expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_role VARCHAR(20);
    v_session_id BIGINT;
BEGIN
    SELECT u.role
      INTO v_role
    FROM clinic.users u
    WHERE u.user_id = p_user_id
      AND u.is_active = TRUE
    LIMIT 1;

    IF v_role IS NULL THEN
        RAISE EXCEPTION 'Cannot create session for missing or inactive user.';
    END IF;

    INSERT INTO clinic.user_session (
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
        NOW(),
        p_ip_address,
        p_user_agent
    )
    RETURNING user_session.session_id INTO v_session_id;

    UPDATE clinic.users
    SET last_login = NOW()
    WHERE users.user_id = p_user_id;

    PERFORM set_config('app.current_user_id', p_user_id::TEXT, FALSE);
    PERFORM set_config('app.current_role', v_role, FALSE);

    RETURN QUERY
    SELECT v_session_id, p_user_id, v_role, p_expires_at;
END;
$$;

CREATE OR REPLACE FUNCTION clinic.auth_touch_session(p_session_token_hash CHAR(64))
RETURNS TABLE (
    user_id INT,
    username VARCHAR(50),
    email VARCHAR(100),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(20),
    session_id BIGINT,
    expires_at TIMESTAMPTZ,
    last_seen_at TIMESTAMPTZ
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_user_id INT;
    v_role VARCHAR(20);
BEGIN
    SELECT s.user_id, s.role
      INTO v_user_id, v_role
    FROM clinic.user_session s
    JOIN clinic.users u ON u.user_id = s.user_id
    WHERE s.session_token_hash = p_session_token_hash
      AND s.revoked_at IS NULL
      AND s.expires_at > NOW()
      AND u.is_active = TRUE
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Invalid, expired, revoked, or inactive session.';
    END IF;

    UPDATE clinic.user_session s
    SET last_seen_at = NOW()
    WHERE s.session_token_hash = p_session_token_hash;

    PERFORM set_config('app.current_user_id', v_user_id::TEXT, FALSE);
    PERFORM set_config('app.current_role', v_role, FALSE);

    RETURN QUERY
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
    FROM clinic.user_session s
    JOIN clinic.users u ON u.user_id = s.user_id
    WHERE s.session_token_hash = p_session_token_hash
    LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION clinic.auth_revoke_session(p_session_token_hash CHAR(64))
RETURNS INT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_affected_rows INT;
BEGIN
    UPDATE clinic.user_session s
    SET revoked_at = COALESCE(s.revoked_at, NOW())
    WHERE s.session_token_hash = p_session_token_hash;

    GET DIAGNOSTICS v_affected_rows = ROW_COUNT;

    PERFORM set_config('app.current_user_id', '', FALSE);
    PERFORM set_config('app.current_role', '', FALSE);

    RETURN v_affected_rows;
END;
$$;

GRANT EXECUTE ON FUNCTION clinic.auth_get_login_user(VARCHAR(50)) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.auth_create_session(INT, CHAR(64), TIMESTAMPTZ, INET, VARCHAR(255)) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.auth_touch_session(CHAR(64)) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.auth_revoke_session(CHAR(64)) TO clinic_app;

COMMENT ON FUNCTION clinic.auth_get_login_user(VARCHAR(50)) IS
    'Returns active user login metadata, including password_hash for application bcrypt verification.';
COMMENT ON FUNCTION clinic.auth_create_session(INT, CHAR(64), TIMESTAMPTZ, INET, VARCHAR(255)) IS
    'Creates a login session after successful application password verification and sets app session context.';
COMMENT ON FUNCTION clinic.auth_touch_session(CHAR(64)) IS
    'Validates a non-revoked session, updates last_seen_at, sets app context, and returns user metadata.';
COMMENT ON FUNCTION clinic.auth_revoke_session(CHAR(64)) IS
    'Revokes one session by hashed token and clears app context.';

-- ============================================================================
-- Suggested login flow:
--   1. SELECT * FROM clinic.auth_get_login_user('alice');             -- app verifies bcrypt
--   2. SELECT * FROM clinic.auth_create_session(...);                 -- app stores raw token client-side only
--   3. SELECT * FROM clinic.auth_touch_session(digest raw token hex); -- each request
--   4. SELECT clinic.auth_revoke_session(digest raw token hex);       -- logout
-- ============================================================================
