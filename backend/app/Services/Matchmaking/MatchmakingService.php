<?php

namespace App\Services\Matchmaking;

use App\Events\ConversationUpdated;
use App\Events\MatchmakingRequestAccepted;
use App\Events\MatchmakingRequestCreated;
use App\Events\MatchmakingRequestRejected;
use App\Exceptions\ApiBusinessException;
use App\Models\Conversation;
use App\Models\ConversationParticipant;
use App\Models\MatchmakingRequest;
use App\Models\User;
use App\Models\UserProfile;
use App\Services\Profile\ProfileAccessControlService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Illuminate\Support\Facades\DB;

class MatchmakingService
{
    public function __construct(
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly ProfileAccessControlService $accessControlService,
    ) {}

    /**
     * Evaluates the matchmaking relationship between $viewer and $target for Screen 12 (MemberProfileScreen).
     *
     * Supported button_state values:
     * - 'available'
     * - 'subscription_required'
     * - 'request_pending'
     * - 'request_received_pending'
     * - 'request_accepted'
     * - 'request_rejected'
     * - 'user_blocked'
     * - 'request_unavailable'
     */
    public function getRelationshipContext(User $viewer, User $target): array
    {
        if ($viewer->id === $target->id) {
            return [
                'button_state' => 'request_unavailable',
                'request_id' => null,
                'request_status' => null,
                'conversation_id' => null,
            ];
        }

        if ($this->accessControlService->isBlockedBetween($viewer->id, $target->id)) {
            return [
                'button_state' => 'user_blocked',
                'request_id' => null,
                'request_status' => null,
                'conversation_id' => null,
            ];
        }

        $lowId = min((int) $viewer->id, (int) $target->id);
        $highId = max((int) $viewer->id, (int) $target->id);

        $requests = MatchmakingRequest::where('user_low_id', $lowId)
            ->where('user_high_id', $highId)
            ->with('conversation')
            ->orderByDesc('id')
            ->get();

        // 1. Accepted relationship takes precedence
        $accepted = $requests->firstWhere('status', MatchmakingRequest::STATUS_ACCEPTED);
        if ($accepted !== null) {
            $convId = $accepted->conversation?->id
                ?? Conversation::where('user_one_id', $lowId)->where('user_two_id', $highId)->value('id');

            return [
                'button_state' => 'request_accepted',
                'request_id' => $accepted->id,
                'request_status' => MatchmakingRequest::STATUS_ACCEPTED,
                'conversation_id' => $convId,
            ];
        }

        // 2. Pending request sent by viewer
        $pendingSent = $requests->first(fn (MatchmakingRequest $r) =>
            $r->status === MatchmakingRequest::STATUS_PENDING && (int) $r->sender_id === (int) $viewer->id
        );
        if ($pendingSent !== null) {
            return [
                'button_state' => 'request_pending',
                'request_id' => $pendingSent->id,
                'request_status' => MatchmakingRequest::STATUS_PENDING,
                'conversation_id' => null,
            ];
        }

        // 3. Pending request received from target
        $pendingReceived = $requests->first(fn (MatchmakingRequest $r) =>
            $r->status === MatchmakingRequest::STATUS_PENDING && (int) $r->recipient_id === (int) $viewer->id
        );
        if ($pendingReceived !== null) {
            return [
                'button_state' => 'request_received_pending',
                'request_id' => $pendingReceived->id,
                'request_status' => MatchmakingRequest::STATUS_PENDING,
                'conversation_id' => null,
            ];
        }

        // 4. Previously rejected request
        $rejected = $requests->firstWhere('status', MatchmakingRequest::STATUS_REJECTED);
        if ($rejected !== null && !config('naseebak.matchmaking.allow_rerequest_after_rejection', false)) {
            return [
                'button_state' => 'request_rejected',
                'request_id' => $rejected->id,
                'request_status' => MatchmakingRequest::STATUS_REJECTED,
                'conversation_id' => null,
            ];
        }

        // 5. Check recipient eligibility
        $targetProfile = $target->profile;
        if (
            $target->account_status !== 'active'
            || !$targetProfile
            || !$targetProfile->isModerationApprovedForDiscovery()
            || !$targetProfile->is_visible
            || UserProfile::calculateAgeYears($targetProfile->date_of_birth) < 18
        ) {
            return [
                'button_state' => 'request_unavailable',
                'request_id' => null,
                'request_status' => null,
                'conversation_id' => null,
            ];
        }

        // 6. Check sender's paid subscription entitlement
        if (!$this->entitlementService->canSendMatchRequest($viewer)) {
            return [
                'button_state' => 'subscription_required',
                'request_id' => null,
                'request_status' => null,
                'conversation_id' => null,
            ];
        }

        return [
            'button_state' => 'available',
            'request_id' => null,
            'request_status' => null,
            'conversation_id' => null,
        ];
    }

