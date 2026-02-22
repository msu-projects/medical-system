# School Clinic Management System

A database system for managing student healthcare at educational institutions. Available for both **PostgreSQL** and **MySQL**. Features QR code check-in, role-based access control, field-level encryption, and an immutable audit trail.

## Overview

The system stores and protects sensitive medical records for students, while providing appropriate access to clinic staff, doctors, and faculty. The planned full-stack implementation uses a React frontend with a Node.js/Express API. Choose either the PostgreSQL or MySQL backend depending on your infrastructure.

## Architecture

<table>
<tr><th>PostgreSQL</th><th>MySQL</th></tr>
<tr>
<td>

```
school_clinic_db
├── clinic schema  — tables, views, functions
└── audit schema   — immutable audit trail
```

</td>
<td>

```
school_clinic         — tables, views, functions
school_clinic_audit   — immutable audit trail
```

</td>
</tr>
</table>

|                           | PostgreSQL                                    | MySQL                                           |
| ------------------------- | --------------------------------------------- | ----------------------------------------------- |
| **Encryption**            | pgcrypto AES-256 (`pgp_sym_encrypt`)          | Built-in AES-256-CBC (`AES_ENCRYPT`)            |
| **Row-Level Security**    | Native RLS policies                           | Simulated via DEFINER views + stored procedures |
| **Session context**       | `set_config('app.encryption_key', ..., true)` | `SET @app_encryption_key = '...';`              |
| **Backups**               | `pg_dump` + GPG                               | `mysqldump` + GPG                               |
| **Encrypted column type** | `BYTEA`                                       | `BLOB`                                          |
| **UUID generation**       | `gen_random_uuid()`                           | `UUID()`                                        |

## Database Schema

| Table                    | Description                                               |
| ------------------------ | --------------------------------------------------------- |
| `users`                  | All system accounts across all roles                      |
| `students`               | Extended student profile (demographics, medical baseline) |
| `qr_codes`               | UUID-based QR tokens for fast clinic check-in             |
| `consultations`          | Medical visit records with encrypted diagnosis/notes      |
| `prescriptions`          | Doctor-issued medication orders (encrypted)               |
| `medicines`              | Medicine catalog                                          |
| `consultation_medicines` | Medicines dispensed per consultation                      |
| `health_clearances`      | Medical certificates and clearance status                 |

> In PostgreSQL, tables live under the `clinic` schema (e.g., `clinic.users`). In MySQL, they live directly in the `school_clinic` database.

## User Roles

| Role             | Access                                                               |
| ---------------- | -------------------------------------------------------------------- |
| `clinic_admin`   | Full access to all data and audit logs                               |
| `clinic_doctor`  | Reads all records; issues diagnoses, prescriptions, and clearances   |
| `clinic_nurse`   | Creates consultations, dispenses medicines, manages student profiles |
| `clinic_student` | Reads own records only (enforced by RLS / filtered views)            |
| `clinic_faculty` | Requests clearances; views clearance status only — no medical data   |

**PostgreSQL:** The login account `clinic_app` connects and calls `SET ROLE` to assume the appropriate group role per request.

**MySQL:** The app connects as `clinic_app` and sets session variables (`@app_current_user_id`, `@app_current_role`) to control access through views and stored procedures.

## Security Model

Five layered controls protect patient data:

1. **Field-level encryption** — `diagnosis`, `treatment_notes`, and `prescription_details` are encrypted at rest using AES-256. The encryption key is passed as a session variable and is never persisted in the database.
   - _PostgreSQL:_ `pgp_sym_encrypt()` via pgcrypto, stored as `BYTEA`
   - _MySQL:_ `AES_ENCRYPT()` with AES-256-CBC, stored as `BLOB` (IV prepended)

2. **Row-Level Security** — Students can only query their own rows. Staff can only modify records they personally attended.
   - _PostgreSQL:_ Native RLS policies on every table
   - _MySQL:_ Enforced via `SQL SECURITY DEFINER` views with WHERE clauses + stored procedures for writes

