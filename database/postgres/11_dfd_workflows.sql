-- ============================================================================
-- 11_dfd_workflows.sql
-- School Clinic Management System - DFD Level 1 Workflow Views & Functions
-- ============================================================================
-- Run AFTER 10_auth_helpers.sql:
--   psql -U postgres -d school_clinic_db -f 11_dfd_workflows.sql
-- ============================================================================
-- These helpers map the Level 1 DFD processes to database-facing workflows.
-- Password checking remains in the application layer. Medical text still uses
-- clinic.encrypt_data/decrypt_data and requires app.encryption_key to be set.
-- ============================================================================

SET search_path TO clinic, public;

-- ============================================================================
-- Workflow Views
-- ============================================================================

CREATE OR REPLACE VIEW clinic.v_dfd_account_details
WITH (security_invoker = true) AS
SELECT
    u.user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    concat_ws(' ', u.first_name, u.last_name) AS full_name,
    u.role,
    u.is_active,
    u.last_login,
    u.created_at AS account_created_at,
    u.updated_at AS account_updated_at,
    s.student_number,
    s.year_of_enrollment,
    s.date_of_birth,
    s.sex,
    s.contact_number,
    s.emergency_contact_name,
    s.emergency_contact_number,
    s.year_level,
    s.section,
    s.blood_type,
    s.allergies,
    q.qr_token,
    q.is_active AS qr_active,
    q.generated_at AS qr_generated_at
FROM clinic.users u
LEFT JOIN clinic.students s ON s.user_id = u.user_id
LEFT JOIN clinic.qr_codes q ON q.student_number = s.student_number;

CREATE OR REPLACE VIEW clinic.v_dfd_qr_checkin_context
WITH (security_invoker = true) AS
SELECT
    q.qr_token,
    q.is_active AS qr_active,
    s.student_number,
    s.user_id AS student_user_id,
    concat_ws(' ', u.first_name, u.last_name) AS student_name,
    s.date_of_birth,
    s.sex,
    s.contact_number,
    s.emergency_contact_name,
    s.emergency_contact_number,
    s.year_level,
    s.section,
    s.blood_type,
    s.allergies
FROM clinic.qr_codes q
JOIN clinic.students s ON s.student_number = q.student_number
JOIN clinic.users u ON u.user_id = s.user_id
WHERE q.is_active = TRUE
  AND u.is_active = TRUE;

CREATE OR REPLACE VIEW clinic.v_dfd_consultation_context
WITH (security_invoker = true) AS
SELECT
    c.consultation_id,
    c.student_number,
    concat_ws(' ', su.first_name, su.last_name) AS student_name,
    s.year_level,
    s.section,
    c.attended_by,
    concat_ws(' ', au.first_name, au.last_name) AS attended_by_name,
    c.check_in_time,
    c.chief_complaint,
    clinic.decrypt_data(c.diagnosis) AS diagnosis,
    clinic.decrypt_data(c.treatment_notes) AS treatment_notes,
    c.vitals_bp,
    c.vitals_temp,
    c.vitals_pulse,
    c.vitals_weight,
    c.status,
    c.updated_at
FROM clinic.consultations c
JOIN clinic.students s ON s.student_number = c.student_number
JOIN clinic.users su ON su.user_id = s.user_id
JOIN clinic.users au ON au.user_id = c.attended_by;

CREATE OR REPLACE VIEW clinic.v_dfd_prescription_context
WITH (security_invoker = true) AS
SELECT
    p.prescription_id,
    p.consultation_id,
    c.student_number,
    concat_ws(' ', su.first_name, su.last_name) AS student_name,
    p.prescribed_by,
    concat_ws(' ', du.first_name, du.last_name) AS prescribed_by_name,
    clinic.decrypt_data(p.prescription_details) AS prescription_details,
    clinic.decrypt_data(p.notes) AS notes,
    p.issued_at
FROM clinic.prescriptions p
JOIN clinic.consultations c ON c.consultation_id = p.consultation_id
JOIN clinic.students s ON s.student_number = c.student_number
JOIN clinic.users su ON su.user_id = s.user_id
JOIN clinic.users du ON du.user_id = p.prescribed_by;

CREATE OR REPLACE VIEW clinic.v_dfd_dispense_context
WITH (security_invoker = true) AS
SELECT
    cm.id AS dispense_id,
    cm.consultation_id,
    c.student_number,
    m.medicine_id,
    m.name AS medicine_name,
    m.unit,
    cm.quantity_given,
    m.available_quantity,
    cm.dispensed_by,
    concat_ws(' ', u.first_name, u.last_name) AS dispensed_by_name,
    cm.dispensed_at
