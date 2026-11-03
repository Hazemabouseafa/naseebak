# نصيبك (Naseebak) — Phase 8: Full Application Testing, Debugging, Integration & Security Audit Report

**Application:** نصيبك — Naseebak (Arabic Matrimonial Platform — Android & Self-Hosted Web Backend)  
**Phase:** Phase 8 — Full Application Testing, Debugging, Integration & Security Audit  
**Execution Mode:** Real CLI Execution, Database Migration/Rollback Verification, Automated Feature & Widget Testing, Static Analysis, and Android Debug APK Compilation  
**Target Architecture:** Flutter 3.47.9 (Dart 3.13.7, Riverpod, RTL Arabic) + Laravel 11.57.1 (PHP 8.3.36, Sanctum, Filament v3.3.57, Reverb) + PostgreSQL 16.4  

---

## 1. Executive Classification Matrix

| Audit & Verification Area | Classification | Summary of Actual Execution Evidence |
| :--- | :---: | :--- |
| **1. Local Runtime Toolchain Provisioning** | **PASS** | PHP `8.3.36`, Composer `2.11.1`, PostgreSQL `16.4`, OpenJDK `17.0.20.1+1`, Flutter `3.47.9`, Dart `3.13.7`, Android SDK `API 36` (`build-tools;36.0.0`, `NDK 28.2`, `CMake 3.22.1`) provisioned and verified. |
| **2. Laravel Backend Dependencies & Boot (`composer install`, `artisan about`)** | **PASS** | `162` Composer packages installed with exit code `0`. Laravel `11.57.1`, Filament `v3.3.57`, Livewire `v3.8.11` booted cleanly. |
| **3. Route Registration & Middleware Audit (`php artisan route:list`)** | **PASS** | All `109` API, Broadcasting, Webhook, Protected Media, and Filament Admin routes registered and verified with exit code `0`. |
| **4. PostgreSQL 16 Migrations, Rollback & Seeding** | **PASS** | `php artisan migrate`, `php artisan migrate:rollback`, `php artisan migrate`, and `php artisan db:seed` all executed cleanly against PostgreSQL `16.4` (`exit code 0`). |
| **5. Section 14 — FCM Notification Security Correction** | **PASS** | `FcmNotificationService` updated and verified: `INVALID_ARGUMENT` invalidates a token **only** when `message.token` is confirmed invalid (`INVALID_REGISTRATION_TOKEN`); payload errors (`INVALID_PAYLOAD_ARGUMENT`) and `SENDER_ID_MISMATCH` (`403`) preserve `is_valid = true`. |
| **6. Laravel Backend Automated Test Suite (`php artisan test`)** | **PASS** | **136 passed (642 assertions), 0 failed** across all 8 Feature Test Suites (Phases 1–8, including End-to-End Scenarios A–G and Security/IDOR Audit Scenario H). |
| **7. Flutter Dependencies & Static Analysis (`flutter pub get`, `flutter analyze`)** | **PASS** | Dependencies resolved cleanly (`exit code 0`); `flutter analyze` exited with code `0` (`No issues found!`). |
| **8. Flutter Automated Unit & Widget Test Suite (`flutter test`)** | **PASS** | **27 passed, 0 failed** (`exit code 0`) across all 6 test suites (`phase1_foundation_test.dart`, `phase2_profile_management_test.dart`, `phase3_discovery_and_search_test.dart`, `phase5_subscription_test.dart`, `phase6_matchmaking_and_messaging_test.dart`, `phase7_notifications_test.dart`). |
| **9. Android Debug APK Compilation (`flutter build apk --debug`)** | **PASS** | Compiled `build\app\outputs\flutter-apk\app-debug.apk` (`167,837,946 bytes` / `160.06 MB`, SHA-256: `97EEC1794E14A356E2102806F42C83A908643F4E264F37B3EB049CBFD3082A36`) targeting `compileSdk = 36`, `targetSdk = 36`, `minSdk = 23` (`exit code 0`). |
| **10. End-to-End Integration Scenarios (Scenarios A–G)** | **PASS** | Verified via automated multi-actor HTTP + PostgreSQL + Queue/Event integration tests in `Phase8IntegrationAndSecurityTest` and individual phase suites. |
| **11. Application Security & IDOR Audit (Scenario H)** | **PASS** | Verified token hashing (`SHA-256`), anti-spoofing, photo privacy gates, subscription server-side re-verification, IDOR prevention across chat/requests/notifications, and Filament RBAC/2FA/Audit logging. |
| **12. Live External Third-Party Production Credentials** | **BLOCKED** | Live production `google-services.json`, production Google Cloud OAuth Client IDs, live Google Play Console In-App Billing merchant account, and live Paymob/Sha7nawy production API keys must be supplied during Phase 9 VPS & Play Console deployment. |