    /**
     * Creates a new pending matchmaking request after verifying all 9 Phase 6 rules:
     * 1. Authenticated sender
     * 2. Sender account is active
     * 3. Sender profile is complete
     * 4. Sender is at least 18
     * 5. Recipient is eligible (active account, adult 18+, not self)
     * 6. Recipient profile is approved and visible
     * 7. Neither user has blocked the other
     * 8. Sender has an active subscription (via SubscriptionEntitlementService::canSendMatchRequest)
     * 9. No conflicting or duplicate request exists (enforced under row-level locks)
     */
    public function createRequest(User $sender, int $recipientUserId): MatchmakingRequest
    {
        if ((int) $sender->id === $recipientUserId) {
            throw new ApiBusinessException(
                'CANNOT_REQUEST_SELF',
                'لا يمكنك إرسال طلب تعارف إلى حسابك الشخصي.',
                422
            );
        }

        if ($sender->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'حسابك غير نشط حالياً ولا يمكنه إرسال طلبات تعارف.',
                403
            );
        }

        $sender->loadMissing('profile');
        $senderProfile = $sender->profile;

        if (!$sender->profile_completed || !$senderProfile) {
            throw new ApiBusinessException(
                'PROFILE_INCOMPLETE',
                'يرجى استكمال ملفك الشخصي أولاً قبل إرسال طلبات التعارف.',
                403
            );
        }

        if (UserProfile::calculateAgeYears($senderProfile->date_of_birth) < 18) {
            throw new ApiBusinessException(
                'UNDERAGE_RESTRICTED',
                'التطبيق مخصص للبالغين من عمر 18 عاماً فأكثر فقط.',
                403
            );
        }

        $recipient = User::with('profile')->find($recipientUserId);
        if (!$recipient || $recipient->account_status !== 'active') {
            throw new ApiBusinessException(
                'RECIPIENT_UNAVAILABLE',
                'حساب العضو المطلوب غير متاح لاستقبال طلبات التعارف.',
                404
            );
        }

        // Check bidirectional blocking BEFORE subscription prompt so blocked users are rejected immediately
        if ($this->accessControlService->isBlockedBetween($sender->id, $recipient->id)) {
            throw new ApiBusinessException(
                'USER_BLOCKED',
                'لا يمكن إرسال طلب تعارف إلى هذا العضو.',
                403
            );
        }

        $recipientProfile = $recipient->profile;
        if (
            !$recipientProfile
            || !$recipientProfile->isModerationApprovedForDiscovery()
            || !$recipientProfile->is_visible
            || UserProfile::calculateAgeYears($recipientProfile->date_of_birth) < 18
        ) {
            throw new ApiBusinessException(
                'RECIPIENT_INELIGIBLE',
                'الملف الشخصي لهذا العضو غير متاح لاستقبال طلبات التعارف حالياً.',
                403
            );
        }

        // Critical Authorization Rule: Check sender's current subscription entitlement via SubscriptionEntitlementService
        if (!$this->entitlementService->canSendMatchRequest($sender)) {
            throw new ApiBusinessException(
                'SUBSCRIPTION_REQUIRED',
                'يتطلب إرسال طلب التعارف اشتراكًا شهريًا نشطًا في نصيبك.',
                403
            );
        }

        $lowId = min((int) $sender->id, (int) $recipient->id);
        $highId = max((int) $sender->id, (int) $recipient->id);

