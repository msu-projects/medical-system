# System Usage Guide — PostgreSQL

Concise SQL simulation for each Level 1 DFD process in `docs/dfd_level_1.md`.

## Setup

Run scripts in order, then seed demo data:

```sql
-- shell
-- psql -U postgres -d school_clinic_db -f database/postgres/01_init.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/02_tables.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/03_encryption.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/04_rls_policies.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/05_views.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/06_grants.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/07_audit.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/08_seed.sql
-- psql -U postgres -d school_clinic_db -f database/postgres/10_auth_helpers.sql
```

Demo password for seeded users: `password123`.

Common users: `admin`, `nurse.garcia`, `nurse.cruz`, `dr.santos`, `dr.reyes`, `prof.luna`, `juan.delacruz`, `maria.clara`.

## 8.0 Authentication & Portal Access

App gets login data, verifies bcrypt password, creates session, then uses hashed token per request.

```sql
-- 8.1-8.3: lookup active account. App verifies password_hash with bcrypt.
SELECT * FROM clinic.auth_get_login_user('nurse.garcia');

-- 8.4: create session after password is verified by app.
SELECT *
FROM clinic.auth_create_session(
  4,
  repeat('a', 64),
  now() + interval '8 hours',
  '127.0.0.1'::inet,
  'SQL demo'
);

-- 8.5: restore request context from session token hash.
SELECT * FROM clinic.auth_touch_session(repeat('a', 64));
SELECT clinic.current_app_user_id(), clinic.current_app_role();

-- Logout.
SELECT * FROM clinic.auth_revoke_session(repeat('a', 64));
```

## 1.0 Manage Accounts

Admin creates, reads, updates, and deactivates accounts.

```sql
SET ROLE clinic_admin;
SET app.current_user_id = '1';

-- Add student account.
WITH new_user AS (
  INSERT INTO clinic.users (username, password_hash, email, first_name, last_name, role)
  VALUES ('luna.student', crypt('password123', gen_salt('bf')), 'luna@student.school.edu', 'Luna', 'Santos', 'student')
  RETURNING user_id
), new_student AS (
  INSERT INTO clinic.students (
    user_id, year_of_enrollment, date_of_birth, sex, contact_number,
    emergency_contact_name, emergency_contact_number, year_level, section, blood_type, allergies
  )
  SELECT user_id, 2024, '2010-09-09', 'Female', '09170000009',
         'Rosa Santos', '09180000009', 'Grade 8', 'Section F', 'O+', 'None'
  FROM new_user
  RETURNING student_number
)
INSERT INTO clinic.qr_codes (student_number)
SELECT student_number FROM new_student
RETURNING qr_token, student_number;
```

```sql
-- Read account with student and QR data.
SELECT *
FROM clinic.v_admin_user_overview
WHERE username = 'luna.student';

-- Update account and student profile.
UPDATE clinic.users
SET email = 'luna.santos@student.school.edu'
WHERE username = 'luna.student';

UPDATE clinic.students
SET contact_number = '09171112222', allergies = 'Peanuts'
WHERE user_id = (SELECT user_id FROM clinic.users WHERE username = 'luna.student');

-- Deactivate account and QR token.
UPDATE clinic.users SET is_active = false WHERE username = 'luna.student';
UPDATE clinic.qr_codes
SET is_active = false
WHERE student_number = (
  SELECT student_number FROM clinic.students WHERE user_id = (SELECT user_id FROM clinic.users WHERE username = 'luna.student')
);

RESET ROLE;
```

## 2.0 Check In Student (QR)

Nurse scans QR token and opens student context.

```sql
SET ROLE clinic_nurse;
SET app.current_user_id = '4';

-- Pick seeded QR token for Juan Dela Cruz.
SELECT qr_token FROM clinic.qr_codes WHERE student_number = '2024-0001' AND is_active = true;

-- Simulate scanned QR lookup.
SELECT *
FROM clinic.v_qr_checkin
WHERE qr_token = (SELECT qr_token FROM clinic.qr_codes WHERE student_number = '2024-0001');

RESET ROLE;
```

