-- ============================================================================
-- 09_backup_restore.sql
-- School Clinic Management System — Backup & Restore Procedures
-- ============================================================================
-- This file documents the backup and restore strategy for the clinic database.
-- The actual automation is in scripts/backup.sh and scripts/restore.sh.
--
-- For a medical records system, backups are CRITICAL:
--   - Patient data must never be lost
--   - Backups must be encrypted (medical data confidentiality)
--   - Recovery must be tested regularly
--   - Audit trail must be preserved intact
-- ============================================================================

-- ============================================================================
-- BACKUP STRATEGY OVERVIEW
-- ============================================================================
--
-- 1. WHAT IS BACKED UP:
--    ┌────────────────────┬──────────────────────────────┬──────────────┐
--    │ Component          │ Tool                         │ Frequency    │
--    ├────────────────────┼──────────────────────────────┼──────────────┤
--    │ Database (all data)│ pg_dump -Fc                  │ Daily        │
--    │ Roles & privileges │ pg_dumpall --roles-only      │ Daily        │
--    │ Configuration      │ postgresql.conf, pg_hba.conf │ On change    │
--    └────────────────────┴──────────────────────────────┴──────────────┘
--
-- 2. ENCRYPTION:
--    All backup files are encrypted using GPG symmetric encryption (AES-256)
--    before being written to disk. This provides:
--      - Data at rest: encrypted in the dump file
--      - Data in columns: already encrypted via pgcrypto (double protection)
--      - Backup key is separate from the column encryption key
--
-- 3. RETENTION POLICY:
--    - Daily backups:   retained for 7 days
--    - Weekly backups:  retained for 4 weeks  (Sunday backups)
--    - Monthly backups: retained for 12 months (1st of month)
--
-- 4. BACKUP USER:
--    Backups MUST be performed by a superuser or a role with BYPASSRLS.
--    This ensures ALL rows are included regardless of RLS policies.
--    Using a non-privileged user would silently produce PARTIAL backups.
--
-- ============================================================================

-- ============================================================================
-- MANUAL BACKUP COMMANDS (for reference)
-- ============================================================================
--
-- Full database backup (custom format, compressed):
--   pg_dump -U postgres -Fc -f school_clinic_backup.dump school_clinic_db
--
-- Full database backup with encryption:
--   pg_dump -U postgres -Fc school_clinic_db | \
--     gpg --batch --yes --symmetric --cipher-algo AES256 \
--     --passphrase-file /path/to/backup_passphrase.txt \
--     -o school_clinic_backup.dump.gpg
--
-- Roles backup (cluster-wide — includes role definitions & memberships):
--   pg_dumpall -U postgres --roles-only -f roles_backup.sql
--
-- Schema-only backup (for documentation / migration reference):
--   pg_dump -U postgres -s -Fc -f schema_only.dump school_clinic_db
--
-- ============================================================================

-- ============================================================================
-- MANUAL RESTORE COMMANDS (for reference)
-- ============================================================================
--
-- 1. Restore roles FIRST (they are cluster-wide):
--   psql -U postgres -f roles_backup.sql
--
-- 2. Create the target database (if it doesn't exist):
--   createdb -U postgres school_clinic_db
--
-- 3. Decrypt and restore:
--   gpg --batch --yes --decrypt \
--     --passphrase-file /path/to/backup_passphrase.txt \
--     school_clinic_backup.dump.gpg | \
--     pg_restore -U postgres -d school_clinic_db --clean --if-exists
--
-- 4. Post-restore maintenance:
--   psql -U postgres -d school_clinic_db -c "ANALYZE;"
--
-- 5. Verify data integrity:
--   psql -U postgres -d school_clinic_db -c "
--     SELECT 'users' AS tbl, COUNT(*) FROM clinic.users
--     UNION ALL SELECT 'students', COUNT(*) FROM clinic.students
--     UNION ALL SELECT 'consultations', COUNT(*) FROM clinic.consultations
--     UNION ALL SELECT 'audit_log', COUNT(*) FROM audit.activity_log;
--   "
--
-- ============================================================================

-- ============================================================================
-- VERIFY BACKUP COMPLETENESS
-- ============================================================================
-- Run this query BEFORE and AFTER backup/restore to compare record counts.

CREATE OR REPLACE FUNCTION clinic.fn_backup_verify()
RETURNS TABLE (
    table_name TEXT,
    record_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'clinic.users'::TEXT,                  COUNT(*) FROM clinic.users
    UNION ALL SELECT 'clinic.students',           COUNT(*) FROM clinic.students
    UNION ALL SELECT 'clinic.qr_codes',           COUNT(*) FROM clinic.qr_codes
    UNION ALL SELECT 'clinic.consultations',      COUNT(*) FROM clinic.consultations
    UNION ALL SELECT 'clinic.prescriptions',      COUNT(*) FROM clinic.prescriptions
    UNION ALL SELECT 'clinic.medicines',          COUNT(*) FROM clinic.medicines
    UNION ALL SELECT 'clinic.consultation_meds',  COUNT(*) FROM clinic.consultation_medicines
    UNION ALL SELECT 'clinic.health_clearances',  COUNT(*) FROM clinic.health_clearances
    UNION ALL SELECT 'audit.activity_log',        COUNT(*) FROM audit.activity_log
    ORDER BY 1;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION clinic.fn_backup_verify() TO clinic_admin;

COMMENT ON FUNCTION clinic.fn_backup_verify() IS
    'Returns record counts for all tables — use before/after backup to verify completeness';

-- ============================================================================
-- IMPORTANT NOTES
-- ============================================================================
--
-- 1. NEVER use --enable-row-security with pg_dump for medical data backups.
--    This flag causes pg_dump to only export rows visible to the dumping user
--    under RLS policies, which WILL result in data loss.
--
-- 2. The column-encrypted data (BYTEA columns with pgcrypto) remains encrypted
--    inside the backup — this provides an extra layer of protection even if
--    the backup encryption is compromised.
--
-- 3. Store backup encryption passphrases SEPARATELY from the backups.
--    Recommended: use a hardware security module or secrets manager.
--
-- 4. Test restores regularly (at least monthly) to a staging environment.
--    A backup that can't be restored is not a backup.
--
-- 5. The scripts/backup.sh and scripts/restore.sh automate this entire process.
-- ============================================================================
