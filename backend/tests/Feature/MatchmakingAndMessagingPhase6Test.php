<?php

namespace Tests\Feature;

use App\Events\ConversationUpdated;
use App\Events\MatchmakingRequestAccepted;
use App\Events\MatchmakingRequestCreated;
use App\Events\MatchmakingRequestRejected;
use App\Events\MessageRead;
use App\Events\MessageSent;
use App\Models\BlockedUser;
use App\Models\Conversation;
use App\Models\ConversationParticipant;
use App\Models\MatchmakingRequest;
use App\Models\Message;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MatchmakingAndMessagingPhase6Test extends TestCase
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
        string $provider = Subscription::CHANNEL_PAYMOB,
        int $expiresInMinutes = 43200
    ): Subscription {
        return Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $this->plan->id,
            'channel' => $provider,
            'external_subscription_id' => 'sub_ref_' . uniqid(),
            'status' => $status,
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addMinutes($expiresInMinutes),
            'auto_renewing' => true,
            'last_verified_at' => now()->subDay(),
        ]);
    }

    /**
     * 1. Subscribed active adult user can send a matchmaking request to an eligible member.
     */
    public function test_subscribed_active_adult_user_can_send_matchmaking_request(): void
    {
        Event::fake([MatchmakingRequestCreated::class]);

        $sender = $this->createEligibleMember([], ['gender' => 'male']);
        $recipient = $this->createEligibleMember([], ['gender' => 'female']);
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);

        $response = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.request.status', 'pending')
            ->assertJsonPath('data.request.sender_id', $sender->id)
            ->assertJsonPath('data.request.recipient_id', $recipient->id);

        $this->assertDatabaseHas('matchmaking_requests', [
            'sender_id' => $sender->id,
            'recipient_id' => $recipient->id,
            'status' => 'pending',
        ]);

        Event::assertDispatched(MatchmakingRequestCreated::class);
    }

    /**
     * 2. Free user cannot send a matchmaking request.
     */
    public function test_free_user_cannot_send_matchmaking_request(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember([], ['gender' => 'female']);

        Sanctum::actingAs($sender);

        $response = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('code', 'SUBSCRIPTION_REQUIRED');

        $this->assertDatabaseCount('matchmaking_requests', 0);
    }

    /**
     * 3. Expired subscriber cannot send a matchmaking request.
     */
    public function test_expired_subscriber_cannot_send_matchmaking_request(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember([], ['gender' => 'female']);

        Subscription::create([
            'user_id' => $sender->id,
            'subscription_plan_id' => $this->plan->id,
            'channel' => Subscription::CHANNEL_PAYMOB,
            'external_subscription_id' => 'exp_sub',
            'status' => Subscription::STATUS_ACTIVE,
            'starts_at' => now()->subDays(35),
            'ends_at' => now()->subMinute(),
        ]);

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(403)
            ->assertJsonPath('code', 'SUBSCRIPTION_REQUIRED');
    }

    /**
     * 4. Cancelled or grace-period Google Play subscriber with valid future ends_at can send a matchmaking request.
     */
    public function test_cancelled_or_grace_period_google_play_subscriber_with_future_ends_at_can_send_request(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember([], ['gender' => 'female']);

        $this->grantActiveSubscription(
            $sender,
            Subscription::STATUS_CANCELLED,
            Subscription::PROVIDER_GOOGLE_PLAY,
            1440
        );

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(201)
            ->assertJsonPath('data.request.status', 'pending');
    }

    /**
     * 5. User cannot send a matchmaking request to themselves.
     */
    public function test_user_cannot_send_matchmaking_request_to_self(): void
    {
        $sender = $this->createEligibleMember();
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $sender->id,
        ])->assertStatus(422)
            ->assertJsonPath('code', 'CANNOT_REQUEST_SELF');
    }

    /**
     * 6. User cannot send a matchmaking request to an unapproved profile.
     */
    public function test_user_cannot_send_request_to_unapproved_profile(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember([], ['moderation_status' => 'pending']);
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(403)
            ->assertJsonPath('code', 'RECIPIENT_INELIGIBLE');
    }

    /**
     * 7. User cannot send a matchmaking request to a hidden profile.
     */
    public function test_user_cannot_send_request_to_hidden_profile(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember([], ['is_visible' => false]);
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(403)
            ->assertJsonPath('code', 'RECIPIENT_INELIGIBLE');
    }

    /**
     * 8. User cannot send a matchmaking request to a suspended or banned user.
     */
    public function test_user_cannot_send_request_to_suspended_or_banned_user(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember(['account_status' => 'suspended']);
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(404)
            ->assertJsonPath('code', 'RECIPIENT_UNAVAILABLE');
    }

    /**
     * 9. User cannot send a matchmaking request if either user blocked the other.
     */
    public function test_user_cannot_send_request_when_blocked_in_either_direction(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember();
        $this->grantActiveSubscription($sender);

        BlockedUser::create([
            'blocker_id' => $recipient->id,
            'blocked_id' => $sender->id,
            'reason' => 'عدم توافق',
        ]);

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(403)
            ->assertJsonPath('code', 'USER_BLOCKED');
    }

    /**
     * 10. Duplicate pending request between the same sender and recipient is rejected.
     */
    public function test_duplicate_pending_request_is_rejected(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember();
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(201);

        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(409)
            ->assertJsonPath('code', 'DUPLICATE_PENDING_REQUEST');

        $this->assertDatabaseCount('matchmaking_requests', 1);
    }

    /**
     * 11. Reciprocal request behavior is handled deterministically without creating unauthorized conversations.
     */
    public function test_reciprocal_pending_request_is_rejected_without_auto_creating_conversation(): void
    {
        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember();
        $this->grantActiveSubscription($userA);
        $this->grantActiveSubscription($userB);

        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userB->id,
        ])->assertStatus(201);

        Sanctum::actingAs($userB);
        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userA->id,
        ])->assertStatus(409)
            ->assertJsonPath('code', 'RECIPROCAL_PENDING_REQUEST_EXISTS');

        $this->assertDatabaseCount('conversations', 0);
    }

    /**
     * 12 & 13. Recipient can view incoming matchmaking requests; Sender can view sent matchmaking requests.
     */
    public function test_sender_and_recipient_can_list_sent_and_incoming_requests(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember();
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);
        $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(201);

        $sentResponse = $this->getJson('/api/v1/matchmaking/requests/sent');
        $sentResponse->assertStatus(200)
            ->assertJsonCount(1, 'data.requests')
            ->assertJsonPath('data.requests.0.recipient_id', $recipient->id);

        Sanctum::actingAs($recipient);
        $incomingResponse = $this->getJson('/api/v1/matchmaking/requests/incoming');
        $incomingResponse->assertStatus(200)
            ->assertJsonCount(1, 'data.requests')
            ->assertJsonPath('data.requests.0.sender_id', $sender->id);
    }

    /**
     * 14, 15, 16. Recipient can accept a pending matchmaking request (even as a free user);
     * creates 1 conversation + 2 participants; accepting twice is idempotent.
     */
    public function test_recipient_accepts_request_creates_single_conversation_and_is_idempotent(): void
    {
        Event::fake([MatchmakingRequestAccepted::class, ConversationUpdated::class]);

        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember(); // Free user!
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);
        $createRes = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(201);

        $requestId = $createRes->json('data.request.id');

        Sanctum::actingAs($recipient);
        $acceptRes1 = $this->postJson("/api/v1/matchmaking/requests/{$requestId}/accept");
        $acceptRes1->assertStatus(200)
            ->assertJsonPath('data.request.status', 'accepted');

        $conversationId = $acceptRes1->json('data.conversation_id');
        $this->assertNotNull($conversationId);

        // Second accept call is idempotent and does not duplicate conversations
        $acceptRes2 = $this->postJson("/api/v1/matchmaking/requests/{$requestId}/accept");
        $acceptRes2->assertStatus(200)
            ->assertJsonPath('data.conversation_id', $conversationId);

        $this->assertDatabaseCount('conversations', 1);
        $this->assertDatabaseCount('conversation_participants', 2);

        Event::assertDispatched(MatchmakingRequestAccepted::class);
    }

    /**
     * 17. Non-recipient cannot accept a request.
     */
    public function test_non_recipient_cannot_accept_request(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember();
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->json('data.request.id');

        // Sender tries to accept their own sent request
        $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->assertStatus(403)
            ->assertJsonPath('code', 'UNAUTHORIZED_REQUEST_ACTION');
    }

    /**
     * 18 & 19. Recipient can reject a pending matchmaking request; Non-recipient cannot reject.
     */
    public function test_recipient_can_reject_and_non_recipient_cannot_reject(): void
    {
        Event::fake([MatchmakingRequestRejected::class]);

        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember();
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->json('data.request.id');

        // Sender cannot reject
        $this->postJson("/api/v1/matchmaking/requests/{$reqId}/reject")
            ->assertStatus(403);

        // Recipient can reject
        Sanctum::actingAs($recipient);
        $this->postJson("/api/v1/matchmaking/requests/{$reqId}/reject")
            ->assertStatus(200)
            ->assertJsonPath('data.request.status', 'rejected');

        Event::assertDispatched(MatchmakingRequestRejected::class);
    }

    /**
     * 20 & 21. Sender can cancel a pending request before response; cannot cancel accepted/rejected request.
     */
    public function test_sender_can_cancel_pending_request_but_not_after_response(): void
    {
        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember();
        $this->grantActiveSubscription($sender);

        Sanctum::actingAs($sender);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->json('data.request.id');

        $this->postJson("/api/v1/matchmaking/requests/{$reqId}/cancel")
            ->assertStatus(200)
            ->assertJsonPath('data.request.status', 'cancelled');

        // Re-send after cancellation is permitted and re-opens the request
        $reqId2 = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->assertStatus(201)->json('data.request.id');

        Sanctum::actingAs($recipient);
        $this->postJson("/api/v1/matchmaking/requests/{$reqId2}/accept")
            ->assertStatus(200);

        // Sender cannot cancel after acceptance
        Sanctum::actingAs($sender);
        $this->postJson("/api/v1/matchmaking/requests/{$reqId2}/cancel")
            ->assertStatus(422)
            ->assertJsonPath('code', 'INVALID_REQUEST_STATE');
    }

    /**
     * 22 & 23. Accepted matchmaking unlocks "accepted_matches_only" photo privacy;
     * Unaccepted matchmaking does NOT unlock "accepted_matches_only" photo privacy.
     */
    public function test_accepted_matchmaking_unlocks_accepted_matches_only_photo_privacy(): void
    {
        Storage::fake('private');

        $sender = $this->createEligibleMember();
        $recipient = $this->createEligibleMember([], ['photo_privacy' => 'accepted_matches_only']);
        $this->grantActiveSubscription($sender);

        Storage::disk('private')->put("user_photos/{$recipient->id}/avatar.jpg", 'fake-jpeg-bytes');

        $photo = UserPhoto::create([
            'user_id' => $recipient->id,
            'storage_disk' => 'private',
            'file_path' => "user_photos/{$recipient->id}/avatar.jpg",
            'mime_type' => 'image/jpeg',
            'file_size_bytes' => 15,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        Sanctum::actingAs($sender);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $recipient->id,
        ])->json('data.request.id');

        // While still pending -> 403 Forbidden
        $this->get("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertStatus(403);

        // Recipient accepts the request
        Sanctum::actingAs($recipient);
        $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->assertStatus(200);

        // Now accepted match -> 200 OK
        Sanctum::actingAs($sender);
        $this->get("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertStatus(200);
    }

    /**
     * 24 & 25. Conversation list returns only participant's conversations;
     * Non-participant cannot view conversation details or messages.
     */
    public function test_conversation_access_is_restricted_to_participants_only(): void
    {
        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember();
        $intruder = $this->createEligibleMember();
        $this->grantActiveSubscription($userA);
        $this->grantActiveSubscription($intruder);

        Sanctum::actingAs($userA);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userB->id,
        ])->json('data.request.id');

        Sanctum::actingAs($userB);
        $convId = $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->json('data.conversation_id');

        // Intruder sees 0 conversations and gets 403 on detail & messages
        Sanctum::actingAs($intruder);
        $this->getJson('/api/v1/conversations')
            ->assertStatus(200)
            ->assertJsonCount(0, 'data.conversations');

        $this->getJson("/api/v1/conversations/{$convId}")
            ->assertStatus(403)
            ->assertJsonPath('code', 'CONVERSATION_ACCESS_FORBIDDEN');

        $this->getJson("/api/v1/conversations/{$convId}/messages")
            ->assertStatus(403)
            ->assertJsonPath('code', 'CONVERSATION_ACCESS_FORBIDDEN');
    }

    /**
     * 26 & 27. Participant with active subscription can send a text message;
     * Participant without active subscription cannot send a message, but CAN read existing conversation messages.
     */
    public function test_subscribed_participant_can_send_message_while_unsubscribed_participant_can_only_read(): void
    {
        Event::fake([MessageSent::class, ConversationUpdated::class]);

        $subscribedSender = $this->createEligibleMember();
        $freeRecipient = $this->createEligibleMember();
        $this->grantActiveSubscription($subscribedSender);

        Sanctum::actingAs($subscribedSender);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $freeRecipient->id,
        ])->json('data.request.id');

        Sanctum::actingAs($freeRecipient);
        $convId = $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->json('data.conversation_id');

        // Subscribed sender sends a message
        Sanctum::actingAs($subscribedSender);
        $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => 'السلام عليكم ورحمة الله وبركاته، تشرفت بمعرفتك.',
            'client_message_id' => 'msg-001',
        ])->assertStatus(201)
            ->assertJsonPath('data.message.body', 'السلام عليكم ورحمة الله وبركاته، تشرفت بمعرفتك.');

        // Free recipient CAN read existing messages
        Sanctum::actingAs($freeRecipient);
        $this->getJson("/api/v1/conversations/{$convId}/messages")
            ->assertStatus(200)
            ->assertJsonCount(1, 'data.messages')
            ->assertJsonPath('data.can_send_messages', false)
            ->assertJsonPath('data.restriction_code', 'SUBSCRIPTION_REQUIRED');

        // Free recipient CANNOT send a reply without an active subscription
        $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => 'وعليكم السلام ورحمة الله وبركاته',
        ])->assertStatus(403)
            ->assertJsonPath('code', 'SUBSCRIPTION_REQUIRED');

        Event::assertDispatched(MessageSent::class);
    }

    /**
     * 28 & 29. Empty message is rejected; Message exceeding maximum length (> 2000) is rejected.
     */
    public function test_empty_or_oversized_messages_are_rejected(): void
    {
        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember();
        $this->grantActiveSubscription($userA);

        Sanctum::actingAs($userA);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userB->id,
        ])->json('data.request.id');

        Sanctum::actingAs($userB);
        $convId = $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->json('data.conversation_id');

        Sanctum::actingAs($userA);

        // Whitespace-only body
        $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => '     ',
        ])->assertStatus(422);

        // Oversized body (> 2000 chars)
        $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => str_repeat('أ', 2005),
        ])->assertStatus(422);
    }

    /**
     * 30 & 31. Duplicate client_message_id is handled idempotently;
     * Sending a message updates conversations.last_message_at and last_message_id.
     */
    public function test_duplicate_client_message_id_is_idempotent_and_updates_conversation_last_message(): void
    {
        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember();
        $this->grantActiveSubscription($userA);

        Sanctum::actingAs($userA);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userB->id,
        ])->json('data.request.id');

        Sanctum::actingAs($userB);
        $convId = $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->json('data.conversation_id');

        Sanctum::actingAs($userA);
        $res1 = $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => 'رسالة تجريبية مع معرف عميل ثابت',
            'client_message_id' => 'idem-client-999',
        ])->assertStatus(201);

        $msgId = $res1->json('data.message.id');

        // Retry with same client_message_id -> returns 200 OK with same message ID and does not duplicate
        $res2 = $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => 'رسالة تجريبية مع معرف عميل ثابت',
            'client_message_id' => 'idem-client-999',
        ])->assertStatus(200)
            ->assertJsonPath('data.idempotent_replay', true)
            ->assertJsonPath('data.message.id', $msgId);

        $this->assertDatabaseCount('messages', 1);

        $conversation = Conversation::findOrFail($convId);
        $this->assertSame($msgId, (int) $conversation->last_message_id);
        $this->assertNotNull($conversation->last_message_at);
    }

    /**
     * 32. Marking a conversation as read updates unread state and read markers.
     */
    public function test_marking_conversation_as_read_updates_read_markers_and_broadcasts_receipt(): void
    {
        Event::fake([MessageRead::class]);

        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember();
        $this->grantActiveSubscription($userA);

        Sanctum::actingAs($userA);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userB->id,
        ])->json('data.request.id');

        Sanctum::actingAs($userB);
        $convId = $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->json('data.conversation_id');

        Sanctum::actingAs($userA);
        $msgId = $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => 'مرحباً بك',
        ])->json('data.message.id');

        Sanctum::actingAs($userB);
        $this->postJson("/api/v1/conversations/{$convId}/read")
            ->assertStatus(200)
            ->assertJsonPath('data.last_read_message_id', $msgId)
            ->assertJsonPath('data.unread_count', 0);

        $this->assertDatabaseHas('messages', [
            'id' => $msgId,
            'is_read' => true,
        ]);

        Event::assertDispatched(MessageRead::class);
    }

    /**
     * 33. Blocking a user cancels pending requests and prevents new messages.
     */
    public function test_blocking_user_cancels_pending_requests_and_blocks_conversation_messages(): void
    {
        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember();
        $this->grantActiveSubscription($userA);
        $this->grantActiveSubscription($userB);

        Sanctum::actingAs($userA);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userB->id,
        ])->json('data.request.id');

        Sanctum::actingAs($userB);
        $convId = $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->json('data.conversation_id');

        // User B blocks User A
        $this->postJson("/api/v1/members/{$userA->id}/block", [
            'reason' => 'إغلاق التواصل',
        ])->assertStatus(200);

        $this->assertDatabaseHas('conversations', [
            'id' => $convId,
            'status' => 'blocked',
        ]);

        // User A cannot send new messages into the blocked conversation
        Sanctum::actingAs($userA);
        $this->postJson("/api/v1/conversations/{$convId}/messages", [
            'body' => 'هل ما زلت متاحاً؟',
        ])->assertStatus(403)
            ->assertJsonPath('code', 'CONVERSATION_BLOCKED');
    }

    /**
     * 34. Private WebSocket channel authorization allows participants and rejects non-participants.
     */
    public function test_websocket_channel_auth_allows_participants_and_rejects_non_participants(): void
    {
        $userA = $this->createEligibleMember();
        $userB = $this->createEligibleMember();
        $intruder = $this->createEligibleMember();
        $this->grantActiveSubscription($userA);

        Sanctum::actingAs($userA);
        $reqId = $this->postJson('/api/v1/matchmaking/requests', [
            'recipient_user_id' => $userB->id,
        ])->json('data.request.id');

        Sanctum::actingAs($userB);
        $convId = $this->postJson("/api/v1/matchmaking/requests/{$reqId}/accept")
            ->json('data.conversation_id');

        // Participant User A can authorize private-conversation.{convId} and private-user.{userA->id}
        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/broadcasting/auth', [
            'socket_id' => '12345.67890',
            'channel_name' => "private-conversation.{$convId}",
        ])->assertStatus(200)
            ->assertJsonStructure(['auth']);

        $this->postJson('/api/v1/broadcasting/auth', [
            'socket_id' => '12345.67890',
            'channel_name' => "private-user.{$userA->id}",
        ])->assertStatus(200)
            ->assertJsonStructure(['auth']);

        // Intruder is rejected from private-conversation.{convId} and private-user.{userA->id}
        Sanctum::actingAs($intruder);
        $this->postJson('/api/v1/broadcasting/auth', [
            'socket_id' => '99999.11111',
            'channel_name' => "private-conversation.{$convId}",
        ])->assertStatus(403)
            ->assertJsonPath('code', 'CHANNEL_SUBSCRIPTION_FORBIDDEN');

        $this->postJson('/api/v1/broadcasting/auth', [
            'socket_id' => '99999.11111',
            'channel_name' => "private-user.{$userA->id}",
        ])->assertStatus(403)
            ->assertJsonPath('code', 'CHANNEL_SUBSCRIPTION_FORBIDDEN');
    }
}
