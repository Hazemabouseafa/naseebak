# نصيبك — NASEEBAK: PHASE 5 IMPLEMENTATION REPORT
## Complete Subscription & Payment Management System

---

## 1. Filament Compatibility Correction & Technical Debt Note

- **Correction to Phase 4 Report:** Filament v5 exists in the ecosystem. In our current [composer.json](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/composer.json), the project currently specifies `"filament/filament": "^3.2"` without a `composer.lock` file because `php` and `composer` binaries are not installed on this local Windows development machine.
- **No Blind Upgrade Rule:** Because upgrading Filament major versions without a local PHP/Composer runtime to resolve dependencies, publish assets, and run tests would be an unverified blind upgrade, the existing Filament v3.2 panel implementation has been preserved intact and updated for Phase 5, while upgrading to **Filament v5** is documented as **outstanding technical debt** to be executed and validated when running `composer` in the target PHP runtime environment.

---

## 2. Unified Subscription Architecture & Entitlement Rules

### Centralized Entitlement Service ([`SubscriptionEntitlementService`](file:///C:/Users/w.i\.gemini/antigravity/scratch/naseebak/backend/app/Services/Subscription/SubscriptionEntitlementService.php))
- **Supported Payment Channels:** `google_play`, `paymob`, `sha7nawy`.
- **Canonical Lifecycle States:**
  - `pending` (mapped from `pending` / `pending_payment` — **never grants access**)
  - `active` (**grants access** while `ends_at > now()`)
  - `cancelled` (**retains access** until the already-paid period `ends_at` expires)
  - `in_grace_period` (mapped from `in_grace_period` / `grace_period` — **retains access** while `grace_period_ends_at > now()`)
  - `on_hold` (**restricts access immediately** until payment is recovered)
  - `expired` (**denies new matchmaking requests and messages** while preserving account, profile, matchmaking requests, and conversation history)
  - `refunded` / `revoked` (**revokes or recalculates entitlement immediately**)
- **Overlapping Paid Periods Protection:** When a member with an existing valid entitlement purchases or renews a subscription, [`SubscriptionEntitlementService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Subscription/SubscriptionEntitlementService.php) locks the user and subscription rows (`lockForUpdate()`) and calculates the new expiration from `max(now(), existing_valid_ends_at)` so a valid subscription is **never shortened**.
- **Backend Middleware & Reusable Checks:** [`EnsureActiveSubscription`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Middleware/EnsureActiveSubscription.php) delegates to `SubscriptionEntitlementService::hasActiveSubscription()` and returns HTTP `403` with `code: "SUBSCRIPTION_REQUIRED"`. Both [`User`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Models/User.php) and [`SubscriptionEntitlementService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Subscription/SubscriptionEntitlementService.php) expose `hasActiveSubscription()`, `canSendMatchRequest()`, and `canSendMessage()`.

---

## 3. Database Schema Enhancements ([2026_11_02_000005_enhance_subscriptions_and_payments_for_phase5.php](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/database/migrations/2026_11_02_000005_enhance_subscriptions_and_payments_for_phase5.php))

- **`subscriptions` table (additive columns):**
  - `google_play_purchase_token_hash` (`VARCHAR(64) UNIQUE NULLABLE`) — SHA-256 digest of the purchase token for fast indexed lookup and cross-account replay prevention without exposing plaintext tokens.
  - `on_hold_at` (`TIMESTAMPTZ NULLABLE`) — Timestamp when Google Play placed the subscription on account hold.
  - `expired_at` (`TIMESTAMPTZ NULLABLE`) — Timestamp when the subscription transitioned to `expired`.
- **`payment_transactions` table (additive columns):**
  - `internal_reference` (`VARCHAR(64) UNIQUE NULLABLE`) — Immutable server-generated order reference (`NSB-PMB-...`, `NSB-SH7-...`, `NSB-GP-...`).
  - `amount_minor` (`BIGINT UNSIGNED NULLABLE`) — Fixed amount snapshot in integer minor currency units (piastres/cents, e.g. `25000` for `250.00 EGP`).
  - `paid_at` (`TIMESTAMPTZ NULLABLE`) — Authoritative payment timestamp.
- **`payment_webhook_events` table:**
  - Stores `(provider, provider_event_id)` with a composite `UNIQUE` constraint (`uq_provider_webhook_event`) for idempotent deduplication of Google Play RTDN Pub/Sub messages and Paymob/Sha7nawy webhooks.

---

## 4. Google Play Billing & Real-Time Developer Notifications (RTDN)

