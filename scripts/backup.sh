#!/usr/bin/env bash
# ============================================================================
# backup.sh — Automated Encrypted Backup for School Clinic Database
# ============================================================================
# Usage:
#   ./scripts/backup.sh
#   ./scripts/backup.sh --no-encrypt    (skip GPG encryption, for development)
#
# Prerequisites:
#   - PostgreSQL client tools (pg_dump, pg_dumpall)
#   - GPG (for encrypted backups)
#   - .pgpass file configured with credentials (chmod 600)
#   - Or: PGPASSWORD environment variable set
#
# Retention:
#   - Daily:   7 days
#   - Weekly:  4 weeks (Sunday backups kept)
#   - Monthly: 12 months (1st-of-month backups kept)
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
LOG_DIR="${BACKUP_DIR}/logs"
PASSPHRASE_FILE="${BACKUP_DIR}/.backup_passphrase"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATE_TODAY=$(date +"%Y%m%d")
DAY_OF_WEEK=$(date +"%u")   # 1=Monday, 7=Sunday
DAY_OF_MONTH=$(date +"%d")  # 01-31

ENCRYPT=true
if [[ "${1:-}" == "--no-encrypt" ]]; then
    ENCRYPT=false
fi

# Retention periods
DAILY_RETENTION=7
WEEKLY_RETENTION=28
MONTHLY_RETENTION=365

# ============================================================================
# Setup
# ============================================================================

mkdir -p "${BACKUP_DIR}/daily" "${BACKUP_DIR}/weekly" "${BACKUP_DIR}/monthly" "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "========================================"
echo " School Clinic DB — Backup"
echo " Started: $(date)"
echo " Database: ${DB_NAME}"
echo " Encryption: ${ENCRYPT}"
echo "========================================"

# ============================================================================
# Validate prerequisites
# ============================================================================

if ! command -v pg_dump &>/dev/null; then
    echo "ERROR: pg_dump not found. Install PostgreSQL client tools."
    exit 1
fi

if [[ "${ENCRYPT}" == true ]] && ! command -v gpg &>/dev/null; then
    echo "ERROR: gpg not found. Install GnuPG or use --no-encrypt."
    exit 1
fi

if [[ "${ENCRYPT}" == true ]] && [[ ! -f "${PASSPHRASE_FILE}" ]]; then
    echo "WARNING: Passphrase file not found at ${PASSPHRASE_FILE}"
    echo "Creating a new passphrase file with a random key..."
    openssl rand -base64 32 > "${PASSPHRASE_FILE}"
    chmod 600 "${PASSPHRASE_FILE}"
    echo "IMPORTANT: Save this passphrase securely! Without it, backups cannot be restored."
    echo "Passphrase file: ${PASSPHRASE_FILE}"
fi

# ============================================================================
# Step 1: Backup roles (cluster-wide)
# ============================================================================

echo ""
echo "[1/4] Backing up roles..."
ROLES_FILE="${BACKUP_DIR}/daily/roles_${TIMESTAMP}.sql"

pg_dumpall -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
    --roles-only \
    -f "${ROLES_FILE}" 2>&1

echo "  Roles saved to: ${ROLES_FILE}"

# ============================================================================
# Step 2: Full database backup
# ============================================================================

echo ""
echo "[2/4] Backing up database..."

DUMP_FILE="${BACKUP_DIR}/daily/${DB_NAME}_${TIMESTAMP}.dump"

if [[ "${ENCRYPT}" == true ]]; then
    # Pipe directly through GPG — dump never touches disk unencrypted
    DUMP_FILE="${DUMP_FILE}.gpg"

    pg_dump -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
        -Fc --no-owner --no-privileges \
        "${DB_NAME}" | \
    gpg --batch --yes --symmetric \
        --cipher-algo AES256 \
        --passphrase-file "${PASSPHRASE_FILE}" \
        -o "${DUMP_FILE}" 2>&1

    echo "  Encrypted dump saved to: ${DUMP_FILE}"
else
    pg_dump -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" \
        -Fc --no-owner --no-privileges \
        -f "${DUMP_FILE}" \
        "${DB_NAME}" 2>&1

    echo "  Dump saved to: ${DUMP_FILE}"
fi

DUMP_SIZE=$(du -h "${DUMP_FILE}" | cut -f1)
echo "  Backup size: ${DUMP_SIZE}"

# ============================================================================
# Step 3: Copy to weekly/monthly if applicable
# ============================================================================

echo ""
echo "[3/4] Managing retention copies..."

# Weekly backup (on Sundays)
if [[ "${DAY_OF_WEEK}" == "7" ]]; then
    cp "${DUMP_FILE}" "${BACKUP_DIR}/weekly/"
    cp "${ROLES_FILE}" "${BACKUP_DIR}/weekly/"
    echo "  Weekly backup created (Sunday)"
fi

# Monthly backup (on the 1st)
if [[ "${DAY_OF_MONTH}" == "01" ]]; then
    cp "${DUMP_FILE}" "${BACKUP_DIR}/monthly/"
    cp "${ROLES_FILE}" "${BACKUP_DIR}/monthly/"
    echo "  Monthly backup created (1st of month)"
fi

# ============================================================================
# Step 4: Clean old backups (retention policy)
# ============================================================================

echo ""
echo "[4/4] Cleaning old backups..."

# Daily: keep last 7 days
DAILY_CLEANED=$(find "${BACKUP_DIR}/daily" -type f -mtime +${DAILY_RETENTION} -delete -print | wc -l)
echo "  Daily: removed ${DAILY_CLEANED} files older than ${DAILY_RETENTION} days"

# Weekly: keep last 4 weeks
WEEKLY_CLEANED=$(find "${BACKUP_DIR}/weekly" -type f -mtime +${WEEKLY_RETENTION} -delete -print | wc -l)
echo "  Weekly: removed ${WEEKLY_CLEANED} files older than ${WEEKLY_RETENTION} days"

# Monthly: keep last 12 months
MONTHLY_CLEANED=$(find "${BACKUP_DIR}/monthly" -type f -mtime +${MONTHLY_RETENTION} -delete -print | wc -l)
echo "  Monthly: removed ${MONTHLY_CLEANED} files older than ${MONTHLY_RETENTION} days"

# Clean old log files (keep 30 days)
find "${LOG_DIR}" -type f -name "*.log" -mtime +30 -delete 2>/dev/null || true

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo " Backup Complete"
echo " Finished: $(date)"
echo " Dump file: ${DUMP_FILE}"
echo " Dump size: ${DUMP_SIZE}"
echo " Log file: ${LOG_FILE}"
echo "========================================"
echo ""

# ============================================================================
# Optional: Verify backup by listing contents
# ============================================================================
if [[ "${ENCRYPT}" != true ]]; then
    echo "Backup contents (table list):"
    pg_restore --list "${DUMP_FILE}" 2>/dev/null | grep "TABLE DATA" || true
    echo ""
fi

exit 0
