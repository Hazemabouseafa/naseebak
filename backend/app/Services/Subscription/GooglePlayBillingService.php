<?php

namespace App\Services\Subscription;

use App\Models\PaymentWebhookEvent;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Carbon\Carbon;
use DomainException;
use Google\Client as GoogleClient;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

class GooglePlayBillingService
{
    public const API_BASE_URL = 'https://androidpublisher.googleapis.com/androidpublisher/v3';

    /**
     * Google Play RTDN subscriptionNotification.notificationType constants:
     * 1  = SUBSCRIPTION_RECOVERED
     * 2  = SUBSCRIPTION_RENEWED
     * 3  = SUBSCRIPTION_CANCELED
     * 4  = SUBSCRIPTION_PURCHASED
     * 5  = SUBSCRIPTION_ON_HOLD
     * 6  = SUBSCRIPTION_IN_GRACE_PERIOD
     * 12 = SUBSCRIPTION_REVOKED
     * 13 = SUBSCRIPTION_EXPIRED
     */
    public const RTDN_SUBSCRIPTION_REVOKED = 12;

    public function __construct(
        private readonly SubscriptionEntitlementService $entitlementService
    ) {}

    /**
     * Verifies a Google Cloud Pub/Sub Push OIDC JWT Bearer token.
     *
     * Enforces:
     * 1. Non-empty Bearer JWT token with RS256 cryptographic signature verification.
     * 2. Issuer (`iss`) in `['https://accounts.google.com', 'accounts.google.com']`.
     * 3. Audience (`aud`) strictly matching `naseebak.google_play.rtdn_oidc_audience`.
     * 4. Authorized service account identity (`email` matching `naseebak.google_play.rtdn_service_account_email`
     *    and `email_verified === true`).
     * 5. Unexpired token (`exp > time()`).
     *
     * @throws AuthenticationException
     */
    public function verifyPubSubOidcPushToken(?string $bearerToken): array
    {
        $token = trim((string) $bearerToken);
        if ($token === '') {
            throw new AuthenticationException('رمز مصادقة Google Cloud Pub/Sub OIDC مفقود.');
        }

        $expectedAudience = trim((string) config('naseebak.google_play.rtdn_oidc_audience', ''));
        $expectedEmail = strtolower(trim((string) config('naseebak.google_play.rtdn_service_account_email', '')));
        $allowedIssuers = (array) config('naseebak.google_play.rtdn_allowed_issuers', [
            'https://accounts.google.com',
            'accounts.google.com',
        ]);

        // Fail closed if server OIDC configuration is missing
        if ($expectedAudience === '' || $expectedEmail === '') {
            throw new AuthenticationException('إعدادات التحقق من هوية Google Cloud Pub/Sub OIDC غير مكتملة على الخادم.');
        }

        $claims = $this->decodeAndVerifyOidcJwtSignature($token, $expectedAudience);

        $issuer = (string) ($claims['iss'] ?? '');
        if (!in_array($issuer, $allowedIssuers, true)) {
            throw new AuthenticationException('مصدر رمز مصادقة RTDN OIDC (iss) غير موثوق.');
        }

        $audience = (string) ($claims['aud'] ?? '');
        if ($audience === '' || !hash_equals($expectedAudience, $audience)) {
            throw new AuthenticationException('جمهور رمز مصادقة RTDN OIDC (aud) غير مطابق.');
        }

        $exp = (int) ($claims['exp'] ?? 0);
        if ($exp <= time()) {
            throw new AuthenticationException('انتهت صلاحية رمز مصادقة RTDN OIDC.');
        }

        $iat = (int) ($claims['iat'] ?? 0);
        if ($iat > (time() + 60)) {
            throw new AuthenticationException('توقيت إصدار رمز مصادقة RTDN OIDC غير صالح.');
        }

        $email = strtolower(trim((string) ($claims['email'] ?? '')));
        $emailVerified = ($claims['email_verified'] ?? false) === true;
        $sub = trim((string) ($claims['sub'] ?? ''));

        if ($email === '' || !$emailVerified || $sub === '' || !hash_equals($expectedEmail, $email)) {
            throw new AuthenticationException('حساب الخدمة المرسل لإشعار RTDN غير مصرح له.');
        }

        return [
            'sub' => $sub,
            'email' => $email,
            'aud' => $audience,
            'iss' => $issuer,
        ];
    }

