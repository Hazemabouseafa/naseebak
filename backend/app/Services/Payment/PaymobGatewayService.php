<?php

namespace App\Services\Payment;

use App\Models\PaymentTransaction;
use App\Models\PaymentWebhookEvent;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use App\Services\Subscription\SubscriptionEntitlementService;
use DomainException;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use RuntimeException;

class PaymobGatewayService implements PaymentGatewayInterface
{
    public const BASE_URL = 'https://accept.paymob.com';

    /**
     * Exact 20 fields required by Paymob Accept Transaction Processed Callback HMAC-SHA512
     * specification in strict lexicographical order:
     */
    public const HMAC_CONCATENATION_PATHS = [
        'amount_cents',
        'created_at',
        'currency',
        'error_occured',
        'has_parent_transaction',
        'id',
        'integration_id',
        'is_3d_secure',
        'is_auth',
        'is_capture',
        'is_refunded',
        'is_standalone_payment',
        'is_voided',
        'order.id',
        'owner',
        'pending',
        'source_data.pan',
        'source_data.sub_type',
        'source_data.type',
        'success',
    ];

    public function __construct(
        private readonly SubscriptionEntitlementService $entitlementService
    ) {}

    public function getProviderName(): string
    {
        return Subscription::CHANNEL_PAYMOB;
    }

    /**
     * Creates an internal PaymentTransaction order with a fixed amount snapshot (in EGP and piastres)
     * and creates a Paymob Intention (`/v1/intention/`) to obtain the hosted Unified Checkout URL.
     */
    public function createPayment(User $user, SubscriptionPlan $plan, string $fixedPriceEgp): array
    {
        $numericPrice = round((float) $fixedPriceEgp, 2);
        if ($numericPrice <= 0) {
            throw new DomainException('سعر الاشتراك غير صالح لإنشاء طلب دفع.');
        }

        $amountMinorCents = (int) round($numericPrice * 100);
        $internalRef = 'NSB-PMB-' . strtoupper(Str::random(14));

        /** @var PaymentTransaction $transaction */
        $transaction = DB::transaction(function () use ($user, $plan, $numericPrice, $amountMinorCents, $internalRef) {
            return PaymentTransaction::create([
                'idempotency_key' => (string) Str::uuid(),
                'internal_reference' => $internalRef,
                'user_id' => $user->id,
                'subscription_plan_id' => $plan->id,
                'gateway' => Subscription::CHANNEL_PAYMOB,
                'amount' => number_format($numericPrice, 2, '.', ''),
                'amount_minor' => $amountMinorCents,
                'currency' => 'EGP',
                'status' => PaymentTransaction::STATUS_PENDING,
                'signature_verified' => false,
            ]);
        });

        $secretKey = (string) config('naseebak.web_payments.paymob.secret_key');
        $publicKey = (string) config('naseebak.web_payments.paymob.public_key');
        $integrationId = (int) config('naseebak.web_payments.paymob.integration_id_card');

        if ($secretKey === '' || $publicKey === '' || $integrationId <= 0) {
            throw new RuntimeException('بيانات الربط مع بوابة الدفع Paymob غير مكتملة على الخادم.');
        }

        $profileName = $user->profile?->full_name ?: 'عضو نصيبك';
        $nameParts = preg_split('/\s+/', trim($profileName), 2);
        $firstName = $nameParts[0] ?? 'Member';
        $lastName = $nameParts[1] ?? 'Naseebak';

        $response = Http::withHeaders([
            'Authorization' => "Token {$secretKey}",
        ])
            ->acceptJson()
            ->timeout(15)
            ->post(self::BASE_URL . '/v1/intention/', [
                'amount' => $amountMinorCents,
                'currency' => 'EGP',
                'payment_methods' => [$integrationId],
                'special_reference' => $internalRef,
                'items' => [
                    [
                        'name' => $plan->name_ar,
                        'amount' => $amountMinorCents,
                        'description' => 'اشتراك شهري في تطبيق نصيبك',
                        'quantity' => 1,
                    ],
                ],
                'billing_data' => [
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'email' => $user->email,
                    'phone_number' => '+201000000000',
                    'country' => 'EG',
                    'city' => $user->profile?->region ?: 'Cairo',
                    'street' => 'NA',
                    'building' => 'NA',
                    'floor' => 'NA',
                    'apartment' => 'NA',
                ],
            ]);

        if (!$response->successful()) {
            Log::error('Paymob intention creation failed', [
                'internal_reference' => $internalRef,
                'http_status' => $response->status(),
            ]);
            throw new RuntimeException('تعذر إنشاء جلسة الدفع لدى بوابة Paymob حالياً.');
        }

        $body = $response->json() ?? [];
        $clientSecret = (string) ($body['client_secret'] ?? '');
        $intentionOrderId = (string) ($body['intention_order_id'] ?? $body['id'] ?? '');

        if ($clientSecret === '') {
            throw new RuntimeException('استجابة بوابة Paymob لا تحتوي على مفتاح جلسة الدفع.');
        }

        $transaction->update([
            'gateway_order_id' => $intentionOrderId !== '' ? $intentionOrderId : $internalRef,
        ]);

        $checkoutUrl = self::BASE_URL . '/unifiedcheckout/?publicKey=' . urlencode($publicKey)
            . '&clientSecret=' . urlencode($clientSecret);

        return [
            'transaction' => $transaction->refresh(),
            'checkout_url' => $checkoutUrl,
        ];
    }

