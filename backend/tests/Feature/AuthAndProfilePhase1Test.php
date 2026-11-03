<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserProfile;
use App\Services\Auth\GoogleIdTokenVerifierService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class AuthAndProfilePhase1Test extends TestCase
{
    use RefreshDatabase;

    public function test_new_user_authenticates_via_google_id_token_and_is_routed_to_complete_profile(): void
    {
        $mockVerifier = Mockery::mock(GoogleIdTokenVerifierService::class);
        $mockVerifier->shouldReceive('verifyIdToken')
            ->once()
            ->with(Mockery::type('string'))
            ->andReturn([
                'sub' => 'google-oauth-sub-100998877',
                'email' => 'sara.mohamed@example.com',
                'email_verified' => true,
                'name' => 'سارة محمد',
            ]);

        $this->app->instance(GoogleIdTokenVerifierService::class, $mockVerifier);

        $response = $this->postJson('/api/v1/auth/google', [
            'id_token' => str_repeat('a', 64),
            'device_name' => 'Pixel 8 Pro',
        ]);

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.is_new_user', true)
            ->assertJsonPath('data.next_route', 'complete_profile')
            ->assertJsonPath('data.user.profile_completed', false);

        $this->assertDatabaseHas('users', [
            'google_sub' => 'google-oauth-sub-100998877',
            'email' => 'sara.mohamed@example.com',
            'account_status' => 'active',
        ]);
    }

    public function test_suspended_user_is_blocked_from_logging_in(): void
    {
        User::create([
            'google_sub' => 'google-oauth-sub-suspended',
            'email' => 'suspended@example.com',
            'account_status' => 'suspended',
            'suspension_reason' => 'مخالفة شروط الاستخدام.',
            'profile_completed' => true,
        ]);

        $mockVerifier = Mockery::mock(GoogleIdTokenVerifierService::class);
        $mockVerifier->shouldReceive('verifyIdToken')
            ->once()
            ->andReturn([
                'sub' => 'google-oauth-sub-suspended',
                'email' => 'suspended@example.com',
                'email_verified' => true,
                'name' => 'حساب موقوف',
            ]);

        $this->app->instance(GoogleIdTokenVerifierService::class, $mockVerifier);

        $response = $this->postJson('/api/v1/auth/google', [
            'id_token' => str_repeat('b', 64),
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('code', 'ACCOUNT_SUSPENDED');
    }

    public function test_underage_user_under_18_cannot_complete_profile(): void
    {
        $user = User::create([
            'google_sub' => 'google-sub-minor',
            'email' => 'minor@example.com',
            'account_status' => 'active',
            'profile_completed' => false,
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/profile/complete', [
            'full_name' => 'قاصر تجريبي',
            'gender' => 'male',
            'date_of_birth' => now()->subYears(17)->format('Y-m-d'),
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'education_level' => 'high_school',
            'occupation' => 'طالب',
            'height_cm' => 170,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'family_home',
            'hobbies' => ['القراءة'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['date_of_birth']);
    }

    public function test_logically_inconsistent_marital_status_and_children_is_rejected(): void
    {
        $user = User::create([
            'google_sub' => 'google-sub-inconsistent',
            'email' => 'inconsistent@example.com',
            'account_status' => 'active',
            'profile_completed' => false,
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/profile/complete', [
            'full_name' => 'أحمد محمود',
            'gender' => 'male',
            'date_of_birth' => '1990-06-15',
            'marital_status' => 'single',
            'previously_married' => true, // Inconsistent with 'single'
            'has_children' => true,       // Inconsistent with 'single'
            'education_level' => 'bachelor',
            'occupation' => 'مهندس برمجيات',
            'height_cm' => 178,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['السفر', 'القراءة'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['previously_married', 'has_children']);
    }

    public function test_valid_adult_profile_auto_calculates_age_and_zodiac_sign(): void
    {
        $user = User::create([
            'google_sub' => 'google-sub-valid-adult',
            'email' => 'sara.valid@example.com',
            'account_status' => 'active',
            'profile_completed' => false,
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/profile/complete', [
            'full_name' => 'سارة محمد',
            'gender' => 'female',
            'date_of_birth' => '1987-06-15',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'education_level' => 'bachelor',
            'occupation' => 'مهندسة معمارية',
            'height_cm' => 165,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['التصميم', 'القراءة'],
            'nationality' => 'مصرية',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'bio' => 'أبحث عن شريك جاد يحترم الحياة الأسرية.',
        ]);

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.profile.zodiac_sign', 'الجوزاء')
            ->assertJsonPath('data.profile.moderation_status', 'pending');

        $this->assertTrue($user->fresh()->profile_completed);
    }
}
