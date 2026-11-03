<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Subscription;
use App\Services\Payment\PaymentGatewayManager;
use App\Services\Subscription\GooglePlayBillingService;
use DomainException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentWebhookController extends Controller
{
    public function __construct(
        private readonly PaymentGatewayManager $gatewayManager,
        private readonly GooglePlayBillingService $googlePlayService,
    ) {}

    /**
     * POST /api/v1/webhooks/paymob
     *
     * Receives Paymob server-to-server transaction callbacks, verifies HMAC-SHA512 signature,
     * validates order ownership, amount, and currency, and activates/extends or refunds subscription.
     * Note: Works even if the active gateway in PaymentSetting was subsequently switched to sha7nawy.
     */
    public function handlePaymobWebhook(Request $request): JsonResponse
    {
        try {
            $result = $this->gatewayManager
                ->driver(Subscription::CHANNEL_PAYMOB)
                ->handleWebhook($request);

            return response()->json([
                'status' => 'success',
                'webhook_status' => $result['status'],
            ]);
        } catch (DomainException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'PAYMOB_WEBHOOK_REJECTED',
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * POST /api/v1/webhooks/sha7nawy
     */
    public function handleSha7nawyWebhook(Request $request): JsonResponse
    {
        try {
            $result = $this->gatewayManager
                ->driver(Subscription::CHANNEL_SHA7NAWY)
                ->handleWebhook($request);

            return response()->json([
                'status' => 'success',
                'webhook_status' => $result['status'],
            ]);
        } catch (DomainException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'SHA7NAWY_WEBHOOK_REJECTED',
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * POST /api/v1/webhooks/google-play/rtdn
     *
     * Receives authenticated Google Play Real-Time Developer Notifications (RTDN) via Google Cloud Pub/Sub:
     * 1. Verifies Google Cloud Pub/Sub OIDC JWT Bearer signature, issuer, audience, and service-account email.
     * 2. Deduplicates by Pub/Sub messageId.
     * 3. Re-queries Google Play Developer API (`subscriptionsv2.get`) for authoritative subscription status.
     * 4. Never activates subscriptions based only on RTDN payloads.
     */
    public function handleGooglePlayRtdn(Request $request): JsonResponse
    {
        try {
            $this->googlePlayService->verifyPubSubOidcPushToken($request->bearerToken());
        } catch (AuthenticationException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'GOOGLE_PLAY_RTDN_UNAUTHORIZED',
                'message' => $e->getMessage(),
            ], 401);
        }

        try {
            $result = $this->googlePlayService->processRtdnPubSubPush($request->all());

            return response()->json([
                'status' => 'success',
                'rtdn_status' => $result['status'],
            ]);
        } catch (DomainException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'GOOGLE_PLAY_RTDN_REJECTED',
                'message' => $e->getMessage(),
            ], 400);
        }
    }
}