---

## 2. Provisioned Runtime Environment & Tool Versions

All runtime tools were installed and executed locally on Windows x64:

| Component | Version | Binary / Installation Path | Status |
| :--- | :--- | :--- | :---: |
| **PHP CLI** | `PHP 8.3.36 (cli) (NTS Visual C++ 2019 x64)` | `C:\Users\w.i\.gemini\antigravity\scratch\tools\php\php.exe` | **PASS** |
| **PHP Extensions** | `pdo_pgsql`, `pgsql`, `gd`, `intl`, `mbstring`, `openssl`, `curl`, `fileinfo`, `zip`, `sodium`, `bcmath` | `C:\Users\w.i\.gemini\antigravity\scratch\tools\php\php.ini` | **PASS** |
| **Composer** | `Composer version 2.11.1` | `C:\Users\w.i\.gemini\antigravity\scratch\tools\php\composer.bat` | **PASS** |
| **PostgreSQL Server** | `PostgreSQL 16.4, compiled by Visual C++ build 1940, 64-bit` | `C:\Users\w.i\.gemini\antigravity\scratch\tools\pgsql\pgsql\bin\postgres.exe` (Port `5432`, `UTC`) | **PASS** |
| **Java JDK** | `OpenJDK 17.0.20.1+1 (Eclipse Temurin)` | `C:\Users\w.i\.gemini\antigravity\scratch\tools\jdk17\bin\java.exe` | **PASS** |
| **Flutter SDK** | `Flutter 3.47.9 • channel stable` | `C:\Users\w.i\.gemini\antigravity\scratch\tools\flutter\bin\flutter.bat` | **PASS** |
| **Dart SDK** | `Dart 3.13.7 (stable)` | `C:\Users\w.i\.gemini\antigravity\scratch\tools\flutter\bin\cache\dart-sdk\bin\dart.exe` | **PASS** |
| **Android SDK** | `platforms;android-36`, `platforms;android-35`, `build-tools;36.0.0`, `ndk;28.2.13676358`, `cmake;3.22.1` | `C:\Users\w.i\AppData\Local\Android\Sdk` | **PASS** |

---

## 3. Laravel Backend & PostgreSQL Verification

### 3.1 Executed Commands & Exit Codes

| Command | Working Directory | Exit Code | Key Output Summary |
| :--- | :--- | :---: | :--- |
| `composer install --no-interaction` | `backend/` | `0` | Installed `162` packages, generated optimized autoload files. |
| `php artisan about` | `backend/` | `0` | Laravel `11.57.1`, PHP `8.3.36`, Filament `v3.3.57`, Livewire `v3.8.11`. |
| `php artisan route:list` | `backend/` | `0` | Listed `109` routes (`api/v1/*`, `broadcasting/auth`, `admin/*`). |
| `php artisan migrate --force` | `backend/` | `0` | Executed all migrations (`0001_01_01_000000` through `2026_03_07_000001`). |
| `php artisan migrate:rollback --force` | `backend/` | `0` | Cleanly rolled back the entire migration batch without orphan constraints. |
| `php artisan migrate --force` | `backend/` | `0` | Re-applied all migrations cleanly on `naseebak_dev`. |
| `php artisan db:seed --force` | `backend/` | `0` | Seeded initial system configuration, subscription plans (`monthly_membership`), and RBAC roles. |
| `php artisan test` | `backend/` | `0` | **136 passed (642 assertions)** in `17.3s`. |

### 3.2 Backend Feature Test Breakdown (`php artisan test`)

1. **`Tests\Feature\AuthAndProfilePhase1Test` — 5 / 5 PASS**
   - Rejects spoofed/invalid Google ID tokens (`401`).
   - Authenticates valid Google OpenID Connect user (`200`, issues Sanctum token).
   - Blocks suspended accounts (`403`, revokes tokens).
   - Rejects underage (`< 18`) profile creation (`422`) and marital status contradictions (`single` + `previously_married = true`).
   - Persists complete 4-step profile, computes accurate age & Arabic zodiac sign, and enforces photo privacy on `/api/v1/media/profile-photos/{photo}`.

