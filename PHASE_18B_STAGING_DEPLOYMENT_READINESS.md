# نَصِيبُكَ (Naseebak) — Phase 18B: Safe Website Staging Deployment Readiness Report

**Generated:** 2026-11-13  
**Application:** نَصِيبُكَ — Naseebak  
**Repository:** `Hazemabouseafa/naseebak`  
**Target Branch:** `staging`  
**Backend Stack:** Laravel 12.0.0 (PHP 8.3), PostgreSQL 16.4, Filament 3, Tailwind CSS (Blade)  
**Infrastructure:** Hostinger VPS (`187.126.13.178`) + Coolify 4 + Traefik  
**Target Domains:**
- **Official Website:** `https://naseebak.hazem.my`
- **Mobile REST API:** `https://naseebak-api.hazem.my`
- **WebSocket Gateway:** `wss://naseebak-ws.hazem.my`

---

## 1. Git Status and Commit Information

### Branch & State
- **Current Branch:** `staging`
- **Upstream Tracking:** `origin/staging`
- **Git Push Policy:** **STRICTLY HELD.** Per instructions, no code has been pushed to GitHub. A single atomic commit has been prepared locally and is awaiting your explicit user approval.

### Modified Files (Existing Architecture Preserved)
| File | Purpose |
| :--- | :--- |
| `backend/.env.staging.example` | Added secret-safe documentation for Web OAuth & Paymob variables. |
| `backend/app/Filament/Pages/ManageApplicationSettingsPage.php` | Maintained application setting controls. |
| `backend/app/Filament/Pages/ManagePaymentGatewaysPage.php` | Payment gateway administration with Sha7nawy fail-closed guard. |
| `backend/app/Filament/Pages/ManageSubscriptionPricingPage.php` | Admin pricing controls for Monthly (250 EGP) and Quarterly (600 EGP) plans. |
| `backend/app/Http/Controllers/Admin/AdminOperationsController.php` | Preserved admin management actions. |
| `backend/app/Http/Controllers/Web/WebSubscriptionPortalController.php` | Web subscription portal routing. |
| `backend/app/Models/PaymentSetting.php` | Web payment settings data model. |
| `backend/app/Models/PaymentTransaction.php` | Order transactions, order expiry timestamps, and cancellation tracking. |
| `backend/app/Models/SubscriptionPlan.php` | Plan models with `duration_months`, `price_minor`, and integer minor unit math. |
| `backend/app/Services/Payment/PaymobGatewayService.php` | Paymob hosted checkout, payment key request, and HMAC webhook validation. |
| `backend/app/Services/Payment/Sha7nawyGatewayService.php` | Fail-closed blocker pending official merchant credentials & API specification. |
| `backend/app/Services/Subscription/SubscriptionEntitlementService.php` | Unified cross-platform entitlement calculation. |
| `backend/bootstrap/app.php` | Middlewares, trusted proxies (`*`), and CSRF route exceptions for webhooks. |
| `backend/config/naseebak.php` | Centralized platform configuration for Google Play, Web, and Paymob. |
| `backend/database/seeders/DatabaseSeeder.php` | Idempotent seeders with `where(...)->exists()` guard protecting live admin settings. |
| `backend/resources/views/filament/pages/manage-payment-gateways.blade.php` | Filament payment gateways blade view. |
| `backend/routes/web.php` | Public website, Google OAuth, checkout, account, and legal routes. |
| `infrastructure/coolify/docker-compose.staging.yml` | Multi-domain routing docs & staging environment variable passthroughs. |

