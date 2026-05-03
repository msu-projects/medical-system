#!/usr/bin/env bash
# ============================================================================
# run_postgres_sql.sh — Execute PostgreSQL SQL files (excluding seed files)
# ============================================================================
# Usage:
#   ./scripts/run_postgres_sql.sh
#
# Optional environment variables:
#   DB_NAME (default: school_clinic_db)
#   DB_USER (default: postgres)
#   DB_HOST (default: localhost)
#   DB_PORT (default: 5432)
#   SQL_DIR  (default: ./database/postgres)
# ============================================================================

set -euo pipefail

DB_NAME="${DB_NAME:-school_clinic_db}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
SQL_DIR="${SQL_DIR:-./database/postgres}"

if ! command -v psql >/dev/null 2>&1; then
    echo "ERROR: psql is not installed or not in PATH."
    exit 1
fi

if [[ ! -d "${SQL_DIR}" ]]; then
    echo "ERROR: SQL directory not found: ${SQL_DIR}"
    exit 1
fi

read -sp "Enter PostgreSQL password for ${DB_USER}: " PGPASSWORD
echo
export PGPASSWORD

echo "========================================"
echo " Running PostgreSQL SQL Files"
echo " Database: ${DB_NAME}"
echo " Host: ${DB_HOST}:${DB_PORT}"
echo " User: ${DB_USER}"
echo " SQL dir: ${SQL_DIR}"
echo " Excluding: *seed*.sql"
echo "========================================"

mapfile -t SQL_FILES < <(find "${SQL_DIR}" -maxdepth 1 -type f -name "*.sql" ! -iname "*seed*.sql" | sort)

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
    echo "No SQL files found to execute."
    exit 0
fi

TOTAL=${#SQL_FILES[@]}
INDEX=1

for file in "${SQL_FILES[@]}"; do
    echo ""
    echo "[${INDEX}/${TOTAL}] Executing ${file}..."

    base_name="$(basename "${file}")"

    if [[ "${base_name,,}" == "01_init.sql" || "${base_name,,}" == "init.sql" ]]; then
        psql \
            -h "${DB_HOST}" \
            -p "${DB_PORT}" \
            -U "${DB_USER}" \
            -v ON_ERROR_STOP=1 \
            -f "${file}"
    else
        psql \
            -h "${DB_HOST}" \
            -p "${DB_PORT}" \
            -U "${DB_USER}" \
            -d "${DB_NAME}" \
            -v ON_ERROR_STOP=1 \
            -f "${file}"
    fi

    echo "Completed: ${file}"
    INDEX=$((INDEX + 1))
done

echo ""
echo "========================================"
echo " All SQL files executed successfully"
echo "========================================"

unset PGPASSWORD
