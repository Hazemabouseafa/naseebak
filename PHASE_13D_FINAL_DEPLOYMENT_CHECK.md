# نَصِيبُكَ — PHASE 13D FINAL DEPLOYMENT CHECK REPORT
## COOLIFY NATIVE ROUTING, REAL DOCKER COMPOSE VALIDATION & PRE-DEPLOYMENT AUDIT

**Date:** November 4, 2026  
**Application Name:** نَصِيبُكَ (Naseebak)  
**Package Identifier:** `com.naseebak.app`  
**Target Environment:** Hostinger Ubuntu VPS (`187.126.13.178`) + Coolify  
**Target Branch:** `staging`  
**GitHub Repository:** `https://github.com/Hazemabouseafa/naseebak` (Private)  

---

## 1. COOLIFY NATIVE DOMAIN ROUTING

In accordance with Phase 13D Hotfix requirements, all manually defined and potentially conflicting `traefik.http.routers...` labels have been completely removed from `infrastructure/coolify/docker-compose.staging.yml`. 

External traffic routing and TLS/SSL certificate issuance are now handled **natively by Coolify** through its web UI and internal proxy orchestration.

### 1.1 Verified Container Listening Ports
| Service | Listening Port | Process / Web Server | Configuration File |
| :--- | :--- | :--- | :--- |
| **API & Admin** (`naseebak-staging-api`) | **8080** | Nginx 1.22 + PHP-FPM 8.3 | [`infrastructure/nginx/naseebak-container.conf`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/nginx/naseebak-container.conf#L2) |
| **Reverb WebSockets** (`naseebak-staging-reverb`) | **8081** | Laravel Reverb WebSocket Server | [`infrastructure/docker/entrypoint.sh`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/docker/entrypoint.sh#L44) |
| **PostgreSQL Database** (`naseebak-staging-postgres`) | **5432** | PostgreSQL 16.4 Alpine | Internal container network ONLY (`expose: 5432`). **Zero public host port binding.** |

### 1.2 Exact Service Route Mapping in Coolify
When creating or editing the Docker Compose application inside the Coolify UI, set the public domains in each service's configuration tab:

- **Laravel REST API & Filament Admin:**
  ```text
  Domain / FQDN: https://naseebak-api.hazem.my
  Port: 8080
  ```
- **Laravel Reverb WebSockets:**
  ```text
  Domain / FQDN: https://naseebak-ws.hazem.my
  Port: 8081
  ```

---

## 2. REAL DOCKER COMPOSE VALIDATION RESULTS

The Docker Compose configuration was directly validated using the standalone **Docker Compose v2.30.2 engine** (`docker-compose.exe -f infrastructure/coolify/docker-compose.staging.yml config`) with safe, non-production placeholder values.

### 2.1 Validation Audit Checklist
- [x] **Compose Syntax & Semantics:** Validated successfully with exit code `0`.
- [x] **Relative Build Contexts:** `context: ../..` resolved cleanly to the repository root directory (`naseebak/`).
- [x] **Dockerfile Availability:** `backend/Dockerfile` exists and all build dependencies exist at expected paths:
  - `backend/composer.json` (Verified)
  - `backend/composer.lock` (Verified)
  - `infrastructure/docker/php-production.ini` (Verified)
  - `infrastructure/nginx/naseebak-container.conf` (Verified)
  - `infrastructure/docker/entrypoint.sh` (Verified)
- [x] **Container Dependencies:**
  - `naseebak-staging-postgres` starts first and runs healthcheck `pg_isready`.
  - `naseebak-staging-api` depends on `naseebak-staging-postgres` (`condition: service_healthy`).
  - `worker`, `reverb`, and `scheduler` depend on both `postgres: healthy` and `api: service_started`.
- [x] **Network Isolation:**
  - Internal Network: `naseebak_staging_internal` (bridge) isolates database, queues, and scheduler.
  - External Network: `coolify` (external bridge) connects only `api` (8080) and `reverb` (8081) to Coolify's reverse proxy.
  - PostgreSQL is completely absent from the `coolify` network.
- [x] **Persistent Volumes:**
  - `naseebak_staging_pgdata` mounts `/var/lib/postgresql/data` (preserves staging DB).
  - `naseebak_staging_private_photos` mounts `/var/www/html/storage/app/private` (preserves private member photos).
- [x] **Cumulative Memory Limits (Exact 800 MB Hard Cap):**
  - `naseebak-staging-postgres`: `224 MB` (234,881,024 bytes)
  - `naseebak-staging-api`: `256 MB` (268,435,456 bytes)
  - `naseebak-staging-worker`: `128 MB` (134,217,728 bytes)
  - `naseebak-staging-reverb`: `96 MB` (100,663,296 bytes)
  - `naseebak-staging-scheduler`: `96 MB` (100,663,296 bytes)
  - **Total Cumulative Allocation:** **800 MB** (fits safely within the 4 GB Hostinger VPS memory budget without impacting co-hosted websites).

---

## 3. SECURITY & GOOGLE OAUTH AUDIT

1. **Keystore SHA-1 Fingerprint:**
   - Command: `keytool -list -v -keystore C:\Users\w.i\.android\debug.keystore -alias androiddebugkey`
   - Actual Fingerprint: `67:6F:17:E7:9C:02:FC:8C:42:30:06:4E:B2:6E:0E:BE:CA:5D:5C:95`
   - Comparison with Expected: **100% Exact Match.**
2. **Android Package Name:** Confirmed `com.naseebak.app`.
3. **OAuth Client Identifiers:**
   - Android Client ID: `520721691788-0fki6oqjcsjtk6g9qbo2ean3fj3cpeq2.apps.googleusercontent.com`
   - Web Client ID: `520721691788-4ngp8rrm7g4foja1f3ql24bv2apdgcoo.apps.googleusercontent.com`
4. **Secret Exposure Audit:**
   - Web Client Secret: **Zero exposure** in client APK, Dart defines, or Git.
   - Private Keys / Keystores: Confirmed excluded via `.gitignore`.
   - Real User Data: Zero real data or `.env` files tracked.
5. **Production Build Safety Guard:**
   - `AppEnvironmentConfig.fromBuildDefines()` in [`mobile/lib/core/config/app_environment.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/core/config/app_environment.dart) strictly prevents production builds from falling back to staging or defaulting to missing endpoints.

---

## 4. AUTOMATED TEST SUITE RESULTS

| Verification Gate | Command Executed | Result | Duration / Details |
| :--- | :--- | :--- | :--- |
| **Docker Compose Config** | `docker-compose.exe ... config` | **Valid** | 0 errors; resolved all build contexts & memory limits |
| **Flutter Static Analysis** | `flutter analyze` | **0 Issues Found** | Ran in 83.4s across entire Flutter codebase |
| **Flutter Test Suite** | `flutter test` | **43 Passed** | 100% pass across all widgets, responsiveness, and safety gates |
| **Laravel Automated Tests** | `php artisan test` | **152 Passed** | 780 assertions passed in 113.9s |
| **Android Debug APK** | `flutter build apk --debug` | **Built Successfully** | `app-debug.apk` (193,396,622 bytes) |

---

## 5. EXACT COOLIFY APPLICATION SETUP VALUES

When configuring the application inside Coolify:

### 5.1 Resource Configuration
- **Type:** Docker Compose
- **Repository:** `Hazemabouseafa/naseebak` (Private)
- **Branch:** `staging`
- **Compose File Location:** `infrastructure/coolify/docker-compose.staging.yml`
- **Base Directory:** `/`

### 5.2 Service Domains (Coolify UI)
- `naseebak-staging-api`: `https://naseebak-api.hazem.my` (Port 8080)
- `naseebak-staging-reverb`: `https://naseebak-ws.hazem.my` (Port 8081)

### 5.3 Staging Environment Variables to Supply in Coolify
```dotenv
STAGING_IMAGE_TAG=v1.0.0-rc1
STAGING_APP_ENV=staging
STAGING_APP_DEBUG=false
STAGING_APP_NAME=Naseebak
STAGING_APP_URL=https://naseebak-api.hazem.my
STAGING_ADMIN_URL=https://naseebak-api.hazem.my/admin

STAGING_DB_DATABASE=naseebak_staging
STAGING_DB_USERNAME=naseebak_staging_user
STAGING_DB_PASSWORD=<GENERATE_STRONG_RANDOM_PASSWORD>

STAGING_APP_KEY=<GENERATE_WITH_php_artisan_key:generate_--show>

STAGING_REVERB_APP_ID=892101
STAGING_REVERB_APP_KEY=nsb_stg_key_sandbox
STAGING_REVERB_APP_SECRET=<GENERATE_SECURE_SECRET>
STAGING_REVERB_PUBLIC_HOST=naseebak-ws.hazem.my
STAGING_REVERB_PUBLIC_SCHEME=https

STAGING_GOOGLE_ANDROID_CLIENT_ID=520721691788-0fki6oqjcsjtk6g9qbo2ean3fj3cpeq2.apps.googleusercontent.com
STAGING_GOOGLE_WEB_CLIENT_ID=520721691788-4ngp8rrm7g4foja1f3ql24bv2apdgcoo.apps.googleusercontent.com
STAGING_GOOGLE_PLAY_PACKAGE_NAME=com.naseebak.app
STAGING_GOOGLE_PLAY_MONTHLY_SUBSCRIPTION_ID=naseebak_monthly_membership

# Transactional Email (Account Deletion)
STAGING_MAIL_MAILER=smtp
STAGING_MAIL_HOST=<SMTP_HOST>
STAGING_MAIL_PORT=587
STAGING_MAIL_USERNAME=<SMTP_USERNAME>
STAGING_MAIL_PASSWORD=<SMTP_PASSWORD>
STAGING_MAIL_ENCRYPTION=tls
STAGING_MAIL_FROM_ADDRESS=noreply@hazem.my
STAGING_MAIL_FROM_NAME="نَصِيبُكَ"
```

---

## 6. GITHUB PUSH READINESS

- **Branch:** `staging`
- **Target Repository:** `Hazemabouseafa/naseebak` (Private)
- **Pre-Push Commit:** All hotfix changes committed cleanly.
- **Safety Status:** No remote push has been performed. No automatic deployment has been triggered. Awaiting explicit owner authorization.
