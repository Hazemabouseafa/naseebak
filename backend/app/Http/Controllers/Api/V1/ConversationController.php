<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiBusinessException;
use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\ConversationParticipant;
use App\Models\Message;
use App\Models\User;
use App\Models\UserProfile;
use App\Services\Messaging\ConversationMessagingService;
use App\Services\Profile\ProfileAccessControlService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConversationController extends Controller
{
    public function __construct(
        private readonly ConversationMessagingService $messagingService,
        private readonly ProfileAccessControlService $accessControlService,
        private readonly SubscriptionEntitlementService $entitlementService,
    ) {}

    /**
     * GET /api/v1/conversations
     *
     * Paginated list of the authenticated user's authorized conversations sorted by
     * most recent activity (last_message_at DESC, id DESC) without loading full chat histories.
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        $perPage = min(
            50,
            max(1, (int) $request->query('per_page', config('naseebak.messaging.conversations_per_page', 20)))
        );

        $paginator = Conversation::whereHas('participants', function ($q) use ($viewer) {
            $q->where('user_id', $viewer->id);
        })
            ->with([
                'participants.user.profile',
                'participants.user.photos',
                'lastMessage',
            ])
            ->orderByRaw('COALESCE(last_message_at, created_at) DESC')
            ->orderByDesc('id')
            ->paginate($perPage);

        $conversations = collect($paginator->items())
            ->map(function (Conversation $conversation) use ($viewer) {
                return $this->formatConversationSummary($viewer, $conversation);
            })
            ->filter()
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'conversations' => $conversations,
                'viewer_entitlement' => $this->entitlementService->getEntitlementPayload($viewer),
                'pagination' => [
                    'current_page' => $paginator->currentPage(),
                    'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(),
                    'total' => $paginator->total(),
                    'has_more_pages' => $paginator->hasMorePages(),
                ],
            ],
        ]);
    }

    /**
     * GET /api/v1/conversations/{conversation}
     *
     * Returns metadata, participant summary, restriction status, and current subscription
     * entitlement for a single authorized conversation.
     */
    public function show(Request $request, Conversation $conversation): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        try {
            $access = $this->messagingService->verifyParticipantAccess($viewer, $conversation);
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }

        $conversation->loadMissing('lastMessage');

        return response()->json([
            'status' => 'success',
            'data' => [
                'conversation' => $this->formatConversationSummary($viewer, $conversation, $access),
                'viewer_entitlement' => $this->entitlementService->getEntitlementPayload($viewer),
                'max_message_length' => (int) config('naseebak.messaging.max_message_length', 2000),
            ],
        ]);
    }

    /**
     * GET /api/v1/conversations/{conversation}/messages
     *
     * Cursor-based pagination for conversation message history (default 30 messages per request).
     * - Supports `before_id` to load older messages when scrolling upward.
     * - Supports `after_id` to resynchronize newer messages missed during temporary disconnection.
     * - Maintains deterministic ordering using `id` as the monotonic key.
     */
    public function messages(Request $request, Conversation $conversation): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        try {
            $access = $this->messagingService->verifyParticipantAccess($viewer, $conversation);
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }

        $limit = min(
            50,
            max(1, (int) $request->query('limit', config('naseebak.messaging.messages_per_page', 30)))
        );

        $beforeId = $request->filled('before_id') ? (int) $request->query('before_id') : null;
        $afterId = $request->filled('after_id') ? (int) $request->query('after_id') : null;

        $query = Message::where('conversation_id', $conversation->id);

        if ($afterId !== null && $afterId > 0) {
            // Reconnection catch-up: load messages newer than after_id
            $rows = $query->where('id', '>', $afterId)
                ->orderBy('id', 'asc')
                ->limit($limit + 1)
                ->get();

            $hasMore = $rows->count() > $limit;
            $slice = $rows->take($limit)->values();
        } else {
            // Initial load or upward scroll for older messages (before_id)
            if ($beforeId !== null && $beforeId > 0) {
                $query->where('id', '<', $beforeId);
            }

            $rows = $query->orderByDesc('id')
                ->limit($limit + 1)
                ->get();

            $hasMore = $rows->count() > $limit;
            // Return in chronological ascending order for chat display while exposing next_before_id cursor
            $slice = $rows->take($limit)->reverse()->values();
        }

        /** @var ConversationParticipant $otherParticipant */
        $otherParticipant = $access['other_participant'];
        $recipientLastReadId = $otherParticipant->last_read_message_id;
        $recipientLastDeliveredId = $otherParticipant->last_delivered_message_id;

        // Acknowledge actual delivery to viewer's client for any incoming messages fetched in this batch
        $maxIncomingFetchedId = (int) ($slice->where('sender_id', '!=', $viewer->id)->max('id') ?? 0);
        if ($maxIncomingFetchedId > 0) {
            $now = now();
            Message::where('conversation_id', $conversation->id)
                ->where('sender_id', '!=', $viewer->id)
                ->where('id', '<=', $maxIncomingFetchedId)
                ->whereNull('delivered_at')
                ->update(['delivered_at' => $now]);

            /** @var ConversationParticipant $viewerParticipant */
            $viewerParticipant = $access['viewer_participant'];
            if ((int) ($viewerParticipant->last_delivered_message_id ?? 0) < $maxIncomingFetchedId) {
                $viewerParticipant->update([
                    'last_delivered_message_id' => $maxIncomingFetchedId,
                    'last_delivered_at' => $now,
                ]);
            }
        }

        $formattedMessages = $slice->map(fn (Message $msg) => $this->formatMessagePayload(
            $msg,
            $recipientLastReadId,
            $recipientLastDeliveredId
        ));

        $oldestLoadedId = $slice->isNotEmpty() ? (int) $slice->first()->id : null;
        $newestLoadedId = $slice->isNotEmpty() ? (int) $slice->last()->id : null;

        return response()->json([
            'status' => 'success',
            'data' => [
                'messages' => $formattedMessages,
                'cursor' => [
                    'limit' => $limit,
                    'has_older_messages' => $afterId === null ? $hasMore : false,
                    'has_newer_messages' => $afterId !== null ? $hasMore : false,
                    'next_before_id' => ($afterId === null && $hasMore) ? $oldestLoadedId : null,
                    'latest_message_id' => $newestLoadedId,
                ],
                'conversation_state' => [
                    'status' => $conversation->status,
                    'is_blocked' => $access['is_blocked'],
                    'can_send_messages' => $access['can_send_messages'],
                    'restriction_code' => $access['restriction_code'],
                    'other_participant_last_read_message_id' => $recipientLastReadId,
                ],
                'can_send_messages' => $access['can_send_messages'],
                'restriction_code' => $access['restriction_code'],
            ],
        ]);
    }

    /**
     * POST /api/v1/conversations/{conversation}/messages
     *
     * Sends a text message after verifying:
     * 1. Participant membership
     * 2. Active account & non-blocked status
     * 3. Current paid subscription via SubscriptionEntitlementService::canSendMessage()
     * 4. Non-empty text <= 2000 chars
     * 5. Idempotent client_message_id
     */
    public function sendMessage(Request $request, Conversation $conversation): JsonResponse
    {
        $maxLength = (int) config('naseebak.messaging.max_message_length', 2000);

        $validated = $request->validate([
            'sender_id' => ['prohibited'],
            'body' => ['required', 'string', 'min:1', "max:{$maxLength}"],
            'client_message_id' => ['nullable', 'string', 'min:6', 'max:100'],
        ], [
            'sender_id.prohibited' => 'لا يُسمح بتمرير معرف المرسل يدوياً.',
            'body.required' => 'يرجى كتابة نص الرسالة.',
            'body.max' => "الحد الأقصى لطول الرسالة هو {$maxLength} حرف.",
        ]);

        /** @var User $sender */
        $sender = $request->user();

        try {
            $result = $this->messagingService->sendMessage(
                sender: $sender,
                conversation: $conversation,
                rawBody: $validated['body'],
                clientMessageId: $validated['client_message_id'] ?? null
            );
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }

        $message = $result['message'];
        $recipientParticipant = $result['recipient_participant'];

        return response()->json([
            'status' => 'success',
            'message' => 'تم إرسال الرسالة بنجاح.',
            'data' => [
                'was_duplicate' => $result['was_duplicate'],
                'idempotent_replay' => $result['was_duplicate'],
                'message' => $this->formatMessagePayload(
                    $message,
                    $recipientParticipant->last_read_message_id,
                    $recipientParticipant->last_delivered_message_id
                ),
            ],
        ], $result['was_duplicate'] ? 200 : 201);
    }

    /**
     * POST /api/v1/conversations/{conversation}/read
     *
     * Marks conversation messages as read using the cursor-based read marker.
     */
    public function markRead(Request $request, Conversation $conversation): JsonResponse
    {
        $validated = $request->validate([
            'up_to_message_id' => ['nullable', 'integer', 'min:1'],
        ]);

        /** @var User $reader */
        $reader = $request->user();

        try {
            $readResult = $this->messagingService->markConversationRead(
                reader: $reader,
                conversation: $conversation,
                upToMessageId: isset($validated['up_to_message_id']) ? (int) $validated['up_to_message_id'] : null
            );
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }

        return response()->json([
            'status' => 'success',
            'data' => $readResult,
        ]);
    }

    private function formatConversationSummary(
        User $viewer,
        Conversation $conversation,
        ?array $precomputedAccess = null
    ): ?array {
        try {
            $access = $precomputedAccess ?? $this->messagingService->verifyParticipantAccess($viewer, $conversation);
        } catch (ApiBusinessException) {
            return null;
        }

        /** @var ConversationParticipant $viewerParticipant */
        $viewerParticipant = $access['viewer_participant'];
        /** @var ConversationParticipant $otherParticipant */
        $otherParticipant = $access['other_participant'];
        /** @var User $otherUser */
        $otherUser = $access['other_user'];
        $otherProfile = $otherUser->profile;

        $primaryPhoto = $otherUser->photos->firstWhere('is_primary', true)
            ?? $otherUser->photos->first();

        $canSeePhoto = (!$access['is_blocked'] && $primaryPhoto)
            ? $this->accessControlService->canAccessPhoto($viewer, $primaryPhoto)
            : false;

        $lastMsg = $conversation->lastMessage;

        return [
            'id' => $conversation->id,
            'matchmaking_request_id' => $conversation->matchmaking_request_id,
            'status' => $access['is_blocked'] ? Conversation::STATUS_BLOCKED : $conversation->status,
            'is_blocked' => $access['is_blocked'],
            'can_send_messages' => $access['can_send_messages'],
            'restriction_code' => $access['restriction_code'],
            'unread_count' => (int) $viewerParticipant->unread_count,
            'viewer_last_read_message_id' => $viewerParticipant->last_read_message_id,
            'other_last_read_message_id' => $otherParticipant->last_read_message_id,
            'last_message_at' => ($conversation->last_message_at ?? $conversation->created_at)?->toIso8601String(),
            'last_message' => $lastMsg ? [
                'id' => $lastMsg->id,
                'sender_id' => $lastMsg->sender_id,
                'body_preview' => mb_strimwidth($lastMsg->body, 0, 90, '…'),
                'is_read' => (bool) $lastMsg->is_read,
                'created_at' => $lastMsg->created_at?->toIso8601String(),
            ] : null,
            'other_member' => [
                'user_id' => $otherUser->id,
                'full_name' => $otherProfile?->full_name ?? 'عضو نصيبك',
                'gender' => $otherProfile?->gender ?? 'female',
                'age_years' => $otherProfile ? UserProfile::calculateAgeYears($otherProfile->date_of_birth) : 18,
                'marital_status' => $otherProfile?->marital_status ?? 'single',
                'region' => $otherProfile?->region ?? '',
                'country_of_residence' => $otherProfile?->country_of_residence ?? '',
                'photo_privacy' => $otherProfile?->photo_privacy ?? 'public',
                'photo_authorized' => $canSeePhoto,
                'primary_photo_id' => ($primaryPhoto && $canSeePhoto) ? (int) $primaryPhoto->id : null,
                'primary_photo_url' => ($primaryPhoto && $canSeePhoto)
                    ? url("/api/v1/profile/photos/{$primaryPhoto->id}/stream")
                    : null,
            ],
        ];
    }

    private function formatMessagePayload(
        Message $message,
        ?int $recipientLastReadId,
        ?int $recipientLastDeliveredId
    ): array {
        return [
            'id' => $message->id,
            'conversation_id' => $message->conversation_id,
            'sender_id' => $message->sender_id,
            'client_message_id' => $message->client_message_id,
            'body' => $message->body,
            'is_read' => (bool) $message->is_read,
            'delivery_status' => $message->deliveryStatus($recipientLastReadId, $recipientLastDeliveredId),
            'delivered_at' => $message->delivered_at?->toIso8601String(),
            'read_at' => $message->read_at?->toIso8601String(),
            'created_at' => $message->created_at?->toIso8601String(),
        ];
    }
}
