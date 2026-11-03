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
        if (!is_numeric($newPrice)) {
            throw new InvalidArgumentException('سعر الاشتراك الشهري يجب أن يكون رقماً صالحاً.');
        }

        $numericPrice = (float) $newPrice;
        if ($numericPrice <= 0) {
            throw new InvalidArgumentException('سعر الاشتراك الشهري يجب أن يكون أكبر من الصفر.');
        }

        // Enforce maximum 2 decimal places precision
        $formattedPrice = number_format(round($numericPrice, 2), 2, '.', '');
        if (abs($numericPrice - (float) $formattedPrice) > 0.0001) {
            throw new InvalidArgumentException('سعر الاشتراك الشهري يجب ألا يتجاوز منزلتين عشريتين.');
        }

        DB::transaction(function () use ($formattedPrice, $adminId, $ipAddress, $reason) {
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
                    'currency' => $lockedSetting->web_currency,
                ],
                'ip_address' => $ipAddress,
                'justification' => $reason ?: "تحديث سعر الاشتراك الشهري عبر الويب من {$previousPrice} إلى {$formattedPrice} {$lockedSetting->web_currency}",
            ]);

            $this->refresh();
        });
    }
}
