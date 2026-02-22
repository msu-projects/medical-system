# School Clinic Management System

A PostgreSQL-backed database system for managing student healthcare at educational institutions. Features QR code check-in, role-based access control, field-level encryption, and an immutable audit trail.

## Overview

The system stores and protects sensitive medical records for students, while providing appropriate access to clinic staff, doctors, and faculty. The planned full-stack implementation uses a React frontend with a Node.js/Express API.

## Architecture

```
school_clinic_db
├── clinic schema       — application tables, views, and functions
└── audit schema        — immutable audit trail (append-only)
```

**Tech stack:** PostgreSQL · pgcrypto (AES-256) · Row-Level Security · pg_dump/GPG backups

## Database Schema

| Table                           | Description                                               |
| ------------------------------- | --------------------------------------------------------- |
| `clinic.users`                  | All system accounts across all roles                      |
| `clinic.students`               | Extended student profile (demographics, medical baseline) |
| `clinic.qr_codes`               | UUID-based QR tokens for fast clinic check-in             |
| `clinic.consultations`          | Medical visit records with encrypted diagnosis/notes      |
| `clinic.prescriptions`          | Doctor-issued medication orders (encrypted)               |
| `clinic.medicines`              | Medicine catalog                                          |
| `clinic.consultation_medicines` | Medicines dispensed per consultation                      |
| `clinic.health_clearances`      | Medical certificates and clearance status                 |

## User Roles

| Role             | Access                                                               |
| ---------------- | -------------------------------------------------------------------- |
| `clinic_admin`   | Full access to all data and audit logs                               |
| `clinic_doctor`  | Reads all records; issues diagnoses, prescriptions, and clearances   |
| `clinic_nurse`   | Creates consultations, dispenses medicines, manages student profiles |
| `clinic_student` | Reads own records only (enforced by RLS + masked views)              |
| `clinic_faculty` | Requests clearances; views clearance status only — no medical data   |

The single login account `clinic_app` connects to the database, then calls `SET ROLE` per authenticated request to assume the appropriate group role.

## Security Model

Five layered controls protect patient data:

1. **Field-level encryption** — `diagnosis`, `treatment_notes`, and `prescription_details` are stored as `BYTEA` using `pgcrypto` AES-256 (`pgp_sym_encrypt`). The encryption key is passed as a transaction-local session variable (`set_config('app.encryption_key', ..., true)`) and is never persisted in the database.

2. **Row-Level Security** — Students can only query their own rows. Staff can only modify records they personally attended.

3. **Role-scoped views** — Each role accesses a dedicated view exposing only appropriate columns (e.g., students see their `diagnosis` but not `treatment_notes`).

4. **Least-privilege grants** — All `PUBLIC` access is revoked. Precise `GRANT` permissions are defined per role per table.

5. **Append-only audit trail** — Every `INSERT`, `UPDATE`, and `DELETE` on all clinical tables is logged to `audit.activity_log` as JSONB via a `SECURITY DEFINER` trigger. No role can update or delete audit records.

### Encrypted Columns

| Table           | Column                          |
| --------------- | ------------------------------- |
| `consultations` | `diagnosis`, `treatment_notes`  |
| `prescriptions` | `prescription_details`, `notes` |

### Role-Scoped Views

| View                        | Accessible By    |
| --------------------------- | ---------------- |
| `v_student_medical_history` | `clinic_student` |
| `v_faculty_clearance`       | `clinic_faculty` |
| `v_nurse_dashboard`         | `clinic_nurse`   |
| `v_doctor_consultations`    | `clinic_doctor`  |
| `v_admin_user_overview`     | `clinic_admin`   |
| `v_qr_checkin`              | `clinic_nurse`   |

## Setup

Run the SQL scripts in order as a PostgreSQL superuser:

```bash
psql -U postgres -f database/01_init.sql
psql -U postgres -d school_clinic_db -f database/02_tables.sql
psql -U postgres -d school_clinic_db -f database/03_encryption.sql
psql -U postgres -d school_clinic_db -f database/04_rls_policies.sql
psql -U postgres -d school_clinic_db -f database/05_views.sql
psql -U postgres -d school_clinic_db -f database/06_grants.sql
psql -U postgres -d school_clinic_db -f database/07_audit.sql
psql -U postgres -d school_clinic_db -f database/08_seed.sql      # optional sample data
```

> **Important:** Change the `clinic_app` role password from `change_me_in_production` before deploying.

### Verification

```sql
\dn                         -- List schemas: clinic, audit
\dx                         -- List extensions: pgcrypto
\du                         -- List roles
SELECT current_database();  -- Should return: school_clinic_db
```

## Usage

### Encrypting data

At the start of each transaction, set the encryption key and current user:

```sql
SELECT set_config('app.encryption_key',  'your-256-bit-secret-key', true);
SELECT set_config('app.current_user_id', '42',                       true);
```

The `true` parameter makes these transaction-local — they are cleared automatically on commit or rollback.

### Writing a consultation

```sql
SELECT clinic.create_consultation(
    p_student_id      := 1,
    p_attended_by     := 4,
    p_chief_complaint := 'Headache and fever',
    p_diagnosis       := 'Acute viral URI',
    p_treatment_notes := 'Given Paracetamol 500mg. Advised rest.'
);
```

### Reading decrypted data

```sql
SELECT consultation_id,
       clinic.decrypt_data(diagnosis)       AS diagnosis,
       clinic.decrypt_data(treatment_notes) AS treatment_notes
FROM clinic.consultations
WHERE student_id = 1;
```

Or use the pre-built role-scoped views, which decrypt automatically.

## Backup & Restore

Backups are encrypted with GPG AES-256. The dump is piped directly through GPG and never touches disk in plaintext.

### Run a backup

```bash
./scripts/backup.sh
./scripts/backup.sh --no-encrypt   # development only
```

Backups are written to `backups/` with daily, weekly (Sundays), and monthly (1st of month) retention tiers:

| Tier    | Retention |
| ------- | --------- |
| Daily   | 7 days    |
| Weekly  | 4 weeks   |
| Monthly | 12 months |

### Restore from backup

```bash
./scripts/restore.sh backups/daily/school_clinic_db_<timestamp>.dump.gpg \
                     backups/daily/roles_<timestamp>.sql
```

The restore script drops and recreates the database, decrypts on-the-fly, runs `ANALYZE`, and verifies record counts across all tables.

> Store backup passphrases **separately** from the backup files. Test restores regularly against a staging environment.

## Project Structure

```
├── database/
│   ├── 01_init.sql             — database, schemas, extensions, roles
│   ├── 02_tables.sql           — table definitions and indexes
│   ├── 03_encryption.sql       — AES-256 encrypt/decrypt helper functions
│   ├── 04_rls_policies.sql     — Row-Level Security policies
│   ├── 05_views.sql            — role-scoped masked views
│   ├── 06_grants.sql           — least-privilege permission matrix
│   ├── 07_audit.sql            — append-only audit trail
│   ├── 08_seed.sql             — sample data for development/testing
│   └── 09_backup_restore.sql   — backup verification function
├── scripts/
│   ├── backup.sh               — automated encrypted backup
│   └── restore.sh              — restore with integrity verification
└── docs/
    ├── overview.md             — project plan and feature list
    ├── dfd-description.md      — logical and physical Data Flow Diagrams
    └── dfd-guide.md            — DFD methodology reference
```
