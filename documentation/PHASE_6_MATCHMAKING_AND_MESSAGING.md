# NASEEBAK (نصيبك) — PHASE 6: MATCHMAKING REQUESTS, AUTHORIZED CONVERSATIONS & REAL-TIME PRIVATE MESSAGING

## 1. Matchmaking Request Lifecycle & State Machine

### Supported Statuses (`matchmaking_requests.status`)
| Status | Arabic Label | Description |
| :--- | :--- | :--- |
| `pending` | قيد الانتظار | Initial state when a subscribed sender creates a request to an eligible recipient. |
| `accepted` | مقبول | Recipient accepted the request; a single one-to-one `Conversation` is atomically created. |
| `rejected` | معتذر عنه | Recipient declined the request (`responded_at` recorded). Re-requesting is blocked by default (`allow_rerequest_after_rejection = false`). |
| `cancelled` | ملغى | Sender cancelled their own `pending` request before the recipient responded (`cancelled_at` recorded). |

### Canonical User-Pair Integrity & Race-Condition Protection
- Every matchmaking request stores `user_low_id = min(sender_id, recipient_id)` and `user_high_id = max(sender_id, recipient_id)`.
- Inside `MatchmakingService::createRequest()`, both user rows are locked in ascending ID order (`SELECT ... FOR UPDATE`) alongside any existing `matchmaking_requests` for `(user_low_id, user_high_id)`:
  - If an `accepted` request already exists -> returns HTTP `409` (`MATCH_ALREADY_ACCEPTED`).
  - If a `pending` request in the same direction already exists -> returns HTTP `409` (`DUPLICATE_PENDING_REQUEST`).
  - If a `pending` request in the reverse direction already exists (User B already requested User A) -> returns HTTP `409` (`RECIPROCAL_PENDING_REQUEST_EXISTS`) instructing the user to accept the incoming request rather than auto-creating a conversation without explicit recipient consent.
  - If a `rejected` request exists -> returns HTTP `422` (`REQUEST_PREVIOUSLY_REJECTED`).

---

## 2. Subscription Entitlement Enforcement Rules

All communication gates are enforced server-side via `SubscriptionEntitlementService`:

| Action | Service Method | Free / Expired Member | Active / Grace-Period / Valid-Future Cancelled Subscriber |
| :--- | :--- | :--- | :--- |
| Browse & Search Profiles | — | Allowed | Allowed |
| View Incoming Requests | — | Allowed | Allowed |
| Accept / Reject Incoming Request | `MatchmakingService::acceptRequest` / `rejectRequest` | Allowed (No subscription required) | Allowed |
| Read Existing Authorized Conversation History | `ConversationMessagingService::getMessages` | Allowed (No subscription required) | Allowed |
| Send Matchmaking Request | `SubscriptionEntitlementService::canSendMatchRequest()` | Blocked (`403 SUBSCRIPTION_REQUIRED`) | Allowed |
| Send Private Message | `SubscriptionEntitlementService::canSendMessage()` | Blocked (`403 SUBSCRIPTION_REQUIRED`) | Allowed |

---

## 3. Conversation Creation & Participant Authorization

- Conversations are **never** created directly by client request. They are created exclusively inside `MatchmakingService::acceptRequest()` within a database transaction.
- `conversations` enforces a unique canonical pair index `uq_conversations_canonical_user_pair` on `(user_one_id, user_two_id)` where `user_one_id = min(userA, userB)` and `user_two_id = max(userA, userB)`.
- Accepting a request twice is idempotent and returns the same `Conversation` and two `ConversationParticipant` rows.
- Every conversation endpoint (`GET /api/v1/conversations/{conversation}`, `GET /api/v1/conversations/{conversation}/messages`, `POST /api/v1/conversations/{conversation}/messages`, `POST /api/v1/conversations/{conversation}/read`) verifies participant membership via `ConversationMessagingService::assertParticipant()`. Non-participants receive HTTP `403` (`CONVERSATION_ACCESS_DENIED`).

---

## 4. Photo Privacy Unlocking (`accepted_matches_only`)

- `ProfileAccessControlService::hasAcceptedMatch($viewerId, $ownerId)` queries `matchmaking_requests` for `status = 'accepted'` in either direction between the two users (as long as neither user has blocked the other).
- When a member sets `photo_privacy = 'accepted_matches_only'`, their protected photo stream (`GET /api/v1/profile/photos/{photo}/stream`) returns `403` while a matchmaking request is `pending`, `rejected`, or `cancelled`, and automatically unlocks (`200 OK`) immediately after the request is `accepted`.

---

## 5. Message Validation, Sanitization & Idempotency