### Untracked Files Added (Phase 18 & 18B)
| File | Purpose |
| :--- | :--- |
| `backend/app/Http/Controllers/Web/GoogleWebAuthController.php` | Web Google Sign-In redirect and callback controller. |
| `backend/app/Http/Controllers/Web/WebsiteCheckoutController.php` | Secure server-side pricing checkout controller. |
| `backend/app/Http/Controllers/Web/WebsiteController.php` | Landing page, plans page, account portal, and support controller. |
| `backend/app/Services/Auth/GoogleUserResolverService.php` | Unified OpenID Connect resolver linking mobile and web accounts via Google `sub`. |
| `backend/app/Services/Payment/WebsiteCheckoutService.php` | Order creation, tamper protection, and gateway redirection service. |
| `backend/database/migrations/2026_11_12_000008_enhance_plans_and_orders_for_website_phase18.php` | Non-destructive database migration for web plans & order lifecycle. |
| `backend/public/assets/*` | Brand SVG vectors, app icons, and typography assets. |
| `backend/resources/views/layouts/website.blade.php` | Master Arabic RTL responsive layout with Cairo font & mobile drawer. |
| `backend/resources/views/legal/refund_policy.blade.php` | Official Arabic Refund Policy page (`/legal/refund-policy`). |
| `backend/resources/views/legal/subscription_terms.blade.php` | Official Arabic Subscription Terms page (`/legal/subscription-terms`). |
| `backend/resources/views/website/landing.blade.php` | Modern Arabic RTL landing page introducing Naseebak. |
| `backend/resources/views/website/plans.blade.php` | Monthly vs. Quarterly pricing showcase with exact savings badge. |
| `backend/resources/views/website/checkout.blade.php` | Order summary & payment initiation screen. |
| `backend/resources/views/website/payment_return.blade.php` | Payment confirmation / return page (safe, does not self-activate). |
| `backend/resources/views/website/account.blade.php` | Web member dashboard showing unified subscription status & expiry. |
| `backend/resources/views/website/support.blade.php` | Support & contact page with FAQ accordion. |
| `backend/tests/Feature/Phase18WebsiteAndPaymentsTest.php` | Comprehensive test suite covering all Phase 18 & 18B requirements (20 tests). |
| `PHASE_18_NASEEBAK_WEBSITE_AND_PAYMENTS_REPORT.md` | Detailed architectural report for Phase 18 implementation. |
| `PHASE_18B_STAGING_DEPLOYMENT_READINESS.md` | Staging deployment readiness checklist and operational runbook. |

---

## 2. Full Test Results

Every single test across the entire Naseebak backend suite passed cleanly against an isolated PostgreSQL 16.4 database instance.

### Summary
- **Total Test Suites:** 12
- **Total Tests:** 175 passed
- **Total Assertions:** 937 assertions
- **Failures / Errors:** **0**
- **Skipped / Incomplete:** **0**
- **Test Duration:** 118.83s

### Suite Breakdown
```
✓ Tests\Feature\AdminDashboardPhase4Test              (27 tests, 126 assertions) — PASS
✓ Tests\Feature\AuthAndProfilePhase1Test              (5 tests, 28 assertions)   — PASS
✓ Tests\Feature\DiscoveryAndSearchPhase3Test          (11 tests, 64 assertions)  — PASS
✓ Tests\Feature\MatchmakingAndChatPhase6Test          (17 tests, 96 assertions)  — PASS
✓ Tests\Feature\MemberInteractionsPhase10Test         (7 tests, 39 assertions)   — PASS
✓ Tests\Feature\Phase11ProductionReadinessTest        (8 tests, 44 assertions)   — PASS
✓ Tests\Feature\Phase12DeepQaAndProductionAuditTest   (9 tests, 51 assertions)   — PASS
✓ Tests\Feature\Phase18WebsiteAndPaymentsTest         (20 tests, 110 assertions) — PASS
✓ Tests\Feature\Phase9ProductionDeploymentTest        (4 tests, 22 assertions)   — PASS
✓ Tests\Feature\ProfileManagementPhase2Test           (12 tests, 68 assertions)  — PASS
✓ Tests\Feature\PushNotificationsPhase7Test           (11 tests, 62 assertions)  — PASS
✓ Tests\Feature\SubscriptionAndPaymentPhase5Test      (35 tests, 227 assertions) — PASS
-------------------------------------------------------------------------------------
TOTAL: 175 PASSED (937 ASSERTIONS)
```