    /**
     * Verifies the RS256 cryptographic signature of the Google OIDC JWT.
     * Uses pinned public key PEM when configured (`naseebak.google_play.rtdn_oidc_public_key_pem`),
     * or Google's official OIDC certificate verification via `Google\Client::verifyIdToken`.
     *
     * @throws AuthenticationException
     */
    protected function decodeAndVerifyOidcJwtSignature(string $jwt, string $expectedAudience): array
    {
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) {
            throw new AuthenticationException('بنية رمز JWT الخاصة بـ RTDN غير صالحة.');
        }

        [$encodedHeader, $encodedPayload, $encodedSignature] = $parts;

        $headerJson = self::base64UrlDecode($encodedHeader);
        $payloadJson = self::base64UrlDecode($encodedPayload);
        $signatureBytes = self::base64UrlDecode($encodedSignature);

        $header = is_string($headerJson) ? json_decode($headerJson, true) : null;
        $payload = is_string($payloadJson) ? json_decode($payloadJson, true) : null;

        if (!is_array($header) || !is_array($payload) || !is_string($signatureBytes) || $signatureBytes === '') {
            throw new AuthenticationException('تعذر فك ترميز رمز JWT الخاص بـ RTDN.');
        }

        if (($header['alg'] ?? '') !== 'RS256') {
            throw new AuthenticationException('خوارزمية توقيع رمز RTDN OIDC غير مدعومة (يجب أن تكون RS256).');
        }

        $publicKeyPem = trim((string) config('naseebak.google_play.rtdn_oidc_public_key_pem', ''));
        if ($publicKeyPem !== '') {
            $signingInput = "{$encodedHeader}.{$encodedPayload}";
            $verified = @openssl_verify($signingInput, $signatureBytes, $publicKeyPem, OPENSSL_ALGO_SHA256);
            if ($verified !== 1) {
                throw new AuthenticationException('التوقيع الرقمي لرمز RTDN OIDC غير صالح.');
            }

            return $payload;
        }

        try {
            $client = new GoogleClient(['client_id' => $expectedAudience]);
            $verifiedPayload = $client->verifyIdToken($jwt);
        } catch (Throwable $e) {
            Log::warning('RTDN OIDC token verification failed', [
                'error_class' => get_class($e),
            ]);
            throw new AuthenticationException('فشل التحقق من التوقيع الرقمي لرمز RTDN OIDC.');
        }

        if (!is_array($verifiedPayload)) {
            throw new AuthenticationException('رمز RTDN OIDC غير صالح أو منتهي الصلاحية.');
        }

