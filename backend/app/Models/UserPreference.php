<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserPreference extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'preferred_gender',
        'min_age',
        'max_age',
        'marital_statuses',
        'education_level',
        'smoking_status',
        'occupation',
        'nationality',
        'country_of_residence',
        'region',
        'notify_new_requests',
        'notify_accepted_requests',
        'notify_new_messages',
        'notify_subscription_alerts',
        'notify_announcements',
    ];

    protected function casts(): array
    {
        return [
            'min_age' => 'integer',
            'max_age' => 'integer',
            'marital_statuses' => 'array',
            'notify_new_requests' => 'boolean',
            'notify_accepted_requests' => 'boolean',
            'notify_new_messages' => 'boolean',
            'notify_subscription_alerts' => 'boolean',
            'notify_announcements' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
