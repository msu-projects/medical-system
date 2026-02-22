#!/usr/bin/env bash
# ============================================================================
# restore.sh — Restore School Clinic Database from Encrypted Backup
# ============================================================================
# Usage:
#   ./scripts/restore.sh <backup_file> [roles_file]
#
# Examples:
#   ./scripts/restore.sh backups/daily/school_clinic_db_20260215_020000.dump.gpg
#   ./scripts/restore.sh backups/daily/school_clinic_db_20260215_020000.dump.gpg backups/daily/roles_20260215_020000.sql
#   ./scripts/restore.sh backups/daily/school_clinic_db_20260215_020000.dump  # unencrypted
#
# This script will:
#   1. Restore roles (if roles file provided)
#   2. Drop and recreate the target database
#   3. Decrypt the backup (if .gpg extension)
#   4. Restore all data
#   5. Run ANALYZE for query optimizer
#   6. Verify record counts
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

DB_NAME="school_clinic_db"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"

BACKUP_DIR="${BACKUP_DIR:-/home/aj/Projects/medical-system/backups}"
PASSPHRASE_FILE="${BACKUP_DIR}/.backup_passphrase"

# ============================================================================
# Argument parsing
# ============================================================================

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <backup_file> [roles_file]"
    echo ""
    echo "Arguments:"
    echo "  backup_file   Path to the .dump or .dump.gpg backup file"
    echo "  roles_file    (Optional) Path to the roles SQL backup file"
    echo ""
    echo "Available backups:"
    find "${BACKUP_DIR}" -name "*.dump*" -type f 2>/dev/null | sort -r | head -10 || echo "  No backups found in ${BACKUP_DIR}"
    exit 1
fi

BACKUP_FILE="$1"
ROLES_FILE="${2:-}"

# ============================================================================
# Validation
# ============================================================================

if [[ ! -f "${BACKUP_FILE}" ]]; then
    echo "ERROR: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

IS_ENCRYPTED=false
if [[ "${BACKUP_FILE}" == *.gpg ]]; then
    IS_ENCRYPTED=true
    if [[ ! -f "${PASSPHRASE_FILE}" ]]; then
        echo "ERROR: Encrypted backup detected but passphrase file not found: ${PASSPHRASE_FILE}"
        echo "Provide the passphrase file or decrypt the backup manually first."
        exit 1
    fi
fi

echo "========================================"
echo " School Clinic DB — Restore"
echo " Started: $(date)"
echo " Backup file: ${BACKUP_FILE}"
echo " Encrypted: ${IS_ENCRYPTED}"
echo " Roles file: ${ROLES_FILE:-'(not provided)'}"
echo " Target DB: ${DB_NAME}"
echo "========================================"

# ============================================================================
# Confirmation prompt
# ============================================================================

echo ""
echo "WARNING: This will DROP and RECREATE the database '${DB_NAME}'."
echo "         All existing data in '${DB_NAME}' will be PERMANENTLY LOST."
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
    echo "Restore cancelled."
    exit 0
fi

# ============================================================================
# Step 1: Restore roles (if provided)
# ============================================================================

if [[ -n "${ROLES_FILE}" ]]; then
    if [[ ! -f "${ROLES_FILE}" ]]; then
        echo "WARNING: Roles file not found: ${ROLES_FILE}"
        echo "Skipping role restoration. Roles may already exist."
    else
        echo ""
        echo "[1/5] Restoring roles..."
        psql -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
            -f "${ROLES_FILE}" 2>&1 || true
        echo "  Roles restored."
    fi
else
    echo ""
    echo "[1/5] Skipping role restoration (no roles file provided)."
    echo "  Ensure roles already exist: clinic_admin, clinic_doctor, clinic_nurse, etc."
fi

# ============================================================================
# Step 2: Drop and recreate database
# ============================================================================

echo ""
echo "[2/5] Dropping and recreating database..."

# Terminate existing connections
psql -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" -d postgres -c "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();
" 2>/dev/null || true

dropdb -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
    --if-exists "${DB_NAME}" 2>&1

createdb -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
    -E UTF8 "${DB_NAME}" 2>&1

echo "  Database '${DB_NAME}' recreated."

# ============================================================================
# Step 3: Restore data
# ============================================================================

echo ""
echo "[3/5] Restoring data..."

if [[ "${IS_ENCRYPTED}" == true ]]; then
    # Decrypt and pipe directly to pg_restore — decrypted dump never touches disk
    gpg --batch --yes --decrypt \
        --passphrase-file "${PASSPHRASE_FILE}" \
        "${BACKUP_FILE}" | \
    pg_restore -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
        -d "${DB_NAME}" \
        --no-owner \
        --no-privileges \
        --if-exists \
        --exit-on-error 2>&1

    echo "  Decrypted and restored successfully."
else
    pg_restore -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
        -d "${DB_NAME}" \
        --no-owner \
        --no-privileges \
        --if-exists \
        --exit-on-error \
        "${BACKUP_FILE}" 2>&1

    echo "  Restored successfully."
fi

# ============================================================================
# Step 4: Post-restore maintenance
# ============================================================================

echo ""
echo "[4/5] Running post-restore maintenance..."

# Rebuild optimizer statistics (pg_dump doesn't include them)
psql -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
    -d "${DB_NAME}" -c "ANALYZE;" 2>&1

echo "  ANALYZE complete — query optimizer statistics rebuilt."

# Re-apply search path
psql -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
    -d "${DB_NAME}" -c "ALTER DATABASE ${DB_NAME} SET search_path TO clinic, public;" 2>&1

echo "  Search path configured."

# ============================================================================
# Step 5: Verify data integrity
# ============================================================================

echo ""
echo "[5/5] Verifying data integrity..."

psql -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
    -d "${DB_NAME}" -c "
    SELECT 'clinic.users'              AS table_name, COUNT(*) AS records FROM clinic.users
    UNION ALL SELECT 'clinic.students',              COUNT(*) FROM clinic.students
    UNION ALL SELECT 'clinic.qr_codes',              COUNT(*) FROM clinic.qr_codes
    UNION ALL SELECT 'clinic.consultations',         COUNT(*) FROM clinic.consultations
    UNION ALL SELECT 'clinic.prescriptions',         COUNT(*) FROM clinic.prescriptions
    UNION ALL SELECT 'clinic.medicines',             COUNT(*) FROM clinic.medicines
    UNION ALL SELECT 'clinic.consultation_meds',     COUNT(*) FROM clinic.consultation_medicines
    UNION ALL SELECT 'clinic.health_clearances',     COUNT(*) FROM clinic.health_clearances
    UNION ALL SELECT 'audit.activity_log',           COUNT(*) FROM audit.activity_log
    ORDER BY 1;
" 2>&1

# Verify encryption is intact
echo ""
echo "Verifying encrypted columns are still encrypted (should show bytea data):"
psql -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
    -d "${DB_NAME}" -c "
    SELECT consultation_id,
           LENGTH(diagnosis) AS diagnosis_bytes,
           CASE WHEN diagnosis IS NOT NULL THEN 'encrypted' ELSE 'null' END AS status
    FROM clinic.consultations
    LIMIT 3;
" 2>&1

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo " Restore Complete"
echo " Finished: $(date)"
echo " Database: ${DB_NAME}"
echo " Source: ${BACKUP_FILE}"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Test the application against the restored database"
echo "  2. Verify encrypted data can be decrypted with the correct key"
echo "  3. Test RLS policies with different roles"
echo ""

exit 0
