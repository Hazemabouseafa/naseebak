# ==============================================================================
# Naseebak (نصيبك) — Production Multi-Role Dockerfile (Laravel 12 + PHP 8.3)
# Roles supported via CONTAINER_ROLE: app | worker | reverb | scheduler
# ==============================================================================
FROM composer:2.8 AS vendor

WORKDIR /app
COPY backend/composer.json backend/composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --no-autoloader \
    --ignore-platform-reqs

FROM php:8.3-fpm-bookworm AS runtime

LABEL org.opencontainers.image.title="Naseebak Backend (نصيبك)"
LABEL org.opencontainers.image.description="Laravel 12 REST API, Filament 3 Admin, Reverb WebSockets & Queue Worker"

# Install only required runtime libraries and Nginx (no Node.js, no Redis server)
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    ca-certificates \
    libpq-dev \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    libfreetype6-dev \
    libonig-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql \
        pgsql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        intl \
        zip \
        opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure PHP-FPM pool for 4GB shared VPS (~48MB per worker, max 6 children = ~288MB peak)
RUN sed -i 's/^pm = .*/pm = dynamic/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^pm.max_children = .*/pm.max_children = 6/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^pm.start_servers = .*/pm.start_servers = 2/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 1/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 3/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^;pm.max_requests = .*/pm.max_requests = 500/' /usr/local/etc/php-fpm.d/www.conf

# Configure Nginx to run unprivileged on port 8080 and serve /var/www/html/public exclusively
COPY infrastructure/docker/php-production.ini /usr/local/etc/php/conf.d/99-naseebak-production.ini
COPY infrastructure/nginx/naseebak-container.conf /etc/nginx/sites-available/default
RUN rm -f /etc/nginx/conf.d/default.conf \
    && mkdir -p /var/lib/nginx /var/log/nginx /run/nginx \
    && chown -R www-data:www-data /var/lib/nginx /var/log/nginx /run/nginx /etc/nginx

WORKDIR /var/www/html

# Copy application source and locked production vendor dependencies
COPY --chown=www-data:www-data backend/ /var/www/html/
COPY --from=vendor --chown=www-data:www-data /app/vendor /var/www/html/vendor
COPY --from=vendor /usr/bin/composer /usr/bin/composer

# Generate optimized, authoritative classmap now that full source and runtime extensions exist
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev --no-scripts --ignore-platform-reqs \
    && rm -f /usr/bin/composer \
    && chown -R www-data:www-data /var/www/html/vendor

COPY --chown=www-data:www-data infrastructure/docker/entrypoint.sh /usr/local/bin/naseebak-entrypoint.sh

RUN chmod +x /usr/local/bin/naseebak-entrypoint.sh \
    && rm -f /var/www/html/.env \
    && rm -f /var/www/html/bootstrap/cache/*.php \
    && mkdir -p \
        /var/www/html/storage/app/private/member-photos \
        /var/www/html/storage/app/backups \
        /var/www/html/storage/framework/cache/data \
        /var/www/html/storage/framework/sessions \
        /var/www/html/storage/framework/views \
        /var/www/html/storage/logs \
        /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 770 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 8080 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD if [ "${CONTAINER_ROLE:-app}" = "app" ]; then curl -fsS http://127.0.0.1:8080/api/v1/health || exit 1; else pgrep -f "artisan" >/dev/null || exit 1; fi

ENTRYPOINT ["/usr/local/bin/naseebak-entrypoint.sh"]
