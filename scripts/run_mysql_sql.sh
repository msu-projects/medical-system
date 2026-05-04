#!/usr/bin/env bash
# ============================================================================
# run_mysql_sql.sh — Execute MySQL SQL files
# ============================================================================
# Usage:
#   ./scripts/run_mysql_sql.sh
#
# Optional environment variables:
#   DB_NAME (default: school_clinic)
#   DB_USER (default: root)
#   DB_HOST (default: localhost)
#   DB_PORT (default: 3306)
#   SQL_DIR  (default: ./database/mysql)
# ============================================================================

set -euo pipefail

DB_NAME="${DB_NAME:-school_clinic}"
DB_USER="${DB_USER:-root}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
SQL_DIR="${SQL_DIR:-./database/mysql}"

if ! command -v mysql >/dev/null 2>&1; then
    echo "ERROR: mysql is not installed or not in PATH."
    exit 1
fi

if [[ ! -d "${SQL_DIR}" ]]; then
    echo "ERROR: SQL directory not found: ${SQL_DIR}"
    exit 1
fi

read -rsp "Enter MySQL password for ${DB_USER}: " MYSQL_PWD
echo
export MYSQL_PWD

echo "========================================"
echo " Running MySQL SQL Files"
echo " Database: ${DB_NAME}"
echo " Host: ${DB_HOST}:${DB_PORT}"
echo " User: ${DB_USER}"
echo " SQL dir: ${SQL_DIR}"
echo " Including all .sql files"
echo "========================================"

mapfile -t SQL_FILES < <(find "${SQL_DIR}" -maxdepth 1 -type f -name "*.sql" | sort)

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
    echo "No SQL files found to execute."
    exit 0
fi

TOTAL=${#SQL_FILES[@]}
INDEX=1

for file in "${SQL_FILES[@]}"; do
    echo
    echo "[${INDEX}/${TOTAL}] Executing ${file}..."

    base_name="$(basename "${file}")"

    if [[ "${base_name,,}" == "01_init.sql" || "${base_name,,}" == "init.sql" ]]; then
        mysql \
            --host="${DB_HOST}" \
            --port="${DB_PORT}" \
            --user="${DB_USER}" \
            --default-character-set=utf8mb4 \
            --binary-mode < "${file}"
    else
        mysql \
            --host="${DB_HOST}" \
            --port="${DB_PORT}" \
            --user="${DB_USER}" \
            --database="${DB_NAME}" \
            --default-character-set=utf8mb4 \
            --binary-mode < "${file}"
    fi

    echo "Completed: ${file}"
    INDEX=$((INDEX + 1))
done

echo
echo "========================================"
echo " All SQL files executed successfully"
echo "========================================"

unset MYSQL_PWD
