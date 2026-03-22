# Data Dictionary
## School Clinic Management System

**Database:** `school_clinic_db`
**Primary Schema:** `clinic`
**Audit Schema:** `audit`
**Last Updated:** 2026-02-22

---

## Table of Contents

1. [Tables](#tables)
   - [clinic.users](#1-clinicusers)
   - [clinic.students](#2-clinicstudents)
   - [clinic.qr_codes](#3-clinicqr_codes)
   - [clinic.consultations](#4-clinicconsultations)
   - [clinic.prescriptions](#5-clinicprescriptions)
   - [clinic.medicines](#6-clinicmedicines)
   - [clinic.consultation_medicines](#7-clinicconsultation_medicines)
   - [clinic.health_clearances](#8-clinichealth_clearances)
   - [audit.activity_log](#9-auditactivity_log)
2. [Views](#views)
3. [Relationships Diagram](#relationships-diagram)
4. [Encryption Notes](#encryption-notes)
5. [Indexes Summary](#indexes-summary)

---

## Tables

### 1. `clinic.users`

Stores all system accounts across every role. Passwords are **never** stored in plain text — only bcrypt hashes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `user_id` | `SERIAL` | PK | Auto-incrementing primary key |
| `username` | `VARCHAR(50)` | NOT NULL, UNIQUE | Login username |
| `password_hash` | `VARCHAR(255)` | NOT NULL | bcrypt hash generated in the application layer |
| `email` | `VARCHAR(100)` | — | User email address |
| `full_name` | `VARCHAR(100)` | NOT NULL | Display name |
| `role` | `VARCHAR(20)` | NOT NULL, CHECK | One of: `admin`, `nurse`, `doctor`, `student`, `faculty` |
| `is_active` | `BOOLEAN` | NOT NULL, DEFAULT `TRUE` | Whether the account is enabled |
| `last_login` | `TIMESTAMPTZ` | — | Timestamp of most recent login |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Last modification timestamp (auto-updated via trigger) |

**Indexes:** `idx_users_role`, `idx_users_username`, `idx_users_is_active`

---

### 2. `clinic.students`

Extended profile for users with `role = 'student'`. One-to-one with `clinic.users`. Contains demographics and medical baseline data.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `student_id` | `SERIAL` | PK | Auto-incrementing primary key |
| `user_id` | `INT` | NOT NULL, UNIQUE, FK → `users.user_id` | Links to the student's user account (CASCADE DELETE) |
| `student_number` | `VARCHAR(20)` | NOT NULL, UNIQUE | School-issued student ID number |
| `date_of_birth` | `DATE` | — | Date of birth |
| `sex` | `VARCHAR(10)` | CHECK | One of: `Male`, `Female`, `Other` |
| `contact_number` | `VARCHAR(20)` | — | Student's contact number |
| `emergency_contact_name` | `VARCHAR(100)` | — | Name of emergency contact |
| `emergency_contact_number` | `VARCHAR(20)` | — | Phone number of emergency contact |
| `year_level` | `VARCHAR(20)` | — | Academic year level (e.g., `Grade 11`) |
| `section` | `VARCHAR(20)` | — | Class section (e.g., `Stem-A`) |
| `blood_type` | `VARCHAR(5)` | CHECK | One of: `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-` |
| `allergies` | `TEXT` | — | Free-text field for known allergies |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Last modification timestamp (auto-updated via trigger) |

**Indexes:** `idx_students_student_number`, `idx_students_year_section`

---

### 3. `clinic.qr_codes`

Each student is assigned a unique UUID-based QR token for fast, non-guessable clinic check-in. The QR code image encodes only the `qr_token` — never the internal `student_id`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `qr_id` | `SERIAL` | PK | Auto-incrementing primary key |
| `student_id` | `INT` | NOT NULL, UNIQUE, FK → `students.student_id` | One QR code per student (CASCADE DELETE) |
| `qr_token` | `UUID` | NOT NULL, UNIQUE, DEFAULT `gen_random_uuid()` | UUID encoded in the physical QR code — prevents ID enumeration |
| `is_active` | `BOOLEAN` | NOT NULL, DEFAULT `TRUE` | Inactive tokens are rejected at check-in |
| `generated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | When the token was generated |

**Indexes:** `idx_qr_codes_token` (partial, `WHERE is_active = TRUE`)

---

### 4. `clinic.consultations`

The core medical record. One row is created per clinic visit. Sensitive clinical columns (`diagnosis`, `treatment_notes`) are stored **AES-256 encrypted** as `BYTEA` using pgcrypto.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `consultation_id` | `SERIAL` | PK | Auto-incrementing primary key |
| `student_id` | `INT` | NOT NULL, FK → `students.student_id` | The student being seen (RESTRICT DELETE) |
| `attended_by` | `INT` | NOT NULL, FK → `users.user_id` | Nurse or doctor who handled the consultation (RESTRICT DELETE) |
| `check_in_time` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | When the student checked in |
| `chief_complaint` | `TEXT` | — | Patient-reported symptoms (plain text) |
| `diagnosis` | `BYTEA` | NOT NULL | **Encrypted** — AES-256 via `pgp_sym_encrypt()`. Decrypt with `pgp_sym_decrypt(diagnosis, key)` |
| `treatment_notes` | `BYTEA` | — | **Encrypted** — internal clinical notes; deliberately hidden from students |
| `vitals_bp` | `VARCHAR(10)` | — | Blood pressure reading (e.g., `120/80`) |
| `vitals_temp` | `DECIMAL(4,1)` | — | Body temperature in °C |
| `vitals_pulse` | `INT` | — | Pulse rate in bpm |
| `vitals_weight` | `DECIMAL(5,1)` | — | Weight in kg |
| `status` | `VARCHAR(20)` | NOT NULL, DEFAULT `'ongoing'`, CHECK | One of: `ongoing`, `completed`, `referred` |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Last modification timestamp (auto-updated via trigger) |

> **Security:** `diagnosis` and `treatment_notes` are encrypted at rest. They must be decrypted in the application layer (or via the provided views) using the session encryption key (`app.encryption_key`). Vitals are stored as plain text and are not considered highly sensitive.

**Indexes:** `idx_consultations_student`, `idx_consultations_attended`, `idx_consultations_date`, `idx_consultations_status`

---

### 5. `clinic.prescriptions`

Doctor-issued medication orders linked to a consultation. `prescription_details` and `notes` are AES-256 encrypted. Only users with role `doctor` may create prescriptions.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `prescription_id` | `SERIAL` | PK | Auto-incrementing primary key |
| `consultation_id` | `INT` | NOT NULL, FK → `consultations.consultation_id` | The consultation this prescription belongs to (CASCADE DELETE) |
| `prescribed_by` | `INT` | NOT NULL, FK → `users.user_id` | The doctor who issued the prescription (RESTRICT DELETE) |
| `prescription_details` | `BYTEA` | NOT NULL | **Encrypted** — medication name, dosage, frequency, and duration |
| `notes` | `BYTEA` | — | **Encrypted** — additional doctor notes |
| `issued_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | When the prescription was issued |

**Indexes:** `idx_prescriptions_consultation`, `idx_prescriptions_doctor`

---

### 6. `clinic.medicines`

A basic catalog of medicines available at the clinic. Tracks names and units; does not perform full inventory tracking.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `medicine_id` | `SERIAL` | PK | Auto-incrementing primary key |
| `name` | `VARCHAR(100)` | NOT NULL | Medicine name (e.g., `Paracetamol 500mg`) |
| `description` | `TEXT` | — | Optional description or notes about the medicine |
| `unit` | `VARCHAR(20)` | NOT NULL, DEFAULT `'tablet'` | Dispensing unit (e.g., `tablet`, `capsule`, `ml`) |
| `is_available` | `BOOLEAN` | NOT NULL, DEFAULT `TRUE` | Whether the medicine is currently in stock |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Record creation timestamp |

**Indexes:** `idx_medicines_name`

---

### 7. `clinic.consultation_medicines`

Junction table that records which medicines were dispensed during a specific consultation, and in what quantity.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `SERIAL` | PK | Auto-incrementing primary key |
| `consultation_id` | `INT` | NOT NULL, FK → `consultations.consultation_id` | The consultation during which the medicine was given (CASCADE DELETE) |
| `medicine_id` | `INT` | NOT NULL, FK → `medicines.medicine_id` | The medicine that was dispensed (RESTRICT DELETE) |
| `quantity_given` | `INT` | NOT NULL, CHECK `> 0` | Number of units dispensed |
| `dispensed_by` | `INT` | FK → `users.user_id` | Staff member who dispensed the medicine (SET NULL on DELETE) |
| `dispensed_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Timestamp of dispensing |

**Indexes:** `idx_consult_med_consultation`, `idx_consult_med_medicine`

---

### 8. `clinic.health_clearances`

Records of health clearances and medical certificates. Faculty members may request a clearance for a student; a nurse or doctor reviews and issues it.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `clearance_id` | `SERIAL` | PK | Auto-incrementing primary key |
| `student_id` | `INT` | NOT NULL, FK → `students.student_id` | The student the clearance is for (CASCADE DELETE) |
| `issued_by` | `INT` | FK → `users.user_id` | Doctor or nurse who issued/evaluated the clearance (SET NULL on DELETE) |
| `purpose` | `VARCHAR(100)` | — | Reason for the clearance (e.g., `Sports Fest`, `ROTC`) |
| `remarks` | `TEXT` | — | Additional remarks from the issuing staff |
| `status` | `VARCHAR(20)` | NOT NULL, DEFAULT `'pending'`, CHECK | One of: `pending`, `cleared`, `not_cleared` |
| `valid_until` | `DATE` | — | Expiry date of the clearance |
| `requested_by` | `INT` | FK → `users.user_id` | Faculty member who requested the clearance (SET NULL on DELETE) |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | Last modification timestamp (auto-updated via trigger) |

**Indexes:** `idx_clearances_student`, `idx_clearances_status`

---

### 9. `audit.activity_log`

Immutable, append-only audit trail. Every `INSERT`, `UPDATE`, and `DELETE` on clinical tables is captured here by a generic trigger. No role may `UPDATE` or `DELETE` rows; only `clinic_admin` may `SELECT`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `log_id` | `BIGSERIAL` | PK | Auto-incrementing primary key |
| `table_schema` | `TEXT` | NOT NULL | Schema of the affected table (e.g., `clinic`) |
| `table_name` | `TEXT` | NOT NULL | Name of the affected table |
| `operation` | `TEXT` | NOT NULL, CHECK | One of: `INSERT`, `UPDATE`, `DELETE` |
| `old_data` | `JSONB` | — | Full previous row state as JSON — `NULL` for INSERT operations |
| `new_data` | `JSONB` | — | Full new row state as JSON — `NULL` for DELETE operations |
| `changed_fields` | `TEXT[]` | — | Array of column names that changed (UPDATE only) |
| `app_user_id` | `TEXT` | — | Application-level user ID from `set_config('app.current_user_id')` |
| `db_user` | `TEXT` | NOT NULL, DEFAULT `current_user` | PostgreSQL database user at time of change |
| `db_role` | `TEXT` | NOT NULL, DEFAULT `session_user` | PostgreSQL session role at time of change |
| `client_ip` | `TEXT` | — | Client IP from `inet_client_addr()` — `NULL` for local connections |
| `changed_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT `NOW()` | When the change occurred |

**Indexes:** `idx_audit_table`, `idx_audit_operation`, `idx_audit_user`, `idx_audit_timestamp`, `idx_audit_composite`

---

## Views

All views are in the `clinic` schema. They provide role-appropriate data access with column masking and automatic decryption of encrypted fields.

| View | Access Level | Purpose |
|---|---|---|
| `v_student_medical_history` | Student (own records only) | Own consultation history with decrypted diagnosis. `treatment_notes` is deliberately excluded. |
| `v_faculty_clearance` | Faculty | Clearance status for requested students. No medical data exposed. |
| `v_nurse_dashboard` | Nurse / Clinic Staff | All consultations with full decrypted medical data, student profile, and vitals. Sorted by status (ongoing first). |
| `v_doctor_consultations` | Doctor | Full medical details including decrypted diagnosis, treatment notes, and linked prescriptions. |
| `v_admin_user_overview` | Admin | All user accounts. `password_hash` is deliberately excluded. |
| `v_qr_checkin` | Nurse / Clinic Staff | Resolves a scanned `qr_token` to a full student profile for fast check-in. Returns only active QR codes. |

---

## Relationships Diagram

```
users (1) ──────────── (1) students
                               │
                      (1) ─── qr_codes
                               │
                      (M) ─── consultations ─── (M) consultation_medicines ─── (M) medicines
                               │
                      (M) ─── prescriptions
                               │
                      (M) ─── health_clearances
```

| Relationship | Cardinality | Notes |
|---|---|---|
| `users` → `students` | 1:1 | Only `role = 'student'` users have a student record |
| `students` → `qr_codes` | 1:1 | Each student has exactly one QR code |
| `students` → `consultations` | 1:M | A student may have many consultation visits |
| `consultations` → `prescriptions` | 1:M | A single visit may generate multiple prescriptions |
| `consultations` → `consultation_medicines` | 1:M | Multiple medicines can be dispensed per visit |
| `medicines` → `consultation_medicines` | 1:M | The same medicine can be dispensed across many visits |
| `students` → `health_clearances` | 1:M | A student can have multiple clearance records over time |
| `users` → `consultations` (`attended_by`) | 1:M | A nurse/doctor attends many consultations |
| `users` → `prescriptions` (`prescribed_by`) | 1:M | A doctor issues many prescriptions |
| `users` → `health_clearances` (`issued_by`, `requested_by`) | 1:M | Staff issue clearances; faculty request them |

---

## Encryption Notes

Two columns in `clinic.consultations` and two in `clinic.prescriptions` are stored encrypted using **pgcrypto AES-256 (`pgp_sym_encrypt`)**.

| Table | Encrypted Column | Reason |
|---|---|---|
| `consultations` | `diagnosis` | Protected health information (PHI) |
| `consultations` | `treatment_notes` | Internal clinical observations — not shown to patients |
| `prescriptions` | `prescription_details` | Medication orders — PHI |
| `prescriptions` | `notes` | Doctor's private prescription notes — PHI |

**Decryption:** Done transparently via the role-based views using the `clinic.decrypt_data()` helper function, which reads the encryption key from the session variable `app.encryption_key`. Raw `BYTEA` values should never be read directly by application code.

---

## Indexes Summary

| Index Name | Table | Column(s) | Notes |
|---|---|---|---|
| `idx_users_role` | `users` | `role` | Filter by role |
| `idx_users_username` | `users` | `username` | Login lookup |
| `idx_users_is_active` | `users` | `is_active` | Active account filtering |
| `idx_students_student_number` | `students` | `student_number` | Student ID search |
| `idx_students_year_section` | `students` | `year_level, section` | Class list queries |
| `idx_qr_codes_token` | `qr_codes` | `qr_token` | Partial — active tokens only |
| `idx_consultations_student` | `consultations` | `student_id` | Patient history lookup |
| `idx_consultations_attended` | `consultations` | `attended_by` | Staff workload queries |
| `idx_consultations_date` | `consultations` | `check_in_time` | Date range queries |
| `idx_consultations_status` | `consultations` | `status` | Dashboard: ongoing visits |
| `idx_prescriptions_consultation` | `prescriptions` | `consultation_id` | Join with consultations |
| `idx_prescriptions_doctor` | `prescriptions` | `prescribed_by` | Doctor prescription history |
| `idx_medicines_name` | `medicines` | `name` | Medicine catalog search |
| `idx_consult_med_consultation` | `consultation_medicines` | `consultation_id` | Join with consultations |
| `idx_consult_med_medicine` | `consultation_medicines` | `medicine_id` | Medicine usage queries |
| `idx_clearances_student` | `health_clearances` | `student_id` | Student clearance history |
| `idx_clearances_status` | `health_clearances` | `status` | Pending clearance queue |
| `idx_audit_table` | `activity_log` | `table_schema, table_name` | Filter by audited table |
| `idx_audit_operation` | `activity_log` | `operation` | Filter by operation type |
| `idx_audit_user` | `activity_log` | `app_user_id` | Audit trail per user |
| `idx_audit_timestamp` | `activity_log` | `changed_at` | Time-range audit queries |
| `idx_audit_composite` | `activity_log` | `table_name, changed_at DESC` | Recent changes per table |