2. **`Tests\Feature\ProfileManagementPhase2Test` — 12 / 12 PASS**
   - Retrieves own profile with `completion_percentage = 100`.
   - Updates profile fields, recalculates zodiac sign, and normalizes `single` marital status flags.
   - Rejects underage date of birth and contradictory marital flags during edits.
   - Updates `profile_visibility` (`visible` / `hidden`) and `photo_privacy` (`all_members`, `subscribers_only`, `approved_matches_only`).
   - Uploads JPG/PNG/WebP photos to private storage (`storage/app/private/profile-photos`), strips EXIF metadata, converts to WebP (`800x800`), and deletes old files on replacement.
   - Rejects oversized (`> 5 MB`) and spoofed non-image uploads.
   - Enforces strict photo authorization for `all_members`, `subscribers_only`, and `approved_matches_only`.

3. **`Tests\Feature\DiscoveryAndSearchPhase3Test` — 22 / 22 PASS**
   - Returns only active, completed, opposite-gender, visible, non-blocked members in discovery feed.
   - Filters by age range (`>= 18`), marital status, `has_children`, `education_level`, `smoking_status`, `home_ownership`, `occupation`, `nationality`, `country_of_residence`, `region`, and `zodiac_sign`.
   - Persists and resets saved `search_preferences`.
   - Enforces deterministic pagination (`newest`, `age_asc`, `age_desc`) and caps `per_page <= 30`.
   - Hides sensitive fields (`email`, `google_id`, raw storage paths) from member profile JSON.
   - Adds/removes favorites idempotently, blocks/unblocks members with immediate mutual invisibility, and submits validated reports (`>= 10` chars).

4. **`Tests\Feature\AdminDashboardPhase4Test` — 25 / 25 PASS**
   - Enforces separate admin guard (`auth:admin`), RBAC (`Super Admin`, `Moderator`, `Support / Reviewer`), and TOTP 2FA challenge.
   - Rate-limits admin login attempts and writes immutable `admin_audit_logs` records.
   - Verifies member suspension/reactivation (immediate Sanctum token revocation), profile review (`approved`, `needs_changes`, `rejected`), photo moderation, report resolution, manual subscription grant/revocation, and system settings updates.

5. **`Tests\Feature\SubscriptionAndPaymentPhase5Test` — 35 / 35 PASS**
   - Verifies Google Play purchases via Google Play Developer API (`subscriptionsv2.get`), enforces one-to-one `purchase_token_hash` ownership binding (`409` on cross-user replay), and rejects unverified client calls.
   - Processes Google Play RTDN Pub/Sub webhooks idempotently (`SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_CANCELED`, `SUBSCRIPTION_ON_HOLD`, `SUBSCRIPTION_IN_GRACE_PERIOD`, `SUBSCRIPTION_REVOKED`, `SUBSCRIPTION_EXPIRED`).
   - Verifies HMAC-signed Paymob and Sha7nawy web payment callbacks, rejects tampered signatures (`401`) and amount mismatches (`422`), and extends calendar-month periods safely without mutating Google Play records.

6. **`Tests\Feature\MatchmakingAndMessagingPhase6Test` — 24 / 24 PASS**
   - Enforces active subscription requirement for sending/accepting matchmaking requests and sending private messages (`402 SUBSCRIPTION_REQUIRED`).
   - Prevents duplicate pending requests via PostgreSQL partial unique index and canonical user pair ordering (`user_one_id < user_two_id`).
   - Creates authorized `Conversation` on request acceptance, persists messages with `client_message_id` idempotency, broadcasts `MessageSentBroadcast` & `MessageReadBroadcast`, and blocks communication immediately when either participant blocks the other or is suspended.

7. **`Tests\Feature\PushNotificationsPhase7Test` — 11 / 11 PASS**
   - Registers/rotates FCM device tokens (`SHA-256` `token_hash`, max 5 active devices per user), unregisters on logout, and transfers device token ownership cleanly across accounts.
   - Enforces per-category notification preferences (`matchmaking_requests`, `messages`, `subscriptions`, `announcements`).
   - Protects message privacy in FCM push payloads (`لديك رسالة جديدة داخل تطبيق نصيبك.` — never leaks message body or sender name).
   - Verifies **Section 14 FCM Error Classification**:
     - `404 UNREGISTERED` -> `is_valid = false` (`UNREGISTERED`).
     - `400 INVALID_ARGUMENT` on `message.token` -> `is_valid = false` (`INVALID_REGISTRATION_TOKEN`).
     - `400 INVALID_ARGUMENT` on `message.data` -> **preserves** `is_valid = true` (`INVALID_PAYLOAD_ARGUMENT`).
     - `403 SENDER_ID_MISMATCH` -> **preserves** `is_valid = true` (`SENDER_ID_MISMATCH`).

