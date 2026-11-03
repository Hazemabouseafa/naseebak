<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentWebhookEvent extends Model
{
    use HasFactory;

    protected $fillable = [
        'provider',
        'provider_event_id',
        'event_type',
        'payment_transaction_id',
        'subscription_id',
        'processing_status',
        'sanitized_payload',
        'processed_at',
    ];

    protected function casts(): array
    {
        return [
            'sanitized_payload' => 'array',
            'processed_at' => 'datetime',
        ];
    }

    public function transaction(): BelongsTo
    {
        return $this->belongsTo(PaymentTransaction::class, 'payment_transaction_id');
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class, 'subscription_id');
    }
}