3. **Role-scoped views** — Each role accesses a dedicated view exposing only appropriate columns (e.g., students see their `diagnosis` but not `treatment_notes`).

4. **Least-privilege grants** — All `PUBLIC` access is revoked. Precise `GRANT` permissions are defined per role per table.

5. **Append-only audit trail** — Every `INSERT`, `UPDATE`, and `DELETE` on all clinical tables is logged with before/after state. No role can update or delete audit records.
   - _PostgreSQL:_ Generic `SECURITY DEFINER` trigger function, JSONB storage in `audit.activity_log`
   - _MySQL:_ Per-table triggers, JSON storage in `school_clinic_audit.activity_log`

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

### PostgreSQL

Run the SQL scripts in order as a PostgreSQL superuser:

```bash
psql -U postgres -f database/postgres/01_init.sql
psql -U postgres -d school_clinic_db -f database/postgres/02_tables.sql
psql -U postgres -d school_clinic_db -f database/postgres/03_encryption.sql
psql -U postgres -d school_clinic_db -f database/postgres/04_rls_policies.sql
psql -U postgres -d school_clinic_db -f database/postgres/05_views.sql
psql -U postgres -d school_clinic_db -f database/postgres/06_grants.sql
psql -U postgres -d school_clinic_db -f database/postgres/07_audit.sql
psql -U postgres -d school_clinic_db -f database/postgres/08_seed.sql      # optional sample data
```

Verify:

```sql
\dn                         -- List schemas: clinic, audit
\dx                         -- List extensions: pgcrypto
\du                         -- List roles
SELECT current_database();  -- Should return: school_clinic_db
```

### MySQL

Run the SQL scripts in order as root:

```bash
mysql -u root -p < database/mysql/01_init.sql
mysql -u root -p school_clinic < database/mysql/02_tables.sql
mysql -u root -p school_clinic < database/mysql/03_encryption.sql
mysql -u root -p school_clinic < database/mysql/04_rls_policies.sql
mysql -u root -p school_clinic < database/mysql/05_views.sql
mysql -u root -p school_clinic < database/mysql/06_grants.sql
mysql -u root -p                < database/mysql/07_audit.sql
mysql -u root -p school_clinic < database/mysql/08_seed.sql      # optional sample data
```

> **Prerequisite:** MySQL 8.0+ is required for `JSON`, expression default values (`UUID()`), and `RANDOM_BYTES()`.

Verify:

```sql
SHOW DATABASES LIKE 'school_clinic%';
SELECT user, host FROM mysql.user WHERE user LIKE 'clinic_%';
SHOW TABLES;
```

> **Important:** Change all role passwords from `change_me_in_production` before deploying.

## Usage

### Setting session context

<table>
<tr><th>PostgreSQL</th><th>MySQL</th></tr>
<tr>
<td>

```sql
SELECT set_config('app.encryption_key',
  'your-256-bit-secret-key', true);
SELECT set_config('app.current_user_id',
  '42', true);
```

</td>
<td>

```sql
SET @app_encryption_key = 'your-256-bit-secret-key';
SET @app_current_user_id = 42;
SET @app_current_role = 'nurse';
SET SESSION block_encryption_mode = 'aes-256-cbc';
```

</td>
</tr>
</table>

### Writing a consultation

<table>
<tr><th>PostgreSQL</th><th>MySQL</th></tr>
<tr>
<td>

```sql
SELECT clinic.create_consultation(
    p_student_id      := 1,
    p_attended_by     := 4,
    p_chief_complaint := 'Headache and fever',
    p_diagnosis       := 'Acute viral URI',
    p_treatment_notes := 'Given Paracetamol 500mg.'
);
```

</td>
<td>

