<?php

namespace App\Services\Discovery;

use App\Models\BlockedUser;
use App\Models\Favorite;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Services\Profile\ProfileAccessControlService;
use Carbon\Carbon;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

class MemberSearchQueryService
{
    public function __construct(
        private readonly ProfileAccessControlService $accessControlService,
    ) {}

    /**
     * Builds the base Eloquent query on UserProfile enforcing all 9 mandatory exclusions:
     * 1. Exclude currently authenticated user
     * 2. Exclude suspended users (account_status != 'active')
     * 3. Exclude banned / pending_deletion / deleted users
     * 4. Exclude hidden profiles (is_visible = false)
     * 5. Exclude unapproved profiles (moderation_status != 'approved')
     * 6. Exclude underage users (date_of_birth > now - 18 years AND age_years < 18)
     * 7. Exclude users blocked by the current user
     * 8. Exclude users who have blocked the current user
     * 9. Exclude soft-deleted or incomplete accounts (users.deleted_at IS NULL AND profile_completed = true)
     */
    public function buildEligibleProfilesQuery(User $viewer): Builder
    {
        $maxAdultBirthDate = Carbon::now()->subYears(18)->format('Y-m-d');

        $query = UserProfile::query()
            ->select([
                'user_profiles.id',
                'user_profiles.user_id',
                'user_profiles.full_name',
                'user_profiles.gender',
                'user_profiles.date_of_birth',
                'user_profiles.age_years',
                'user_profiles.zodiac_sign',
                'user_profiles.marital_status',
                'user_profiles.education_level',
                'user_profiles.occupation',
                'user_profiles.smoking_status',
                'user_profiles.nationality',
                'user_profiles.country_of_residence',
                'user_profiles.region',
                'user_profiles.is_visible',
                'user_profiles.photo_privacy',
                'user_profiles.moderation_status',
                'user_profiles.created_at',
            ])
            ->join('users', 'users.id', '=', 'user_profiles.user_id')
            ->where('user_profiles.user_id', '!=', $viewer->id)
            ->whereNull('users.deleted_at')
            ->where('users.account_status', '=', 'active')
            ->where('users.profile_completed', '=', true)
            ->where('user_profiles.is_visible', '=', true);

        if (UserProfile::isModerationRequired()) {
            $query->where('user_profiles.moderation_status', '=', UserProfile::STATUS_APPROVED);
        } else {
            $query->where('user_profiles.moderation_status', '!=', UserProfile::STATUS_REJECTED);
        }

        return $query
            ->where('user_profiles.age_years', '>=', 18)
            ->whereDate('user_profiles.date_of_birth', '<=', $maxAdultBirthDate)
            ->whereNotExists(function ($subQuery) use ($viewer) {
                $subQuery->selectRaw('1')
                    ->from('blocked_users')
                    ->where(function ($q) use ($viewer) {
                        $q->where('blocked_users.blocker_id', '=', $viewer->id)
                            ->whereColumn('blocked_users.blocked_id', 'user_profiles.user_id');
                    })
                    ->orWhere(function ($q) use ($viewer) {
                        $q->where('blocked_users.blocked_id', '=', $viewer->id)
                            ->whereColumn('blocked_users.blocker_id', 'user_profiles.user_id');
                    });
            });
    }

