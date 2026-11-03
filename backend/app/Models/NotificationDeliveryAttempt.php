<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationDeliveryAttempt extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $table = 'notification_delivery_attempts';

    protected $fillable = [
        'notification_id',
        'device_token_id',
        'attempt_number',
        'status',
        'http_status',
        'fcm_error_code',
        'fcm_message_id',
        'attempted_at',
    ];

    protected function casts(): array
    {
        return [
            'attempt_number' => 'integer',
            'http_status' => 'integer',
            'attempted_at' => 'datetime',
        ];
    }

    public function notification(): BelongsTo
    {
        return $this->belongsTo(NotificationRecord::class, 'notification_id');
    }

    public function deviceToken(): BelongsTo
    {
        return $this->belongsTo(DeviceToken::class, 'device_token_id');
    }
}
