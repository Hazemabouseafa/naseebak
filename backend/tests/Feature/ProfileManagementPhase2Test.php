<?php

namespace Tests\Feature;

use App\Models\BlockedUser;
use App\Models\MatchmakingRequest;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProfileManagementPhase2Test extends TestCase
{
    use RefreshDatabase;

    private function createMemberWithProfile(array $userOverrides = [], array $profileOverrides = []): User
    {
        $user = User::create(array_merge([
            'google_sub' => 'google-sub-' . uniqid(),
            'email' => uniqid('member_') . '@example.com',
            'account_status' => 'active',
            'profile_completed' => true,
        ], $userOverrides));

        UserProfile::create(array_merge([
            'user_id' => $user->id,
            'full_name' => 'سارة محمد',
            'gender' => 'female',
            'date_of_birth' => '1992-06-15',
            'age_years' => 34,
            'zodiac_sign' => 'الجوزاء',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'مهندسة معمارية',
            'height_cm' => 165,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['القراءة', 'التصميم'],
            'nationality' => 'مصرية',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'bio' => 'أبحث عن شريك جاد لبناء أسرة مستقرة.',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => 'approved',
        ], $profileOverrides));

        return $user;
    }

    /** 1. Reading the authenticated profile */
    public function test_authenticated_user_can_read_own_profile(): void
    {
        $user = $this->createMemberWithProfile();

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/profile');

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.profile_completed', true)
            ->assertJsonPath('data.profile.full_name', 'سارة محمد')
            ->assertJsonPath('data.profile.occupation', 'مهندسة معمارية')
            ->assertJsonPath('data.privacy.is_visible', true)
            ->assertJsonPath('data.privacy.photo_privacy', 'public');
    }

    /** 2. Editing profile fields */
    public function test_authenticated_user_can_edit_profile_fields(): void
    {
        $user = $this->createMemberWithProfile();

        $response = $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/profile', [
                'full_name' => 'سارة محمد عبد الرحمن',
                'gender' => 'female',
                'date_of_birth' => '1990-04-25',
                'marital_status' => 'divorced',
                'previously_married' => true,
                'has_children' => true,
                'children_count' => 1,
                'education_level' => 'master',
                'occupation' => 'استشارية هندسية',
                'height_cm' => 167,
                'smoking_status' => 'non_smoker',
                'home_ownership' => 'owned',
                'hobbies' => ['القراءة', 'السفر'],
                'nationality' => 'مصرية',
                'country_of_residence' => 'مصر',
                'region' => 'الجيزة',
                'bio' => 'نبذة محدثة بعد التعديل.',
            ]);

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.profile.full_name', 'سارة محمد عبد الرحمن')
            ->assertJsonPath('data.profile.marital_status', 'divorced')
            ->assertJsonPath('data.profile.zodiac_sign', 'الثور')
            ->assertJsonPath('data.profile.education_level', 'master')
            ->assertJsonPath('data.profile.region', 'الجيزة');
    }

    /** 3. Rejecting invalid input (marital status inconsistency & invalid height) */
    public function test_editing_profile_rejects_inconsistent_marital_status_and_invalid_height(): void
    {
        $user = $this->createMemberWithProfile();

        $response = $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/profile', [
                'full_name' => 'سارة محمد',
                'gender' => 'female',
                'date_of_birth' => '1992-06-15',
                'marital_status' => 'divorced',
                'previously_married' => false, // Invalid: divorced requires previously_married = true
                'has_children' => false,
                'education_level' => 'bachelor',
                'occupation' => 'مهندسة',
                'height_cm' => 95, // Invalid: < 120 cm
                'smoking_status' => 'non_smoker',
                'home_ownership' => 'owned',
                'hobbies' => ['القراءة'],
                'nationality' => 'مصرية',
                'country_of_residence' => 'مصر',
                'region' => 'القاهرة',
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['height_cm']);
    }

    /** 4. Rejecting underage registration/update (< 18 years old) */
    public function test_editing_profile_rejects_underage_date_of_birth(): void
    {
        $user = $this->createMemberWithProfile();

        $response = $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/profile', [
                'full_name' => 'سارة محمد',
                'gender' => 'female',
                'date_of_birth' => now()->subYears(16)->format('Y-m-d'),
                'marital_status' => 'single',
                'previously_married' => false,
                'has_children' => false,
                'education_level' => 'high_school',
                'occupation' => 'طالبة',
                'height_cm' => 160,
                'smoking_status' => 'non_smoker',
                'home_ownership' => 'family_home',
                'hobbies' => ['القراءة'],
                'nationality' => 'مصرية',
                'country_of_residence' => 'مصر',
                'region' => 'القاهرة',
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['date_of_birth']);
    }

    /** 5. Uploading valid profile images and cleaning up replaced orphan files */
    public function test_uploading_valid_profile_photo_stores_in_private_storage_and_cleans_up_previous_primary(): void
    {
        Storage::fake('private');
        $user = $this->createMemberWithProfile();

        $firstImage = UploadedFile::fake()->image('avatar1.jpg', 600, 600);
        $firstResponse = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/profile/photo', [
                'photo' => $firstImage,
                'is_primary' => true,
            ]);

        $firstResponse->assertCreated()
            ->assertJsonPath('status', 'success');

        $firstPhoto = UserPhoto::where('user_id', $user->id)->firstOrFail();
        Storage::disk('private')->assertExists($firstPhoto->file_path);

        // Upload replacement primary photo -> old file must be deleted (no orphan files)
        $secondImage = UploadedFile::fake()->image('avatar2.png', 800, 800);
        $secondResponse = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/profile/photo', [
                'photo' => $secondImage,
                'is_primary' => true,
            ]);

        $secondResponse->assertCreated();
        Storage::disk('private')->assertMissing($firstPhoto->file_path);
        $this->assertEquals(1, UserPhoto::where('user_id', $user->id)->count());
    }

    /** 6. Rejecting invalid file types (spoofed extension or non-image binary) */
    public function test_uploading_non_image_file_is_rejected(): void
    {
        Storage::fake('private');
        $user = $this->createMemberWithProfile();

        $fakeScript = UploadedFile::fake()->create('malicious.php.jpg', 120, 'text/plain');

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/profile/photo', [
                'photo' => $fakeScript,
            ]);

        $response->assertStatus(422);
    }

    /** 7. Rejecting oversized uploads (> 2 MB / 2048 KB) */
    public function test_uploading_oversized_photo_above_2mb_is_rejected(): void
    {
        Storage::fake('private');
        $user = $this->createMemberWithProfile();

        $oversizedImage = UploadedFile::fake()->image('huge.jpg', 1200, 1200)->size(2500);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/profile/photo', [
                'photo' => $oversizedImage,
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['photo']);
    }

    /** 8. Unauthorized profile modification (preventing user_id tampering & unauthenticated requests) */
    public function test_user_cannot_modify_another_members_profile_by_passing_user_id(): void
    {
        $attacker = $this->createMemberWithProfile(['email' => 'attacker@example.com']);
        $victim = $this->createMemberWithProfile([
            'email' => 'victim@example.com',
        ], [
            'full_name' => 'أحمد الضحية',
            'gender' => 'male',
        ]);

        // Unauthenticated attempt
        $this->patchJson('/api/v1/profile', ['full_name' => 'Hacked'])->assertStatus(401);

        // Authenticated attempt passing victim's user_id in payload (prohibited rule)
        $response = $this->actingAs($attacker, 'sanctum')
            ->patchJson('/api/v1/profile', [
                'user_id' => $victim->id,
                'full_name' => 'محاولة اختراق',
                'gender' => 'female',
                'date_of_birth' => '1992-06-15',
                'marital_status' => 'single',
                'previously_married' => false,
                'has_children' => false,
                'education_level' => 'bachelor',
                'occupation' => 'مهندسة',
                'height_cm' => 165,
                'smoking_status' => 'non_smoker',
                'home_ownership' => 'owned',
                'hobbies' => ['القراءة'],
                'nationality' => 'مصرية',
                'country_of_residence' => 'مصر',
                'region' => 'القاهرة',
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['user_id']);

        $this->assertEquals('أحمد الضحية', $victim->fresh()->profile->full_name);
    }

    /** 9. Privacy settings updates */
    public function test_user_can_update_and_retrieve_privacy_settings(): void
    {
        $user = $this->createMemberWithProfile();

        $patchResponse = $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/profile/privacy', [
                'is_visible' => false,
                'photo_privacy' => 'accepted_matches_only',
            ]);

        $patchResponse->assertOk()
            ->assertJsonPath('data.is_visible', false)
            ->assertJsonPath('data.photo_privacy', 'accepted_matches_only');

        $getResponse = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/profile/privacy');

        $getResponse->assertOk()
            ->assertJsonPath('data.is_visible', false)
            ->assertJsonPath('data.photo_privacy', 'accepted_matches_only');
    }

    /** 10. Unauthorized image access (subscribers_only & accepted_matches_only enforcement) */
    public function test_protected_photo_stream_enforces_photo_privacy_levels(): void
    {
        Storage::fake('private');
        $owner = $this->createMemberWithProfile([], [
            'photo_privacy' => 'subscribers_only',
        ]);

        $photoPath = "member-photos/{$owner->id}/11111111-2222-3333-4444-555555555555.jpg";
        Storage::disk('private')->put($photoPath, 'fake-jpeg-binary');

        $photo = UserPhoto::create([
            'user_id' => $owner->id,
            'storage_disk' => 'private',
            'file_path' => $photoPath,
            'mime_type' => 'image/jpeg',
            'file_size_bytes' => 16,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        $freeViewer = $this->createMemberWithProfile();

        // Owner can ALWAYS view their own photo
        $this->actingAs($owner, 'sanctum')
            ->get("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertOk();

        // Free member is denied when photo_privacy is 'subscribers_only'
        $this->actingAs($freeViewer, 'sanctum')
            ->getJson("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertStatus(403)
            ->assertJsonPath('code', 'PHOTO_ACCESS_FORBIDDEN');

        // Grant active subscription to viewer -> now allowed for 'subscribers_only'
        $plan = SubscriptionPlan::create([
            'code' => 'monthly_test',
            'name_ar' => 'شهري',
            'duration_days' => 30,
            'google_play_product_id' => 'naseebak_monthly',
            'web_price_amount' => 250,
            'web_price_currency' => 'EGP',
        ]);
        Subscription::create([
            'user_id' => $freeViewer->id,
            'subscription_plan_id' => $plan->id,
            'channel' => 'google_play',
            'status' => 'active',
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDays(29),
        ]);

        $this->actingAs($freeViewer->fresh(), 'sanctum')
            ->get("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertOk();

        // Switch owner photo_privacy to 'accepted_matches_only' -> subscriber without accepted match is denied
        $owner->profile->update(['photo_privacy' => 'accepted_matches_only']);
        $this->actingAs($freeViewer->fresh(), 'sanctum')
            ->getJson("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertStatus(403);

        // Create accepted matchmaking request -> now allowed
        MatchmakingRequest::create([
            'sender_id' => $freeViewer->id,
            'recipient_id' => $owner->id,
            'status' => 'accepted',
            'responded_at' => now(),
        ]);

        $this->actingAs($freeViewer->fresh(), 'sanctum')
            ->get("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertOk();
    }

    /** 11. Hidden profile enforcement (is_visible = false) */
    public function test_hidden_profile_cannot_be_viewed_by_other_members_without_accepted_match(): void
    {
        $hiddenUser = $this->createMemberWithProfile([], [
            'is_visible' => false,
        ]);
        $viewer = $this->createMemberWithProfile();

        // Owner can always view own profile
        $this->actingAs($hiddenUser, 'sanctum')
            ->getJson('/api/v1/profile')
            ->assertOk();

        // Other member cannot access hidden profile
        $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/members/{$hiddenUser->id}/profile")
            ->assertStatus(403)
            ->assertJsonPath('code', 'PROFILE_UNAVAILABLE');
    }

    /** 12. Blocked user restrictions */
    public function test_blocked_user_cannot_view_member_profile_or_stream_photo(): void
    {
        Storage::fake('private');
        $memberA = $this->createMemberWithProfile();
        $memberB = $this->createMemberWithProfile();

        $photoPath = "member-photos/{$memberA->id}/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg";
        Storage::disk('private')->put($photoPath, 'fake-jpeg-binary');
        $photo = UserPhoto::create([
            'user_id' => $memberA->id,
            'storage_disk' => 'private',
            'file_path' => $photoPath,
            'mime_type' => 'image/jpeg',
            'file_size_bytes' => 16,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        BlockedUser::create([
            'blocker_id' => $memberA->id,
            'blocked_id' => $memberB->id,
            'reason' => 'إزعاج',
        ]);

        // Blocked user B cannot view A's profile
        $this->actingAs($memberB, 'sanctum')
            ->getJson("/api/v1/members/{$memberA->id}/profile")
            ->assertStatus(403);

        // Blocked user B cannot stream A's photo even though photo_privacy is 'public'
        $this->actingAs($memberB, 'sanctum')
            ->getJson("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertStatus(403);
    }
}
