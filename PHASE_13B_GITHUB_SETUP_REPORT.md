# نَصِيبُكَ — NASEEBAK
## PHASE 13B: GITHUB REPOSITORY SETUP, SECURITY AUDIT & COOLIFY PREPARATION REPORT

---

### Executive Summary

| Parameter | Value / Status |
| :--- | :--- |
| **Application Name** | **نَصِيبُكَ — Naseebak** (Arabic Matrimonial Platform) |
| **Phase** | Phase 13B — GitHub Repository Setup & Staging Preparation |
| **GitHub Target Repository** | [`https://github.com/Hazemabouseafa/naseebak`](https://github.com/Hazemabouseafa/naseebak) |
| **Repository Visibility** | **PRIVATE** (Verified via GitHub API) |
| **GitHub Authenticated User** | `Hazemabouseafa` (CLI Token Scopes: `repo`, `read:org`, `gist`) |
| **Deployment Target Branch** | `staging` |
| **Security Audit Status** | **PASSED (100% Clean)** — Zero active secrets, zero private keys, zero live tokens in tracked files or Git history |
| **Docker Compose Validation** | **PASSED (Valid YAML & Contexts)** — Exactly 800 MB hard memory cap across 5 isolated containers |
| **Remote Push Status** | **AWAITING OWNER APPROVAL** (Local repo configured; remote created; push held per safety protocol) |
| **VPS Deployment Status** | **STOPPED (Preflight Completed)** — Zero containers deployed to VPS |

---

## 1. Project Component Verification

All components developed across Phases 1–13A have been preserved, verified, and integrated into the dedicated deployment branch `staging`:

| Component | Path / Manifest | Verification Status |
| :--- | :--- | :--- |
| **Flutter Mobile App** | `mobile/lib/main.dart`, `mobile/pubspec.yaml` | Verified (Riverpod, Astra Design System, Screens 1–24, Android Gradle configs) |
| **Laravel 12 REST API** | `backend/app/`, `backend/composer.json` | Verified (152 passing tests, 780 assertions, Sanctum auth, Policy checks) |
| **PostgreSQL Migrations** | `backend/database/migrations/` | Verified (Complete relational schema, private photo metadata, legal compliance) |
| **Filament Admin Panel** | `backend/app/Filament/` | Verified (Filament v3 resources, user moderation, subscriptions, safety audit) |
| **Laravel Reverb Server** | `backend/config/reverb.php` | Verified (Real-time authenticated chat WebSockets, private channels) |
| **Docker Configuration** | `backend/Dockerfile`, `infrastructure/docker/entrypoint.sh` | Verified (Multi-role container, Nginx 8080 unprivileged, PHP 8.3 FPM, OOM-safe) |
| **Coolify Staging Stack** | `infrastructure/coolify/docker-compose.staging.yml` | Verified (Isolated PostgreSQL 16.4, API, Worker, Reverb, Scheduler; 800MB cap) |
| **Environment Templates** | `.env.staging.example`, `backend/.env.staging.example` | Created & Verified (Safe template manifests with explicit placeholder variables) |

---

## 2. Git Repository & Staging Branch Status

### Branch Topology
- **Active Working Branch:** `staging`
- **Source Checkpoint Branch:** `phase-13a-vps-preflight-staging` (Tag: `checkpoint-phase-13a-complete`, Commit: `c947621`)
- **Staging Initial Commit:** `8fef6b3` (`feat(phase-13b): prepare staging branch, Coolify stack environment template, and deployment manifests`)

### Strict `.gitignore` Verification
The repository `.gitignore` has been audited and guarantees strict exclusion of:
- All `.env` files (`.env`, `.env.*`, `backend/.env`) except sanitized example templates (`.env.example`, `.env.staging.example`, `.env.production.example`).
- Cloud credentials, service accounts (`*service-account*.json`, `*firebase-adminsdk*.json`, `google-services.json`).
- Cryptographic private keys and certificates (`*.pem`, `*.key`, `*.jks`, `*.keystore`, `key.properties`, `id_rsa*`, `id_ed25519*`).
- Private user data and runtime storage (`backend/storage/app/private/member-photos/*`, `backend/storage/logs/*.log`, `backend/storage/framework/cache/data/*`).
- Dependencies and build caches (`backend/vendor/`, `backend/node_modules/`, `mobile/build/`, `mobile/.dart_tool/`, `mobile/android/.gradle/`).

---

## 3. Comprehensive Pre-Upload Security Audit

A deep automated security scan was performed across all tracked files (`git ls-files`) and full commit history (`git log -p`):

| Target Scanned | Patterns Evaluated | Result | Findings / Actions |
| :--- | :--- | :--- | :--- |
| **Tracked File Names** | `\.env$`, `\.key$`, `\.pem$`, `\.keystore$`, `service-account`, `google-services\.json` | **PASSED** | Only placeholder example files tracked (`google-services.json.example`, `.env.staging.example`). |
| **Tracked File Contents** | RSA/EC/SSH private keys, Google API keys (`AIza...`), GitHub tokens (`ghp_...`), Live `APP_KEY`, Live passwords | **PASSED** | Zero leaked credentials. Reports contain only documentation placeholders (`GENERATE_NEW_SECURE_PASSWORD`). |
| **Git Commit History** | `git log -p -G` scanning all 23 historical commits for secrets, certificates, and credentials | **PASSED** | Zero secret values ever committed in any past commit. |
| **Database Passwords** | `DB_PASSWORD=...` | **PASSED** | Empty or placeholder strings only. |
| **Payment Secrets** | `PAYMOB_API_KEY=`, `PAYMOB_SECRET_KEY=`, `PAYMOB_HMAC_SECRET=` | **PASSED** | Unset placeholder values only. |
| **Firebase / Google Keys** | `GOOGLE_ANDROID_CLIENT_ID=`, `FCM_PROJECT_ID=` | **PASSED** | Unset placeholder values only. |

> [!NOTE]
> No production credentials or secrets exist in the repository. Credential rotation is **NOT required** because no real secrets were ever committed to Git.

---

## 4. Private GitHub Repository Creation & Verification

Using the authenticated GitHub CLI (`gh`) under account **Hazemabouseafa**:

1. **Existence Check:** Verified `Hazemabouseafa/naseebak` did not previously exist (no overwrite risk).
2. **Repository Creation:** Created the private repository via GitHub API:
   - **Repository URL:** `https://github.com/Hazemabouseafa/naseebak`
   - **SSH URL:** `git@github.com:Hazemabouseafa/naseebak.git`
   - **Visibility:** `PRIVATE` (Confirmed: `{"isPrivate": true, "visibility": "PRIVATE"}`)
   - **Description:** `نَصِيبُكَ (Naseebak) — Arabic matrimonial platform (Flutter + Laravel 12 + Filament 3 + Reverb + PostgreSQL)`
3. **Local Remote Configuration:**
   - Configured `origin` remote:
     ```bash
     git remote add origin https://github.com/Hazemabouseafa/naseebak.git
     ```
4. **Push Protocol Enforcement:**
   - Per Phase 13B instructions, **no code has been pushed to the remote repository yet**.
   - The initial remote push is waiting for explicit user approval.

---

## 5. Staging Docker Compose Validation

The staging Docker stack at `infrastructure/coolify/docker-compose.staging.yml` was parsed and verified using Symfony YAML:

```
SUCCESS: Valid YAML syntax!
Services count: 5
 - naseebak-staging-postgres      | Memory: 224M   | CPU: 0.40
 - naseebak-staging-api           | Memory: 256M   | CPU: 0.50
 - naseebak-staging-worker        | Memory: 128M   | CPU: 0.20
 - naseebak-staging-reverb        | Memory: 96M    | CPU: 0.15
 - naseebak-staging-scheduler     | Memory: 96M    | CPU: 0.15
Total Memory Limit across services: 800 MB
Volumes count: 2 (naseebak_staging_pgdata, naseebak_staging_private_photos)
Networks count: 2 (naseebak_staging_internal, coolify)
```

### Build Context & Dockerfile Verification
- **Compose Service Build:**
  ```yaml
  naseebak-staging-api:
    build:
      context: ../..
      dockerfile: backend/Dockerfile
  ```
  - When Coolify executes Docker Compose inside `infrastructure/coolify`, `context: ../..` resolves to the repository root (`/`).
  - `backend/Dockerfile` is located at `<root>/backend/Dockerfile`.
  - All referenced files (`backend/composer.json`, `infrastructure/docker/php-production.ini`, `infrastructure/nginx/naseebak-container.conf`, `infrastructure/docker/entrypoint.sh`) exist and are tracked in the Git repository.

---

## 6. Exact Coolify Staging Settings & Connection Runbook

### A. Repository Connection (Coolify Official GitHub App)
1. In the Coolify dashboard (`http://<vps-ip>:8000` or custom Coolify dashboard URL):
   - Navigate to **Sources** -> **GitHub App**.
   - If the Coolify GitHub App is already connected to `Hazemabouseafa`:
     - Open GitHub -> **Settings** -> **Applications** -> **Installed GitHub Apps** -> **Coolify**.
     - Under **Repository Access**, ensure **Only select repositories** is selected, and add `Hazemabouseafa/naseebak`.
2. In Coolify:
   - Create Project: `Naseebak`
   - Create Environment: `staging`
   - Click **+ New Resource** -> **Private Repository (with GitHub App)**.
   - Select: `Hazemabouseafa/naseebak`.

### B. Coolify Deployment Parameters

| Setting Field | Exact Value to Enter |
| :--- | :--- |
| **Repository URL** | `https://github.com/Hazemabouseafa/naseebak` |
| **Build Pack / Strategy** | **Docker Compose** |
| **Branch** | `staging` |
| **Base Directory** | `/` (Repository Root) |
| **Docker Compose Location** | `infrastructure/coolify/docker-compose.staging.yml` |
| **Auto-Deploy on Push** | **DISABLED (Unchecked)** — Mandatory to prevent unexpected deployments |

### C. Required Coolify Environment Variables
Enter these in Coolify under **Configuration** -> **Environment Variables**:

```dotenv
# Docker Image
STAGING_IMAGE_TAG=v1.0.0-rc1

# Isolated PostgreSQL 16 Credentials
STAGING_DB_DATABASE=naseebak_staging
STAGING_DB_USERNAME=naseebak_staging_user
STAGING_DB_PASSWORD=GENERATE_STRONG_RANDOM_PASSWORD_32_CHARS

# Laravel Security Key (Generate with: php artisan key:generate --show)
STAGING_APP_KEY=base64:GENERATE_NEW_UNIQUE_STAGING_KEY=

# Staging URL & WebSockets
STAGING_APP_URL=https://staging-api.YOUR_DOMAIN
STAGING_REVERB_APP_ID=nsb_stg_app
STAGING_REVERB_APP_KEY=nsb_stg_key_sandbox
STAGING_REVERB_APP_SECRET=GENERATE_STRONG_REVERB_SECRET
STAGING_REVERB_PUBLIC_HOST=staging-api.YOUR_DOMAIN
```

---

## 7. Temporary Domain & Network Strategy

> [!WARNING]
> Do not attempt live mobile testing or payment callbacks over unencrypted HTTP or unverified temporary wildcard domains (`*.sslip.io`).

1. **Protocol Limitations on Temporary URLs:**
   - **Android Cleartext Restrictions:** Android 9+ enforces TLS. Unencrypted HTTP endpoints are blocked by the OS network stack.
   - **Google Sign-In:** Google OAuth reject non-HTTPS callback and verification origins.
   - **Laravel Sanctum & Session Cookies:** `SESSION_SECURE_COOKIE=true` mandates HTTPS for cookie transmission.
   - **Reverb WebSockets:** Mobile client requires `wss://` (secure WebSockets).
   - **Paymob Webhooks:** Post-checkout server-to-server callbacks require a reachable HTTPS URL.
2. **Recommended Staging Domain Architecture:**
   - Map a real subdomain (e.g. `staging-api.domain.com`) via DNS A Record to the VPS IP.
   - Allow Coolify's built-in Traefik reverse proxy to automatically generate a trusted Let's Encrypt TLS certificate.
   - Set `STAGING_APP_URL=https://staging-api.domain.com` and `STAGING_REVERB_PUBLIC_HOST=staging-api.domain.com`.

---

## 8. Remaining Blockers & Next Actions

1. **Awaiting User Push Approval:**
   - The private repository is ready at `https://github.com/Hazemabouseafa/naseebak`.
   - The push command to execute upon approval:
     ```bash
     git push -u origin staging
     ```
2. **Subsequent Phase (Phase 14 / Deployment):**
   - Server owner runs read-only VPS capacity preflight (`free -h`, `df -h`, `docker ps`).
   - Configure Coolify GitHub App and Staging Environment Variables.
   - Trigger initial manual build in Coolify.
   - Run staging database migrations and seeders inside container.
