<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class UserProfile extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_CORRECTION_REQUESTED = 'correction_requested';

    public const ALLOWED_MODERATION_STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_APPROVED,
        self::STATUS_REJECTED,
        self::STATUS_CORRECTION_REQUESTED,
    ];

    protected $fillable = [
        'user_id',
        'full_name',
        'gender',
        'date_of_birth',
        'age_years',
        'zodiac_sign',
        'marital_status',
        'previously_married',
        'has_children',
        'children_count',
        'education_level',
        'occupation',
        'height_cm',
        'smoking_status',
        'home_ownership',
        'hobbies',
        'nationality',
        'country_of_residence',
        'region',
        'bio',
        'is_visible',
        'photo_privacy',
        'moderation_status',
        'moderation_notes',
        'moderated_by',
        'moderated_by_admin_id',
        'moderated_at',
    ];

    protected function casts(): array
    {
        return [
            'date_of_birth' => 'date:Y-m-d',
            'age_years' => 'integer',
            'previously_married' => 'boolean',
            'has_children' => 'boolean',
            'children_count' => 'integer',
            'height_cm' => 'integer',
            'hobbies' => 'array',
            'is_visible' => 'boolean',
            'moderated_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function moderatedByAdmin(): BelongsTo
    {
        return $this->belongsTo(Administrator::class, 'moderated_by_admin_id');
    }

    public function moderationHistories(): HasMany
    {
        return $this->hasMany(ModerationHistory::class, 'target_id')
            ->where('target_type', self::class)
            ->orderByDesc('created_at');
    }

    /**
     * Checks whether administrator profile moderation is required before discovery.
     * Defaults to true (strict moderation) unless explicitly disabled in AppSetting.
     */
    public static function isModerationRequired(): bool
    {
        try {
            $setting = AppSetting::where('setting_key', 'require_profile_moderation')->first();
            if ($setting !== null && is_array($setting->setting_value) && array_key_exists('enabled', $setting->setting_value)) {
                return (bool) $setting->setting_value['enabled'];
            }
        } catch (\Throwable) {
            // Fallback to strict moderation if settings table is not yet available
        }

        return true;
    }

    /**
     * Checks whether this profile satisfies the moderation policy for member discovery.
     */
    public function isModerationApprovedForDiscovery(): bool
    {
        if (self::isModerationRequired()) {
            return $this->moderation_status === self::STATUS_APPROVED;
        }

        return $this->moderation_status !== self::STATUS_REJECTED;
    }

    /**
     * Determines whether this profile satisfies moderation and visibility requirements for member discovery.
     */
    public function isDiscoverableByMembers(): bool
    {
        if (!$this->is_visible || (int) $this->age_years < 18) {
            return false;
        }

        return $this->isModerationApprovedForDiscovery();
    }

    /**
     * Calculate exact age in years from date of birth.
     */
    public static function calculateAgeYears(string|Carbon $dateOfBirth): int
    {
        $dob = $dateOfBirth instanceof Carbon ? $dateOfBirth : Carbon::parse($dateOfBirth);
        return $dob->age;
    }

    /**
     * Calculate Arabic zodiac sign (البرج الفلكي) automatically from month and day.
     */
    public static function calculateArabicZodiacSign(string|Carbon $dateOfBirth): string
    {
        $dob = $dateOfBirth instanceof Carbon ? $dateOfBirth : Carbon::parse($dateOfBirth);
        $month = (int) $dob->format('n');
        $day = (int) $dob->format('j');

        return match (true) {
            ($month === 3 && $day >= 21) || ($month === 4 && $day <= 19) => 'الحمل',
            ($month === 4 && $day >= 20) || ($month === 5 && $day <= 20) => 'الثور',
            ($month === 5 && $day >= 21) || ($month === 6 && $day <= 20) => 'الجوزاء',
            ($month === 6 && $day >= 21) || ($month === 7 && $day <= 22) => 'السرطان',
            ($month === 7 && $day >= 23) || ($month === 8 && $day <= 22) => 'الأسد',
            ($month === 8 && $day >= 23) || ($month === 9 && $day <= 22) => 'العذراء',
            ($month === 9 && $day >= 23) || ($month === 10 && $day <= 22) => 'الميزان',
            ($month === 10 && $day >= 23) || ($month === 11 && $day <= 21) => 'العقرب',
            ($month === 11 && $day >= 22) || ($month === 12 && $day <= 21) => 'القوس',
            ($month === 12 && $day >= 22) || ($month === 1 && $day <= 19) => 'الجدي',
            ($month === 1 && $day >= 20) || ($month === 2 && $day <= 18) => 'الدلو',
            default => 'الحوت',
        };
    }
}
