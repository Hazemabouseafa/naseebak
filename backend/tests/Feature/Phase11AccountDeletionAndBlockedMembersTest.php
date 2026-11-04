<?php

namespace Tests\Feature;

use App\Models\BlockedUser;
use App\Models\Conversation;
use App\Models\ConversationParticipant;
use App\Models\DeviceToken;
use App\Models\Favorite;
use App\Models\MatchmakingRequest;
use App\Models\Message;
use App\Models\NotificationRecord;
use App\Models\Subscription;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Services\Auth\GoogleIdTokenVerifierService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Mockery;
use Tests\TestCase;

class Phase11AccountDeletionAndBlockedMembersTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('private');
    }

    /**
     * 1. Priority 1 — Account Deletion requires explicit confirmation string ('حذف', 'DELETE')
     */
    public function test_account_deletion_requires_explicit_confirmation(): void
    {
        $user = $this->createActiveMember('user1@example.com');
        $token = $user->createToken('test')->plainTextToken;

        // Missing confirmation
        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson('/api/v1/auth/account', []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['confirmation']);

        // Invalid confirmation
        $invalidResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson('/api/v1/auth/account', [
                'confirmation' => 'لا أحذف',
            ]);

        $invalidResponse->assertStatus(422)
            ->assertJsonPath('code', 'INVALID_CONFIRMATION');
    }

    /**
     * 2. Priority 1 — Account Deletion purges photos, revokes tokens, cancels requests, closes chats, and anonymizes user
     */
    public function test_account_deletion_purges_photos_revokes_tokens_cancels_requests_and_anonymizes_user(): void
    {
        $user = $this->createActiveMember('ahmed.delete@example.com', 'أحمد كمال');
        $partner = $this->createActiveMember('nour.partner@example.com', 'نور الهدى');

        $plan = \App\Models\SubscriptionPlan::create([
            'code' => 'naseebak_monthly_del_test',
            'name_ar' => 'الباقة الشهرية الموحدة',
            'description_ar' => 'اشتراك تجريبي',
            'web_price_amount' => 75.00,
            'web_price_currency' => 'SAR',
            'duration_days' => 30,
            'google_play_product_id' => 'naseebak_monthly_del_sub',
            'is_active' => true,
        ]);

        // Give user an active subscription
        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => 'google_play',
            'status' => 'active',
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDays(29),
            'auto_renewing' => true,
        ]);

        // Upload photo on fake private storage
        $photoPath = "member-photos/{$user->id}/test_photo.jpg";
        Storage::disk('private')->put($photoPath, 'fake-binary-image-data');

        UserPhoto::create([
            'user_id' => $user->id,
            'storage_disk' => 'private',
            'file_path' => $photoPath,
            'mime_type' => 'image/jpeg',
            'file_size_bytes' => 1024,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        // Device token & notification
        DeviceToken::create([
            'user_id' => $user->id,
            'fcm_token' => 'fcm-device-token-12345',
            'token_fingerprint' => DeviceToken::computeFingerprint('fcm-device-token-12345'),
            'device_type' => 'android',
        ]);

        NotificationRecord::create([
            'event_id' => (string) \Illuminate\Support\Str::uuid(),
            'user_id' => $user->id,
            'event_type' => NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT,
            'title_ar' => 'مرحباً بك',
            'body_ar' => 'تم تفعيل حسابك بنجاح',
            'action_route' => NotificationRecord::ROUTE_NOTIFICATION_CENTER,
        ]);

        // Mutual favorite
        Favorite::create(['user_id' => $user->id, 'favorited_user_id' => $partner->id]);
        Favorite::create(['user_id' => $partner->id, 'favorited_user_id' => $user->id]);

        // Pending matchmaking request
        $request = MatchmakingRequest::create([
            'sender_id' => $user->id,
            'recipient_id' => $partner->id,
            'status' => MatchmakingRequest::STATUS_PENDING,
        ]);

        // Conversation between them linked to accepted request
        $acceptedReq = MatchmakingRequest::create([
            'sender_id' => $partner->id,
            'recipient_id' => $user->id,
            'status' => MatchmakingRequest::STATUS_ACCEPTED,
        ]);
        $conversation = Conversation::create([
            'matchmaking_request_id' => $acceptedReq->id,
            'user_one_id' => min($user->id, $partner->id),
            'user_two_id' => max($user->id, $partner->id),
            'status' => Conversation::STATUS_ACTIVE,
        ]);
        ConversationParticipant::create(['conversation_id' => $conversation->id, 'user_id' => $user->id]);
        ConversationParticipant::create(['conversation_id' => $conversation->id, 'user_id' => $partner->id]);

        $token = $user->createToken('test-mobile-token')->plainTextToken;

        // Perform authoritative account deletion API
        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson('/api/v1/auth/account', [
                'confirmation' => 'حذف',
                'reason' => 'found_partner',
                'notes' => 'وفقني الله بالزواج، شكراً نَصِيبُكَ',
            ]);

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.account_status', 'deleted')
            ->assertJsonPath('data.google_play_subscriptions_url', 'https://play.google.com/store/account/subscriptions');

        // Check storage photo was physically purged
        $this->assertFalse(Storage::disk('private')->exists($photoPath));
        $this->assertDatabaseMissing('user_photos', ['user_id' => $user->id]);

        // Check device tokens & notifications purged
        $this->assertDatabaseMissing('device_tokens', ['user_id' => $user->id]);
        $this->assertDatabaseMissing('notifications', ['user_id' => $user->id]);

        // Check favorites removed
        $this->assertDatabaseMissing('favorites', ['user_id' => $user->id]);
        $this->assertDatabaseMissing('favorites', ['favorited_user_id' => $user->id]);

        // Check matchmaking request was cancelled
        $this->assertEquals(MatchmakingRequest::STATUS_CANCELLED, $request->fresh()->status);

        // Check conversation was closed
        $this->assertEquals(Conversation::STATUS_CLOSED, $conversation->fresh()->status);

        // Check user profile was anonymized
        $profile = UserProfile::where('user_id', $user->id)->first();
        $this->assertEquals('عضو محذوف', $profile->full_name);
        $this->assertNull($profile->bio);
        $this->assertFalse($profile->is_visible);

        // Check user soft-deleted and email anonymized
        $freshUser = User::withTrashed()->find($user->id);
        $this->assertTrue($freshUser->trashed());
        $this->assertEquals('deleted', $freshUser->account_status);
        $this->assertStringStartsWith("deleted_{$user->id}_", $freshUser->email);

        // Check tokens revoked
        $this->assertCount(0, $freshUser->tokens);

        // Verify personal access tokens were wiped from database
        $this->assertDatabaseMissing('personal_access_tokens', ['tokenable_id' => $user->id]);

        // Subsequent access with revoked token must be denied (401 unauthenticated or 403 inactive account)
        $subsequentResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/auth/me');
        $this->assertContains($subsequentResponse->status(), [401, 403]);
    }

    /**
     * 3. Priority 1 — Deleted account cannot be logged in again via Google Sign-In
     */
    public function test_deleted_user_cannot_login_again_via_google(): void
    {
        $user = $this->createActiveMember('deleted.member@example.com');
        $user->update([
            'account_status' => 'deleted',
            'deletion_requested_at' => now(),
        ]);
        $user->delete();

        $mockVerifier = Mockery::mock(GoogleIdTokenVerifierService::class);
        $mockVerifier->shouldReceive('verifyIdToken')
            ->once()
            ->andReturn([
                'sub' => $user->google_sub,
                'email' => 'deleted.member@example.com',
                'email_verified' => true,
                'name' => 'عضو محذوف',
            ]);
        $this->app->instance(GoogleIdTokenVerifierService::class, $mockVerifier);

        $response = $this->postJson('/api/v1/auth/google', [
            'id_token' => str_repeat('b', 64),
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('code', 'ACCOUNT_DELETED');
    }

    /**
     * 4. Priority 2 — Blocked members listing and unblock endpoints
     */
    public function test_blocked_members_list_and_unblock_functionality(): void
    {
        $viewer = $this->createActiveMember('viewer@example.com', 'سعد');
        $blocked1 = $this->createActiveMember('blocked1@example.com', 'فاطمة');
        $blocked2 = $this->createActiveMember('blocked2@example.com', 'ريم');

        BlockedUser::create([
            'blocker_id' => $viewer->id,
            'blocked_id' => $blocked1->id,
            'reason' => 'سلوك غير لائق',
        ]);
        BlockedUser::create([
            'blocker_id' => $viewer->id,
            'blocked_id' => $blocked2->id,
            'reason' => 'حظر وقائي',
        ]);

        $token = $viewer->createToken('viewer-token')->plainTextToken;

        // 1. GET /api/v1/blocked-members
        $listResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/blocked-members');

        $listResponse->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonCount(2, 'data.blocked_members')
            ->assertJsonPath('data.blocked_members.0.unblock_allowed', true);

        // 2. DELETE /api/v1/members/{member}/block (Unblock blocked1)
        $unblockResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->deleteJson("/api/v1/members/{$blocked1->id}/block");

        $unblockResponse->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.blocked_user_id', $blocked1->id)
            ->assertJsonPath('data.is_blocked', false)
            ->assertJsonPath('data.was_unblocked', true);

        $this->assertDatabaseMissing('blocked_users', [
            'blocker_id' => $viewer->id,
            'blocked_id' => $blocked1->id,
        ]);

        // 3. Verify only 1 member remains blocked
        $remainingResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/blocked-members');

        $remainingResponse->assertOk()
            ->assertJsonCount(1, 'data.blocked_members')
            ->assertJsonPath('data.blocked_members.0.blocked_user_id', $blocked2->id);
    }

    /**
     * 5. Priority 2 — Blocked user cannot bypass matchmaking and conversation authorization
     */
    public function test_blocked_user_cannot_bypass_matchmaking_and_conversation(): void
    {
        $userA = $this->createActiveMember('userA@example.com', 'خالد');
        $userB = $this->createActiveMember('userB@example.com', 'منى');

        $plan = \App\Models\SubscriptionPlan::create([
            'code' => 'naseebak_monthly_block_test',
            'name_ar' => 'الباقة الشهرية الموحدة',
            'description_ar' => 'اشتراك تجريبي',
            'web_price_amount' => 75.00,
            'web_price_currency' => 'SAR',
            'duration_days' => 30,
            'google_play_product_id' => 'naseebak_monthly_block_sub',
            'is_active' => true,
        ]);

        // Give both active subscriptions
        foreach ([$userA, $userB] as $u) {
            Subscription::create([
                'user_id' => $u->id,
                'subscription_plan_id' => $plan->id,
                'channel' => 'google_play',
                'status' => 'active',
                'starts_at' => now()->subDay(),
                'ends_at' => now()->addDays(29),
            ]);
        }

        // User A blocks User B
        BlockedUser::create([
            'blocker_id' => $userA->id,
            'blocked_id' => $userB->id,
            'reason' => 'حظر أمني',
        ]);

        $tokenB = $userB->createToken('userB-token')->plainTextToken;

        // User B attempts to send matchmaking request to User A -> 403 USER_BLOCKED
        $reqResponse = $this->withHeader('Authorization', "Bearer {$tokenB}")
            ->postJson('/api/v1/matchmaking/requests', [
                'recipient_id' => $userA->id,
            ]);

        $reqResponse->assertStatus(403)
            ->assertJsonPath('code', 'USER_BLOCKED');

        // Existing conversation between them is blocked
        $acceptedMatch = MatchmakingRequest::create([
            'sender_id' => $userA->id,
            'recipient_id' => $userB->id,
            'status' => MatchmakingRequest::STATUS_ACCEPTED,
        ]);
        $conv = Conversation::create([
            'matchmaking_request_id' => $acceptedMatch->id,
            'user_one_id' => min($userA->id, $userB->id),
            'user_two_id' => max($userA->id, $userB->id),
            'status' => Conversation::STATUS_BLOCKED,
        ]);
        ConversationParticipant::create(['conversation_id' => $conv->id, 'user_id' => $userA->id]);
        ConversationParticipant::create(['conversation_id' => $conv->id, 'user_id' => $userB->id]);

        // User B attempts to send message in blocked conversation -> 403 CONVERSATION_BLOCKED
        $msgResponse = $this->withHeader('Authorization', "Bearer {$tokenB}")
            ->postJson("/api/v1/conversations/{$conv->id}/messages", [
                'body' => 'مرحباً، هل يمكننا الحديث؟',
                'client_message_id' => 'client-msg-12345',
            ]);

        $msgResponse->assertStatus(403)
            ->assertJsonPath('code', 'CONVERSATION_BLOCKED');
    }

    /**
     * 6. Web Account Deletion page & request submission (Google Play Store compliance)
     */
    public function test_web_account_deletion_page_and_submission(): void
    {
        // 1. GET /legal/delete-account renders informative page
        $pageResponse = $this->get('/legal/delete-account');

        $pageResponse->assertOk()
            ->assertSee('نَصِيبُكَ', false)
            ->assertSee('حذف الحساب والبيانات الشخصية', false)
            ->assertSee('Google Play', false)
            ->assertSee('https://play.google.com/store/account/subscriptions', false);

        // 2. POST /legal/delete-account executes account deletion with CSRF and validation
        $targetUser = $this->createActiveMember('web.delete.target@example.com', 'طارق');
        $this->assertEquals('active', $targetUser->account_status);

        $submitResponse = $this->actingAs($targetUser, 'web')->post('/legal/delete-account', [
            'email' => 'web.delete.target@example.com',
            'confirmation' => 'حذف',
            'acknowledge_play_store' => '1',
            'reason' => 'عدم الحاجة للتطبيق حالياً',
        ]);

        $submitResponse->assertRedirect(route('legal.delete_account'))
            ->assertSessionHas('success');

        $freshTarget = User::withTrashed()->find($targetUser->id);
        $this->assertTrue($freshTarget->trashed());
        $this->assertEquals('deleted', $freshTarget->account_status);
    }

    private function createActiveMember(string $email, string $fullName = 'عضو تجريبي'): User
    {
        $user = User::create([
            'google_sub' => 'sub-' . md5($email),
            'email' => $email,
            'email_verified' => true,
            'role' => 'member',
            'account_status' => 'active',
            'profile_completed' => true,
            'last_active_at' => now(),
        ]);

        UserProfile::create([
            'user_id' => $user->id,
            'full_name' => $fullName,
            'gender' => 'male',
            'date_of_birth' => '1995-05-15',
            'age_years' => 29,
            'zodiac_sign' => 'الثور',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'مهندس برمجيات',
            'height_cm' => 176,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => json_encode(['القراءة', 'السفر']),
            'nationality' => 'سعودي',
            'country_of_residence' => 'السعودية',
            'region' => 'الرياض',
            'bio' => 'مهندس برمجيات مهتم بالاستقرار وتكوين أسرة',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => 'approved',
        ]);

        return $user;
    }
}
