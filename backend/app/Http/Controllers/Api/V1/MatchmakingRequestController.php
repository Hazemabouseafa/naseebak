<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiBusinessException;
use App\Http\Controllers\Controller;
use App\Models\BlockedUser;
use App\Models\Conversation;
use App\Models\MatchmakingRequest;
use App\Models\User;
use App\Models\UserProfile;
use App\Services\Matchmaking\MatchmakingService;
use App\Services\Profile\ProfileAccessControlService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MatchmakingRequestController extends Controller
{
    public function __construct(
        private readonly MatchmakingService $matchmakingService,
        private readonly ProfileAccessControlService $accessControlService,
    ) {}

    /**
     * GET /api/v1/matchmaking/requests
     *
     * Returns the authenticated user's matchmaking requests grouped into:
     * 1. incoming (الواردة)
     * 2. sent     (المرسلة)
     * 3. accepted (المقبولة)
     *
     * Strictly excludes blocked or suspended members and enforces photo privacy rules.
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        $blockedIds = BlockedUser::where('blocker_id', $viewer->id)
            ->pluck('blocked_id')
            ->merge(
                BlockedUser::where('blocked_id', $viewer->id)->pluck('blocker_id')
            )
            ->unique()
            ->values()
            ->all();

        // 1. Incoming requests (الواردة — pending & rejected received)
        $incomingQuery = MatchmakingRequest::where('recipient_id', $viewer->id)
            ->whereIn('status', [MatchmakingRequest::STATUS_PENDING, MatchmakingRequest::STATUS_REJECTED])
            ->with(['sender.profile', 'sender.photos', 'conversation'])
            ->orderByRaw("CASE WHEN status = 'pending' THEN 0 ELSE 1 END")
            ->orderByDesc('created_at');

        if (!empty($blockedIds)) {
            $incomingQuery->whereNotIn('sender_id', $blockedIds);
        }

        $incoming = $incomingQuery->get()
            ->filter(fn (MatchmakingRequest $r) =>
                $r->sender !== null
                && $r->sender->account_status === 'active'
                && $r->sender->profile !== null
            )
            ->map(fn (MatchmakingRequest $r) => $this->formatRequestItem($viewer, $r, $r->sender, 'incoming'))
            ->values();

        // 2. Sent requests (المرسلة — pending, rejected, cancelled sent by viewer)
        $sentQuery = MatchmakingRequest::where('sender_id', $viewer->id)
            ->whereIn('status', [
                MatchmakingRequest::STATUS_PENDING,
                MatchmakingRequest::STATUS_REJECTED,
                MatchmakingRequest::STATUS_CANCELLED,
            ])
            ->with(['recipient.profile', 'recipient.photos', 'conversation'])
            ->orderByDesc('created_at');

        if (!empty($blockedIds)) {
            $sentQuery->whereNotIn('recipient_id', $blockedIds);
        }

        $sent = $sentQuery->get()
            ->filter(fn (MatchmakingRequest $r) =>
                $r->recipient !== null
                && $r->recipient->account_status === 'active'
                && $r->recipient->profile !== null
            )
            ->map(fn (MatchmakingRequest $r) => $this->formatRequestItem($viewer, $r, $r->recipient, 'sent'))
            ->values();

        // 3. Accepted requests (المقبولة — accepted in either direction)
        $acceptedQuery = MatchmakingRequest::where('status', MatchmakingRequest::STATUS_ACCEPTED)
            ->where(function ($q) use ($viewer) {
                $q->where('sender_id', $viewer->id)
                    ->orWhere('recipient_id', $viewer->id);
            })
            ->with(['sender.profile', 'sender.photos', 'recipient.profile', 'recipient.photos', 'conversation'])
            ->orderByDesc('responded_at')
            ->orderByDesc('id');

        $accepted = $acceptedQuery->get()
            ->map(function (MatchmakingRequest $r) use ($viewer, $blockedIds) {
                $otherUser = (int) $r->sender_id === (int) $viewer->id ? $r->recipient : $r->sender;
                if (
                    !$otherUser
                    || $otherUser->account_status !== 'active'
                    || !$otherUser->profile
                    || in_array((int) $otherUser->id, $blockedIds, true)
                ) {
                    return null;
                }

                return $this->formatRequestItem($viewer, $r, $otherUser, 'accepted');
            })
            ->filter()
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'incoming' => $incoming,
                'sent' => $sent,
                'accepted' => $accepted,
            ],
        ]);
    }

    /**
     * GET /api/v1/matchmaking/requests/sent
     */
    public function sent(Request $request): JsonResponse
    {
        $all = $this->index($request)->getData(true);

        return response()->json([
            'status' => 'success',
            'data' => [
                'requests' => $all['data']['sent'] ?? [],
            ],
        ]);
    }

    /**
     * GET /api/v1/matchmaking/requests/incoming
     */
    public function incoming(Request $request): JsonResponse
    {
        $all = $this->index($request)->getData(true);

        return response()->json([
            'status' => 'success',
            'data' => [
                'requests' => $all['data']['incoming'] ?? [],
            ],
        ]);
    }

    /**
     * POST /api/v1/matchmaking/requests
     *
     * Prohibits client-supplied `sender_id`. Uses `$request->user()` exclusively.
     */
    public function store(Request $request): JsonResponse
    {
        if (!$request->has('recipient_id') && $request->has('recipient_user_id')) {
            $request->merge(['recipient_id' => $request->input('recipient_user_id')]);
        }

        $validated = $request->validate([
            'sender_id' => ['prohibited'],
            'recipient_id' => ['required', 'integer', 'min:1'],
        ], [
            'sender_id.prohibited' => 'لا يُسمح بتمرير معرف المرسل يدوياً؛ يتم تحديد الهوية من الجلسة الموثقة.',
            'recipient_id.required' => 'يرجى تحديد العضو المستلم لطلب التعارف.',
        ]);

        /** @var User $sender */
        $sender = $request->user();

        try {
            $created = $this->matchmakingService->createRequest(
                sender: $sender,
                recipientUserId: (int) $validated['recipient_id']
            );
        } catch (ApiBusinessException $e) {
            return response()->json(array_merge([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->extraPayload), $e->httpStatus);
        }

        $created->loadMissing(['recipient.profile', 'recipient.photos']);

        return response()->json([
            'status' => 'success',
            'message' => 'تم إرسال طلب التعارف بنجاح',
            'data' => [
                'request' => $created->recipient
                    ? $this->formatRequestItem($sender, $created, $created->recipient, 'sent')
                    : [
                        'id' => $created->id,
                        'status' => $created->status,
                    ],
            ],
        ], 201);
    }

    /**
     * GET /api/v1/matchmaking/requests/{matchmakingRequest}
     */
    public function show(Request $request, MatchmakingRequest $matchmakingRequest): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        if (
            (int) $matchmakingRequest->sender_id !== (int) $viewer->id
            && (int) $matchmakingRequest->recipient_id !== (int) $viewer->id
        ) {
            return response()->json([
                'status' => 'error',
                'code' => 'UNAUTHORIZED_REQUEST_ACCESS',
                'message' => 'غير مصرح لك بعرض تفاصيل طلب التعارف هذا.',
            ], 403);
        }

        $matchmakingRequest->loadMissing([
            'sender.profile',
            'sender.photos',
            'recipient.profile',
            'recipient.photos',
            'conversation',
        ]);

        $otherUser = (int) $matchmakingRequest->sender_id === (int) $viewer->id
            ? $matchmakingRequest->recipient
            : $matchmakingRequest->sender;

        if (!$otherUser || $this->accessControlService->isBlockedBetween($viewer->id, $otherUser->id)) {
            return response()->json([
                'status' => 'error',
                'code' => 'REQUEST_UNAVAILABLE',
                'message' => 'طلب التعارف غير متاح للعرض.',
            ], 403);
        }

        $direction = $matchmakingRequest->status === MatchmakingRequest::STATUS_ACCEPTED
            ? 'accepted'
            : ((int) $matchmakingRequest->recipient_id === (int) $viewer->id ? 'incoming' : 'sent');

        return response()->json([
            'status' => 'success',
            'data' => [
                'request' => $this->formatRequestItem($viewer, $matchmakingRequest, $otherUser, $direction),
            ],
        ]);
    }

    /**
     * POST /api/v1/matchmaking/requests/{matchmakingRequest}/accept
     */
    public function accept(Request $request, MatchmakingRequest $matchmakingRequest): JsonResponse
    {
        /** @var User $actor */
        $actor = $request->user();

        try {
            $result = $this->matchmakingService->acceptRequest($actor, $matchmakingRequest);
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }

        $updatedRequest = $result['request'];
        $conversation = $result['conversation'];
        $updatedRequest->loadMissing(['sender.profile', 'sender.photos', 'conversation']);

        return response()->json([
            'status' => 'success',
            'message' => 'تم قبول طلب التعارف وفتح المحادثة الخاصة بنجاح.',
            'data' => [
                'request' => $updatedRequest->sender
                    ? $this->formatRequestItem($actor, $updatedRequest, $updatedRequest->sender, 'accepted')
                    : ['id' => $updatedRequest->id, 'status' => $updatedRequest->status],
                'conversation_id' => $conversation->id,
            ],
        ]);
    }

    /**
     * POST /api/v1/matchmaking/requests/{matchmakingRequest}/reject
     */
    public function reject(Request $request, MatchmakingRequest $matchmakingRequest): JsonResponse
    {
        /** @var User $actor */
        $actor = $request->user();

        try {
            $updated = $this->matchmakingService->rejectRequest($actor, $matchmakingRequest);
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم رفض طلب التعارف.',
            'data' => [
                'request_id' => $updated->id,
                'status' => $updated->status,
                'responded_at' => $updated->responded_at?->toIso8601String(),
                'request' => [
                    'id' => $updated->id,
                    'status' => $updated->status,
                    'responded_at' => $updated->responded_at?->toIso8601String(),
                ],
            ],
        ]);
    }

    /**
     * POST /api/v1/matchmaking/requests/{matchmakingRequest}/cancel
     */
    public function cancel(Request $request, MatchmakingRequest $matchmakingRequest): JsonResponse
    {
        /** @var User $actor */
        $actor = $request->user();

        try {
            $updated = $this->matchmakingService->cancelRequest($actor, $matchmakingRequest);
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم إلغاء طلب التعارف المرسل.',
            'data' => [
                'request_id' => $updated->id,
                'status' => $updated->status,
                'cancelled_at' => $updated->cancelled_at?->toIso8601String(),
                'request' => [
                    'id' => $updated->id,
                    'status' => $updated->status,
                    'cancelled_at' => $updated->cancelled_at?->toIso8601String(),
                ],
            ],
        ]);
    }

    private function formatRequestItem(
        User $viewer,
        MatchmakingRequest $request,
        User $otherUser,
        string $direction
    ): array {
        $profile = $otherUser->profile;
        $primaryPhoto = $otherUser->photos->firstWhere('is_primary', true)
            ?? $otherUser->photos->first();

        $canSeePhoto = $primaryPhoto
            ? $this->accessControlService->canAccessPhoto($viewer, $primaryPhoto)
            : false;

        $lowId = min((int) $request->sender_id, (int) $request->recipient_id);
        $highId = max((int) $request->sender_id, (int) $request->recipient_id);

        $conversationId = $request->conversation?->id;
        if ($conversationId === null && $request->status === MatchmakingRequest::STATUS_ACCEPTED) {
            $conversationId = Conversation::where('user_one_id', $lowId)
                ->where('user_two_id', $highId)
                ->value('id');
        }

        return [
            'id' => $request->id,
            'direction' => $direction,
            'sender_id' => $request->sender_id,
            'recipient_id' => $request->recipient_id,
            'status' => $request->status,
            'status_label_ar' => match ($request->status) {
                MatchmakingRequest::STATUS_PENDING => 'قيد الانتظار',
                MatchmakingRequest::STATUS_ACCEPTED => 'مقبول',
                MatchmakingRequest::STATUS_REJECTED => 'مرفوض',
                MatchmakingRequest::STATUS_CANCELLED => 'ملغى',
                default => $request->status,
            },
            'can_accept' => (int) $request->recipient_id === (int) $viewer->id
                && $request->status === MatchmakingRequest::STATUS_PENDING,
            'can_reject' => (int) $request->recipient_id === (int) $viewer->id
                && $request->status === MatchmakingRequest::STATUS_PENDING,
            'can_cancel' => (int) $request->sender_id === (int) $viewer->id
                && $request->status === MatchmakingRequest::STATUS_PENDING,
            'conversation_id' => $conversationId,
            'created_at' => $request->created_at?->toIso8601String(),
            'responded_at' => $request->responded_at?->toIso8601String(),
            'member' => [
                'user_id' => $otherUser->id,
                'full_name' => $profile?->full_name ?? 'عضو نصيبك',
                'gender' => $profile?->gender ?? 'female',
                'age_years' => $profile ? UserProfile::calculateAgeYears($profile->date_of_birth) : 18,
                'marital_status' => $profile?->marital_status ?? 'single',
                'region' => $profile?->region ?? '',
                'country_of_residence' => $profile?->country_of_residence ?? '',
                'photo_privacy' => $profile?->photo_privacy ?? 'public',
                'photo_authorized' => $canSeePhoto,
                'primary_photo_id' => ($primaryPhoto && $canSeePhoto) ? (int) $primaryPhoto->id : null,
                'primary_photo_url' => ($primaryPhoto && $canSeePhoto)
                    ? url("/api/v1/profile/photos/{$primaryPhoto->id}/stream")
                    : null,
            ],
        ];
    }
}
