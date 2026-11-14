<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements FilamentUser
{
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    protected $fillable = [
        'google_sub',
        'email',
        'email_verified',
        'role',
        'account_status',
        'suspension_reason',
        'suspended_at',
        'profile_completed',
        'admin_password_hash',
        'mfa_secret',
        'last_active_at',
        'deletion_requested_at',
    ];

    protected $hidden = [
        'google_sub',
        'admin_password_hash',
        'mfa_secret',
    ];

    protected function casts(): array
    {
        return [
            'email_verified' => 'boolean',
            'profile_completed' => 'boolean',
            'suspended_at' => 'datetime',
            'last_active_at' => 'datetime',
            'deletion_requested_at' => 'datetime',
        ];
    }

    /**
     * Regular User records cannot access the Filament Admin Panel (administrators use the separate Administrator model).
     */
    public function canAccessPanel(Panel $panel): bool
    {
        return false;
    }

    public function getAuthPassword(): string
    {
        return (string) $this->admin_password_hash;
    }

    public function isSuspended(): bool
    {
        return $this->account_status === 'suspended';
    }

    /**
     * Checks server-side whether the member currently has a verified active subscription entitlement.
     * Supports 'active', 'cancelled' (until ends_at expires), and 'in_grace_period' / 'grace_period'.
     * Excludes 'pending', 'pending_payment', 'on_hold', 'expired', 'refunded', and 'revoked'.
     */
    public function hasActiveSubscription(): bool
    {
        if ($this->account_status !== 'active') {
            return false;
        }

        $now = now();

        return $this->subscriptions()
            ->where(function ($query) use ($now) {
                $query->where(function ($q) use ($now) {
                    $q->whereIn('status', [
                        Subscription::STATUS_ACTIVE,
                        Subscription::STATUS_CANCELLED,
                    ])->whereNotNull('ends_at')
                      ->where('ends_at', '>', $now);
                })->orWhere(function ($q) use ($now) {
                    $q->whereIn('status', [
                        Subscription::STATUS_IN_GRACE_PERIOD,
                        Subscription::STATUS_GRACE_PERIOD_ALIAS,
                    ])->where(function ($graceQ) use ($now) {
                        $graceQ->where(function ($g1) use ($now) {
                            $g1->whereNotNull('grace_period_ends_at')
                                ->where('grace_period_ends_at', '>', $now);
                        })->orWhere(function ($g2) use ($now) {
                            $g2->whereNull('grace_period_ends_at')
                                ->whereNotNull('ends_at')
                                ->where('ends_at', '>', $now);
                        });
                    });
                });
            })
            ->exists();
    }

    public function canSendMatchRequest(): bool
    {
        return $this->account_status === 'active'
            && (bool) $this->profile_completed
            && $this->hasActiveSubscription();
    }

    public function canSendMessage(): bool
    {
        return $this->account_status === 'active'
            && (bool) $this->profile_completed
            && $this->hasActiveSubscription();
    }

    public function profile(): HasOne
    {
        return $this->hasOne(UserProfile::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(UserPhoto::class);
    }

    public function preferences(): HasOne
    {
        return $this->hasOne(UserPreference::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    public function activeSubscription(): HasOne
    {
        return $this->hasOne(Subscription::class)
            ->whereIn('status', Subscription::ENTITLED_STATUSES)
            ->where(function ($query) {
                $query->where('ends_at', '>', now())
                    ->orWhere('grace_period_ends_at', '>', now());
            })
            ->latestOfMany('ends_at');
    }

    public function paymentTransactions(): HasMany
    {
        return $this->hasMany(PaymentTransaction::class);
    }

    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }

    public function notificationRecords(): HasMany
    {
        return $this->hasMany(NotificationRecord::class, 'user_id');
    }

    public function notificationPreference(): HasOne
    {
        return $this->hasOne(NotificationPreference::class, 'user_id');
    }

    public function sentMatchmakingRequests(): HasMany
    {
        return $this->hasMany(MatchmakingRequest::class, 'sender_id');
    }

    public function receivedMatchmakingRequests(): HasMany
    {
        return $this->hasMany(MatchmakingRequest::class, 'recipient_id');
    }

    public function supportTickets(): HasMany
    {
        return $this->hasMany(SupportTicket::class, 'user_id');
    }
}
