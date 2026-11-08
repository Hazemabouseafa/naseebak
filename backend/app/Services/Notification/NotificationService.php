<?php

namespace App\Services\Notification;

use App\Events\NotificationCreated;
use App\Exceptions\ApiBusinessException;
use App\Jobs\DispatchAnnouncementCampaignJob;
use App\Jobs\SendPushNotificationJob;
use App\Models\Administrator;
use App\Models\AnnouncementCampaign;
use App\Models\Conversation;
use App\Models\ConversationParticipant;
use App\Models\DeviceToken;
use App\Models\MatchmakingRequest;
use App\Models\Message;
use App\Models\NotificationDeliveryAttempt;
use App\Models\NotificationPreference;
use App\Models\NotificationRecord;
use App\Models\Subscription;
use App\Models\User;
use App\Services\Admin\AdminAuditService;
use App\Services\Profile\ProfileAccessControlService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class NotificationService
{
    public function __construct(
        private readonly ProfileAccessControlService $accessControlService,
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly AdminAuditService $adminAuditService,
    ) {}

    /**
     * Registers or refreshes an FCM device token for the authenticated user.
     * Safely reassigns ownership if another user previously signed in on the same device.
     */
    public function registerDeviceToken(
        User $user,
        string $rawFcmToken,
        string $platform = 'android',
        ?string $deviceModel = null,
        ?string $appVersion = null,
        ?string $osVersion = null
    ): DeviceToken {
        if ($user->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'لا يمكن تسجيل رمز الإشعارات لحساب غير نشط.',
                403
            );
        }

        $trimmedToken = trim($rawFcmToken);
        if (strlen($trimmedToken) < 20 || strlen($trimmedToken) > 512) {
            throw new ApiBusinessException(
                'INVALID_FCM_TOKEN',
                'رمز جهاز الإشعارات غير صالح.',
                422
            );
        }

        $fingerprint = DeviceToken::computeFingerprint($trimmedToken);

        return DB::transaction(function () use ($user, $trimmedToken, $fingerprint, $platform, $deviceModel, $appVersion, $osVersion) {
            $existing = DeviceToken::where('token_fingerprint', $fingerprint)
                ->orWhere('fcm_token', $trimmedToken)
                ->lockForUpdate()
                ->first();

            $payload = [
                'user_id' => $user->id,
                'token_fingerprint' => $fingerprint,
                'fcm_token' => $trimmedToken,
                'device_platform' => strtolower($platform ?: 'android'),
                'device_model' => $deviceModel ? mb_substr(trim($deviceModel), 0, 120) : null,
                'app_version' => $appVersion ? mb_substr(trim($appVersion), 0, 32) : null,
                'os_version' => $osVersion ? mb_substr(trim($osVersion), 0, 32) : null,
                'is_valid' => true,
                'invalidated_reason' => null,
                'invalidated_at' => null,
                'last_registered_at' => now(),
            ];

            if ($existing !== null) {
                $existing->update($payload);
                return $existing->refresh();
            }

            return DeviceToken::create($payload);
        });
    }

    /**
     * Unregisters a specific device token (or all tokens for the authenticated user on logout)
     * without affecting tokens owned by other users.
     */
    public function unregisterDeviceToken(User $user, ?string $rawFcmToken = null): int
    {
        $query = DeviceToken::where('user_id', $user->id);

        if ($rawFcmToken !== null && trim($rawFcmToken) !== '') {
            $trimmed = trim($rawFcmToken);
            $fingerprint = DeviceToken::computeFingerprint($trimmed);
            $query->where(function ($q) use ($trimmed, $fingerprint) {
                $q->where('token_fingerprint', $fingerprint)
                    ->orWhere('fcm_token', $trimmed);
            });
        }

        return $query->delete();
    }

    /**
     * Retrieves or initializes the user's notification preferences.
     */
    public function getOrCreatePreferences(User $user): NotificationPreference
    {
        return NotificationPreference::firstOrCreate(
            ['user_id' => $user->id],
            [
                'matchmaking_requests_enabled' => true,
                'messages_enabled' => true,
                'subscriptions_enabled' => true,
                'announcements_enabled' => true,
            ]
        );
    }

    /**
     * Updates the user's notification category preferences.
     */
    public function updatePreferences(User $user, array $attributes): NotificationPreference
    {
        $prefs = $this->getOrCreatePreferences($user);

        $allowed = array_intersect_key($attributes, array_flip([
            'matchmaking_requests_enabled',
            'messages_enabled',
            'subscriptions_enabled',
            'announcements_enabled',
        ]));

        $prefs->update($allowed);

        return $prefs->refresh();
    }

    /**
     * Checks whether the recipient has enabled push/in-app delivery for the given notification event type.
     */
    public function isCategoryEnabledForUser(User $user, string $eventType): bool
    {
        $prefs = $this->getOrCreatePreferences($user);

        return match ($eventType) {
            NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            NotificationRecord::TYPE_ACCEPTED_MATCHMAKING_REQUEST,
            NotificationRecord::TYPE_REJECTED_MATCHMAKING_REQUEST => (bool) $prefs->matchmaking_requests_enabled,
            NotificationRecord::TYPE_NEW_PRIVATE_MESSAGE => (bool) $prefs->messages_enabled,
            NotificationRecord::TYPE_SUBSCRIPTION_ACTIVATED,
            NotificationRecord::TYPE_SUBSCRIPTION_EXPIRING_SOON,
            NotificationRecord::TYPE_SUBSCRIPTION_EXPIRED => (bool) $prefs->subscriptions_enabled,
            NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT => (bool) $prefs->announcements_enabled,
            default => true,
        };
    }

    /**
     * Event 1 — New Matchmaking Request notification for the recipient.
     */
    public function notifyMatchmakingRequestCreated(MatchmakingRequest $request): ?NotificationRecord
    {
        $recipient = User::find($request->recipient_id);
        if (!$recipient || $recipient->account_status !== 'active') {
            return null;
        }

        if ($this->accessControlService->isBlockedBetween($request->sender_id, $request->recipient_id)) {
            return null;
        }

        return $this->createAndDispatchNotification(
            recipient: $recipient,
            eventType: NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            titleAr: 'طلب تعارف جديد',
            bodyAr: 'لديك طلب تعارف جديد',
            deduplicationKey: "matchmaking_created:{$request->id}",
            actionRoute: NotificationRecord::ROUTE_MATCHMAKING_INCOMING,
            referenceType: 'matchmaking_request',
            referenceId: $request->id,
            routingMetadata: [
                'request_id' => $request->id,
                'tab' => 'incoming',
            ]
        );
    }

    /**
     * Event 2 — Accepted Matchmaking Request notification for the original sender.
     */
    public function notifyMatchmakingRequestAccepted(
        MatchmakingRequest $request,
        Conversation $conversation
    ): ?NotificationRecord {
        $sender = User::find($request->sender_id);
        if (!$sender || $sender->account_status !== 'active') {
            return null;
        }

        if ($this->accessControlService->isBlockedBetween($request->sender_id, $request->recipient_id)) {
            return null;
        }

        return $this->createAndDispatchNotification(
            recipient: $sender,
            eventType: NotificationRecord::TYPE_ACCEPTED_MATCHMAKING_REQUEST,
            titleAr: 'تمت الموافقة على طلبك',
            bodyAr: 'تمت الموافقة على طلب التعارف',
            deduplicationKey: "matchmaking_accepted:{$request->id}",
            actionRoute: NotificationRecord::ROUTE_CONVERSATION,
            referenceType: 'conversation',
            referenceId: $conversation->id,
            routingMetadata: [
                'request_id' => $request->id,
                'conversation_id' => $conversation->id,
                'tab' => 'accepted',
            ]
        );
    }

    /**
     * Event 3 — Rejected Matchmaking Request notification for the original sender.
     */
    public function notifyMatchmakingRequestRejected(MatchmakingRequest $request): ?NotificationRecord
    {
        $sender = User::find($request->sender_id);
        if (!$sender || $sender->account_status !== 'active') {
            return null;
        }

        if ($this->accessControlService->isBlockedBetween($request->sender_id, $request->recipient_id)) {
            return null;
        }

        if (!$this->isCategoryEnabledForUser($sender, NotificationRecord::TYPE_REJECTED_MATCHMAKING_REQUEST)) {
            return null;
        }

        return $this->createAndDispatchNotification(
            recipient: $sender,
            eventType: NotificationRecord::TYPE_REJECTED_MATCHMAKING_REQUEST,
            titleAr: 'تحديث طلب التعارف',
            bodyAr: 'هناك تحديث بخصوص طلب التعارف',
            deduplicationKey: "matchmaking_rejected:{$request->id}",
            actionRoute: NotificationRecord::ROUTE_MATCHMAKING_SENT,
            referenceType: 'matchmaking_request',
            referenceId: $request->id,
            routingMetadata: [
                'request_id' => $request->id,
                'tab' => 'sent',
            ]
        );
    }

    /**
     * Private Message Notification (Privacy-safe generic text only; never stores or sends message content).
     */
    public function notifyPrivateMessageSent(
        Conversation $conversation,
        Message $message,
        int $recipientUserId
    ): ?NotificationRecord {
        if ($conversation->status !== Conversation::STATUS_ACTIVE) {
            return null;
        }

        $recipient = User::find($recipientUserId);
        if (!$recipient || $recipient->account_status !== 'active') {
            return null;
        }

        $isParticipant = ConversationParticipant::where('conversation_id', $conversation->id)
            ->where('user_id', $recipient->id)
            ->exists();

        if (!$isParticipant) {
            return null;
        }

        if ($this->accessControlService->isBlockedBetween($message->sender_id, $recipient->id)) {
            return null;
        }

        return $this->createAndDispatchNotification(
            recipient: $recipient,
            eventType: NotificationRecord::TYPE_NEW_PRIVATE_MESSAGE,
            titleAr: 'رسالة جديدة',
            bodyAr: 'لديك رسالة جديدة',
            deduplicationKey: "message_sent:{$message->id}",
            actionRoute: NotificationRecord::ROUTE_CONVERSATION,
            referenceType: 'conversation',
            referenceId: $conversation->id,
            routingMetadata: [
                'conversation_id' => $conversation->id,
            ]
        );
    }

    /**
     * Subscription Activated Notification (only after verified payment / entitlement activation).
     */
    public function notifySubscriptionActivated(Subscription $subscription): ?NotificationRecord
    {
        if (!$subscription->isCurrentlyEntitled()) {
            return null;
        }

        $user = User::find($subscription->user_id);
        if (!$user || $user->account_status !== 'active') {
            return null;
        }

        $periodKey = $subscription->ends_at?->getTimestamp() ?? $subscription->id;

        return $this->createAndDispatchNotification(
            recipient: $user,
            eventType: NotificationRecord::TYPE_SUBSCRIPTION_ACTIVATED,
            titleAr: 'تم تفعيل اشتراكك',
            bodyAr: 'تم تفعيل اشتراكك بنجاح',
            deduplicationKey: "sub_activated:{$subscription->id}:{$periodKey}",
            actionRoute: NotificationRecord::ROUTE_SUBSCRIPTION,
            referenceType: 'subscription',
            referenceId: $subscription->id,
            routingMetadata: [
                'reference_id' => $subscription->id,
            ]
        );
    }

    /**
     * Subscription Approaching Expiration Notification (respects Google Play auto-renewal and overlapping subscriptions).
     */
    public function notifySubscriptionExpiringSoon(Subscription $subscription): ?NotificationRecord
    {
        if (!$subscription->isCurrentlyEntitled()) {
            return null;
        }

        // For Google Play subscriptions with automatic renewal enabled, do NOT imply the subscription will certainly end
        if ($subscription->channel === Subscription::CHANNEL_GOOGLE_PLAY && $subscription->auto_renewing) {
            return null;
        }

        $user = User::find($subscription->user_id);
        if (!$user || $user->account_status !== 'active') {
            return null;
        }

        // Check if another subscription grants a later expiration beyond the reminder window
        $highestSub = $this->entitlementService->findHighestPrioritySubscription($user);
        if ($highestSub && $highestSub->id !== $subscription->id) {
            $reminderDays = (int) config('naseebak.notifications.subscription_expiry_reminder_days', 3);
            $effectiveEnd = $highestSub->effectiveExpirationAt();
            if ($effectiveEnd && $effectiveEnd->greaterThan(now()->addDays($reminderDays))) {
                return null;
            }
        }

        $periodDate = $subscription->ends_at?->format('Y-m-d') ?? 'current';

        return $this->createAndDispatchNotification(
            recipient: $user,
            eventType: NotificationRecord::TYPE_SUBSCRIPTION_EXPIRING_SOON,
            titleAr: 'اشتراكك يقترب من الانتهاء',
            bodyAr: 'اشتراكك الشهري يقترب من الانتهاء، يمكنك التجديد لضمان استمرار التواصل.',
            deduplicationKey: "sub_expiring:{$subscription->id}:{$periodDate}",
            actionRoute: NotificationRecord::ROUTE_SUBSCRIPTION,
            referenceType: 'subscription',
            referenceId: $subscription->id,
            routingMetadata: [
                'reference_id' => $subscription->id,
            ]
        );
    }

    /**
     * Subscription Expired Notification.
     * Never falsely reports expiration when another valid subscription from any channel still grants entitlement.
     */
    public function notifySubscriptionExpiredIfNoOtherEntitlement(
        User $user,
        Subscription $expiredSubscription
    ): ?NotificationRecord {
        if ($user->account_status !== 'active') {
            return null;
        }

        // Critical check: Do NOT notify expiration if another active/grace subscription still grants access!
        if ($this->entitlementService->hasActiveSubscription($user)) {
            return null;
        }

        $periodKey = $expiredSubscription->ends_at?->getTimestamp() ?? $expiredSubscription->id;

        return $this->createAndDispatchNotification(
            recipient: $user,
            eventType: NotificationRecord::TYPE_SUBSCRIPTION_EXPIRED,
            titleAr: 'انتهت صلاحية اشتراكك',
            bodyAr: 'انتهت صلاحية اشتراكك',
            deduplicationKey: "sub_expired:{$expiredSubscription->id}:{$periodKey}",
            actionRoute: NotificationRecord::ROUTE_SUBSCRIPTION,
            referenceType: 'subscription',
            referenceId: $expiredSubscription->id,
            routingMetadata: [
                'reference_id' => $expiredSubscription->id,
            ]
        );
    }

    /**
     * Creates a deduplicated database notification record and dispatches the FCM push job after DB commit.
     */
    public function createAndDispatchNotification(
        User $recipient,
        string $eventType,
        string $titleAr,
        string $bodyAr,
        string $deduplicationKey,
        string $actionRoute = NotificationRecord::ROUTE_NOTIFICATION_CENTER,
        ?string $referenceType = null,
        ?int $referenceId = null,
        array $routingMetadata = [],
        ?int $campaignId = null
    ): ?NotificationRecord {
        if ($recipient->account_status !== 'active') {
            return null;
        }

        $safeRoute = in_array($actionRoute, NotificationRecord::ALLOWED_ROUTES, true)
            ? $actionRoute
            : NotificationRecord::ROUTE_NOTIFICATION_CENTER;

        $categoryEnabled = $this->isCategoryEnabledForUser($recipient, $eventType);

        // For optional marketing/admin announcements, do not force notifications on users who opted out
        if ($eventType === NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT && !$categoryEnabled) {
            return null;
        }

        $initialDeliveryStatus = $categoryEnabled
            ? NotificationRecord::DELIVERY_QUEUED
            : NotificationRecord::DELIVERY_DISABLED_BY_PREFERENCE;

        return DB::transaction(function () use (
            $recipient,
            $eventType,
            $titleAr,
            $bodyAr,
            $deduplicationKey,
            $safeRoute,
            $referenceType,
            $referenceId,
            $routingMetadata,
            $campaignId,
            $categoryEnabled,
            $initialDeliveryStatus
        ) {
            $existing = NotificationRecord::where('user_id', $recipient->id)
                ->where('deduplication_key', $deduplicationKey)
                ->first();

            if ($existing !== null) {
                return $existing;
            }

            $sanitizedRouting = $this->sanitizeRoutingMetadata($routingMetadata);

            $notification = NotificationRecord::create([
                'event_id' => (string) Str::uuid(),
                'deduplication_key' => $deduplicationKey,
                'user_id' => $recipient->id,
                'event_type' => $eventType,
                'title_ar' => mb_substr(trim($titleAr), 0, 160),
                'body_ar' => mb_substr(trim($bodyAr), 0, 500),
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'action_route' => $safeRoute,
                'routing_metadata' => $sanitizedRouting,
                'campaign_id' => $campaignId,
                'is_read' => false,
                'fcm_delivery_status' => $initialDeliveryStatus,
                'delivery_attempts' => 0,
            ]);

            // Broadcast over Reverb private-user.{userId} after commit for active foreground sessions
            try {
                NotificationCreated::dispatch($notification);
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Failed to broadcast NotificationCreated over Reverb', [
                    'notification_id' => $notification->id,
                    'error' => $e->getMessage(),
                ]);
            }

            // Queue FCM push notification job after commit if user enabled this category
            if ($categoryEnabled) {
                try {
                    SendPushNotificationJob::dispatch($notification->id)->afterCommit();
                } catch (\Throwable $e) {
                    \Illuminate\Support\Facades\Log::warning('Failed to dispatch SendPushNotificationJob', [
                        'notification_id' => $notification->id,
                        'error' => $e->getMessage(),
                    ]);
                }
            }

            return $notification;
        });
    }

    /**
     * Marks a single notification owned by $user as read.
     */
    public function markAsRead(User $user, NotificationRecord $notification): NotificationRecord
    {
        if ((int) $notification->user_id !== (int) $user->id) {
            throw new ApiBusinessException(
                'NOTIFICATION_ACCESS_DENIED',
                'غير مصرح لك بالوصول إلى هذا الإشعار.',
                403
            );
        }

        if (!$notification->is_read) {
            $updates = [
                'is_read' => true,
                'read_at' => now(),
            ];

            if ($notification->fcm_delivery_status === NotificationRecord::DELIVERY_SUBMITTED_TO_FCM) {
                $updates['fcm_delivery_status'] = NotificationRecord::DELIVERY_CONFIRMED_OPENED;
            }

            $notification->update($updates);

            if ($notification->campaign_id !== null) {
                AnnouncementCampaign::where('id', $notification->campaign_id)
                    ->increment('confirmed_read_count');
            }
        }

        return $notification->refresh();
    }

    /**
     * Marks all unread notifications for $user as read.
     */
    public function markAllAsRead(User $user): int
    {
        return NotificationRecord::where('user_id', $user->id)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
                'updated_at' => now(),
            ]);
    }

    /**
     * Deletes a notification from the user's personal Notification Center without touching conversation messages.
     */
    public function deleteNotification(User $user, NotificationRecord $notification): void
    {
        if ((int) $notification->user_id !== (int) $user->id) {
            throw new ApiBusinessException(
                'NOTIFICATION_ACCESS_DENIED',
                'غير مصرح لك بحذف هذا الإشعار.',
                403
            );
        }

        if (!empty($notification->deduplication_key)) {
            $cacheKey = "user_deleted_notif_keys:{$user->id}";
            $deletedKeys = \Illuminate\Support\Facades\Cache::get($cacheKey, []);
            if (!is_array($deletedKeys)) {
                $deletedKeys = [];
            }
            $deletedKeys[$notification->deduplication_key] = true;
            \Illuminate\Support\Facades\Cache::forever($cacheKey, $deletedKeys);
        }

        $notification->delete();
    }

    /**
     * Ensures real user activity (incoming/accepted/rejected matchmaking requests,
     * incoming private messages, and active subscriptions) has corresponding in-app
     * NotificationRecord rows even if an earlier real-time broadcast failed.
     */
    public function syncUserActivityNotifications(User $user): void
    {
        if ($user->account_status !== 'active') {
            return;
        }

        try {
            $deletedKeys = \Illuminate\Support\Facades\Cache::get("user_deleted_notif_keys:{$user->id}", []);
            if (!is_array($deletedKeys)) {
                $deletedKeys = [];
            }

            $existingKeys = NotificationRecord::where('user_id', $user->id)
                ->whereNotNull('deduplication_key')
                ->pluck('deduplication_key')
                ->flip()
                ->all();

            // 0. Administrative Announcement Campaigns (ensures Filament campaigns appear even without a separate queue worker)
            if ($this->isCategoryEnabledForUser($user, NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT)) {
                $campaigns = AnnouncementCampaign::whereIn('status', [
                    AnnouncementCampaign::STATUS_QUEUED,
                    AnnouncementCampaign::STATUS_PROCESSING,
                    AnnouncementCampaign::STATUS_COMPLETED,
                    AnnouncementCampaign::STATUS_SCHEDULED,
                ])
                    ->where(function ($q) {
                        $q->whereNull('scheduled_at')
                            ->orWhere('scheduled_at', '<=', now());
                    })
                    ->orderByDesc('id')
                    ->limit(25)
                    ->get();

                foreach ($campaigns as $campaign) {
                    if (in_array($campaign->status, [
                        AnnouncementCampaign::STATUS_QUEUED,
                        AnnouncementCampaign::STATUS_SCHEDULED,
                    ], true)) {
                        try {
                            $this->processQueuedAnnouncementCampaign($campaign);
                        } catch (\Throwable) {
                        }
                    }

                    $dedupKey = "campaign:{$campaign->id}:user:{$user->id}";
                    if (isset($existingKeys[$dedupKey]) || isset($deletedKeys[$dedupKey])) {
                        continue;
                    }

                    $audience = $campaign->audience ?: AnnouncementCampaign::AUDIENCE_ALL_ELIGIBLE;
                    $isEligibleForCampaign = $this->buildEligibleAudienceQuery($audience)
                        ->where('users.id', $user->id)
                        ->exists();

                    if (!$isEligibleForCampaign) {
                        continue;
                    }

                    $this->insertBackfilledNotification(
                        user: $user,
                        eventType: NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT,
                        titleAr: $campaign->title_ar,
                        bodyAr: $campaign->body_ar,
                        deduplicationKey: $dedupKey,
                        actionRoute: $campaign->action_route ?: NotificationRecord::ROUTE_NOTIFICATION_CENTER,
                        referenceType: 'announcement_campaign',
                        referenceId: (int) $campaign->id,
                        routingMetadata: [
                            'reference_id' => (int) $campaign->id,
                        ],
                        createdAt: $campaign->dispatched_at ?? $campaign->created_at
                    );
                    $existingKeys[$dedupKey] = true;
                }
            }

            // 1. Incoming pending matchmaking requests
            $incomingRequests = MatchmakingRequest::where('recipient_id', $user->id)
                ->where('status', MatchmakingRequest::STATUS_PENDING)
                ->with('sender.profile')
                ->orderByDesc('id')
                ->limit(25)
                ->get();

            foreach ($incomingRequests as $req) {
                $dedupKey = "matchmaking_created:{$req->id}";
                if (isset($existingKeys[$dedupKey]) || isset($deletedKeys[$dedupKey])) {
                    continue;
                }
                $senderName = $req->sender?->profile?->full_name;
                $bodyAr = $senderName
                    ? "أرسل لك \"{$senderName}\" طلب تعارف جديد."
                    : 'لديك طلب تعارف جديد';

                $this->insertBackfilledNotification(
                    user: $user,
                    eventType: NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
                    titleAr: 'طلب تعارف جديد',
                    bodyAr: $bodyAr,
                    deduplicationKey: $dedupKey,
                    actionRoute: NotificationRecord::ROUTE_MATCHMAKING_INCOMING,
                    referenceType: 'matchmaking_request',
                    referenceId: (int) $req->id,
                    routingMetadata: [
                        'request_id' => (int) $req->id,
                        'tab' => 'incoming',
                    ],
                    createdAt: $req->created_at
                );
                $existingKeys[$dedupKey] = true;
            }

            // 2. Accepted matchmaking requests (for both sender and recipient)
            $acceptedRequests = MatchmakingRequest::where('status', MatchmakingRequest::STATUS_ACCEPTED)
                ->where(function ($q) use ($user) {
                    $q->where('sender_id', $user->id)
                        ->orWhere('recipient_id', $user->id);
                })
                ->with(['sender.profile', 'recipient.profile', 'conversation'])
                ->orderByDesc('responded_at')
                ->orderByDesc('id')
                ->limit(20)
                ->get();

            foreach ($acceptedRequests as $req) {
                $isSender = (int) $req->sender_id === (int) $user->id;
                $dedupKey = $isSender
                    ? "matchmaking_accepted:{$req->id}"
                    : "matchmaking_accepted_recipient:{$req->id}";
                if (isset($existingKeys[$dedupKey]) || isset($deletedKeys[$dedupKey])) {
                    continue;
                }
                $convId = $req->conversation?->id;
                $otherName = $isSender
                    ? $req->recipient?->profile?->full_name
                    : $req->sender?->profile?->full_name;
                $titleAr = $isSender ? 'تمت الموافقة على طلبك' : 'تم فتح محادثة تعارف';
                $bodyAr = $otherName
                    ? ($isSender
                        ? "وافق \"{$otherName}\" على طلب التعارف الخاص بك."
                        : "تم قبول طلب التعارف وفتح المحادثة الخاصة مع \"{$otherName}\".")
                    : 'تمت الموافقة على طلب التعارف';

                $this->insertBackfilledNotification(
                    user: $user,
                    eventType: NotificationRecord::TYPE_ACCEPTED_MATCHMAKING_REQUEST,
                    titleAr: $titleAr,
                    bodyAr: $bodyAr,
                    deduplicationKey: $dedupKey,
                    actionRoute: $convId ? NotificationRecord::ROUTE_CONVERSATION : NotificationRecord::ROUTE_MATCHMAKING_INCOMING,
                    referenceType: $convId ? 'conversation' : 'matchmaking_request',
                    referenceId: (int) ($convId ?? $req->id),
                    routingMetadata: array_filter([
                        'request_id' => (int) $req->id,
                        'conversation_id' => $convId ? (int) $convId : null,
                        'tab' => 'accepted',
                    ], fn ($v) => $v !== null),
                    createdAt: $req->responded_at ?? $req->updated_at
                );
                $existingKeys[$dedupKey] = true;
            }

            // 3. Rejected matchmaking requests (for sender)
            $rejectedRequests = MatchmakingRequest::where('sender_id', $user->id)
                ->where('status', MatchmakingRequest::STATUS_REJECTED)
                ->orderByDesc('responded_at')
                ->orderByDesc('id')
                ->limit(15)
                ->get();

            foreach ($rejectedRequests as $req) {
                $dedupKey = "matchmaking_rejected:{$req->id}";
                if (isset($existingKeys[$dedupKey]) || isset($deletedKeys[$dedupKey])) {
                    continue;
                }
                $this->insertBackfilledNotification(
                    user: $user,
                    eventType: NotificationRecord::TYPE_REJECTED_MATCHMAKING_REQUEST,
                    titleAr: 'تحديث طلب التعارف',
                    bodyAr: 'هناك تحديث بخصوص طلب التعارف',
                    deduplicationKey: $dedupKey,
                    actionRoute: NotificationRecord::ROUTE_MATCHMAKING_SENT,
                    referenceType: 'matchmaking_request',
                    referenceId: (int) $req->id,
                    routingMetadata: [
                        'request_id' => (int) $req->id,
                        'tab' => 'sent',
                    ],
                    createdAt: $req->responded_at ?? $req->updated_at
                );
                $existingKeys[$dedupKey] = true;
            }

            // 4. Incoming messages in user's active conversations
            $conversationIds = ConversationParticipant::where('user_id', $user->id)
                ->pluck('conversation_id')
                ->all();

            if (!empty($conversationIds)) {
                $incomingMessages = Message::whereIn('conversation_id', $conversationIds)
                    ->where('sender_id', '!=', $user->id)
                    ->with('sender.profile')
                    ->orderByDesc('id')
                    ->limit(20)
                    ->get();

                foreach ($incomingMessages as $msg) {
                    $dedupKey = "message_sent:{$msg->id}";
                    if (isset($existingKeys[$dedupKey]) || isset($deletedKeys[$dedupKey])) {
                        continue;
                    }
                    $senderName = $msg->sender?->profile?->full_name;
                    $bodyAr = $senderName
                        ? "أرسل لك \"{$senderName}\" رسالة جديدة في المحادثة."
                        : 'لديك رسالة جديدة';

                    $this->insertBackfilledNotification(
                        user: $user,
                        eventType: NotificationRecord::TYPE_NEW_PRIVATE_MESSAGE,
                        titleAr: 'رسالة جديدة',
                        bodyAr: $bodyAr,
                        deduplicationKey: $dedupKey,
                        actionRoute: NotificationRecord::ROUTE_CONVERSATION,
                        referenceType: 'conversation',
                        referenceId: (int) $msg->conversation_id,
                        routingMetadata: [
                            'conversation_id' => (int) $msg->conversation_id,
                        ],
                        isRead: (bool) $msg->is_read,
                        readAt: $msg->read_at,
                        createdAt: $msg->created_at
                    );
                    $existingKeys[$dedupKey] = true;
                }
            }

            // 5. Active subscriptions
            $activeSubscriptions = Subscription::where('user_id', $user->id)
                ->whereIn('status', Subscription::ENTITLED_STATUSES)
                ->where('ends_at', '>', now())
                ->orderByDesc('id')
                ->limit(5)
                ->get();

            foreach ($activeSubscriptions as $sub) {
                $periodKey = $sub->ends_at?->getTimestamp() ?? $sub->id;
                $dedupKey = "sub_activated:{$sub->id}:{$periodKey}";
                if (isset($existingKeys[$dedupKey]) || isset($deletedKeys[$dedupKey])) {
                    continue;
                }
                $this->insertBackfilledNotification(
                    user: $user,
                    eventType: NotificationRecord::TYPE_SUBSCRIPTION_ACTIVATED,
                    titleAr: 'تم تفعيل اشتراكك',
                    bodyAr: 'تم تفعيل اشتراكك الشهري في نصيبك بنجاح.',
                    deduplicationKey: $dedupKey,
                    actionRoute: NotificationRecord::ROUTE_SUBSCRIPTION,
                    referenceType: 'subscription',
                    referenceId: (int) $sub->id,
                    routingMetadata: [
                        'reference_id' => (int) $sub->id,
                    ],
                    createdAt: $sub->starts_at ?? $sub->created_at
                );
                $existingKeys[$dedupKey] = true;
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('syncUserActivityNotifications encountered non-fatal error', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    private function insertBackfilledNotification(
        User $user,
        string $eventType,
        string $titleAr,
        string $bodyAr,
        string $deduplicationKey,
        string $actionRoute,
        ?string $referenceType = null,
        ?int $referenceId = null,
        array $routingMetadata = [],
        bool $isRead = false,
        $readAt = null,
        $createdAt = null
    ): void {
        $record = NotificationRecord::firstOrCreate(
            [
                'user_id' => $user->id,
                'deduplication_key' => $deduplicationKey,
            ],
            [
                'event_id' => (string) Str::uuid(),
                'event_type' => $eventType,
                'title_ar' => mb_substr(trim($titleAr), 0, 160),
                'body_ar' => mb_substr(trim($bodyAr), 0, 500),
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'action_route' => $actionRoute,
                'routing_metadata' => $this->sanitizeRoutingMetadata($routingMetadata),
                'is_read' => $isRead,
                'read_at' => $readAt,
                'fcm_delivery_status' => NotificationRecord::DELIVERY_NO_ACTIVE_DEVICES,
                'delivery_attempts' => 0,
            ]
        );

        if ($createdAt !== null && $record->wasRecentlyCreated) {
            $record->timestamps = false;
            $record->forceFill([
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ])->saveQuietly();
        }
    }

    public function getUnreadCount(User $user): int
    {
        return NotificationRecord::where('user_id', $user->id)
            ->where('is_read', false)
            ->count();
    }

    /**
     * Builds the server-side eligible recipient query for an administrative announcement audience.
     */
    public function buildEligibleAudienceQuery(string $audience): Builder
    {
        if (!in_array($audience, AnnouncementCampaign::ALLOWED_AUDIENCES, true)) {
            throw new ApiBusinessException(
                'INVALID_AUDIENCE',
                'فئة الجمهور المستهدف غير صالحة.',
                422
            );
        }

        $query = User::query()
            ->where('role', 'member')
            ->where('account_status', 'active')
            ->whereDoesntHave('notificationPreference', function (Builder $q) {
                $q->where('announcements_enabled', false);
            });

        $now = now();

        if ($audience === AnnouncementCampaign::AUDIENCE_ACTIVE_SUBSCRIBERS) {
            $query->whereHas('subscriptions', function (Builder $q) use ($now) {
                $q->whereIn('status', Subscription::ENTITLED_STATUSES)
                    ->where(function (Builder $subQ) use ($now) {
                        $subQ->where('ends_at', '>', $now)
                            ->orWhere('grace_period_ends_at', '>', $now);
                    });
            });
        } elseif ($audience === AnnouncementCampaign::AUDIENCE_EXPIRED_SUBSCRIBERS) {
            $query->whereHas('subscriptions', function (Builder $q) {
                $q->where('status', Subscription::STATUS_EXPIRED);
            })->whereDoesntHave('subscriptions', function (Builder $q) use ($now) {
                $q->whereIn('status', Subscription::ENTITLED_STATUSES)
                    ->where(function (Builder $subQ) use ($now) {
                        $subQ->where('ends_at', '>', $now)
                            ->orWhere('grace_period_ends_at', '>', $now);
                    });
            });
        }

        return $query;
    }

    public function countEligibleAudience(string $audience): int
    {
        return $this->buildEligibleAudienceQuery($audience)->count();
    }

    /**
     * Creates and queues an administrative announcement campaign with super_admin authorization,
     * confirmation requirement, idempotency protection, and audit logging.
     */
    public function createAndQueueAnnouncementCampaign(
        Administrator $actor,
        array $validated
    ): AnnouncementCampaign {
        if (!$actor->isSuperAdmin()) {
            throw new ApiBusinessException(
                'ADMIN_FORBIDDEN',
                'إرسال الإعلانات الإدارية الجماعية متاح للمدير العام فقط.',
                403
            );
        }

        if (empty($validated['confirmed'])) {
            throw new ApiBusinessException(
                'CONFIRMATION_REQUIRED',
                'يرجى تأكيد معاينة الإشعار وعدد المستلمين قبل الإرسال.',
                422
            );
        }

        $audience = (string) $validated['audience'];
        $titleAr = trim((string) $validated['title_ar']);
        $bodyAr = trim((string) $validated['body_ar']);
        $idempotencyKey = (string) ($validated['idempotency_key'] ?? hash('sha256', "{$actor->id}|{$audience}|{$titleAr}|{$bodyAr}"));

        return DB::transaction(function () use ($actor, $audience, $titleAr, $bodyAr, $idempotencyKey, $validated) {
            $existing = AnnouncementCampaign::where('idempotency_key', $idempotencyKey)
                ->lockForUpdate()
                ->first();

            if ($existing !== null) {
                return $existing;
            }

            $recipientCount = $this->countEligibleAudience($audience);
            $scheduledAt = !empty($validated['scheduled_at']) ? $validated['scheduled_at'] : null;

            $campaign = AnnouncementCampaign::create([
                'created_by_admin_id' => $actor->id,
                'title_ar' => mb_substr($titleAr, 0, 160),
                'body_ar' => mb_substr($bodyAr, 0, 500),
                'audience' => $audience,
                'action_route' => NotificationRecord::ROUTE_NOTIFICATION_CENTER,
                'status' => $scheduledAt ? AnnouncementCampaign::STATUS_SCHEDULED : AnnouncementCampaign::STATUS_QUEUED,
                'scheduled_at' => $scheduledAt,
                'eligible_recipients_count' => $recipientCount,
                'idempotency_key' => $idempotencyKey,
            ]);

            $this->adminAuditService->record(
                actor: $actor,
                action: 'announcement_campaign.queued',
                target: $campaign,
                previousValues: null,
                newValues: [
                    'audience' => $audience,
                    'eligible_recipients_count' => $recipientCount,
                    'title_ar' => $campaign->title_ar,
                ],
                reason: 'إرسال إشعار إداري عام عبر لوحة التحكم'
            );

            if (!$scheduledAt || \Illuminate\Support\Carbon::parse($scheduledAt)->lte(now())) {
                DB::afterCommit(function () use ($campaign) {
                    try {
                        $this->processQueuedAnnouncementCampaign($campaign->fresh() ?? $campaign);
                    } catch (\Throwable) {
                        DispatchAnnouncementCampaignJob::dispatch($campaign->id);
                    }
                });
            }

            return $campaign;
        });
    }

    /**
     * Processes a queued announcement campaign in bounded chunks so HTTP requests never block.
     */
    public function processQueuedAnnouncementCampaign(AnnouncementCampaign $campaign): void
    {
        if (in_array($campaign->status, [
            AnnouncementCampaign::STATUS_COMPLETED,
            AnnouncementCampaign::STATUS_CANCELLED,
        ], true)) {
            return;
        }

        $campaign->update([
            'status' => AnnouncementCampaign::STATUS_PROCESSING,
            'dispatched_at' => $campaign->dispatched_at ?? now(),
        ]);

        $chunkSize = max(25, (int) config('naseebak.notifications.campaign_chunk_size', 100));
        $queuedCount = 0;

        $this->buildEligibleAudienceQuery($campaign->audience)
            ->orderBy('id')
            ->chunkById($chunkSize, function ($users) use ($campaign, &$queuedCount) {
                foreach ($users as $user) {
                    $record = $this->createAndDispatchNotification(
                        recipient: $user,
                        eventType: NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT,
                        titleAr: $campaign->title_ar,
                        bodyAr: $campaign->body_ar,
                        deduplicationKey: "campaign:{$campaign->id}:user:{$user->id}",
                        actionRoute: NotificationRecord::ROUTE_NOTIFICATION_CENTER,
                        referenceType: 'announcement_campaign',
                        referenceId: $campaign->id,
                        routingMetadata: [
                            'reference_id' => $campaign->id,
                        ],
                        campaignId: $campaign->id
                    );

                    if ($record !== null) {
                        $queuedCount++;
                    }
                }
            });

        $campaign->update([
            'status' => AnnouncementCampaign::STATUS_COMPLETED,
            'queued_count' => $queuedCount,
            'completed_at' => now(),
        ]);
    }

    /**
     * Cleans up old notification records and delivery attempt logs according to retention rules
     * without ever deleting private conversation messages.
     *
     * @return array{deleted_notifications: int, deleted_attempts: int}
     */
    public function cleanupOldNotifications(): array
    {
        $notifDays = max(7, (int) config('naseebak.notifications.retention_days', 90));
        $attemptDays = max(7, (int) config('naseebak.notifications.delivery_attempts_retention_days', 30));

        $deletedAttempts = NotificationDeliveryAttempt::where('attempted_at', '<', now()->subDays($attemptDays))
            ->delete();

        $deletedNotifications = NotificationRecord::where('created_at', '<', now()->subDays($notifDays))
            ->delete();

        return [
            'deleted_notifications' => $deletedNotifications,
            'deleted_attempts' => $deletedAttempts,
        ];
    }

    private function sanitizeRoutingMetadata(array $metadata): array
    {
        $allowedKeys = [
            'request_id',
            'conversation_id',
            'reference_id',
            'tab',
        ];

        $clean = [];
        foreach ($allowedKeys as $key) {
            if (isset($metadata[$key]) && is_scalar($metadata[$key])) {
                $clean[$key] = $metadata[$key];
            }
        }

        return $clean;
    }
}