    public function verifyPayment(PaymentTransaction $transaction, array $verificationData = []): PaymentTransaction
    {
        return $transaction->refresh();
    }

    /**
     * Processes Paymob Transaction Processed Callback (`POST /api/v1/webhooks/paymob`).
     *
     * Enforces:
     * 1. Fail-closed HMAC-SHA512 verification across all 20 documented Paymob fields using `hash_equals`.
     * 2. Integration ID validation against configured Paymob card integration ID.
     * 3. Strict transaction reference validation (`merchant_order_id` / `special_reference` & `order.id`).
     * 4. Strict validation of `amount_cents` (`amount_minor`) and `currency === 'EGP'`.
     * 5. Idempotent payment processing: neither duplicate webhook deliveries nor separate event IDs
     *    representing the same payment can ever activate or extend a subscription twice.
     */
    public function handleWebhook(Request $request): array
    {
        $providedHmac = (string) $request->query('hmac', $request->header('X-Paymob-Hmac', ''));
        $payload = $request->all();
        $obj = $payload['obj'] ?? $payload;

        if (!is_array($obj) || empty($obj['id'])) {
            throw new DomainException('بيانات إشعار الدفع من Paymob غير مكتملة.');
        }

        if (!$this->verifyHmacSignature($obj, $providedHmac)) {
            throw new DomainException('توقيع الأمان (HMAC) لإشعار Paymob غير صالح.');
        }

        // Validate integration_id if configured on server
        $expectedIntegrationId = (int) config('naseebak.web_payments.paymob.integration_id_card', 0);
        if ($expectedIntegrationId > 0 && (int) ($obj['integration_id'] ?? 0) !== $expectedIntegrationId) {
            throw new DomainException('معرف قناة الدفع (integration_id) في إشعار Paymob غير مطابق.');
        }

        $paymobTxId = trim((string) $obj['id']);
        $isRefunded = (bool) ($obj['is_refunded'] ?? false);
        $isVoided = (bool) ($obj['is_voided'] ?? false);
        $isSuccess = (bool) ($obj['success'] ?? false);
        $isPending = (bool) ($obj['pending'] ?? false);
        $errorOccured = (bool) ($obj['error_occured'] ?? false);

        $eventType = ($isRefunded || $isVoided)
            ? 'TRANSACTION_REFUNDED'
            : ($isSuccess ? 'TRANSACTION_SUCCEEDED' : 'TRANSACTION_FAILED');

        $rawEventId = trim((string) ($payload['event_id'] ?? $request->header('X-Paymob-Event-Id', '')));
        $eventId = $rawEventId !== '' ? $rawEventId : "{$paymobTxId}:{$eventType}";

        // Locate and strictly validate the internal PaymentTransaction reference
        $specialReference = trim((string) (
            data_get($obj, 'order.merchant_order_id')
            ?? data_get($obj, 'special_reference')
            ?? ''
        ));
        $paymobOrderId = trim((string) data_get($obj, 'order.id', ''));

        if ($specialReference === '' && $paymobOrderId === '') {
            throw new DomainException('مرجع الطلب الداخلي (merchant_order_id / order.id) مفقود في إشعار Paymob.');
        }

        $transaction = $this->resolveAndValidateTransactionReference($specialReference, $paymobOrderId, $paymobTxId);

        // Strict Currency Verification
        $webhookCurrency = strtoupper(trim((string) ($obj['currency'] ?? '')));
        if ($webhookCurrency === '' || $webhookCurrency !== strtoupper((string) $transaction->currency)) {
            throw new DomainException("عملة الدفع المستلمة ({$webhookCurrency}) لا تطابق عملة الطلب ({$transaction->currency}).");
        }

        // Strict Amount Verification in minor units (piastres/cents)
        $webhookAmountCents = (int) ($obj['amount_cents'] ?? -1);
        $expectedAmountCents = $transaction->amount_minor !== null
            ? (int) $transaction->amount_minor
            : (int) round(((float) $transaction->amount) * 100);

        if ($webhookAmountCents <= 0 || $webhookAmountCents !== $expectedAmountCents) {
            throw new DomainException("مبلغ العملية المستلم ({$webhookAmountCents} قرش) لا يطابق المبلغ المحدد للطلب ({$expectedAmountCents} قرش).");
        }

        return DB::transaction(function () use (
            $transaction,
            $paymobTxId,
            $paymobOrderId,
            $isRefunded,
            $isVoided,
            $isSuccess,
            $isPending,
            $errorOccured,
            $eventId,
            $eventType
        ) {
            /** @var PaymentTransaction $lockedTx */
            $lockedTx = PaymentTransaction::where('id', $transaction->id)->lockForUpdate()->firstOrFail();

            // 1. Check exact webhook event ID deduplication
            $existingEvent = PaymentWebhookEvent::where('provider', Subscription::CHANNEL_PAYMOB)
                ->where('provider_event_id', $eventId)
                ->lockForUpdate()
                ->first();

            if ($existingEvent !== null) {
                return [
                    'status' => 'ignored_duplicate',
                    'transaction' => $lockedTx,
                ];
            }

            // 2. Payment-level idempotency: if a separate callback or different event_id / paymobTxId
            //    arrives for a payment order that was ALREADY fulfilled (or already refunded), never process twice!
            if ($isRefunded || $isVoided) {
                if ($lockedTx->status === PaymentTransaction::STATUS_REFUNDED) {
                    $this->recordWebhookEvent($eventId, $eventType, $lockedTx, $paymobTxId, 'ignored_duplicate');
                    return [
                        'status' => 'ignored_duplicate',
                        'transaction' => $lockedTx,
                    ];
                }

                $lockedTx->update([
                    'gateway_transaction_id' => $lockedTx->gateway_transaction_id ?: $paymobTxId,
                    'signature_verified' => true,
                    'verified_at' => now(),
                ]);

                $this->entitlementService->revokeOrRecalculateOnRefund($lockedTx, 'refunded');
            } elseif ($isSuccess && !$isPending && !$errorOccured) {
                if ($lockedTx->status === PaymentTransaction::STATUS_SUCCEEDED && $lockedTx->subscription_id !== null) {
                    $this->recordWebhookEvent($eventId, $eventType, $lockedTx, $paymobTxId, 'ignored_duplicate');
                    return [
                        'status' => 'ignored_duplicate',
                        'transaction' => $lockedTx,
                    ];
                }

                $lockedTx->update([
                    'gateway_transaction_id' => $paymobTxId,
                    'gateway_order_id' => $paymobOrderId ?: $lockedTx->gateway_order_id,
                    'status' => PaymentTransaction::STATUS_SUCCEEDED,
                    'signature_verified' => true,
                    'verified_at' => $lockedTx->verified_at ?? now(),
                    'paid_at' => $lockedTx->paid_at ?? now(),
                    'gateway_response_summary' => [
                        'paymob_tx_id' => $paymobTxId,
                        'success' => true,
                    ],
                ]);

                $this->entitlementService->activateOrExtendFromVerifiedWebTransaction($lockedTx);
            } else {
                // Failed payment: never activate subscription or overwrite an already succeeded order
                if ($lockedTx->status !== PaymentTransaction::STATUS_SUCCEEDED) {
                    $lockedTx->update([
                        'gateway_transaction_id' => $lockedTx->gateway_transaction_id ?: $paymobTxId,
                        'status' => PaymentTransaction::STATUS_FAILED,
                        'signature_verified' => true,
                        'verified_at' => now(),
                        'gateway_response_summary' => [
                            'paymob_tx_id' => $paymobTxId,
                            'success' => false,
                            'error_occured' => $errorOccured,
                        ],
                    ]);
                }
            }

            $this->recordWebhookEvent($eventId, $eventType, $lockedTx->fresh(), $paymobTxId, 'processed');

            return [
                'status' => 'processed',
                'transaction' => $lockedTx->refresh(),
            ];
        });
    }

