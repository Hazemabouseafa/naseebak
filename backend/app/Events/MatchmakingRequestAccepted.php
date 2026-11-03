<?php

namespace App\Events;

use App\Models\Conversation;
use App\Models\MatchmakingRequest;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MatchmakingRequestAccepted implements ShouldBroadcastNow, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly MatchmakingRequest $matchmakingRequest,
        public readonly Conversation $conversation
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->matchmakingRequest->sender_id),
            new PrivateChannel('user.' . $this->matchmakingRequest->recipient_id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'matchmaking.request.accepted';
    }

    public function broadcastWith(): array
    {
        return [
            'request_id' => $this->matchmakingRequest->id,
            'conversation_id' => $this->conversation->id,
            'sender_id' => $this->matchmakingRequest->sender_id,
            'recipient_id' => $this->matchmakingRequest->recipient_id,
            'status' => $this->matchmakingRequest->status,
            'responded_at' => $this->matchmakingRequest->responded_at?->toIso8601String(),
        ];
    }
}
