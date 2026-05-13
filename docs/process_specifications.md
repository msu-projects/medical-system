# Process Specifications

## School Clinic Management System

**System:** School Clinic Management System
**Database:** `school_clinic_db` / Schema: `clinic`
**Last Updated:** 2026-05-13

---

## Table of Contents

1. [P1 — Authentication & Portal Access](#p1--authentication--portal-access)
2. [P2 — QR Code Check-in System](#p2--qr-code-check-in-system)
3. [P3 — Consultation Management](#p3--consultation-management)
4. [P4 — Prescription & Dispensing](#p4--prescription--dispensing)
5. [P5 — Health Clearance Management](#p5--health-clearance-management)
6. [P6 — System & User Administration](#p6--system--user-administration)
7. [P7 — View Medical History](#p7--view-medical-history)

---

## P1 — Authentication & Portal Access

**Process ID:** P1
**Process Name:** Authentication & Portal Access
**Module:** Web Application (Login Portal)
**Triggered By:** Any user (Student, Clinic Staff, Doctor, Faculty, System Admin) attempting to access the system

### Description

Validates user credentials against stored account records. On success, establishes a session and routes the user to the role-appropriate dashboard. On failure, returns an informative error without disclosing whether the username or password was incorrect (to prevent enumeration).

### Inputs

| Input                   | Source            | Format              |
| ----------------------- | ----------------- | ------------------- |
| `username`              | User (login form) | `VARCHAR(50)`       |
| `password` (plain text) | User (login form) | String (not stored) |

### Processing Logic

1. Receive `username` and `password` from the login form.
2. Query `clinic.users` for a record matching the provided `username` where `is_active = TRUE`.
3. If no active record is found, return a generic authentication error — do **not** specify whether the username or password was wrong.
4. Compare the submitted password against the stored `password_hash` using **bcrypt**.
5. If the hash comparison fails, return the same generic authentication error.
6. On success:
   - Update `last_login` in `clinic.users` to `NOW()`.
   - Write a login event to `audit.activity_log`.
   - Create and return a session token containing `user_id` and `role`.
7. Route the user to the dashboard corresponding to their `role`:
   - `admin` → Admin Panel (P6)
   - `nurse` → Clinic Staff Dashboard (P3, P4)
   - `doctor` → Doctor Module (P3, P4)
   - `student` → Student Portal
   - `faculty` → Faculty Portal (P5)

### Outputs

| Output               | Destination          | Description                             |
| -------------------- | -------------------- | --------------------------------------- |
| Session token + role | All users            | Grants access to the appropriate portal |
| Authentication error | All users            | Generic error on credential mismatch    |
| `last_login` update  | `clinic.users`       | Timestamp of the successful login       |
| Audit entry          | `audit.activity_log` | Records login event                     |

### Business Rules

- Passwords must **never** be stored in plain text. Only bcrypt hashes are persisted.
- Accounts with `is_active = FALSE` are immediately rejected at step 2 — no hash comparison is performed.
- Login error messages must not reveal which field (username or password) was incorrect.
- Session tokens must carry the minimum required claims: `user_id` and `role`.

### Data Stores Accessed

| Store                | Operation                                      |
| -------------------- | ---------------------------------------------- |
| `clinic.users`       | READ (credential lookup), WRITE (`last_login`) |
| `audit.activity_log` | WRITE (login event)                            |

---

## P2 — QR Code Check-in System

**Process ID:** P2
**Process Name:** QR Code Check-in System
**Module:** Scanner Application (Clinic Front Desk)
**Triggered By:** Clinic Staff scanning a student's QR code at the clinic entrance

### Description

Resolves a scanned QR token to a student record and presents the student's profile to clinic staff, enabling fast check-in without manual searching. The QR code encodes only a UUID token — never a guessable internal ID.

### Inputs

| Input                      | Source                                  | Format        |
| -------------------------- | --------------------------------------- | ------------- |
| QR code image              | Student (physical card / device screen) | Image         |
| Scanned QR token (decoded) | QR scanner hardware/app                 | `UUID` string |

### Processing Logic

1. Decode the QR code image to extract the `qr_token` (UUID).
2. Query `clinic.qr_codes` for a record matching `qr_token` where `is_active = TRUE`.
3. If no active token is found, display an "Invalid or Inactive QR Code" error to clinic staff. Do **not** proceed.
4. Retrieve the associated `student_id` from the matched QR record.
5. Query `clinic.students` for the full student profile using the resolved `student_id`.
6. Display the student's demographics and baseline health data to clinic staff.
7. Prepare a new consultation record pre-filled with `student_id` and `check_in_time = NOW()` (handed off to P3).

### Outputs

| Output                                        | Destination                  | Description                                 |
| --------------------------------------------- | ---------------------------- | ------------------------------------------- |
| Student profile (demographics, baseline data) | Clinic Staff dashboard       | Displayed immediately after successful scan |
| Pre-filled consultation record                | P3 (Consultation Management) | Starts the consultation flow                |
| "Invalid QR Code" error                       | Clinic Staff                 | Shown when token is not found or inactive   |

### Business Rules

- QR codes encode only the `qr_token` UUID — the internal `student_id` is never embedded in the QR image.
- Inactive tokens (`is_active = FALSE`) are rejected and trigger an error.
- A student may only have one active QR code at a time (`UNIQUE` constraint on `student_id` in `clinic.qr_codes`).
- If a QR code is reported lost or compromised, staff must deactivate the existing token (`is_active = FALSE`) and generate a new UUID — the old token becomes permanently invalid.

### Data Stores Accessed

| Store             | Operation                                        |
| ----------------- | ------------------------------------------------ |
| `clinic.qr_codes` | READ (token validation, `student_id` resolution) |
| `clinic.students` | READ (profile retrieval)                         |

---

## P3 — Consultation Management

**Process ID:** P3
**Process Name:** Consultation Management
**Module:** Clinic Staff Dashboard / Doctor Module
**Triggered By:** Clinic staff initiating a consultation (after QR check-in via P2) or doctor reviewing/updating a patient record

### Description

Creates and manages consultation records for each clinic visit. Handles the recording of patient vitals and chief complaints by nursing staff, and the entry of diagnosis and treatment notes by doctors. Sensitive clinical data (`diagnosis`, `treatment_notes`) is encrypted at rest using AES-256 via pgcrypto.

### Inputs

| Input                                                       | Source                | Format                                     |
| ----------------------------------------------------------- | --------------------- | ------------------------------------------ |
| `student_id`, `check_in_time`                               | P2 (pre-filled)       | INT, TIMESTAMPTZ                           |
| `chief_complaint`                                           | Clinic Staff          | TEXT                                       |
| `vitals_bp`, `vitals_temp`, `vitals_pulse`, `vitals_weight` | Clinic Staff          | VARCHAR / DECIMAL / INT                    |
| `diagnosis`                                                 | School Doctor         | TEXT (encrypted before storage)            |
| `treatment_notes`                                           | School Doctor         | TEXT (encrypted before storage)            |
| `status` update                                             | Clinic Staff / Doctor | One of: `ongoing`, `completed`, `referred` |

### Processing Logic

1. Receive the pre-filled consultation record from P2 (`student_id`, `check_in_time`).
2. Clinic staff enter vitals (`vitals_bp`, `vitals_temp`, `vitals_pulse`, `vitals_weight`) and `chief_complaint`.
3. Save the initial consultation record to `clinic.consultations` with `status = 'ongoing'`.
4. When the doctor is ready:
   a. Retrieve and display the student's full consultation history (decrypting `diagnosis` fields using `pgp_sym_decrypt(diagnosis, app.encryption_key)`).
   b. Doctor enters `diagnosis` and `treatment_notes`.
   c. Encrypt both fields using `pgp_sym_encrypt(value, app.encryption_key)` before writing to the database.
5. Update the consultation record's `status` as appropriate (`completed` or `referred`).
6. On any INSERT or UPDATE, trigger a write to `audit.activity_log`.
7. Make the completed (non-sensitive) consultation logs available to the Student Portal (excluding `treatment_notes`).

### Outputs

| Output                                   | Destination            | Description                                                 |
| ---------------------------------------- | ---------------------- | ----------------------------------------------------------- |
| Consultation record                      | `clinic.consultations` | Full visit record with encrypted clinical data              |
| Patient medical history (decrypted view) | Doctor / Clinic Staff  | Displayed in the dashboard                                  |
| Personal consultation logs               | Student Portal         | History visible to the student (excludes `treatment_notes`) |
| Audit entry                              | `audit.activity_log`   | Records each create/update event                            |

### Business Rules

- `diagnosis` and `treatment_notes` **must** be encrypted with `pgp_sym_encrypt()` before any INSERT or UPDATE. Plaintext storage is not allowed.
- `treatment_notes` are clinical-only: they must **never** be exposed through the Student Portal.
- Every consultation is linked to both a `student_id` and the `attended_by` user ID (the nurse or doctor).
- Consultation records must not be deleted once created (referential integrity via `RESTRICT` on foreign keys).
- `status` must always be one of `ongoing`, `completed`, or `referred`.
- Vitals are stored as plain text and do not require encryption.

### Data Stores Accessed

| Store                  | Operation                                         |
| ---------------------- | ------------------------------------------------- |
| `clinic.consultations` | READ (history), WRITE (new record, status update) |
| `clinic.students`      | READ (profile context)                            |
| `audit.activity_log`   | WRITE (change events)                             |

---

## P4 — Prescription & Dispensing

**Process ID:** P4
**Process Name:** Prescription & Dispensing
**Module:** Doctor / Nurse Module
**Triggered By:** Doctor issuing a prescription during or after a consultation; Clinic Staff dispensing medicines from inventory

### Description

Manages the full prescription lifecycle: from a doctor issuing a prescription tied to a consultation, through clinic staff dispensing medicines from inventory, to updating stock levels. Both prescription data and dispensing records are persisted for full traceability. Prescription details are stored encrypted.

### Inputs

| Input                                                      | Source        | Format                                    |
| ---------------------------------------------------------- | ------------- | ----------------------------------------- |
| `consultation_id`, `prescribed_by`, `prescription_details` | School Doctor | INT, INT, TEXT (encrypted before storage) |
| `medicine_id`, `quantity_dispensed`, `dispensed_by`        | Clinic Staff  | INT, INT, INT                             |
| Medicine stock lookup request                              | P4 (internal) | —                                         |

### Processing Logic

1. **Prescription Issuance (Doctor):**
   a. Doctor selects a consultation and enters prescription details.
   b. Encrypt `prescription_details` using `pgp_sym_encrypt(value, app.encryption_key)`.
   c. Write a new record to `clinic.prescriptions` linked to the `consultation_id`.

2. **Medicine Dispensing (Clinic Staff):**
   a. Query `clinic.medicines` to retrieve the available medicine list and current stock levels.
   b. Staff select medicines and quantities to dispense.
   c. Validate that `quantity_in_stock >= quantity_dispensed`. If not, display a low-stock error and halt.
   d. Insert a record into `clinic.consultation_medicines` for each dispensed medicine.
   e. Decrement `quantity_in_stock` in `clinic.medicines` by the dispensed quantity.

3. Write an audit entry to `audit.activity_log` for each prescription issued and each dispensing event.
4. Make prescription records available to the Student Portal (decrypted, read-only).

### Outputs

| Output               | Destination                     | Description                                           |
| -------------------- | ------------------------------- | ----------------------------------------------------- |
| Prescription record  | `clinic.prescriptions`          | Encrypted prescription linked to consultation         |
| Dispensing record    | `clinic.consultation_medicines` | Per-medicine dispensing record                        |
| Stock level update   | `clinic.medicines`              | Decremented `quantity_in_stock`                       |
| Low-stock error      | Clinic Staff                    | Shown when requested quantity exceeds available stock |
| Prescription summary | Student Portal                  | Decrypted, read-only view for the student             |
| Audit entry          | `audit.activity_log`            | Records prescription and dispensing events            |

### Business Rules

- Prescription details **must** be encrypted before storage using `pgp_sym_encrypt()`.
- Dispensing must be blocked if `quantity_in_stock < quantity_dispensed`.
- Each dispensed medicine is recorded individually in `clinic.consultation_medicines` for accurate inventory tracking.
- Stock cannot go below zero — this is enforced at the application layer.
- A prescription must always be linked to an existing `consultation_id`.

### Data Stores Accessed

| Store                           | Operation                                  |
| ------------------------------- | ------------------------------------------ |
| `clinic.prescriptions`          | WRITE (new prescription)                   |
| `clinic.medicines`              | READ (stock list), WRITE (stock decrement) |
| `clinic.consultation_medicines` | WRITE (dispensing record)                  |
| `audit.activity_log`            | WRITE (prescription and dispensing events) |

---

## P5 — Health Clearance Management

**Process ID:** P5
**Process Name:** Health Clearance Management
**Module:** Faculty Portal / Clinic Staff & Doctor Module
**Triggered By:** Faculty submitting a health clearance request for a student; Clinic Staff or Doctor evaluating and issuing a clearance

### Description

Handles the lifecycle of health clearance requests: from a faculty member requesting a clearance for a student, through clinical evaluation, to final issuance of the clearance result and medical certificate.

### Inputs

| Input                                           | Source                | Format            |
| ----------------------------------------------- | --------------------- | ----------------- |
| `student_id`, clearance request                 | Faculty               | INT, request form |
| Clearance evaluation data (`status`, `remarks`) | Clinic Staff / Doctor | VARCHAR, TEXT     |

### Processing Logic

1. **Request Submission (Faculty):**
   a. Faculty submits a clearance request specifying the target student.
   b. A new record is created in `clinic.health_clearances` with `status = 'pending'`.

2. **Evaluation (Clinic Staff / Doctor):**
   a. Retrieve the pending clearance request from `clinic.health_clearances`.
   b. Review the student's consultation history (from `clinic.consultations` via P3) for relevant medical context.
   c. Set the clearance `status` to `cleared` or `not_cleared`.
   d. Optionally enter `remarks` to accompany the decision.
   e. Update the clearance record in `clinic.health_clearances`.

3. Notify the Faculty of the clearance outcome.
4. Generate and deliver a Medical Certificate document to the student if status is `cleared`.
5. Write an audit entry to `audit.activity_log` for each status change.

### Outputs

| Output                       | Destination                | Description                                       |
| ---------------------------- | -------------------------- | ------------------------------------------------- |
| Clearance record (pending)   | `clinic.health_clearances` | Created when faculty submits the request          |
| Clearance record (evaluated) | `clinic.health_clearances` | Updated with `cleared` / `not_cleared` status     |
| Clearance status             | Faculty Portal             | Displayed to the requesting faculty member        |
| Medical Certificate          | Student Portal             | Downloadable document; only issued when `cleared` |
| Audit entry                  | `audit.activity_log`       | Records request creation and status change events |

### Business Rules

- Only `nurse`, `doctor`, and `admin` roles may evaluate and update clearance status.
- `Faculty` may only submit and view clearance requests — they cannot approve or deny them.
- Medical Certificates are generated **only** when the final status is `cleared`.
- A clearance record is immutable once evaluated — corrections require creating a new record, not overwriting.

### Data Stores Accessed

| Store                      | Operation                                                   |
| -------------------------- | ----------------------------------------------------------- |
| `clinic.health_clearances` | READ (pending requests), WRITE (new request, status update) |
| `clinic.consultations`     | READ (medical context during evaluation)                    |
| `audit.activity_log`       | WRITE (lifecycle events)                                    |

---

## P6 — System & User Administration

**Process ID:** P6
**Process Name:** System & User Administration
**Module:** Admin Panel
**Triggered By:** System Admin performing account management, role assignments, or system configuration tasks

### Description

Provides full control over user accounts, role assignments, and system-level settings. Restricted exclusively to users with the `admin` role. All administrative actions are logged to the audit trail.

### Inputs

| Input                                                                   | Source       | Format             |
| ----------------------------------------------------------------------- | ------------ | ------------------ |
| New user details (`username`, `full_name`, `email`, `role`, `password`) | System Admin | Form fields        |
| Account update (role change, activate/deactivate)                       | System Admin | Form fields        |
| System configuration settings                                           | System Admin | Key-value settings |

### Processing Logic

1. **Create User Account:**
   a. Admin provides new user details.
   b. Validate that `username` is unique in `clinic.users`.
   c. Hash the provided password using **bcrypt**.
   d. Insert a new record into `clinic.users` with `is_active = TRUE`.
   e. If the role is `student`, navigate to P6-Student: also create the associated record in `clinic.students` and generate a QR token in `clinic.qr_codes`.

2. **Update User Account:**
   a. Admin selects an existing user.
   b. Permitted updates include: `role`, `is_active`, `email`, `full_name`.
   c. `password_hash` may be reset (re-hashed) but never read back in plain text.
   d. Apply the update to `clinic.users`; the `updated_at` trigger fires automatically.

3. **Deactivate / Reactivate Account:**
   a. Admin toggles `is_active` on a user record.
   b. Deactivated accounts are immediately blocked from login (enforced at P1, step 2).
   c. If the deactivated user is a student, their QR code is also set to `is_active = FALSE`.

4. Write a detailed audit entry to `audit.activity_log` for every action performed (account creation, role change, deactivation, reactivation).

### Outputs

| Output               | Destination          | Description                                           |
| -------------------- | -------------------- | ----------------------------------------------------- |
| New user record      | `clinic.users`       | Account created with bcrypt-hashed password           |
| New student profile  | `clinic.students`    | Created when new user has `role = 'student'`          |
| New QR code token    | `clinic.qr_codes`    | Generated for new student accounts                    |
| Updated user record  | `clinic.users`       | Reflects role change, status toggle, or detail update |
| Deactivated QR token | `clinic.qr_codes`    | Set `is_active = FALSE` when student is deactivated   |
| Audit entry          | `audit.activity_log` | Records all admin actions                             |

### Business Rules

- Only users with `role = 'admin'` may access P6.
- Passwords must be **bcrypt-hashed** before storage — the plain-text password is never persisted.
- `username` must be unique across all roles in `clinic.users`.
- Deactivating a student account must also deactivate their QR code in `clinic.qr_codes`.
- Admin accounts themselves (`role = 'admin'`) may only be created or modified by another admin — a system must have at least one active admin at all times.
- Every action performed in P6 must produce an audit log entry.

### Data Stores Accessed

| Store                | Operation                                                      |
| -------------------- | -------------------------------------------------------------- |
| `clinic.users`       | READ (lookup), WRITE (create, update, deactivate)              |
| `clinic.students`    | WRITE (create student profile for new student accounts)        |
| `clinic.qr_codes`    | WRITE (generate new token, deactivate on student deactivation) |
| `audit.activity_log` | WRITE (all admin actions)                                      |

---

## P7 — View Medical History

**Process ID:** P7
**Process Name:** View Medical History
**Module:** Student Portal
**Triggered By:** Student opening the Medical History page and submitting login credentials (or using an active authenticated session)

### Description

Authenticates the student and compiles a longitudinal medical history view from consultations, prescriptions, and dispensed medicines. The process returns only student-allowed data and excludes clinical-only notes.

### Inputs

| Input                                     | Source                    | Format                        |
| ----------------------------------------- | ------------------------- | ----------------------------- |
| `username`, `password` or active session  | Student Portal (Student)  | `VARCHAR(50)`, String / Token |
| Student authentication context            | `clinic.users`            | User record (`role`, status)  |
| Consultation history                      | `clinic.consultations`    | Records by `student_id`       |
| Prescription history                      | `clinic.prescriptions`    | Records by `consultation_id`  |
| Dispensed medicine history                | `clinic.consultation_medicines` | Records by `consultation_id`  |

### Processing Logic

1. Receive student access request from the Student Portal.
2. Authenticate against `clinic.users`, ensuring the account is active and the role is `student`.
3. Resolve the student's profile context and retrieve consultation history from `clinic.consultations` for that student.
4. Collect related prescription records from `clinic.prescriptions` using consultation references.
5. Collect dispensed medicine records from `clinic.consultation_medicines` using consultation references.
6. Build a unified medical history timeline grouped per consultation (consultation details + prescriptions + dispensed medicines).
7. Filter out restricted fields (for example, clinical-only `treatment_notes`) before rendering.
8. Return the final medical history view to the student portal.

### Outputs

| Output                        | Destination      | Description                                                      |
| ----------------------------- | ---------------- | ---------------------------------------------------------------- |
| Medical history display       | Student Portal   | Chronological student-facing view of consultations and medicines |
| Authentication/access error   | Student Portal   | Generic error for invalid credentials or unauthorized access      |

### Business Rules

- Only authenticated users with `role = 'student'` may access this process.
- Students may view only their own history; records must be filtered by the authenticated student's identity.
- `treatment_notes` must never be exposed through the Student Portal.
- History data is read-only in this process; no consultation, prescription, or dispensing records are modified.
- If no history exists, the portal must return an empty-state response (not a system error).

### Data Stores Accessed

| Store                          | Operation                                               |
| ------------------------------ | ------------------------------------------------------- |
| `clinic.users`                 | READ (student authentication and role/status validation) |
| `clinic.consultations`         | READ (consultation history by student)                  |
| `clinic.prescriptions`         | READ (prescription records by consultation)             |
| `clinic.consultation_medicines` | READ (dispensed medicine records by consultation)      |

---

## Summary Table

| Process                             | Role(s) Involved                       | Primary Data Stores                                                         |
| ----------------------------------- | -------------------------------------- | --------------------------------------------------------------------------- |
| P1 — Authentication & Portal Access | All roles                              | `clinic.users`, `audit.activity_log`                                        |
| P2 — QR Code Check-in System        | Clinic Staff, Student                  | `clinic.qr_codes`, `clinic.students`                                        |
| P3 — Consultation Management        | Clinic Staff, Doctor, Student          | `clinic.consultations`, `clinic.students`                                   |
| P4 — Prescription & Dispensing      | Doctor, Clinic Staff, Student          | `clinic.prescriptions`, `clinic.medicines`, `clinic.consultation_medicines` |
| P5 — Health Clearance Management    | Faculty, Clinic Staff, Doctor, Student | `clinic.health_clearances`, `clinic.consultations`                          |
| P6 — System & User Administration   | System Admin                           | `clinic.users`, `clinic.students`, `clinic.qr_codes`                        |
| P7 — View Medical History           | Student                                | `clinic.users`, `clinic.consultations`, `clinic.prescriptions`, `clinic.consultation_medicines` |
