-- ============================================================================
-- 04_rls_policies.sql
-- School Clinic Management System — Row-Level Security Policies
-- ============================================================================
-- Run AFTER 03_encryption.sql:
--   psql -U postgres -d school_clinic_db -f 04_rls_policies.sql
-- ============================================================================
-- ROW-LEVEL SECURITY (RLS) ensures that each role can only see/modify
-- the rows they are authorized to access, even if they have SELECT/INSERT
-- grants on the table.
--
-- The application MUST set these session variables per-transaction:
--   SELECT set_config('app.current_user_id', '<user_id>', true);
--   SELECT set_config('app.current_role', '<role_name>', true);
--
-- 'true' = transaction-local (auto-cleared on commit/rollback)
-- ============================================================================

SET search_path TO clinic, public;

-- --------------------------------------------------------
-- Helper function: Get current app user_id safely
-- --------------------------------------------------------
CREATE OR REPLACE FUNCTION clinic.current_app_user_id()
RETURNS INT AS $$
BEGIN
    return NULLIF(current_setting('app.current_user_id', true), '')::INT;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, clinic;

ALTER FUNCTION clinic.current_app_user_id() OWNER TO clinic_rls_owner;
GRANT SELECT ON clinic.users TO clinic_rls_owner;

COMMENT ON FUNCTION clinic.current_app_user_id() IS
    'Returns the current application user_id from session variable, or NULL if not set.';

-- Helper function: Get current app role safely
CREATE OR REPLACE FUNCTION clinic.current_app_role()
RETURNS TEXT AS $$
BEGIN
    return NULLIF(current_setting('app.current_user_id', true), '')::INT;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, clinic;

ALTER FUNCTION clinic.current_app_role() OWNER TO clinic_rls_owner;

-- Helper function: Get student_number for current user
CREATE OR REPLACE FUNCTION clinic.current_student_number()
RETURNS VARCHAR(20) AS $$
DECLARE
    sid VARCHAR(20);
BEGIN
    SELECT student_number INTO sid
    FROM clinic.students
    WHERE user_id = clinic.current_app_user_id();
    RETURN sid;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, clinic;

ALTER FUNCTION clinic.current_student_number() OWNER TO clinic_rls_owner;
GRANT SELECT ON clinic.students TO clinic_rls_owner;

-- ============================================================================
-- ENABLE RLS ON ALL CLINICAL TABLES
-- ============================================================================
-- FORCE ensures even table owners are subject to RLS during normal queries.

ALTER TABLE clinic.users                ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic.students             ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic.consultations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic.prescriptions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic.consultation_medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic.health_clearances    ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic.qr_codes            ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic.medicines            ENABLE ROW LEVEL SECURITY;

ALTER TABLE clinic.users                FORCE ROW LEVEL SECURITY;
ALTER TABLE clinic.students             FORCE ROW LEVEL SECURITY;
ALTER TABLE clinic.consultations        FORCE ROW LEVEL SECURITY;
ALTER TABLE clinic.prescriptions        FORCE ROW LEVEL SECURITY;
ALTER TABLE clinic.consultation_medicines FORCE ROW LEVEL SECURITY;
ALTER TABLE clinic.health_clearances    FORCE ROW LEVEL SECURITY;
ALTER TABLE clinic.qr_codes            FORCE ROW LEVEL SECURITY;
ALTER TABLE clinic.medicines            FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICIES: clinic.users
-- ============================================================================

-- Admin: full access to all user records
CREATE POLICY admin_all_users ON clinic.users
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Doctor/Nurse: can see all users (needed for lookups)
CREATE POLICY staff_read_users ON clinic.users
    FOR SELECT
    TO clinic_doctor, clinic_nurse
    USING (true);

-- Internal trigger owner: needs read access for role-enforcement lookups
CREATE POLICY trigger_owner_read_users ON clinic.users
    FOR SELECT
    TO clinic_trigger_owner
    USING (true);

-- Student: can only see their own user record
CREATE POLICY student_own_user ON clinic.users
    FOR SELECT
    TO clinic_student
    USING (user_id = clinic.current_app_user_id());

