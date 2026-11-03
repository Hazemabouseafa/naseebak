<?php

namespace App\Services\Notification;

use App\Models\DeviceToken;
use App\Models\NotificationDeliveryAttempt;
use App\Models\NotificationRecord;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

class FcmNotificationService
{
    private const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
    private const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    /**
     * Allowlisted routing metadata keys permitted inside FCM HTTP v1 `data` map.
     * Sensitive matrimonial profile fields or private message contents are strictly forbidden.
     */
    private const ALLOWED_DATA_KEYS = [
        'event_id',
        'notification_id',
        'event_type',
        'action_route',
        'reference_type',
        'reference_id',
        'conversation_id',
        'request_id',
        'tab',
    ];

    /**
     * Sends a privacy-safe notification record to all active valid devices of the recipient
     * via the official Firebase Cloud Messaging HTTP v1 API.
     *
     * Note: An accepted FCM HTTP v1 response (`submitted_to_fcm`) indicates that Google's push
     * relay accepted the request; it does NOT guarantee that the notification was displayed or read.
     *
     * @return array{
     *   status: string,
     *   submitted_count: int,
     *   rejected_count: int,
     *   transient_failure_count: int,
     *   should_retry: bool,
     *   last_error_code: ?string
     * }
     */
    public function sendNotificationToUserDevices(NotificationRecord $notification, int $attemptNumber = 1): array
    {
        $user = $notification->user;
        if (!$user || $user->account_status !== 'active') {
            $notification->update([
                'fcm_delivery_status' => NotificationRecord::DELIVERY_REJECTED_BY_FCM,
                'fcm_error_code' => 'RECIPIENT_INACTIVE',
            ]);

            return [
                'status' => NotificationRecord::DELIVERY_REJECTED_BY_FCM,
                'submitted_count' => 0,
                'rejected_count' => 1,
                'transient_failure_count' => 0,
                'should_retry' => false,
                'last_error_code' => 'RECIPIENT_INACTIVE',
            ];
        }

        $devices = DeviceToken::where('user_id', $user->id)
            ->where('is_valid', true)
            ->get();

        if ($devices->isEmpty()) {
            $notification->update([
                'fcm_delivery_status' => NotificationRecord::DELIVERY_NO_ACTIVE_DEVICES,
                'last_delivery_attempt_at' => now(),
            ]);

            return [
                'status' => NotificationRecord::DELIVERY_NO_ACTIVE_DEVICES,
                'submitted_count' => 0,
                'rejected_count' => 0,
                'transient_failure_count' => 0,
                'should_retry' => false,
                'last_error_code' => null,
            ];
        }

        $projectId = (string) config('naseebak.fcm.project_id', '');
        if ($projectId === '') {
            $notification->update([
                'fcm_delivery_status' => NotificationRecord::DELIVERY_FAILED_TRANSIENT,
                'fcm_error_code' => 'FCM_NOT_CONFIGURED',
                'last_delivery_attempt_at' => now(),
            ]);

            return [
                'status' => NotificationRecord::DELIVERY_FAILED_TRANSIENT,
                'submitted_count' => 0,
                'rejected_count' => 0,
                'transient_failure_count' => $devices->count(),
                'should_retry' => false,
                'last_error_code' => 'FCM_NOT_CONFIGURED',
            ];
        }

        try {
            $accessToken = $this->getAccessToken();
        } catch (Throwable $e) {
            Log::warning('FCM OAuth token acquisition failed', [
                'notification_id' => $notification->id,
                'error' => $e->getMessage(),
            ]);

            $notification->update([
                'fcm_delivery_status' => NotificationRecord::DELIVERY_FAILED_TRANSIENT,
                'fcm_error_code' => 'OAUTH_TOKEN_ERROR',
                'delivery_attempts' => $attemptNumber,
                'last_delivery_attempt_at' => now(),
            ]);

            return [
                'status' => NotificationRecord::DELIVERY_FAILED_TRANSIENT,
                'submitted_count' => 0,
                'rejected_count' => 0,
                'transient_failure_count' => $devices->count(),
                'should_retry' => true,
                'last_error_code' => 'OAUTH_TOKEN_ERROR',
            ];
        }

        $endpoint = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
        $submittedCount = 0;
        $rejectedCount = 0;
        $transientCount = 0;
        $lastErrorCode = null;

        foreach ($devices as $device) {
            // Skip if this specific device already succeeded for this notification on an earlier attempt
            $alreadySubmitted = NotificationDeliveryAttempt::where('notification_id', $notification->id)
                ->where('device_token_id', $device->id)
                ->where('status', NotificationRecord::DELIVERY_SUBMITTED_TO_FCM)
                ->exists();

            if ($alreadySubmitted) {
                $submittedCount++;
                continue;
            }

            $payload = $this->buildHttpV1MessagePayload($notification, $device->fcm_token);

            try {
                $response = Http::withToken($accessToken)
                    ->timeout(10)
                    ->acceptJson()
                    ->withBody(
                        (string) json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                        'application/json'
                    )
                    ->post($endpoint);

                $device->update(['last_delivery_attempt_at' => now()]);
                $httpStatus = $response->status();

                if ($response->successful()) {
                    $submittedCount++;
                    $fcmMessageName = (string) ($response->json('name') ?? '');

                    NotificationDeliveryAttempt::create([
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'attempt_number' => $attemptNumber,
                        'status' => NotificationRecord::DELIVERY_SUBMITTED_TO_FCM,
                        'http_status' => $httpStatus,
                        'fcm_message_id' => $fcmMessageName !== '' ? $fcmMessageName : null,
                        'attempted_at' => now(),
                    ]);
                    continue;
                }

                $responseJson = $response->json() ?? [];
                $errorCode = $this->extractFcmErrorCode($responseJson, $httpStatus);
                $lastErrorCode = $errorCode;

                if ($this->isConfirmedInvalidTokenError($errorCode, $httpStatus, $responseJson)) {
                    $rejectedCount++;
                    $invalidationReason = $errorCode === 'INVALID_ARGUMENT'
                        ? 'INVALID_REGISTRATION_TOKEN'
                        : $errorCode;

                    $device->update([
                        'is_valid' => false,
                        'invalidated_reason' => $invalidationReason,
                        'invalidated_at' => now(),
                    ]);

                    NotificationDeliveryAttempt::create([
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'attempt_number' => $attemptNumber,
                        'status' => 'invalid_token_removed',
                        'http_status' => $httpStatus,
                        'fcm_error_code' => $invalidationReason,
                        'attempted_at' => now(),
                    ]);
                } elseif ($errorCode === 'SENDER_ID_MISMATCH') {
                    // Preserve the device token: SENDER_ID_MISMATCH often indicates a server-side
                    // Firebase project / service-account configuration mismatch.
                    $rejectedCount++;
                    Log::error('FCM SENDER_ID_MISMATCH detected — preserving device token and flagging configuration issue', [
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'project_id' => $projectId,
                        'http_status' => $httpStatus,
                    ]);

                    NotificationDeliveryAttempt::create([
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'attempt_number' => $attemptNumber,
                        'status' => NotificationRecord::DELIVERY_REJECTED_BY_FCM,
                        'http_status' => $httpStatus,
                        'fcm_error_code' => 'SENDER_ID_MISMATCH',
                        'attempted_at' => now(),
                    ]);
                } elseif ($errorCode === 'INVALID_ARGUMENT') {
                    // Payload or uncertain argument error: preserve the device token, record the error,
                    // log the payload/configuration problem, and do NOT retry an identical invalid payload.
                    $rejectedCount++;
                    $lastErrorCode = 'INVALID_PAYLOAD_ARGUMENT';
                    Log::warning('FCM INVALID_ARGUMENT (non-token payload/config error) — preserving device token', [
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'http_status' => $httpStatus,
                        'fcm_message' => $responseJson['error']['message'] ?? null,
                    ]);

                    NotificationDeliveryAttempt::create([
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'attempt_number' => $attemptNumber,
                        'status' => NotificationRecord::DELIVERY_REJECTED_BY_FCM,
                        'http_status' => $httpStatus,
                        'fcm_error_code' => 'INVALID_PAYLOAD_ARGUMENT',
                        'attempted_at' => now(),
                    ]);
                } elseif ($this->isTransientFcmError($errorCode, $httpStatus)) {
                    $transientCount++;

                    NotificationDeliveryAttempt::create([
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'attempt_number' => $attemptNumber,
                        'status' => NotificationRecord::DELIVERY_FAILED_TRANSIENT,
                        'http_status' => $httpStatus,
                        'fcm_error_code' => $errorCode,
                        'attempted_at' => now(),
                    ]);
                } else {
                    $rejectedCount++;

                    NotificationDeliveryAttempt::create([
                        'notification_id' => $notification->id,
                        'device_token_id' => $device->id,
                        'attempt_number' => $attemptNumber,
                        'status' => NotificationRecord::DELIVERY_REJECTED_BY_FCM,
                        'http_status' => $httpStatus,
                        'fcm_error_code' => $errorCode,
                        'attempted_at' => now(),
                    ]);
                }
            } catch (Throwable $e) {
                $transientCount++;
                $lastErrorCode = 'NETWORK_EXCEPTION';

                NotificationDeliveryAttempt::create([
                    'notification_id' => $notification->id,
                    'device_token_id' => $device->id,
                    'attempt_number' => $attemptNumber,
                    'status' => NotificationRecord::DELIVERY_FAILED_TRANSIENT,
                    'http_status' => null,
                    'fcm_error_code' => 'NETWORK_EXCEPTION',
                    'attempted_at' => now(),
                ]);
            }
        }

        $finalStatus = match (true) {
            $submittedCount > 0 => NotificationRecord::DELIVERY_SUBMITTED_TO_FCM,
            $transientCount > 0 => NotificationRecord::DELIVERY_FAILED_TRANSIENT,
            default => NotificationRecord::DELIVERY_REJECTED_BY_FCM,
        };

        $notification->update([
            'fcm_delivery_status' => $finalStatus,
            'delivery_attempts' => $attemptNumber,
            'last_delivery_attempt_at' => now(),
            'fcm_submitted_at' => $submittedCount > 0 ? ($notification->fcm_submitted_at ?? now()) : null,
            'fcm_error_code' => $submittedCount > 0 ? null : $lastErrorCode,
        ]);

        return [
            'status' => $finalStatus,
            'submitted_count' => $submittedCount,
            'rejected_count' => $rejectedCount,
            'transient_failure_count' => $transientCount,
            'should_retry' => $submittedCount === 0 && $transientCount > 0,
            'last_error_code' => $lastErrorCode,
        ];
    }

