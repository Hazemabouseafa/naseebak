#!/usr/bin/env bash
# ==============================================================================
# Naseebak (نصيبك) — Isolated Backup Restore Verification Script
# Restores a PostgreSQL dump and private photo archive into an isolated
# temporary database and directory to prove backup recoverability without
# touching production data.
# ==============================================================================

set -euo pipefail

DB_DUMP_FILE="${1:?Usage: verify-restore.sh <path-to-db.dump> <path-to-photos.tar.gz>}"
PHOTOS_ARCHIVE="${2:?Usage: verify-restore.sh <path-to-db.dump> <path-to-photos.tar.gz>}"
PG_CONTAINER="${PG_CONTAINER:-naseebak-postgres}"
DB_USER="${DB_USERNAME:-naseebak_user}"
VERIFY_DB="naseebak_restore_verify_$$"
VERIFY_DIR="/tmp/naseebak_photos_verify_$$"

cleanup() {
    docker exec "${PG_CONTAINER}" psql -U "${DB_USER}" -d postgres -c "DROP DATABASE IF EXISTS ${VERIFY_DB};" >/dev/null 2>&1 || true
    rm -rf "${VERIFY_DIR}"
}
trap cleanup EXIT

echo "[1/4] Creating isolated verification database: ${VERIFY_DB}..."
docker exec "${PG_CONTAINER}" psql -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${VERIFY_DB};"

echo "[2/4] Restoring dump into ${VERIFY_DB}..."
docker exec -i "${PG_CONTAINER}" pg_restore -U "${DB_USER}" -d "${VERIFY_DB}" --no-owner --no-privileges < "${DB_DUMP_FILE}"

echo "[3/4] Verifying core Naseebak tables in restored database..."
TABLE_COUNT=$(docker exec "${PG_CONTAINER}" psql -U "${DB_USER}" -d "${VERIFY_DB}" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
echo "  - Restored public table count: ${TABLE_COUNT}"
if [ "${TABLE_COUNT}" -lt 15 ]; then
    echo "[FAIL] Restored database has fewer than 15 tables (${TABLE_COUNT})." >&2
    exit 1
fi

echo "[4/4] Extracting private photo archive into isolated directory ${VERIFY_DIR}..."
mkdir -p "${VERIFY_DIR}"
tar -C "${VERIFY_DIR}" -xzf "${PHOTOS_ARCHIVE}"
test -d "${VERIFY_DIR}/member-photos"

echo "[PASS] Isolated PostgreSQL and Private Photo backup restore verification succeeded."
