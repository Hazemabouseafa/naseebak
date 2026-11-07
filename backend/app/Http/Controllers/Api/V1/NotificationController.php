<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiBusinessException;
use App\Http\Controllers\Controller;
use App\Models\NotificationRecord;
use App\Models\User;
use App\Services\Notification\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function __construct(
        private readonly NotificationService $notificationService
    ) {}

    /**
     * GET /api/v1/notifications
     *
     * Returns paginated in-app notifications for the authenticated user sorted newest first.
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $this->notificationService->syncUserActivityNotifications($user);

        $perPage = min(50, max(5, (int) $request->query(
            'per_page',
            config('naseebak.notifications.notifications_per_page', 20)
        )));

        $paginator = NotificationRecord::where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate($perPage);

        $unreadCount = $this->notificationService->getUnreadCount($user);

        $items = $paginator->getCollection()->map(
            fn (NotificationRecord $n) => $this->formatNotification($n)
        )->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'notifications' => $items,
                'unread_count' => $unreadCount,
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
     * GET /api/v1/notifications/unread-count
     */
    public function unreadCount(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $this->notificationService->syncUserActivityNotifications($user);

        return response()->json([
            'status' => 'success',
            'data' => [
                'unread_count' => $this->notificationService->getUnreadCount($user),
            ],
        ]);
    }

    /**
     * POST /api/v1/notifications/{notification}/read
     */
    public function markRead(Request $request, NotificationRecord $notification): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        try {
            $updated = $this->notificationService->markAsRead($user, $notification);

            return response()->json([
                'status' => 'success',
                'message' => 'تم تحديد الإشعار كمقروء.',
                'data' => [
                    'notification' => $this->formatNotification($updated),
                    'unread_count' => $this->notificationService->getUnreadCount($user),
                ],
            ]);
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }
    }

    /**
     * POST /api/v1/notifications/read-all
     */
    public function markAllRead(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $updatedCount = $this->notificationService->markAllAsRead($user);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديد جميع الإشعارات كمقروءة.',
            'data' => [
                'updated_count' => $updatedCount,
                'unread_count' => 0,
            ],
        ]);
    }

    /**
     * DELETE /api/v1/notifications/{notification}
     */
    public function destroy(Request $request, NotificationRecord $notification): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        try {
            $this->notificationService->deleteNotification($user, $notification);

            return response()->json([
                'status' => 'success',
                'message' => 'تم حذف الإشعار من مركز الإشعارات.',
                'data' => [
                    'unread_count' => $this->notificationService->getUnreadCount($user),
                ],
            ]);
        } catch (ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }
    }

    private function formatNotification(NotificationRecord $n): array
    {
        return [
            'id' => $n->id,
            'event_id' => $n->event_id,
            'event_type' => $n->event_type,
            'title_ar' => $n->title_ar,
            'body_ar' => $n->body_ar,
            'reference_type' => $n->reference_type,
            'reference_id' => $n->reference_id,
            'action_route' => $n->action_route ?? NotificationRecord::ROUTE_NOTIFICATION_CENTER,
            'routing_metadata' => $n->routing_metadata ?? [],
            'is_read' => (bool) $n->is_read,
            'read_at' => $n->read_at?->toIso8601String(),
            'created_at' => $n->created_at?->toIso8601String(),
        ];
    }
}
