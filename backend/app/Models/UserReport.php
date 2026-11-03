<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserReport extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_UNDER_REVIEW = 'under_review';
    public const STATUS_RESOLVED = 'resolved';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_DISMISSED = 'dismissed';

    protected $fillable = [
        'reporter_id',
        'reported_user_id',
        'conversation_id',
        'message_id',
        'reason_category',
        'details',
        'status',
        'assigned_moderator_id',
        'resolution_notes',
        'reviewed_by',
        'reviewed_by_admin_id',
        'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'reviewed_at' => 'datetime',
        ];
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function reportedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_user_id');
    }

    public function assignedModerator(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'assigned_moderator_id');
    }

    public function reviewedByAdmin(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'reviewed_by_admin_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