## 3.0 Record Consultation

Nurse records complaint, vitals, diagnosis, and treatment notes.

```sql
SET ROLE clinic_nurse;
SET app.current_user_id = '4';

WITH new_consultation AS (
  SELECT clinic.create_consultation(
    '2024-0001',
    4,
    'Headache after morning class',
    'Tension headache',
    'Rested in clinic for 30 minutes. Advised hydration and meal intake.',
    '116/74',
    36.8,
    78,
    58.5
  ) AS consultation_id
)
UPDATE clinic.consultations
SET status = 'completed'
WHERE consultation_id = (SELECT consultation_id FROM new_consultation)
RETURNING consultation_id, status;

RESET ROLE;
```

## 4.0 Issue Prescription

Doctor validates consultation reference and records encrypted prescription.

```sql
SET ROLE clinic_doctor;
SET app.current_user_id = '2';

-- Doctor reviews consultation.
SELECT consultation_id, student_number, chief_complaint, status
FROM clinic.consultations
WHERE student_number = '2024-0003'
ORDER BY check_in_time DESC;

-- Issue prescription for seeded consultation 3.
SELECT clinic.create_prescription(
  3,
  2,
  'Ibuprofen 200mg — 1 tablet every 8 hours for 5 days with food.',
  'Follow up in 1 week if swelling continues.'
) AS prescription_id;

RESET ROLE;
```

## 5.0 Dispense Medicine

Nurse checks catalog, records dispensing, and updates stock.

```sql
SET ROLE clinic_nurse;
SET app.current_user_id = '4';

-- Medicine catalog.
SELECT medicine_id, name, unit, available_quantity
FROM clinic.medicines
WHERE available_quantity > 0
ORDER BY name;

-- Dispense Paracetamol for consultation 1.
INSERT INTO clinic.consultation_medicines (consultation_id, medicine_id, quantity_given, dispensed_by)
VALUES (1, 1, 2, 4);

UPDATE clinic.medicines
SET available_quantity = available_quantity - 2
WHERE medicine_id = 1 AND available_quantity >= 2;

RESET ROLE;
```

## 6.0 Manage Health Clearance

Faculty requests clearance; doctor or nurse records decision.

```sql
SET ROLE clinic_faculty;
SET app.current_user_id = '11';

-- Faculty request.
INSERT INTO clinic.health_clearances (student_number, purpose, requested_by)
VALUES ('2024-0002', 'Science fair travel — May 2026', 11)
RETURNING clearance_id, status;

-- Use returned clearance_id in doctor update below.

RESET ROLE;

SET ROLE clinic_doctor;
SET app.current_user_id = '2';

-- Doctor reviews medical context.
SELECT * FROM clinic.v_doctor_consultations WHERE student_number = '2024-0002';

-- Doctor clears request.
UPDATE clinic.health_clearances
SET status = 'cleared', issued_by = 2, valid_until = '2026-05-31', remarks = 'Fit for participation'
WHERE clearance_id = 6; -- replace with returned clearance_id

RESET ROLE;
```

## 7.0 View Medical History

Student logs in and sees own consultations, prescriptions, and dispensed medicines only.

```sql
SET ROLE clinic_student;
SET app.current_user_id = '6'; -- Juan Dela Cruz

SELECT consultation_id, check_in_time, chief_complaint, diagnosis,
       prescription_details, medicine_name, quantity_given
FROM clinic.v_student_medical_history
ORDER BY check_in_time DESC;

RESET ROLE;
```

## Quick Verification

```sql
SELECT role, count(*) FROM clinic.users GROUP BY role ORDER BY role;
SELECT count(*) AS students FROM clinic.students;
SELECT count(*) AS consultations FROM clinic.consultations;
SELECT count(*) AS prescriptions FROM clinic.prescriptions;
SELECT count(*) AS clearances FROM clinic.health_clearances;
```