        return DB::transaction(function () use ($sender, $recipient, $lowId, $highId) {
            // Lock both user rows in deterministic ascending ID order to prevent deadlocks and race conditions
            User::whereIn('id', [$lowId, $highId])
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            // Re-verify block inside transaction lock
            if ($this->accessControlService->isBlockedBetween($sender->id, $recipient->id)) {
                throw new ApiBusinessException(
                    'USER_BLOCKED',
                    'لا يمكن إرسال طلب تعارف إلى هذا العضو.',
                    403
                );
            }

            // Lock any existing matchmaking requests between the two users in either direction
            $existingRequests = MatchmakingRequest::where('user_low_id', $lowId)
                ->where('user_high_id', $highId)
                ->lockForUpdate()
                ->get();

            // 1. Already accepted relationship?
            if ($existingRequests->contains('status', MatchmakingRequest::STATUS_ACCEPTED)) {
                throw new ApiBusinessException(
                    'MATCH_ALREADY_ACCEPTED',
                    'يوجد تعارف مقبول ومحادثة متاحة بالفعل بينكما.',
                    409
                );
            }

            // 2. Duplicate pending request from same sender?
            $sameDirectionRow = $existingRequests->first(fn (MatchmakingRequest $r) =>
                (int) $r->sender_id === (int) $sender->id && (int) $r->recipient_id === (int) $recipient->id
            );

            if ($sameDirectionRow !== null && $sameDirectionRow->status === MatchmakingRequest::STATUS_PENDING) {
                throw new ApiBusinessException(
                    'DUPLICATE_PENDING_REQUEST',
                    'طلب التعارف قيد الانتظار بالفعل لدى هذا العضو.',
                    409
                );
            }

            // 3. Reciprocal pending request from recipient to sender?
            // Safe policy: A reciprocal request must NOT automatically grant conversation access without explicit acceptance!
            $reversePendingRow = $existingRequests->first(fn (MatchmakingRequest $r) =>
                (int) $r->sender_id === (int) $recipient->id
                && (int) $r->recipient_id === (int) $sender->id
                && $r->status === MatchmakingRequest::STATUS_PENDING
            );

            if ($reversePendingRow !== null) {
                throw new ApiBusinessException(
                    'RECIPROCAL_PENDING_REQUEST_EXISTS',
                    'لديك طلب تعارف وارد بالفعل من هذا العضو بانتظار قبولك في قائمة الطلبات الواردة.',
                    409,
                    ['incoming_request_id' => $reversePendingRow->id]
                );
            }

            // 4. Safe rejection policy: prevent repeated requests after rejection unless explicitly enabled
            if (
                $existingRequests->contains('status', MatchmakingRequest::STATUS_REJECTED)
                && !config('naseebak.matchmaking.allow_rerequest_after_rejection', false)
            ) {
                throw new ApiBusinessException(
                    'REQUEST_PREVIOUSLY_REJECTED',
                    'تم الاعتذار عن طلب التعارف مسبقاً ولا يمكن إعادة إرسال الطلب.',
                    422
                );
            }

            // 5. If sender previously cancelled their own request, reopen that row to preserve unique(sender_id, recipient_id)
            if ($sameDirectionRow !== null && $sameDirectionRow->status === MatchmakingRequest::STATUS_CANCELLED) {
                $sameDirectionRow->update([
                    'status' => MatchmakingRequest::STATUS_PENDING,
                    'responded_at' => null,
                    'cancelled_at' => null,
                ]);
                $request = $sameDirectionRow->refresh();
            } else {
                $request = MatchmakingRequest::create([
                    'sender_id' => $sender->id,
                    'recipient_id' => $recipient->id,
                    'user_low_id' => $lowId,
                    'user_high_id' => $highId,
                    'status' => MatchmakingRequest::STATUS_PENDING,
                ]);
            }

            try {
                app(\App\Services\Notification\NotificationService::class)
                    ->notifyMatchmakingRequestCreated($request);
            } catch (\Throwable) {
            }

            try {
                MatchmakingRequestCreated::dispatch($request);
            } catch (\Throwable) {
            }

            return $request;
        });
    }

    /**
     * Accepts an incoming pending matchmaking request and atomically creates
     * the single authorized one-to-one Conversation and ConversationParticipant records.
     *
     * Note: Accepting an incoming request does NOT require a paid subscription.
     *
     * @return array{request: MatchmakingRequest, conversation: Conversation}
     */
    public function acceptRequest(User $actor, MatchmakingRequest $matchmakingRequest): array
    {
        if ($actor->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'حسابك غير نشط حالياً.',
                403
            );
        }

        if ((int) $matchmakingRequest->recipient_id !== (int) $actor->id) {
            throw new ApiBusinessException(
                'UNAUTHORIZED_REQUEST_ACTION',
                'لا يُسمح بقبول طلب تعارف غير موجه إلى حسابك.',
                403
            );
        }

        $lowId = min((int) $matchmakingRequest->sender_id, (int) $matchmakingRequest->recipient_id);
        $highId = max((int) $matchmakingRequest->sender_id, (int) $matchmakingRequest->recipient_id);

        return DB::transaction(function () use ($actor, $matchmakingRequest, $lowId, $highId) {
            // Lock both user rows in canonical order
            $users = User::whereIn('id', [$lowId, $highId])
                ->orderBy('id')
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            $sender = $users->get((int) $matchmakingRequest->sender_id);
            $recipient = $users->get((int) $matchmakingRequest->recipient_id);

            if (!$sender || !$recipient || $sender->account_status !== 'active' || $recipient->account_status !== 'active') {
                throw new ApiBusinessException(
                    'PARTICIPANT_INACTIVE',
                    'لا يمكن قبول الطلب لأن أحد الحسابين غير نشط حالياً.',
                    403
                );
            }

            if ($this->accessControlService->isBlockedBetween($sender->id, $recipient->id)) {
                throw new ApiBusinessException(
                    'USER_BLOCKED',
                    'لا يمكن قبول طلب التعارف لوجود حظر بين الحسابين.',
                    403
                );
            }

            /** @var MatchmakingRequest $lockedRequest */
            $lockedRequest = MatchmakingRequest::where('id', $matchmakingRequest->id)
                ->lockForUpdate()
                ->firstOrFail();

            // Idempotent handling for repeated/concurrent acceptance of the same request
            if ($lockedRequest->status === MatchmakingRequest::STATUS_ACCEPTED) {
                $existingConversation = Conversation::where('user_one_id', $lowId)
                    ->where('user_two_id', $highId)
                    ->first()
                    ?? Conversation::where('matchmaking_request_id', $lockedRequest->id)->first();

                if ($existingConversation !== null) {
                    return [
                        'request' => $lockedRequest,
                        'conversation' => $existingConversation,
                    ];
                }
            }

            if ($lockedRequest->status !== MatchmakingRequest::STATUS_PENDING) {
                throw new ApiBusinessException(
                    'INVALID_REQUEST_STATE',
                    'لا يمكن قبول هذا الطلب لأنه لم يعد قيد الانتظار.',
                    422
                );
            }

            $now = now();
            $lockedRequest->update([
                'status' => MatchmakingRequest::STATUS_ACCEPTED,
                'responded_at' => $now,
            ]);

            // Cancel any stale pending request in the opposite direction if one existed
            MatchmakingRequest::where('sender_id', $recipient->id)
                ->where('recipient_id', $sender->id)
                ->where('status', MatchmakingRequest::STATUS_PENDING)
                ->update([
                    'status' => MatchmakingRequest::STATUS_CANCELLED,
                    'cancelled_at' => $now,
                    'responded_at' => $now,
                ]);

            // Atomically find or create the single canonical Conversation for this pair
            $conversation = Conversation::where('user_one_id', $lowId)
                ->where('user_two_id', $highId)
                ->lockForUpdate()
                ->first();

            if ($conversation === null) {
                $conversation = Conversation::create([
                    'matchmaking_request_id' => $lockedRequest->id,
                    'user_one_id' => $lowId,
                    'user_two_id' => $highId,
                    'status' => Conversation::STATUS_ACTIVE,
                ]);
            } elseif ($conversation->status !== Conversation::STATUS_ACTIVE) {
                $conversation->update([
                    'matchmaking_request_id' => $lockedRequest->id,
                    'status' => Conversation::STATUS_ACTIVE,
                ]);
            }

            // Ensure both authorized participants exist exactly once
            ConversationParticipant::firstOrCreate(
                [
                    'conversation_id' => $conversation->id,
                    'user_id' => $sender->id,
                ],
                [
                    'unread_count' => 0,
                ]
            );

            ConversationParticipant::firstOrCreate(
                [
                    'conversation_id' => $conversation->id,
                    'user_id' => $recipient->id,
                ],
                [
                    'unread_count' => 0,
                ]
            );

            $freshRequest = $lockedRequest->fresh();

            try {
                app(\App\Services\Notification\NotificationService::class)
                    ->notifyMatchmakingRequestAccepted($freshRequest, $conversation);
            } catch (\Throwable) {
            }

            try {
                MatchmakingRequestAccepted::dispatch($freshRequest, $conversation);
                ConversationUpdated::dispatch($conversation, [(int) $sender->id, (int) $recipient->id]);
            } catch (\Throwable) {
            }

            return [
                'request' => $freshRequest,
                'conversation' => $conversation->fresh(),
            ];
        });
    }

    /**
     * Rejects an incoming pending matchmaking request without creating a conversation.
     * Does NOT require a paid subscription.
     */
    public function rejectRequest(User $actor, MatchmakingRequest $matchmakingRequest): MatchmakingRequest
    {
        if ($actor->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'حسابك غير نشط حالياً.',
                403
            );
        }

        if ((int) $matchmakingRequest->recipient_id !== (int) $actor->id) {
            throw new ApiBusinessException(
                'UNAUTHORIZED_REQUEST_ACTION',
                'لا يُسمح برفض طلب تعارف غير موجه إلى حسابك.',
                403
            );
        }

        return DB::transaction(function () use ($matchmakingRequest) {
            /** @var MatchmakingRequest $lockedRequest */
            $lockedRequest = MatchmakingRequest::where('id', $matchmakingRequest->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($lockedRequest->status === MatchmakingRequest::STATUS_REJECTED) {
                return $lockedRequest;
            }

            if ($lockedRequest->status !== MatchmakingRequest::STATUS_PENDING) {
                throw new ApiBusinessException(
                    'INVALID_REQUEST_STATE',
                    'لا يمكن رفض هذا الطلب لأنه لم يعد قيد الانتظار.',
                    422
                );
            }

            $lockedRequest->update([
                'status' => MatchmakingRequest::STATUS_REJECTED,
                'responded_at' => now(),
            ]);

            $freshRejected = $lockedRequest->fresh();

            try {
                app(\App\Services\Notification\NotificationService::class)
                    ->notifyMatchmakingRequestRejected($freshRejected);
            } catch (\Throwable) {
            }

            try {
                MatchmakingRequestRejected::dispatch($freshRejected);
            } catch (\Throwable) {
            }

            return $freshRejected;
        });
    }

    /**
     * Allows the sender of a pending matchmaking request to cancel it while still pending.
     */
    public function cancelRequest(User $actor, MatchmakingRequest $matchmakingRequest): MatchmakingRequest
    {
        if ($actor->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'حسابك غير نشط حالياً.',
                403
            );
        }

        if ((int) $matchmakingRequest->sender_id !== (int) $actor->id) {
            throw new ApiBusinessException(
                'UNAUTHORIZED_REQUEST_ACTION',
                'لا يُسمح بإلغاء طلب تعارف لم تقم بإرساله.',
                403
            );
        }

        return DB::transaction(function () use ($matchmakingRequest) {
            /** @var MatchmakingRequest $lockedRequest */
            $lockedRequest = MatchmakingRequest::where('id', $matchmakingRequest->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($lockedRequest->status === MatchmakingRequest::STATUS_CANCELLED) {
                return $lockedRequest;
            }

            if ($lockedRequest->status !== MatchmakingRequest::STATUS_PENDING) {
                throw new ApiBusinessException(
                    'INVALID_REQUEST_STATE',
                    'لا يمكن إلغاء الطلب بعد الرد عليه.',
                    422
                );
            }

            $now = now();
            $lockedRequest->update([
                'status' => MatchmakingRequest::STATUS_CANCELLED,
                'cancelled_at' => $now,
                'responded_at' => $now,
            ]);

            return $lockedRequest->fresh();
        });
    }
}
