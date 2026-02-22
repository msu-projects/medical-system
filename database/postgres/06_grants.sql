-- ============================================================================
-- 06_grants.sql
-- School Clinic Management System — Permission Matrix (GRANT / REVOKE)
-- ============================================================================
-- Run AFTER 05_views.sql:
--   psql -U postgres -d school_clinic_db -f 06_grants.sql
-- ============================================================================
-- This file implements the principle of least privilege.
-- Each role gets only the minimum permissions required for its function.
--
-- GRANT MATRIX:
-- ┌───────────────────────────┬───────┬────────┬───────┬─────────┬─────────┐
-- │ Object                    │ Admin │ Doctor │ Nurse │ Student │ Faculty │
-- ├───────────────────────────┼───────┼────────┼───────┼─────────┼─────────┤
-- │ users                     │ ALL   │ SEL    │ SEL   │ SEL*    │ SEL*    │
-- │ students                  │ ALL   │ SEL    │ ALL   │ SEL*    │ —       │
-- │ qr_codes                  │ ALL   │ —      │ SEL   │ SEL*    │ —       │
-- │ consultations             │ ALL   │ S,U    │ S,I,U │ SEL*    │ —       │
-- │ prescriptions             │ ALL   │ S,I,U  │ SEL   │ SEL*    │ —       │
-- │ medicines                 │ ALL   │ SEL    │ S,U   │ —       │ —       │
-- │ consultation_medicines    │ ALL   │ SEL    │ S,I   │ SEL*    │ —       │
-- │ health_clearances         │ ALL   │ S,I,U  │ ALL   │ SEL*    │ S,I*   │
-- │ audit.activity_log        │ SEL   │ —      │ —     │ —       │ —       │
-- ├───────────────────────────┼───────┼────────┼───────┼─────────┼─────────┤
-- │ v_student_medical_history │ —     │ —      │ —     │ SEL     │ —       │
-- │ v_faculty_clearance       │ —     │ —      │ —     │ —       │ SEL     │
-- │ v_nurse_dashboard         │ —     │ —      │ SEL   │ —       │ —       │
-- │ v_doctor_consultations    │ —     │ SEL    │ —     │ —       │ —       │
-- │ v_admin_user_overview     │ SEL   │ —      │ —     │ —       │ —       │
-- │ v_qr_checkin              │ —     │ —      │ SEL   │ —       │ —       │
-- └───────────────────────────┴───────┴────────┴───────┴─────────┴─────────┘
-- * = additionally filtered by RLS policies (04_rls_policies.sql)
-- S=SELECT, I=INSERT, U=UPDATE, D=DELETE
-- ============================================================================

SET search_path TO clinic, public;

-- ============================================================================
-- STEP 1: REVOKE ALL FROM PUBLIC
-- ============================================================================
-- Remove default PUBLIC access from every object. This ensures no role
-- gets accidental access. This is the foundation of least-privilege.

REVOKE ALL ON ALL TABLES    IN SCHEMA clinic FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA clinic FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA clinic FROM PUBLIC;
REVOKE ALL ON SCHEMA clinic FROM PUBLIC;

-- ============================================================================
-- STEP 2: Grant schema usage (some roles need re-grant after revoke)
-- ============================================================================

GRANT USAGE ON SCHEMA clinic TO clinic_admin, clinic_doctor, clinic_nurse, clinic_student, clinic_faculty;
GRANT USAGE ON SCHEMA audit  TO clinic_admin;

-- ============================================================================
-- STEP 3: Sequence usage (needed for INSERT with SERIAL columns)
-- ============================================================================

GRANT USAGE ON ALL SEQUENCES IN SCHEMA clinic TO clinic_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA clinic TO clinic_nurse;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA clinic TO clinic_doctor;
-- Students and faculty don't create records directly (except faculty clearance requests)
GRANT USAGE ON SEQUENCE clinic.health_clearances_clearance_id_seq TO clinic_faculty;

-- ============================================================================
-- STEP 4: Function execution grants
-- ============================================================================

-- Encryption/decryption helpers — needed by roles that read/write encrypted data
GRANT EXECUTE ON FUNCTION clinic.encrypt_data(TEXT)          TO clinic_admin, clinic_doctor, clinic_nurse;
GRANT EXECUTE ON FUNCTION clinic.decrypt_data(BYTEA)         TO clinic_admin, clinic_doctor, clinic_nurse, clinic_student;
GRANT EXECUTE ON FUNCTION clinic.create_consultation         TO clinic_admin, clinic_nurse;
GRANT EXECUTE ON FUNCTION clinic.create_prescription         TO clinic_admin, clinic_doctor;

-- RLS helper functions — all roles need these
GRANT EXECUTE ON FUNCTION clinic.current_app_user_id()  TO clinic_admin, clinic_doctor, clinic_nurse, clinic_student, clinic_faculty;
GRANT EXECUTE ON FUNCTION clinic.current_app_role()     TO clinic_admin, clinic_doctor, clinic_nurse, clinic_student, clinic_faculty;
GRANT EXECUTE ON FUNCTION clinic.current_student_id()   TO clinic_admin, clinic_doctor, clinic_nurse, clinic_student;

