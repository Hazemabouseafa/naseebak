#!/usr/bin/env bash
# ==============================================================================
# Naseebak (نصيبك) — Shared Ubuntu VPS Pre-Deployment Resource & Service Inspector
# Target Spec: Ubuntu VPS (4 GB RAM, 50 GB Disk) hosting existing customer apps.
# SAFE READ-ONLY SCRIPT: Does NOT modify, restart, or overwrite any services.
# ==============================================================================

set -euo pipefail

echo "=== [1/8] System & OS Information ==="
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release

echo ""
echo "=== [2/8] Available RAM & Swap Usage ==="
free -h

echo ""
echo "=== [3/8] Disk Usage (50 GB Shared VPS Check) ==="
df -hT

echo ""
echo "=== [4/8] Running Services (Systemd) ==="
systemctl list-units --type=service --state=running --no-pager

echo ""
echo "=== [5/8] Installed PHP & PHP-FPM Versions ==="
which php && php -v || echo "PHP CLI not in default PATH"
ls -la /run/php/ 2>/dev/null || true

echo ""
echo "=== [6/8] Database Services (PostgreSQL / MySQL / Redis) ==="
pg_isready 2>/dev/null || echo "PostgreSQL client check skipped or not running"
ss -tulpn | grep -E ':(5432|3306|6379|80|443|8080)\b' || true

echo ""
echo "=== [7/8] Existing Nginx Virtual Hosts (Read-Only) ==="
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || true

echo ""
echo "=== [8/8] Top Memory-Consuming Processes ==="
ps aux --sort=-%mem | head -n 15
