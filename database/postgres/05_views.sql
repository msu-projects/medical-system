-- ============================================================================
-- 05_views.sql
-- School Clinic Management System — Role-Based Masked Views
-- ============================================================================
-- Run AFTER 04_rls_policies.sql:
--   psql -U postgres -d school_clinic_db -f 05_views.sql
-- ============================================================================
-- These views provide role-appropriate data access with:
--   1. Column masking   — hide internal/sensitive columns from certain roles
--   2. Auto-decryption  — decrypt BYTEA columns using the session key
--   3. Filtered rows    — show only authorized records per role
--
-- Views run with security_invoker=true so caller permissions and RLS are
-- always enforced. Users still need SELECT on the view, and base-table
-- access remains constrained by grants and row-level policies.
-- ============================================================================

SET search_path TO clinic, public;

-- ============================================================================
-- 1. STUDENT VIEW: v_student_medical_history
-- ============================================================================
-- Students can see their own:
--   - Consultation details (decrypted diagnosis, but NOT treatment_notes)
--   - Prescription details (decrypted)
--   - Medicines dispensed
--   - Vitals
--
-- treatment_notes is deliberately excluded — it contains internal clinical
-- observations not meant for patient viewing.

CREATE OR REPLACE VIEW clinic.v_student_medical_history
WITH (security_invoker = true) AS
SELECT
    c.consultation_id,
    c.check_in_time,
    c.chief_complaint,
    clinic.decrypt_data(c.diagnosis)    AS diagnosis,
    -- treatment_notes deliberately EXCLUDED (internal clinical notes)
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status                            AS consultation_status,
    concat_ws(' ', u_staff.first_name, u_staff.last_name) AS attended_by_name,
    -- Prescription info (if any)
    p.prescription_id,
    clinic.decrypt_data(p.prescription_details) AS prescription_details,
    p.issued_at                         AS prescription_date,
    concat_ws(' ', u_doc.first_name, u_doc.last_name) AS prescribed_by_name,
    -- Medicines dispensed (if any)
    m.name                              AS medicine_name,
    cm.quantity_given,
    cm.dispensed_at
FROM
    clinic.consultations c
    JOIN clinic.students s ON c.student_id = s.student_id
    JOIN clinic.users u_staff ON c.attended_by = u_staff.user_id
    LEFT JOIN clinic.prescriptions p ON c.consultation_id = p.consultation_id
    LEFT JOIN clinic.users u_doc ON p.prescribed_by = u_doc.user_id
    LEFT JOIN clinic.consultation_medicines cm ON c.consultation_id = cm.consultation_id
    LEFT JOIN clinic.medicines m ON cm.medicine_id = m.medicine_id
WHERE
    s.user_id = clinic.current_app_user_id()
ORDER BY
    c.check_in_time DESC;

COMMENT ON VIEW clinic.v_student_medical_history IS
    'Student-facing view — own medical history with decrypted diagnosis (excludes internal treatment notes)';

-- ============================================================================
-- 2. FACULTY VIEW: v_faculty_clearance
-- ============================================================================
-- Faculty can ONLY see:
--   - Student name
--   - Clearance status, purpose, validity
--
-- NO medical details, NO diagnoses, NO prescriptions, NO consultation history.

CREATE OR REPLACE VIEW clinic.v_faculty_clearance
WITH (security_invoker = true) AS
SELECT
    hc.clearance_id,
    concat_ws(' ', u_student.first_name, u_student.last_name) AS student_name,
    s.student_number,
    s.year_level,
    s.section,
    hc.purpose,
    hc.status                            AS clearance_status,
    hc.valid_until,
    hc.remarks,
    concat_ws(' ', u_issued.first_name, u_issued.last_name) AS issued_by_name,
    hc.created_at                        AS requested_at
FROM
    clinic.health_clearances hc
    JOIN clinic.students s ON hc.student_id = s.student_id
    JOIN clinic.users u_student ON s.user_id = u_student.user_id
    LEFT JOIN clinic.users u_issued ON hc.issued_by = u_issued.user_id
WHERE
    -- Faculty can see clearances they requested, or that are finalized
    hc.requested_by = clinic.current_app_user_id()
    OR hc.status IN ('cleared', 'not_cleared')
ORDER BY
    hc.created_at DESC;

COMMENT ON VIEW clinic.v_faculty_clearance IS
    'Faculty-facing view — clearance status only, no medical details';

-- ============================================================================
-- 3. NURSE DASHBOARD VIEW: v_nurse_dashboard
-- ============================================================================
-- Nurses see all consultations with decrypted data, student info, and vitals.
-- Used for the main clinic workflow.

CREATE OR REPLACE VIEW clinic.v_nurse_dashboard
WITH (security_invoker = true) AS
SELECT
    c.consultation_id,
    c.check_in_time,
    s.student_number,
    concat_ws(' ', u_student.first_name, u_student.last_name) AS student_name,
    s.year_level,
    s.section,
    s.blood_type,
    s.allergies,
    c.chief_complaint,
    clinic.decrypt_data(c.diagnosis)     AS diagnosis,
    clinic.decrypt_data(c.treatment_notes) AS treatment_notes,
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status                             AS consultation_status,
    concat_ws(' ', u_staff.first_name, u_staff.last_name) AS attended_by_name,
    c.updated_at
