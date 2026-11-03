<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationPreference extends Model
{
    use HasFactory;

    protected $table = 'notification_preferences';

    protected $fillable = [
        'user_id',
        'matchmaking_requests_enabled',
        'messages_enabled',
        'subscriptions_enabled',
        'announcements_enabled',
    ];

    protected function casts(): array
    {
        return [
            'matchmaking_requests_enabled' => 'boolean',
            'messages_enabled' => 'boolean',
            'subscriptions_enabled' => 'boolean',
            'announcements_enabled' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