- **Text-Only Scope:** Phase 6 supports UTF-8 Arabic and English text messages only (`1` to `2000` characters, configurable via `config('naseebak.messaging.max_length')`).
- **Sanitization:** `ConversationMessagingService::sanitizeMessageBody()` strips invisible control characters (`\x00-\x08`, `\x0B`, `\x0C`, `\x0E-\x1F`, `\x7F`), normalizes `\r\n` to `\n`, and rejects empty/whitespace-only strings (`422 EMPTY_MESSAGE`).
- **Client Idempotency:** Each outgoing message includes an optional `client_message_id` (max 100 chars). The database enforces `uq_messages_conv_sender_client_id` on `(conversation_id, sender_id, client_message_id)`. Retrying a message with the same `client_message_id` returns the existing `Message` record (`200 OK`, `idempotent_replay: true`) without creating duplicate rows or re-broadcasting duplicate events.
- **Cursor Pagination:** `GET /api/v1/conversations/{conversation}/messages` supports `before_id` (upward scroll history, 30 messages per page) and `after_id` (reconnection catch-up), ordered deterministically by `messages.id`.

---

## 6. Laravel Reverb Configuration & Private Channel Authorization

- **Configuration Files:**
  - `backend/config/broadcasting.php` (`reverb` default connection)
  - `backend/config/reverb.php`
  - `backend/routes/channels.php`
  - `backend/app/Http/Controllers/Api/V1/BroadcastAuthController.php` (`POST /api/v1/broadcasting/auth`)
- **Authorized Private Channels:**
  1. `private-conversation.{conversationId}`: Authorized only when the authenticated active user is a participant in `conversation_participants` for `{conversationId}`.
  2. `private-user.{userId}`: Authorized only when `(int) $user->id === (int) $userId`.
- **Broadcast Events (`ShouldBroadcastNow` + `ShouldDispatchAfterCommit`):**
  - `matchmaking.request.created` (`MatchmakingRequestCreated`)
  - `matchmaking.request.accepted` (`MatchmakingRequestAccepted`)
  - `matchmaking.request.rejected` (`MatchmakingRequestRejected`)
  - `conversation.updated` (`ConversationUpdated`)
  - `message.sent` (`MessageSent`)
  - `message.read` (`MessageRead`)

---

## 7. Coolify & Shared 4 GB Ubuntu VPS Deployment Preparation for Reverb

To run smoothly on the shared 4 GB RAM Ubuntu VPS alongside existing workloads:
1. **Single-Instance Mode:** Set `REVERB_SCALING_ENABLED=false` in `.env` so Reverb runs as a single lightweight process without requiring Redis pub/sub scaling overhead.
2. **Process Management:** Run `php artisan reverb:start --host=0.0.0.0 --port=8080` as a supervised service (or Coolify companion service) with `--max-request-size=10000` and memory limit monitoring.
3. **Reverse Proxy & TLS (`WSS`):** Configure Coolify / Caddy / Nginx to proxy `/app/*` and `/apps/*` over TLS (`wss://api.naseebak.app`) to `127.0.0.1:8080` with `Upgrade: websocket` and `Connection: Upgrade` headers.
4. **Environment Variables (`.env.example`):**
   - `BROADCAST_CONNECTION=reverb`
   - `REVERB_APP_ID`, `REVERB_APP_KEY`, `REVERB_APP_SECRET`
   - `REVERB_HOST`, `REVERB_PORT=443`, `REVERB_SCHEME=https`

---

## 8. Flutter Real-Time WebSocket Client & Reconnection Synchronization

- `RealtimeMessagingService` (`mobile/lib/features/messaging/data/services/realtime_messaging_service.dart`):
  - Connects to Laravel Reverb using `web_socket_channel`.
  - Responds to `pusher:ping` with `pusher:pong`.
  - Authorizes `private-user.{userId}` and `private-conversation.{conversationId}` via `POST /api/v1/broadcasting/auth` using the user's Sanctum bearer token.
  - Implements exponential backoff reconnection (`2s`, `4s`, `8s`, `16s`, `30s`).
  - Emits `onReconnectedStream` upon re-establishing connection, triggering `MessagingNotifier.resynchronizeAfterReconnection()` which fetches missed messages using `after_id` and deduplicates by `client_message_id` and `id`.

---

## 9. Blocking & Reporting Integration

- **Blocking (`POST /api/v1/members/{member}/block`):**
  - Immediately cancels all `pending` matchmaking requests in either direction between the two users.
  - Marks any existing `Conversation` between the two users as `status = 'blocked'`, immediately preventing new messages (`403 CONVERSATION_BLOCKED`).
- **Reporting (`POST /api/v1/members/{member}/report`):**
  - Supports reporting from `MemberProfileScreen` or directly from `ChatScreen` with optional `conversation_id` and `message_id` validation (verifying the reported message belongs to the conversation and was sent by the reported member).

---

## 10. Verification & Test Status

- **Backend Feature Tests:** `backend/tests/Feature/MatchmakingAndMessagingPhase6Test.php` (covers all 34 scenarios).
- **Flutter Widget & Service Tests:** `mobile/test/phase6_matchmaking_and_messaging_test.dart` (covers all 15 scenarios).
- **Execution Note:** Because `php`, `composer`, `flutter`, and `psql` binaries are not installed in this local Windows environment, all backend and Flutter tests are **Implemented at source level and ready for execution** (`Implemented — not executed locally due to missing PHP/Flutter binaries`).
