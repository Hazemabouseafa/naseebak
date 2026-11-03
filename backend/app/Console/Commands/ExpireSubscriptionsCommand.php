<?php

namespace App\Console\Commands;

use App\Jobs\DispatchAnnouncementCampaignJob;
use App\Models\AnnouncementCampaign;
use App\Services\Notification\NotificationService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Illuminate\Console\Command;

class ExpireSubscriptionsCommand extends Command
{
    protected $signature = 'naseebak:expire-subscriptions';

    protected $description = 'فحص الاشتراكات المنتهية، وإرسال تذكيرات اقتراب الانتهاء، وتشغيل الحملات المجدولة وتنظيف السجلات القديمة';

    public function handle(
        SubscriptionEntitlementService $entitlementService,
        NotificationService $notificationService
    ): int {
        $expiredCount = $entitlementService->expireElapsedSubscriptionsBatch();
        $remindersCount = $entitlementService->dispatchApproachingExpirationRemindersBatch();

        // Dispatch any scheduled announcement campaigns whose scheduled_at has arrived
        $dueCampaigns = AnnouncementCampaign::where('status', AnnouncementCampaign::STATUS_SCHEDULED)
            ->whereNotNull('scheduled_at')
            ->where('scheduled_at', '<=', now())
            ->get();

        foreach ($dueCampaigns as $campaign) {
            $campaign->update(['status' => AnnouncementCampaign::STATUS_QUEUED]);
            DispatchAnnouncementCampaignJob::dispatch($campaign->id);
        }

        $cleanup = $notificationService->cleanupOldNotifications();

        $this->info(
            "تم تحديث ({$expiredCount}) اشتراكاً منتهياً، وإرسال ({$remindersCount}) تذكيراً، وتنظيف ({$cleanup['deleted_notifications']}) إشعاراً قديماً."
        );

        return self::SUCCESS;
    }
}