FROM clinic.consultation_medicines cm
JOIN clinic.consultations c ON c.consultation_id = cm.consultation_id
JOIN clinic.medicines m ON m.medicine_id = cm.medicine_id
LEFT JOIN clinic.users u ON u.user_id = cm.dispensed_by;

CREATE OR REPLACE VIEW clinic.v_dfd_clearance_context
WITH (security_invoker = true) AS
SELECT
    hc.clearance_id,
    hc.student_number,
    concat_ws(' ', su.first_name, su.last_name) AS student_name,
    s.year_level,
    s.section,
    hc.purpose,
    hc.remarks,
    hc.status,
    hc.valid_until,
    hc.requested_by,
    concat_ws(' ', fu.first_name, fu.last_name) AS requested_by_name,
    hc.issued_by,
    concat_ws(' ', iu.first_name, iu.last_name) AS issued_by_name,
    hc.created_at,
    hc.updated_at
FROM clinic.health_clearances hc
JOIN clinic.students s ON s.student_number = hc.student_number
JOIN clinic.users su ON su.user_id = s.user_id
LEFT JOIN clinic.users fu ON fu.user_id = hc.requested_by
LEFT JOIN clinic.users iu ON iu.user_id = hc.issued_by;

CREATE OR REPLACE VIEW clinic.v_dfd_active_sessions
WITH (security_invoker = true) AS
SELECT
    s.session_id,
    s.user_id,
    u.username,
    concat_ws(' ', u.first_name, u.last_name) AS full_name,
    s.role,
    s.issued_at,
    s.expires_at,
    s.last_seen_at,
    s.ip_address,
    s.user_agent
FROM clinic.user_session s
JOIN clinic.users u ON u.user_id = s.user_id
WHERE s.revoked_at IS NULL
  AND s.expires_at > NOW()
  AND u.is_active = TRUE;

-- ============================================================================
-- 1.0 Manage Accounts
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_add_account(
    p_username VARCHAR(50),
    p_password_hash VARCHAR(255),
    p_email VARCHAR(100),
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_role VARCHAR(20),
    p_student_number VARCHAR(10) DEFAULT NULL,
    p_year_of_enrollment SMALLINT DEFAULT NULL,
    p_date_of_birth DATE DEFAULT NULL,
    p_sex VARCHAR(10) DEFAULT NULL,
    p_contact_number VARCHAR(20) DEFAULT NULL,
    p_emergency_contact_name VARCHAR(100) DEFAULT NULL,
    p_emergency_contact_number VARCHAR(20) DEFAULT NULL,
    p_year_level VARCHAR(20) DEFAULT NULL,
    p_section VARCHAR(20) DEFAULT NULL,
    p_blood_type VARCHAR(5) DEFAULT NULL,
    p_allergies TEXT DEFAULT NULL
)
RETURNS TABLE (user_id INT, student_number VARCHAR(10), qr_token UUID, result TEXT)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_user_id INT;
    v_student_number VARCHAR(10);
    v_qr_token UUID;
