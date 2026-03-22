-- ============================================================================
-- 07_audit.sql
-- School Clinic Management System — Audit Logging (Trigger-Based)
-- ============================================================================
-- Run AFTER 06_grants.sql:
--   psql -U postgres -d school_clinic_db -f 07_audit.sql
-- ============================================================================
-- AUDIT TRAIL captures every INSERT, UPDATE, and DELETE on clinical tables.
--
-- Design:
--   - Single generic audit table in the isolated 'audit' schema
--   - JSONB columns for old_data/new_data — works for any table schema
--   - SECURITY DEFINER trigger function — allows all roles to generate
--     audit entries without direct INSERT on the audit table
--   - Records app-level user identity (from session variable) + DB role
--   - Captures client IP address when available
--
-- Security:
--   - Only clinic_admin can SELECT from the audit table
--   - NO role can UPDATE or DELETE audit records (append-only)
--   - Audit table in separate schema prevents accidental access
-- ============================================================================

SET search_path TO clinic, public;

-- ============================================================================
-- 1. AUDIT TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit.activity_log (
    log_id        BIGSERIAL    PRIMARY KEY,
    table_schema  TEXT         NOT NULL,
    table_name    TEXT         NOT NULL,
    operation     TEXT         NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data      JSONB,       -- NULL for INSERT
    new_data      JSONB,       -- NULL for DELETE
    changed_fields TEXT[],     -- List of changed column names (UPDATE only)
    app_user_id   TEXT,        -- Application-level user ID (from session var)
    db_user       TEXT         NOT NULL DEFAULT current_user,
    db_role       TEXT         NOT NULL DEFAULT session_user,
    client_ip     TEXT,
    changed_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Index for common audit queries
CREATE INDEX IF NOT EXISTS idx_audit_table     ON audit.activity_log (table_schema, table_name);
CREATE INDEX IF NOT EXISTS idx_audit_operation ON audit.activity_log (operation);
CREATE INDEX IF NOT EXISTS idx_audit_user      ON audit.activity_log (app_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit.activity_log (changed_at);
CREATE INDEX IF NOT EXISTS idx_audit_composite ON audit.activity_log (table_name, changed_at DESC);

COMMENT ON TABLE  audit.activity_log             IS 'Immutable audit trail — every change to clinical data is logged here';
COMMENT ON COLUMN audit.activity_log.old_data     IS 'Previous row state as JSONB (NULL for INSERT)';
COMMENT ON COLUMN audit.activity_log.new_data     IS 'New row state as JSONB (NULL for DELETE)';
COMMENT ON COLUMN audit.activity_log.changed_fields IS 'Column names that changed (UPDATE only) — for quick change discovery';
COMMENT ON COLUMN audit.activity_log.app_user_id  IS 'Application user ID from set_config(app.current_user_id) — may differ from db_user';
COMMENT ON COLUMN audit.activity_log.client_ip    IS 'Client IP address from inet_client_addr() — NULL for local connections';

-- ============================================================================
-- 2. AUDIT TRIGGER FUNCTION (Generic — works for any table)
-- ============================================================================

CREATE OR REPLACE FUNCTION audit.fn_audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    old_json    JSONB := NULL;
    new_json    JSONB := NULL;
    changed     TEXT[] := NULL;
    app_uid     TEXT;
BEGIN
    -- Get application-level user identity (set by the app per-transaction)
    app_uid := current_setting('app.current_user_id', true);  -- missing_ok = true

    -- Build JSONB representations
    IF TG_OP = 'DELETE' THEN
        old_json := to_jsonb(OLD);

    ELSIF TG_OP = 'INSERT' THEN
        new_json := to_jsonb(NEW);

    ELSIF TG_OP = 'UPDATE' THEN
        old_json := to_jsonb(OLD);
        new_json := to_jsonb(NEW);

        -- Compute list of changed columns
        changed := ARRAY(
            SELECT key
            FROM jsonb_each(old_json) AS o(key, value)
            WHERE NOT (new_json ? key AND new_json->key IS NOT DISTINCT FROM o.value)
            UNION
            SELECT key
            FROM jsonb_each(new_json) AS n(key, value)
            WHERE NOT (old_json ? key AND old_json->key IS NOT DISTINCT FROM n.value)
        );

        -- Skip audit if nothing actually changed
        IF array_length(changed, 1) IS NULL THEN
            RETURN NULL;
        END IF;
    END IF;

    -- Insert audit record
    INSERT INTO audit.activity_log (
        table_schema,
        table_name,
        operation,
        old_data,
        new_data,
        changed_fields,
        app_user_id,
        db_user,
        db_role,
        client_ip
    ) VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP,
        old_json,
        new_json,
        changed,
        app_uid,
        current_user,
        session_user,
        inet_client_addr()::TEXT
    );

    -- AFTER trigger — return value is ignored, but convention is:
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, audit, clinic;

COMMENT ON FUNCTION audit.fn_audit_trigger() IS
    'Generic audit trigger — logs INSERT/UPDATE/DELETE with before/after state as JSONB. SECURITY DEFINER allows all roles to generate audit entries.';

-- ============================================================================
-- 3. ATTACH AUDIT TRIGGERS TO ALL CLINICAL TABLES
-- ============================================================================
-- Using AFTER triggers so we audit what actually happened (post-constraint checks).

-- clinic.users
DROP TRIGGER IF EXISTS trg_audit_users ON clinic.users;
CREATE TRIGGER trg_audit_users
    AFTER INSERT OR UPDATE OR DELETE ON clinic.users
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- clinic.students
DROP TRIGGER IF EXISTS trg_audit_students ON clinic.students;
CREATE TRIGGER trg_audit_students
    AFTER INSERT OR UPDATE OR DELETE ON clinic.students
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- clinic.qr_codes
DROP TRIGGER IF EXISTS trg_audit_qr_codes ON clinic.qr_codes;
CREATE TRIGGER trg_audit_qr_codes
    AFTER INSERT OR UPDATE OR DELETE ON clinic.qr_codes
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- clinic.consultations
DROP TRIGGER IF EXISTS trg_audit_consultations ON clinic.consultations;
CREATE TRIGGER trg_audit_consultations
    AFTER INSERT OR UPDATE OR DELETE ON clinic.consultations
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- clinic.prescriptions
DROP TRIGGER IF EXISTS trg_audit_prescriptions ON clinic.prescriptions;
CREATE TRIGGER trg_audit_prescriptions
    AFTER INSERT OR UPDATE OR DELETE ON clinic.prescriptions
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- clinic.medicines
DROP TRIGGER IF EXISTS trg_audit_medicines ON clinic.medicines;
CREATE TRIGGER trg_audit_medicines
    AFTER INSERT OR UPDATE OR DELETE ON clinic.medicines
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- clinic.consultation_medicines
DROP TRIGGER IF EXISTS trg_audit_consultation_medicines ON clinic.consultation_medicines;
CREATE TRIGGER trg_audit_consultation_medicines
    AFTER INSERT OR UPDATE OR DELETE ON clinic.consultation_medicines
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- clinic.health_clearances
DROP TRIGGER IF EXISTS trg_audit_health_clearances ON clinic.health_clearances;
CREATE TRIGGER trg_audit_health_clearances
    AFTER INSERT OR UPDATE OR DELETE ON clinic.health_clearances
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

-- ============================================================================
-- 4. AUDIT TABLE SECURITY
-- ============================================================================
-- The audit log is APPEND-ONLY. No role should be able to modify or delete
-- audit records. Only clinic_admin can read the audit trail.

-- Revoke everything from everyone
REVOKE ALL ON audit.activity_log FROM PUBLIC;
REVOKE ALL ON SCHEMA audit FROM PUBLIC;

-- Grant schema usage to admin only
GRANT USAGE ON SCHEMA audit TO clinic_admin;

-- Admin: can only READ audit records (no UPDATE, no DELETE)
GRANT SELECT ON audit.activity_log TO clinic_admin;

-- The trigger function is SECURITY DEFINER (runs as the function owner,
-- typically postgres), so it can INSERT into audit.activity_log regardless
-- of the calling role's permissions. This is intentional — we want every
-- role's actions to be audited, but no role should be able to write
-- arbitrary entries or tamper with existing records.

-- Grant sequence usage for the trigger function's INSERTs
GRANT USAGE ON SEQUENCE audit.activity_log_log_id_seq TO clinic_admin;
-- The SECURITY DEFINER function runs as owner (postgres), which has
-- implicit access to the sequence, so no additional grants needed for
-- other roles — the trigger handles everything.

-- ============================================================================
-- 5. HELPER VIEWS FOR AUDIT QUERIES
-- ============================================================================

-- Recent activity view — admin-only
CREATE OR REPLACE VIEW audit.v_recent_activity AS
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
    audit.activity_log
ORDER BY
    changed_at DESC
LIMIT 100;

GRANT SELECT ON audit.v_recent_activity TO clinic_admin;

COMMENT ON VIEW audit.v_recent_activity IS
    'Last 100 audit entries — quick overview for admin dashboard';

-- Medical record access log — who accessed/modified patient data
CREATE OR REPLACE VIEW audit.v_medical_record_access AS
SELECT
    log_id,
    table_name,
    operation,
    app_user_id,
    db_user,
    CASE
        WHEN operation = 'INSERT' THEN new_data->>'student_id'
        WHEN operation = 'DELETE' THEN old_data->>'student_id'
        ELSE COALESCE(new_data->>'student_id', old_data->>'student_id')
    END AS affected_student_id,
    changed_fields,
    changed_at,
    client_ip
FROM
    audit.activity_log
WHERE
    table_name IN ('consultations', 'prescriptions', 'consultation_medicines', 'health_clearances')
ORDER BY
    changed_at DESC;

GRANT SELECT ON audit.v_medical_record_access TO clinic_admin;

COMMENT ON VIEW audit.v_medical_record_access IS
    'Audit trail filtered to medical record access — useful for compliance reviews';

-- ============================================================================
-- Verification
-- ============================================================================
-- 1. Make a change and check the audit log:
--
--   SELECT set_config('app.current_user_id', '1', true);
--   UPDATE clinic.users SET is_active = FALSE WHERE user_id = 99;
--   SELECT * FROM audit.activity_log ORDER BY log_id DESC LIMIT 5;
--
-- 2. Verify immutability:
--
--   SET ROLE clinic_nurse;
--   DELETE FROM audit.activity_log WHERE log_id = 1;  -- ERROR: permission denied
--   UPDATE audit.activity_log SET operation = 'INSERT' WHERE log_id = 1;  -- ERROR
--   RESET ROLE;
--
-- 3. Verify admin can read:
--
--   SET ROLE clinic_admin;
--   SELECT * FROM audit.v_recent_activity;  -- OK
--   SELECT * FROM audit.v_medical_record_access;  -- OK
--   RESET ROLE;
-- ============================================================================
