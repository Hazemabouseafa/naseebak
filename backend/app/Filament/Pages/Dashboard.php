<?php

namespace App\Filament\Pages;

use App\Filament\Widgets\MemberGrowthChartWidget;
use App\Filament\Widgets\PlatformStatsOverviewWidget;
use App\Filament\Widgets\SubscriptionDistributionChartWidget;
use App\Filament\Widgets\VerifiedRevenueTrendChartWidget;
use App\Providers\Filament\AdminPanelProvider;
use Filament\Pages\Dashboard as BaseDashboard;

class Dashboard extends BaseDashboard
{
    protected static ?string $navigationIcon = 'heroicon-o-home';
    protected static ?string $navigationLabel = 'لوحة المعلومات';
    protected static ?string $title = 'لوحة المعلومات — نصيبك';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_HOME;
    protected static ?int $navigationSort = 1;

    public function getWidgets(): array
    {
        return [
            PlatformStatsOverviewWidget::class,
            MemberGrowthChartWidget::class,
            SubscriptionDistributionChartWidget::class,
            VerifiedRevenueTrendChartWidget::class,
        ];
    }

    public function getColumns(): int|string|array
    {
        return 2;
    }
}
