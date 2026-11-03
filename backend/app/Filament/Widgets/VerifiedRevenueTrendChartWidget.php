<?php

namespace App\Filament\Widgets;

use App\Models\PaymentTransaction;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Facades\DB;

class VerifiedRevenueTrendChartWidget extends ChartWidget
{
    protected static ?string $heading = 'إجمالي المدفوعات الموثقة شهرياً (ج.م)';
    protected static ?int $sort = 4;
    protected int|string|array $columnSpan = 'full';

    protected function getData(): array
    {
        $startDate = now()->subMonths(5)->startOfMonth();

        $driver = DB::connection()->getDriverName();
        $monthExpr = $driver === 'pgsql'
            ? "TO_CHAR(created_at, 'YYYY-MM')"
            : "strftime('%Y-%m', created_at)";

        // Strictly sums verified succeeded payment transactions only
        $revenueByMonth = PaymentTransaction::query()
            ->where('status', 'succeeded')
            ->where('signature_verified', true)
            ->where('created_at', '>=', $startDate)
            ->selectRaw("{$monthExpr} as month_key, COALESCE(SUM(amount), 0) as total_amount")
            ->groupBy('month_key')
            ->pluck('total_amount', 'month_key');

        $labels = [];
        $data = [];

        for ($i = 5; $i >= 0; $i--) {
            $month = now()->subMonths($i);
            $key = $month->format('Y-m');
            $labels[] = $month->translatedFormat('M Y');
            $data[] = round((float) ($revenueByMonth[$key] ?? 0), 2);
        }

        return [
            'datasets' => [
                [
                    'label' => 'المدفوعات الموثقة (ج.م)',
                    'data' => $data,
                    'backgroundColor' => '#145A9E',
                    'borderColor' => '#123D6A',
                ],
            ],
            'labels' => $labels,
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }
}