### Backend Verification ([`GooglePlayBillingService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Subscription/GooglePlayBillingService.php))
- Queries the official Google Play Developer API v3 endpoint:
  `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptionsv2/tokens/{token}`
- Verifies package name (`com.naseebak.app`), product ID (`naseebak_monthly_membership`), `subscriptionState`, `expiryTime`, `acknowledgementState`, and `externalAccountIdentifiers.obfuscatedExternalAccountId` (when present).
- Prevents cross-account token replay by verifying `google_play_purchase_token_hash` ownership before and during database transaction locking.
- Automatically acknowledges verified active purchases (`POST .../purchases/subscriptions/{productId}/tokens/{token}:acknowledge`).
- Processes Google Cloud Pub/Sub RTDN push notifications (`POST /api/v1/webhooks/google-play/rtdn`), deduplicating by `message.messageId` and always re-querying `subscriptionsv2.get` rather than trusting the notification payload alone.

### Flutter Implementation (Screens `11` & `اشتراكي`)
- [`SubscriptionScreen`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/subscription/presentation/screens/subscription_screen.dart) (`الاشتراك الشهري`):
  - Displays `"فعّل اشتراكك وابدأ التواصل"` and the 3 core benefits (`إرسال طلبات التعارف`, `التواصل بعد الموافقة`, `إرسال الرسائل الخاصة`).
  - Queries the localized price exclusively from Google Play Billing via [`GooglePlayBillingClientService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/subscription/data/services/google_play_billing_service.dart). Never displays a fake price if the store product is unavailable.
  - `"اشترك الآن"` opens only the authorized Google Play Billing purchase flow (zero external payment links inside the Play-distributed Android app).
- [`MySubscriptionScreen`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/subscription/presentation/screens/my_subscription_screen.dart) (`اشتراكي`):
  - Displays current status, plan, billing channel, current period end, renewal terms, subscription history, and official Google Play subscription management guidance.

---

## 5. External Web Payment System (Paymob & Sha7nawy)

- **Strict Isolation from Android Play App:** Web checkout routes (`/membership/auth/google`, `/membership/status`, `/membership/checkout`) in [`WebSubscriptionPortalController`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Controllers/Web/WebSubscriptionPortalController.php) are completely separate from the Android app.
- **Paymob Adapter ([`PaymobGatewayService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Payment/PaymobGatewayService.php)):**
  - Creates an internal `PaymentTransaction` with a fixed EGP and piastres (`amount_minor`) snapshot, calls Paymob Intention API (`POST https://accept.paymob.com/v1/intention/`), and returns the hosted Unified Checkout URL.
  - Verifies incoming webhooks (`POST /api/v1/webhooks/paymob`) using the exact 20-field lexicographical HMAC-SHA512 concatenation algorithm (`PaymobGatewayService::computeHmac`), verifies currency (`EGP`) and `amount_cents`, deduplicates via `payment_webhook_events`, and activates/extends or refunds the subscription.
  - Pending Paymob transactions survive even if the Super Admin later switches `active_web_payment_gateway` to `sha7nawy`.
- **Sha7nawy Adapter ([`Sha7nawyGatewayService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Payment/Sha7nawyGatewayService.php)):**
  - Implements [`PaymentGatewayInterface`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Payment/Contracts/PaymentGatewayInterface.php) and persists internal pending transaction snapshots safely, but returns a controlled `DomainException` rather than fabricating undocumented API endpoints or HMAC algorithms for `https://gate.sha7nawy.com/`.
  - **Missing Specifications Documented for Sha7nawy:** Official merchant REST endpoint URLs for order creation & status inquiry, required HTTP authentication header format, and official webhook HMAC signature header & field concatenation order.

---

## 6. Required Environment Variables

```dotenv
# Google Play Billing & Developer API v3
GOOGLE_PLAY_PACKAGE_NAME=com.naseebak.app
GOOGLE_PLAY_MONTHLY_SUBSCRIPTION_ID=naseebak_monthly_membership
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH=/var/www/naseebak/storage/app/private/google-play-service-account.json

# Paymob Accept Web Payment Gateway
PAYMOB_API_KEY=
PAYMOB_SECRET_KEY=
PAYMOB_PUBLIC_KEY=
PAYMOB_HMAC_SECRET=
PAYMOB_INTEGRATION_ID_CARD=
PAYMOB_IFRAME_ID=

# Sha7nawy Web Payment Gateway (https://gate.sha7nawy.com)
SHA7NAWY_BASE_URL=https://gate.sha7nawy.com
SHA7NAWY_API_KEY=
SHA7NAWY_MERCHANT_ID=
SHA7NAWY_WEBHOOK_SECRET=
```
