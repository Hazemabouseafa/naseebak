<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Conversation extends Model
{
    use HasFactory;

    public const STATUS_ACTIVE = 'active';
    public const STATUS_BLOCKED = 'blocked';
    public const STATUS_CLOSED = 'closed';

    protected $fillable = [
        'matchmaking_request_id',
        'user_one_id',
        'user_two_id',
        'status',
        'last_message_at',
        'last_message_id',
    ];

    protected function casts(): array
    {
        return [
            'last_message_at' => 'datetime',
        ];
    }

    public function matchmakingRequest(): BelongsTo
    {
        return $this->belongsTo(MatchmakingRequest::class);
    }

    public function userOne(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_one_id')->withTrashed();
    }

    public function userTwo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_two_id')->withTrashed();
    }

    public function participants(): HasMany
    {
        return $this->hasMany(ConversationParticipant::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    public function lastMessage(): BelongsTo
    {
        return $this->belongsTo(Message::class, 'last_message_id');
    }

    /**
     * Returns the canonical ascending pair for two user IDs.
     *
     * @return array{user_one_id: int, user_two_id: int, 0: int, 1: int}
     */
    public static function canonicalPair(int $userAId, int $userBId): array
    {
        $low = min($userAId, $userBId);
        $high = max($userAId, $userBId);

        return [
            'user_one_id' => $low,
            'user_two_id' => $high,
            0 => $low,
            1 => $high,
        ];
    }

    /**
     * Checks if a given user ID is a participant in this conversation.
     */
    public function hasParticipant(int $userId): bool
    {
        if ($this->user_one_id !== null && $this->user_two_id !== null) {
            return (int) $this->user_one_id === $userId || (int) $this->user_two_id === $userId;
        }

        return $this->participants()->where('user_id', $userId)->exists();
    }
}
