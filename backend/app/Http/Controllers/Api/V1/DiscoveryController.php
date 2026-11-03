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
        $defaultOppositeGender = null;
        if ($viewer->profile?->gender === 'male') {
            $defaultOppositeGender = 'female';
        } elseif ($viewer->profile?->gender === 'female') {
            $defaultOppositeGender = 'male';
        }

        $filters = [
            'gender' => $preferences?->preferred_gender ?? $defaultOppositeGender,
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

        // If strict saved preferences yield 0 results, fall back to recent eligible members (preserving gender preference if set)
        if ($suggestedProfiles->isEmpty()) {
            $fallbackQuery = $this->searchQueryService->buildEligibleProfilesQuery($viewer);
            if (!empty($filters['gender'])) {
                $fallbackQuery->where('user_profiles.gender', '=', $filters['gender']);
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
        $filters = $request->normalizedFilters();

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

        $defaultOppositeGender = null;
        if ($viewer->profile?->gender === 'male') {
            $defaultOppositeGender = 'female';
        } elseif ($viewer->profile?->gender === 'female') {
            $defaultOppositeGender = 'male';
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
        $validated = $request->validated();

        $smokingStatus = $validated['smoking_status'] ?? null;
        if ($smokingStatus === 'all') {
            $smokingStatus = null;
        }

        $preferences = UserPreference::updateOrCreate(
            ['user_id' => $viewer->id],
            [
                'preferred_gender' => $validated['preferred_gender'] ?? null,
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
                'preferences' => $this->formatPreferencesPayload($preferences, null),
            ],
        ]);
    }

    private function persistPreferencesFromFilters(User $viewer, array $filters): void
    {
        UserPreference::updateOrCreate(
            ['user_id' => $viewer->id],
            [
                'preferred_gender' => $filters['gender'],
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
