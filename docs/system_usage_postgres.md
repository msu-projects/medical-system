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
-- psql -U postgres -d school_clinic_db -f database/postgres/11_dfd_workflows.sql
```

Demo password for seeded users: `password123`.

Common users: `admin`, `nurse.garcia`, `nurse.cruz`, `dr.santos`, `dr.reyes`, `prof.luna`, `juan.delacruz`, `maria.clara`.

```sql
SELECT set_config('app.encryption_key', 'dev-secret-key-change-in-prod', false);
```

## 8.0 Authentication & Portal Access

App gets login data, verifies bcrypt password, creates session, then routes the user to the correct portal from the hashed session token.

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
SELECT * FROM clinic.route_user_portal(repeat('a', 64));
SELECT clinic.current_app_user_id(), clinic.current_app_role();

-- Active session dashboard context.
SELECT * FROM clinic.v_active_sessions;

-- Logout.
SELECT * FROM clinic.auth_revoke_session(repeat('a', 64));
```

## 1.0 Manage Accounts

Admin creates, reads, updates, and deactivates accounts through DFD workflow helpers.

```sql
SET ROLE clinic_admin;
SET app.current_user_id = '1';

-- Add student account.
WITH new_user AS (
  SELECT *
  FROM clinic.add_account(
    'luna.student',
    crypt('password123', gen_salt('bf')),
    'luna@student.school.edu',
    'Luna',
    'Santos',
    'student',
    NULL,
    2024::smallint,
    '2010-09-09',
    'Female',
    '09170000009',
    'Rosa Santos',
    '09180000009',
    'Grade 8',
    'Section F',
    'O+',
    'None'
  )
)
SELECT user_id, student_number, qr_token, result FROM new_user;
```

```sql
-- Read account with student and QR data.
SELECT *
FROM clinic.v_account_details
WHERE username = 'luna.student';

-- Update account and student profile.
SELECT *
FROM clinic.update_account(
  (SELECT user_id FROM clinic.users WHERE username = 'luna.student'),
  'luna.santos@student.school.edu',
  NULL,
  NULL,
  true,
  NULL,
  NULL,
  '09171112222',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  'Peanuts',
  true
);

-- Deactivate account and QR token.
SELECT *
FROM clinic.deactivate_account(
  (SELECT user_id FROM clinic.users WHERE username = 'luna.student')
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
FROM clinic.check_in_qr(
  (SELECT qr_token FROM clinic.qr_codes WHERE student_number = '2024-0001')
);

-- Same data is available as workflow context.
SELECT *
FROM clinic.v_qr_checkin_context
WHERE qr_token = (SELECT qr_token FROM clinic.qr_codes WHERE student_number = '2024-0001');

RESET ROLE;
```

## 3.0 Record Consultation

Nurse records complaint, vitals, diagnosis, and treatment notes.

```sql
SET ROLE clinic_nurse;
SET app.current_user_id = '4';

WITH new_consultation AS (
  SELECT clinic.save_consultation(
    NULL,
    '2024-0001',
    4,
    'Headache after morning class',
    'Tension headache',
    'Rested in clinic for 30 minutes. Advised hydration and meal intake.',
    '116/74',
    36.8,
    78,
    58.5,
    'ongoing'
  ) AS consultation_id
)
SELECT clinic.save_consultation(
  consultation_id,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  'completed'
) AS completed_consultation_id
FROM new_consultation;

SELECT *
FROM clinic.v_consultation_context
WHERE student_number = '2024-0001'
ORDER BY check_in_time DESC;

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
SELECT clinic.issue_prescription(
  3,
  2,
  'Ibuprofen 200mg - 1 tablet every 8 hours for 5 days with food.',
  'Follow up in 1 week if swelling continues.'
) AS prescription_id;

SELECT * FROM clinic.v_prescription_context WHERE consultation_id = 3;

RESET ROLE;
```

## 5.0 Dispense Medicine

Nurse checks catalog, records dispensing, and updates stock in one workflow call.

```sql
SET ROLE clinic_nurse;
SET app.current_user_id = '4';

-- Medicine catalog.
SELECT medicine_id, name, unit, available_quantity
FROM clinic.medicines
WHERE available_quantity > 0
ORDER BY name;

-- Dispense Paracetamol for consultation 1.
SELECT * FROM clinic.dispense_medicine(1, 1, 2, 4);

SELECT * FROM clinic.v_dispense_context WHERE consultation_id = 1;

RESET ROLE;
```

## 6.0 Manage Health Clearance

Faculty requests clearance; doctor or nurse records decision through workflow helpers.

```sql
SET ROLE clinic_faculty;
SET app.current_user_id = '11';

-- Faculty request.
SELECT clinic.request_clearance('2024-0002', 11, 'Science fair travel - May 2026') AS clearance_id;

RESET ROLE;

SET ROLE clinic_doctor;
SET app.current_user_id = '2';

-- Doctor reviews medical context.
SELECT * FROM clinic.v_doctor_consultations WHERE student_number = '2024-0002';

-- Doctor clears request.
SELECT *
FROM clinic.decide_clearance(
  6, -- replace with returned clearance_id
  2,
  'cleared',
  'Fit for participation',
  '2026-05-31'
);

SELECT * FROM clinic.v_clearance_context WHERE clearance_id = 6;

RESET ROLE;
```

## 7.0 View Medical History

Student logs in and sees own consultations, prescriptions, and dispensed medicines only.

```sql
SET ROLE clinic_student;
SET app.current_user_id = '6'; -- Juan Dela Cruz

SELECT *
FROM clinic.student_medical_history();

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
