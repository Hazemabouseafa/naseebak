<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class AnnouncementCampaign extends Model
{
    use HasFactory;

    protected $table = 'announcement_campaigns';

    protected static function booted(): void
    {
        static::creating(function (self $campaign) {
            if (empty($campaign->idempotency_key)) {
                $campaign->idempotency_key = (string) Str::uuid();
            }
        });
    }

    public const AUDIENCE_ALL_ELIGIBLE = 'all_eligible_members';
    public const AUDIENCE_ACTIVE_SUBSCRIBERS = 'active_subscribers';
    public const AUDIENCE_EXPIRED_SUBSCRIBERS = 'expired_subscribers';

    // Segment alias constants
    public const SEGMENT_ALL_ACTIVE_MEMBERS = self::AUDIENCE_ALL_ELIGIBLE;
    public const SEGMENT_ACTIVE_SUBSCRIBERS = self::AUDIENCE_ACTIVE_SUBSCRIBERS;
    public const SEGMENT_EXPIRED_SUBSCRIBERS = self::AUDIENCE_EXPIRED_SUBSCRIBERS;

    public const ALLOWED_AUDIENCES = [
        self::AUDIENCE_ALL_ELIGIBLE,
        self::AUDIENCE_ACTIVE_SUBSCRIBERS,
        self::AUDIENCE_EXPIRED_SUBSCRIBERS,
    ];

    public const STATUS_DRAFT = 'draft';
    public const STATUS_SCHEDULED = 'scheduled';
    public const STATUS_QUEUED = 'queued';
    public const STATUS_PROCESSING = 'processing';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'created_by_admin_id',
        'title_ar',
        'body_ar',
        'audience',
        'target_segment',
        'action_route',
        'status',
        'scheduled_at',
        'dispatched_at',
        'completed_at',
        'eligible_recipients_count',
        'queued_count',
        'submitted_to_fcm_count',
        'rejected_by_fcm_count',
        'confirmed_read_count',
        'idempotency_key',
    ];

    public function setTargetSegmentAttribute(?string $value): void
    {
        if ($value !== null) {
            $this->attributes['audience'] = $value;
        }
    }

    public function getTargetSegmentAttribute(): ?string
    {
        return $this->attributes['audience'] ?? null;
    }

    public function getDispatchedCountAttribute(): int
    {
        return (int) ($this->attributes['queued_count'] ?? 0);
    }

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'dispatched_at' => 'datetime',
            'completed_at' => 'datetime',
            'eligible_recipients_count' => 'integer',
            'queued_count' => 'integer',
            'submitted_to_fcm_count' => 'integer',
            'rejected_by_fcm_count' => 'integer',
            'confirmed_read_count' => 'integer',
        ];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'created_by_admin_id');
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(NotificationRecord::class, 'campaign_id');
    }
}
