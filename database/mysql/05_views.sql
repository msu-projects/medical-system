-- ============================================================================
-- 05_views.sql
-- School Clinic Management System — Role-Based Masked Views (MySQL)
-- ============================================================================
-- Run AFTER 04_rls_policies.sql:
--   mysql -u root -p school_clinic < 05_views.sql
-- ============================================================================
-- These views provide role-appropriate data access with:
--   1. Column masking   — hide internal/sensitive columns from certain roles
--   2. Auto-decryption  — decrypt BLOB columns using the session key
--   3. Filtered rows    — show only authorized records per role
--
-- Views use SQL SECURITY DEFINER so they execute with the creator's
-- privileges, allowing users with only view-level grants to query
-- the underlying tables they cannot access directly.
-- ============================================================================

USE school_clinic;

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

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_student_medical_history AS
SELECT
    c.consultation_id,
    c.check_in_time,
    c.chief_complaint,
    decrypt_data(c.diagnosis)               AS diagnosis,
    -- treatment_notes deliberately EXCLUDED (internal clinical notes)
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status                                                    AS consultation_status,
    CONCAT(u_staff.first_name, ' ', u_staff.last_name)          AS attended_by_name,
    -- Prescription info (if any)
    p.prescription_id,
    decrypt_data(p.prescription_details)                        AS prescription_details,
    p.issued_at                                                 AS prescription_date,
    CONCAT(u_doc.first_name, ' ', u_doc.last_name)              AS prescribed_by_name,
    -- Medicines dispensed (if any)
    m.name                                  AS medicine_name,
    cm.quantity_given,
    cm.dispensed_at
FROM
    consultations c
    JOIN students s ON c.student_id = s.student_id
    JOIN users u_staff ON c.attended_by = u_staff.user_id
    LEFT JOIN prescriptions p ON c.consultation_id = p.consultation_id
    LEFT JOIN users u_doc ON p.prescribed_by = u_doc.user_id
    LEFT JOIN consultation_medicines cm ON c.consultation_id = cm.consultation_id
    LEFT JOIN medicines m ON cm.medicine_id = m.medicine_id
WHERE
    s.user_id = current_app_user_id()
ORDER BY
    c.check_in_time DESC;

-- ============================================================================
-- 2. FACULTY VIEW: v_faculty_clearance
-- ============================================================================
-- Faculty can ONLY see:
--   - Student name
--   - Clearance status, purpose, validity
--
-- NO medical details, NO diagnoses, NO prescriptions, NO consultation history.

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_faculty_clearance AS
SELECT
    hc.clearance_id,
    CONCAT(u_student.first_name, ' ', u_student.last_name) AS student_name,
    s.student_number,
    s.year_level,
    s.section,
    hc.purpose,
    hc.status                                              AS clearance_status,
    hc.valid_until,
    hc.remarks,
    CONCAT(u_issued.first_name, ' ', u_issued.last_name)   AS issued_by_name,
    hc.created_at                                          AS requested_at
FROM
    health_clearances hc
    JOIN students s ON hc.student_id = s.student_id
    JOIN users u_student ON s.user_id = u_student.user_id
    LEFT JOIN users u_issued ON hc.issued_by = u_issued.user_id
WHERE
    hc.requested_by = current_app_user_id()
    OR hc.status IN ('cleared', 'not_cleared')
ORDER BY
    hc.created_at DESC;

-- ============================================================================
-- 3. NURSE DASHBOARD VIEW: v_nurse_dashboard
-- ============================================================================
-- Nurses see all consultations with decrypted data, student info, and vitals.

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_nurse_dashboard AS
SELECT
    c.consultation_id,
    c.check_in_time,
    s.student_number,
    CONCAT(u_student.first_name, ' ', u_student.last_name) AS student_name,
    s.year_level,
    s.section,
    s.blood_type,
    s.allergies,
    c.chief_complaint,
    decrypt_data(c.diagnosis)                              AS diagnosis,
    decrypt_data(c.treatment_notes)                        AS treatment_notes,
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status                                               AS consultation_status,
    CONCAT(u_staff.first_name, ' ', u_staff.last_name)     AS attended_by_name,
    c.updated_at
