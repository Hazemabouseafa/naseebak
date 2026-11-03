<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceToken extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'token_fingerprint',
        'fcm_token',
        'device_platform',
        'device_model',
        'app_version',
        'os_version',
        'is_valid',
        'invalidated_reason',
        'invalidated_at',
        'last_registered_at',
        'last_delivery_attempt_at',
    ];

    protected $hidden = [
        'fcm_token',
    ];

    protected function casts(): array
    {
        return [
            'is_valid' => 'boolean',
            'invalidated_at' => 'datetime',
            'last_registered_at' => 'datetime',
            'last_delivery_attempt_at' => 'datetime',
        ];
    }

    public static function computeFingerprint(string $rawToken): string
    {
        return hash('sha256', trim($rawToken));
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
