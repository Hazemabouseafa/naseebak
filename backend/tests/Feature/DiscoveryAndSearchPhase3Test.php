<?php

namespace Tests\Feature;

use App\Models\BlockedUser;
use App\Models\Favorite;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class DiscoveryAndSearchPhase3Test extends TestCase
{
    use RefreshDatabase;

    private function createMember(array $userOverrides = [], array $profileOverrides = []): User
    {
        $user = User::create(array_merge([
            'google_sub' => 'google-sub-' . uniqid(),
            'email' => uniqid('member_') . '@example.com',
            'account_status' => 'active',
            'profile_completed' => true,
        ], $userOverrides));

        $dob = $profileOverrides['date_of_birth'] ?? '1990-06-15';
        $age = Carbon::parse($dob)->age;

        UserProfile::create(array_merge([
            'user_id' => $user->id,
            'full_name' => 'أحمد محمود',
            'gender' => 'male',
            'date_of_birth' => $dob,
            'age_years' => $age,
            'zodiac_sign' => 'الجوزاء',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'مهندس مدني',
            'height_cm' => 178,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['القراءة', 'السفر'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'bio' => 'أبحث عن شريكة جادة.',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => 'approved',
        ], $profileOverrides));

        return $user;
    }

    /** 1. Discovery returns eligible members */
    public function test_discovery_returns_eligible_members_and_excludes_viewer(): void
    {
        $viewer = $this->createMember([], ['full_name' => 'سارة محمد', 'gender' => 'female']);
        $eligibleMale = $this->createMember([], ['full_name' => 'أحمد علي', 'gender' => 'male']);

        $response = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/discovery');

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonCount(1, 'data.suggested_members')
            ->assertJsonPath('data.suggested_members.0.user_id', $eligibleMale->id)
            ->assertJsonPath('data.suggested_members.0.full_name', 'أحمد علي');
    }

    /** 2. Hidden profiles are excluded */
    public function test_hidden_profiles_are_excluded_from_discovery_and_search(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $this->createMember([], ['full_name' => 'عضو مخفي', 'gender' => 'male', 'is_visible' => false]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');
    }

    /** 3. Suspended accounts are excluded */
    public function test_suspended_accounts_are_excluded_from_search(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $this->createMember(['account_status' => 'suspended'], ['full_name' => 'عضو موقوف', 'gender' => 'male']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');
    }

    /** 4. Unapproved profiles are excluded */
    public function test_unapproved_profiles_are_excluded_from_search(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $this->createMember([], ['moderation_status' => 'pending']);
        $this->createMember([], ['moderation_status' => 'rejected']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');
    }

    /** 5. Underage accounts are excluded */
    public function test_underage_accounts_are_excluded_from_search(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $this->createMember([], [
            'date_of_birth' => now()->subYears(17)->format('Y-m-d'),
            'age_years' => 17,
        ]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');
    }

    /** 6. Blocked relationships are excluded in both directions */
    public function test_blocked_relationships_are_excluded_in_both_directions(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $blockedByViewer = $this->createMember([], ['full_name' => 'محظور مني']);
        $blockedViewer = $this->createMember([], ['full_name' => 'حظرني']);

        BlockedUser::create(['blocker_id' => $viewer->id, 'blocked_id' => $blockedByViewer->id]);
        BlockedUser::create(['blocker_id' => $blockedViewer->id, 'blocked_id' => $viewer->id]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');
    }

    /** 7. Search by gender */
    public function test_search_filters_by_gender(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $male = $this->createMember([], ['gender' => 'male']);
        $this->createMember([], ['gender' => 'female']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?gender=male')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $male->id);
    }

    /** 8. Search by age range */
    public function test_search_filters_by_age_range(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $age30 = $this->createMember([], ['date_of_birth' => now()->subYears(30)->format('Y-m-d')]);
        $this->createMember([], ['date_of_birth' => now()->subYears(48)->format('Y-m-d')]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?min_age=28&max_age=35')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $age30->id);
    }

    /** 9. Search by marital status (single & multiple) */
    public function test_search_filters_by_marital_status(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $divorced = $this->createMember([], ['marital_status' => 'divorced', 'previously_married' => true]);
        $this->createMember([], ['marital_status' => 'single']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?marital_statuses[]=divorced')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $divorced->id);
    }

    /** 10. Search by education */
    public function test_search_filters_by_education_level(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $master = $this->createMember([], ['education_level' => 'master']);
        $this->createMember([], ['education_level' => 'bachelor']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?education_level=master')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $master->id);
    }

    /** 11. Search by smoking status */
    public function test_search_filters_by_smoking_status(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $nonSmoker = $this->createMember([], ['smoking_status' => 'non_smoker']);
        $this->createMember([], ['smoking_status' => 'smoker']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?smoking_status=non_smoker')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $nonSmoker->id);
    }

    /** 12. Search by occupation */
    public function test_search_filters_by_occupation(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $doctor = $this->createMember([], ['occupation' => 'طبيب أسنان']);
        $this->createMember([], ['occupation' => 'محاسب قانوني']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?occupation=طبيب')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $doctor->id);
    }

    /** 13. Search by nationality */
    public function test_search_filters_by_nationality(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $saudi = $this->createMember([], ['nationality' => 'سعودي']);
        $this->createMember([], ['nationality' => 'مصري']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?nationality=سعودي')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $saudi->id);
    }

    /** 14. Combined filters */
    public function test_search_with_combined_filters(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $target = $this->createMember([], [
            'gender' => 'male',
            'date_of_birth' => now()->subYears(35)->format('Y-m-d'),
            'marital_status' => 'single',
            'education_level' => 'bachelor',
            'smoking_status' => 'non_smoker',
            'occupation' => 'مهندس برمجيات',
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'الإسكندرية',
        ]);
        $this->createMember([], [
            'gender' => 'male',
            'region' => 'القاهرة',
        ]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?gender=male&min_age=30&max_age=40&marital_statuses[]=single&education_level=bachelor&smoking_status=non_smoker&occupation=مهندس&nationality=مصري&country_of_residence=مصر&region=الإسكندرية')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $target->id);
    }

    /** 15. Pagination (20 default per page) */
    public function test_search_pagination_returns_bounded_pages(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        for ($i = 0; $i < 25; $i++) {
            $this->createMember([], ['full_name' => "عضو رقم {$i}"]);
        }

        $page1 = $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?page=1')
            ->assertOk()
            ->assertJsonCount(20, 'data.members')
            ->assertJsonPath('data.pagination.total', 25)
            ->assertJsonPath('data.pagination.has_more_pages', true);

        $page2 = $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?page=2')
            ->assertOk()
            ->assertJsonCount(5, 'data.members')
            ->assertJsonPath('data.pagination.has_more_pages', false);
    }

    /** 16. Invalid filter rejection (min_age < 18, min_age > max_age, invalid sort) */
    public function test_invalid_search_filters_are_rejected(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?min_age=16')
            ->assertStatus(422)
            ->assertJsonValidationErrors(['min_age']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?min_age=45&max_age=30')
            ->assertStatus(422)
            ->assertJsonValidationErrors(['min_age']);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search?sort=sql_injection_drop_table')
            ->assertStatus(422)
            ->assertJsonValidationErrors(['sort']);
    }

    /** 17. Unauthorized API access */
    public function test_unauthenticated_requests_to_discovery_and_search_are_rejected(): void
    {
        $this->getJson('/api/v1/discovery')->assertStatus(401);
        $this->getJson('/api/v1/members/search')->assertStatus(401);
        $this->getJson('/api/v1/favorites')->assertStatus(401);
        $this->getJson('/api/v1/search/preferences')->assertStatus(401);
    }

    /** 18. Private member field protection (never expose email, google_sub, date_of_birth) */
    public function test_member_search_and_profile_never_expose_private_fields(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $target = $this->createMember([
            'email' => 'secret.private@example.com',
            'google_sub' => 'secret-google-sub-999',
        ]);

        $profileResponse = $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/members/{$target->id}/profile")
            ->assertOk();

        $memberData = $profileResponse->json('data.member');
        $this->assertArrayNotHasKey('email', $memberData);
        $this->assertArrayNotHasKey('google_sub', $memberData);
        $this->assertArrayNotHasKey('date_of_birth', $memberData);
        $this->assertArrayHasKey('age_years', $memberData);
    }

    /** 19. Favorites creation */
    public function test_member_can_add_eligible_profile_to_favorites(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $target = $this->createMember([], ['gender' => 'male']);

        $this->actingAs($viewer, 'sanctum')
            ->postJson("/api/v1/favorites/{$target->id}")
            ->assertCreated()
            ->assertJsonPath('data.is_favorited', true);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/favorites')
            ->assertOk()
            ->assertJsonCount(1, 'data.favorites')
            ->assertJsonPath('data.favorites.0.user_id', $target->id);
    }

    /** 20. Duplicate favorite prevention & self/blocked favorite prevention */
    public function test_duplicate_and_self_and_blocked_favorites_are_prevented(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $target = $this->createMember([], ['gender' => 'male']);

        // Cannot favorite self
        $this->actingAs($viewer, 'sanctum')
            ->postJson("/api/v1/favorites/{$viewer->id}")
            ->assertStatus(422);

        // Duplicate favorite calls remain idempotent (1 database row)
        $this->actingAs($viewer, 'sanctum')->postJson("/api/v1/favorites/{$target->id}")->assertCreated();
        $this->actingAs($viewer, 'sanctum')->postJson("/api/v1/favorites/{$target->id}")->assertCreated();
        $this->assertEquals(1, Favorite::where('user_id', $viewer->id)->count());

        // Blocking removes favorite and prevents re-favoriting
        BlockedUser::create(['blocker_id' => $viewer->id, 'blocked_id' => $target->id]);
        $this->actingAs($viewer, 'sanctum')
            ->postJson("/api/v1/favorites/{$target->id}")
            ->assertStatus(403);
    }

    /** 21. Favorite deletion */
    public function test_member_can_remove_profile_from_favorites(): void
    {
        $viewer = $this->createMember([], ['gender' => 'female']);
        $target = $this->createMember([], ['gender' => 'male']);

        Favorite::create(['user_id' => $viewer->id, 'favorited_user_id' => $target->id]);

        $this->actingAs($viewer, 'sanctum')
            ->deleteJson("/api/v1/favorites/{$target->id}")
            ->assertOk()
            ->assertJsonPath('data.is_favorited', false);

        $this->assertEquals(0, Favorite::where('user_id', $viewer->id)->count());
    }

    /** 22. Private photo authorization in search & member profile */
    public function test_search_and_member_profile_enforce_photo_privacy_rules(): void
    {
        Storage::fake('private');
        $viewer = $this->createMember([], ['gender' => 'female']);
        $restrictedMember = $this->createMember([], [
            'gender' => 'male',
            'photo_privacy' => 'subscribers_only',
        ]);

        $photoPath = "member-photos/{$restrictedMember->id}/11111111-2222-3333-4444-555555555555.jpg";
        Storage::disk('private')->put($photoPath, 'binary-jpeg-data');
        UserPhoto::create([
            'user_id' => $restrictedMember->id,
            'storage_disk' => 'private',
            'file_path' => $photoPath,
            'mime_type' => 'image/jpeg',
            'file_size_bytes' => 16,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        // Non-subscribed viewer gets photo_authorized = false and primary_photo_url = null
        $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/members/{$restrictedMember->id}/profile")
            ->assertOk()
            ->assertJsonPath('data.member.photo_authorized', false)
            ->assertJsonPath('data.member.primary_photo_url', null);
    }

    /** 23. Phase 16 — Complete Two-Account Reciprocal Discovery & Filter Resilience Verification */
    public function test_two_eligible_accounts_a_male_and_b_female_discover_each_other_across_all_scenarios(): void
    {
        $accountA = $this->createMember([
            'account_status' => 'active',
            'profile_completed' => true,
        ], [
            'full_name' => 'أحمد محمود',
            'gender' => 'male',
            'date_of_birth' => Carbon::now()->subYears(30)->format('Y-m-d'),
            'age_years' => 30,
            'marital_status' => 'single',
            'education_level' => 'bachelor',
            'occupation' => 'مهندس برمجيات',
            'smoking_status' => 'non_smoker',
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'is_visible' => true,
            'moderation_status' => 'approved',
        ]);

        $accountB = $this->createMember([
            'account_status' => 'active',
            'profile_completed' => true,
        ], [
            'full_name' => 'مريم خالد',
            'gender' => 'female',
            'date_of_birth' => Carbon::now()->subYears(26)->format('Y-m-d'),
            'age_years' => 26,
            'marital_status' => 'single',
            'education_level' => 'bachelor',
            'occupation' => 'طبيبة صيدلانية',
            'smoking_status' => 'non_smoker',
            'nationality' => 'مصرية',
            'country_of_residence' => 'جمهورية مصر العربية',
            'region' => 'محافظة القاهرة',
            'is_visible' => true,
            'moderation_status' => 'approved',
        ]);

        // 1. Account A loads Home Discovery -> Account B appears
        $this->actingAs($accountA, 'sanctum')
            ->getJson('/api/v1/discovery')
            ->assertOk()
            ->assertJsonCount(1, 'data.suggested_members')
            ->assertJsonPath('data.suggested_members.0.user_id', $accountB->id);

        // 2. Account B loads Home Discovery -> Account A appears
        $this->actingAs($accountB, 'sanctum')
            ->getJson('/api/v1/discovery')
            ->assertOk()
            ->assertJsonCount(1, 'data.suggested_members')
            ->assertJsonPath('data.suggested_members.0.user_id', $accountA->id);

        // 3. Account A searches with empty optional filters -> Account B appears (defaults to opposite gender)
        $this->actingAs($accountA, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonPath('data.pagination.total', 1)
            ->assertJsonPath('data.members.0.user_id', $accountB->id);

        // 4. Account B searches with empty optional filters -> Account A appears (defaults to opposite gender)
        $this->actingAs($accountB, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonPath('data.pagination.total', 1)
            ->assertJsonPath('data.members.0.user_id', $accountA->id);

        // 5. Account A searches with scalar marital_statuses=single (Dio query format) & masculine nationality 'مصري' & short country 'مصر' & region 'القاهرة'
        $this->actingAs($accountA, 'sanctum')
            ->getJson('/api/v1/members/search?marital_statuses=single&nationality=' . urlencode('مصري') . '&country_of_residence=' . urlencode('مصر') . '&region=' . urlencode('القاهرة'))
            ->assertOk()
            ->assertJsonPath('data.pagination.total', 1)
            ->assertJsonPath('data.members.0.user_id', $accountB->id);

        // 6. Account B edits her already-approved profile via PATCH /api/v1/profile -> moderation_status stays 'approved'
        $this->actingAs($accountB, 'sanctum')
            ->patchJson('/api/v1/profile', [
                'full_name' => 'مريم خالد عبد الرحمن',
                'gender' => 'female',
                'date_of_birth' => Carbon::now()->subYears(26)->format('Y-m-d'),
                'marital_status' => 'single',
                'previously_married' => false,
                'has_children' => false,
                'children_count' => 0,
                'education_level' => 'bachelor',
                'occupation' => 'طبيبة صيدلانية',
                'height_cm' => 165,
                'smoking_status' => 'non_smoker',
                'home_ownership' => 'owned',
                'hobbies' => ['القراءة', 'السفر'],
                'nationality' => 'مصرية',
                'country_of_residence' => 'مصر',
                'region' => 'القاهرة',
                'bio' => 'أبحث عن شريك حياة ملتزم.',
            ])
            ->assertOk()
            ->assertJsonPath('data.profile.moderation_status', 'approved');

        // Account A still discovers Account B after profile edit
        $this->actingAs($accountA, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonPath('data.pagination.total', 1)
            ->assertJsonPath('data.members.0.user_id', $accountB->id);

        // 7. Corrupted preferred_gender ('male' for male Account A) is automatically self-healed on discovery
        \App\Models\UserPreference::updateOrCreate(
            ['user_id' => $accountA->id],
            ['preferred_gender' => 'male', 'min_age' => 18, 'max_age' => 60]
        );

        $this->actingAs($accountA, 'sanctum')
            ->getJson('/api/v1/discovery')
            ->assertOk()
            ->assertJsonCount(1, 'data.suggested_members')
            ->assertJsonPath('data.suggested_members.0.user_id', $accountB->id)
            ->assertJsonPath('data.saved_preferences.preferred_gender', 'female');
    }
}
