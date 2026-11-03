<?php

namespace App\Services\Messaging;

use App\Events\ConversationUpdated;
use App\Events\MessageRead;
use App\Events\MessageSent;
use App\Exceptions\ApiBusinessException;
use App\Models\Conversation;
use App\Models\ConversationParticipant;
use App\Models\Message;
use App\Models\User;
use App\Services\Profile\ProfileAccessControlService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Illuminate\Support\Facades\DB;

class ConversationMessagingService
{
    public function __construct(
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly ProfileAccessControlService $accessControlService,
    ) {}

    /**
     * Verifies that $user is an authorized participant of $conversation and returns
     * both participant rows plus blocking and subscription state.
     *
     * @return array{
     *   viewer_participant: ConversationParticipant,
     *   other_participant: ConversationParticipant,
     *   other_user: User,
     *   is_blocked: bool,
     *   is_other_active: bool,
     *   can_send_messages: bool,
     *   restriction_code: ?string
     * }
     */
    public function verifyParticipantAccess(User $user, Conversation $conversation): array
    {
        if ($user->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'حسابك غير نشط حالياً.',
                403
            );
        }

        $conversation->loadMissing(['participants.user.profile', 'participants.user.photos']);

        /** @var ?ConversationParticipant $viewerParticipant */
        $viewerParticipant = $conversation->participants
            ->first(fn (ConversationParticipant $p) => (int) $p->user_id === (int) $user->id);

        /** @var ?ConversationParticipant $otherParticipant */
        $otherParticipant = $conversation->participants
            ->first(fn (ConversationParticipant $p) => (int) $p->user_id !== (int) $user->id);

        if (!$viewerParticipant || !$otherParticipant || !$otherParticipant->user) {
            throw new ApiBusinessException(
                'CONVERSATION_ACCESS_FORBIDDEN',
                'غير مصرح لك بالوصول إلى هذه المحادثة الخاصة.',
                403
            );
        }

        $otherUser = $otherParticipant->user;
        $isBlocked = $conversation->status === Conversation::STATUS_BLOCKED
            || $this->accessControlService->isBlockedBetween($user->id, $otherUser->id);

        $isOtherActive = $otherUser->account_status === 'active'
            && $conversation->status === Conversation::STATUS_ACTIVE;

        $hasPaidEntitlement = $this->entitlementService->canSendMessage($user);

        $restrictionCode = null;
        if ($isBlocked) {
            $restrictionCode = 'CONVERSATION_BLOCKED';
        } elseif (!$isOtherActive) {
            $restrictionCode = 'CONVERSATION_UNAVAILABLE';
        } elseif (!$hasPaidEntitlement) {
            $restrictionCode = 'SUBSCRIPTION_REQUIRED';
        }

