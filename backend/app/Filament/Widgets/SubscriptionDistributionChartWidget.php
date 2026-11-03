<?php

namespace App\Filament\Widgets;

use App\Models\Subscription;
use Filament\Widgets\ChartWidget;

class SubscriptionDistributionChartWidget extends ChartWidget
{
    protected static ?string $heading = 'توزيع الاشتراكات حسب الحالة';
    protected static ?int $sort = 3;

    protected function getData(): array
    {
        $countsByStatus = Subscription::query()
            ->selectRaw('status, COUNT(*) as aggregate_count')
            ->groupBy('status')
            ->pluck('aggregate_count', 'status');

        return [
            'datasets' => [
                [
                    'label' => 'عدد الاشتراكات',
                    'data' => [
                        (int) ($countsByStatus['active'] ?? 0),
                        (int) (($countsByStatus['in_grace_period'] ?? 0) + ($countsByStatus['grace_period'] ?? 0)),
                        (int) ($countsByStatus['expired'] ?? 0),
                        (int) ($countsByStatus['cancelled'] ?? 0),
                        (int) (($countsByStatus['pending'] ?? 0) + ($countsByStatus['pending_payment'] ?? 0) + ($countsByStatus['on_hold'] ?? 0)),
                    ],
                    'backgroundColor' => [
                        '#145A9E', // Primary Blue
                        '#FFC43D', // Accent Yellow
                        '#667085', // Neutral Slate
                        '#D92D20', // Red
                        '#123D6A', // Dark Blue
                    ],
                ],
            ],
            'labels' => [
                'نشط',
                'فترة سماح',
                'منتهي',
                'ملغى',
                'بانتظار الدفع',
            ],
        ];
    }

    protected function getType(): string
    {
        return 'doughnut';
    }
}
