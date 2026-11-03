<?php

namespace App\Jobs;

use App\Models\AnnouncementCampaign;
use App\Services\Notification\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class DispatchAnnouncementCampaignJob implements ShouldQueue, ShouldBeUnique
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public int $uniqueFor = 600;

    public function __construct(
        public readonly int $campaignId
    ) {
        $this->afterCommit();
    }

    public function uniqueId(): string
    {
        return "dispatch_announcement_campaign_{$this->campaignId}";
    }

    public function handle(NotificationService $notificationService): void
    {
        $campaign = AnnouncementCampaign::find($this->campaignId);
        if (!$campaign) {
            return;
        }

        $notificationService->processQueuedAnnouncementCampaign($campaign);
    }
}
