# System Usage Guide — MySQL

Concise SQL simulation for each Level 1 DFD process in `docs/dfd_level_1.md`.

## Setup

Run scripts in order, then seed demo data:

```sql
-- shell
-- mysql -u root -p < database/mysql/01_init.sql
-- mysql -u root -p school_clinic < database/mysql/02_tables.sql
-- mysql -u root -p school_clinic < database/mysql/03_encryption.sql
-- mysql -u root -p school_clinic < database/mysql/04_rls_policies.sql
-- mysql -u root -p school_clinic < database/mysql/05_views.sql
-- mysql -u root -p school_clinic < database/mysql/06_grants.sql
-- mysql -u root -p school_clinic < database/mysql/07_audit.sql
-- mysql -u root -p school_clinic < database/mysql/08_seed.sql
-- mysql -u root -p school_clinic < database/mysql/10_auth_helpers.sql
```

Demo password for seeded users: `password123`.

Common users: `admin`, `nurse.garcia`, `nurse.cruz`, `dr.santos`, `dr.reyes`, `prof.luna`, `juan.delacruz`, `maria.clara`.

```sql
USE school_clinic;
```

## 8.0 Authentication & Portal Access

App gets login data, verifies bcrypt password, creates session, then uses hashed token per request.

```sql
-- 8.1-8.3: lookup active account. App verifies password_hash with bcrypt.
CALL auth_get_login_user('nurse.garcia');

-- 8.4: create session after password is verified by app.
CALL auth_create_session(
  4,
  REPEAT('a', 64),
  DATE_ADD(NOW(), INTERVAL 8 HOUR),
  '127.0.0.1',
  'SQL demo'
);

-- 8.5: restore request context from session token hash.
CALL auth_touch_session(REPEAT('a', 64));
SELECT current_app_user_id(), current_app_role();

-- Logout.
CALL auth_revoke_session(REPEAT('a', 64));
```

## 1.0 Manage Accounts

Admin creates, reads, updates, and deactivates accounts.

```sql
SET @app_current_user_id = 1;
SET @app_current_role = 'admin';

-- Add student account.
INSERT INTO users (username, password_hash, email, first_name, last_name, role)
VALUES ('luna.student', '$2b$12$demo.hash.replace.in.app', 'luna@student.school.edu', 'Luna', 'Santos', 'student');

SET @new_user_id = LAST_INSERT_ID();

INSERT INTO students (
  user_id, year_of_enrollment, date_of_birth, sex, contact_number,
  emergency_contact_name, emergency_contact_number, year_level, section, blood_type, allergies
)
VALUES (@new_user_id, 2024, '2010-09-09', 'Female', '09170000009',
        'Rosa Santos', '09180000009', 'Grade 8', 'Section F', 'O+', 'None');

SET @new_student_number = (SELECT student_number FROM students WHERE user_id = @new_user_id);
INSERT INTO qr_codes (student_number) VALUES (@new_student_number);

-- Read account with student and QR data.
SELECT * FROM v_admin_user_overview WHERE username = 'luna.student';
SELECT * FROM qr_codes WHERE student_number = @new_student_number;

-- Update account and student profile.
UPDATE users SET email = 'luna.santos@student.school.edu' WHERE username = 'luna.student';
UPDATE students SET contact_number = '09171112222', allergies = 'Peanuts' WHERE user_id = @new_user_id;

-- Deactivate account and QR token.
UPDATE users SET is_active = FALSE WHERE username = 'luna.student';
UPDATE qr_codes SET is_active = FALSE WHERE student_number = @new_student_number;
```

## 2.0 Check In Student (QR)

Nurse scans QR token and opens student context.

