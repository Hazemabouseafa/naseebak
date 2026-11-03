<?php

namespace App\Providers\Filament;

use App\Filament\Pages\Dashboard;
use App\Filament\Pages\ManageApplicationSettingsPage;
use App\Filament\Pages\ManagePaymentGatewaysPage;
use App\Filament\Pages\ManageSubscriptionPricingPage;
use App\Filament\Widgets\MemberGrowthChartWidget;
use App\Filament\Widgets\PlatformStatsOverviewWidget;
use App\Filament\Widgets\SubscriptionDistributionChartWidget;
use App\Filament\Widgets\VerifiedRevenueTrendChartWidget;
use App\Http\Middleware\EnsureAdminAccountIsActive;
use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Navigation\NavigationGroup;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\AuthenticateSession;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\View\Middleware\ShareErrorsFromSession;

class AdminPanelProvider extends PanelProvider
{
    public const NAV_GROUP_HOME = 'الرئيسية';
    public const NAV_GROUP_USERS = 'إدارة المستخدمين';
    public const NAV_GROUP_BILLING = 'الاشتراكات والمدفوعات';
    public const NAV_GROUP_SYSTEM = 'إدارة النظام';

    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->authGuard('admin')
            ->login()
            ->brandName('لوحة تحكم نصيبك')
            ->font('Cairo')
            ->colors([
                // Primary Blue: #145A9E
                'primary' => Color::hex('#145A9E'),
                // Dark Blue: #123D6A
                'info' => Color::hex('#123D6A'),
                // Accent Yellow: #FFC43D
                'warning' => Color::hex('#FFC43D'),
                // Destructive Red
                'danger' => Color::hex('#D92D20'),
                // Success Green (status badge only)
                'success' => Color::hex('#12B76A'),
                // Neutral Slate Text (#1D2939)
                'gray' => Color::Slate,
            ])
            ->navigationGroups([
                NavigationGroup::make()
                    ->label(self::NAV_GROUP_HOME)
                    ->collapsible(false),
                NavigationGroup::make()
                    ->label(self::NAV_GROUP_USERS)
                    ->collapsible(false),
                NavigationGroup::make()
                    ->label(self::NAV_GROUP_BILLING)
                    ->collapsible(false),
                NavigationGroup::make()
                    ->label(self::NAV_GROUP_SYSTEM)
                    ->collapsible(false),
            ])
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\\Filament\\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\\Filament\\Pages')
            ->pages([
                Dashboard::class,
                ManageSubscriptionPricingPage::class,
                ManagePaymentGatewaysPage::class,
                ManageApplicationSettingsPage::class,
            ])
            ->widgets([
                PlatformStatsOverviewWidget::class,
                MemberGrowthChartWidget::class,
                SubscriptionDistributionChartWidget::class,
                VerifiedRevenueTrendChartWidget::class,
            ])
            ->middleware([
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                AuthenticateSession::class,
                ShareErrorsFromSession::class,
                VerifyCsrfToken::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,
                EnsureAdminAccountIsActive::class,
            ]);
    }
}
