#!/usr/bin/env bash
# ==============================================================================
# Naseebak (نصيبك) — Safe Non-Destructive Application Rollback Script
# Reverts Naseebak containers to a known-good IMAGE_TAG without destroying
# production PostgreSQL records or private member photos, and without
# touching any other customer containers on the shared VPS.
# ==============================================================================

set -euo pipefail

PREVIOUS_IMAGE_TAG="${1:?Usage: rollback-naseebak.sh <previous-image-tag>}"
COMPOSE_FILE="${COMPOSE_FILE:-infrastructure/coolify/docker-compose.coolify.yml}"

echo "=================================================================="
echo " Naseebak (نصيبك) — Rolling back application to ${PREVIOUS_IMAGE_TAG}"
echo "=================================================================="

export IMAGE_TAG="${PREVIOUS_IMAGE_TAG}"

echo "[1/3] Recreating only Naseebak stateless application containers (preserving naseebak-postgres & volumes)..."
docker compose -f "${COMPOSE_FILE}" up -d --no-deps \
    naseebak-api \
    naseebak-worker \
    naseebak-reverb \
    naseebak-scheduler

echo "[2/3] Clearing and warming caches on rolled-back naseebak-api container..."
docker exec naseebak-api php artisan optimize:clear --no-interaction
docker exec naseebak-api php artisan config:cache --no-interaction
docker exec naseebak-api php artisan route:cache --no-interaction
docker exec naseebak-api php artisan view:cache --no-interaction
docker exec naseebak-api php artisan queue:restart --no-interaction

echo "[3/3] Verifying health endpoint on rolled-back release..."
docker exec naseebak-api curl -fsS http://127.0.0.1:8080/api/v1/health
echo ""
echo "[SUCCESS] Rollback to ${PREVIOUS_IMAGE_TAG} completed safely."
