<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Subscription extends Model
{
    use HasFactory;

    // Supported payment channels
    public const CHANNEL_GOOGLE_PLAY = 'google_play';
    public const CHANNEL_PAYMOB = 'paymob';
    public const CHANNEL_SHA7NAWY = 'sha7nawy';

    // Backward-compatible provider constant aliases
    public const PROVIDER_GOOGLE_PLAY = self::CHANNEL_GOOGLE_PLAY;
    public const PROVIDER_PAYMOB = self::CHANNEL_PAYMOB;
    public const PROVIDER_SHA7NAWY = self::CHANNEL_SHA7NAWY;

    public const ALLOWED_CHANNELS = [
        self::CHANNEL_GOOGLE_PLAY,
        self::CHANNEL_PAYMOB,
        self::CHANNEL_SHA7NAWY,
    ];

    // Canonical lifecycle states
    public const STATUS_PENDING = 'pending';
    public const STATUS_PENDING_PAYMENT = 'pending_payment'; // Legacy alias mapped to pending
    public const STATUS_ACTIVE = 'active';
    public const STATUS_CANCELLED = 'cancelled';
    public const STATUS_EXPIRED = 'expired';
    public const STATUS_IN_GRACE_PERIOD = 'in_grace_period';
    public const STATUS_GRACE_PERIOD_ALIAS = 'grace_period';
    public const STATUS_ON_HOLD = 'on_hold';
    public const STATUS_REFUNDED = 'refunded';
    public const STATUS_REVOKED = 'revoked';

    public const ENTITLED_STATUSES = [
        self::STATUS_ACTIVE,
        self::STATUS_CANCELLED,
        self::STATUS_IN_GRACE_PERIOD,
        self::STATUS_GRACE_PERIOD_ALIAS,
    ];

    protected $fillable = [
        'user_id',
        'subscription_plan_id',
        'channel',
        'status',
        'external_subscription_id',
        'google_play_purchase_token',
        'google_play_purchase_token_hash',
        'auto_renewing',
        'starts_at',
        'ends_at',
        'grace_period_ends_at',
        'on_hold_at',
        'cancelled_at',
        'expired_at',
        'revoked_at',
        'last_verified_at',
        'verification_metadata',
    ];

    protected $hidden = [
        'google_play_purchase_token',
        'google_play_purchase_token_hash',
    ];

    protected function casts(): array
    {
        return [
            'auto_renewing' => 'boolean',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'grace_period_ends_at' => 'datetime',
            'on_hold_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'expired_at' => 'datetime',
            'revoked_at' => 'datetime',
            'last_verified_at' => 'datetime',
            'verification_metadata' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlan::class, 'subscription_plan_id');
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(PaymentTransaction::class);
    }

    /**
     * Normalizes internal/legacy status aliases into the canonical Phase 5 status strings.
     */
    public function normalizedStatus(): string
    {
        return match ($this->status) {
            self::STATUS_PENDING_PAYMENT => self::STATUS_PENDING,
            self::STATUS_GRACE_PERIOD_ALIAS => self::STATUS_IN_GRACE_PERIOD,
            default => $this->status,
        };
    }

    /**
     * Determines whether this subscription record currently grants paid entitlement
     * based on verified status and current UTC timestamp.
     *
     * Rules:
     * - 'active' and 'cancelled' grant access while ends_at > now()
     * - 'in_grace_period' / 'grace_period' grants access while grace_period_ends_at > now() or ends_at > now()
     * - 'pending', 'on_hold', 'expired', 'refunded', 'revoked' NEVER grant access.
     */
    public function isCurrentlyEntitled(): bool
    {
        $now = now();
        $normalized = $this->normalizedStatus();

        if (in_array($normalized, [self::STATUS_ACTIVE, self::STATUS_CANCELLED], true)) {
            return $this->ends_at !== null && $this->ends_at->greaterThan($now);
        }

        if ($normalized === self::STATUS_IN_GRACE_PERIOD) {
            $effectiveGraceEnd = $this->grace_period_ends_at ?? $this->ends_at;
            return $effectiveGraceEnd !== null && $effectiveGraceEnd->greaterThan($now);
        }

        return false;
    }

    /**
     * Returns the effective expiration timestamp for this subscription record.
     */
    public function effectiveExpirationAt(): ?\Carbon\CarbonInterface
    {
        if ($this->normalizedStatus() === self::STATUS_IN_GRACE_PERIOD && $this->grace_period_ends_at !== null) {
            return $this->grace_period_ends_at;
        }

        return $this->ends_at;
    }
}
