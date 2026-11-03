#!/usr/bin/env bash
# ==============================================================================
# Naseebak (نصيبك) — Shared 4GB VPS Capacity & Coolify Isolation Assessor
# READ-ONLY SCRIPT: Never modifies, restarts, or deletes any customer services.
# Enforces hard safety thresholds before any Naseebak container deployment.
# ==============================================================================

set -euo pipefail

MIN_AVAILABLE_MEMORY_WITH_SWAP_MB="${MIN_AVAILABLE_MEMORY_WITH_SWAP_MB:-1350}"
MIN_FREE_DISK_MB="${MIN_FREE_DISK_MB:-8192}"

echo "=================================================================="
echo " Naseebak (نصيبك) — Shared Production VPS Capacity Assessment"
echo " Timestamp (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "=================================================================="

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
USED_RAM_MB=$(free -m | awk '/^Mem:/ {print $3}')
AVAIL_RAM_MB=$(free -m | awk '/^Mem:/ {print $7}')
TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/ {print $2}')
FREE_SWAP_MB=$(free -m | awk '/^Swap:/ {print $4}')
EFFECTIVE_HEADROOM_MB=$((AVAIL_RAM_MB + FREE_SWAP_MB))

FREE_DISK_MB=$(df -m / | awk 'NR==2 {print $4}')
TOTAL_DISK_MB=$(df -m / | awk 'NR==2 {print $2}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)

echo "[1/5] Host Memory & Swap:"
echo "  - Total RAM:          ${TOTAL_RAM_MB} MB"
echo "  - Used RAM:           ${USED_RAM_MB} MB"
echo "  - Available RAM:      ${AVAIL_RAM_MB} MB"
echo "  - Total Swap:         ${TOTAL_SWAP_MB} MB (Free: ${FREE_SWAP_MB} MB)"
echo "  - Effective Headroom: ${EFFECTIVE_HEADROOM_MB} MB (Required: >= ${MIN_AVAILABLE_MEMORY_WITH_SWAP_MB} MB)"

echo ""
echo "[2/5] Host Storage (/):"
echo "  - Total Disk:         ${TOTAL_DISK_MB} MB"
echo "  - Free Disk:          ${FREE_DISK_MB} MB (Required: >= ${MIN_FREE_DISK_MB} MB)"

echo ""
echo "[3/5] CPU Load Average:"
echo "  - Load Average:       ${LOAD_AVG}"

echo ""
echo "[4/5] Existing Running Docker Containers (Read-Only):"
if command -v docker >/dev/null 2>&1; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" || true
else
    echo "  - Docker CLI not accessible to current user."
fi

echo ""
echo "[5/5] Capacity Gate Evaluation (Naseebak Peak Budget = 1,248 MB):"
if [ "${EFFECTIVE_HEADROOM_MB}" -lt "${MIN_AVAILABLE_MEMORY_WITH_SWAP_MB}" ]; then
    echo "  [BLOCKER] Insufficient memory headroom (${EFFECTIVE_HEADROOM_MB} MB < ${MIN_AVAILABLE_MEMORY_WITH_SWAP_MB} MB)." >&2
    echo "  Recommendation: Provision a 2 GB swapfile or upgrade VPS RAM before starting Naseebak containers." >&2
    exit 2
fi

if [ "${FREE_DISK_MB}" -lt "${MIN_FREE_DISK_MB}" ]; then
    echo "  [BLOCKER] Insufficient free disk space (${FREE_DISK_MB} MB < ${MIN_FREE_DISK_MB} MB)." >&2
    exit 3
fi

echo "  [PASS] VPS satisfies memory and disk safety thresholds for isolated Naseebak deployment."
