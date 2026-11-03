<?php

namespace App\Jobs;

use App\Models\AnnouncementCampaign;
use App\Models\NotificationRecord;
use App\Services\Notification\FcmNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendPushNotificationJob implements ShouldQueue, ShouldBeUnique
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 4;

    public int $uniqueFor = 300;

    /**
     * Exponential backoff intervals in seconds for transient FCM HTTP v1 failures.
     *
     * @var array<int, int>
     */
    public array $backoff = [15, 60, 180];

    public function __construct(
        public readonly int $notificationId
    ) {
        $this->afterCommit();
    }

    public function uniqueId(): string
    {
        return "send_push_notification_{$this->notificationId}";
    }

    public function handle(FcmNotificationService $fcmService): void
    {
        $notification = NotificationRecord::with('user')->find($this->notificationId);
        if (!$notification) {
            return;
        }

        // Idempotency guard: never re-send if already submitted to FCM, opened, or disabled by preference
        if (in_array($notification->fcm_delivery_status, [
            NotificationRecord::DELIVERY_SUBMITTED_TO_FCM,
            NotificationRecord::DELIVERY_CONFIRMED_OPENED,
            NotificationRecord::DELIVERY_DISABLED_BY_PREFERENCE,
        ], true)) {
            return;
        }

        $attemptNumber = max(1, $this->attempts());
        $result = $fcmService->sendNotificationToUserDevices($notification, $attemptNumber);

        // Update campaign statistics when applicable
        if ($notification->campaign_id !== null) {
            if ($result['status'] === NotificationRecord::DELIVERY_SUBMITTED_TO_FCM) {
                AnnouncementCampaign::where('id', $notification->campaign_id)
                    ->increment('submitted_to_fcm_count');
            } elseif (
                !$result['should_retry']
                && in_array($result['status'], [
                    NotificationRecord::DELIVERY_REJECTED_BY_FCM,
                    NotificationRecord::DELIVERY_NO_ACTIVE_DEVICES,
                ], true)
            ) {
                AnnouncementCampaign::where('id', $notification->campaign_id)
                    ->increment('rejected_by_fcm_count');
            }
        }

        if ($result['should_retry'] && $attemptNumber < $this->tries) {
            $delay = $this->backoff[$attemptNumber - 1] ?? 180;
            $this->release($delay);
        }
    }
}
