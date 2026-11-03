<?php

namespace App\Models;

use DomainException;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ModerationHistory extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'administrator_id',
        'target_type',
        'target_id',
        'previous_status',
        'new_status',
        'reason',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::updating(function () {
            throw new DomainException('سجل قرارات المراجعة غير قابل للتعديل.');
        });

        static::deleting(function () {
            throw new DomainException('سجل قرارات المراجعة غير قابل للحذف.');
        });
    }

    public function administrator(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'administrator_id');
    }
}
