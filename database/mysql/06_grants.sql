-- ============================================================================
-- 06_grants.sql
-- School Clinic Management System — Permission Matrix (MySQL)
-- ============================================================================
-- Run AFTER 05_views.sql:
--   mysql -u root -p school_clinic < 06_grants.sql
-- ============================================================================
-- PostgreSQL is the source of truth for role intent. This script applies the
-- equivalent least-privilege model to MySQL roles.
-- ============================================================================

-- ============================================================================
-- STEP 1: Reset role privileges
-- ============================================================================
REVOKE ALL PRIVILEGES, GRANT OPTION FROM
    'clinic_admin', 'clinic_doctor', 'clinic_nurse', 'clinic_student', 'clinic_faculty',
    'clinic_trigger_owner', 'clinic_rls_owner', 'audit_writer_owner';

-- ============================================================================
-- STEP 2: clinic_admin — full clinic access + audit read
-- ============================================================================
GRANT ALL PRIVILEGES ON school_clinic.* TO 'clinic_admin';
GRANT SELECT ON school_clinic_audit.* TO 'clinic_admin';

-- ============================================================================
-- STEP 3: Function execution grants
-- ============================================================================
GRANT EXECUTE ON FUNCTION school_clinic.encrypt_data TO
    'clinic_admin', 'clinic_doctor', 'clinic_nurse';
GRANT EXECUTE ON FUNCTION school_clinic.decrypt_data TO
    'clinic_admin', 'clinic_doctor', 'clinic_nurse', 'clinic_student';

GRANT EXECUTE ON FUNCTION school_clinic.current_app_user_id TO
    'clinic_admin', 'clinic_doctor', 'clinic_nurse', 'clinic_student', 'clinic_faculty';
GRANT EXECUTE ON FUNCTION school_clinic.current_app_role TO
    'clinic_admin', 'clinic_doctor', 'clinic_nurse', 'clinic_student', 'clinic_faculty';
GRANT EXECUTE ON FUNCTION school_clinic.current_student_number TO
    'clinic_admin', 'clinic_doctor', 'clinic_nurse', 'clinic_student';

GRANT EXECUTE ON PROCEDURE school_clinic.create_consultation TO
    'clinic_admin', 'clinic_nurse';
GRANT EXECUTE ON PROCEDURE school_clinic.create_prescription TO
    'clinic_admin', 'clinic_doctor';

GRANT EXECUTE ON PROCEDURE school_clinic.secure_create_consultation TO
    'clinic_admin', 'clinic_nurse';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_update_consultation TO
    'clinic_admin', 'clinic_nurse', 'clinic_doctor';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_create_prescription TO
    'clinic_admin', 'clinic_doctor';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_request_clearance TO
    'clinic_admin', 'clinic_faculty';
GRANT EXECUTE ON PROCEDURE school_clinic.secure_update_clearance TO
    'clinic_admin', 'clinic_doctor', 'clinic_nurse';

-- ============================================================================
-- STEP 4: Table-level grants — clinic_doctor
-- ============================================================================
GRANT SELECT ON school_clinic.users TO 'clinic_doctor';
GRANT SELECT ON school_clinic.user_session TO 'clinic_doctor';
GRANT SELECT ON school_clinic.students TO 'clinic_doctor';
GRANT SELECT, UPDATE ON school_clinic.consultations TO 'clinic_doctor';
GRANT SELECT, INSERT, UPDATE ON school_clinic.prescriptions TO 'clinic_doctor';
GRANT SELECT ON school_clinic.medicines TO 'clinic_doctor';
GRANT SELECT ON school_clinic.consultation_medicines TO 'clinic_doctor';
GRANT SELECT, INSERT, UPDATE ON school_clinic.health_clearances TO 'clinic_doctor';

-- ============================================================================
-- STEP 5: Table-level grants — clinic_nurse
-- ============================================================================
GRANT SELECT ON school_clinic.users TO 'clinic_nurse';
GRANT SELECT ON school_clinic.user_session TO 'clinic_nurse';
GRANT SELECT, INSERT, UPDATE ON school_clinic.students TO 'clinic_nurse';
GRANT SELECT ON school_clinic.qr_codes TO 'clinic_nurse';
GRANT SELECT, INSERT, UPDATE ON school_clinic.consultations TO 'clinic_nurse';
GRANT SELECT ON school_clinic.prescriptions TO 'clinic_nurse';
GRANT SELECT, UPDATE ON school_clinic.medicines TO 'clinic_nurse';
GRANT SELECT, INSERT ON school_clinic.consultation_medicines TO 'clinic_nurse';
GRANT SELECT, INSERT, UPDATE ON school_clinic.health_clearances TO 'clinic_nurse';

-- ============================================================================
-- STEP 6: Table-level grants — clinic_student
-- ============================================================================
-- Parity with PostgreSQL intent: table SELECT is allowed, row filtering is
-- enforced by role-aware views/procedures and session context.
GRANT SELECT ON school_clinic.users TO 'clinic_student';
GRANT SELECT ON school_clinic.user_session TO 'clinic_student';
GRANT SELECT ON school_clinic.students TO 'clinic_student';
GRANT SELECT ON school_clinic.qr_codes TO 'clinic_student';
GRANT SELECT ON school_clinic.consultations TO 'clinic_student';
GRANT SELECT ON school_clinic.prescriptions TO 'clinic_student';
GRANT SELECT ON school_clinic.consultation_medicines TO 'clinic_student';
GRANT SELECT ON school_clinic.health_clearances TO 'clinic_student';
GRANT SELECT ON school_clinic.medicines TO 'clinic_student';

-- ============================================================================
-- STEP 7: Table-level grants — clinic_faculty
-- ============================================================================
GRANT SELECT ON school_clinic.users TO 'clinic_faculty';
GRANT SELECT ON school_clinic.user_session TO 'clinic_faculty';
GRANT SELECT, INSERT ON school_clinic.health_clearances TO 'clinic_faculty';

-- ============================================================================
-- STEP 8: View-level grants
-- ============================================================================
GRANT SELECT ON school_clinic.v_student_medical_history TO 'clinic_student';
GRANT SELECT ON school_clinic.v_faculty_clearance TO 'clinic_faculty';
GRANT SELECT ON school_clinic.v_nurse_dashboard TO 'clinic_nurse';
GRANT SELECT ON school_clinic.v_qr_checkin TO 'clinic_nurse';
GRANT SELECT ON school_clinic.v_doctor_consultations TO 'clinic_doctor';
GRANT SELECT ON school_clinic.v_admin_user_overview TO 'clinic_admin';

-- ============================================================================
-- STEP 9: Internal owner roles (definer helpers)
-- ============================================================================
GRANT SELECT ON school_clinic.users TO 'clinic_trigger_owner', 'clinic_rls_owner';
GRANT SELECT ON school_clinic.students TO 'clinic_rls_owner';
GRANT SELECT, INSERT, UPDATE ON school_clinic.student_number_counters TO 'clinic_trigger_owner';

-- Audit-table privileges are granted in 07_audit.sql after the audit schema is created.

FLUSH PRIVILEGES;

-- ============================================================================
-- Verification
-- ============================================================================
-- SHOW GRANTS FOR 'clinic_admin';
-- SHOW GRANTS FOR 'clinic_student';
-- SHOW GRANTS FOR 'clinic_faculty';
-- ============================================================================
