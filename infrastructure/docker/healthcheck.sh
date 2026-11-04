#!/usr/bin/env sh
set -e

ROLE="${CONTAINER_ROLE:-app}"

case "$ROLE" in
    app)
        # Verify Nginx and PHP-FPM are serving the public health endpoint with HTTP 200
        curl -fsS http://127.0.0.1:8080/api/v1/health >/dev/null 2>&1 || exit 1
        ;;
    reverb)
        # Verify Reverb is bound and accepting TCP socket connections on the configured port
        php -r '$p = (int)(getenv("REVERB_SERVER_PORT") ?: 8081); $fp = @fsockopen("127.0.0.1", $p, $e1, $e2, 2); exit($fp ? 0 : 1);' || exit 1
        ;;
    worker)
        # Verify queue worker process is active and running
        pgrep -f "artisan queue:work" >/dev/null 2>&1 || exit 1
        ;;
    scheduler)
        # Verify scheduler process or loop is active
        pgrep -f "naseebak-entrypoint.sh" >/dev/null 2>&1 || pgrep -f "schedule:run" >/dev/null 2>&1 || exit 1
        ;;
    *)
        exit 1
        ;;
esac

exit 0
