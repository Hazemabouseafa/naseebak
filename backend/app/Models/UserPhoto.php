<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class UserPhoto extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';

    protected $fillable = [
        'user_id',
        'storage_disk',
        'file_path',
        'mime_type',
        'file_size_bytes',
        'is_primary',
        'moderation_status',
        'moderation_notes',
        'moderated_by_admin_id',
        'moderated_at',
    ];

    protected function casts(): array
    {
        return [
            'file_size_bytes' => 'integer',
            'is_primary' => 'boolean',
            'moderated_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function moderatedByAdmin(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'moderated_by_admin_id');
    }

    public function moderationHistories(): HasMany
    {
        return $this->hasMany(ModerationHistory::class, 'target_id')
            ->where('target_type', self::class)
            ->orderByDesc('created_at');
    }

    /**
     * Checks whether this photo satisfies the moderation policy for display to authorized members.
     * When strict moderation is required (default), only 'approved' photos are displayed.
     * When require_profile_moderation is disabled in AppSetting, non-rejected photos are displayed.
     */
    public function isModerationApprovedForDisplay(): bool
    {
        if (UserProfile::isModerationRequired()) {
            return $this->moderation_status === self::STATUS_APPROVED;
        }

        return $this->moderation_status !== self::STATUS_REJECTED;
    }
}
