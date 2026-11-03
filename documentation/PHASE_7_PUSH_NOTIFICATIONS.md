# NASEEBAK — نصيبك
## PHASE 7: COMPLETE PUSH NOTIFICATIONS (FCM HTTP v1) & IN-APP NOTIFICATION CENTER

---

## 1. Strict Architectural Boundary & Firebase Scope
- **Firebase Cloud Messaging (FCM) is used strictly and exclusively for push notification delivery.**
- **Zero other Firebase services are used:**
  - Authentication remains **Google Sign-In + Laravel Sanctum** (`POST /api/v1/auth/google`).
  - Database remains **self-hosted PostgreSQL**.
  - File storage remains **self-hosted Laravel private storage**.
  - Real-time in-app messaging & foreground event streaming remain **self-hosted Laravel Reverb WebSockets**.
  - Business logic & administration remain **Laravel 11 + Filament**.

---

## 2. FCM HTTP v1 Architecture & Service Account Authentication
- **Endpoint:** `https://fcm.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/messages:send`
- **Legacy FCM API Prohibition:** The deprecated `https://fcm.googleapis.com/fcm/send` legacy server-key API is never used.
- **OAuth 2.0 RS256 Service Account Exchange (`FcmNotificationService`):**
  - Reads service account credentials from `FIREBASE_SERVICE_ACCOUNT_JSON_PATH` or `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` (outside public web roots).
  - Signs an RS256 JWT assertion for scope `https://www.googleapis.com/auth/firebase.messaging` and exchanges it at `https://oauth2.googleapis.com/token`.
  - Caches the resulting bearer access token in Laravel Cache for 50 minutes (`naseebak:fcm:oauth_access_token:{project_id}`).
- **Delivery Status Honesty:**
  - When FCM HTTP v1 returns HTTP `200 OK` with a `projects/.../messages/...` identifier, `NotificationRecord.delivery_status` is set to **`submitted_to_fcm`** (never falsely labeled as "displayed on device" or "read by user").
  - Every HTTP v1 attempt is logged in `notification_delivery_attempts` with `http_status`, `fcm_message_id`, `error_code`, and `attempted_at`.

---

## 3. Device Token Lifecycle, Multi-Device Support & Cross-Account Safety
Implemented in `DeviceToken`, `DeviceTokenController`, and Flutter `PushNotificationService`:
1. **Registration (`POST /api/v1/device-tokens`):**
   - Validates `fcm_token` (`min:32`, `max:4096`) and `platform = android`.
   - Computes deterministic SHA-256 `token_fingerprint` (`uq_device_tokens_fingerprint`).
2. **Token Rotation (`onTokenRefresh`):**
   - When the same `user_id` + `device_id` registers a refreshed token, previous active tokens for that `device_id` are automatically marked `is_active = false` (`invalidated_reason = replaced_by_refreshed_device_token`).
3. **Cross-Account Ownership Transfer:**
   - If User B signs in on a physical Android device previously used by User A and registers the same `fcm_token`, ownership of that token row is atomically reassigned to User B inside a database transaction so User A never receives push notifications on that device.
4. **Logout Deactivation:**
   - `DELETE /api/v1/device-tokens/current` and `POST /api/v1/auth/logout` deactivate the current device token (`invalidated_reason = user_logout`) before clearing the local Sanctum token.
5. **Invalid Token Cleanup:**
   - When FCM HTTP v1 returns `UNREGISTERED` (404), `INVALID_ARGUMENT` (400), or `SENDER_ID_MISMATCH` (403), `FcmNotificationService` immediately marks the `DeviceToken` as `is_active = false` with `invalidated_at = now()`.

---

## 4. Privacy-Safe Notification Payload Contract
No private message bodies, email addresses, phone numbers, dates of birth, Google `sub` identifiers, or payment tokens are ever included in FCM payloads.

| Notification Type | Arabic Title (`title_ar`) | External Push Body | Action Route (`action_route`) | Android Channel ID |
|---|---|---|---|---|
| `matchmaking_request_received` | `طلب تعارف جديد` | `لديك طلب تعارف جديد` | `matchmaking_requests` (`tab: incoming`) | `matchmaking_requests` |
| `matchmaking_request_accepted` | `تم قبول طلب التعارف` | `تمت الموافقة على طلب التعارف` | `conversation` (`conversation_id`) | `matchmaking_requests` |
| `matchmaking_request_rejected` | `تحديث بخصوص طلب التعارف` | `هناك تحديث بخصوص طلب التعارف` | `matchmaking_requests` (`tab: sent`) | `matchmaking_requests` |
| `new_message_received` | `رسالة جديدة` | `لديك رسالة جديدة` | `conversation` (`conversation_id`) | `messages` |
| `subscription_activated` | `تم تفعيل اشتراكك` | `تم تفعيل اشتراكك بنجاح` | `my_subscription` | `subscriptions` |
| `subscription_expiring_soon` | `تنبيه انتهاء الاشتراك` | `ينتهي اشتراكك قريبًا` | `subscription_center` | `subscriptions` |
| `subscription_expired` | `انتهت صلاحية اشتراكك` | `انتهت صلاحية اشتراكك` | `subscription_center` | `subscriptions` |
| `general_announcement` | Admin-defined Arabic title | Admin-defined Arabic body | `notifications_center` (or allowed route) | `announcements` |

---

