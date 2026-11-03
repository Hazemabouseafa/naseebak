<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ConversationParticipant extends Model
{
    use HasFactory;

    protected $fillable = [
        'conversation_id',
        'user_id',
        'unread_count',
        'last_read_message_id',
        'last_read_at',
        'last_delivered_message_id',
        'last_delivered_at',
    ];

    protected function casts(): array
    {
        return [
            'unread_count' => 'integer',
            'last_read_message_id' => 'integer',
            'last_read_at' => 'datetime',
            'last_delivered_message_id' => 'integer',
            'last_delivered_at' => 'datetime',
        ];
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
