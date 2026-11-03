<?php

namespace App\Models;

use DomainException;
use Filament\Models\Contracts\FilamentUser;
use Filament\Models\Contracts\HasName;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class Administrator extends Authenticatable implements FilamentUser, HasName
{
    use HasFactory, Notifiable;

    public const ROLE_SUPER_ADMIN = 'super_admin';
    public const ROLE_MODERATOR = 'moderator';

    public const ALLOWED_ROLES = [
        self::ROLE_SUPER_ADMIN,
        self::ROLE_MODERATOR,
    ];

    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'is_active',
        'mfa_enabled',
        'mfa_secret',
        'mfa_recovery_codes',
        'mfa_verified_at',
        'last_login_at',
        'last_login_ip',
        'suspension_reason',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'mfa_secret',
        'mfa_recovery_codes',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'is_active' => 'boolean',
            'mfa_enabled' => 'boolean',
            'mfa_secret' => 'encrypted',
            'mfa_recovery_codes' => 'encrypted:array',
            'mfa_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        // Safeguard: Prevent demoting or deactivating the final active Super Administrator
        static::updating(function (Administrator $admin) {
            $wasActiveSuperAdmin = $admin->getOriginal('role') === self::ROLE_SUPER_ADMIN
                && (bool) $admin->getOriginal('is_active') === true;

            $willCeaseBeingActiveSuperAdmin = $admin->role !== self::ROLE_SUPER_ADMIN
                || !$admin->is_active;

            if ($wasActiveSuperAdmin && $willCeaseBeingActiveSuperAdmin) {
                $remainingActiveSuperAdmins = self::where('role', self::ROLE_SUPER_ADMIN)
                    ->where('is_active', true)
                    ->where('id', '!=', $admin->id)
                    ->count();

                if ($remainingActiveSuperAdmins === 0) {
                    throw new DomainException('لا يمكن إيقاف أو تخفيض صلاحية المدير العام الوحيد النشط في النظام.');
                }
            }
        });

        // Safeguard: Prevent deleting the final active Super Administrator
        static::deleting(function (Administrator $admin) {
            if ($admin->role === self::ROLE_SUPER_ADMIN && $admin->is_active) {
                $remainingActiveSuperAdmins = self::where('role', self::ROLE_SUPER_ADMIN)
                    ->where('is_active', true)
                    ->where('id', '!=', $admin->id)
                    ->count();

                if ($remainingActiveSuperAdmins === 0) {
                    throw new DomainException('لا يمكن حذف المدير العام الوحيد النشط في النظام.');
                }
            }
        });
    }

    public function canAccessPanel(Panel $panel): bool
    {
        return $this->is_active
            && in_array($this->role, self::ALLOWED_ROLES, true);
    }

    public function getFilamentName(): string
    {
        return $this->name;
    }

    public function isSuperAdmin(): bool
    {
        return $this->is_active && $this->role === self::ROLE_SUPER_ADMIN;
    }

    public function isModerator(): bool
    {
        return $this->is_active && $this->role === self::ROLE_MODERATOR;
    }

    public function hasRoleOrHigher(string $requiredRole): bool
    {
        if (!$this->is_active) {
            return false;
        }

        if ($this->role === self::ROLE_SUPER_ADMIN) {
            return true;
        }

        return $this->role === $requiredRole;
    }

    public function auditLogs(): HasMany
    {
        return $this->hasMany(AdminAuditLog::class, 'administrator_id');
    }

    public function moderationHistories(): HasMany
    {
        return $this->hasMany(ModerationHistory::class, 'administrator_id');
    }
}
