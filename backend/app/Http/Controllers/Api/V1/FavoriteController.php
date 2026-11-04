<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\BlockedUser;
use App\Models\Conversation;
use App\Models\Favorite;
use App\Models\MatchmakingRequest;
use App\Models\Message;
use App\Models\User;
use App\Models\UserProfile;
use App\Models\UserReport;
use App\Services\Discovery\MemberSearchQueryService;
use App\Services\Profile\ProfileAccessControlService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class FavoriteController extends Controller
{
    public function __construct(
        private readonly ProfileAccessControlService $accessControlService,
        private readonly MemberSearchQueryService $searchQueryService,
    ) {}

    /**
     * GET /api/v1/favorites
     *
     * Returns saved favorite members while strictly filtering out any member who has since:
     * - Become suspended or deleted
     * - Hidden their profile (unless an accepted match exists)
     * - Become unapproved
     * - Blocked or been blocked by the current user
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        $favoritedUserIds = Favorite::where('user_id', $viewer->id)
            ->orderByDesc('created_at')
            ->pluck('favorited_user_id');

        if ($favoritedUserIds->isEmpty()) {
            return response()->json([
                'status' => 'success',
                'data' => [
                    'favorites' => [],
                ],
            ]);
        }

        // Query only eligible visible/approved/non-blocked profiles among favorited IDs
        $eligibleProfiles = $this->searchQueryService
            ->buildEligibleProfilesQuery($viewer)
            ->whereIn('user_profiles.user_id', $favoritedUserIds->all())
            ->get()
            ->keyBy('user_id');

        // Preserve chronological favorite order
        $orderedProfiles = $favoritedUserIds
            ->map(fn ($id) => $eligibleProfiles->get($id))
            ->filter()
            ->values();

        $formatted = $this->searchQueryService
            ->formatMemberCardsCollection($viewer, $orderedProfiles)
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'favorites' => $formatted,
            ],
        ]);
    }

    /**
     * POST /api/v1/favorites/{member}
     *
     * Prevents:
     * - Favoriting own account
     * - Favoriting blocked members
     * - Favoriting suspended, hidden, underage, or unapproved profiles
     * - Duplicate favorites (idempotent updateOrCreate)
     */
    public function store(Request $request, User $member): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        if ($viewer->id === $member->id) {
            return response()->json([
                'status' => 'error',
                'code' => 'CANNOT_FAVORITE_SELF',
                'message' => 'لا يمكنك إضافة حسابك الشخصي إلى قائمة المفضلة.',
            ], 422);
        }

        $member->loadMissing('profile');
        $targetProfile = $member->profile;

        if (
            !$targetProfile
            || $targetProfile->moderation_status !== 'approved'
            || $targetProfile->age_years < 18
            || !$this->accessControlService->canViewProfile($viewer, $member, $targetProfile)
        ) {
            return response()->json([
                'status' => 'error',
                'code' => 'MEMBER_INACCESSIBLE',
                'message' => 'لا يمكن إضافة هذا العضو إلى المفضلة لعدم توفر الملف الشخصي.',
            ], 403);
        }

        Favorite::firstOrCreate([
            'user_id' => $viewer->id,
            'favorited_user_id' => $member->id,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تمت إضافة العضو إلى المفضلة بنجاح.',
            'data' => [
                'favorited_user_id' => $member->id,
                'is_favorited' => true,
            ],
        ], 201);
    }

    /**
     * DELETE /api/v1/favorites/{member}
     */
    public function destroy(Request $request, User $member): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        Favorite::where('user_id', $viewer->id)
            ->where('favorited_user_id', $member->id)
            ->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تمت إزالة العضو من المفضلة.',
            'data' => [
                'favorited_user_id' => $member->id,
                'is_favorited' => false,
            ],
        ]);
    }

    /**
     * POST /api/v1/members/{member}/block
     * Safety Action: Block a member (also removes mutual favorites immediately).
     */
    public function blockMember(Request $request, User $member): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        if ($viewer->id === $member->id) {
            return response()->json([
                'status' => 'error',
                'code' => 'CANNOT_BLOCK_SELF',
                'message' => 'لا يمكنك حظر حسابك الشخصي.',
            ], 422);
        }

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        DB::transaction(function () use ($viewer, $member, $validated) {
            BlockedUser::updateOrCreate(
                [
                    'blocker_id' => $viewer->id,
                    'blocked_id' => $member->id,
                ],
                [
                    'reason' => $validated['reason'] ?? 'حظر من صفحة الملف الشخصي',
                ]
            );

            // Remove any favorites in either direction
            Favorite::where(function ($q) use ($viewer, $member) {
                $q->where('user_id', $viewer->id)->where('favorited_user_id', $member->id);
            })->orWhere(function ($q) use ($viewer, $member) {
                $q->where('user_id', $member->id)->where('favorited_user_id', $viewer->id);
            })->delete();

            // Cancel any pending matchmaking requests in either direction
            $now = now();
            MatchmakingRequest::where('status', MatchmakingRequest::STATUS_PENDING)
                ->where(function ($q) use ($viewer, $member) {
                    $q->where(function ($sub) use ($viewer, $member) {
                        $sub->where('sender_id', $viewer->id)->where('recipient_id', $member->id);
                    })->orWhere(function ($sub) use ($viewer, $member) {
                        $sub->where('sender_id', $member->id)->where('recipient_id', $viewer->id);
                    });
                })
                ->update([
                    'status' => MatchmakingRequest::STATUS_CANCELLED,
                    'cancelled_at' => $now,
                    'responded_at' => $now,
                ]);

            // Mark any existing conversation between the two users as blocked (while preserving message history)
            $lowId = min((int) $viewer->id, (int) $member->id);
            $highId = max((int) $viewer->id, (int) $member->id);

            Conversation::where(function ($q) use ($lowId, $highId, $viewer, $member) {
                $q->where(function ($pair) use ($lowId, $highId) {
                    $pair->where('user_one_id', $lowId)->where('user_two_id', $highId);
                })->orWhere(function ($participants) use ($viewer, $member) {
                    $participants->whereHas('participants', fn ($p) => $p->where('user_id', $viewer->id))
                        ->whereHas('participants', fn ($p) => $p->where('user_id', $member->id));
                });
            })->update([
                'status' => Conversation::STATUS_BLOCKED,
            ]);
        });

        return response()->json([
            'status' => 'success',
            'message' => 'تم حظر العضو بنجاح ولن يظهر لك مجدداً.',
        ]);
    }

    /**
     * GET /api/v1/blocked-members
     *
     * Returns paginated list of members blocked by the authenticated user.
     */
    public function blockedMembers(Request $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        $perPage = min(50, max(1, (int) $request->query('per_page', 20)));

        $paginator = BlockedUser::where('blocker_id', $viewer->id)
            ->with(['blocked.profile', 'blocked.photos'])
            ->orderByDesc('created_at')
            ->paginate($perPage);

        $items = collect($paginator->items())->map(function (BlockedUser $block) {
            $blockedUser = $block->blocked;
            $profile = $blockedUser?->profile;

            return [
                'id' => $block->id,
                'blocked_user_id' => $block->blocked_id,
                'full_name' => $profile?->full_name ?? 'عضو نصيبك',
                'gender' => $profile?->gender ?? 'female',
                'age_years' => $profile ? UserProfile::calculateAgeYears($profile->date_of_birth) : 18,
                'region' => $profile?->region ?? '',
                'country_of_residence' => $profile?->country_of_residence ?? '',
                'reason' => $block->reason ?? 'تم الحظر بواسطة المستخدم',
                'blocked_at' => $block->created_at?->toIso8601String(),
                'unblock_allowed' => true,
            ];
        });

        return response()->json([
            'status' => 'success',
            'data' => [
                'blocked_members' => $items,
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
     * DELETE /api/v1/members/{member}/block
     *
     * Unblocks a previously blocked member.
     */
    public function unblockMember(Request $request, User $member): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        $deletedCount = BlockedUser::where('blocker_id', $viewer->id)
            ->where('blocked_id', $member->id)
            ->delete();

        // Check if mutual block still exists from other user
        $stillBlockedByOther = BlockedUser::where('blocker_id', $member->id)
            ->where('blocked_id', $viewer->id)
            ->exists();

        if (!$stillBlockedByOther) {
            $lowId = min((int) $viewer->id, (int) $member->id);
            $highId = max((int) $viewer->id, (int) $member->id);

            Conversation::where(function ($q) use ($lowId, $highId) {
                $q->where('user_one_id', $lowId)->where('user_two_id', $highId);
            })->where('status', Conversation::STATUS_BLOCKED)
                ->update(['status' => Conversation::STATUS_ACTIVE]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم إلغاء حظر العضو بنجاح.',
            'data' => [
                'blocked_user_id' => $member->id,
                'is_blocked' => false,
                'was_unblocked' => $deletedCount > 0,
            ],
        ]);
    }

    /**
     * POST /api/v1/members/{member}/report
     * Safety Action: Report a member to administrators.
     */
    public function reportMember(Request $request, User $member): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();

        if ($viewer->id === $member->id) {
            return response()->json([
                'status' => 'error',
                'code' => 'CANNOT_REPORT_SELF',
                'message' => 'لا يمكنك الإبلاغ عن حسابك الشخصي.',
            ], 422);
        }

        $validated = $request->validate([
            'reason_category' => [
                'required',
                Rule::in(['inappropriate_behavior', 'fake_profile', 'harassment', 'scam_attempt', 'other']),
            ],
            'details' => ['required', 'string', 'min:5', 'max:1000'],
            'conversation_id' => ['nullable', 'integer', 'min:1'],
            'message_id' => ['nullable', 'integer', 'min:1'],
        ], [
            'reason_category.required' => 'يرجى اختيار سبب البلاغ.',
            'details.required' => 'يرجى كتابة تفاصيل البلاغ ليتمكن فريق المراجعة من التحقق.',
            'details.min' => 'يرجى توضيح تفاصيل البلاغ بشكل كافٍ.',
        ]);

        $conversationId = isset($validated['conversation_id']) ? (int) $validated['conversation_id'] : null;
        $messageId = isset($validated['message_id']) ? (int) $validated['message_id'] : null;

        // If a conversation or message reference is supplied, verify that the reporter and reported member belong to it
        if ($conversationId !== null) {
            $authorizedConversation = Conversation::where('id', $conversationId)
                ->whereHas('participants', fn ($q) => $q->where('user_id', $viewer->id))
                ->whereHas('participants', fn ($q) => $q->where('user_id', $member->id))
                ->first();

            if (!$authorizedConversation) {
                return response()->json([
                    'status' => 'error',
                    'code' => 'INVALID_CONVERSATION_REFERENCE',
                    'message' => 'مرجع المحادثة المرفق بالبلاغ غير صالح.',
                ], 403);
            }
        }

        if ($messageId !== null) {
            $referencedMessage = Message::find($messageId);
            if (
                !$referencedMessage
                || ($conversationId !== null && (int) $referencedMessage->conversation_id !== $conversationId)
            ) {
                return response()->json([
                    'status' => 'error',
                    'code' => 'INVALID_MESSAGE_REFERENCE',
                    'message' => 'مرجع الرسالة المرفق بالبلاغ غير صالح.',
                ], 422);
            }

            if ($conversationId === null) {
                $authorizedConversation = Conversation::where('id', $referencedMessage->conversation_id)
                    ->whereHas('participants', fn ($q) => $q->where('user_id', $viewer->id))
                    ->whereHas('participants', fn ($q) => $q->where('user_id', $member->id))
                    ->first();

                if (!$authorizedConversation) {
                    return response()->json([
                        'status' => 'error',
                        'code' => 'INVALID_MESSAGE_REFERENCE',
                        'message' => 'غير مصرح لك بالإبلاغ عن رسالة خارج محادثاتك.',
                    ], 403);
                }

                $conversationId = $authorizedConversation->id;
            }
        }

        UserReport::create([
            'reporter_id' => $viewer->id,
            'reported_user_id' => $member->id,
            'conversation_id' => $conversationId,
            'message_id' => $messageId,
            'reason_category' => $validated['reason_category'],
            'details' => trim($validated['details']),
            'status' => 'pending',
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم إرسال البلاغ إلى إدارة نصيبك وسيتم التعامل معه بسرية تامة.',
        ], 201);
    }
}
