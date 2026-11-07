<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SearchMembersRequest;
use App\Http\Requests\Api\V1\UpdateSearchPreferencesRequest;
use App\Models\User;
use App\Models\UserPreference;
use App\Services\Discovery\MemberSearchQueryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DiscoveryController extends Controller
{
    public function __construct(
        private readonly MemberSearchQueryService $searchQueryService,
    ) {}

    /**
     * GET /api/v1/discovery
     *
     * Returns suggested eligible members for Screen 07 (Home / Discover).
     * Uses real database records matching saved preferences (or recent eligible members of opposite gender by default)
     * without generating fake users or artificial compatibility percentages.
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();
        $viewer->loadMissing(['profile', 'preferences']);

        $preferences = $viewer->preferences;
        $defaultOppositeGender = $this->resolveOppositeGender($viewer);

        // Self-heal any corrupted preferred_gender that was accidentally saved as viewer's own gender
        if (
            $preferences !== null
            && $defaultOppositeGender !== null
            && $preferences->preferred_gender === $viewer->profile?->gender
        ) {
            $preferences->update(['preferred_gender' => $defaultOppositeGender]);
        }

        $targetGender = $defaultOppositeGender ?? $preferences?->preferred_gender;

        $filters = [
            'gender' => $targetGender,
            'min_age' => $preferences?->min_age ?? 18,
            'max_age' => $preferences?->max_age ?? 65,
            'marital_statuses' => $preferences?->marital_statuses ?? [],
            'education_level' => $preferences?->education_level,
            'smoking_status' => $preferences?->smoking_status,
            'occupation' => $preferences?->occupation,
            'nationality' => $preferences?->nationality,
            'country_of_residence' => $preferences?->country_of_residence,
            'region' => $preferences?->region,
            'sort' => 'newest',
        ];

        $query = $this->searchQueryService->buildEligibleProfilesQuery($viewer);
        $this->searchQueryService->applySearchFilters($query, $filters);

        $suggestedProfiles = $query->limit(15)->get();

        // If strict saved preferences yield 0 results, fall back to recent eligible members (preserving opposite gender preference)
        if ($suggestedProfiles->isEmpty()) {
            $fallbackQuery = $this->searchQueryService->buildEligibleProfilesQuery($viewer);
            if (!empty($targetGender)) {
                $fallbackQuery->where('user_profiles.gender', '=', $targetGender);
            }
            $fallbackQuery->orderByDesc('user_profiles.created_at')
                ->orderByDesc('user_profiles.id');
            $suggestedProfiles = $fallbackQuery->limit(15)->get();
        }

        $formattedSuggested = $this->searchQueryService
            ->formatMemberCardsCollection($viewer, $suggestedProfiles)
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'suggested_members' => $formattedSuggested,
                'saved_preferences' => $this->formatPreferencesPayload($preferences, $defaultOppositeGender),
            ],
        ]);
    }

    /**
     * GET /api/v1/members/search
     *
     * Server-side PostgreSQL search & pagination for Screen 08 & Screen 09.
     */
    public function search(SearchMembersRequest $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();
        $viewer->loadMissing('profile');

        $filters = $request->normalizedFilters();
        $defaultOppositeGender = $this->resolveOppositeGender($viewer);

        if (empty($filters['gender']) && $defaultOppositeGender !== null) {
            $filters['gender'] = $defaultOppositeGender;
        }

        // Optionally persist preferences when user initiates search from Screen 08
        if ($request->boolean('save_preferences', false)) {
            $this->persistPreferencesFromFilters($viewer, $filters);
        }

        $query = $this->searchQueryService->buildEligibleProfilesQuery($viewer);
        $this->searchQueryService->applySearchFilters($query, $filters);

        $paginator = $this->searchQueryService->paginateFormattedMembers(
            $viewer,
            $query,
            $filters['per_page']
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'members' => $paginator->items(),
                'applied_filters' => $filters,
                'pagination' => [
                    'current_page' => $paginator->currentPage(),
                    'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(),
                    'total' => $paginator->total(),
                    'has_more_pages' => $paginator->hasMorePages(),
                ],
            ],
        ]);
    }

    /**
     * GET /api/v1/search/preferences
     */
    public function getSearchPreferences(Request $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();
        $viewer->loadMissing(['profile', 'preferences']);

        $defaultOppositeGender = $this->resolveOppositeGender($viewer);
        if (
            $viewer->preferences !== null
            && $defaultOppositeGender !== null
            && $viewer->preferences->preferred_gender === $viewer->profile?->gender
        ) {
            $viewer->preferences->update(['preferred_gender' => $defaultOppositeGender]);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'preferences' => $this->formatPreferencesPayload($viewer->preferences, $defaultOppositeGender),
            ],
        ]);
    }

    /**
     * PUT /api/v1/search/preferences
     */
    public function updateSearchPreferences(UpdateSearchPreferencesRequest $request): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();
        $viewer->loadMissing('profile');
        $validated = $request->validated();
        $defaultOppositeGender = $this->resolveOppositeGender($viewer);

        $smokingStatus = $validated['smoking_status'] ?? null;
        if ($smokingStatus === 'all') {
            $smokingStatus = null;
        }

        $preferredGender = $validated['preferred_gender'] ?? $defaultOppositeGender;

        $preferences = UserPreference::updateOrCreate(
            ['user_id' => $viewer->id],
            [
                'preferred_gender' => $preferredGender,
                'min_age' => (int) $validated['min_age'],
                'max_age' => (int) $validated['max_age'],
                'marital_statuses' => !empty($validated['marital_statuses'])
                    ? array_values(array_unique($validated['marital_statuses']))
                    : null,
                'education_level' => $validated['education_level'] ?? null,
                'smoking_status' => $smokingStatus,
                'occupation' => isset($validated['occupation']) && trim($validated['occupation']) !== ''
                    ? trim($validated['occupation'])
                    : null,
                'nationality' => isset($validated['nationality']) && trim($validated['nationality']) !== ''
                    ? trim($validated['nationality'])
                    : null,
                'country_of_residence' => isset($validated['country_of_residence']) && trim($validated['country_of_residence']) !== ''
                    ? trim($validated['country_of_residence'])
                    : null,
                'region' => isset($validated['region']) && trim($validated['region']) !== ''
                    ? trim($validated['region'])
                    : null,
            ]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'تم حفظ تفضيلات البحث بنجاح.',
            'data' => [
                'preferences' => $this->formatPreferencesPayload($preferences, $defaultOppositeGender),
            ],
        ]);
    }

    private function resolveOppositeGender(User $viewer): ?string
    {
        return match ($viewer->profile?->gender) {
            'male' => 'female',
            'female' => 'male',
            default => null,
        };
    }

    private function persistPreferencesFromFilters(User $viewer, array $filters): void
    {
        $defaultOppositeGender = $this->resolveOppositeGender($viewer);
        $preferredGender = $filters['gender'] ?? $defaultOppositeGender;
        if ($defaultOppositeGender !== null && $preferredGender === $viewer->profile?->gender) {
            $preferredGender = $defaultOppositeGender;
        }

        UserPreference::updateOrCreate(
            ['user_id' => $viewer->id],
            [
                'preferred_gender' => $preferredGender,
                'min_age' => $filters['min_age'] ?? 18,
                'max_age' => $filters['max_age'] ?? 60,
                'marital_statuses' => !empty($filters['marital_statuses'])
                    ? $filters['marital_statuses']
                    : null,
                'education_level' => $filters['education_level'],
                'smoking_status' => $filters['smoking_status'],
                'occupation' => $filters['occupation'],
                'nationality' => $filters['nationality'],
                'country_of_residence' => $filters['country_of_residence'],
                'region' => $filters['region'],
            ]
        );
    }

    private function formatPreferencesPayload(?UserPreference $pref, ?string $defaultGender): array
    {
        return [
            'preferred_gender' => $pref?->preferred_gender ?? $defaultGender,
            'min_age' => $pref ? (int) $pref->min_age : 18,
            'max_age' => $pref ? (int) $pref->max_age : 60,
            'marital_statuses' => $pref?->marital_statuses ?? [],
            'education_level' => $pref?->education_level,
            'smoking_status' => $pref?->smoking_status,
            'occupation' => $pref?->occupation,
            'nationality' => $pref?->nationality,
            'country_of_residence' => $pref?->country_of_residence,
            'region' => $pref?->region,
        ];
    }
}
