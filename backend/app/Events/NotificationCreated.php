<?php

namespace App\Events;

use App\Models\NotificationRecord;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class NotificationCreated implements ShouldBroadcastNow, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly NotificationRecord $notification
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("user.{$this->notification->user_id}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'notification.created';
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->notification->id,
            'event_id' => $this->notification->event_id,
            'event_type' => $this->notification->event_type,
            'title_ar' => $this->notification->title_ar,
            'body_ar' => $this->notification->body_ar,
            'reference_type' => $this->notification->reference_type,
            'reference_id' => $this->notification->reference_id,
            'action_route' => $this->notification->action_route,
            'routing_metadata' => $this->notification->routing_metadata ?? [],
            'is_read' => (bool) $this->notification->is_read,
            'created_at' => $this->notification->created_at?->toIso8601String(),
        ];
    }
}
