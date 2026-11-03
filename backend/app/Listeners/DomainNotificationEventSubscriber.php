<?php

namespace App\Listeners;

use App\Events\MatchmakingRequestAccepted;
use App\Events\MatchmakingRequestCreated;
use App\Events\MatchmakingRequestRejected;
use App\Events\MessageSent;
use App\Services\Notification\NotificationService;
use Illuminate\Events\Dispatcher;

class DomainNotificationEventSubscriber
{
    public function __construct(
        private readonly NotificationService $notificationService
    ) {}

    public function handleMatchmakingRequestCreated(MatchmakingRequestCreated $event): void
    {
        $this->notificationService->notifyMatchmakingRequestCreated($event->matchmakingRequest);
    }

    public function handleMatchmakingRequestAccepted(MatchmakingRequestAccepted $event): void
    {
        $this->notificationService->notifyMatchmakingRequestAccepted(
            $event->matchmakingRequest,
            $event->conversation
        );
    }

    public function handleMatchmakingRequestRejected(MatchmakingRequestRejected $event): void
    {
        $this->notificationService->notifyMatchmakingRequestRejected($event->matchmakingRequest);
    }

    public function handleMessageSent(MessageSent $event): void
    {
        $this->notificationService->notifyPrivateMessageSent(
            $event->conversation,
            $event->message,
            $event->recipientUserId
        );
    }

    public function subscribe(Dispatcher $events): array
    {
        return [
            MatchmakingRequestCreated::class => 'handleMatchmakingRequestCreated',
            MatchmakingRequestAccepted::class => 'handleMatchmakingRequestAccepted',
            MatchmakingRequestRejected::class => 'handleMatchmakingRequestRejected',
            MessageSent::class => 'handleMessageSent',
        ];
    }
}