8. **`Tests\Feature\Phase8IntegrationAndSecurityTest` — 2 / 2 PASS**
   - **Test 1 (`End-to-End Integration Scenarios A–G`):** Executes the full lifecycle across User A (male) and User B (female): Google OAuth login -> 4-step profile completion -> WebP photo upload & privacy enforcement -> Discovery & Advanced Search -> Favorites -> Subscription gating (`402`) -> Google Play verified subscription activation -> Matchmaking request creation & acceptance -> Authorized real-time conversation & message deduplication -> In-app & FCM notifications -> Blocking & Admin suspension token revocation.
   - **Test 2 (`Security & IDOR Audit Scenario H`):** Verifies cross-user IDOR attempts against conversations (`403`), matchmaking requests (`403`), notifications (`404`), and private photos (`403`) all fail deterministically.

---

## 4. Section 14 — Mandatory FCM Notification Security Correction

### 4.1 Audited File
- [`backend/app/Services/Notification/FcmNotificationService.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Notification/FcmNotificationService.php)

### 4.2 Root Cause & Applied Fix
Previously, any `400 INVALID_ARGUMENT` or `403 SENDER_ID_MISMATCH` response from FCM HTTP v1 could indiscriminately mark a user's `user_device_tokens` record as `is_valid = false`, even when the failure was caused by a malformed payload field (`message.data`) or a temporary server-side Firebase credentials mismatch (`SENDER_ID_MISMATCH`).

We updated [`FcmNotificationService::sendMessageToToken`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Notification/FcmNotificationService.php#L105-L157) and added [`FcmNotificationService::isInvalidArgument causedByToken`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Notification/FcmNotificationService.php#L204-L246):
1. **`UNREGISTERED` (`404`):** Marks `is_valid = false` with `invalidation_reason = 'UNREGISTERED'`.
2. **`INVALID_ARGUMENT` (`400`) caused specifically by `message.token`:** Inspects `error.details[].fieldViolations` (`field === 'message.token'` or description mentioning registration token) and `error.message`. Only when the token itself is confirmed invalid does it mark `is_valid = false` with `invalidation_reason = 'INVALID_REGISTRATION_TOKEN'`.
3. **`INVALID_ARGUMENT` (`400`) caused by payload/data (`message.data`, etc.):** Logs a structured warning (`error_code = 'INVALID_PAYLOAD_ARGUMENT'`) and **preserves** `is_valid = true`.
4. **`SENDER_ID_MISMATCH` (`403`):** Logs a structured `Log::critical` configuration alert (`error_code = 'SENDER_ID_MISMATCH'`) and **preserves** `is_valid = true`.

---

## 5. Flutter Mobile Application Verification & APK Compilation

### 5.1 Executed Commands & Exit Codes

| Command | Working Directory | Exit Code | Key Output Summary |
| :--- | :--- | :---: | :--- |
| `flutter doctor -v` | `mobile/` | `0` | Flutter `3.47.9` (stable), Dart `3.13.7`, Android SDK `36.0.0`, OpenJDK `17.0.20.1+1`. |
| `flutter pub get` | `mobile/` | `0` | Resolved all dependencies cleanly. |
| `flutter analyze` | `mobile/` | `0` | `Analyzing mobile... No issues found! (ran in 19.7s)` |
| `flutter test --reporter expanded` | `mobile/` | `0` | `00:12 +27: All tests passed!` (`27 / 27 PASS`) |
| `flutter build apk --debug` | `mobile/` | `0` | `√ Built build\app\outputs\flutter-apk\app-debug.apk` (`167,837,946 bytes` / `160.06 MB`) |

### 5.2 Flutter Automated Test Suite Breakdown (`27 / 27 PASS`)

1. **[`test/phase1_foundation_test.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/test/phase1_foundation_test.dart) — 3 / 3 PASS**
   - `ProfileRegistrationDraft` age (`>= 18`) and Arabic zodiac sign calculation.
   - `WelcomeScreen` (Screen 01) & `GoogleSignInScreen` (Screen 02) Arabic RTL layout & navigation.
   - `SuspendedAccountScreen` & `ProfileRegistrationCoordinatorScreen` (Screens 03–06) RTL rendering.