    /**
     * Builds a privacy-safe FCM HTTP v1 message payload.
     * Never includes private chat message contents, emails, phone numbers, or sensitive profile data.
     */
    public function buildHttpV1MessagePayload(NotificationRecord $notification, string $fcmToken): array
    {
        $channelId = $this->resolveAndroidChannelId($notification->event_type);
        $isAnnouncement = $notification->event_type === NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT;

        $rawRouting = is_array($notification->routing_metadata) ? $notification->routing_metadata : [];
        $safeData = [
            'event_id' => (string) $notification->event_id,
            'notification_id' => (string) $notification->id,
            'event_type' => (string) $notification->event_type,
            'action_route' => (string) ($notification->action_route ?? NotificationRecord::ROUTE_NOTIFICATION_CENTER),
        ];

        if ($notification->reference_type !== null) {
            $safeData['reference_type'] = (string) $notification->reference_type;
        }
        if ($notification->reference_id !== null) {
            $safeData['reference_id'] = (string) $notification->reference_id;
        }

        foreach ($rawRouting as $key => $value) {
            if (in_array((string) $key, self::ALLOWED_DATA_KEYS, true) && is_scalar($value)) {
                $safeData[(string) $key] = (string) $value;
            }
        }

        return [
            'message' => [
                'token' => $fcmToken,
                'notification' => [
                    'title' => $notification->title_ar,
                    'body' => $notification->body_ar,
                ],
                'data' => $safeData,
                'android' => [
                    // Ordinary announcements use NORMAL priority; transactional matchmaking/messages/subscriptions use HIGH
                    'priority' => $isAnnouncement ? 'NORMAL' : 'HIGH',
                    'notification' => [
                        'channel_id' => $channelId,
                        'visibility' => 'PRIVATE',
                        'sound' => 'default',
                    ],
                ],
            ],
        ];
    }