-- Student: can also see minimal staff/doctor identities tied to their own records
-- so student-facing history views can show attended/prescribed names.
CREATE POLICY student_related_staff_user ON clinic.users
    FOR SELECT
    TO clinic_student
    USING (
        role IN ('doctor', 'nurse')
        AND (
            user_id IN (
                SELECT c.attended_by
                FROM clinic.consultations c
                WHERE c.student_number = clinic.current_student_number()
            )
            OR user_id IN (
                SELECT p.prescribed_by
                FROM clinic.prescriptions p
                JOIN clinic.consultations c
                  ON c.consultation_id = p.consultation_id
                WHERE c.student_number = clinic.current_student_number()
            )
        )
    );

-- Faculty: can only see their own user record
CREATE POLICY faculty_own_user ON clinic.users
    FOR SELECT
    TO clinic_faculty
    USING (user_id = clinic.current_app_user_id());

-- ============================================================================
-- POLICIES: clinic.students
-- ============================================================================

-- Admin: full access
CREATE POLICY admin_all_students ON clinic.students
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Doctor: can view all student profiles
CREATE POLICY doctor_read_students ON clinic.students
    FOR SELECT
    TO clinic_doctor
    USING (true);

-- Nurse: can view and update student profiles (e.g., update allergies)
CREATE POLICY nurse_manage_students ON clinic.students
    FOR ALL
    TO clinic_nurse
    USING (true)
    WITH CHECK (true);

-- Student: can only see their own profile
CREATE POLICY student_own_profile ON clinic.students
    FOR SELECT
    TO clinic_student
    USING (user_id = clinic.current_app_user_id());

-- ============================================================================
-- POLICIES: clinic.consultations
-- ============================================================================

-- Admin: full access
CREATE POLICY admin_all_consultations ON clinic.consultations
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Doctor: can view all consultations, update ones they attend
CREATE POLICY doctor_read_consultations ON clinic.consultations
    FOR SELECT
    TO clinic_doctor
    USING (true);

CREATE POLICY doctor_update_consultations ON clinic.consultations
    FOR UPDATE
    TO clinic_doctor
    USING (attended_by = clinic.current_app_user_id())
    WITH CHECK (attended_by = clinic.current_app_user_id());

-- Nurse: can view all, create new, update ones they attend
CREATE POLICY nurse_read_consultations ON clinic.consultations
    FOR SELECT
    TO clinic_nurse
    USING (true);

CREATE POLICY nurse_insert_consultations ON clinic.consultations
    FOR INSERT
    TO clinic_nurse
    WITH CHECK (attended_by = clinic.current_app_user_id());

CREATE POLICY nurse_update_consultations ON clinic.consultations
    FOR UPDATE
    TO clinic_nurse
    USING (attended_by = clinic.current_app_user_id())
    WITH CHECK (attended_by = clinic.current_app_user_id());

-- Student: can only see their own consultations
CREATE POLICY student_own_consultations ON clinic.consultations
    FOR SELECT
    TO clinic_student
    USING (student_number = clinic.current_student_number());

-- ============================================================================
-- POLICIES: clinic.prescriptions
-- ============================================================================

-- Admin: full access
CREATE POLICY admin_all_prescriptions ON clinic.prescriptions
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Doctor: can view all, create and update their own prescriptions
CREATE POLICY doctor_read_prescriptions ON clinic.prescriptions
    FOR SELECT
    TO clinic_doctor
    USING (true);

CREATE POLICY doctor_insert_prescriptions ON clinic.prescriptions
    FOR INSERT
    TO clinic_doctor
    WITH CHECK (prescribed_by = clinic.current_app_user_id());

CREATE POLICY doctor_update_prescriptions ON clinic.prescriptions
    FOR UPDATE
    TO clinic_doctor
    USING (prescribed_by = clinic.current_app_user_id())
    WITH CHECK (prescribed_by = clinic.current_app_user_id());

-- Nurse: can view prescriptions (to know what was prescribed)
CREATE POLICY nurse_read_prescriptions ON clinic.prescriptions
    FOR SELECT
    TO clinic_nurse
    USING (true);

-- Student: can only see prescriptions for their own consultations
CREATE POLICY student_own_prescriptions ON clinic.prescriptions
    FOR SELECT
    TO clinic_student
    USING (
        consultation_id IN (
            SELECT consultation_id
            FROM clinic.consultations
            WHERE student_number = clinic.current_student_number()
        )
    );

-- ============================================================================
-- POLICIES: clinic.consultation_medicines
-- ============================================================================