BEGIN
    INSERT INTO clinic.users (username, password_hash, email, first_name, last_name, role)
    VALUES (p_username, p_password_hash, p_email, p_first_name, p_last_name, p_role)
    RETURNING users.user_id INTO v_user_id;

    IF p_role = 'student' THEN
        IF p_year_of_enrollment IS NULL THEN
            RAISE EXCEPTION 'year_of_enrollment is required when role=student';
        END IF;

        INSERT INTO clinic.students (
            student_number, user_id, year_of_enrollment, date_of_birth, sex,
            contact_number, emergency_contact_name, emergency_contact_number,
            year_level, section, blood_type, allergies
        )
        VALUES (
            p_student_number, v_user_id, p_year_of_enrollment, p_date_of_birth, p_sex,
            p_contact_number, p_emergency_contact_name, p_emergency_contact_number,
            p_year_level, p_section, p_blood_type, p_allergies
        )
        RETURNING students.student_number INTO v_student_number;

        INSERT INTO clinic.qr_codes (student_number)
        VALUES (v_student_number)
        RETURNING qr_codes.qr_token INTO v_qr_token;
    END IF;

    RETURN QUERY SELECT v_user_id, v_student_number, v_qr_token, 'account_created'::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION clinic.dfd_update_account(
    p_user_id INT,
    p_email VARCHAR(100) DEFAULT NULL,
    p_first_name VARCHAR(100) DEFAULT NULL,
    p_last_name VARCHAR(100) DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL,
    p_date_of_birth DATE DEFAULT NULL,
    p_sex VARCHAR(10) DEFAULT NULL,
    p_contact_number VARCHAR(20) DEFAULT NULL,
    p_emergency_contact_name VARCHAR(100) DEFAULT NULL,
    p_emergency_contact_number VARCHAR(20) DEFAULT NULL,
    p_year_level VARCHAR(20) DEFAULT NULL,
    p_section VARCHAR(20) DEFAULT NULL,
    p_blood_type VARCHAR(5) DEFAULT NULL,
    p_allergies TEXT DEFAULT NULL,
    p_qr_active BOOLEAN DEFAULT NULL
)
RETURNS TABLE (user_id INT, student_number VARCHAR(10), result TEXT)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_student_number VARCHAR(10);
BEGIN
    UPDATE clinic.users u
    SET email = COALESCE(p_email, u.email),
        first_name = COALESCE(p_first_name, u.first_name),
        last_name = COALESCE(p_last_name, u.last_name),
        is_active = COALESCE(p_is_active, u.is_active)
    WHERE u.user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User % does not exist', p_user_id;
    END IF;

    SELECT s.student_number INTO v_student_number
    FROM clinic.students s
    WHERE s.user_id = p_user_id;

    IF v_student_number IS NOT NULL THEN
        UPDATE clinic.students s
        SET date_of_birth = COALESCE(p_date_of_birth, s.date_of_birth),
            sex = COALESCE(p_sex, s.sex),
            contact_number = COALESCE(p_contact_number, s.contact_number),
            emergency_contact_name = COALESCE(p_emergency_contact_name, s.emergency_contact_name),
            emergency_contact_number = COALESCE(p_emergency_contact_number, s.emergency_contact_number),
            year_level = COALESCE(p_year_level, s.year_level),
            section = COALESCE(p_section, s.section),
            blood_type = COALESCE(p_blood_type, s.blood_type),
            allergies = COALESCE(p_allergies, s.allergies)
        WHERE s.student_number = v_student_number;

        IF p_qr_active IS NOT NULL THEN
            UPDATE clinic.qr_codes q
            SET is_active = p_qr_active
            WHERE q.student_number = v_student_number;
        END IF;
    END IF;

    RETURN QUERY SELECT p_user_id, v_student_number, 'account_updated'::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION clinic.dfd_deactivate_account(p_user_id INT)
RETURNS TABLE (user_id INT, student_number VARCHAR(10), result TEXT)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_student_number VARCHAR(10);
BEGIN
    UPDATE clinic.users u
    SET is_active = FALSE
    WHERE u.user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User % does not exist', p_user_id;
    END IF;

    SELECT s.student_number INTO v_student_number
    FROM clinic.students s
    WHERE s.user_id = p_user_id;

    IF v_student_number IS NOT NULL THEN
        UPDATE clinic.qr_codes q
        SET is_active = FALSE
        WHERE q.student_number = v_student_number;
    END IF;

    UPDATE clinic.user_session us
    SET revoked_at = COALESCE(us.revoked_at, NOW())
    WHERE us.user_id = p_user_id
      AND us.revoked_at IS NULL;

    RETURN QUERY SELECT p_user_id, v_student_number, 'account_deactivated'::TEXT;
END;
$$;

-- ============================================================================
-- 2.0 Check In Student (QR)
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_check_in_qr(p_qr_token UUID)
RETURNS SETOF clinic.v_dfd_qr_checkin_context
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
    SELECT *
    FROM clinic.v_dfd_qr_checkin_context
    WHERE qr_token = p_qr_token;
$$;

