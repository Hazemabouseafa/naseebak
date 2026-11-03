#!/usr/bin/env bash
# ==============================================================================
# Naseebak (نصيبك) — PostgreSQL + Private Member Photos Backup Script
# Supports local staging dir + optional AES-256 encryption + S3 off-server upload
# ==============================================================================

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/naseebak}"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
PG_CONTAINER="${PG_CONTAINER:-naseebak-postgres}"
API_CONTAINER="${API_CONTAINER:-naseebak-api}"
DB_NAME="${DB_DATABASE:-naseebak_prod}"
DB_USER="${DB_USERNAME:-naseebak_user}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

mkdir -p "${BACKUP_ROOT}/db" "${BACKUP_ROOT}/photos"
chmod 700 "${BACKUP_ROOT}"

DB_DUMP_FILE="${BACKUP_ROOT}/db/naseebak_db_${TIMESTAMP}.dump"
PHOTOS_ARCHIVE="${BACKUP_ROOT}/photos/naseebak_private_photos_${TIMESTAMP}.tar.gz"

echo "[1/4] Creating PostgreSQL custom-format dump (${DB_DUMP_FILE})..."
docker exec "${PG_CONTAINER}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" -Fc --no-owner --no-privileges > "${DB_DUMP_FILE}"
sha256sum "${DB_DUMP_FILE}" > "${DB_DUMP_FILE}.sha256"

echo "[2/4] Archiving private member photos (${PHOTOS_ARCHIVE})..."
docker exec "${API_CONTAINER}" tar -C /var/www/html/storage/app/private -czf - member-photos > "${PHOTOS_ARCHIVE}"
sha256sum "${PHOTOS_ARCHIVE}" > "${PHOTOS_ARCHIVE}.sha256"

if [ -n "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]; then
    echo "[3/4] Encrypting backup artifacts with AES-256-CBC..."
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass env:BACKUP_ENCRYPTION_PASSPHRASE -in "${DB_DUMP_FILE}" -out "${DB_DUMP_FILE}.enc"
    rm -f "${DB_DUMP_FILE}"
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass env:BACKUP_ENCRYPTION_PASSPHRASE -in "${PHOTOS_ARCHIVE}" -out "${PHOTOS_ARCHIVE}.enc"
    rm -f "${PHOTOS_ARCHIVE}"
else
    echo "[3/4] BACKUP_ENCRYPTION_PASSPHRASE not set; keeping unencrypted archives with 0600 permissions."
    chmod 600 "${DB_DUMP_FILE}" "${PHOTOS_ARCHIVE}"
fi

echo "[4/4] Pruning local backup archives older than ${RETENTION_DAYS} days..."
find "${BACKUP_ROOT}" -type f -mtime +"${RETENTION_DAYS}" -delete

echo "[SUCCESS] Backup completed at ${TIMESTAMP}."
