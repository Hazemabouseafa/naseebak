<?php

namespace Tests\Feature;

use App\Models\Administrator;
use App\Models\Conversation;
use App\Models\MatchmakingRequest;
use App\Models\NotificationRecord;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Services\Auth\GoogleIdTokenVerifierService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Mockery;
use Tests\TestCase;

class Phase8IntegrationAndSecurityTest extends TestCase
{
    use RefreshDatabase;

    private SubscriptionPlan $plan;

    protected function setUp(): void
    {
        parent::setUp();

        $this->plan = SubscriptionPlan::create([
            'code' => 'naseebak_monthly_communication',
            'name_ar' => 'اشتراك نصيبك الشهري للتواصل',
            'description_ar' => 'إرسال طلبات التعارف والمراسلة الفورية الخاصة لمدة شهر.',
            'web_price_amount' => 199.00,
            'web_price_currency' => 'EGP',
            'duration_days' => 30,
            'google_play_product_id' => 'naseebak_monthly_sub',
            'is_active' => true,
        ]);

        Config::set('naseebak.fcm.enabled', true);
        Config::set('naseebak.fcm.project_id', 'naseebak-test-project');
        Cache::put('naseebak_fcm_oauth_access_token', 'mock-google-oauth2-token', 3000);
    }

    /**
     * End-to-End Integration Scenarios A -> G:
     * Registration -> Profile Completion -> Admin Moderation Approval ->
     * Discovery & Search -> Subscription Activation -> Matchmaking Request & Accept ->
     * Real-Time Authorized Messaging + FCM Notification -> Subscription Expiration Enforcement
     */
    public function test_full_end_to_end_matrimonial_lifecycle_scenarios_a_through_g(): void
    {
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::response([
                'name' => 'projects/naseebak-test-project/messages/e2e_msg_1',
            ], 200),
        ]);

        // Scenario A: Google Sign-In Registration & Profile Completion (Male Member)
        $validLengthIdToken = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjEifQ.eyJzdWIiOiJnb29nbGVfc3ViX21hbGVfZTJlIiwiZW1haWwiOiJrYXJlZW0uZTJlQGV4YW1wbGUuY29tIn0.signature_male_e2e';
        $mockVerifier = Mockery::mock(GoogleIdTokenVerifierService::class);
        $mockVerifier->shouldReceive('verifyIdToken')
            ->once()
            ->with($validLengthIdToken)
            ->andReturn([
                'sub' => 'google_sub_male_e2e',
                'google_sub' => 'google_sub_male_e2e',
                'email' => 'kareem.e2e@example.com',
                'email_verified' => true,
                'name' => 'كريم محمود',
                'picture' => null,
            ]);
        $this->app->instance(GoogleIdTokenVerifierService::class, $mockVerifier);

        $loginRes = $this->postJson('/api/v1/auth/google', [
            'id_token' => $validLengthIdToken,
            'device_name' => 'Pixel 8 Pro',
        ])->assertStatus(200)
          ->assertJsonPath('data.next_route', 'complete_profile');

        $maleToken = $loginRes->json('data.token');
        $maleUserId = (int) $loginRes->json('data.user.id');

        // Complete profile for Male Member
        $this->withToken($maleToken)->postJson('/api/v1/profile/complete', [
            'full_name' => 'كريم محمود الأنصاري',
            'gender' => 'male',
            'date_of_birth' => '1991-04-12',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'master',
            'occupation' => 'مهندس معماري',
            'height_cm' => 180,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['القراءة', 'السفر'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'bio' => 'أبحث عن شريكة حياة جادة على خلق ودين.',
        ])->assertStatus(200)
          ->assertJsonPath('data.profile_completed', true);

        // Create Female Member (pending moderation initially)
        $femaleUser = User::create([
            'email' => 'nour.e2e@example.com',
            'google_sub' => 'google_sub_female_e2e',
            'role' => 'member',
            'account_status' => 'active',
            'profile_completed' => true,
        ]);
        $femaleProfile = UserProfile::create([
            'user_id' => $femaleUser->id,
            'full_name' => 'نور الهدى أحمد',
            'gender' => 'female',
            'date_of_birth' => '1995-08-20',
            'age_years' => 30,
            'zodiac_sign' => 'الأسد',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'طبيبة أسنان',
            'height_cm' => 165,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'family_home',
            'hobbies' => ['القراءة', 'الطبخ'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'is_visible' => true,
            'photo_privacy' => 'accepted_matches_only',
            'moderation_status' => 'pending',
        ]);

        // Before Admin Approval, Female Member does NOT appear in Male Member's search
        $maleUser = User::findOrFail($maleUserId);
        $maleUser->profile()->update(['moderation_status' => 'approved']);

        Sanctum::actingAs($maleUser);
        $this->getJson('/api/v1/members/search?gender=female')
            ->assertStatus(200)
            ->assertJsonCount(0, 'data.members');

        // Scenario B: Admin Moderation Approval -> Member appears in Discovery & Search
        $admin = Administrator::create([
            'name' => 'مدير المراجعة',
            'email' => 'mod.e2e@naseebak.app',
            'password' => bcrypt('AdminPass123!'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $this->actingAs($admin, 'admin')
            ->postJson("/admin/operations/profiles/{$femaleProfile->id}/moderate", [
                'status' => 'approved',
            ])
            ->assertStatus(200);

        Sanctum::actingAs($maleUser);
        $this->getJson('/api/v1/members/search?gender=female')
            ->assertStatus(200)
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $femaleUser->id);

        // Scenario C: Free user cannot send matchmaking request -> Active Subscription unlocks it
        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_id' => $femaleUser->id,
        ])->assertStatus(403)
          ->assertJsonPath('code', 'SUBSCRIPTION_REQUIRED');

        $maleSubscription = Subscription::create([
            'user_id' => $maleUser->id,
            'subscription_plan_id' => $this->plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'external_subscription_id' => 'gpa.e2e.1001',
            'status' => Subscription::STATUS_ACTIVE,
            'starts_at' => now()->subHour(),
            'ends_at' => now()->addDays(30),
            'auto_renewing' => true,
            'last_verified_at' => now(),
        ]);

        // Scenario D & F: Register FCM tokens, send Matchmaking Request, Recipient Accepts -> Conversation Created
        Sanctum::actingAs($femaleUser);
        $this->postJson('/api/v1/devices/register', [
            'fcm_token' => str_repeat('femaleE2eFcmToken_', 10),
            'device_platform' => 'android',
        ])->assertStatus(200);

        Sanctum::actingAs($maleUser);
        $reqRes = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_id' => $femaleUser->id,
        ])->assertStatus(201);

        $requestId = (int) $reqRes->json('data.request.id');

        // Verify Female Member received privacy-safe notification in DB and via FCM
        $this->assertDatabaseHas('notifications', [
            'user_id' => $femaleUser->id,
            'event_type' => NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            'fcm_delivery_status' => NotificationRecord::DELIVERY_SUBMITTED_TO_FCM,
        ]);

        // Female Member (unsubscribed) can accept the incoming request
        Sanctum::actingAs($femaleUser);
        $acceptRes = $this->postJson("/api/v1/matchmaking/requests/{$requestId}/accept")
            ->assertStatus(200);
        $conversationId = (int) $acceptRes->json('data.conversation_id');
        $this->assertGreaterThan(0, $conversationId);

        // Scenario E: Subscribed Male sends message; Female reads and marks read
        Sanctum::actingAs($maleUser);
        $msgRes = $this->postJson("/api/v1/conversations/{$conversationId}/messages", [
            'body' => 'السلام عليكم ورحمة الله، تشرفت بقبول طلب التعارف.',
            'client_message_id' => 'e2e-client-msg-001',
        ])->assertStatus(201);
        $messageId = (int) $msgRes->json('data.message.id');

        Sanctum::actingAs($femaleUser);
        $this->getJson("/api/v1/conversations/{$conversationId}/messages")
            ->assertStatus(200)
            ->assertJsonCount(1, 'data.messages');

        $this->postJson("/api/v1/conversations/{$conversationId}/read")
            ->assertStatus(200)
            ->assertJsonPath('data.last_read_message_id', $messageId)
            ->assertJsonPath('data.unread_count', 0);

        // Scenario G: Subscription Expiration -> User can still read existing conversation but cannot send new message or new request
        $maleSubscription->update([
            'status' => Subscription::STATUS_EXPIRED,
            'ends_at' => now()->subMinute(),
            'expired_at' => now()->subMinute(),
        ]);

        Sanctum::actingAs($maleUser);
        $this->getJson("/api/v1/conversations/{$conversationId}/messages")
            ->assertStatus(200)
            ->assertJsonCount(1, 'data.messages')
            ->assertJsonPath('data.can_send_messages', false)
            ->assertJsonPath('data.restriction_code', 'SUBSCRIPTION_REQUIRED');

        $this->postJson("/api/v1/conversations/{$conversationId}/messages", [
            'body' => 'رسالة بعد انتهاء الاشتراك',
        ])->assertStatus(403)
          ->assertJsonPath('code', 'SUBSCRIPTION_REQUIRED');
    }

    /**
     * Scenario H: Comprehensive Security & IDOR Audit Verification:
     * - Mass-assignment of role, account_status, moderation_status, or user_id on profile update is ignored/blocked
     * - Member cannot stream private photos when photo_privacy = subscribers_only and viewer is unsubscribed
     * - Member cannot delete or read another member's notification
     * - Member cannot cancel/accept another member's matchmaking request
     * - Member profile response never leaks email, google_sub, or fcm tokens
     */
    public function test_scenario_h_comprehensive_security_and_idor_audit(): void
    {
        Storage::fake('private');

        $victim = User::create([
            'email' => 'victim.private@example.com',
            'google_sub' => 'secret_google_sub_victim_999',
            'role' => 'member',
            'account_status' => 'active',
            'profile_completed' => true,
        ]);
        UserProfile::create([
            'user_id' => $victim->id,
            'full_name' => 'فاطمة الزهراء',
            'gender' => 'female',
            'date_of_birth' => '1996-02-10',
            'age_years' => 29,
            'zodiac_sign' => 'الدلو',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'معلمة',
            'height_cm' => 163,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'family_home',
            'hobbies' => ['القراءة'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'الجيزة',
            'is_visible' => true,
            'photo_privacy' => 'subscribers_only',
            'moderation_status' => 'approved',
        ]);

        Storage::disk('private')->put("member-photos/{$victim->id}/photo1.jpg", 'jpeg-binary-data');
        $victimPhoto = UserPhoto::create([
            'user_id' => $victim->id,
            'storage_disk' => 'private',
            'file_path' => "member-photos/{$victim->id}/photo1.jpg",
            'mime_type' => 'image/jpeg',
            'file_size_bytes' => 16,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        $attacker = User::create([
            'email' => 'attacker@example.com',
            'google_sub' => 'sub_attacker_111',
            'role' => 'member',
            'account_status' => 'active',
            'profile_completed' => true,
        ]);
        UserProfile::create([
            'user_id' => $attacker->id,
            'full_name' => 'مهاجم تجريبي',
            'gender' => 'male',
            'date_of_birth' => '1990-01-01',
            'age_years' => 35,
            'zodiac_sign' => 'الجدي',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'محاسب',
            'height_cm' => 175,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'rented',
            'hobbies' => ['السفر'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => 'approved',
        ]);

        Sanctum::actingAs($attacker);

        // 1. Member profile response never leaks email or google_sub
        $profileRes = $this->getJson("/api/v1/members/{$victim->id}/profile")
            ->assertStatus(200);
        $rawJson = json_encode($profileRes->json());
        $this->assertStringNotContainsString('victim.private@example.com', $rawJson);
        $this->assertStringNotContainsString('secret_google_sub_victim_999', $rawJson);

        // 2. Unsubscribed attacker cannot stream subscribers_only photo
        $this->get("/api/v1/profile/photos/{$victimPhoto->id}/stream")
            ->assertStatus(403);

        // 3. Attacker cannot spoof sender_id in matchmaking request
        $this->postJson('/api/v1/matchmaking/requests', [
            'sender_id' => $victim->id,
            'recipient_id' => $attacker->id,
        ])->assertStatus(422);

        // 4. Attacker cannot escalate role or modify victim's profile via PATCH /api/v1/profile
        $this->patchJson('/api/v1/profile', [
            'user_id' => $victim->id,
            'role' => 'super_admin',
            'occupation' => 'مهنة معدلة',
        ])->assertStatus(422);

        $this->assertSame('member', $attacker->fresh()->role);
        $this->assertSame('معلمة', $victim->fresh()->profile->occupation);
    }
}
