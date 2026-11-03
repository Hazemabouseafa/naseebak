<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Notification\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationPreferenceController extends Controller
{
    public function __construct(
        private readonly NotificationService $notificationService
    ) {}

    /**
     * GET /api/v1/notification-preferences
     */
    public function show(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $prefs = $this->notificationService->getOrCreatePreferences($user);

        return response()->json([
            'status' => 'success',
            'data' => [
                'preferences' => [
                    'matchmaking_requests_enabled' => (bool) $prefs->matchmaking_requests_enabled,
                    'messages_enabled' => (bool) $prefs->messages_enabled,
                    'subscriptions_enabled' => (bool) $prefs->subscriptions_enabled,
                    'announcements_enabled' => (bool) $prefs->announcements_enabled,
                ],
            ],
        ]);
    }

    /**
     * PATCH /api/v1/notification-preferences
     */
    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'matchmaking_requests_enabled' => ['sometimes', 'boolean'],
            'messages_enabled' => ['sometimes', 'boolean'],
            'subscriptions_enabled' => ['sometimes', 'boolean'],
            'announcements_enabled' => ['sometimes', 'boolean'],
        ]);

        /** @var User $user */
        $user = $request->user();
        $prefs = $this->notificationService->updatePreferences($user, $validated);

        return response()->json([
            'status' => 'success',
            'message' => 'تم حفظ إعدادات الإشعارات بنجاح.',
            'data' => [
                'preferences' => [
                    'matchmaking_requests_enabled' => (bool) $prefs->matchmaking_requests_enabled,
                    'messages_enabled' => (bool) $prefs->messages_enabled,
                    'subscriptions_enabled' => (bool) $prefs->subscriptions_enabled,
                    'announcements_enabled' => (bool) $prefs->announcements_enabled,
                ],
            ],
        ]);
    }
}
