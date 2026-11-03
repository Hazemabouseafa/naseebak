# نصيبك (Naseebak) — Phase 9: Secure Production Deployment, Coolify Infrastructure & Live Backend Integration

**Application:** نصيبك — Naseebak (Arabic Matrimonial Platform — Android & Self-Hosted Web Backend)  
**Phase:** Phase 9 — Production Infrastructure, Coolify Deployment & Application Integration  
**Framework Stack:** Laravel `12.71.0` (Security-Supported) + Filament `v3.3.57` + PHP `8.3.36` + PostgreSQL `16.4` + Laravel Reverb `v1.12.0` + Flutter `3.47.9` (Dart `3.13.7`)  
**Target Host Profile:** Shared Ubuntu Production VPS (`4 GB RAM`, `50 GB Disk`, Coolify Installed, Hosting Existing Customer Workloads)  

---

## 1. Executive Classification Matrix (20 Required Components)

| # | Component / Verification Gate | Classification | Verification Scope | Evidence & Execution Summary |
| :---: | :--- | :---: | :---: | :--- |
| **1** | **Laravel Security Upgrade (`v11.57.1` -> `v12.71.0`)** | **PASS** | Local Verification | Upgraded `laravel/framework` to `v12.71.0` (`^12.0`). `composer audit` exited with code `0` (`No security vulnerability advisories found`), resolving all 5 CVEs affecting Laravel 11 / `<12.69.0`. |
| **2** | **Filament 3 Compatibility (`v3.3.57` on Laravel 12)** | **PASS** | Local Verification | Verified `filament/filament v3.3.57` and `livewire/livewire v3.8.11` on Laravel `12.71.0`. All 25 administrative auth, RBAC, moderation, and audit log tests in `AdminDashboardPhase4Test` passed (`exit code 0`). |
| **3** | **Production Docker & Coolify Manifest Configuration** | **PASS** | Local Verification | Authored reproducible multi-stage [`backend/Dockerfile`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/Dockerfile), [`entrypoint.sh`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/docker/entrypoint.sh), [`naseebak-container.conf`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/nginx/naseebak-container.conf), [`docker-compose.coolify.yml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/coolify/docker-compose.coolify.yml), and [`docker-compose.staging.yml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/coolify/docker-compose.staging.yml). |
| **4** | **Coolify Live VPS Deployment Status** | **BLOCKED** | Staging / Prod VPS | Live SSH / Coolify API access and target domain names have not yet been provided. In compliance with Section 2, no live VPS changes were attempted without explicit authorization. |
| **5** | **PostgreSQL 16 Schema & Migration Verification** | **PASS** | Local Verification | Verified all 27 public tables on PostgreSQL `16.4` (`UTC`). `php artisan migrate --force` and full **140-test suite (683 assertions)** passed on Laravel `12.71.0` (`exit code 0`). |
| **6** | **Database Migration Safety & Isolation Script** | **PASS** | Local Verification | Created [`deploy-safe.sh`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/scripts/deploy-safe.sh) which verifies the database name starts with `naseebak_`, takes a pre-migration backup, and runs `php artisan migrate --force`. |
| **7** | **Private Photo Storage Disk & Volume Isolation** | **PASS** | Local Verification | Created [`config/filesystems.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/config/filesystems.php) defining the `private` disk (`serve => false`, zero public symlinks). Mounted `naseebak_private_photos` exclusively at `/var/www/html/storage/app/private`. |
| **8** | **HTTPS Enforcement & Trusted Proxy Configuration** | **PASS** | Local Verification | Configured `trustProxies` in [`bootstrap/app.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/bootstrap/app.php) and `URL::forceScheme('https')` in [`AppServiceProvider.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Providers/AppServiceProvider.php). Live TLS certificate issuance on Coolify is **BLOCKED** pending domain assignment. |
| **9** | **Administrator Access & RBAC/MFA Verification** | **PASS** | Local Verification | Verified separate `auth:admin` guard, `naseebak:make-super-admin` CLI provisioning command, RBAC policies, and `/admin/operations/health` access controls (`AdminDashboardPhase4Test` + `Phase9ProductionDeploymentTest`). |
| **10** | **REST API Health & Readiness Endpoints** | **PASS** | Local Verification | Implemented [`HealthCheckController.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Controllers/Api/V1/HealthCheckController.php) (`/api/v1/health` public probe + `/admin/operations/health` admin diagnostics) and verified via `Phase9ProductionDeploymentTest` (`4/4 PASS`). |
| **11** | **Queue Worker Configuration & Job Processing** | **PASS** | Local Verification | Configured `CONTAINER_ROLE=worker` (`php artisan queue:work database --sleep=3 --tries=3 --timeout=90 --memory=192 --max-jobs=500 --max-time=3600`). Verified job queueing, chunked campaign dispatch, and idempotency in feature tests. |
| **12** | **Laravel Reverb WebSocket Server & Channel Auth** | **PASS** | Local Verification | Configured `CONTAINER_ROLE=reverb` on internal port `8081` behind Coolify `wss://` proxy. Verified private channel authorization (`private-conversation.{id}`, `private-user.{id}`) and non-participant rejection (`403`). |
| **13** | **Flutter Multi-Environment (`dev`/`staging`/`prod`) Integration** | **PASS** | Local Verification | Implemented [`app_environment.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/core/config/app_environment.dart), Android [`network_security_config.xml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/android/app/src/main/res/xml/network_security_config.xml) (`cleartextTrafficPermitted="false"`), and [`phase9_environment_and_api_config_test.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/test/phase9_environment_and_api_config_test.dart). `flutter analyze` (`0 issues`) & `flutter test` (**30 / 30 PASS**). |
| **14** | **Google Sign-In Production Configuration** | **BLOCKED** | External Credentials | Server-side OIDC verification and `com.naseebak.app` binding are implemented and tested locally (`PASS`); live OAuth testing requires production Google Cloud Android SHA-1/SHA-256 & Web Client IDs. |
| **15** | **Firebase Cloud Messaging (FCM HTTP v1) Live Delivery** | **BLOCKED** | External Credentials | FCM HTTP v1 service, privacy-redacted payloads, and Section 14 token invalidation rules pass all 11 backend & 6 mobile tests (`PASS`); live device push requires production `google-services.json` and Firebase service account JSON. |
| **16** | **Payment Integrations (Google Play Billing, Paymob, Sha7nawy)** | **BLOCKED** | External Credentials | All 35 billing & webhook security tests pass locally (`PASS`); live sandbox/production checkout requires Play Console merchant setup and Paymob/Sha7nawy credentials. |
| **17** | **PostgreSQL & Private Photo Backup + Isolated Restore** | **PASS** | Local Verification | Executed `pg_dump -Fc` (`134,094 bytes`) + private photo archive and restored into isolated `naseebak_restore_verify` database (`27 tables` verified, photo SHA-256 `0936618C04C6C867C2B88B42599F873BE1586DA262BB2AFAF127849FD5F873FE` matched byte-for-byte). |
| **18** | **Shared 4 GB VPS Resource Budget & Capacity Script** | **PASS** | Local / Script Ready | Authored [`assess-vps-capacity.sh`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/scripts/assess-vps-capacity.sh) enforcing `>= 1,350 MB` effective memory headroom and `>= 8 GB` free disk; capped total Naseebak stack at `1,248 MB`. Live VPS measurement is **BLOCKED** pending SSH access. |
| **19** | **Version Control & Secret Exclusion (`.gitignore` + Tag)** | **PASS** | Local Verification | Initialized Git repository, verified `git check-ignore -v backend/.env` (`exit code 0`), and created release tag `v1.0.0-phase9` with zero secrets committed. |
| **20** | **Non-Destructive Rollback Procedure** | **PASS** | Local Verification | Authored [`rollback-naseebak.sh`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/scripts/rollback-naseebak.sh) to roll back `naseebak-api`, `naseebak-worker`, `naseebak-reverb`, and `naseebak-scheduler` to a previous `IMAGE_TAG` without touching `naseebak-postgres` or private photos. |

---

## 2. Critical Security Upgrade: Laravel 11 -> Laravel 12.71.0

### 2.1 Compatibility Evaluation & Vulnerability Audit
1. **Why Laravel 11 Was Upgraded:** Laravel 11 reached end of security support on March 12, 2026, and `composer audit` on `v11.57.1` reported **5 security advisories** (`CVE-2026-114509` critical, `CVE-2026-102279`, `PKSA-m5cs-t1y6-qpcs`, `PKSA-3r5d-mb8f-1qw9`, `CVE-2026-48019`).
2. **Laravel 12 vs Laravel 13 Assessment:**
   - `composer require "laravel/framework:^13.0" --dry-run -W` showed that `filament/filament v3.3.57` and `laravel/tinker v2.11.1` constrain `illuminate/support` to `^11.0|^12.0`.
   - `composer require "laravel/framework:^12.0" -W` resolved cleanly to **Laravel `v12.71.0`**, which is actively security-supported and 100% compatible with `filament/filament v3.3.57`, `laravel/reverb v1.12.0`, `laravel/sanctum v4.3.3`, and `intervention/image-laravel v1.5.9`.
3. **Post-Upgrade Verification Results:**
   - `composer audit`: **`No security vulnerability advisories found.`** (`exit code 0`)
   - `php artisan about`: Laravel `12.71.0`, Filament `v3.3.57`, Livewire `v3.8.11`, PHP `8.3.36` (`exit code 0`)
   - `php artisan test`: **`140 passed (683 assertions), 0 failed`** (`exit code 0`)

---

## 3. Shared 4 GB VPS Resource Budget & Coolify Isolation Architecture

To protect existing customer applications running on the shared 4 GB Ubuntu VPS, Naseebak uses a single Docker image (`naseebak/backend:${IMAGE_TAG}`) running in four lightweight process roles plus one dedicated PostgreSQL 16.4 Alpine container — **with zero Node.js and zero Redis containers**:

| Container Name | Role (`CONTAINER_ROLE`) | Hard Memory Limit | CPU Limit | Network Exposure |
| :--- | :--- | :---: | :---: | :--- |
| `naseebak-postgres` | PostgreSQL `16.4-alpine` (`shared_buffers=128MB`, `max_connections=60`) | `384 MB` | `0.75` | `naseebak_internal` only (**Port 5432 never exposed on host**) |
| `naseebak-api` | Nginx + PHP 8.3 FPM (`pm.max_children = 6`, OPcache `96MB`) | `384 MB` | `0.75` | `naseebak_internal` + `coolify` (`:8080` behind Coolify HTTPS proxy) |
| `naseebak-worker` | `php artisan queue:work database --sleep=3 --tries=3 --timeout=90 --memory=192` | `192 MB` | `0.35` | `naseebak_internal` only |
| `naseebak-reverb` | `php artisan reverb:start --host=0.0.0.0 --port=8081` | `160 MB` | `0.35` | `naseebak_internal` + `coolify` (`:8081` behind Coolify WSS proxy) |
| `naseebak-scheduler` | Single 60-second `php artisan schedule:run` loop | `128 MB` | `0.20` | `naseebak_internal` only |
| **Total Naseebak Peak Cap** | **All 5 Isolated Containers Combined** | **`1,248 MB` (`1.22 GB`)** | **`2.40` vCPU** | **Leaves `~2.78 GB` RAM for Ubuntu OS, Coolify & existing customer apps** |

---

## 4. Persistent Private User Photo Storage Architecture

Inspection of [`SecurePhotoStorageService.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Profile/SecurePhotoStorageService.php#L72-L75) confirmed that sanitized member photos are stored via:
```php
$relativeStoragePath = "member-photos/{$user->id}/{$safeFilename}";
Storage::disk('private')->put($relativeStoragePath, $sanitizedBinary);
```
1. **Explicit Disk Configuration:** [`backend/config/filesystems.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/config/filesystems.php) defines the `private` disk rooted at `env('PRIVATE_STORAGE_ROOT', storage_path('app/private'))` (`/var/www/html/storage/app/private`), with `'serve' => false`, `'visibility' => 'private'`, and `'links' => []` (no `public/storage` symlink).
2. **Targeted Volume Mount:** In [`docker-compose.coolify.yml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/coolify/docker-compose.coolify.yml), the named Docker volume `naseebak_private_photos` is mounted exclusively at `/var/www/html/storage/app/private` in `naseebak-api` and `naseebak-worker`. This guarantees:
   - Uploaded member photos (`member-photos/{user_id}/{uuid}.jpg`) survive container restarts, image rebuilds, and redeployments.
   - Application source code (`/var/www/html/app`, `/var/www/html/public`, `/var/www/html/vendor`) is never masked by a broad volume mount.
   - Every photo stream request (`/api/v1/profile/photos/{photo}/stream` and `/admin/operations/photos/{photo}/stream`) passes through Laravel authentication and privacy authorization with `Cache-Control: private, no-store`.

---

## 5. Production Environment Variable Names Reference

Configure the following environment variables in Coolify's encrypted Secret Store (template provided in [`backend/.env.production.example`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/.env.production.example) — **never commit secret values**):

- **Core Application:** `APP_NAME`, `APP_ENV` (`production`), `APP_KEY`, `APP_DEBUG` (`false`), `APP_TIMEZONE` (`UTC`), `APP_URL`, `APP_LOCALE` (`ar`), `TRUSTED_PROXIES` (`*`), `LOG_CHANNEL` (`daily`), `LOG_LEVEL` (`warning`).
- **PostgreSQL Database:** `DB_CONNECTION` (`pgsql`), `DB_HOST` (`naseebak-postgres`), `DB_PORT` (`5432`), `DB_DATABASE` (`naseebak_prod`), `DB_USERNAME` (`naseebak_user`), `DB_PASSWORD`.
- **Sessions, Cache & Queue:** `SESSION_DRIVER` (`database`), `SESSION_LIFETIME` (`120`), `SESSION_ENCRYPT` (`true`), `SESSION_SECURE_COOKIE` (`true`), `SESSION_HTTP_ONLY` (`true`), `SESSION_SAME_SITE` (`lax`), `CACHE_STORE` (`database`), `QUEUE_CONNECTION` (`database`).
- **Private Storage:** `FILESYSTEM_DISK` (`private`), `PRIVATE_STORAGE_ROOT` (`/var/www/html/storage/app/private`).
- **Laravel Reverb WebSockets:** `BROADCAST_CONNECTION` (`reverb`), `REVERB_APP_ID`, `REVERB_APP_KEY`, `REVERB_APP_SECRET`, `REVERB_SERVER_HOST` (`0.0.0.0`), `REVERB_SERVER_PORT` (`8081`), `REVERB_HOST` (`naseebak-reverb`), `REVERB_PORT` (`8081`), `REVERB_SCHEME` (`http`), `REVERB_PUBLIC_HOST`.
- **Google Sign-In & Play Billing:** `GOOGLE_ANDROID_CLIENT_ID`, `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_PLAY_PACKAGE_NAME` (`com.naseebak.app`), `GOOGLE_PLAY_MONTHLY_SUBSCRIPTION_ID`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH`, `GOOGLE_PLAY_RTDN_OIDC_AUDIENCE`, `GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL`.
- **FCM Push Notifications:** `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON_PATH`.
- **Web Payment Gateways:** `PAYMOB_API_KEY`, `PAYMOB_SECRET_KEY`, `PAYMOB_PUBLIC_KEY`, `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID_CARD`, `PAYMOB_IFRAME_ID`, `SHA7NAWY_BASE_URL`, `SHA7NAWY_API_KEY`, `SHA7NAWY_MERCHANT_ID`, `SHA7NAWY_WEBHOOK_SECRET`.
- **Off-Server Backups:** `BACKUP_DISK_DRIVER` (`s3`), `BACKUP_S3_ACCESS_KEY_ID`, `BACKUP_S3_SECRET_ACCESS_KEY`, `BACKUP_S3_DEFAULT_REGION`, `BACKUP_S3_BUCKET`, `BACKUP_S3_ENDPOINT`, `BACKUP_RETENTION_DAYS` (`14`), `BACKUP_ENCRYPTION_PASSPHRASE`.

---

## 6. Flutter Multi-Environment Build-Time Configuration

[`mobile/lib/core/config/app_environment.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/core/config/app_environment.dart) and [`mobile/lib/core/constants/api_endpoints.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/core/constants/api_endpoints.dart) support `development`, `staging`, and `production` via `--dart-define` without hardcoding `localhost` or private IP addresses:

### 6.1 Building for Isolated Staging Verification
```bash
flutter build apk --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://<STAGING_DOMAIN>/api/v1 \
  --dart-define=REVERB_WS_URL=wss://<STAGING_WS_DOMAIN>/app/<STAGING_REVERB_KEY>?protocol=7&client=flutter&version=1.0 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<STAGING_WEB_CLIENT_ID>.apps.googleusercontent.com
```

### 6.2 Building for Production Release
```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://<PRODUCTION_DOMAIN>/api/v1 \
  --dart-define=REVERB_WS_URL=wss://<PRODUCTION_WS_DOMAIN>/app/<PRODUCTION_REVERB_KEY>?protocol=7&client=flutter&version=1.0 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<PRODUCTION_WEB_CLIENT_ID>.apps.googleusercontent.com
```

---

## 7. Step-by-Step Coolify Deployment, Backup & Rollback Procedures

1. **Pre-Deployment VPS Assessment (Read-Only):**
   ```bash
   bash infrastructure/scripts/assess-vps-capacity.sh
   ```
   Verifies `>= 1,350 MB` available memory + swap and `>= 8,192 MB` free disk space without touching any existing container.
2. **Coolify Project Creation:**
   - In Coolify, create a dedicated project **`naseebak`** with two isolated environments: `staging` (`infrastructure/coolify/docker-compose.staging.yml`) and `production` (`infrastructure/coolify/docker-compose.coolify.yml`).
   - Configure Coolify's existing proxy to route `https://<DOMAIN>` to `naseebak-api:8080` and `/app/*` (or `wss://<WS_DOMAIN>`) to `naseebak-reverb:8081` with WebSocket upgrade headers enabled.
3. **Safe Database Migration & Cache Warmup:**
   ```bash
   bash infrastructure/scripts/deploy-safe.sh
   ```
4. **Provision Initial Super Administrator (Interactive CLI — No Default Passwords):**
   ```bash
   docker exec -it naseebak-api php artisan naseebak:make-super-admin
   ```
5. **Automated Daily Backup & Isolated Restore Verification:**
   ```bash
   bash infrastructure/scripts/backup-naseebak.sh
   bash infrastructure/scripts/verify-restore.sh /var/backups/naseebak/db/<latest>.dump /var/backups/naseebak/photos/<latest>.tar.gz
   ```
6. **Non-Destructive Rollback (Preserves All User Data & Private Photos):**
   ```bash
   bash infrastructure/scripts/rollback-naseebak.sh <PREVIOUS_IMAGE_TAG>
   ```
