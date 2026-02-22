-- ============================================================================
-- 06_grants.sql
-- School Clinic Management System — Permission Matrix (MySQL)
-- ============================================================================
-- Run AFTER 05_views.sql:
--   mysql -u root -p school_clinic < 06_grants.sql
-- ============================================================================
-- This file implements the principle of least privilege.
-- Each role gets only the minimum permissions required for its function.
--
-- GRANT MATRIX:
-- ┌───────────────────────────┬───────┬────────┬───────┬─────────┬─────────┐
-- │ Object                    │ Admin │ Doctor │ Nurse │ Student │ Faculty │
-- ├───────────────────────────┼───────┼────────┼───────┼─────────┼─────────┤
-- │ users                     │ ALL   │ SEL    │ SEL   │ —†      │ —†      │
-- │ students                  │ ALL   │ SEL    │ ALL   │ —†      │ —       │
-- │ qr_codes                  │ ALL   │ —      │ SEL   │ —†      │ —       │
-- │ consultations             │ ALL   │ S,U    │ S,I,U │ —†      │ —       │
-- │ prescriptions             │ ALL   │ S,I,U  │ SEL   │ —†      │ —       │
-- │ medicines                 │ ALL   │ SEL    │ S,U   │ —       │ —       │
-- │ consultation_medicines    │ ALL   │ SEL    │ S,I   │ —†      │ —       │
-- │ health_clearances         │ ALL   │ S,I,U  │ ALL   │ —†      │ —†      │
-- │ audit.activity_log        │ SEL   │ —      │ —     │ —       │ —       │
-- ├───────────────────────────┼───────┼────────┼───────┼─────────┼─────────┤
-- │ v_student_medical_history │ —     │ —      │ —     │ SEL     │ —       │
-- │ v_faculty_clearance       │ —     │ —      │ —     │ —       │ SEL     │
-- │ v_nurse_dashboard         │ —     │ —      │ SEL   │ —       │ —       │
-- │ v_doctor_consultations    │ —     │ SEL    │ —     │ —       │ —       │
-- │ v_admin_user_overview     │ SEL   │ —      │ —     │ —       │ —       │
-- │ v_qr_checkin              │ —     │ —      │ SEL   │ —       │ —       │
-- └───────────────────────────┴───────┴────────┴───────┴─────────┴─────────┘
-- † = student/faculty access base tables only via DEFINER views (no direct access)
-- S=SELECT, I=INSERT, U=UPDATE, D=DELETE
-- ============================================================================

-- ============================================================================
-- STEP 1: REVOKE ALL FROM EACH ROLE
-- ============================================================================
-- Remove any previously granted access to start clean.

REVOKE ALL PRIVILEGES ON school_clinic.* FROM 'clinic_admin'@'%';
REVOKE ALL PRIVILEGES ON school_clinic.* FROM 'clinic_doctor'@'%';
REVOKE ALL PRIVILEGES ON school_clinic.* FROM 'clinic_nurse'@'%';
REVOKE ALL PRIVILEGES ON school_clinic.* FROM 'clinic_student'@'%';
REVOKE ALL PRIVILEGES ON school_clinic.* FROM 'clinic_faculty'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_admin'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_doctor'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_nurse'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_student'@'%';
REVOKE ALL PRIVILEGES ON school_clinic_audit.* FROM 'clinic_faculty'@'%';

-- ============================================================================
-- STEP 2: clinic_admin — Full access to everything
-- ============================================================================

GRANT ALL PRIVILEGES ON school_clinic.* TO 'clinic_admin'@'%';
GRANT SELECT ON school_clinic_audit.* TO 'clinic_admin'@'%';

-- ============================================================================
-- STEP 3: clinic_doctor
-- ============================================================================

GRANT SELECT                 ON school_clinic.users                  TO 'clinic_doctor'@'%';
GRANT SELECT                 ON school_clinic.students               TO 'clinic_doctor'@'%';
GRANT SELECT, UPDATE         ON school_clinic.consultations          TO 'clinic_doctor'@'%';
GRANT SELECT, INSERT, UPDATE ON school_clinic.prescriptions          TO 'clinic_doctor'@'%';
GRANT SELECT                 ON school_clinic.medicines              TO 'clinic_doctor'@'%';
GRANT SELECT                 ON school_clinic.consultation_medicines TO 'clinic_doctor'@'%';
GRANT SELECT, INSERT, UPDATE ON school_clinic.health_clearances      TO 'clinic_doctor'@'%';
-- View access
GRANT SELECT ON school_clinic.v_doctor_consultations TO 'clinic_doctor'@'%';
-- Function / procedure access
GRANT EXECUTE ON FUNCTION  school_clinic.encrypt_data           TO 'clinic_doctor'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.decrypt_data           TO 'clinic_doctor'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.current_app_user_id    TO 'clinic_doctor'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.current_app_role       TO 'clinic_doctor'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.current_student_id     TO 'clinic_doctor'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.create_prescription    TO 'clinic_doctor'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_create_prescription TO 'clinic_doctor'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_update_clearance   TO 'clinic_doctor'@'%';

