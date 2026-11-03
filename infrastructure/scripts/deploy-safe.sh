#!/usr/bin/env bash
# ==============================================================================
# Naseebak (نصيبك) — Safe Isolated Deployment & Non-Destructive Migration Script
# Protects all existing customer containers on the shared Coolify VPS.
# ==============================================================================

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-infrastructure/coolify/docker-compose.coolify.yml}"
API_CONTAINER="${API_CONTAINER:-naseebak-api}"
PG_CONTAINER="${PG_CONTAINER:-naseebak-postgres}"
EXPECTED_DB_PREFIX="naseebak_"

echo "[1/7] Running pre-deployment VPS capacity check..."
bash infrastructure/scripts/assess-vps-capacity.sh

echo "[2/7] Verifying database isolation inside ${API_CONTAINER}..."
CURRENT_DB=$(docker exec "${API_CONTAINER}" php artisan tinker --execute="echo config('database.connections.pgsql.database');" | tr -d '\r\n')
if [[ "${CURRENT_DB}" != ${EXPECTED_DB_PREFIX}* ]]; then
    echo "[ABORT] Target database '${CURRENT_DB}' does not start with '${EXPECTED_DB_PREFIX}'. Refusing to run migrations!" >&2
    exit 1
fi
echo "  - Confirmed isolated Naseebak database: ${CURRENT_DB}"

echo "[3/7] Creating pre-migration recoverable backup..."
bash infrastructure/scripts/backup-naseebak.sh

echo "[4/7] Inspecting pending migrations (read-only status check)..."
docker exec "${API_CONTAINER}" php artisan migrate:status --no-interaction

echo "[5/7] Executing forward-safe production migrations..."
docker exec "${API_CONTAINER}" php artisan migrate --force --no-interaction

echo "[6/7] Caching Laravel configuration, routes, views & events and signaling queue workers..."
docker exec "${API_CONTAINER}" php artisan config:cache --no-interaction
docker exec "${API_CONTAINER}" php artisan route:cache --no-interaction
docker exec "${API_CONTAINER}" php artisan view:cache --no-interaction
docker exec "${API_CONTAINER}" php artisan event:cache --no-interaction
docker exec "${API_CONTAINER}" php artisan queue:restart --no-interaction

echo "[7/7] Verifying application readiness via /api/v1/health..."
docker exec "${API_CONTAINER}" curl -fsS http://127.0.0.1:8080/api/v1/health
echo ""
echo "[SUCCESS] Naseebak deployment and migrations verified cleanly."