    /**
     * Applies parameterized search filters and deterministic secondary sorting to the eligible query.
     */
    public function applySearchFilters(Builder $query, array $filters): Builder
    {
        if (!empty($filters['gender'])) {
            $query->where('user_profiles.gender', '=', $filters['gender']);
        }

        // Accurate age filtering using both date_of_birth boundaries and indexed age_years
        if (!empty($filters['min_age'])) {
            $minAge = max(18, (int) $filters['min_age']);
            $maxBirthDateForMinAge = Carbon::now()->subYears($minAge)->format('Y-m-d');
            $query->whereDate('user_profiles.date_of_birth', '<=', $maxBirthDateForMinAge);
        }

        if (!empty($filters['max_age'])) {
            $maxAge = (int) $filters['max_age'];
            $minBirthDateForMaxAge = Carbon::now()->subYears($maxAge + 1)->addDay()->format('Y-m-d');
            $query->whereDate('user_profiles.date_of_birth', '>=', $minBirthDateForMaxAge);
        }

        if (!empty($filters['marital_statuses']) && is_array($filters['marital_statuses'])) {
            $query->whereIn('user_profiles.marital_status', $filters['marital_statuses']);
        }

        if (!empty($filters['education_level'])) {
            $query->where('user_profiles.education_level', '=', $filters['education_level']);
        }

        if (!empty($filters['smoking_status']) && $filters['smoking_status'] !== 'all') {
            $query->where('user_profiles.smoking_status', '=', $filters['smoking_status']);
        }

        if (!empty($filters['occupation'])) {
            $escapedOccupation = addcslashes(mb_strtolower($filters['occupation']), '%_');
            $query->whereRaw('LOWER(user_profiles.occupation) LIKE ?', ['%' . $escapedOccupation . '%']);
        }

        if (!empty($filters['nationality'])) {
            $nationalityVariants = $this->resolveNationalityVariants((string) $filters['nationality']);
            $query->whereIn('user_profiles.nationality', $nationalityVariants);
        }

        if (!empty($filters['country_of_residence'])) {
            $countryVariants = $this->resolveCountryVariants((string) $filters['country_of_residence']);
            $query->whereIn('user_profiles.country_of_residence', $countryVariants);
        }

        if (!empty($filters['region'])) {
            $regionVariants = $this->resolveRegionVariants((string) $filters['region']);
            $query->whereIn('user_profiles.region', $regionVariants);
        }

        // Deterministic sorting with secondary key (user_profiles.id) to prevent pagination duplicates
        $sort = $filters['sort'] ?? 'newest';
        match ($sort) {
            // Younger first -> more recent date_of_birth first
            'age_asc' => $query->orderByDesc('user_profiles.date_of_birth')
                ->orderByDesc('user_profiles.id'),
            // Older first -> earlier date_of_birth first
            'age_desc' => $query->orderBy('user_profiles.date_of_birth')
                ->orderByDesc('user_profiles.id'),
            default => $query->orderByDesc('user_profiles.created_at')
                ->orderByDesc('user_profiles.id'),
        };

        return $query;
    }

    /**
     * Executes paginated search and formats member cards without N+1 queries
     * or exposing any private account fields (email, google_sub, date_of_birth, etc.).
     */
    public function paginateFormattedMembers(
        User $viewer,
        Builder $query,
        int $perPage = 20
    ): LengthAwarePaginator {
        $boundedPerPage = max(1, min(50, $perPage));
        $paginator = $query->paginate($boundedPerPage);

        $profiles = collect($paginator->items());
        $formattedItems = $this->formatMemberCardsCollection($viewer, $profiles);

        $paginator->setCollection($formattedItems);
        return $paginator;
    }

    /**
     * Formats a collection of UserProfile models into safe public member card arrays,
     * eager-loading primary photos and favorite status in bulk to prevent N+1 queries.
     */
    public function formatMemberCardsCollection(User $viewer, Collection $profiles): Collection
    {
        if ($profiles->isEmpty()) {
            return collect();
        }

        $userIds = $profiles->pluck('user_id')->unique()->values()->all();

        // Bulk load approved primary photos
        $primaryPhotosByUser = UserPhoto::whereIn('user_id', $userIds)
            ->where('is_primary', true)
            ->where('moderation_status', 'approved')
            ->with('user.profile')
            ->get()
            ->keyBy('user_id');

        // Bulk load viewer's favorited user IDs
        $favoritedIds = Favorite::where('user_id', $viewer->id)
            ->whereIn('favorited_user_id', $userIds)
            ->pluck('favorited_user_id')
            ->flip();

        return $profiles->map(function (UserProfile $profile) use ($viewer, $primaryPhotosByUser, $favoritedIds) {
            /** @var ?UserPhoto $primaryPhoto */
            $primaryPhoto = $primaryPhotosByUser->get($profile->user_id);

            $canSeePhoto = $primaryPhoto !== null
                && $this->accessControlService->canAccessPhoto($viewer, $primaryPhoto);

            return [
                'user_id' => (int) $profile->user_id,
                'full_name' => $profile->full_name,
                'gender' => $profile->gender,
                'age_years' => UserProfile::calculateAgeYears($profile->date_of_birth),
                'marital_status' => $profile->marital_status,
                'education_level' => $profile->education_level,
                'occupation' => $profile->occupation,
                'smoking_status' => $profile->smoking_status,
                'nationality' => $profile->nationality,
                'country_of_residence' => $profile->country_of_residence,
                'region' => $profile->region,
                'photo_privacy' => $profile->photo_privacy,
                'photo_authorized' => $canSeePhoto,
                'primary_photo_id' => ($primaryPhoto && $canSeePhoto) ? (int) $primaryPhoto->id : null,
                'primary_photo_url' => ($primaryPhoto && $canSeePhoto)
                    ? url("/api/v1/profile/photos/{$primaryPhoto->id}/stream")
                    : null,
                'is_favorited' => $favoritedIds->has($profile->user_id),
            ];
        });
    }