    public function resolveAndroidChannelId(string $eventType): string
    {
        return match ($eventType) {
            NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            NotificationRecord::TYPE_ACCEPTED_MATCHMAKING_REQUEST,
            NotificationRecord::TYPE_REJECTED_MATCHMAKING_REQUEST => (string) config('naseebak.fcm.channels.matchmaking', 'matchmaking_requests'),
            NotificationRecord::TYPE_NEW_PRIVATE_MESSAGE => (string) config('naseebak.fcm.channels.messages', 'private_messages'),
            NotificationRecord::TYPE_SUBSCRIPTION_ACTIVATED,
            NotificationRecord::TYPE_SUBSCRIPTION_EXPIRING_SOON,
            NotificationRecord::TYPE_SUBSCRIPTION_EXPIRED => (string) config('naseebak.fcm.channels.subscriptions', 'subscription_updates'),
            default => (string) config('naseebak.fcm.channels.announcements', 'announcements'),
        };
    }

    /**
     * Acquires a short-lived Google OAuth 2.0 access token for FCM HTTP v1 using the service account JSON.
     */
    protected function getAccessToken(): string
    {
        $cached = Cache::get('naseebak_fcm_oauth_access_token');
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }

        $credentialsPath = (string) config('naseebak.fcm.service_account_json', '');
        if ($credentialsPath === '' || !is_file($credentialsPath)) {
            throw new RuntimeException('ملف حساب الخدمة الخاص بـ Firebase Cloud Messaging غير متوفر.');
        }