-- Admin: full access
CREATE POLICY admin_all_consult_meds ON clinic.consultation_medicines
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Doctor: can view
CREATE POLICY doctor_read_consult_meds ON clinic.consultation_medicines
    FOR SELECT
    TO clinic_doctor
    USING (true);

-- Nurse: can view and dispense medicines
CREATE POLICY nurse_manage_consult_meds ON clinic.consultation_medicines
    FOR ALL
    TO clinic_nurse
    USING (true)
    WITH CHECK (true);

-- Student: can see medicines dispensed in their own consultations
CREATE POLICY student_own_consult_meds ON clinic.consultation_medicines
    FOR SELECT
    TO clinic_student
    USING (
        consultation_id IN (
            SELECT consultation_id
            FROM clinic.consultations
            WHERE student_number = clinic.current_student_number()
        )
    );

-- ============================================================================
-- POLICIES: clinic.health_clearances
-- ============================================================================

-- Admin: full access
CREATE POLICY admin_all_clearances ON clinic.health_clearances
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Doctor: can view all, create and update clearances they issue
CREATE POLICY doctor_read_clearances ON clinic.health_clearances
    FOR SELECT
    TO clinic_doctor
    USING (true);

CREATE POLICY doctor_manage_clearances ON clinic.health_clearances
    FOR INSERT
    TO clinic_doctor
    WITH CHECK (issued_by = clinic.current_app_user_id());

CREATE POLICY doctor_update_clearances ON clinic.health_clearances
    FOR UPDATE
    TO clinic_doctor
    USING (issued_by = clinic.current_app_user_id())
    WITH CHECK (issued_by = clinic.current_app_user_id());

-- Nurse: can view all, create and update clearances
CREATE POLICY nurse_manage_clearances ON clinic.health_clearances
    FOR ALL
    TO clinic_nurse
    USING (true)
    WITH CHECK (true);

-- Student: can see their own clearances
CREATE POLICY student_own_clearances ON clinic.health_clearances
    FOR SELECT
    TO clinic_student
    USING (student_number = clinic.current_student_number());

-- Faculty: can see clearances they requested OR that are finalized
CREATE POLICY faculty_view_clearances ON clinic.health_clearances
    FOR SELECT
    TO clinic_faculty
    USING (
        requested_by = clinic.current_app_user_id()
        OR status IN ('cleared', 'not_cleared')
    );

-- Faculty: can request a new clearance
CREATE POLICY faculty_request_clearances ON clinic.health_clearances
    FOR INSERT
    TO clinic_faculty
    WITH CHECK (requested_by = clinic.current_app_user_id());

-- ============================================================================
-- POLICIES: clinic.qr_codes
-- ============================================================================

-- Admin: full access
CREATE POLICY admin_all_qr ON clinic.qr_codes
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Nurse: can read QR codes (needed for check-in scanning)
CREATE POLICY nurse_read_qr ON clinic.qr_codes
    FOR SELECT
    TO clinic_nurse
    USING (true);

-- Student: can see their own QR code
CREATE POLICY student_own_qr ON clinic.qr_codes
    FOR SELECT
    TO clinic_student
    USING (student_number = clinic.current_student_number());

-- ============================================================================
-- POLICIES: clinic.medicines
-- ============================================================================
-- Medicines catalog is not sensitive — all clinical staff can read.

-- Admin: full access
CREATE POLICY admin_all_medicines ON clinic.medicines
    FOR ALL
    TO clinic_admin
    USING (true)
    WITH CHECK (true);

-- Doctor/Nurse: can view available medicines
CREATE POLICY staff_read_medicines ON clinic.medicines
    FOR SELECT
    TO clinic_doctor, clinic_nurse
    USING (true);

-- Nurse: can also update medicine availability
CREATE POLICY nurse_update_medicines ON clinic.medicines
    FOR UPDATE
    TO clinic_nurse
    USING (true)
    WITH CHECK (true);

-- ============================================================================
-- Verification
-- ============================================================================
-- Test RLS as a student:
--
--   SET ROLE clinic_student;
--   SELECT set_config('app.current_user_id', '5', true);  -- student's user_id
--   SELECT set_config('app.current_role', 'student', true);
--
--   -- Should only return own records:
--   SELECT * FROM clinic.consultations;
--   SELECT * FROM clinic.health_clearances;
--
--   -- Should fail (no policy):
--   INSERT INTO clinic.consultations (...) VALUES (...);
--
--   RESET ROLE;
-- ============================================================================
