<?php

namespace App\Services\Payment;

use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use DomainException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Sha7nawy Web Payment Gateway Adapter (https://gate.sha7nawy.com/)
 *
 * IMPORTANT ARCHITECTURAL & SECURITY NOTE (Section 15 Compliance):
 * Official merchant API endpoint specifications, authentication headers, and webhook
 * cryptographic signature verification specifications for `https://gate.sha7nawy.com/`
 * have not yet been supplied in the workspace.
 *
 * Per strict engineering rules:
 * - No undocumented API endpoints, authentication headers, or status codes are invented.
 * - No simulated or unverified payments can ever activate a subscription.
 * - Order creation persists the internal pending transaction audit record and returns
 *   a controlled `SHA7NAWY_SPECIFICATION_PENDING` error rather than firing an undocumented HTTP request.
 */
class Sha7nawyGatewayService implements PaymentGatewayInterface
{
    public function getProviderName(): string
    {
        return Subscription::CHANNEL_SHA7NAWY;
    }

    public function isConfigured(): bool
    {
        return filled(config('naseebak.web_payments.sha7nawy.api_key'))
            && filled(config('naseebak.web_payments.sha7nawy.merchant_id'))
            && filled(config('naseebak.web_payments.sha7nawy.webhook_secret'));
    }

    public function createPayment(User $user, SubscriptionPlan $plan, string $fixedPriceEgp): array
    {
        $amountMinorCents = trim($fixedPriceEgp) !== ''
            ? SubscriptionPlan::parseDecimalToMinorUnits($fixedPriceEgp)
            : $plan->effectivePriceMinor();

        if ($amountMinorCents <= 0) {
            throw new DomainException('سعر الاشتراك غير صالح لإنشاء طلب دفع.');
        }

        $fixedAmountDecimal = SubscriptionPlan::formatMinorUnitsToDecimal($amountMinorCents);
        $internalRef = 'NSB-SH7-' . strtoupper(Str::random(14));

        // Persist the internal pending transaction snapshot safely
        DB::transaction(function () use ($user, $plan, $fixedAmountDecimal, $amountMinorCents, $internalRef) {
            PaymentTransaction::create([
                'idempotency_key' => (string) Str::uuid(),
                'internal_reference' => $internalRef,
                'user_id' => $user->id,
                'subscription_plan_id' => $plan->id,
                'gateway' => Subscription::CHANNEL_SHA7NAWY,
                'amount' => $fixedAmountDecimal,
                'amount_minor' => $amountMinorCents,
                'currency' => 'EGP',
                'status' => PaymentTransaction::STATUS_PENDING,
                'signature_verified' => false,
                'expires_at' => now()->addHours(2),
            ]);
        });

        throw new DomainException(
            'بوابة الدفع شحناوي (Sha7nawy) قيد استكمال مواصفات الربط التقني الرسمية (API Specification & Webhook HMAC). لم يتم خصم أي مبالغ.'
        );
    }

    public function verifyPayment(PaymentTransaction $transaction, array $verificationData = []): PaymentTransaction
    {
        throw new DomainException(
            'التحقق المباشر عبر بوابة شحناوي (Sha7nawy) متوقف لحين تزويد التوثيق الرسمي لنقاط نهاية التحقق.'
        );
    }

    public function handleWebhook(Request $request): array
    {
        throw new DomainException(
            'تم رفض إشعار Webhook لبوابة شحناوي (Sha7nawy) لعدم توفر خوارزمية التحقق من التوقيع الرقمي الرسمية في التوثيق.'
        );
    }

    public function getPaymentStatus(PaymentTransaction $transaction): string
    {
        return $transaction->status;
    }
}
