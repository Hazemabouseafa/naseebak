<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class NotificationRecord extends Model
{
    use HasFactory;

    protected $table = 'notifications';

    public const TYPE_NEW_MATCHMAKING_REQUEST = 'new_matchmaking_request';
    public const TYPE_ACCEPTED_MATCHMAKING_REQUEST = 'accepted_matchmaking_request';
    public const TYPE_REJECTED_MATCHMAKING_REQUEST = 'rejected_matchmaking_request';
    public const TYPE_NEW_PRIVATE_MESSAGE = 'new_private_message';
    public const TYPE_SUBSCRIPTION_ACTIVATED = 'subscription_activated';
    public const TYPE_SUBSCRIPTION_EXPIRING_SOON = 'subscription_expiring_soon';
    public const TYPE_SUBSCRIPTION_EXPIRED = 'subscription_expired';
    public const TYPE_ADMIN_ANNOUNCEMENT = 'admin_announcement';
    public const TYPE_SUPPORT_REPLY = 'support_reply';

    public const ROUTE_MATCHMAKING_INCOMING = 'matchmaking_incoming';
    public const ROUTE_MATCHMAKING_ACCEPTED = 'matchmaking_accepted';
    public const ROUTE_MATCHMAKING_SENT = 'matchmaking_sent';
    public const ROUTE_CONVERSATION = 'conversation';
    public const ROUTE_SUBSCRIPTION = 'subscription';
    public const ROUTE_NOTIFICATION_CENTER = 'notification_center';
    public const ROUTE_SUPPORT_TICKET = 'support_ticket';

    public const ALLOWED_ROUTES = [
        self::ROUTE_MATCHMAKING_INCOMING,
        self::ROUTE_MATCHMAKING_ACCEPTED,
        self::ROUTE_MATCHMAKING_SENT,
        self::ROUTE_CONVERSATION,
        self::ROUTE_SUBSCRIPTION,
        self::ROUTE_NOTIFICATION_CENTER,
        self::ROUTE_SUPPORT_TICKET,
    ];

    public const DELIVERY_QUEUED = 'queued';
    public const DELIVERY_SUBMITTED_TO_FCM = 'submitted_to_fcm';
    public const DELIVERY_REJECTED_BY_FCM = 'rejected_by_fcm';
    public const DELIVERY_FAILED_TRANSIENT = 'failed_transient';
    public const DELIVERY_NO_ACTIVE_DEVICES = 'no_active_devices';
    public const DELIVERY_DISABLED_BY_PREFERENCE = 'disabled_by_preference';
    public const DELIVERY_SKIPPED_FOREGROUND = 'skipped_foreground';
    public const DELIVERY_CONFIRMED_OPENED = 'confirmed_opened';

    protected $fillable = [
        'event_id',
        'deduplication_key',
        'user_id',
        'event_type',
        'title_ar',
        'body_ar',
        'reference_type',
        'reference_id',
        'action_route',
        'routing_metadata',
        'campaign_id',
        'is_read',
        'read_at',
        'fcm_delivery_status',
        'delivery_attempts',
        'last_delivery_attempt_at',
        'fcm_submitted_at',
        'fcm_error_code',
    ];

    protected function casts(): array
    {
        return [
            'routing_metadata' => 'array',
            'is_read' => 'boolean',
            'read_at' => 'datetime',
            'delivery_attempts' => 'integer',
            'last_delivery_attempt_at' => 'datetime',
            'fcm_submitted_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(AnnouncementCampaign::class, 'campaign_id');
    }

    public function deliveryAttemptLogs(): HasMany
    {
        return $this->hasMany(NotificationDeliveryAttempt::class, 'notification_id');
    }
}
