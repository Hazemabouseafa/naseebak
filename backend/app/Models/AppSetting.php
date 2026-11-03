<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AppSetting extends Model
{
    use HasFactory;

    protected $fillable = [
        'setting_key',
        'setting_value',
        'description_ar',
        'updated_by',
        'updated_by_admin_id',
    ];

    protected function casts(): array
    {
        return [
            'setting_value' => 'array',
        ];
    }

    public function updatedByAdmin(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'updated_by_admin_id');
    }
}
