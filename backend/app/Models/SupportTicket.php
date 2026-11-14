<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SupportTicket extends Model
{
    use HasFactory;

    public const TYPE_INQUIRY = 'inquiry';
    public const TYPE_COMPLAINT = 'complaint';

    public const TYPES = [
        self::TYPE_INQUIRY,
        self::TYPE_COMPLAINT,
    ];

    public const CATEGORY_GENERAL = 'general';
    public const CATEGORY_ACCOUNT = 'account';
    public const CATEGORY_SUBSCRIPTION = 'subscription';
    public const CATEGORY_TECHNICAL = 'technical';
    public const CATEGORY_BEHAVIOR = 'behavior';
    public const CATEGORY_SUGGESTION = 'suggestion';

    public const CATEGORIES = [
        self::CATEGORY_GENERAL,
        self::CATEGORY_ACCOUNT,
        self::CATEGORY_SUBSCRIPTION,
        self::CATEGORY_TECHNICAL,
        self::CATEGORY_BEHAVIOR,
        self::CATEGORY_SUGGESTION,
    ];

    public const STATUS_OPEN = 'open';
    public const STATUS_IN_PROGRESS = 'in_progress';
    public const STATUS_ANSWERED = 'answered';
    public const STATUS_CLOSED = 'closed';

    public const STATUSES = [
        self::STATUS_OPEN,
        self::STATUS_IN_PROGRESS,
        self::STATUS_ANSWERED,
        self::STATUS_CLOSED,
    ];

    public const OPEN_STATUSES = [
        self::STATUS_OPEN,
        self::STATUS_IN_PROGRESS,
    ];

    public const SENDER_MEMBER = 'member';
    public const SENDER_ADMIN = 'admin';

    protected $fillable = [
        'ticket_number',
        'user_id',
        'type',
        'category',
        'subject',
        'message',
        'status',
        'assigned_admin_id',
        'responded_by_admin_id',
        'admin_reply',
        'responded_at',
        'last_activity_at',
        'last_sender_type',
        'closed_at',
    ];

    protected function casts(): array
    {
        return [
            'responded_at' => 'datetime',
            'last_activity_at' => 'datetime',
            'closed_at' => 'datetime',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id')->withTrashed();
    }

    public function assignedAdmin(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'assigned_admin_id');
    }

    public function respondedByAdmin(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'responded_by_admin_id');
    }

    public function replies(): HasMany
    {
        return $this->hasMany(SupportTicketReply::class, 'support_ticket_id')
            ->orderBy('created_at')
            ->orderBy('id');
    }

    public function isClosed(): bool
    {
        return $this->status === self::STATUS_CLOSED;
    }

    public function awaitingAdminReply(): bool
    {
        return in_array($this->status, self::OPEN_STATUSES, true);
    }

    public static function typeLabels(): array
    {
        return [
            self::TYPE_INQUIRY => 'استفسار',
            self::TYPE_COMPLAINT => 'شكوى',
        ];
    }

    public static function categoryLabels(): array
    {
        return [
            self::CATEGORY_GENERAL => 'استفسار عام',
            self::CATEGORY_ACCOUNT => 'الحساب والملف الشخصي',
            self::CATEGORY_SUBSCRIPTION => 'العضوية والاشتراك',
            self::CATEGORY_TECHNICAL => 'مشكلة تقنية',
            self::CATEGORY_BEHAVIOR => 'شكوى سلوك أو محتوى',
            self::CATEGORY_SUGGESTION => 'اقتراح وتطوير',
        ];
    }

    public static function statusLabels(): array
    {
        return [
            self::STATUS_OPEN => 'جديد / مفتوح',
            self::STATUS_IN_PROGRESS => 'قيد المراجعة',
            self::STATUS_ANSWERED => 'تم الرد',
            self::STATUS_CLOSED => 'مغلق',
        ];
    }

    public function typeLabel(): string
    {
        return self::typeLabels()[$this->type] ?? $this->type;
    }

    public function categoryLabel(): string
    {
        return self::categoryLabels()[$this->category] ?? $this->category;
    }

    public function statusLabel(): string
    {
        return self::statusLabels()[$this->status] ?? $this->status;
    }
}
