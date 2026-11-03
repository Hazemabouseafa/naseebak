<?php

namespace App\Filament\Widgets;

use App\Models\User;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Facades\DB;

class MemberGrowthChartWidget extends ChartWidget
{
    protected static ?string $heading = 'نمو الأعضاء خلال آخر 6 أشهر';
    protected static ?int $sort = 2;

    protected function getData(): array
    {
        $startDate = now()->subMonths(5)->startOfMonth();

        // Efficient single aggregate query
        $driver = DB::connection()->getDriverName();
        $monthExpr = $driver === 'pgsql'
            ? "TO_CHAR(created_at, 'YYYY-MM')"
            : "strftime('%Y-%m', created_at)";

        $countsByMonth = User::query()
            ->where('role', 'member')
            ->where('created_at', '>=', $startDate)
            ->selectRaw("{$monthExpr} as month_key, COUNT(*) as aggregate_count")
            ->groupBy('month_key')
            ->pluck('aggregate_count', 'month_key');

        $labels = [];
        $data = [];

        for ($i = 5; $i >= 0; $i--) {
            $month = now()->subMonths($i);
            $key = $month->format('Y-m');
            $labels[] = $month->translatedFormat('M Y');
            $data[] = (int) ($countsByMonth[$key] ?? 0);
        }

        return [
            'datasets' => [
                [
                    'label' => 'الأعضاء المسجلون الجدد',
                    'data' => $data,
                    'backgroundColor' => '#145A9E',
                    'borderColor' => '#145A9E',
                ],
            ],
            'labels' => $labels,
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}
