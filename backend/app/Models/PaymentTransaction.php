<?php

namespace App\Models;

use DomainException;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentTransaction extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_SUCCEEDED = 'succeeded';
    public const STATUS_FAILED = 'failed';
    public const STATUS_REFUNDED = 'refunded';
    public const STATUS_DISPUTED = 'disputed';

    protected $fillable = [
        'idempotency_key',
        'internal_reference',
        'user_id',
        'subscription_id',
        'subscription_plan_id',
        'gateway',
        'gateway_transaction_id',
        'gateway_order_id',
        'amount',
        'amount_minor',
        'currency',
        'status',
        'signature_verified',
        'verified_at',
        'paid_at',
        'gateway_response_summary',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'amount_minor' => 'integer',
            'signature_verified' => 'boolean',
            'verified_at' => 'datetime',
            'paid_at' => 'datetime',
            'gateway_response_summary' => 'array',
        ];
    }

    protected static function booted(): void
    {
        // Payment transaction records are strictly append-only financial history and cannot be deleted
        static::deleting(function () {
            throw new DomainException('سجل المعاملات المالية (PaymentTransaction) غير قابل للحذف نهائياً.');
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlan::class, 'subscription_plan_id');
    }
}