```sql
CALL create_consultation(
    1, 4,
    'Headache and fever',
    'Acute viral URI',
    'Given Paracetamol 500mg.',
    NULL, NULL, NULL, NULL,
    @new_id
);
SELECT @new_id;
```

</td>
</tr>
</table>

### Reading decrypted data

<table>
<tr><th>PostgreSQL</th><th>MySQL</th></tr>
<tr>
<td>

```sql
SELECT consultation_id,
  clinic.decrypt_data(diagnosis) AS diagnosis
FROM clinic.consultations
WHERE student_id = 1;
```

</td>
<td>

```sql
SELECT consultation_id,
  decrypt_data(diagnosis) AS diagnosis
FROM consultations
WHERE student_id = 1;
```

</td>
</tr>
</table>

Or use the pre-built role-scoped views, which decrypt automatically.

## Backup & Restore

Backups are encrypted with GPG AES-256. The dump is piped directly through GPG and never touches disk in plaintext.

### PostgreSQL

```bash
./scripts/backup.sh                # encrypted backup
./scripts/backup.sh --no-encrypt   # development only
```

```bash
./scripts/restore.sh backups/daily/school_clinic_db_<timestamp>.dump.gpg \
                     backups/daily/roles_<timestamp>.sql
```

### MySQL

```bash
# Backup
mysqldump -u root -p --single-transaction --routines --triggers --events \
  --databases school_clinic school_clinic_audit | \
  gpg --batch --yes --symmetric --cipher-algo AES256 \
  --passphrase-file /path/to/passphrase.txt \
  -o school_clinic_backup.sql.gpg

# Restore
gpg --batch --yes --decrypt --passphrase-file /path/to/passphrase.txt \
  school_clinic_backup.sql.gpg | mysql -u root -p
```

### Retention tiers

| Tier    | Retention |
| ------- | --------- |
| Daily   | 7 days    |
| Weekly  | 4 weeks   |
| Monthly | 12 months |

> Store backup passphrases **separately** from the backup files. Test restores regularly against a staging environment.

## Project Structure

```
├── database/
│   ├── postgres/                       — PostgreSQL implementation
│   │   ├── 01_init.sql                 — database, schemas, extensions, roles
│   │   ├── 02_tables.sql               — table definitions and indexes
│   │   ├── 03_encryption.sql           — pgcrypto AES-256 helpers
│   │   ├── 04_rls_policies.sql         — native Row-Level Security policies
│   │   ├── 05_views.sql                — role-scoped masked views
│   │   ├── 06_grants.sql               — least-privilege permission matrix
│   │   ├── 07_audit.sql                — append-only audit trail (JSONB)
│   │   ├── 08_seed.sql                 — sample data for development/testing
│   │   └── 09_backup_restore.sql       — backup verification function
│   └── mysql/                          — MySQL implementation
│       ├── 01_init.sql                 — databases, users, basic privileges
│       ├── 02_tables.sql               — table definitions (InnoDB)
│       ├── 03_encryption.sql           — AES-256-CBC encrypt/decrypt functions
│       ├── 04_rls_policies.sql         — RLS simulation via procedures
│       ├── 05_views.sql                — role-scoped DEFINER views
│       ├── 06_grants.sql               — least-privilege permission matrix
│       ├── 07_audit.sql                — per-table audit triggers (JSON)
│       ├── 08_seed.sql                 — sample data for development/testing
│       └── 09_backup_restore.sql       — backup verification procedure
├── scripts/
│   ├── backup.sh                       — automated encrypted backup (PostgreSQL)
│   └── restore.sh                      — restore with integrity verification
└── docs/
    ├── overview.md                     — project plan and feature list
    ├── data_dictionary.md              — data dictionary
    ├── dfd-description.md              — logical and physical Data Flow Diagrams
    ├── dfd-guide.md                    — DFD methodology reference
    ├── physical_dfd_guide.md           — physical DFD guide
    └── process_specifications.md       — process specifications
```