## 5. Deduplication, Active Screen Suppression & Queue Architecture
- **Database Deduplication:** `notifications` table enforces unique index `uq_notifications_user_dedup_key` on `['user_id', 'deduplication_key']`.
- **Reverb + FCM Foreground Deduplication:** Every notification includes a UUID `event_id` in both the Reverb `notification.created` broadcast (`private-users.{userId}.notifications`) and the FCM `data` payload. Flutter `PushNotificationService.markEventSeenIfNew(eventId)` ensures each event is processed once.
- **Active Conversation Suppression:** When the user is actively viewing `ChatScreen(conversationId: X)`, `activeConversationIdProvider` equals `X`, suppressing redundant foreground push banners for conversation `X`.
- **Queue & Retry Strategy:**
  - `SendPushNotificationJob` implements `ShouldQueue` and `ShouldBeUnique` on queue `notifications` (`$tries = 4`, `$backoff = [15, 60, 180]`, `$afterCommit = true`).
  - Transient FCM errors (`429`, `500`, `503`) trigger job retry; permanent token errors (`UNREGISTERED`) deactivate the token without pointless retries.

---

## 6. Subscription Reminders & Dual-Entitlement Guards
- `ExpireSubscriptionsCommand` (`subscriptions:expire-due`, scheduled every 15 minutes in `routes/console.php`):
  1. Sends one-time `subscription_expiring_soon` reminders for active non-auto-renewing subscriptions expiring within `NASEEBAK_SUBSCRIPTION_EXPIRING_REMINDER_HOURS` (default `72` hours).
  2. **Google Play Auto-Renewing Suppression:** Skips `subscription_expiring_soon` when `provider = google_play` and `auto_renewing = true`.
  3. **Dual-Entitlement Expiration Guard:** `notifySubscriptionExpiredIfNoOtherEntitlement()` checks `SubscriptionEntitlementService::hasActiveSubscription($user)` before sending `subscription_expired`, ensuring a user with another active subscription (e.g., Web + Google Play) never receives a false expiration alert.

---

## 7. 4 GB Ubuntu VPS (Coolify) Resource Configuration
To run smoothly within the single 4 GB RAM VPS alongside Nginx, PHP-FPM, PostgreSQL, and Laravel Reverb:
- **Queue Worker Command:**
  ```bash
  php artisan queue:work database --queue=notifications,default --sleep=3 --tries=4 --max-time=3600 --memory=128
  ```
- **Scheduler Command:**
  ```bash
  php artisan schedule:work
  ```

---

## 8. Required External Firebase Credentials (Production / Staging Setup)
Before live FCM push delivery can execute on physical Android devices, provide:
1. `mobile/android/app/google-services.json` (template provided at `mobile/android/app/google-services.json.example`).
2. Backend `.env` variables:
   - `FCM_ENABLED=true`
   - `FIREBASE_PROJECT_ID=your-firebase-project-id`
   - `FIREBASE_SERVICE_ACCOUNT_JSON_PATH=/var/www/storage/app/private/firebase-service-account.json`

---

## 9. Real Android Device Test Plan (16 Scenarios)

| # | Scenario | Steps | Expected Result |
|---|---|---|---|
| 1 | Permission Granted | Install on Android 13+, sign in, tap "تفعيل الإشعارات", grant system dialog | `POST_NOTIFICATIONS` granted; token synced via `POST /api/v1/device-tokens` |
| 2 | Permission Denied | Deny system dialog on Android 13+ | App does not crash; `NotificationCenterScreen` displays banner `"فعّل الإشعارات لتصلك طلبات التعارف والرسائل الجديدة."` |
| 3 | Token Registration | Sign in with Google on physical device | `device_tokens` row created with `is_active = true` and SHA-256 `token_fingerprint` |
| 4 | Token Refresh | Trigger FCM token rotation | Old token for same `device_id` marked `is_active = false`; new token active |
| 5 | Matchmaking Request (Background) | Background Receiver app; Sender sends request | Android system tray shows `"طلب تعارف جديد"` / `"لديك طلب تعارف جديد"` on channel `matchmaking_requests` |
| 6 | Matchmaking Request (Terminated) | Force-close Receiver app; Sender sends request; tap notification | App cold-starts and navigates to `MatchmakingRequestsScreen` (Incoming tab) |
| 7 | Matchmaking Accepted | Receiver accepts request while Sender app is backgrounded; Sender taps notification | Sender receives `"تم قبول طلب التعارف"` and tapping opens `ChatScreen` for the new conversation |
| 8 | Matchmaking Rejected | Receiver rejects request | Sender receives polite `"تحديث بخصوص طلب التعارف"` / `"هناك تحديث بخصوص طلب التعارف"` |
| 9 | New Message (Active Chat Open) | Both users open same `ChatScreen(conversationId: X)`; User 1 sends message | Message appears via Reverb WebSocket; no duplicate system banner shown |
| 10 | New Message (Other Screen Open) | User 2 is on `DiscoveryHomeScreen`; User 1 sends message | Unread badge increments; local notification banner shown once (deduplicated by `event_id`) |
| 11 | New Message (Background) | User 2 backgrounds app; User 1 sends message | System notification shows `"رسالة جديدة"` / `"لديك رسالة جديدة"` without message body |
| 12 | New Message (Terminated) | User 2 force-closes app; User 1 sends message; tap notification | App launches and opens `ChatScreen(conversationId: X)` after participant check |
| 13 | Subscription Activated | Complete Google Play or Paymob/Sha7nawy verification | User receives `"تم تفعيل اشتراكك"`; tapping opens `MySubscriptionScreen` |
| 14 | Subscription Expiring Soon | Run `php artisan subscriptions:expire-due` with non-auto-renewing sub <72h | User receives `"تنبيه انتهاء الاشتراك"` once per billing cycle |
| 15 | Subscription Expired | Run `php artisan subscriptions:expire-due` after `expires_at` | User receives `"انتهت صلاحية اشتراكك"`; tapping opens `SubscriptionScreen` |
| 16 | Logout & Account Switch | User A logs out (`DELETE /api/v1/device-tokens/current`), User B logs in on same phone | User A's token deactivated/reassigned; events for User A never appear on User B's session |