2. **[`test/phase2_profile_management_test.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/test/phase2_profile_management_test.dart) — 3 / 3 PASS**
   - `ProfileManagementNotifier.validateProfileDraft` underage and marital status consistency checks.
   - `MyProfileScreen` (Screen 18) real profile data rendering and action buttons.
   - `EditProfileScreen` (Screen 19) and `PrivacySettingsScreen` (Screen 21) RTL controls.

3. **[`test/phase3_discovery_and_search_test.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/test/phase3_discovery_and_search_test.dart) — 3 / 3 PASS**
   - `SearchPreferencesModel` age range validation and active filter chip generation.
   - `MemberCard` Arabic RTL rendering, photo privacy badge, and favorite toggle callback.
   - `AdvancedSearchScreen` (Screen 08), `SearchResultsScreen` (Screen 09 empty state), and `FavoritesScreen` (Screen 16 empty state).

4. **[`test/phase5_subscription_test.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/test/phase5_subscription_test.dart) — 5 / 5 PASS**
   - `SubscriptionScreen` (Screen 12) Arabic RTL benefits and localized Google Play price rendering.
   - Store product unavailable fallback state.
   - Purchase error banner on Google Play Billing failure.
   - `MySubscriptionScreen` (Screen 20) active, expired, and refresh states.
   - Pending purchase verification state handling.

5. **[`test/phase6_matchmaking_and_messaging_test.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/test/phase6_matchmaking_and_messaging_test.dart) — 7 / 7 PASS**
   - `MemberProfileScreen` (Screen 10) `"طلب التعارف"` -> `"طلب التعارف قيد الانتظار"` state transition for subscribed viewers.
   - `MemberProfileScreen` subscription required bottom sheet prompt for unsubscribed viewers.
   - `"قبول طلب التعارف"` and `"إرسال رسالة"` button states on `MemberProfileScreen`.
   - `MatchmakingRequestsScreen` (Screen 11) incoming, sent, and accepted tabs, accept/reject/cancel actions.
   - `ConversationsScreen` (Screen 13) empty state and conversation list with unread badges.
   - `ChatScreen` (Screen 14) RTL message history, optimistic send + WebSocket echo deduplication, and reconnect resynchronization.
   - `ChatScreen` draft preservation on `SUBSCRIPTION_REQUIRED` and disabled composer when blocked.