```sql
SET @app_current_user_id = 4;
SET @app_current_role = 'nurse';

-- Pick seeded QR token for Juan Dela Cruz.
SELECT qr_token FROM qr_codes WHERE student_number = '2024-0001' AND is_active = TRUE;

-- Simulate scanned QR lookup.
SELECT *
FROM v_qr_checkin
WHERE qr_token = (SELECT qr_token FROM qr_codes WHERE student_number = '2024-0001' LIMIT 1);
```

## 3.0 Record Consultation

Nurse records complaint, vitals, diagnosis, and treatment notes.

```sql
SET @app_current_user_id = 4;
SET @app_current_role = 'nurse';

CALL create_consultation(
  '2024-0001',
  4,
  'Headache after morning class',
  'Tension headache',
  'Rested in clinic for 30 minutes. Advised hydration and meal intake.',
  '116/74',
  36.8,
  78,
  58.5,
  @consultation_id
);

SELECT @consultation_id AS consultation_id;

-- Update status after student leaves.
UPDATE consultations SET status = 'completed' WHERE consultation_id = @consultation_id;
```

## 4.0 Issue Prescription

Doctor validates consultation reference and records encrypted prescription.

```sql
SET @app_current_user_id = 2;
SET @app_current_role = 'doctor';

-- Doctor reviews consultation.
SELECT consultation_id, student_number, chief_complaint, status
FROM consultations
WHERE student_number = '2024-0003'
ORDER BY check_in_time DESC;

-- Issue prescription for seeded consultation 3.
CALL create_prescription(
  3,
  2,
  'Ibuprofen 200mg — 1 tablet every 8 hours for 5 days with food.',
  'Follow up in 1 week if swelling continues.',
  @prescription_id
);

SELECT @prescription_id AS prescription_id;
```

## 5.0 Dispense Medicine

Nurse checks catalog, records dispensing, and updates stock.

```sql
SET @app_current_user_id = 4;
SET @app_current_role = 'nurse';

-- Medicine catalog.
SELECT medicine_id, name, unit, available_quantity
FROM medicines
WHERE available_quantity > 0
ORDER BY name;

-- Dispense Paracetamol for consultation 1.
INSERT INTO consultation_medicines (consultation_id, medicine_id, quantity_given, dispensed_by)
VALUES (1, 1, 2, 4);

UPDATE medicines
SET available_quantity = available_quantity - 2
WHERE medicine_id = 1 AND available_quantity >= 2;
```

## 6.0 Manage Health Clearance

Faculty requests clearance; doctor or nurse records decision.

```sql
SET @app_current_user_id = 11;
SET @app_current_role = 'faculty';

-- Faculty request.
INSERT INTO health_clearances (student_number, purpose, requested_by)
VALUES ('2024-0002', 'Science fair travel — May 2026', 11);

SET @clearance_id = LAST_INSERT_ID();
SELECT clearance_id, status FROM health_clearances WHERE clearance_id = @clearance_id;

SET @app_current_user_id = 2;
SET @app_current_role = 'doctor';

-- Doctor reviews medical context.
SELECT * FROM v_doctor_consultations WHERE student_number = '2024-0002';

-- Doctor clears request.
UPDATE health_clearances
SET status = 'cleared', issued_by = 2, valid_until = '2026-05-31', remarks = 'Fit for participation'
WHERE clearance_id = @clearance_id;
```

## 7.0 View Medical History

Student logs in and sees own consultations, prescriptions, and dispensed medicines only.

```sql
SET @app_current_user_id = 6; -- Juan Dela Cruz
SET @app_current_role = 'student';

SELECT consultation_id, check_in_time, chief_complaint, diagnosis,
       prescription_details, medicine_name, quantity_given
FROM v_student_medical_history
ORDER BY check_in_time DESC;
```

## Quick Verification

```sql
SELECT role, count(*) FROM users GROUP BY role ORDER BY role;
SELECT count(*) AS students FROM students;
SELECT count(*) AS consultations FROM consultations;
SELECT count(*) AS prescriptions FROM prescriptions;
SELECT count(*) AS clearances FROM health_clearances;
```