        return [
            'viewer_participant' => $viewerParticipant,
            'other_participant' => $otherParticipant,
            'other_user' => $otherUser,
            'is_blocked' => $isBlocked,
            'is_other_active' => $isOtherActive,
            'can_send_messages' => $restrictionCode === null,
            'restriction_code' => $restrictionCode,
        ];
    }

    /**
     * Checks whether a user is allowed to subscribe to the real-time WebSocket channel
     * `private-conversation.{conversationId}`.
     *
     * Security Rule: Blocked or non-participant users are denied WebSocket subscription.
     */
    public function canSubscribeToConversationChannel(User $user, int $conversationId): bool
    {
        if ($user->account_status !== 'active') {
            return false;
        }

        $conversation = Conversation::with('participants')->find($conversationId);
        if (!$conversation || $conversation->status !== Conversation::STATUS_ACTIVE) {
            return false;
        }

        $viewerParticipant = $conversation->participants
            ->first(fn (ConversationParticipant $p) => (int) $p->user_id === (int) $user->id);
        $otherParticipant = $conversation->participants
            ->first(fn (ConversationParticipant $p) => (int) $p->user_id !== (int) $user->id);

        if (!$viewerParticipant || !$otherParticipant) {
            return false;
        }

        if ($this->accessControlService->isBlockedBetween($user->id, (int) $otherParticipant->user_id)) {
            return false;
        }

        return true;
    }

    /**
     * Sends a text message inside an authorized conversation.
     *
     * Enforces:
     * 1. Authenticated active participant
     * 2. No block relationship in either direction
     * 3. Active recipient account & active conversation status
     * 4. Active paid subscription via SubscriptionEntitlementService::canSendMessage()
     *    (returns HTTP 403 SUBSCRIPTION_REQUIRED if expired/free)
     * 5. Non-empty text <= max_message_length (2000 chars)
     * 6. Idempotent duplicate prevention via (conversation_id, sender_id, client_message_id)
     * 7. Broadcasts MessageSent and ConversationUpdated ONLY after PostgreSQL commit
     *
     * @return array{message: Message, was_duplicate: bool, recipient_participant: ConversationParticipant}
     */
    public function sendMessage(
        User $sender,
        Conversation $conversation,
        string $rawBody,
        ?string $clientMessageId = null
    ): array {
        $access = $this->verifyParticipantAccess($sender, $conversation);

        if ($access['is_blocked']) {
            throw new ApiBusinessException(
                'CONVERSATION_BLOCKED',
                'لا يمكن إرسال رسائل في هذه المحادثة بسبب وجود حظر بين الحسابين.',
                403
            );
        }

        if (!$access['is_other_active']) {
            throw new ApiBusinessException(
                'CONVERSATION_UNAVAILABLE',
                'هذه المحادثة غير متاحة لإرسال رسائل جديدة حالياً.',
                403
            );
        }

        // Critical Business Requirement: Every outgoing message checks SubscriptionEntitlementService::canSendMessage()
        if (!$this->entitlementService->canSendMessage($sender)) {
            throw new ApiBusinessException(
                'SUBSCRIPTION_REQUIRED',
                'يتطلب إرسال الرسائل الخاصة اشتراكًا شهريًا نشطًا في نصيبك.',
                403
            );
        }

        $body = trim($rawBody);
        $maxLength = (int) config('naseebak.messaging.max_message_length', 2000);

        if ($body === '') {
            throw new ApiBusinessException(
                'EMPTY_MESSAGE_BODY',
                'لا يمكن إرسال رسالة فارغة.',
                422
            );
        }

        if (mb_strlen($body) > $maxLength) {
            throw new ApiBusinessException(
                'MESSAGE_TOO_LONG',
                "تجاوزت الرسالة الحد الأقصى المسموح به ({$maxLength} حرف).",
                422
            );
        }

        $normalizedClientId = $clientMessageId !== null && trim($clientMessageId) !== ''
            ? trim($clientMessageId)
            : null;

        /** @var User $otherUser */
        $otherUser = $access['other_user'];

        return DB::transaction(function () use (
            $sender,
            $conversation,
            $body,
            $normalizedClientId,
            $otherUser
        ) {
            /** @var Conversation $lockedConversation */
            $lockedConversation = Conversation::where('id', $conversation->id)
                ->lockForUpdate()
                ->firstOrFail();

            if (
                $lockedConversation->status !== Conversation::STATUS_ACTIVE
                || $this->accessControlService->isBlockedBetween($sender->id, $otherUser->id)
            ) {
                throw new ApiBusinessException(
                    'CONVERSATION_BLOCKED',
                    'لا يمكن إرسال رسائل في هذه المحادثة.',
                    403
                );
            }

            // Idempotent duplicate check by client_message_id
            if ($normalizedClientId !== null) {
                $existingMessage = Message::where('conversation_id', $lockedConversation->id)
                    ->where('sender_id', $sender->id)
                    ->where('client_message_id', $normalizedClientId)
                    ->first();

                if ($existingMessage !== null) {
                    $recipientParticipant = ConversationParticipant::where('conversation_id', $lockedConversation->id)
                        ->where('user_id', $otherUser->id)
                        ->firstOrFail();

                    return [
                        'message' => $existingMessage,
                        'was_duplicate' => true,
                        'recipient_participant' => $recipientParticipant,
                    ];
                }
            }

            $message = Message::create([
                'conversation_id' => $lockedConversation->id,
                'sender_id' => $sender->id,
                'client_message_id' => $normalizedClientId,
                'body' => $body,
                'is_read' => false,
            ]);

            $lockedConversation->update([
                'last_message_id' => $message->id,
                'last_message_at' => $message->created_at,
            ]);

            /** @var ConversationParticipant $recipientParticipant */
            $recipientParticipant = ConversationParticipant::where('conversation_id', $lockedConversation->id)
                ->where('user_id', $otherUser->id)
                ->lockForUpdate()
                ->firstOrFail();

            $recipientParticipant->increment('unread_count');

            // Dispatch broadcast events (ShouldDispatchAfterCommit ensures delivery only after DB commit)
            MessageSent::dispatch($message, $lockedConversation->fresh(), (int) $otherUser->id);
            ConversationUpdated::dispatch($lockedConversation->fresh(), [(int) $sender->id, (int) $otherUser->id]);

            return [
                'message' => $message,
                'was_duplicate' => false,
                'recipient_participant' => $recipientParticipant->fresh(),
            ];
        });
    }

    /**
     * Marks messages in the conversation as read using a cursor-based read marker
     * on ConversationParticipant plus a single bulk update on unread incoming messages.
     *
     * Note: Reading messages and marking them read does NOT require a paid subscription.
     */
    public function markConversationRead(
        User $reader,
        Conversation $conversation,
        ?int $upToMessageId = null
    ): array {
        $access = $this->verifyParticipantAccess($reader, $conversation);

        /** @var ConversationParticipant $viewerParticipant */
        $viewerParticipant = $access['viewer_participant'];

        return DB::transaction(function () use ($reader, $conversation, $viewerParticipant, $upToMessageId) {
            /** @var ConversationParticipant $lockedParticipant */
            $lockedParticipant = ConversationParticipant::where('id', $viewerParticipant->id)
                ->lockForUpdate()
                ->firstOrFail();

            $latestMessageQuery = Message::where('conversation_id', $conversation->id);
            if ($upToMessageId !== null && $upToMessageId > 0) {
                $latestMessageQuery->where('id', '<=', $upToMessageId);
            }

            $latestMessageId = (int) ($latestMessageQuery->max('id') ?? 0);
            $now = now();

            $newReadMarker = max((int) ($lockedParticipant->last_read_message_id ?? 0), $latestMessageId);

            // Bulk mark unread incoming messages up to the cursor in a single SQL statement
            if ($newReadMarker > 0) {
                Message::where('conversation_id', $conversation->id)
                    ->where('sender_id', '!=', $reader->id)
                    ->where('id', '<=', $newReadMarker)
                    ->where('is_read', false)
                    ->update([
                        'is_read' => true,
                        'delivered_at' => $now,
                        'read_at' => $now,
                    ]);
            }

            $lockedParticipant->update([
                'unread_count' => Message::where('conversation_id', $conversation->id)
                    ->where('sender_id', '!=', $reader->id)
                    ->where('is_read', false)
                    ->count(),
                'last_read_message_id' => $newReadMarker > 0 ? $newReadMarker : $lockedParticipant->last_read_message_id,
                'last_read_at' => $now,
                'last_delivered_message_id' => max(
                    (int) ($lockedParticipant->last_delivered_message_id ?? 0),
                    $newReadMarker
                ) ?: null,
                'last_delivered_at' => $now,
            ]);

            if ($newReadMarker > 0) {
                MessageRead::dispatch(
                    $conversation->id,
                    (int) $reader->id,
                    $newReadMarker,
                    $now->toIso8601String()
                );
            }

            return [
                'conversation_id' => $conversation->id,
                'last_read_message_id' => $lockedParticipant->last_read_message_id,
                'unread_count' => (int) $lockedParticipant->unread_count,
                'read_at' => $now->toIso8601String(),
            ];
        });
    }
}
