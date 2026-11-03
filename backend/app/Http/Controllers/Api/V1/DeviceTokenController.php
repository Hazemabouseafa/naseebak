<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiBusinessException;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Notification\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function __construct(
        private readonly NotificationService $notificationService
    ) {}

    /**
     * POST /api/v1/devices/register
     *
     * Registers or refreshes an FCM registration token for the authenticated user.
     * Never trusts arbitrary user_id parameters from the client.
     */
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'fcm_token' => ['required', 'string', 'min:20', 'max:512'],
            'device_platform' => ['nullable', 'string', 'in:android,ios,web'],
            'device_model' => ['nullable', 'string', 'max:120'],
            'app_version' => ['nullable', 'string', 'max:32'],
            'os_version' => ['nullable', 'string', 'max:32'],
        ], [
            'fcm_token.required' => 'رمز جهاز الإشعارات مطلوب.',
            'fcm_token.min' => 'رمز جهاز الإشعارات غير صالح.',
        ]);

        /** @var User $user */
        $user = $request->user();

        try {
            $tokenRecord = $this->notificationService->registerDeviceToken(
                user: $user,
                rawFcmToken: $validated['fcm_token'],
                platform: $validated['device_platform'] ?? 'android',
                deviceModel: $validated['device_model'] ?? null,
                appVersion: $validated['app_version'] ?? null,
                osVersion: $validated['os_version'] ?? null
            );

            return response()->json([
                'status' => 'success',
                'message' => 'تم تسجيل جهاز الإشعارات بنجاح.',
                'data' => [
                    'device' => [
                        'id' => $tokenRecord->id,
                        'user_id' => $tokenRecord->user_id,
                        'token_fingerprint' => $tokenRecord->token_fingerprint,
                        'device_platform' => $tokenRecord->device_platform,
                        'device_model' => $tokenRecord->device_model,
                        'is_valid' => (bool) $tokenRecord->is_valid,
                        'last_registered_at' => $tokenRecord->last_registered_at?->toIso8601String(),
                    ],
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
     * DELETE /api/v1/devices/unregister
     *
     * Unregisters the current device token (or all tokens for the authenticated user on logout).
     */
    public function unregister(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'fcm_token' => ['nullable', 'string', 'max:512'],
        ]);

        /** @var User $user */
        $user = $request->user();

        $removedCount = $this->notificationService->unregisterDeviceToken(
            user: $user,
            rawFcmToken: $validated['fcm_token'] ?? null
        );

        return response()->json([
            'status' => 'success',
            'message' => 'تم إلغاء تسجيل جهاز الإشعارات بنجاح.',
            'data' => [
                'removed_count' => $removedCount,
            ],
        ]);
    }
}
