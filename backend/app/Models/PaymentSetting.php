<?php

namespace App\Models;

use DomainException;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class PaymentSetting extends Model
{
    use HasFactory;

    public const ALLOWED_GATEWAYS = ['paymob', 'sha7nawy'];

    protected $fillable = [
        'active_web_payment_gateway',
        'web_monthly_price',
        'web_currency',
        'subscription_duration_days',
        'paymob_configured',
        'sha7nawy_configured',
        'sha7nawy_integration_status',
        'updated_by',
        'updated_by_admin_id',
    ];

    public static function current(): self
    {
        return self::first() ?? new self([
            'active_web_payment_gateway' => 'paymob',
            'web_monthly_price' => '250.00',
            'web_currency' => 'EGP',
            'subscription_duration_days' => 30,
        ]);
    }

    protected function casts(): array
    {
        return [
            'web_monthly_price' => 'decimal:2',
            'subscription_duration_days' => 'integer',
            'paymob_configured' => 'boolean',
            'sha7nawy_configured' => 'boolean',
        ];
    }

    public function updatedByAdmin(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'updated_by_admin_id');
    }

    /**
     * Checks whether the specified web payment provider is configured and ready for activation.
     */
    public function isGatewayConfigured(string $gateway): bool
    {
        return match ($gateway) {
            'paymob' => (bool) $this->paymob_configured
                || (
                    filled(config('naseebak.web_payments.paymob.api_key'))
                    && filled(config('naseebak.web_payments.paymob.hmac_secret'))
                    && filled(config('naseebak.web_payments.paymob.integration_id_card'))
                ),
            'sha7nawy' => (
                (bool) $this->sha7nawy_configured
                && $this->sha7nawy_integration_status === 'ready'
            ) || (
                filled(config('naseebak.web_payments.sha7nawy.api_key'))
                && filled(config('naseebak.web_payments.sha7nawy.merchant_id'))
                && filled(config('naseebak.web_payments.sha7nawy.webhook_secret'))
            ),
            default => false,
        };
    }

    /**
     * Atomically switch the active web payment gateway ('paymob' or 'sha7nawy')
     * using database row locking (lockForUpdate), verifying configuration readiness,
     * and recording an immutable audit log entry.
     */
    public function switchActiveGatewayAtomically(
        string $newGateway,
        int $actorId,
        ?string $ipAddress = null,
        bool $isAdministratorModel = true
    ): void {
        if (!in_array($newGateway, self::ALLOWED_GATEWAYS, true)) {
            throw new InvalidArgumentException("بوابة الدفع غير مدعومة: {$newGateway}");
        }

        DB::transaction(function () use ($newGateway, $actorId, $ipAddress, $isAdministratorModel) {
            /** @var self $lockedSetting */
            $lockedSetting = self::where('id', $this->id)->lockForUpdate()->firstOrFail();

            if (!$lockedSetting->isGatewayConfigured($newGateway)) {
                throw new DomainException("لا يمكن تفعيل بوابة الدفع ({$newGateway}) لأن بيانات الربط الخاصة بها غير مكتملة.");
            }

            $previousGateway = $lockedSetting->active_web_payment_gateway;

            $updatePayload = [
                'active_web_payment_gateway' => $newGateway,
            ];

            if ($isAdministratorModel) {
                $updatePayload['updated_by_admin_id'] = $actorId;
            } else {
                $updatePayload['updated_by'] = $actorId;
            }

            $lockedSetting->update($updatePayload);

            AdminAuditLog::create([
                'administrator_id' => $isAdministratorModel ? $actorId : null,
                'admin_user_id' => !$isAdministratorModel ? $actorId : null,
                'action' => 'payment_gateway.switched',
                'target_type' => self::class,
                'target_id' => $lockedSetting->id,
                'previous_values' => ['active_web_payment_gateway' => $previousGateway],
                'new_values' => ['active_web_payment_gateway' => $newGateway],
                'ip_address' => $ipAddress,
                'justification' => "تبديل بوابة الدفع الإلكترونية النشطة من {$previousGateway} إلى {$newGateway}",
            ]);

            $this->refresh();
        });
    }

    /**
     * Updates the monthly web subscription price in EGP atomically and records an audit log entry.
     * Does NOT modify Google Play Billing prices or historical payment transactions.
     */
    public function updateMonthlyWebPriceAtomically(
        float|string $newPrice,
        int $adminId,
        ?string $ipAddress = null,
        ?string $reason = null
    ): void {
        $minorUnits = SubscriptionPlan::parseDecimalToMinorUnits($newPrice);
        $formattedPrice = SubscriptionPlan::formatMinorUnitsToDecimal($minorUnits);

        DB::transaction(function () use ($formattedPrice, $minorUnits, $adminId, $ipAddress, $reason) {
            /** @var self $lockedSetting */
            $lockedSetting = self::where('id', $this->id)->lockForUpdate()->firstOrFail();
            $previousPrice = (string) $lockedSetting->web_monthly_price;

            $lockedSetting->update([
                'web_monthly_price' => $formattedPrice,
                'updated_by_admin_id' => $adminId,
            ]);

            // Keep the active web subscription plan synchronized for future web checkouts only
            SubscriptionPlan::where('code', 'monthly_membership')
                ->update([
                    'web_price_amount' => $formattedPrice,
                    'price_minor' => $minorUnits,
                ]);

            AdminAuditLog::create([
                'administrator_id' => $adminId,
                'action' => 'subscription_pricing.updated',
                'target_type' => self::class,
                'target_id' => $lockedSetting->id,
                'previous_values' => [
                    'web_monthly_price' => $previousPrice,
                    'currency' => $lockedSetting->web_currency,
                ],
                'new_values' => [
                    'web_monthly_price' => $formattedPrice,
                    'price_minor' => $minorUnits,
                    'currency' => $lockedSetting->web_currency,
                ],
                'ip_address' => $ipAddress,
                'justification' => $reason ?: "تحديث سعر الاشتراك الشهري عبر الويب من {$previousPrice} إلى {$formattedPrice} {$lockedSetting->web_currency}",
            ]);

            $this->refresh();
        });
    }

    /**
     * Updates either monthly_membership or quarterly_membership plan price/title/status atomically
     * using exact integer minor units without touching historical orders or Google Play products.
     */
    public function updatePlanPricingAtomically(
        string $planCode,
        float|string|int $newPrice,
        ?string $nameAr,
        ?bool $isActive,
        int $adminId,
        ?string $ipAddress = null,
        ?string $reason = null
    ): SubscriptionPlan {
        if (!in_array($planCode, ['monthly_membership', 'quarterly_membership'], true)) {
            throw new InvalidArgumentException("رمز الباقة غير مدعوم للتعديل عبر الموقع: {$planCode}");
        }

        $minorUnits = SubscriptionPlan::parseDecimalToMinorUnits($newPrice);
        $formattedPrice = SubscriptionPlan::formatMinorUnitsToDecimal($minorUnits);

        return DB::transaction(function () use ($planCode, $minorUnits, $formattedPrice, $nameAr, $isActive, $adminId, $ipAddress, $reason) {
            /** @var self $lockedSetting */
            $lockedSetting = self::where('id', $this->id)->lockForUpdate()->firstOrFail();

            /** @var SubscriptionPlan $plan */
            $plan = SubscriptionPlan::where('code', $planCode)->lockForUpdate()->firstOrFail();

            $previousValues = [
                'code' => $plan->code,
                'name_ar' => $plan->name_ar,
                'web_price_amount' => (string) $plan->web_price_amount,
                'price_minor' => (int) $plan->effectivePriceMinor(),
                'is_active' => (bool) $plan->is_active,
            ];

            $updates = [
                'web_price_amount' => $formattedPrice,
                'price_minor' => $minorUnits,
            ];

            if ($nameAr !== null && trim($nameAr) !== '') {
                $updates['name_ar'] = trim($nameAr);
            }

            if ($isActive !== null) {
                $updates['is_active'] = $isActive;
            }

            $plan->update($updates);

            if ($planCode === 'monthly_membership') {
                $lockedSetting->update([
                    'web_monthly_price' => $formattedPrice,
                    'updated_by_admin_id' => $adminId,
                ]);
            }

            AdminAuditLog::create([
                'administrator_id' => $adminId,
                'action' => 'subscription_plan_pricing.updated',
                'target_type' => SubscriptionPlan::class,
                'target_id' => $plan->id,
                'previous_values' => $previousValues,
                'new_values' => [
                    'code' => $plan->code,
                    'name_ar' => $plan->name_ar,
                    'web_price_amount' => (string) $plan->web_price_amount,
                    'price_minor' => (int) $plan->price_minor,
                    'is_active' => (bool) $plan->is_active,
                ],
                'ip_address' => $ipAddress,
                'justification' => $reason ?: "تحديث تسعير الباقة ({$plan->code}) إلى {$formattedPrice} {$plan->web_price_currency}",
            ]);

            $this->refresh();

            return $plan->fresh();
        });
    }

    /**
     * Non-secret diagnostic snapshot of configured web payment gateways.
     */
    public function gatewayDiagnostics(): array
    {
        $paymobMissing = [];
        if (blank(config('naseebak.web_payments.paymob.api_key')) && blank(config('naseebak.web_payments.paymob.secret_key'))) {
            $paymobMissing[] = 'PAYMOB_API_KEY / PAYMOB_SECRET_KEY';
        }
        if (blank(config('naseebak.web_payments.paymob.secret_key')) || blank(config('naseebak.web_payments.paymob.public_key'))) {
            $paymobMissing[] = 'PAYMOB_SECRET_KEY / PAYMOB_PUBLIC_KEY (Intention API)';
        }
        if (blank(config('naseebak.web_payments.paymob.hmac_secret'))) {
            $paymobMissing[] = 'PAYMOB_HMAC_SECRET';
        }
        if (blank(config('naseebak.web_payments.paymob.integration_id_card'))) {
            $paymobMissing[] = 'PAYMOB_INTEGRATION_ID_CARD';
        }

        $shaMissing = [];
        if (blank(config('naseebak.web_payments.sha7nawy.api_key'))) {
            $shaMissing[] = 'SHA7NAWY_API_KEY';
        }
        if (blank(config('naseebak.web_payments.sha7nawy.merchant_id'))) {
            $shaMissing[] = 'SHA7NAWY_MERCHANT_ID';
        }
        if (blank(config('naseebak.web_payments.sha7nawy.webhook_secret'))) {
            $shaMissing[] = 'SHA7NAWY_WEBHOOK_SECRET';
        }

        return [
            'paymob' => [
                'configured' => $this->isGatewayConfigured('paymob'),
                'missing_items' => $paymobMissing,
                'status_label_ar' => $this->isGatewayConfigured('paymob') ? 'جاهزة ومفعّلة للربط' : 'بيانات الربط غير مكتملة في البيئة',
                'notes_ar' => 'تعتمد على Paymob Intention API وتوقيع HMAC-SHA512 للتحقق من الـ Webhook.',
            ],
            'sha7nawy' => [
                'configured' => $this->isGatewayConfigured('sha7nawy'),
                'missing_items' => array_merge($shaMissing, ['Official Sha7nawy API & Webhook Specification']),
                'status_label_ar' => 'بانتظار مواصفات الـ API الرسمية والاعتمادات (Sha7nawy)',
                'notes_ar' => 'البوابة محمية بإغلاق آمن (Fail-Closed) ولن تصدر طلبات دفع وهمية قبل استلام التوثيق الرسمي.',
            ],
        ];
    }
}