FROM
    clinic.consultations c
    JOIN clinic.students s ON c.student_id = s.student_id
    JOIN clinic.users u_student ON s.user_id = u_student.user_id
    JOIN clinic.users u_staff ON c.attended_by = u_staff.user_id
ORDER BY
    CASE WHEN c.status = 'ongoing' THEN 0 ELSE 1 END,
    c.check_in_time DESC;

COMMENT ON VIEW clinic.v_nurse_dashboard IS
    'Nurse dashboard — all consultations with decrypted medical data and student details';

-- ============================================================================
-- 4. DOCTOR VIEW: v_doctor_consultations
-- ============================================================================
-- Doctors see full medical details including prescriptions.

CREATE OR REPLACE VIEW clinic.v_doctor_consultations
WITH (security_invoker = true) AS
SELECT
    c.consultation_id,
    c.check_in_time,
    s.student_number,
    concat_ws(' ', u_student.first_name, u_student.last_name) AS student_name,
    s.date_of_birth,
    s.sex,
    s.blood_type,
    s.allergies,
    c.chief_complaint,
    clinic.decrypt_data(c.diagnosis)      AS diagnosis,
    clinic.decrypt_data(c.treatment_notes) AS treatment_notes,
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status                              AS consultation_status,
    concat_ws(' ', u_staff.first_name, u_staff.last_name) AS attended_by_name,
    -- Prescription details
    p.prescription_id,
    clinic.decrypt_data(p.prescription_details) AS prescription_details,
    clinic.decrypt_data(p.notes)          AS prescription_notes,
    p.issued_at                           AS prescription_date,
    concat_ws(' ', u_doc.first_name, u_doc.last_name) AS prescribed_by_name,
    c.updated_at
FROM
    clinic.consultations c
    JOIN clinic.students s ON c.student_id = s.student_id
    JOIN clinic.users u_student ON s.user_id = u_student.user_id
    JOIN clinic.users u_staff ON c.attended_by = u_staff.user_id
    LEFT JOIN clinic.prescriptions p ON c.consultation_id = p.consultation_id
    LEFT JOIN clinic.users u_doc ON p.prescribed_by = u_doc.user_id
ORDER BY
    c.check_in_time DESC;

COMMENT ON VIEW clinic.v_doctor_consultations IS
    'Doctor view — full medical details with decrypted diagnosis, treatment notes, and prescriptions';

-- ============================================================================
-- 5. ADMIN VIEW: v_admin_user_overview
-- ============================================================================
-- Admin overview of all user accounts (password_hash is excluded).

CREATE OR REPLACE VIEW clinic.v_admin_user_overview
WITH (security_invoker = true) AS
SELECT
    u.user_id,
    u.username,
    -- password_hash deliberately EXCLUDED from view
    u.email,
    concat_ws(' ', u.first_name, u.last_name) AS full_name,
    u.role,
    u.is_active,
    u.last_login,
    u.created_at,
    s.student_number,
    s.year_level,
    s.section
FROM
    clinic.users u
    LEFT JOIN clinic.students s ON u.user_id = s.user_id
ORDER BY
    u.role, full_name;

COMMENT ON VIEW clinic.v_admin_user_overview IS
    'Admin user management view — all accounts WITHOUT password hashes';

-- ============================================================================
-- 6. QR CHECK-IN VIEW: v_qr_checkin
-- ============================================================================
-- Used by nurses when scanning a QR code to pull up student profile.

CREATE OR REPLACE VIEW clinic.v_qr_checkin
WITH (security_invoker = true) AS
SELECT
    q.qr_token,
    s.student_id,
    s.student_number,
    concat_ws(' ', u_student.first_name, u_student.last_name) AS student_name,
    s.date_of_birth,
    s.sex,
    s.blood_type,
    s.allergies,
    s.emergency_contact_name,
    s.emergency_contact_number,
    s.year_level,
    s.section,
    q.is_active                          AS qr_active
FROM
    clinic.qr_codes q
    JOIN clinic.students s ON q.student_id = s.student_id
    JOIN clinic.users u_student ON s.user_id = u_student.user_id
WHERE
    q.is_active = TRUE;

COMMENT ON VIEW clinic.v_qr_checkin IS
    'QR check-in lookup — scanned QR token resolves to student profile for clinic staff';

-- ============================================================================
-- Verification
-- ============================================================================
-- \dv clinic.*   -- List all views in clinic schema
--
-- Test as student:
--   SET ROLE clinic_student;
--   SELECT set_config('app.current_user_id', '5', true);
--   SELECT set_config('app.encryption_key', 'test-key', true);
--   SELECT * FROM clinic.v_student_medical_history;  -- should show own records
--   RESET ROLE;
--
-- Test as faculty:
--   SET ROLE clinic_faculty;
--   SELECT set_config('app.current_user_id', '8', true);
--   SELECT * FROM clinic.v_faculty_clearance;         -- only clearance status
--   RESET ROLE;
-- ============================================================================