    /**
     * Resolves the internal PaymentTransaction and validates that all provided
     * transaction/order references match without conflict.
     */
    protected function resolveAndValidateTransactionReference(
        string $specialReference,
        string $paymobOrderId,
        string $paymobTxId
    ): PaymentTransaction {
        $transaction = null;

        if ($specialReference !== '') {
            $transaction = PaymentTransaction::where('gateway', Subscription::CHANNEL_PAYMOB)
                ->where('internal_reference', $specialReference)
                ->first();
        }

        if ($transaction === null && $paymobOrderId !== '') {
            $transaction = PaymentTransaction::where('gateway', Subscription::CHANNEL_PAYMOB)
                ->where('gateway_order_id', $paymobOrderId)
                ->first();
        }

        if ($transaction === null && $paymobTxId !== '') {
            $transaction = PaymentTransaction::where('gateway', Subscription::CHANNEL_PAYMOB)
                ->where('gateway_transaction_id', $paymobTxId)
                ->first();
        }

        if (!$transaction) {
            throw new DomainException('لم يتم العثور على طلب الدفع الداخلي المطابق لإشعار Paymob.');
        }

        // Cross-validate internal_reference if specialReference was supplied
        if (
            $specialReference !== ''
            && $transaction->internal_reference !== null
            && !hash_equals((string) $transaction->internal_reference, $specialReference)
        ) {
            throw new DomainException('مرجع الطلب الداخلي (merchant_order_id) لا يطابق السجل المحفوظ.');
        }

        // Cross-validate gateway_order_id if it was already set to a distinct Paymob order ID
        if (
            $paymobOrderId !== ''
            && $transaction->gateway_order_id !== null
            && $transaction->gateway_order_id !== $transaction->internal_reference
            && !hash_equals((string) $transaction->gateway_order_id, $paymobOrderId)
        ) {
            throw new DomainException('معرف طلب Paymob (order.id) لا يطابق السجل المحفوظ.');
        }

        // Ensure no other transaction row has already claimed this Paymob transaction ID
        $conflictingTxExists = PaymentTransaction::where('gateway', Subscription::CHANNEL_PAYMOB)
            ->where('gateway_transaction_id', $paymobTxId)
            ->where('id', '!=', $transaction->id)
            ->exists();

        if ($conflictingTxExists) {
            throw new DomainException('معرف عملية الدفع (id) مرتبط مسبقاً بطلب داخلي آخر.');
        }

        return $transaction;
    }

