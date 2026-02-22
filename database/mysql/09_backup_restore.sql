-- ============================================================================
-- 09_backup_restore.sql
-- School Clinic Management System — Backup & Restore Procedures (MySQL)
-- ============================================================================
-- This file documents the backup and restore strategy for the MySQL version.
-- The actual automation would be implemented in shell scripts.
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
--    ┌──────────────────────┬───────────────────────────────┬──────────────┐
--    │ Component            │ Tool                          │ Frequency    │
--    ├──────────────────────┼───────────────────────────────┼──────────────┤
--    │ Both databases       │ mysqldump --single-transaction│ Daily        │
--    │ User accounts/grants │ pt-show-grants / mysqldump    │ Daily        │
--    │ Configuration        │ my.cnf                        │ On change    │
--    └──────────────────────┴───────────────────────────────┴──────────────┘
--
-- 2. ENCRYPTION:
--    All backup files are encrypted using GPG symmetric encryption (AES-256)
--    before being written to disk. This provides:
--      - Data at rest: encrypted in the dump file
--      - Data in columns: already encrypted via AES_ENCRYPT (double protection)
--      - Backup key is separate from the column encryption key
--
-- 3. RETENTION POLICY:
--    - Daily backups:   retained for 7 days
--    - Weekly backups:  retained for 4 weeks  (Sunday backups)
--    - Monthly backups: retained for 12 months (1st of month)
--
-- 4. BACKUP USER:
--    Backups should be performed with a user that has sufficient privileges
--    to read ALL data. Use --single-transaction for consistent InnoDB backups.
--
-- ============================================================================

-- ============================================================================
-- MANUAL BACKUP COMMANDS (for reference)
-- ============================================================================
--
-- Full database backup (both databases):
--   mysqldump -u root -p --single-transaction --routines --triggers --events \
--     --databases school_clinic school_clinic_audit > school_clinic_backup.sql
--
-- Full database backup with encryption:
--   mysqldump -u root -p --single-transaction --routines --triggers --events \
--     --databases school_clinic school_clinic_audit | \
--     gpg --batch --yes --symmetric --cipher-algo AES256 \
--     --passphrase-file /path/to/backup_passphrase.txt \
--     -o school_clinic_backup.sql.gpg
--
-- User/grant backup:
--   mysql -u root -p -N -e "SELECT CONCAT('SHOW GRANTS FOR ''',user,'''@''',host,''';') \
--     FROM mysql.user WHERE user LIKE 'clinic_%'" | \
--     mysql -u root -p -N > grants_backup.sql
--
-- Schema-only backup:
--   mysqldump -u root -p --single-transaction --no-data --routines --triggers \
--     --databases school_clinic school_clinic_audit > schema_only.sql
--
-- ============================================================================

-- ============================================================================
-- MANUAL RESTORE COMMANDS (for reference)
-- ============================================================================
--
-- 1. Decrypt the backup:
--   gpg --batch --yes --decrypt \
--     --passphrase-file /path/to/backup_passphrase.txt \
--     school_clinic_backup.sql.gpg > school_clinic_backup.sql
--
-- 2. Restore (this will DROP and recreate the databases):
--   mysql -u root -p < school_clinic_backup.sql
--
-- 3. Restore grants:
--   mysql -u root -p < grants_backup.sql
--   mysql -u root -p -e "FLUSH PRIVILEGES;"
--
-- 4. Post-restore maintenance:
--   mysqlcheck -u root -p --analyze school_clinic school_clinic_audit
--
-- 5. Verify data integrity:
--   mysql -u root -p -e "
--     SELECT 'users' AS tbl, COUNT(*) AS cnt FROM school_clinic.users
--     UNION ALL SELECT 'students', COUNT(*) FROM school_clinic.students
--     UNION ALL SELECT 'consultations', COUNT(*) FROM school_clinic.consultations
--     UNION ALL SELECT 'audit_log', COUNT(*) FROM school_clinic_audit.activity_log;
--   "
--
-- ============================================================================

-- ============================================================================
-- VERIFY BACKUP COMPLETENESS
-- ============================================================================

USE school_clinic;

DELIMITER //

CREATE PROCEDURE fn_backup_verify()
SQL SECURITY DEFINER
COMMENT 'Returns record counts for all tables — use before/after backup to verify completeness.'
BEGIN
    SELECT 'school_clinic.users'                AS table_name, COUNT(*) AS record_count FROM school_clinic.users
    UNION ALL SELECT 'school_clinic.students',           COUNT(*) FROM school_clinic.students
    UNION ALL SELECT 'school_clinic.qr_codes',           COUNT(*) FROM school_clinic.qr_codes
    UNION ALL SELECT 'school_clinic.consultations',      COUNT(*) FROM school_clinic.consultations
    UNION ALL SELECT 'school_clinic.prescriptions',      COUNT(*) FROM school_clinic.prescriptions
    UNION ALL SELECT 'school_clinic.medicines',          COUNT(*) FROM school_clinic.medicines
    UNION ALL SELECT 'school_clinic.consultation_meds',  COUNT(*) FROM school_clinic.consultation_medicines
    UNION ALL SELECT 'school_clinic.health_clearances',  COUNT(*) FROM school_clinic.health_clearances
    UNION ALL SELECT 'school_clinic_audit.activity_log', COUNT(*) FROM school_clinic_audit.activity_log
    ORDER BY table_name;
END //

DELIMITER ;

GRANT EXECUTE ON PROCEDURE school_clinic.fn_backup_verify TO 'clinic_admin'@'%';

-- ============================================================================
-- IMPORTANT NOTES
-- ============================================================================
--
-- 1. Always use --single-transaction for InnoDB backups to get a consistent
--    snapshot without locking tables.
--
-- 2. Include --routines --triggers --events to capture stored procedures,
--    functions, triggers, and scheduled events.
--
-- 3. The column-encrypted data (BLOB columns with AES_ENCRYPT) remains
--    encrypted inside the backup — this provides an extra layer of protection
--    even if the backup encryption is compromised.
--
-- 4. Store backup encryption passphrases SEPARATELY from the backups.
--    Recommended: use a hardware security module or secrets manager.
--
-- 5. Test restores regularly (at least monthly) to a staging environment.
--    A backup that can't be restored is not a backup.
--
-- 6. For binary log backups (point-in-time recovery):
--      mysqlbinlog --read-from-remote-server --host=localhost \
--        --raw --result-file=/backups/binlog/ mysql-bin.000001
--
-- ============================================================================
