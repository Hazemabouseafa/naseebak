<?php

namespace Tests\Feature;

use App\Jobs\DispatchAnnouncementCampaignJob;
use App\Models\Administrator;
use App\Models\AnnouncementCampaign;
use App\Models\Conversation;
use App\Models\ConversationParticipant;
use App\Models\DeviceToken;
use App\Models\MatchmakingRequest;
use App\Models\Message;
use App\Models\NotificationPreference;
use App\Models\NotificationRecord;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserProfile;
use App\Services\Notification\NotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PushNotificationsPhase7Test extends TestCase
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

    private function createEligibleMember(array $userOverrides = [], array $profileOverrides = []): User
    {
        $user = User::create(array_merge([
            'email' => 'member_' . uniqid() . '@example.com',
            'google_sub' => 'sub_' . uniqid(),
            'role' => 'member',
            'account_status' => 'active',
            'profile_completed' => true,
        ], $userOverrides));

        UserProfile::create(array_merge([
            'user_id' => $user->id,
            'full_name' => 'عضو نصيبك ' . $user->id,
            'gender' => 'male',
            'date_of_birth' => '1994-05-15',
            'age_years' => 31,
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
            'hobbies' => ['القراءة', 'السفر'],
            'nationality' => 'مصر',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => 'approved',
        ], $profileOverrides));

        return $user->fresh(['profile']);
    }

    private function grantActiveSubscription(
        User $user,
        string $status = Subscription::STATUS_ACTIVE,
        string $channel = Subscription::CHANNEL_PAYMOB,
        bool $autoRenewing = false,
        int $expiresInHours = 720
    ): Subscription {
        return Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $this->plan->id,
            'channel' => $channel,
            'external_subscription_id' => 'sub_' . uniqid(),
            'status' => $status,
            'starts_at' => now()->subDays(2),
            'ends_at' => now()->addHours($expiresInHours),
            'auto_renewing' => $autoRenewing,
            'last_verified_at' => now()->subDays(2),
        ]);
    }

    public function test_01_authenticated_user_can_register_valid_android_fcm_token_and_unauthenticated_cannot(): void
    {
        $validToken = str_repeat('aB9_cD-1', 20);

        // Unauthenticated cannot register
        $this->postJson('/api/v1/devices/register', [
            'fcm_token' => $validToken,
            'device_platform' => 'android',
        ])->assertStatus(401);

        $user = $this->createEligibleMember();
        Sanctum::actingAs($user);

        // Invalid short token rejected
        $this->postJson('/api/v1/devices/register', [
            'fcm_token' => 'short-token',
            'device_platform' => 'android',
        ])->assertStatus(422);

        // Valid token registered
        $res = $this->postJson('/api/v1/devices/register', [
            'fcm_token' => $validToken,
            'device_platform' => 'android',
            'device_model' => 'Pixel 8 Pro',
            'app_version' => '1.0.0+1',
            'os_version' => 'Android 14',
        ]);

        $res->assertStatus(200)
            ->assertJsonPath('data.device.device_platform', 'android')
            ->assertJsonPath('data.device.is_valid', true);

        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $user->id,
            'token_fingerprint' => DeviceToken::computeFingerprint($validToken),
            'is_valid' => true,
        ]);
    }

    public function test_02_duplicate_token_registration_is_idempotent_and_cross_account_login_transfers_ownership(): void
    {
        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember(['email' => 'b@example.com']);
        $sharedToken = str_repeat('sharedDeviceToken99_', 10);

        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/devices/register', [
            'fcm_token' => $sharedToken,
            'device_platform' => 'android',
        ])->assertStatus(200);

        // Duplicate registration by same user does not create duplicate rows
        $this->postJson('/api/v1/devices/register', [
            'fcm_token' => $sharedToken,
            'device_platform' => 'android',
        ])->assertStatus(200);

        $this->assertSame(1, DeviceToken::where('user_id', $userA->id)->where('is_valid', true)->count());

        // User B signs in on the same physical device and registers the same FCM token
        Sanctum::actingAs($userB);
        $this->postJson('/api/v1/devices/register', [
            'fcm_token' => $sharedToken,
            'device_platform' => 'android',
        ])->assertStatus(200);

        // Token ownership transferred to User B
        $this->assertSame(0, DeviceToken::where('user_id', $userA->id)->where('is_valid', true)->count());
        $this->assertSame(1, DeviceToken::where('user_id', $userB->id)->where('is_valid', true)->count());

        // Unregistering on logout removes User B's token
        $this->deleteJson('/api/v1/devices/unregister', [
            'fcm_token' => $sharedToken,
        ])->assertStatus(200)
          ->assertJsonPath('data.removed_count', 1);

        $this->assertSame(0, DeviceToken::where('user_id', $userB->id)->count());
    }

    public function test_03_matchmaking_request_lifecycle_creates_notifications_and_sends_privacy_safe_fcm_v1(): void
    {
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::response([
                'name' => 'projects/naseebak-test-project/messages/msg_1001',
            ], 200),
        ]);

        $sender = $this->createEligibleMember([], ['gender' => 'male', 'full_name' => 'أحمد السعيد']);
        $receiver = $this->createEligibleMember([], ['gender' => 'female', 'full_name' => 'سارة محمود']);

        $this->grantActiveSubscription($sender);
        $this->grantActiveSubscription($receiver);

        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $notificationService->registerDeviceToken($sender, str_repeat('senderTok_', 16), 'android');
        $notificationService->registerDeviceToken($receiver, str_repeat('receiverTok_', 16), 'android');

        // 1. Send matchmaking request -> Receiver notified
        Sanctum::actingAs($sender);
        $sendRes = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_id' => $receiver->id,
        ])->assertStatus(201);

        $requestId = $sendRes->json('data.request.id');

        $receiverNotif = NotificationRecord::where('user_id', $receiver->id)
            ->where('event_type', NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST)
            ->first();

        $this->assertNotNull($receiverNotif);
        $this->assertSame('طلب تعارف جديد', $receiverNotif->title_ar);
        $this->assertSame('لديك طلب تعارف جديد', $receiverNotif->body_ar);
        $this->assertSame(NotificationRecord::DELIVERY_SUBMITTED_TO_FCM, $receiverNotif->fcm_delivery_status);

        // 2. Receiver accepts request -> Sender notified
        Sanctum::actingAs($receiver);
        $this->postJson("/api/v1/matchmaking/requests/{$requestId}/accept")
            ->assertStatus(200);

        $senderAcceptNotif = NotificationRecord::where('user_id', $sender->id)
            ->where('event_type', NotificationRecord::TYPE_ACCEPTED_MATCHMAKING_REQUEST)
            ->first();

        $this->assertNotNull($senderAcceptNotif);
        $this->assertSame('تمت الموافقة على طلبك', $senderAcceptNotif->title_ar);
        $this->assertSame('تمت الموافقة على طلب التعارف', $senderAcceptNotif->body_ar);
        $this->assertNotEmpty($senderAcceptNotif->routing_metadata['conversation_id'] ?? null);
    }

    public function test_04_matchmaking_request_rejection_sends_polite_arabic_notification_to_sender(): void
    {
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::response([
                'name' => 'projects/naseebak-test-project/messages/msg_1002',
            ], 200),
        ]);

        $sender = $this->createEligibleMember([], ['gender' => 'male']);
        $receiver = $this->createEligibleMember([], ['gender' => 'female']);
        $this->grantActiveSubscription($sender);
        $this->grantActiveSubscription($receiver);

        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $notificationService->registerDeviceToken($sender, str_repeat('senderRejTok_', 15), 'android');

        Sanctum::actingAs($sender);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_id' => $receiver->id,
        ])->assertStatus(201)->json('data.request.id');

        Sanctum::actingAs($receiver);
        $this->postJson("/api/v1/matchmaking/requests/{$reqId}/reject")
            ->assertStatus(200);

        $rejNotif = NotificationRecord::where('user_id', $sender->id)
            ->where('event_type', NotificationRecord::TYPE_REJECTED_MATCHMAKING_REQUEST)
            ->first();

        $this->assertNotNull($rejNotif);
        $this->assertSame('تحديث طلب التعارف', $rejNotif->title_ar);
        $this->assertSame('هناك تحديث بخصوص طلب التعارف', $rejNotif->body_ar);
    }

    public function test_05_new_private_message_sends_privacy_safe_notification_without_message_text(): void
    {
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::response([
                'name' => 'projects/naseebak-test-project/messages/msg_1003',
            ], 200),
        ]);

        $user1 = $this->createEligibleMember([], ['gender' => 'male']);
        $user2 = $this->createEligibleMember([], ['gender' => 'female']);
        $this->grantActiveSubscription($user1);
        $this->grantActiveSubscription($user2);

        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $notificationService->registerDeviceToken($user2, str_repeat('user2MsgTok_', 15), 'android');

        $matchReq = MatchmakingRequest::create([
            'sender_id' => $user1->id,
            'recipient_id' => $user2->id,
            'status' => MatchmakingRequest::STATUS_ACCEPTED,
            'responded_at' => now(),
        ]);

        $pair = Conversation::canonicalPair($user1->id, $user2->id);
        $conversation = Conversation::create([
            'matchmaking_request_id' => $matchReq->id,
            'user_one_id' => $pair['user_one_id'],
            'user_two_id' => $pair['user_two_id'],
            'status' => Conversation::STATUS_ACTIVE,
        ]);

        ConversationParticipant::create(['conversation_id' => $conversation->id, 'user_id' => $user1->id, 'joined_at' => now()]);
        ConversationParticipant::create(['conversation_id' => $conversation->id, 'user_id' => $user2->id, 'joined_at' => now()]);

        $secretMessage = 'هذه رسالة سرية للغاية تحتوي على تفاصيل عائلية خاصة 987654';

        Sanctum::actingAs($user1);
        $this->postJson("/api/v1/conversations/{$conversation->id}/messages", [
            'body' => $secretMessage,
        ])->assertStatus(201);

        $msgNotif = NotificationRecord::where('user_id', $user2->id)
            ->where('event_type', NotificationRecord::TYPE_NEW_PRIVATE_MESSAGE)
            ->first();

        $this->assertNotNull($msgNotif);
        $this->assertSame('رسالة جديدة', $msgNotif->title_ar);
        $this->assertSame('لديك رسالة جديدة', $msgNotif->body_ar);
        $this->assertStringNotContainsString($secretMessage, json_encode($msgNotif->toArray()));

        Http::assertSent(function ($request) use ($secretMessage) {
            return !str_contains($request->body(), $secretMessage)
                && str_contains($request->body(), 'لديك رسالة جديدة');
        });
    }

    public function test_06_unregistered_fcm_token_is_automatically_invalidated_on_404_response(): void
    {
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::response([
                'error' => [
                    'code' => 404,
                    'message' => 'Requested entity was not found.',
                    'status' => 'NOT_FOUND',
                    'details' => [
                        ['@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode' => 'UNREGISTERED'],
                    ],
                ],
            ], 404),
        ]);

        $sender = $this->createEligibleMember([], ['gender' => 'male']);
        $receiver = $this->createEligibleMember([], ['gender' => 'female']);

        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $staleToken = $notificationService->registerDeviceToken(
            $receiver,
            str_repeat('staleUnregTok_', 14),
            'android'
        );

        $req = MatchmakingRequest::create([
            'sender_id' => $sender->id,
            'recipient_id' => $receiver->id,
            'status' => MatchmakingRequest::STATUS_PENDING,
        ]);

        $record = $notificationService->notifyMatchmakingRequestCreated($req);
        $this->assertNotNull($record);

        $staleToken->refresh();
        $this->assertFalse($staleToken->is_valid);
        $this->assertSame('UNREGISTERED', $staleToken->invalidated_reason);

        $record->refresh();
        $this->assertSame(NotificationRecord::DELIVERY_REJECTED_BY_FCM, $record->fcm_delivery_status);
        $this->assertSame('UNREGISTERED', $record->fcm_error_code);
    }

    public function test_07_subscription_lifecycle_notifications_and_google_play_autorenew_skip_and_dual_entitlement_guard(): void
    {
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::response([
                'name' => 'projects/naseebak-test-project/messages/msg_sub',
            ], 200),
        ]);

        $user = $this->createEligibleMember();
        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $notificationService->registerDeviceToken($user, str_repeat('subTok_', 18), 'android');

        // 1. Subscription activated notification (idempotent per subscription id + expiry)
        $webSub = $this->grantActiveSubscription($user, Subscription::STATUS_ACTIVE, Subscription::CHANNEL_PAYMOB, false, 48);
        $act1 = $notificationService->notifySubscriptionActivated($webSub);
        $act2 = $notificationService->notifySubscriptionActivated($webSub);
        $this->assertSame($act1->id, $act2->id);

        // 2. Expiring soon reminder works for non-auto-renewing web subscription
        $remWeb = $notificationService->notifySubscriptionExpiringSoon($webSub);
        $this->assertNotNull($remWeb);

        // 3. Google Play auto-renewing subscription skips expiring-soon reminder
        $gpAutoSub = $this->grantActiveSubscription($user, Subscription::STATUS_ACTIVE, Subscription::CHANNEL_GOOGLE_PLAY, true, 48);
        $remGp = $notificationService->notifySubscriptionExpiringSoon($gpAutoSub);
        $this->assertNull($remGp);

        // 4. Dual entitlement guard: if webSub expires while gpAutoSub is still active, NO expired notification is sent
        $webSub->update(['status' => Subscription::STATUS_EXPIRED, 'ends_at' => now()->subMinute()]);
        $expiredNotifWhileGpActive = $notificationService->notifySubscriptionExpiredIfNoOtherEntitlement($user, $webSub);
        $this->assertNull($expiredNotifWhileGpActive);

        // 5. Once gpAutoSub also expires, expired notification IS sent
        $gpAutoSub->update(['status' => Subscription::STATUS_EXPIRED, 'ends_at' => now()->subMinute()]);
        $expiredNotifFinal = $notificationService->notifySubscriptionExpiredIfNoOtherEntitlement($user, $gpAutoSub);
        $this->assertNotNull($expiredNotifFinal);
        $this->assertSame(NotificationRecord::TYPE_SUBSCRIPTION_EXPIRED, $expiredNotifFinal->event_type);
    }

    public function test_08_notification_preferences_suppress_fcm_push_while_keeping_in_app_record(): void
    {
        Http::fake();

        $user1 = $this->createEligibleMember([], ['gender' => 'male']);
        $user2 = $this->createEligibleMember([], ['gender' => 'female']);

        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $notificationService->registerDeviceToken($user2, str_repeat('prefTok_', 18), 'android');

        Sanctum::actingAs($user2);

        // Disable messages push preference via PATCH /api/v1/notification-preferences
        $this->patchJson('/api/v1/notification-preferences', [
            'messages_enabled' => false,
        ])->assertStatus(200)
          ->assertJsonPath('data.preferences.messages_enabled', false);

        $matchReq = MatchmakingRequest::create([
            'sender_id' => $user1->id,
            'recipient_id' => $user2->id,
            'status' => MatchmakingRequest::STATUS_ACCEPTED,
            'responded_at' => now(),
        ]);
        $pair = Conversation::canonicalPair($user1->id, $user2->id);
        $conversation = Conversation::create([
            'matchmaking_request_id' => $matchReq->id,
            'user_one_id' => $pair['user_one_id'],
            'user_two_id' => $pair['user_two_id'],
            'status' => Conversation::STATUS_ACTIVE,
        ]);
        ConversationParticipant::create(['conversation_id' => $conversation->id, 'user_id' => $user1->id, 'joined_at' => now()]);
        ConversationParticipant::create(['conversation_id' => $conversation->id, 'user_id' => $user2->id, 'joined_at' => now()]);
        $msg = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $user1->id,
            'body' => 'مرحبا',
            'status' => Message::STATUS_SENT,
        ]);

        $record = $notificationService->notifyPrivateMessageSent($conversation, $msg, $user2->id);

        $this->assertNotNull($record);
        $this->assertSame(NotificationRecord::DELIVERY_DISABLED_BY_PREFERENCE, $record->fcm_delivery_status);

        // No FCM HTTP call was made
        Http::assertNothingSent();
    }

    public function test_09_in_app_notification_center_pagination_mark_read_mark_all_read_and_delete_authorization(): void
    {
        $userA = $this->createEligibleMember([], ['gender' => 'female']);
        $userB = $this->createEligibleMember([], ['gender' => 'male']);

        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $n1 = $notificationService->createAndDispatchNotification(
            recipient: $userA,
            eventType: NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            titleAr: 'طلب تعارف جديد',
            bodyAr: 'لديك طلب تعارف جديد',
            deduplicationKey: 'test_n1'
        );
        $n2 = $notificationService->createAndDispatchNotification(
            recipient: $userA,
            eventType: NotificationRecord::TYPE_ACCEPTED_MATCHMAKING_REQUEST,
            titleAr: 'تمت الموافقة على طلبك',
            bodyAr: 'تمت الموافقة على طلب التعارف',
            deduplicationKey: 'test_n2'
        );

        Sanctum::actingAs($userA);

        // List & unread count
        $this->getJson('/api/v1/notifications')
            ->assertStatus(200)
            ->assertJsonPath('data.unread_count', 2);

        // User B cannot mark User A's notification as read or delete it
        Sanctum::actingAs($userB);
        $this->postJson("/api/v1/notifications/{$n1->id}/read")->assertStatus(403);
        $this->deleteJson("/api/v1/notifications/{$n1->id}")->assertStatus(403);

        // User A marks single notification as read
        Sanctum::actingAs($userA);
        $this->postJson("/api/v1/notifications/{$n1->id}/read")
            ->assertStatus(200)
            ->assertJsonPath('data.unread_count', 1);

        // User A marks all as read
        $this->postJson('/api/v1/notifications/read-all')
            ->assertStatus(200)
            ->assertJsonPath('data.unread_count', 0);

        // User A deletes notification
        $this->deleteJson("/api/v1/notifications/{$n2->id}")
            ->assertStatus(200);

        $this->assertDatabaseMissing('notifications', ['id' => $n2->id]);
    }

    public function test_10_admin_announcement_campaign_chunked_dispatch_respects_preferences_and_idempotency(): void
    {
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::response([
                'name' => 'projects/naseebak-test-project/messages/msg_camp',
            ], 200),
        ]);

        $admin = Administrator::create([
            'name' => 'مدير الإشعارات',
            'email' => 'admin_notif@naseebak.app',
            'password' => bcrypt('SecretAdminPass123!'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $memberOptIn = $this->createEligibleMember();
        $memberOptOut = $this->createEligibleMember();

        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        $notificationService->updatePreferences($memberOptOut, [
            'announcements_enabled' => false,
        ]);

        $campaign = AnnouncementCampaign::create([
            'created_by_admin_id' => $admin->id,
            'title_ar' => 'تحديث جديد في منصة نصيبك',
            'body_ar' => 'تم إطلاق مزايا جديدة لتحسين تجربة البحث والتعارف الجاد.',
            'target_segment' => AnnouncementCampaign::SEGMENT_ALL_ACTIVE_MEMBERS,
            'action_route' => NotificationRecord::ROUTE_NOTIFICATION_CENTER,
            'status' => AnnouncementCampaign::STATUS_QUEUED,
        ]);

        // Run DispatchAnnouncementCampaignJob synchronously
        $job = new DispatchAnnouncementCampaignJob($campaign->id);
        $job->handle($notificationService);

        $campaign->refresh();
        $this->assertSame(AnnouncementCampaign::STATUS_COMPLETED, $campaign->status);
        $this->assertSame(1, $campaign->dispatched_count);

        // Opt-in member received notification, opt-out member did not
        $this->assertDatabaseHas('notifications', [
            'user_id' => $memberOptIn->id,
            'campaign_id' => $campaign->id,
            'event_type' => NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT,
        ]);
        $this->assertDatabaseMissing('notifications', [
            'user_id' => $memberOptOut->id,
            'campaign_id' => $campaign->id,
        ]);
    }

    public function test_11_fcm_invalid_argument_preserves_token_on_payload_error_and_invalidates_only_on_confirmed_token_error_and_preserves_on_sender_id_mismatch(): void
    {
        $user = $this->createEligibleMember();
        /** @var NotificationService $notificationService */
        $notificationService = app(NotificationService::class);
        /** @var \App\Services\Notification\FcmNotificationService $fcmService */
        $fcmService = app(\App\Services\Notification\FcmNotificationService::class);

        $token = $notificationService->registerDeviceToken(
            $user,
            str_repeat('validDeviceToken77_', 12),
            'android'
        );

        // Case A: INVALID_ARGUMENT caused by payload field violation (NOT message.token) -> preserve token!
        Http::fake([
            'https://fcm.googleapis.com/v1/projects/*/messages:send' => Http::Sequence()
                ->push([
                    'error' => [
                        'code' => 400,
                        'message' => 'Invalid value at message.android.ttl',
                        'status' => 'INVALID_ARGUMENT',
                        'details' => [
                            [
                                '@type' => 'type.googleapis.com/google.rpc.BadRequest',
                                'fieldViolations' => [
                                    ['field' => 'message.android.ttl', 'description' => 'Invalid duration format'],
                                ],
                            ],
                        ],
                    ],
                ], 400)
                ->push([
                    'error' => [
                        'code' => 403,
                        'message' => 'SenderId mismatch',
                        'status' => 'PERMISSION_DENIED',
                        'details' => [
                            [
                                '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                                'errorCode' => 'SENDER_ID_MISMATCH',
                            ],
                        ],
                    ],
                ], 403)
                ->push([
                    'error' => [
                        'code' => 400,
                        'message' => 'The registration token is not a valid FCM registration token',
                        'status' => 'INVALID_ARGUMENT',
                        'details' => [
                            [
                                '@type' => 'type.googleapis.com/google.rpc.BadRequest',
                                'fieldViolations' => [
                                    ['field' => 'message.token', 'description' => 'The registration token is not a valid FCM registration token'],
                                ],
                            ],
                        ],
                    ],
                ], 400),
        ]);

        // 1. Payload INVALID_ARGUMENT -> token remains valid, should_retry = false
        $n1 = NotificationRecord::create([
            'event_id' => (string) \Illuminate\Support\Str::uuid(),
            'deduplication_key' => 'case_a_payload',
            'user_id' => $user->id,
            'event_type' => NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            'title_ar' => 'طلب تعارف جديد',
            'body_ar' => 'لديك طلب تعارف جديد',
            'action_route' => NotificationRecord::ROUTE_MATCHMAKING_INCOMING,
            'fcm_delivery_status' => NotificationRecord::DELIVERY_QUEUED,
        ]);

        $resA = $fcmService->sendNotificationToUserDevices($n1, 1);
        $this->assertFalse($resA['should_retry']);
        $this->assertSame('INVALID_PAYLOAD_ARGUMENT', $resA['last_error_code']);
        $token->refresh();
        $this->assertTrue($token->is_valid);

        // 2. SENDER_ID_MISMATCH -> token remains valid, should_retry = false
        $n2 = NotificationRecord::create([
            'event_id' => (string) \Illuminate\Support\Str::uuid(),
            'deduplication_key' => 'case_b_sender_mismatch',
            'user_id' => $user->id,
            'event_type' => NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            'title_ar' => 'طلب تعارف جديد',
            'body_ar' => 'لديك طلب تعارف جديد',
            'action_route' => NotificationRecord::ROUTE_MATCHMAKING_INCOMING,
            'fcm_delivery_status' => NotificationRecord::DELIVERY_QUEUED,
        ]);

        $resB = $fcmService->sendNotificationToUserDevices($n2, 1);
        $this->assertFalse($resB['should_retry']);
        $this->assertSame('SENDER_ID_MISMATCH', $resB['last_error_code']);
        $token->refresh();
        $this->assertTrue($token->is_valid);

        // 3. INVALID_ARGUMENT specifically targeting message.token -> token IS invalidated
        $n3 = NotificationRecord::create([
            'event_id' => (string) \Illuminate\Support\Str::uuid(),
            'deduplication_key' => 'case_c_bad_token',
            'user_id' => $user->id,
            'event_type' => NotificationRecord::TYPE_NEW_MATCHMAKING_REQUEST,
            'title_ar' => 'طلب تعارف جديد',
            'body_ar' => 'لديك طلب تعارف جديد',
            'action_route' => NotificationRecord::ROUTE_MATCHMAKING_INCOMING,
            'fcm_delivery_status' => NotificationRecord::DELIVERY_QUEUED,
        ]);

        $resC = $fcmService->sendNotificationToUserDevices($n3, 1);
        $this->assertFalse($resC['should_retry']);
        $token->refresh();
        $this->assertFalse($token->is_valid);
        $this->assertSame('INVALID_REGISTRATION_TOKEN', $token->invalidated_reason);
    }
}