6. **[`test/phase7_notifications_test.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/test/phase7_notifications_test.dart) — 6 / 6 PASS**
   - `NotificationCenterScreen` empty state (`"لا توجد إشعارات حاليًا"`).
   - `NotificationCenterScreen` list rendering, unread count badge, mark-read, mark-all-read, and single notification delete.
   - Error & retry state recovery.
   - Android 13+ notification permission prompt banner and permission request action.
   - `NotificationPreferencesScreen` 4 category toggles (`matchmaking_requests`, `messages`, `subscriptions`, `announcements`).
   - Real-time Reverb WebSocket + FCM `event_id` deduplication and logout token cleanup.

---

## 6. Bugs Discovered & Fixed During Phase 8 Real Execution

| # | Layer | File(s) Modified | Root Cause Discovered During Execution | Fix Applied & Verified |
| :---: | :--- | :--- | :--- | :--- |
| **1** | Backend (FCM) | [`FcmNotificationService.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Notification/FcmNotificationService.php) | `INVALID_ARGUMENT` (`400`) and `SENDER_ID_MISMATCH` (`403`) were not distinguishing invalid registration tokens from payload errors or sender ID misconfiguration; JSON payload escaped Arabic characters (`\uXXXX`). | Implemented `isInvalidArgumentCausedByToken()` checking `BadRequest.fieldViolations` for `message.token`, preserved `is_valid = true` on payload errors and `SENDER_ID_MISMATCH`, and encoded FCM JSON with `JSON_UNESCAPED_UNICODE \| JSON_UNESCAPED_SLASHES`. |
| **2** | Backend (Matchmaking API) | [`MatchmakingRequestController.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Controllers/Api/V1/MatchmakingRequestController.php), [`api.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/routes/api.php) | Mobile client & tests used both `recipient_user_id` and `recipient_id`, dedicated `/sent` and `/incoming` tab endpoints, and expected `data.request` on `reject`/`cancel`. | Normalized `recipient_id` / `recipient_user_id` in `store()`, added `/api/v1/matchmaking/requests/sent` and `/incoming` routes, and returned `data.request` in `reject()` and `cancel()`. |
| **3** | Backend (Notifications & Announcements) | [`Conversation.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Models/Conversation.php), [`AnnouncementCampaign.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Models/AnnouncementCampaign.php) | Missing `Conversation::canonicalPair()` helper and `AnnouncementCampaign` segment constants / `idempotency_key` auto-default. | Added `Conversation::canonicalPair()`, `SEGMENT_*` constants, `target_segment` / `dispatched_count` accessors, and UUID default `idempotency_key` on `AnnouncementCampaign`. |
| **4** | Backend (Testing & Timezone) | [`phpunit.xml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/phpunit.xml), [`SubscriptionAndPaymentPhase5Test.php`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/tests/Feature/SubscriptionAndPaymentPhase5Test.php) | Windows OpenSSL required explicit `openssl.cnf` path in `openssl_pkey_new`, and `APP_TIMEZONE=UTC` needed `force="true"` to match PostgreSQL `UTC` session timestamps. | Passed explicit `config` to `openssl_pkey_new` / `openssl_pkey_export` and set `force="true"` on `APP_TIMEZONE=UTC` in `phpunit.xml`. |
| **5** | Mobile (Android Build & SDK 36) | [`android/app/build.gradle.kts`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/android/app/build.gradle.kts), [`AndroidManifest.xml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/android/app/src/main/AndroidManifest.xml) | Missing Android Gradle wrapper scaffolding and `coreLibraryDesugaring` required by `flutter_local_notifications ^17.2.3`. | Generated Android platform wrapper, configured `compileSdk = 36`, `targetSdk = 36`, `minSdk = 23`, enabled `isCoreLibraryDesugaringEnabled = true` with `desugar_jdk_libs:2.1.4`, and restored UTF-8 Arabic manifest (`نصيبك`). |
| **6** | Mobile (Flutter 3.47 Material 3 API) | [`app_theme.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/core/theme/app_theme.dart), [`app_colors.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/core/constants/app_colors.dart) | Flutter `3.47.9` changed `ThemeData.cardTheme` type from `CardTheme` to `CardThemeData`. | Updated `cardTheme: CardThemeData(...)` in `app_theme.dart` and added `AppColors.primaryBlueDark`. |
| **7** | Mobile (Real-Time Chat Deduplication) | [`messaging_provider.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/messaging/presentation/providers/messaging_provider.dart) | `_deduplicateMessages()` keyed sent messages by `client:{clientMessageId}` and incoming WebSocket echoes without `client_message_id` by `id:{id}`, causing a duplicate bubble when the echo lacked `client_message_id`. | Updated `_deduplicateMessages()` to match existing messages by **either** canonical server `id > 0` **or** non-empty `clientMessageId`, replacing in place. |
| **8** | Mobile (Small Viewport Layout Overflows & Material Ancestor) | [`google_sign_in_screen.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/auth/presentation/screens/google_sign_in_screen.dart), [`member_profile_screen.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/discovery/presentation/screens/member_profile_screen.dart), [`notification_preferences_screen.dart`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/notifications/presentation/screens/notification_preferences_screen.dart) | `GoogleSignInScreen` overflowed by `5px` and `_showSubscriptionRequiredSheet` overflowed by `25px` on `600px`-tall viewports; `SwitchListTile` inside decorated `Container` needed an inner `Material` widget in Flutter 3.47. | Wrapped `GoogleSignInScreen` body in `LayoutBuilder` + `SingleChildScrollView` + `IntrinsicHeight`, added `isScrollControlled: true` + `SingleChildScrollView` to `_showSubscriptionRequiredSheet`, and added a transparent `Material` wrapper in `NotificationPreferencesScreen`. |

---

## 7. Application Security Audit Summary

1. **Authentication & Session Security (`PASS`):**
   - Google OpenID Connect ID tokens are verified server-side via [`GoogleIdentityVerifierService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Auth/GoogleIdentityVerifierService.php) (`iss`, `aud`, `exp`, `sub`, `email_verified`).
   - Sanctum tokens are stored hashed in PostgreSQL and stored in `FlutterSecureStorage` on Android.
   - Suspended accounts (`status = suspended`) are blocked immediately by [`EnsureActiveMember`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Middleware/EnsureActiveMember.php) and have all active Sanctum tokens and FCM tokens revoked.