-- ============================================================================
-- 3.0 Record Consultation
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_save_consultation(
    p_consultation_id INT DEFAULT NULL,
    p_student_number VARCHAR(10) DEFAULT NULL,
    p_attended_by INT DEFAULT NULL,
    p_chief_complaint TEXT DEFAULT NULL,
    p_diagnosis TEXT DEFAULT '',
    p_treatment_notes TEXT DEFAULT NULL,
    p_vitals_bp VARCHAR(10) DEFAULT NULL,
    p_vitals_temp DECIMAL(4,1) DEFAULT NULL,
    p_vitals_pulse INT DEFAULT NULL,
    p_vitals_weight DECIMAL(5,1) DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT 'ongoing'
)
RETURNS INT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_consultation_id INT;
BEGIN
    IF p_consultation_id IS NULL THEN
        IF p_student_number IS NULL OR p_attended_by IS NULL THEN
            RAISE EXCEPTION 'student_number and attended_by are required for a new consultation';
        END IF;

        INSERT INTO clinic.consultations (
            student_number, attended_by, chief_complaint, diagnosis, treatment_notes,
            vitals_bp, vitals_temp, vitals_pulse, vitals_weight, status
        )
        VALUES (
            p_student_number, p_attended_by, p_chief_complaint,
            clinic.encrypt_data(COALESCE(p_diagnosis, '')),
            clinic.encrypt_data(p_treatment_notes),
            p_vitals_bp, p_vitals_temp, p_vitals_pulse, p_vitals_weight, p_status
        )
        RETURNING consultation_id INTO v_consultation_id;
    ELSE
        UPDATE clinic.consultations c
        SET chief_complaint = COALESCE(p_chief_complaint, c.chief_complaint),
            diagnosis = CASE WHEN p_diagnosis IS NULL THEN c.diagnosis ELSE clinic.encrypt_data(p_diagnosis) END,
            treatment_notes = CASE WHEN p_treatment_notes IS NULL THEN c.treatment_notes ELSE clinic.encrypt_data(p_treatment_notes) END,
            vitals_bp = COALESCE(p_vitals_bp, c.vitals_bp),
            vitals_temp = COALESCE(p_vitals_temp, c.vitals_temp),
            vitals_pulse = COALESCE(p_vitals_pulse, c.vitals_pulse),
            vitals_weight = COALESCE(p_vitals_weight, c.vitals_weight),
            status = COALESCE(p_status, c.status)
        WHERE c.consultation_id = p_consultation_id
        RETURNING c.consultation_id INTO v_consultation_id;

        IF v_consultation_id IS NULL THEN
            RAISE EXCEPTION 'Consultation % does not exist', p_consultation_id;
        END IF;
    END IF;

    RETURN v_consultation_id;
END;
$$;