    /**
     * Expands an Arabic nationality term to include both masculine and feminine inflections
     * (e.g. 'مصري' <-> 'مصرية', 'سعودي' <-> 'سعودية') so gender inflection differences
     * never exclude eligible members.
     *
     * @return array<int, string>
     */
    private function resolveNationalityVariants(string $nationality): array
    {
        $trimmed = trim($nationality);
        if ($trimmed === '') {
            return [];
        }

        $variants = [$trimmed];

        // Strip trailing feminine taa marbuta / haa to obtain masculine stem
        $stem = preg_replace('/[ةه]$/u', '', $trimmed) ?? $trimmed;
        if ($stem !== '') {
            $variants[] = $stem;
            $variants[] = $stem . 'ة';
            $variants[] = $stem . 'ه';
        }

        // Common country-name / nisba synonyms
        $synonymGroups = [
            ['مصري', 'مصرية', 'مصريه', 'مصر'],
            ['سعودي', 'سعودية', 'سعوديه', 'السعودية'],
            ['إماراتي', 'إماراتية', 'اماراتي', 'اماراتية', 'الإمارات', 'الامارات'],
            ['أردني', 'أردنية', 'اردني', 'اردنية', 'الأردن', 'الاردن'],
            ['كويتي', 'كويتية', 'الكويت'],
            ['قطري', 'قطرية', 'قطر'],
            ['بحريني', 'بحرينية', 'البحرين'],
            ['عماني', 'عمانية', 'عُماني', 'عُمانية', 'عمان', 'سلطنة عمان'],
            ['مغربي', 'مغربية', 'المغرب'],
            ['تونسي', 'تونسية', 'تونس'],
            ['جزائري', 'جزائرية', 'الجزائر'],
            ['سوداني', 'سودانية', 'السودان'],
            ['سوري', 'سورية', 'سوريا'],
            ['لبناني', 'لبنانية', 'لبنان'],
            ['فلسطيني', 'فلسطينية', 'فلسطين'],
            ['عراقي', 'عراقية', 'العراق'],
            ['يمني', 'يمنية', 'اليمن'],
            ['ليبي', 'ليبية', 'ليبيا'],
        ];

        foreach ($synonymGroups as $group) {
            if (in_array($trimmed, $group, true) || in_array($stem, $group, true)) {
                $variants = array_merge($variants, $group);
            }
        }

        return array_values(array_unique(array_filter($variants, fn (string $v) => $v !== '')));
    }

    /**
     * Expands common Arabic country names to include short and official forms.
     *
     * @return array<int, string>
     */
    private function resolveCountryVariants(string $country): array
    {
        $trimmed = trim($country);
        if ($trimmed === '') {
            return [];
        }

        $variants = [$trimmed];

        $countryGroups = [
            ['مصر', 'جمهورية مصر العربية'],
            ['السعودية', 'المملكة العربية السعودية'],
            ['الإمارات', 'الامارات', 'الإمارات العربية المتحدة', 'الامارات العربية المتحدة'],
            ['الأردن', 'الاردن', 'المملكة الأردنية الهاشمية'],
            ['الكويت', 'دولة الكويت'],
            ['قطر', 'دولة قطر'],
            ['البحرين', 'مملكة البحرين'],
            ['عمان', 'سلطنة عمان', 'سلطنة عُمان'],
            ['المغرب', 'المملكة المغربية'],
            ['تونس', 'الجمهورية التونسية'],
            ['الجزائر', 'الجمهورية الجزائرية'],
            ['السودان', 'جمهورية السودان'],
        ];

        foreach ($countryGroups as $group) {
            if (in_array($trimmed, $group, true)) {
                $variants = array_merge($variants, $group);
            }
        }

        return array_values(array_unique($variants));
    }

    /**
     * Expands an Arabic region/governorate name to match with or without 'محافظة ' / 'منطقة ' prefixes.
     *
     * @return array<int, string>
     */
    private function resolveRegionVariants(string $region): array
    {
        $trimmed = trim($region);
        if ($trimmed === '') {
            return [];
        }

        $base = preg_replace('/^(محافظة|منطقة|مدينة)\s+/u', '', $trimmed) ?? $trimmed;
        $base = trim($base);

        return array_values(array_unique(array_filter([
            $trimmed,
            $base,
            'محافظة ' . $base,
            'منطقة ' . $base,
            'مدينة ' . $base,
        ], fn (string $v) => $v !== '')));
    }
}