2. **Profile & Photo Privacy (`PASS`):**
   - Profile photos are stored outside `public/` in `storage/app/private/profile-photos`, processed via GD to strip EXIF metadata and convert to `800x800` WebP.
   - [`ProfilePhotoController::show`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Controllers/Api/V1/ProfilePhotoController.php) enforces `all_members`, `subscribers_only`, and `approved_matches_only` authorization on every image request with `Cache-Control: private, no-store`.
   - Public member profile JSON never exposes `email`, `google_id`, `fcm_token`, or internal storage paths.

3. **Subscription & Payment Security (`PASS`):**
   - Client never unlocks communication locally; [`SubscriptionEntitlementService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Subscription/SubscriptionEntitlementService.php) computes entitlement strictly from server-verified `subscriptions` rows (`status IN ('active', 'grace_period') AND current_period_ends_at > now()`).
   - Google Play `purchase_token_hash` (`SHA-256`) is uniquely bound to a single `user_id`; cross-user replay returns `409 Conflict`.
   - Paymob & Sha7nawy webhooks verify HMAC-SHA512 / HMAC-SHA256 signatures and exact cent amounts before granting calendar-month entitlement.

4. **Messaging, WebSockets & Push Notifications (`PASS`):**
   - Private Reverb channels (`private-conversation.{id}`, `private-user.{id}`, `private-users.{id}.notifications`) enforce participant/owner checks in `routes/channels.php`.
   - FCM push payloads for private messages use generic Arabic text (`لديك رسالة جديدة داخل تطبيق نصيبك.`) and never transmit private message text to FCM.
   - Raw FCM tokens are protected with `SHA-256` `token_hash` uniqueness and redacted from application logs.

5. **Admin Dashboard Security (`PASS`):**
   - Isolated `admin` guard (`admin_users` table), mandatory TOTP 2FA (`EnsureAdminTwoFactorVerified`), RBAC policies (`Super Admin`, `Moderator`, `Support / Reviewer`), and immutable `admin_audit_logs` on every administrative mutation.

---

## 8. Google Play Store Technical & Policy Readiness Audit

- **Android Target SDK:** `compileSdk = 36`, `targetSdk = 36`, `minSdk = 23` configured in [`android/app/build.gradle.kts`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/android/app/build.gradle.kts) (`PASS`).
- **Permissions Minimality:** [`AndroidManifest.xml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/android/app/src/main/AndroidManifest.xml) declares only `android.permission.INTERNET` and `android.permission.POST_NOTIFICATIONS` — zero dangerous/prohibited permissions (`READ_CONTACTS`, `READ_SMS`, `ACCESS_FINE_LOCATION`, `READ_MEDIA_IMAGES` not requested) (`PASS`).
- **Google Play Billing Compliance:** Mobile app uses `in_app_purchase ^3.2.0` (`GooglePlayBillingClientService`) exclusively for in-app digital subscription purchases; no external payment links or webviews exist inside the Android APK (`PASS`).
- **UGC Moderation & Safety:** Every member profile and chat screen provides one-tap **Block (`حظر العضو`)** and **Report (`إبلاغ عن إساءة`)** functionality backed by Filament admin moderation queues (`PASS`).

---

## 9. Remaining External Blockers Before Production Launch (Phase 9)

The following items are classified as **`BLOCKED`** solely because they require live production credentials and external console provisioning during **Phase 9 (Production VPS Deployment & Play Store Release)**:
1. **Firebase Production Config:** Place the production `google-services.json` in `mobile/android/app/google-services.json` and the Firebase service account JSON on the production VPS (`FIREBASE_CREDENTIALS_JSON`).
2. **Google Cloud OAuth Credentials:** Configure the production Android SHA-1/SHA-256 signing certificate fingerprint and Web Client ID in `GOOGLE_ALLOWED_CLIENT_IDS`.
3. **Google Play Console In-App Subscription Product:** Create the `monthly_membership` recurring subscription product in Google Play Console and link the Real-Time Developer Notifications (RTDN) Pub/Sub topic.
4. **Release Signing Keystore:** Provision the production upload keystore (`upload-keystore.jks`) and `key.properties` for building the signed production Android App Bundle (`flutter build appbundle --release`).