-- ============================================================================
-- STEP 4: clinic_nurse
-- ============================================================================

GRANT SELECT                 ON school_clinic.users                  TO 'clinic_nurse'@'%';
GRANT SELECT, INSERT, UPDATE ON school_clinic.students               TO 'clinic_nurse'@'%';
GRANT SELECT                 ON school_clinic.qr_codes               TO 'clinic_nurse'@'%';
GRANT SELECT, INSERT, UPDATE ON school_clinic.consultations          TO 'clinic_nurse'@'%';
GRANT SELECT                 ON school_clinic.prescriptions          TO 'clinic_nurse'@'%';
GRANT SELECT, UPDATE         ON school_clinic.medicines              TO 'clinic_nurse'@'%';
GRANT SELECT, INSERT         ON school_clinic.consultation_medicines TO 'clinic_nurse'@'%';
GRANT SELECT, INSERT, UPDATE ON school_clinic.health_clearances      TO 'clinic_nurse'@'%';
-- View access
GRANT SELECT ON school_clinic.v_nurse_dashboard TO 'clinic_nurse'@'%';
GRANT SELECT ON school_clinic.v_qr_checkin      TO 'clinic_nurse'@'%';
-- Function / procedure access
GRANT EXECUTE ON FUNCTION  school_clinic.encrypt_data           TO 'clinic_nurse'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.decrypt_data           TO 'clinic_nurse'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.current_app_user_id    TO 'clinic_nurse'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.current_app_role       TO 'clinic_nurse'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.current_student_id     TO 'clinic_nurse'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.create_consultation    TO 'clinic_nurse'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_create_consultation TO 'clinic_nurse'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_update_consultation TO 'clinic_nurse'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_update_clearance   TO 'clinic_nurse'@'%';

-- ============================================================================
-- STEP 5: clinic_student
-- ============================================================================
-- Students ONLY access data through DEFINER views. No direct table access.

GRANT SELECT ON school_clinic.v_student_medical_history TO 'clinic_student'@'%';
-- Function access (needed by the views)
GRANT EXECUTE ON FUNCTION school_clinic.decrypt_data        TO 'clinic_student'@'%';
GRANT EXECUTE ON FUNCTION school_clinic.current_app_user_id TO 'clinic_student'@'%';
GRANT EXECUTE ON FUNCTION school_clinic.current_app_role    TO 'clinic_student'@'%';
GRANT EXECUTE ON FUNCTION school_clinic.current_student_id  TO 'clinic_student'@'%';

-- ============================================================================
-- STEP 6: clinic_faculty
-- ============================================================================
-- Faculty ONLY accesses the v_faculty_clearance view for reading.
-- They can also request clearances via procedures.

GRANT SELECT ON school_clinic.v_faculty_clearance TO 'clinic_faculty'@'%';
-- Function / procedure access
GRANT EXECUTE ON FUNCTION  school_clinic.current_app_user_id    TO 'clinic_faculty'@'%';
GRANT EXECUTE ON FUNCTION  school_clinic.current_app_role       TO 'clinic_faculty'@'%';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_request_clearance TO 'clinic_faculty'@'%';

-- ============================================================================
-- STEP 7: clinic_app — Application service account
-- ============================================================================
-- The application connects as clinic_app. It needs broad access because it
-- executes queries on behalf of all roles, using session variables to control
-- which views/procedures are accessible per request.

GRANT SELECT, INSERT, UPDATE, DELETE ON school_clinic.* TO 'clinic_app'@'%';
GRANT EXECUTE ON school_clinic.* TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic_audit.* TO 'clinic_app'@'%';

FLUSH PRIVILEGES;

-- ============================================================================
-- Verification
-- ============================================================================
-- Check grants for a specific user:
--   SHOW GRANTS FOR 'clinic_student'@'%';
--   SHOW GRANTS FOR 'clinic_faculty'@'%';
--   SHOW GRANTS FOR 'clinic_doctor'@'%';
--
-- Test permission denied (connect as clinic_student):
--   mysql -u clinic_student -p school_clinic
--   SELECT * FROM consultations;  -- ERROR: access denied
--   SELECT * FROM v_student_medical_history;  -- OK (filtered by view)
-- ============================================================================