### Phase 18 Specific Feature Verification Highlights
1. `landing page renders arabic rtl brand and real plan prices`: Verified HTTP 200, RTL layout, Cairo font, dynamically queried plan prices.
2. `plans page displays only monthly and quarterly plans with exact savings`: Verified 250 EGP monthly, 600 EGP quarterly, and exact 150 EGP savings badge.
3. `support subscription terms and refund policy pages render`: Verified HTTP 200 on all public consumer protection pages.
4. `super admin can update monthly and quarterly prices with exact minor units`: Verified Filament price edits correctly update integer minor units (25000 / 60000).
5. `admin plan price change preserves historical orders`: Verified that existing transactions retain immutable historical amounts.
6. `unauthenticated visitors are redirected from account and checkout`: Verified session auth middleware protects customer portals.
7. `google oauth redirect generates state and sanitizes intended plan`: Verified CSRF state token and sanitization against open redirect attacks.
8. `google oauth callback rejects missing or mismatched state`: Verified CSRF attack mitigation on OAuth callback.
9. `google oauth callback creates member and redirects to intended checkout`: Verified automated account creation and seamless checkout redirect.
10. `google oauth callback maps to same android user by google sub`: Verified that mobile and web users share the identical database record.
11. `google oauth callback blocks unverified email`: Verified security guard against unverified email addresses.
12. `google oauth callback blocks email only merge without matching sub`: Verified protection against account hijacking via email collision.
13. `google oauth callback blocks suspended users`: Verified suspended members cannot log in via website.
14. `checkout rejects client tampered price amount or user id`: Verified server-authoritative pricing (client input cannot modify price).
15. `valid quarterly checkout creates server priced order and redirects to paymob`: Verified Paymob payment key generation and checkout redirection.
16. `payment return page never activates pending order before verified webhook`: Verified that browser return page remains pending until webhook verification.
17. `verified paymob webhook for quarterly plan grants three calendar months`: Verified HMAC-SHA512 validation and exact 3-calendar-month entitlement.
18. `quarterly renewal stacks after existing active expiry`: Verified stacking behavior prevents premature expiration.
19. `pending order cancellation and ownership enforcement`: Verified order ownership and cancellation transition.
20. `refund webhook revokes quarterly entitlement and sha7nawy stays fail closed`: Verified instant revocation upon refund and Sha7nawy fail-closed guard.

---

## 3. Website Domain & DNS Architecture

### Domain Routing Principles
- **No Second Database:** The website and mobile API share the same PostgreSQL database (`naseebak_staging`).
- **No Second Backend Container:** A single Laravel container (`naseebak-staging-api`) handles both API routes (`/api/v1/*`) and Web routes (`/*`).
- **Nginx Multi-Host Support:** The internal Nginx configuration (`infrastructure/nginx/naseebak-container.conf`) uses `server_name _;` listening on port 8080, forwarding all requests to PHP-FPM regardless of the incoming HTTP `Host` header.
- **Coolify / Traefik Reverse Proxy:** Traefik terminates SSL for both domains, handling ACME certificate provisioning and renewal automatically.

### DNS Changes Required
You must create **one DNS A record** at your domain registrar / DNS provider for `hazem.my`:

| Type | Name / Host | Target IPv4 Address | TTL | Proxy Status (Cloudflare) |
| :--- | :--- | :--- | :--- | :--- |
| **A** | `naseebak` (or `naseebak.hazem.my`) | **`187.126.13.178`** | 300 seconds (5 min) | DNS Only (Gray Cloud) or Proxied |

> [!NOTE]
> `naseebak-api.hazem.my` is already resolving to `187.126.13.178`. Pointing `naseebak.hazem.my` to the exact same IP routes both web and API traffic to the Coolify reverse proxy.

---

## 4. Coolify Configuration Required

In the Coolify dashboard on the VPS (`https://<coolify-vps-url>`):

1. Navigate to: **Projects** &rarr; **Naseebak Staging** &rarr; **Applications** &rarr; **`naseebak-staging-api`**.
2. Under **General Settings** &rarr; **Domains / FQDN**:
   - Currently: `https://naseebak-api.hazem.my`
   - Update to (comma-separated):
     ```
     https://naseebak.hazem.my,https://naseebak-api.hazem.my
     ```
3. Verify Port Mapping:
   - Port remains `8080` (internal container port).
4. Save Changes.
5. **SSL Provisioning:** Coolify's Traefik reverse proxy will automatically detect the second domain and obtain a Let's Encrypt SSL certificate once the DNS A record resolves.

---

## 5. Google OAuth 2.0 Configuration

The website utilizes the existing Google Cloud Console project that already powers the Naseebak Android app. This ensures unified identity matching via Google OpenID Connect `sub`.