-- ============================================================================
-- STEP 5: TABLE-LEVEL GRANTS — clinic_admin
-- ============================================================================
-- Full access to everything (CRUD on all tables).

GRANT ALL ON ALL TABLES    IN SCHEMA clinic TO clinic_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA clinic TO clinic_admin;

-- ============================================================================
-- STEP 6: TABLE-LEVEL GRANTS — clinic_doctor
-- ============================================================================

GRANT SELECT                ON clinic.users                  TO clinic_doctor;
GRANT SELECT                ON clinic.students               TO clinic_doctor;
GRANT SELECT, UPDATE        ON clinic.consultations          TO clinic_doctor;
GRANT SELECT, INSERT, UPDATE ON clinic.prescriptions         TO clinic_doctor;
GRANT SELECT                ON clinic.medicines              TO clinic_doctor;
GRANT SELECT                ON clinic.consultation_medicines TO clinic_doctor;
GRANT SELECT, INSERT, UPDATE ON clinic.health_clearances    TO clinic_doctor;
-- No access to qr_codes (doctors don't scan QR)

-- ============================================================================
-- STEP 7: TABLE-LEVEL GRANTS — clinic_nurse
-- ============================================================================

GRANT SELECT                ON clinic.users                  TO clinic_nurse;
GRANT SELECT, INSERT, UPDATE ON clinic.students              TO clinic_nurse;
GRANT SELECT                ON clinic.qr_codes               TO clinic_nurse;
GRANT SELECT, INSERT, UPDATE ON clinic.consultations         TO clinic_nurse;
GRANT SELECT                ON clinic.prescriptions          TO clinic_nurse;
GRANT SELECT, UPDATE        ON clinic.medicines              TO clinic_nurse;
GRANT SELECT, INSERT        ON clinic.consultation_medicines TO clinic_nurse;
GRANT SELECT, INSERT, UPDATE ON clinic.health_clearances    TO clinic_nurse;

-- ============================================================================
-- STEP 8: TABLE-LEVEL GRANTS — clinic_student
-- ============================================================================
-- Students access data ONLY through masked views + RLS.
-- Direct table SELECT is needed for RLS policies to work, but rows
-- are filtered by RLS so students only see their own data.

GRANT SELECT ON clinic.users                  TO clinic_student;
GRANT SELECT ON clinic.students               TO clinic_student;
GRANT SELECT ON clinic.qr_codes              TO clinic_student;
GRANT SELECT ON clinic.consultations          TO clinic_student;
GRANT SELECT ON clinic.prescriptions          TO clinic_student;
GRANT SELECT ON clinic.consultation_medicines TO clinic_student;
GRANT SELECT ON clinic.health_clearances      TO clinic_student;
GRANT SELECT ON clinic.medicines              TO clinic_student;

-- ============================================================================
-- STEP 9: TABLE-LEVEL GRANTS — clinic_faculty
-- ============================================================================
-- Faculty ONLY accesses the v_faculty_clearance view for reading.
-- They can also INSERT clearance requests.

GRANT SELECT ON clinic.users             TO clinic_faculty;
GRANT SELECT, INSERT ON clinic.health_clearances TO clinic_faculty;

-- ============================================================================
-- STEP 10: VIEW-LEVEL GRANTS
-- ============================================================================
-- Each role gets SELECT on their designated view(s) only.

-- Student views
GRANT SELECT ON clinic.v_student_medical_history TO clinic_student;

-- Faculty views
GRANT SELECT ON clinic.v_faculty_clearance       TO clinic_faculty;

-- Nurse views
GRANT SELECT ON clinic.v_nurse_dashboard         TO clinic_nurse;
GRANT SELECT ON clinic.v_qr_checkin              TO clinic_nurse;

-- Doctor views
GRANT SELECT ON clinic.v_doctor_consultations    TO clinic_doctor;

-- Admin views
GRANT SELECT ON clinic.v_admin_user_overview     TO clinic_admin;

-- ============================================================================
-- STEP 11: AUDIT SCHEMA GRANTS
-- ============================================================================
-- Only admin can read the audit log. No one can UPDATE or DELETE audit records.
-- The audit trigger function is SECURITY DEFINER, so it can INSERT into
-- the audit table on behalf of any role.

-- (Audit table and grants will be finalized in 07_audit.sql)

-- ============================================================================
-- Verification
-- ============================================================================
-- Check effective permissions:
--
--   SELECT grantee, table_name, privilege_type
--   FROM information_schema.table_privileges
--   WHERE table_schema = 'clinic'
--   ORDER BY grantee, table_name, privilege_type;
--
-- Test permission denied:
--   SET ROLE clinic_student;
--   DELETE FROM clinic.consultations WHERE consultation_id = 1;  -- ERROR: permission denied
--   INSERT INTO clinic.consultations (...) VALUES (...);          -- ERROR: permission denied
--   RESET ROLE;
--
--   SET ROLE clinic_faculty;
--   SELECT * FROM clinic.consultations;  -- ERROR: permission denied
--   SELECT * FROM clinic.v_faculty_clearance;  -- OK (only clearance data)
--   RESET ROLE;
-- ============================================================================
