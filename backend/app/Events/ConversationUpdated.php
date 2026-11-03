<?php

namespace App\Events;

use App\Models\Conversation;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ConversationUpdated implements ShouldBroadcastNow, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param int[] $recipientUserIds
     */
    public function __construct(
        public readonly Conversation $conversation,
        public readonly array $recipientUserIds
    ) {}

    public function broadcastOn(): array
    {
        return array_map(
            fn (int $userId) => new PrivateChannel("user.{$userId}"),
            array_values(array_unique($this->recipientUserIds))
        );
    }

    public function broadcastAs(): string
    {
        return 'conversation.updated';
    }

    public function broadcastWith(): array
    {
        return [
            'conversation_id' => $this->conversation->id,
            'status' => $this->conversation->status,
            'last_message_id' => $this->conversation->last_message_id,
            'last_message_at' => $this->conversation->last_message_at?->toIso8601String(),
        ];
    }
}