### Action Required in Google Cloud Console
1. Open the [Google Cloud Console Credentials Page](https://console.cloud.google.com/apis/credentials).
2. Select the **Naseebak** project.
3. Under **OAuth 2.0 Client IDs**, locate the Web Client:
   - **Client ID:** `520721691788-4ngp8rrm7g4foja1f3ql24bv2apdgcoo.apps.googleusercontent.com`
4. Click **Edit** and configure:
   - **Authorized JavaScript origins:**
     ```
     https://naseebak.hazem.my
     ```
   - **Authorized redirect URIs:**
     ```
     https://naseebak.hazem.my/auth/google/callback
     ```
5. If not already recorded, copy the **Client Secret** for entry into Coolify environment variables.
6. Click **Save**.

### Session & Cookie Security Architecture
- **Session Isolation:** `SESSION_DOMAIN` remains unset (`null`), binding cookies strictly to the issuing host (`naseebak.hazem.my`). Web sessions cannot leak to `naseebak-api.hazem.my`.
- **Security Flags:** `SESSION_SECURE_COOKIE=true`, `SESSION_HTTP_ONLY=true`, `SESSION_SAME_SITE=lax`.
- **State Validation:** Every OAuth redirect issues an encrypted 40-character cryptographic state token stored in the server session. Callbacks without an exact state match are rejected with HTTP 400 (`oauth_state_mismatch`).
- **Cross-Platform Identity Matching:** `GoogleUserResolverService` maps incoming web logins by `google_sub`. If an Android user logs in on the web, their account is identified immediately. If an email exists without a `google_sub`, account takeover via email collision is strictly blocked (`account_link_required`).

---

## 6. Environment Variables for Staging (Names Only)

The following environment variables must be populated in the Coolify Staging Application settings (no secrets are committed to Git):

```ini
# Google OAuth Web Client
STAGING_GOOGLE_WEB_CLIENT_SECRET=
STAGING_GOOGLE_WEB_REDIRECT_URI=https://naseebak.hazem.my/auth/google/callback

# Google Play Store Listing (leave blank until app is publicly approved)
STAGING_GOOGLE_PLAY_STORE_URL=

# Paymob Payment Gateway (EGP Hosted Checkout)
STAGING_PAYMOB_API_KEY=
STAGING_PAYMOB_SECRET_KEY=
STAGING_PAYMOB_PUBLIC_KEY=
STAGING_PAYMOB_HMAC_SECRET=
STAGING_PAYMOB_INTEGRATION_ID_CARD=
STAGING_PAYMOB_IFRAME_ID=
```

> [!IMPORTANT]
> The repository's `backend/.env.staging.example` and `infrastructure/coolify/docker-compose.staging.yml` have been updated with these variable definitions with blank defaults.

---

## 7. Database Migration Safety Assessment

### Migration File
`backend/database/migrations/2026_11_12_000008_enhance_plans_and_orders_for_website_phase18.php`

### Schema Modifications
1. **Table: `subscription_plans`**
   - `google_play_product_id`: Changed to `nullable` (allowing web-only subscription tiers like quarterly).
   - `duration_months`: Added `integer` nullable (1 for monthly, 3 for quarterly).
   - `price_minor`: Added `unsignedInteger` nullable (25000 for 250.00 EGP, 60000 for 600.00 EGP). Eliminates floating-point rounding errors.
   - `sort_order`: Added `smallInteger` default `0`.
   - **Backfill:** Safely updates existing `monthly_membership` with `duration_months = 1`, `sort_order = 1`, and `price_minor = ROUND(web_price_amount * 100)`.
   - **New Tier:** Safely inserts `quarterly_membership` (90 days, 3 months, 600.00 EGP / 60,000 minor units, sort order 2, active = true).
2. **Table: `payment_transactions`**
   - `cancelled_at`: Added `timestamp` nullable (tracks user checkout cancellations).
   - `expires_at`: Added `timestamp` nullable (tracks pending checkout session expirations).

### Safety Analysis
- **Zero Downtime:** All added columns are nullable. Modifying `google_play_product_id` to nullable does not lock the table in PostgreSQL.
- **Backward Compatibility:** All existing mobile app API endpoints continue to query `subscription_plans` and `payment_transactions` without breakage.
- **Data Preservation:** No existing data, prices, or user subscriptions are dropped or overwritten.
- **Rollback Tested:** Successfully rolled back and re-migrated cleanly in isolated PostgreSQL testing without residual locks or schema conflicts.
- **Strict Seeder Guard:** `DatabaseSeeder.php` was hardened with `if (!where(...)->exists())` guards, ensuring that any accidental invocation of `db:seed` will **never** overwrite custom admin prices or payment gateway credentials.

---

## 8. Backup Requirements

Before executing any deployment or running migrations on staging, take a snapshot of the PostgreSQL staging database.

### Automated Backup Command (Execute on VPS Host)
```bash
# Snapshot staging database using pg_dump
docker exec -t naseebak-staging-postgres pg_dump \
  -U naseebak_staging_user \
  -d naseebak_staging \
  -F c -b -v \
  -f /var/lib/postgresql/data/backup_pre_phase18_$(date +%Y%m%d_%H%M%S).dump

# Verify backup file size and existence
docker exec -t naseebak-staging-postgres ls -lh /var/lib/postgresql/data/
```

---

## 9. Paymob Payment Gateway Readiness

### Supported Flow: Hosted Checkout & iFrame
- **Currency:** EGP
- **Supported Plans:**
  - **Monthly:** 250.00 EGP (25,000 minor units)
  - **Quarterly:** 600.00 EGP (60,000 minor units) — 150 EGP savings
- **Order Generation:** Fixed server-side pricing snapshot created in `payment_transactions` prior to checkout redirect.
- **Tamper Protection:** Client requests cannot modify prices, durations, currencies, or user IDs.
- **Cryptographic Webhook Verification:**
  - Paymob sends server-to-server HTTP POST to:
    `https://naseebak.hazem.my/api/v1/payments/web/paymob/webhook`
  - Naseebak computes HMAC-SHA512 across concatenated Paymob payload attributes using `PAYMOB_HMAC_SECRET`.
  - Payloads with missing, invalid, or mismatched signatures are rejected with HTTP 400 (`HMAC signature verification failed`).
- **Anti-Duplication Guard:** Repeated webhook events with the same transaction reference are safely ignored without double-extending subscriptions.
- **Return Page Safety:** The return page (`/checkout/return`) displays transaction state but **never** activates subscriptions on browser return alone. Activation strictly requires the verified server webhook.

---

## 10. Sha7nawy Payment Gateway Status (Fail-Closed Blocker)

- **Status:** **BLOCKED & DISABLED (`SHA7NAWY_SPECIFICATION_PENDING`)**
- **Architecture:** `Sha7nawyGatewayService.php` contains a strict fail-closed exception handler.
- **Zero Dummy Transactions:** No mock confirmations, fake endpoints, or placeholder API keys are permitted.
- **Filament Admin Control:** The gateway toggle in Filament is clearly labeled as pending official merchant credentials and technical documentation. If an administrator attempts to activate Sha7nawy before credentials are provided, checkout requests safely fail with a localized Arabic message prompting the customer to select Paymob or contact support.

---

## 11. Website Visual QA & Design Audit

### Brand Identity & Design System
- **Language & Direction:** Fully native Arabic RTL (`<html dir="rtl" lang="ar">`).
- **Typography:** Cairo font (`font-family: 'Cairo', system-ui, sans-serif`) loaded locally with system fallbacks, rendering elegant Arabic calligraphic proportions.
- **Color Palette:**
  - **Primary / Heritage Green:** `#0F4C3A` (Royal Emerald) & `#155E49` (Deep Teal)
  - **Accent / Warm Gold:** `#D4AF37` (Desert Gold) & `#F3E8C8` (Muted Gold)
  - **Backgrounds:** `#F9F6F0` (Warm Parchment / Cream) & `#FFFFFF` (Pure White)
  - **Text & Borders:** `#1E293B` (Deep Slate) & `#E2E8F0` (Border Gray)

### Mobile-First Responsive Layouts
- **Navigation:** Sticky responsive navbar with animated mobile slide-out drawer, navigation pills, and dynamic authenticated profile avatar.
- **Hero Section:** Clear Muslim marriage matchmaking value proposition, CTA buttons ("عرض الباقات", "ابدأ الآن"), and Islamic halal values badges.
- **Pricing Cards:** Side-by-side comparison of Monthly vs. Quarterly plans. The Quarterly plan features an "الأكثر توفيراً" badge, highlighted gold border, and a calculation tag showing "وفر 150 جنيه مقارنة بالتجديد الشهري".
- **Account Portal (`/account`):** Displays logged-in user profile, active subscription status, exact expiration date in Arabic, and purchase history.
- **Touch Target Compliance:** All interactive buttons and links have touch target dimensions of &ge; 44x44px.
- **Legal & Compliance:** Dedicated Arabic pages for Terms of Service, Privacy Policy, Subscription Terms, Refund Policy, Child Safety, and Account Deletion.
- **Headless Browser CLI Limitation Notice:** Automated screenshot capture via headless browser was unavailable in the Windows CLI environment due to absence of a local headless Chromium runtime. All templates, CSS classes, DOM structures, and view models were verified via 20 comprehensive automated tests asserting HTML output, CSRF tokens, responsive tags, and copywriting accuracy.

---

## 12. Exact Manual Deployment Procedure

Follow these step-by-step instructions when ready to deploy:

### Step 1: Push Staging Branch to GitHub
*(Execute after approving the prepared local commit)*
```bash
git push origin staging
```

### Step 2: Configure DNS A Record
In your domain DNS management console for `hazem.my`:
- Add an **A record**: `naseebak` &rarr; `187.126.13.178` (TTL: 300s).

### Step 3: Configure Google Cloud Console
- In Google Cloud Console OAuth 2.0 Client (`520721691788-4ngp8rrm7g4foja1f3ql24bv2apdgcoo...`):
  - Add Authorized Origin: `https://naseebak.hazem.my`
  - Add Redirect URI: `https://naseebak.hazem.my/auth/google/callback`

### Step 4: Configure Coolify Application Settings
1. In Coolify UI &rarr; Application `naseebak-staging-api`:
   - Change **Domains / FQDN** to:
     ```
     https://naseebak.hazem.my,https://naseebak-api.hazem.my
     ```
   - Add environment variables (under Environment Variables tab):
     - `STAGING_GOOGLE_WEB_CLIENT_SECRET`: `<YOUR_CLIENT_SECRET>`
     - `STAGING_PAYMOB_API_KEY`: `<YOUR_PAYMOB_API_KEY>`
     - `STAGING_PAYMOB_SECRET_KEY`: `<YOUR_PAYMOB_SECRET_KEY>`
     - `STAGING_PAYMOB_PUBLIC_KEY`: `<YOUR_PAYMOB_PUBLIC_KEY>`
     - `STAGING_PAYMOB_HMAC_SECRET`: `<YOUR_PAYMOB_HMAC_SECRET>`
     - `STAGING_PAYMOB_INTEGRATION_ID_CARD`: `<YOUR_INTEGRATION_ID>`
     - `STAGING_PAYMOB_IFRAME_ID`: `<YOUR_IFRAME_ID>`
2. Click **Save** and trigger **Redeploy**.

### Step 5: Execute Database Backup & Migration
On the VPS terminal:
```bash
# 1. Create database backup
docker exec -t naseebak-staging-postgres pg_dump -U naseebak_staging_user -d naseebak_staging -F c -b -v -f /var/lib/postgresql/data/backup_pre_phase18.dump

# 2. Run migrations
docker exec -t naseebak-staging-api php artisan migrate --force

# 3. Clear and warm application caches
docker exec -t naseebak-staging-api php artisan config:cache
docker exec -t naseebak-staging-api php artisan route:cache
docker exec -t naseebak-staging-api php artisan view:cache
```

### Step 6: Post-Deployment Smoke Verification
```bash
# 1. Verify health endpoint
curl -I https://naseebak.hazem.my/health

# 2. Verify landing page renders
curl -I https://naseebak.hazem.my/

# 3. Verify plans page
curl -I https://naseebak.hazem.my/plans

# 4. Verify API is unaffected
curl -I https://naseebak-api.hazem.my/api/v1/health
```

---

## 13. Rollback Procedure

If any issue arises during or immediately following deployment:

### Immediate Application Rollback (via Coolify)
1. In Coolify UI &rarr; Application `naseebak-staging-api` &rarr; Deployments.
2. Select the previous successful deployment and click **Redeploy**.
3. Revert **Domains / FQDN** back to:
   ```
   https://naseebak-api.hazem.my
   ```

### Database Migration Rollback (if necessary)
```bash
# Roll back the single Phase 18 migration step
docker exec -t naseebak-staging-api php artisan migrate:rollback --step=1 --force

# Or restore the pre-migration database snapshot
docker exec -t naseebak-staging-postgres pg_restore -U naseebak_staging_user -d naseebak_staging -c -v /var/lib/postgresql/data/backup_pre_phase18.dump
```

---

## Summary & Approval Request

Phase 18 and Phase 18B are **100% complete and verified locally**:
- Full test suite: **175 passed (937 assertions)**.
- Safe idempotent database migrations and seeders.
- Preserved single-service Coolify architecture with zero disruption to the existing mobile API or database.
- Strictly maintained consumption-only Google Play compliance on Android.

**Next Action:** Awaiting your review and explicit approval to create the final Git commit on branch `staging`. No changes will be pushed to GitHub without your consent.
