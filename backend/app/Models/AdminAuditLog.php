<?php

namespace App\Models;

use DomainException;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminAuditLog extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'administrator_id',
        'admin_user_id',
        'action',
        'target_type',
        'target_id',
        'previous_values',
        'new_values',
        'ip_address',
        'justification',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'previous_values' => 'array',
            'new_values' => 'array',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        // Append-only enforcement: Audit log records can NEVER be modified or deleted
        static::updating(function () {
            throw new DomainException('سجل النشاط الإداري (AdminAuditLog) غير قابل للتعديل نهائياً.');
        });

        static::deleting(function () {
            throw new DomainException('سجل النشاط الإداري (AdminAuditLog) غير قابل للحذف نهائياً.');
        });
    }

    public function administrator(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'administrator_id');
    }

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_user_id');
    }
}