    protected function recordWebhookEvent(
        string $eventId,
        string $eventType,
        PaymentTransaction $transaction,
        string $paymobTxId,
        string $processingStatus
    ): void {
        PaymentWebhookEvent::create([
            'provider' => Subscription::CHANNEL_PAYMOB,
            'provider_event_id' => $eventId,
            'event_type' => $eventType,
            'payment_transaction_id' => $transaction->id,
            'subscription_id' => $transaction->subscription_id,
            'processing_status' => $processingStatus,
            'sanitized_payload' => [
                'paymob_tx_id' => $paymobTxId,
                'event_type' => $eventType,
                'processing_status' => $processingStatus,
            ],
            'processed_at' => now(),
        ]);
    }

    public function getPaymentStatus(PaymentTransaction $transaction): string
    {
        return $transaction->status;
    }

    /**
     * Fail-closed Paymob HMAC-SHA512 verification across the exact 20 documented fields.
     */
    public function verifyHmacSignature(array $obj, string $providedHmac): bool
    {
        $hmacSecret = (string) config('naseebak.web_payments.paymob.hmac_secret');
        $normalizedProvided = strtolower(trim($providedHmac));

        // Fail closed if secret or signature is missing, non-hex, or not 128 chars (512 bits)
        if (
            $hmacSecret === ''
            || $normalizedProvided === ''
            || strlen($normalizedProvided) !== 128
            || !ctype_xdigit($normalizedProvided)
        ) {
            return false;
        }

        // Fail closed if any of the 20 required Paymob HMAC fields is missing from the callback object
        if (!self::hasAllRequiredHmacFields($obj)) {
            return false;
        }

        $computed = self::computeHmac($obj, $hmacSecret);
        return hash_equals($computed, $normalizedProvided);
    }

    /**
     * Verifies that all 20 required Paymob callback fields are present in the payload.
     */
    public static function hasAllRequiredHmacFields(array $obj): bool
    {
        foreach (self::HMAC_CONCATENATION_PATHS as $path) {
            if (!Arr::has($obj, $path)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Computes the lowercase hex HMAC-SHA512 signature for a Paymob Transaction Processed Callback object.
     */
    public static function computeHmac(array $obj, string $hmacSecret): string
    {
        $concatenated = '';
        foreach (self::HMAC_CONCATENATION_PATHS as $path) {
            $val = data_get($obj, $path, '');
            if (is_bool($val)) {
                $concatenated .= $val ? 'true' : 'false';
            } elseif ($val === null) {
                $concatenated .= '';
            } else {
                $concatenated .= (string) $val;
            }
        }

        return hash_hmac('sha512', $concatenated, $hmacSecret);
    }
}