-- ============================================================================
-- 4.0 Issue Prescription
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_issue_prescription(
    p_consultation_id INT,
    p_prescribed_by INT,
    p_prescription_details TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_prescription_id INT;
BEGIN
    INSERT INTO clinic.prescriptions (consultation_id, prescribed_by, prescription_details, notes)
    VALUES (
        p_consultation_id,
        p_prescribed_by,
        clinic.encrypt_data(p_prescription_details),
        clinic.encrypt_data(p_notes)
    )
    RETURNING prescription_id INTO v_prescription_id;

    RETURN v_prescription_id;
END;
$$;

-- ============================================================================
-- 5.0 Dispense Medicine
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_dispense_medicine(
    p_consultation_id INT,
    p_medicine_id INT,
    p_quantity_given INT,
    p_dispensed_by INT DEFAULT NULL
)
RETURNS TABLE (dispense_id INT, remaining_quantity INT, result TEXT)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_available INT;
    v_dispense_id INT;
    v_remaining INT;
BEGIN
    IF p_quantity_given <= 0 THEN
        RAISE EXCEPTION 'quantity_given must be greater than zero';
    END IF;

    SELECT m.available_quantity INTO v_available
    FROM clinic.medicines m
    WHERE m.medicine_id = p_medicine_id
    FOR UPDATE;

    IF v_available IS NULL THEN
        RAISE EXCEPTION 'Medicine % does not exist', p_medicine_id;
    END IF;

    IF v_available < p_quantity_given THEN
        RAISE EXCEPTION 'Insufficient medicine quantity. Available %, requested %', v_available, p_quantity_given;
    END IF;

    INSERT INTO clinic.consultation_medicines (
        consultation_id, medicine_id, quantity_given, dispensed_by
    )
    VALUES (p_consultation_id, p_medicine_id, p_quantity_given, p_dispensed_by)
    RETURNING id INTO v_dispense_id;

    UPDATE clinic.medicines m
    SET available_quantity = m.available_quantity - p_quantity_given
    WHERE m.medicine_id = p_medicine_id
    RETURNING m.available_quantity INTO v_remaining;

    RETURN QUERY SELECT v_dispense_id, v_remaining, 'medicine_dispensed'::TEXT;
END;
$$;

-- ============================================================================
-- 6.0 Manage Health Clearance
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_request_clearance(
    p_student_number VARCHAR(10),
    p_requested_by INT,
    p_purpose VARCHAR(100) DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
DECLARE
    v_clearance_id INT;
BEGIN
    INSERT INTO clinic.health_clearances (student_number, requested_by, purpose, status)
    VALUES (p_student_number, p_requested_by, p_purpose, 'pending')
    RETURNING clearance_id INTO v_clearance_id;

    RETURN v_clearance_id;
END;
$$;

CREATE OR REPLACE FUNCTION clinic.dfd_decide_clearance(
    p_clearance_id INT,
    p_issued_by INT,
    p_status VARCHAR(20),
    p_remarks TEXT DEFAULT NULL,
    p_valid_until DATE DEFAULT NULL
)
RETURNS TABLE (clearance_id INT, status VARCHAR(20), result TEXT)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
BEGIN
    IF p_status NOT IN ('cleared', 'not_cleared', 'pending') THEN
        RAISE EXCEPTION 'Invalid clearance status %', p_status;
    END IF;

    UPDATE clinic.health_clearances hc
    SET issued_by = p_issued_by,
        status = p_status,
        remarks = p_remarks,
        valid_until = p_valid_until
    WHERE hc.clearance_id = p_clearance_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Clearance % does not exist', p_clearance_id;
    END IF;

    RETURN QUERY SELECT p_clearance_id, p_status, 'clearance_recorded'::TEXT;
END;
$$;

-- ============================================================================
-- 7.0 View Medical History
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_student_medical_history(p_student_user_id INT DEFAULT NULL)
RETURNS SETOF clinic.v_student_medical_history
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
    SELECT *
    FROM clinic.v_student_medical_history
    WHERE p_student_user_id IS NULL
       OR p_student_user_id = clinic.current_app_user_id();
$$;

-- ============================================================================
-- 8.0 Authentication & Portal Access
-- ============================================================================

CREATE OR REPLACE FUNCTION clinic.dfd_route_user_portal(p_session_token_hash CHAR(64))
RETURNS TABLE (
    user_id INT,
    username VARCHAR(50),
    role VARCHAR(20),
    portal VARCHAR(30),
    session_id BIGINT,
    expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = clinic, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        touched.user_id,
        touched.username,
        touched.role,
        CASE touched.role
            WHEN 'admin' THEN 'admin_portal'
            WHEN 'nurse' THEN 'clinic_staff_portal'
            WHEN 'doctor' THEN 'doctor_portal'
            WHEN 'faculty' THEN 'faculty_portal'
            WHEN 'student' THEN 'student_portal'
        END::VARCHAR(30) AS portal,
        touched.session_id,
        touched.expires_at
    FROM clinic.auth_touch_session(p_session_token_hash) AS touched;
END;
$$;

GRANT SELECT ON
    clinic.v_dfd_account_details,
    clinic.v_dfd_qr_checkin_context,
    clinic.v_dfd_consultation_context,
    clinic.v_dfd_prescription_context,
    clinic.v_dfd_dispense_context,
    clinic.v_dfd_clearance_context,
    clinic.v_dfd_active_sessions
TO clinic_app;

GRANT EXECUTE ON FUNCTION clinic.dfd_add_account(
    VARCHAR(50), VARCHAR(255), VARCHAR(100), VARCHAR(100), VARCHAR(100), VARCHAR(20),
    VARCHAR(10), SMALLINT, DATE, VARCHAR(10), VARCHAR(20), VARCHAR(100), VARCHAR(20),
    VARCHAR(20), VARCHAR(20), VARCHAR(5), TEXT
) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_update_account(
    INT, VARCHAR(100), VARCHAR(100), VARCHAR(100), BOOLEAN, DATE, VARCHAR(10), VARCHAR(20),
    VARCHAR(100), VARCHAR(20), VARCHAR(20), VARCHAR(20), VARCHAR(5), TEXT, BOOLEAN
) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_deactivate_account(INT) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_check_in_qr(UUID) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_save_consultation(
    INT, VARCHAR(10), INT, TEXT, TEXT, TEXT, VARCHAR(10), NUMERIC, INT, NUMERIC, VARCHAR(20)
) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_issue_prescription(INT, INT, TEXT, TEXT) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_dispense_medicine(INT, INT, INT, INT) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_request_clearance(VARCHAR(10), INT, VARCHAR(100)) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_decide_clearance(INT, INT, VARCHAR(20), TEXT, DATE) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_student_medical_history(INT) TO clinic_app;
GRANT EXECUTE ON FUNCTION clinic.dfd_route_user_portal(CHAR(64)) TO clinic_app;
