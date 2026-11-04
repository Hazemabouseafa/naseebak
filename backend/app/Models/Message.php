<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Message extends Model
{
    use HasFactory;

    public const STATUS_SENT = 'delivered_server';
    public const STATUS_DELIVERED = 'delivered_recipient';
    public const STATUS_READ = 'read';

    protected $fillable = [
        'conversation_id',
        'sender_id',
        'client_message_id',
        'body',
        'is_read',
        'delivered_at',
        'read_at',
    ];

    protected function casts(): array
    {
        return [
            'is_read' => 'boolean',
            'delivered_at' => 'datetime',
            'read_at' => 'datetime',
        ];
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id')->withTrashed();
    }

    /**
     * Computes the authoritative message delivery status:
     * - 'read'                => recipient has read the message (or participant cursor >= message.id)
     * - 'delivered_recipient' => recipient client acknowledged delivery
     * - 'delivered_server'    => persisted in PostgreSQL on the server
     */
    public function deliveryStatus(?int $recipientLastReadMessageId = null, ?int $recipientLastDeliveredMessageId = null): string
    {
        if (
            $this->is_read
            || $this->read_at !== null
            || ($recipientLastReadMessageId !== null && $recipientLastReadMessageId >= (int) $this->id)
        ) {
            return 'read';
        }

        if (
            $this->delivered_at !== null
            || ($recipientLastDeliveredMessageId !== null && $recipientLastDeliveredMessageId >= (int) $this->id)
        ) {
            return 'delivered_recipient';
        }

        return 'delivered_server';
    }
}