FROM
    consultations c
    JOIN students s ON c.student_id = s.student_id
    JOIN users u_student ON s.user_id = u_student.user_id
    JOIN users u_staff ON c.attended_by = u_staff.user_id
ORDER BY
    CASE WHEN c.status = 'ongoing' THEN 0 ELSE 1 END,
    c.check_in_time DESC;

-- ============================================================================
-- 4. DOCTOR VIEW: v_doctor_consultations
-- ============================================================================
-- Doctors see full medical details including prescriptions.

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_doctor_consultations AS
SELECT
    c.consultation_id,
    c.check_in_time,
    s.student_number,
    CONCAT(u_student.first_name, ' ', u_student.last_name)  AS student_name,
    s.date_of_birth,
    s.sex,
    s.blood_type,
    s.allergies,
    c.chief_complaint,
    decrypt_data(c.diagnosis)                               AS diagnosis,
    decrypt_data(c.treatment_notes)                         AS treatment_notes,
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status                                                AS consultation_status,
    CONCAT(u_staff.first_name, ' ', u_staff.last_name)      AS attended_by_name,
    -- Prescription details
    p.prescription_id,
    decrypt_data(p.prescription_details)                    AS prescription_details,
    decrypt_data(p.notes)                                   AS prescription_notes,
    p.issued_at                                             AS prescription_date,
    CONCAT(u_doc.first_name, ' ', u_doc.last_name)          AS prescribed_by_name,
    c.updated_at
FROM
    consultations c
    JOIN students s ON c.student_id = s.student_id
    JOIN users u_student ON s.user_id = u_student.user_id
    JOIN users u_staff ON c.attended_by = u_staff.user_id
    LEFT JOIN prescriptions p ON c.consultation_id = p.consultation_id
    LEFT JOIN users u_doc ON p.prescribed_by = u_doc.user_id
ORDER BY
    c.check_in_time DESC;

-- ============================================================================
-- 5. ADMIN VIEW: v_admin_user_overview
-- ============================================================================
-- Admin overview of all user accounts (password_hash is excluded).

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_admin_user_overview AS
SELECT
    u.user_id,
    u.username,
    -- password_hash deliberately EXCLUDED from view
    u.email,
    CONCAT(u.first_name, ' ', u.last_name) AS full_name,
    u.role,
    u.is_active,
    u.last_login,
    u.created_at,
    s.student_number,
    s.year_level,
    s.section
FROM
    users u
    LEFT JOIN students s ON u.user_id = s.user_id
ORDER BY
    u.role, CONCAT(u.first_name, ' ', u.last_name);

-- ============================================================================
-- 6. QR CHECK-IN VIEW: v_qr_checkin
-- ============================================================================
-- Used by nurses when scanning a QR code to pull up student profile.

CREATE OR REPLACE
DEFINER = 'root'@'localhost'
SQL SECURITY DEFINER
VIEW v_qr_checkin AS
SELECT
    q.qr_token,
    s.student_id,
    s.student_number,
    CONCAT(u_student.first_name, ' ', u_student.last_name) AS student_name,
    s.date_of_birth,
    s.sex,
    s.blood_type,
    s.allergies,
    s.emergency_contact_name,
    s.emergency_contact_number,
    s.year_level,
    s.section,
    q.is_active                                            AS qr_active
FROM
    qr_codes q
    JOIN students s ON q.student_id = s.student_id
    JOIN users u_student ON s.user_id = u_student.user_id
WHERE
    q.is_active = TRUE;

-- ============================================================================
-- Verification
-- ============================================================================
-- SHOW FULL TABLES WHERE Table_type = 'VIEW';
--
-- Test as student:
--   SET @app_current_user_id = 6;
--   SET @app_current_role = 'student';
--   SET @app_encryption_key = 'dev-secret-key-change-in-prod';
--   SET SESSION block_encryption_mode = 'aes-256-cbc';
--   SELECT * FROM v_student_medical_history;  -- should show only own records
--
-- Test as faculty:
--   SET @app_current_user_id = 11;
--   SET @app_current_role = 'faculty';
--   SELECT * FROM v_faculty_clearance;        -- only clearance status
-- ============================================================================