        return $verifiedPayload;
    }

    private static function base64UrlDecode(string $input): string|false
    {
        $remainder = strlen($input) % 4;
        if ($remainder > 0) {
            $input .= str_repeat('=', 4 - $remainder);
        }
        return base64_decode(strtr($input, '-_', '+/'), true);
    }

    /**
     * Verifies a Google Play subscription purchase token using the official
     * Google Play Developer API (`purchases.subscriptionsv2.get`), acknowledges
     * verified unacknowledged purchases, and updates the member's entitlement.
     *
     * SECURITY RULE: Never log raw purchase tokens or service-account secrets.
     */
    public function verifyAndSyncPurchaseForUser(
        User $user,
        string $productId,
        string $purchaseToken,
        ?string $packageName = null,
        array $rtdnContext = []
    ): Subscription {
        $expectedPackage = (string) config('naseebak.google_play.package_name', 'com.naseebak.app');
        if ($packageName !== null && $packageName !== '' && $packageName !== $expectedPackage) {
            throw new DomainException('معرف حزمة التطبيق (packageName) غير مطابق للتطبيق الرسمي.');
        }

        $plan = SubscriptionPlan::where('google_play_product_id', $productId)
            ->where('is_active', true)
            ->first();

        if (!$plan) {
            throw new DomainException('معرف باقة الاشتراك في Google Play غير معروف أو غير مفعل.');
        }

        $trimmedToken = trim($purchaseToken);
        if (strlen($trimmedToken) < 12) {
            throw new DomainException('رمز الشراء المستلم من Google Play غير صالح.');
        }

        // Prevent replay across different accounts before even calling Google Play API if already bound
        $tokenHash = hash('sha256', $trimmedToken);
        $existingBoundSub = Subscription::where('google_play_purchase_token_hash', $tokenHash)
            ->orWhere('google_play_purchase_token', $trimmedToken)
            ->first();

        if ($existingBoundSub !== null && (int) $existingBoundSub->user_id !== (int) $user->id) {
            throw new DomainException('رمز الشراء هذا مرتبط بحساب عضو آخر ولا يمكن إعادة استخدامه.');
        }

        // Always query Google Play Developer API subscriptionsv2 for authoritative subscription state
        $v2Response = $this->fetchSubscriptionV2FromGoogle($expectedPackage, $trimmedToken);
        $parsedState = $this->parseSubscriptionsV2Payload($v2Response, $productId, $user->id, $rtdnContext);

        // Acknowledge verified active/entitled purchase if not yet acknowledged
        if (
            in_array($parsedState['mapped_status'], [Subscription::STATUS_ACTIVE, Subscription::STATUS_IN_GRACE_PERIOD], true)
            && ($parsedState['acknowledgement_state'] ?? '') === 'ACKNOWLEDGEMENT_STATE_PENDING'
        ) {
            $this->acknowledgeSubscriptionPurchase($expectedPackage, $productId, $trimmedToken);
            $parsedState['acknowledgement_state'] = 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';
        }

        return $this->entitlementService->syncVerifiedGooglePlayPurchase(
            user: $user,
            plan: $plan,
            purchaseToken: $trimmedToken,
            verifiedGooglePlayState: $parsedState
        );
    }

    /**
     * Processes a Google Play Real-Time Developer Notification (RTDN) delivered via Google Cloud Pub/Sub.
     *
     * Rules:
     * - Deduplicates using Pub/Sub `message.messageId`.
     * - Never activates subscriptions based only on RTDN payloads.
     * - Always re-queries Google Play Developer API (`subscriptionsv2.get`) to establish authoritative state.
     */
    public function processRtdnPubSubPush(array $pubSubEnvelope): array
    {
        $message = $pubSubEnvelope['message'] ?? null;
        if (!is_array($message) || empty($message['messageId']) || empty($message['data'])) {
            throw new DomainException('حمولة إشعار Google Play RTDN غير صالحة.');
        }

        $messageId = (string) $message['messageId'];

        // Idempotent deduplication by Pub/Sub messageId
        $existingEvent = PaymentWebhookEvent::where('provider', Subscription::CHANNEL_GOOGLE_PLAY)
            ->where('provider_event_id', $messageId)
            ->first();

        if ($existingEvent !== null) {
            return [
                'status' => 'ignored_duplicate',
                'event_id' => $messageId,
                'subscription_id' => $existingEvent->subscription_id,
            ];
        }

        $decodedJson = base64_decode((string) $message['data'], true);
        $rtdnPayload = is_string($decodedJson) ? json_decode($decodedJson, true) : null;

        if (!is_array($rtdnPayload)) {
            throw new DomainException('تعذر فك ترميز بيانات إشعار RTDN.');
        }

        $packageName = (string) ($rtdnPayload['packageName'] ?? '');
        $expectedPackage = (string) config('naseebak.google_play.package_name', 'com.naseebak.app');

        if ($packageName !== $expectedPackage) {
            throw new DomainException('حزمة التطبيق في إشعار RTDN غير مطابقة.');
        }

        // Ignore testNotification safely while recording event
        if (isset($rtdnPayload['testNotification'])) {
            PaymentWebhookEvent::create([
                'provider' => Subscription::CHANNEL_GOOGLE_PLAY,
                'provider_event_id' => $messageId,
                'event_type' => 'TEST_NOTIFICATION',
                'processing_status' => 'processed',
                'sanitized_payload' => ['version' => $rtdnPayload['version'] ?? '1.0'],
                'processed_at' => now(),
            ]);

            return ['status' => 'processed_test', 'event_id' => $messageId];
        }

        $subNotification = $rtdnPayload['subscriptionNotification'] ?? null;
        $voidedNotification = $rtdnPayload['voidedPurchaseNotification'] ?? null;

        $purchaseToken = (string) ($subNotification['purchaseToken'] ?? $voidedNotification['purchaseToken'] ?? '');
        $subscriptionId = (string) ($subNotification['subscriptionId'] ?? config('naseebak.google_play.monthly_subscription_id'));
        $notificationType = (int) ($subNotification['notificationType'] ?? 0);

        if ($purchaseToken === '') {
            throw new DomainException('إشعار RTDN لا يحتوي على رمز شراء للتحقق.');
        }

        $tokenHash = hash('sha256', trim($purchaseToken));
        $subscription = Subscription::where('google_play_purchase_token_hash', $tokenHash)
            ->orWhere('google_play_purchase_token', trim($purchaseToken))
            ->first();

        if (!$subscription || !$subscription->user) {
            throw new DomainException('لم يتم العثور على اشتراك داخلي مرتبط برمز الشراء في إشعار RTDN.');
        }

        $isRevokedOrVoided = $voidedNotification !== null
            || $notificationType === self::RTDN_SUBSCRIPTION_REVOKED;

        // Re-query Google Play Developer API subscriptionsv2 to obtain authoritative state
        $updatedSubscription = $this->verifyAndSyncPurchaseForUser(
            user: $subscription->user,
            productId: $subscriptionId ?: $subscription->plan?->google_play_product_id,
            purchaseToken: $purchaseToken,
            packageName: $packageName,
            rtdnContext: [
                'notification_type' => $notificationType,
                'is_revoked_or_voided' => $isRevokedOrVoided,
            ]
        );

        PaymentWebhookEvent::create([
            'provider' => Subscription::CHANNEL_GOOGLE_PLAY,
            'provider_event_id' => $messageId,
            'event_type' => $voidedNotification ? 'VOIDED_PURCHASE' : "SUBSCRIPTION_NOTIFICATION_{$notificationType}",
            'subscription_id' => $updatedSubscription->id,
            'processing_status' => 'processed',
            'sanitized_payload' => [
                'notification_type' => $notificationType,
                'subscription_id' => $subscriptionId,
                'resulting_status' => $updatedSubscription->status,
            ],
            'processed_at' => now(),
        ]);

        return [
            'status' => 'processed',
            'event_id' => $messageId,
            'subscription_id' => $updatedSubscription->id,
            'resulting_status' => $updatedSubscription->status,
        ];
    }

    /**
     * Calls `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptionsv2/tokens/{token}`
     */
    protected function fetchSubscriptionV2FromGoogle(string $packageName, string $purchaseToken): array
    {
        $accessToken = $this->acquireGooglePublisherAccessToken();
        $url = self::API_BASE_URL . "/applications/{$packageName}/purchases/subscriptionsv2/tokens/{$purchaseToken}";

        $response = Http::withToken($accessToken)
            ->acceptJson()
            ->timeout(15)
            ->get($url);

        if ($response->status() === 404 || $response->status() === 400 || $response->status() === 401) {
            throw new DomainException('تعذر التحقق من صلاحية عملية الشراء لدى متجر Google Play.');
        }

        if (!$response->successful()) {
            Log::error('Google Play subscriptionsv2 API error', [
                'http_status' => $response->status(),
            ]);
            throw new RuntimeException('خدمة التحقق من متجر Google Play غير متاحة مؤقتاً.');
        }

        return $response->json() ?? [];
    }

    /**
     * Acknowledges a verified subscription purchase via Google Play Developer API v3.
     */
    protected function acknowledgeSubscriptionPurchase(string $packageName, string $productId, string $purchaseToken): void
    {
        $accessToken = $this->acquireGooglePublisherAccessToken();
        $url = self::API_BASE_URL . "/applications/{$packageName}/purchases/subscriptions/{$productId}/tokens/{$purchaseToken}:acknowledge";

        Http::withToken($accessToken)
            ->acceptJson()
            ->timeout(15)
            ->post($url, (object) []);
    }

    /**
     * Parses the official Google Play `SubscriptionPurchaseV2` response into canonical Naseebak state.
     *
     * Strictly requires `lineItems[0].expiryTime` from Google Play Developer API and never assumes 30 days.
     */
    public function parseSubscriptionsV2Payload(
        array $payload,
        string $expectedProductId,
        int $expectedUserId,
        array $rtdnContext = []
    ): array {
        $rawState = (string) ($payload['subscriptionState'] ?? '');
        $lineItems = $payload['lineItems'] ?? [];
        $firstItem = is_array($lineItems) && isset($lineItems[0]) ? $lineItems[0] : [];

        $actualProductId = (string) ($firstItem['productId'] ?? '');
        if ($actualProductId !== '' && $actualProductId !== $expectedProductId) {
            throw new DomainException('معرف المنتج المشترى من Google Play لا يطابق باقة الاشتراك المطلوبة.');
        }

        // Verify obfuscatedExternalAccountId if present in payload
        $externalAccountId = $payload['externalAccountIdentifiers']['obfuscatedExternalAccountId'] ?? null;
        if ($externalAccountId !== null && $externalAccountId !== '' && (string) $externalAccountId !== (string) $expectedUserId) {
            throw new DomainException('عملية الشراء هذه مسجلة لحساب مستخدم مختلف.');
        }

        $expiryTimeStr = trim((string) ($firstItem['expiryTime'] ?? ''));
        if ($expiryTimeStr === '') {
            throw new DomainException('استجابة Google Play لا تحتوي على تاريخ انتهاء الصلاحية الموثق (expiryTime).');
        }

        $endsAt = Carbon::parse($expiryTimeStr);
        $startsAt = isset($payload['startTime']) ? Carbon::parse((string) $payload['startTime']) : now();
        $autoRenewing = (bool) data_get($firstItem, 'autoRenewingPlan.autoRenewEnabled', false);

        $isRevokedSignal = ($rtdnContext['is_revoked_or_voided'] ?? false) === true
            || isset($payload['canceledStateContext']['developerInitiatedCancellation']);

        $mappedStatus = match ($rawState) {
            'SUBSCRIPTION_STATE_ACTIVE' => Subscription::STATUS_ACTIVE,
            'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' => Subscription::STATUS_IN_GRACE_PERIOD,
            'SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_PAUSED' => Subscription::STATUS_ON_HOLD,
            'SUBSCRIPTION_STATE_CANCELED' => $isRevokedSignal && $endsAt->lessThanOrEqualTo(now())
                ? Subscription::STATUS_REVOKED
                : ($endsAt->greaterThan(now())
                    ? Subscription::STATUS_CANCELLED
                    : Subscription::STATUS_EXPIRED),
            'SUBSCRIPTION_STATE_EXPIRED' => $isRevokedSignal
                ? Subscription::STATUS_REVOKED
                : Subscription::STATUS_EXPIRED,
            'SUBSCRIPTION_STATE_REVOKED' => Subscription::STATUS_REVOKED,
            'SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED' => Subscription::STATUS_PENDING,
            default => throw new DomainException('حالة الاشتراك المستلمة من Google Play غير مدعومة أو غير صالحة.'),
        };

        return [
            'product_id' => $actualProductId ?: $expectedProductId,
            'raw_subscription_state' => $rawState,
            'mapped_status' => $mappedStatus,
            'starts_at' => $startsAt->toIso8601String(),
            'ends_at' => $endsAt->toIso8601String(),
            'grace_period_ends_at' => $mappedStatus === Subscription::STATUS_IN_GRACE_PERIOD
                ? $endsAt->toIso8601String()
                : null,
            'auto_renewing' => $autoRenewing,
            'acknowledgement_state' => (string) ($payload['acknowledgementState'] ?? 'ACKNOWLEDGEMENT_STATE_UNSPECIFIED'),
            'external_subscription_id' => (string) ($payload['latestOrderId'] ?? ''),
        ];
    }

    /**
     * Acquires an OAuth2 Bearer token for `https://www.googleapis.com/auth/androidpublisher`
     * using the configured service account JSON file.
     * In automated testing mode when HTTP is faked, returns a test bearer token.
     */
    protected function acquireGooglePublisherAccessToken(): string
    {
        if (app()->runningUnitTests()) {
            return 'test-google-publisher-oauth-token';
        }

        $serviceAccountPath = (string) config('naseebak.google_play.service_account_json');
        if ($serviceAccountPath === '' || !is_file($serviceAccountPath)) {
            throw new RuntimeException('ملف حساب الخدمة (Service Account) الخاص بـ Google Play Developer API غير متوفر على الخادم.');
        }

        $client = new GoogleClient();
        $client->setAuthConfig($serviceAccountPath);
        $client->addScope('https://www.googleapis.com/auth/androidpublisher');

        $tokenArray = $client->fetchAccessTokenWithAssertion();
        if (empty($tokenArray['access_token'])) {
            throw new RuntimeException('تعذر استخراج رمز وصول Google Play Developer API.');
        }

        return (string) $tokenArray['access_token'];
    }
}
