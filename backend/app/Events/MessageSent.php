<?php

namespace App\Events;

use App\Models\BlockedUser;
use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcastNow, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly Message $message,
        public readonly Conversation $conversation,
        public readonly int $recipientUserId
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('conversation.' . $this->conversation->id),
            new PrivateChannel('user.' . $this->recipientUserId),
        ];
    }

    public function broadcastAs(): string
    {
        return 'message.sent';
    }

    /**
     * Security check: Avoid broadcasting new private content to recipients whose
     * access has been revoked, suspended, or blocked.
     */
    public function broadcastWhen(): bool
    {
        if ($this->conversation->status !== Conversation::STATUS_ACTIVE) {
            return false;
        }

        $senderId = (int) $this->message->sender_id;
        $recipientId = (int) $this->recipientUserId;

        $isBlocked = BlockedUser::where(function ($q) use ($senderId, $recipientId) {
            $q->where('blocker_id', $senderId)->where('blocked_id', $recipientId);
        })->orWhere(function ($q) use ($senderId, $recipientId) {
            $q->where('blocker_id', $recipientId)->where('blocked_id', $senderId);
        })->exists();

        return !$isBlocked;
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->message->id,
            'conversation_id' => $this->message->conversation_id,
            'sender_id' => $this->message->sender_id,
            'client_message_id' => $this->message->client_message_id,
            'body' => $this->message->body,
            'is_read' => (bool) $this->message->is_read,
            'delivery_status' => 'delivered_server',
            'created_at' => $this->message->created_at?->toIso8601String(),
        ];
    }
}
