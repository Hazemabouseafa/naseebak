<?php

namespace App\Services\Payment;

use App\Models\PaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\SubscriptionPlan;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;

class WebsiteCheckoutService
{
    public const SUPPORTED_WEB_PLAN_CODES = [
        'monthly_membership',
        'quarterly_membership',
    ];

    public function __construct(
        private readonly PaymentGatewayManager $gatewayManager,
    ) {}

    /**
     * Resolves an active web-purchasable plan and creates a gateway checkout session
     * strictly using server-side integer pricing.
     *
     * @return array{transaction: PaymentTransaction, checkout_url: string, plan: SubscriptionPlan}
     */
    public function initiateCheckout(User $user, string $planCode): array
    {
        if (!in_array($planCode, self::SUPPORTED_WEB_PLAN_CODES, true)) {
            throw new DomainException('الباقة المطلوبة غير متاحة للاشتراك عبر الموقع.');
        }

        $setting = PaymentSetting::first();
        $plan = SubscriptionPlan::where('code', $planCode)
            ->where('is_active', true)
            ->first();

        if (!$setting || !$plan) {
            throw new DomainException('باقة الاشتراك المختارة غير مفعّلة حالياً.');
        }

        $minorUnits = $this->resolveAuthoritativeMinorUnits($plan, $setting);
        $fixedPriceEgp = SubscriptionPlan::formatMinorUnitsToDecimal($minorUnits);

        $gateway = $this->gatewayManager->getActiveWebGateway();
        $result = $gateway->createPayment($user, $plan, $fixedPriceEgp);

        return [
            'transaction' => $result['transaction'],
            'checkout_url' => $result['checkout_url'],
            'plan' => $plan,
        ];
    }

    public function cancelPendingOrderForUser(User $user, string $internalReference): PaymentTransaction
    {
        return DB::transaction(function () use ($user, $internalReference) {
            /** @var ?PaymentTransaction $tx */
            $tx = PaymentTransaction::where('internal_reference', $internalReference)
                ->lockForUpdate()
                ->first();

            if (!$tx || (int) $tx->user_id !== (int) $user->id) {
                throw new DomainException('المعاملة المطلوبة غير موجودة لهذا الحساب.');
            }

            if ($tx->status === PaymentTransaction::STATUS_SUCCEEDED) {
                throw new DomainException('لا يمكن إلغاء معاملة تم تأكيد دفعها وتفعيلها بالفعل.');
            }

            if ($tx->status === PaymentTransaction::STATUS_PENDING) {
                $tx->update([
                    'status' => PaymentTransaction::STATUS_CANCELLED,
                    'cancelled_at' => now(),
                ]);
            }

            return $tx->fresh(['plan']);
        });
    }

    public function resolveReturnState(PaymentTransaction $transaction): string
    {
        return match ($transaction->status) {
            PaymentTransaction::STATUS_SUCCEEDED => 'success',
            PaymentTransaction::STATUS_PENDING => 'pending',
            PaymentTransaction::STATUS_CANCELLED => 'cancelled',
            default => 'failed',
        };
    }

    private function resolveAuthoritativeMinorUnits(SubscriptionPlan $plan, PaymentSetting $setting): int
    {
        if ($plan->code === 'monthly_membership' && (string) $setting->web_monthly_price !== '') {
            $planMinor = $plan->effectivePriceMinor();
            $settingMinor = SubscriptionPlan::parseDecimalToMinorUnits((string) $setting->web_monthly_price);

            // Honor setting minor if plan price_minor was not yet populated
            return $planMinor > 0 ? $planMinor : $settingMinor;
        }

        $minor = $plan->effectivePriceMinor();
        if ($minor <= 0) {
            throw new DomainException('سعر الباقة غير مضبوط بشكل صحيح على الخادم.');
        }

        return $minor;
    }
}
