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
-- mysql -u root -p school_clinic < database/mysql/11_dfd_workflows.sql
```

Demo password for seeded users: `password123`.

Common users: `admin`, `nurse.garcia`, `nurse.cruz`, `dr.santos`, `dr.reyes`, `prof.luna`, `juan.delacruz`, `maria.clara`.

```sql
USE school_clinic;
SET @app_encryption_key = 'dev-secret-key-change-in-prod';
```

## 8.0 Authentication & Portal Access

App gets login data, verifies bcrypt password, creates session, then routes the user to the correct portal from the hashed session token.

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
CALL route_user_portal(REPEAT('a', 64));
SELECT current_app_user_id(), current_app_role();

-- Active session dashboard context.
SELECT * FROM v_active_sessions;

-- Logout.
CALL auth_revoke_session(REPEAT('a', 64));
```

## 1.0 Manage Accounts

Admin creates, reads, updates, and deactivates accounts through DFD workflow helpers.

```sql
SET @app_current_user_id = 1;
SET @app_current_role = 'admin';

-- Add student account.
CALL add_account(
  'luna.student',
  '$2b$12$demo.hash.replace.in.app',
  'luna@student.school.edu',
  'Luna',
  'Santos',
  'student',
  NULL,
  2024,
  '2010-09-09',
  'Female',
  '09170000009',
  'Rosa Santos',
  '09180000009',
  'Grade 8',
  'Section F',
  'O+',
  'None'
);

-- Read account with student and QR data.
SELECT * FROM v_account_details WHERE username = 'luna.student';

-- Update account and student profile.
SET @new_user_id = (SELECT user_id FROM users WHERE username = 'luna.student');
CALL update_account(
  @new_user_id,
  'luna.santos@student.school.edu',
  NULL,
  NULL,
  TRUE,
  NULL,
  NULL,
  '09171112222',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  'Peanuts',
  TRUE
);

-- Deactivate account and QR token.
CALL deactivate_account(@new_user_id);
```

## 2.0 Check In Student (QR)

Nurse scans QR token and opens student context.

```sql
SET @app_current_user_id = 4;
SET @app_current_role = 'nurse';

-- Pick seeded QR token for Juan Dela Cruz.
SELECT qr_token FROM qr_codes WHERE student_number = '2024-0001' AND is_active = TRUE;

-- Simulate scanned QR lookup.
CALL check_in_qr((SELECT qr_token FROM qr_codes WHERE student_number = '2024-0001' LIMIT 1));
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

Nurse checks catalog, records dispensing, and updates stock in one workflow call.

```sql
SET @app_current_user_id = 4;
SET @app_current_role = 'nurse';

-- Medicine catalog.
SELECT medicine_id, name, unit, available_quantity
FROM medicines
WHERE available_quantity > 0
ORDER BY name;

-- Dispense Paracetamol for consultation 1.
CALL dispense_medicine(1, 1, 2, 4);

SELECT * FROM v_dispense_context WHERE consultation_id = 1;
```

## 6.0 Manage Health Clearance

Faculty requests clearance; doctor or nurse records decision through workflow helpers.

```sql
SET @app_current_user_id = 11;
SET @app_current_role = 'faculty';

-- Faculty request.
CALL request_clearance('2024-0002', 11, 'Science fair travel - May 2026');

SET @clearance_id = LAST_INSERT_ID();
SELECT * FROM v_clearance_context WHERE clearance_id = @clearance_id;

SET @app_current_user_id = 2;
SET @app_current_role = 'doctor';

-- Doctor reviews medical context.
SELECT * FROM v_doctor_consultations WHERE student_number = '2024-0002';

-- Doctor clears request.
CALL decide_clearance(@clearance_id, 2, 'cleared', 'Fit for participation', '2026-05-31');
```

## 7.0 View Medical History

Student logs in and sees own consultations, prescriptions, and dispensed medicines only.

```sql
SET @app_current_user_id = 6; -- Juan Dela Cruz
SET @app_current_role = 'student';

CALL student_medical_history();
```

## Quick Verification

```sql
SELECT role, count(*) FROM users GROUP BY role ORDER BY role;
SELECT count(*) AS students FROM students;
SELECT count(*) AS consultations FROM consultations;
SELECT count(*) AS prescriptions FROM prescriptions;
SELECT count(*) AS clearances FROM health_clearances;
```