        $json = json_decode((string) file_get_contents($credentialsPath), true);
        if (!is_array($json) || empty($json['client_email']) || empty($json['private_key'])) {
            throw new RuntimeException('بيانات حساب الخدمة لـ FCM غير صالحة.');
        }

        $now = time();
        $header = $this->base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claimSet = $this->base64UrlEncode(json_encode([
            'iss' => $json['client_email'],
            'scope' => self::FCM_SCOPE,
            'aud' => $json['token_uri'] ?? self::OAUTH_TOKEN_URL,
            'iat' => $now,
            'exp' => $now + 3600,
        ]));

        $unsignedJwt = "{$header}.{$claimSet}";
        $signature = '';
        if (!openssl_sign($unsignedJwt, $signature, $json['private_key'], OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('تعذر توقيع طلب OAuth لخدمة FCM.');
        }

        $assertion = "{$unsignedJwt}." . $this->base64UrlEncode($signature);

        $response = Http::asForm()
            ->timeout(10)
            ->post($json['token_uri'] ?? self::OAUTH_TOKEN_URL, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]);

        if (!$response->successful()) {
            throw new RuntimeException('فشل الحصول على رمز الوصول من Google OAuth لخدمة FCM.');
        }

        $token = (string) ($response->json('access_token') ?? '');
        if ($token === '') {
            throw new RuntimeException('رمز الوصول المستلم من Google OAuth فارغ.');
        }

        Cache::put('naseebak_fcm_oauth_access_token', $token, now()->addMinutes(50));

        return $token;
    }

    private function extractFcmErrorCode(array $responseBody, int $httpStatus): string
    {
        $details = $responseBody['error']['details'] ?? [];
        if (is_array($details)) {
            foreach ($details as $detail) {
                if (is_array($detail) && !empty($detail['errorCode'])) {
                    return (string) $detail['errorCode'];
                }
            }
        }

        $status = $responseBody['error']['status'] ?? null;
        if (is_string($status) && $status !== '') {
            return $status;
        }

        return "HTTP_{$httpStatus}";
    }

    /**
     * Determines whether the FCM HTTP v1 error specifically proves that the registration token itself is invalid.
     *
     * - UNREGISTERED (404): Token is confirmed unregistered.
     * - INVALID_ARGUMENT (400): Only invalidates the token if BadRequest.fieldViolations explicitly targets
     *   `message.token` or the error message explicitly confirms the registration token is invalid.
     *   Payload-level INVALID_ARGUMENT or SENDER_ID_MISMATCH errors do NOT invalidate the token.
     */
    private function isConfirmedInvalidTokenError(string $errorCode, int $httpStatus, array $responseBody = []): bool
    {
        if ($errorCode === 'UNREGISTERED' || ($httpStatus === 404 && $errorCode !== 'NOT_FOUND_PROJECT')) {
            return true;
        }

        if ($errorCode === 'INVALID_ARGUMENT') {
            return $this->doesInvalidArgumentSpecificallyTargetToken($responseBody);
        }

        return false;
    }

    private function doesInvalidArgumentSpecificallyTargetToken(array $responseBody): bool
    {
        $errorMessage = strtolower((string) ($responseBody['error']['message'] ?? ''));
        if (str_contains($errorMessage, 'registration token is not a valid fcm registration token')) {
            return true;
        }

        $details = $responseBody['error']['details'] ?? [];
        if (!is_array($details)) {
            return false;
        }

        foreach ($details as $detail) {
            if (!is_array($detail)) {
                continue;
            }
            $violations = $detail['fieldViolations'] ?? [];
            if (!is_array($violations)) {
                continue;
            }
            foreach ($violations as $violation) {
                $field = strtolower((string) ($violation['field'] ?? ''));
                $description = strtolower((string) ($violation['description'] ?? ''));
                if ($field === 'message.token' || str_contains($description, 'registration token')) {
                    return true;
                }
            }
        }

        return false;
    }

    private function isTransientFcmError(string $errorCode, int $httpStatus): bool
    {
        if (in_array($errorCode, ['UNAVAILABLE', 'INTERNAL', 'QUOTA_EXCEEDED', 'RESOURCE_EXHAUSTED'], true)) {
            return true;
        }

        return $httpStatus === 429 || $httpStatus >= 500;
    }

    private function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
