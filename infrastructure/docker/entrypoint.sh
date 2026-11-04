#!/usr/bin/env sh
set -eu

ROLE="${CONTAINER_ROLE:-app}"

# Ensure persistent private photo storage & framework cache directories exist with writable permissions
mkdir -p \
    /var/www/html/storage/app/private/member-photos \
    /var/www/html/storage/app/backups \
    /var/www/html/storage/framework/cache/data \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs \
    /var/www/html/bootstrap/cache

if [ "${APP_ENV:-production}" = "production" ] || [ "${APP_ENV:-production}" = "staging" ]; then
    php artisan config:cache --no-interaction
    php artisan route:cache --no-interaction
    php artisan view:cache --no-interaction
    php artisan event:cache --no-interaction
fi

case "$ROLE" in
    app)
        echo "[Naseebak] Starting HTTP Application role (PHP-FPM + Nginx on :8080)..."
        if [ -n "${PHP_FPM_MAX_CHILDREN:-}" ]; then
            sed -i "s/^pm.max_children = .*/pm.max_children = ${PHP_FPM_MAX_CHILDREN}/" /usr/local/etc/php-fpm.d/www.conf
        fi
        php-fpm -D
        exec nginx -g "daemon off;"
        ;;
    worker)
        echo "[Naseebak] Starting Queue Worker role..."
        exec php artisan queue:work "${QUEUE_CONNECTION:-database}" \
            --sleep=3 \
            --tries=3 \
            --timeout=90 \
            --memory="${WORKER_MEMORY:-128}" \
            --max-jobs=500 \
            --max-time=3600 \
            --no-interaction
        ;;
    reverb)
        echo "[Naseebak] Starting Laravel Reverb WebSocket Server role on :${REVERB_SERVER_PORT:-8081}..."
        exec php artisan reverb:start \
            --host="${REVERB_SERVER_HOST:-0.0.0.0}" \
            --port="${REVERB_SERVER_PORT:-8081}" \
            --no-interaction
        ;;
    scheduler)
        echo "[Naseebak] Starting Single Laravel Scheduler role (60s interval)..."
        while true; do
            php artisan schedule:run --verbose --no-interaction
            sleep 60
        done
        ;;
    *)
        echo "[Naseebak] Unknown CONTAINER_ROLE: $ROLE" >&2
        exit 1
        ;;
esac
