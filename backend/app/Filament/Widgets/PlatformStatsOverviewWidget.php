<?php

namespace App\Filament\Widgets;

use App\Models\MatchmakingRequest;
use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\User;
use App\Models\UserProfile;
use App\Models\UserReport;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class PlatformStatsOverviewWidget extends BaseWidget
{
    protected static ?int $sort = 1;
    protected int|string|array $columnSpan = 'full';

    /**
     * Computes all platform & matchmaking metrics directly from PostgreSQL aggregate queries.
     * No hardcoded numbers or placeholder values are used.
     */
    public static function computeMetrics(): array
    {
        $totalMembers = User::where('role', 'member')->count();

        $newMembersLast7Days = User::where('role', 'member')
            ->where('created_at', '>=', now()->subDays(7))
            ->count();

        $activeMembers = User::where('role', 'member')
            ->where('account_status', 'active')
            ->where('profile_completed', true)
            ->count();

        $pendingProfiles = UserProfile::whereIn('moderation_status', [
            UserProfile::STATUS_PENDING,
            UserProfile::STATUS_CORRECTION_REQUESTED,
        ])->count();

        $activeSubscriptions = Subscription::whereIn('status', Subscription::ENTITLED_STATUSES)
            ->where(function ($query) {
                $query->whereNull('ends_at')
                    ->orWhere('ends_at', '>', now());
            })
            ->count();

        $expiredSubscriptions = Subscription::where(function ($query) {
            $query->where('status', 'expired')
                ->orWhere(function ($q) {
                    $q->whereNotNull('ends_at')->where('ends_at', '<=', now());
                });
        })->count();

        $verifiedPaymentsSum = (float) PaymentTransaction::where('status', 'succeeded')
            ->where('signature_verified', true)
            ->sum('amount');

        $openReports = UserReport::whereIn('status', [
            UserReport::STATUS_PENDING,
            UserReport::STATUS_UNDER_REVIEW,
        ])->count();

        $pendingMatchmakingRequests = MatchmakingRequest::where('status', MatchmakingRequest::STATUS_PENDING)->count();
        $acceptedMatchmakingRequests = MatchmakingRequest::where('status', MatchmakingRequest::STATUS_ACCEPTED)->count();
        $rejectedMatchmakingRequests = MatchmakingRequest::where('status', MatchmakingRequest::STATUS_REJECTED)->count();

        return [
            'total_members' => $totalMembers,
            'new_members_7d' => $newMembersLast7Days,
            'active_members' => $activeMembers,
            'pending_profiles' => $pendingProfiles,
            'active_subscriptions' => $activeSubscriptions,
            'expired_subscriptions' => $expiredSubscriptions,
            'verified_payments_total' => round($verifiedPaymentsSum, 2),
            'open_reports' => $openReports,
            'pending_matchmaking_requests' => $pendingMatchmakingRequests,
            'accepted_matchmaking_requests' => $acceptedMatchmakingRequests,
            'rejected_matchmaking_requests' => $rejectedMatchmakingRequests,
        ];
    }

    protected function getStats(): array
    {
        $metrics = self::computeMetrics();

        return [
            Stat::make('إجمالي الأعضاء', number_format($metrics['total_members']))
                ->description('إجمالي الحسابات المسجلة في نصيبك')
                ->color('primary'),

            Stat::make('الأعضاء الجدد', number_format($metrics['new_members_7d']))
                ->description('خلال آخر 7 أيام')
                ->color('info'),

            Stat::make('الأعضاء النشطون', number_format($metrics['active_members']))
                ->description('حسابات نشطة ومكتملة البيانات')
                ->color('success'),

            Stat::make('الملفات قيد المراجعة', number_format($metrics['pending_profiles']))
                ->description('تنتظر قرار المشرفين')
                ->color($metrics['pending_profiles'] > 0 ? 'warning' : 'success'),

            Stat::make('الاشتراكات النشطة', number_format($metrics['active_subscriptions']))
                ->description('اشتراكات سارية الصلاحية حالياً')
                ->color('primary'),

            Stat::make('الاشتراكات المنتهية', number_format($metrics['expired_subscriptions']))
                ->description('اشتراكات انتهت صلاحيتها')
                ->color('gray'),

            Stat::make('إجمالي المدفوعات الناجحة', number_format($metrics['verified_payments_total'], 2) . ' ج.م')
                ->description('المدفوعات المؤكدة والموقعة رقمياً فقط')
                ->color('success'),

            Stat::make('طلبات التعارف (قيد الانتظار / مقبولة / مرفوضة)', sprintf(
                '%s / %s / %s',
                number_format($metrics['pending_matchmaking_requests']),
                number_format($metrics['accepted_matchmaking_requests']),
                number_format($metrics['rejected_matchmaking_requests'])
            ))
                ->description('إحصائيات طلبات التعارف الحقيقية')
                ->color('primary'),

            Stat::make('البلاغات المفتوحة', number_format($metrics['open_reports']))
                ->description('بلاغات جديدة أو قيد المراجعة')
                ->color($metrics['open_reports'] > 0 ? 'danger' : 'success'),
        ];
    }
}
