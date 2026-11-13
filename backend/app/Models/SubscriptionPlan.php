<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SubscriptionPlan extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name_ar',
        'description_ar',
        'duration_days',
        'duration_months',
        'google_play_product_id',
        'web_price_amount',
        'price_minor',
        'web_price_currency',
        'is_active',
        'sort_order',
        'features_ar',
    ];

    protected function casts(): array
    {
        return [
            'duration_days' => 'integer',
            'duration_months' => 'integer',
            'web_price_amount' => 'decimal:2',
            'price_minor' => 'integer',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
            'features_ar' => 'array',
        ];
    }

    /**
     * Parses a decimal currency amount into exact integer minor units (piastres/halalas)
     * without IEEE-754 floating point arithmetic.
     */
    public static function parseDecimalToMinorUnits(string|int|float $amount): int
    {
        if (is_int($amount)) {
            if ($amount <= 0) {
                throw new \InvalidArgumentException('المبلغ المالي يجب أن يكون أكبر من الصفر.');
            }

            return $amount * 100;
        }

        $raw = is_float($amount) ? sprintf('%.2F', $amount) : trim((string) $amount);
        if (preg_match('/^\d+(?:\.\d{1,2})?$/', $raw) !== 1) {
            throw new \InvalidArgumentException('صيغة المبلغ المالي غير صالحة أو تتجاوز منزلتين عشريتين.');
        }

        [$majorPart, $minorPart] = array_pad(explode('.', $raw, 2), 2, '0');
        $minorUnits = ((int) $majorPart * 100) + (int) str_pad($minorPart, 2, '0', STR_PAD_RIGHT);

        if ($minorUnits <= 0) {
            throw new \InvalidArgumentException('المبلغ المالي يجب أن يكون أكبر من الصفر.');
        }

        return $minorUnits;
    }

    public static function formatMinorUnitsToDecimal(int $minorUnits): string
    {
        $safeMinor = max(0, $minorUnits);
        $major = intdiv($safeMinor, 100);
        $fraction = $safeMinor % 100;

        return $major . '.' . str_pad((string) $fraction, 2, '0', STR_PAD_LEFT);
    }

    public function effectivePriceMinor(): int
    {
        if ((int) ($this->price_minor ?? 0) > 0) {
            return (int) $this->price_minor;
        }

        if ($this->web_price_amount !== null) {
            try {
                return self::parseDecimalToMinorUnits((string) $this->web_price_amount);
            } catch (\InvalidArgumentException) {
                return 0;
            }
        }

        return 0;
    }

    public function formattedPrice(): string
    {
        $decimal = self::formatMinorUnitsToDecimal($this->effectivePriceMinor());

        return str_ends_with($decimal, '.00')
            ? substr($decimal, 0, -3)
            : $decimal;
    }

    public function effectiveMonths(): int
    {
        if ((int) ($this->duration_months ?? 0) > 0) {
            return (int) $this->duration_months;
        }

        return $this->code === 'quarterly_membership' ? 3 : 1;
    }

    public static function computeSavingsPercentVsMonthly(?self $monthly, ?self $quarterly): ?int
    {
        if (!$monthly || !$quarterly) {
            return null;
        }

        $monthlyMinor = $monthly->effectivePriceMinor();
        $quarterlyMinor = $quarterly->effectivePriceMinor();
        $months = $quarterly->effectiveMonths();

        if ($monthlyMinor <= 0 || $quarterlyMinor <= 0 || $months <= 1) {
            return null;
        }

        $baselineMinor = $monthlyMinor * $months;
        if ($quarterlyMinor >= $baselineMinor) {
            return null;
        }

        return intdiv(($baselineMinor - $quarterlyMinor) * 100, $baselineMinor);
    }
}
