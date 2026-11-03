<?php

namespace App\Events;

use App\Models\MatchmakingRequest;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MatchmakingRequestCreated implements ShouldBroadcastNow, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly MatchmakingRequest $matchmakingRequest
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->matchmakingRequest->recipient_id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'matchmaking.request.created';
    }

    public function broadcastWhen(): bool
    {
        $recipient = $this->matchmakingRequest->recipient;
        return $recipient !== null && $recipient->account_status === 'active';
    }

    public function broadcastWith(): array
    {
        return [
            'request_id' => $this->matchmakingRequest->id,
            'sender_id' => $this->matchmakingRequest->sender_id,
            'recipient_id' => $this->matchmakingRequest->recipient_id,
            'status' => $this->matchmakingRequest->status,
            'created_at' => $this->matchmakingRequest->created_at?->toIso8601String(),
        ];
    }
}
