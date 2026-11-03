<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SubscriptionPlan extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name_ar',
        'description_ar',
        'duration_days',
        'google_play_product_id',
        'web_price_amount',
        'web_price_currency',
        'is_active',
        'features_ar',
    ];

    protected function casts(): array
    {
        return [
            'duration_days' => 'integer',
            'web_price_amount' => 'decimal:2',
            'is_active' => 'boolean',
            'features_ar' => 'array',
        ];
    }
}
