<?php

namespace Tests\Feature;

use App\Models\Administrator;
use App\Models\PaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Auth\GoogleIdTokenVerifierService;
use App\Services\Payment\PaymobGatewayService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Mockery;
use Tests\TestCase;

class Phase18WebsiteAndPaymentsTest extends TestCase
{
    use RefreshDatabase;

    private const PAYMOB_HMAC_SECRET = 'phase18_test_paymob_hmac_secret_123456';

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed();

        config([
            'naseebak.google_auth.web_client_id' => 'test-web-client-id.apps.googleusercontent.com',
            'naseebak.google_auth.web_client_secret' => 'test-web-client-secret',
            'naseebak.google_auth.web_redirect_uri' => 'https://naseebak.hazem.my/auth/google/callback',
            'naseebak.web_payments.paymob.secret_key' => 'egy_sk_test_phase18',
            'naseebak.web_payments.paymob.public_key' => 'egy_pk_test_phase18',
            'naseebak.web_payments.paymob.hmac_secret' => self::PAYMOB_HMAC_SECRET,
            'naseebak.web_payments.paymob.integration_id_card' => 445566,
            'naseebak.web_payments.paymob.api_key' => 'test-paymob-api-key',
        ]);

        PaymentSetting::where('id', 1)->update([
            'active_web_payment_gateway' => 'paymob',
            'paymob_configured' => true,
        ]);
    }

    public function test_landing_page_renders_arabic_rtl_brand_and_real_plan_prices(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
        $response->assertSee('dir="rtl"', false);
        $response->assertSee('كل حكاية جميلة', false);
        $response->assertSee('IBM+Plex+Sans+Arabic', false);
        $response->assertSee('naseebak-website.css', false);
        $response->assertSee('الباقة الشهرية', false);
        $response->assertSee('الباقة الربع سنوية', false);
        $response->assertSee('250');
        $response->assertSee('600');
        $response->assertDontSee('play.google.com/store/apps/details?id=fake');
    }

    public function test_plans_page_displays_only_monthly_and_quarterly_plans_with_exact_savings(): void
    {
        $response = $this->get('/plans');

        $response->assertStatus(200);
        $response->assertSee('الباقة الشهرية');
        $response->assertSee('الباقة الربع سنوية');
        $response->assertSee('وفر 20%');
        $response->assertSee('250');
        $response->assertSee('600');
    }

    public function test_support_subscription_terms_and_refund_policy_pages_render(): void
    {
        $this->get('/support')->assertStatus(200)->assertSee('الدعم والتواصل مع فريق نَصِيبُكَ');
        $this->get('/legal/subscription-terms')->assertStatus(200)->assertSee('شروط الاشتراك');
        $this->get('/legal/refund-policy')->assertStatus(200)->assertSee('سياسة الاسترداد');
    }

    public function test_super_admin_can_update_monthly_and_quarterly_prices_with_exact_minor_units_and_moderator_blocked(): void
    {
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);

        $this->actingAs($moderator, 'admin')
            ->putJson('/admin/operations/settings/plans/quarterly_membership', [
                'web_price_amount' => '549.50',
            ])
            ->assertStatus(403);

        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/plans/quarterly_membership', [
                'web_price_amount' => '549.50',
                'name_ar' => 'الباقة الربع سنوية المميزة',
                'is_active' => true,
                'reason' => 'تحديث موسمي',
            ])
            ->assertStatus(200)
            ->assertJsonPath('data.price_minor', 54950)
            ->assertJsonPath('data.duration_months', 3)
            ->assertJsonPath('data.name_ar', 'الباقة الربع سنوية المميزة');

        $quarterly = SubscriptionPlan::where('code', 'quarterly_membership')->firstOrFail();
        $this->assertSame(54950, (int) $quarterly->price_minor);
        $this->assertSame('549.50', (string) $quarterly->web_price_amount);
    }

    public function test_admin_plan_price_change_preserves_historical_orders(): void
    {
        $user = $this->createMember('hist@example.com', 'sub-hist-1');
        $quarterly = SubscriptionPlan::where('code', 'quarterly_membership')->firstOrFail();

        $oldTx = PaymentTransaction::create([
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
            'internal_reference' => 'NSB-PMB-HISTORDER1',
            'user_id' => $user->id,
            'subscription_plan_id' => $quarterly->id,
            'gateway' => 'paymob',
            'amount' => '600.00',
            'amount_minor' => 60000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
        ]);

        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/plans/quarterly_membership', [
                'web_price_amount' => '750.00',
            ])
            ->assertStatus(200);

        $oldTx->refresh();
        $this->assertSame('600.00', (string) $oldTx->amount);
        $this->assertSame(60000, (int) $oldTx->amount_minor);
    }

    public function test_unauthenticated_visitors_are_redirected_from_account_and_checkout(): void
    {
        $this->get('/account')->assertRedirect();
        $this->get('/plans/monthly_membership/checkout')->assertRedirect();
        $this->post('/checkout', ['plan_code' => 'monthly_membership'])->assertRedirect();
    }

    public function test_google_oauth_redirect_generates_state_and_sanitizes_intended_plan(): void
    {
        $response = $this->get('/auth/google/redirect?plan=quarterly_membership');

        $response->assertRedirect();
        $location = (string) $response->headers->get('Location');
        $this->assertStringStartsWith('https://accounts.google.com/o/oauth2/v2/auth?', $location);
        $this->assertStringContainsString('state=', $location);
        $this->assertSame('quarterly_membership', session('website_intended_plan'));

        $this->get('/auth/google/redirect?plan=https://evil.com');
        $this->assertSame('quarterly_membership', session('website_intended_plan'));
    }

    public function test_google_oauth_callback_rejects_missing_or_mismatched_state(): void
    {
        $this->withSession(['google_oauth_state' => 'expected-secret-state'])
            ->get('/auth/google/callback?code=fake-code&state=wrong-state')
            ->assertStatus(403);

        $this->assertGuest('web');
    }

    public function test_google_oauth_callback_creates_member_and_redirects_to_intended_checkout(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response([
                'access_token' => 'ya29.fake',
                'id_token' => 'fake.google.id.token',
            ], 200),
        ]);

        $verifier = Mockery::mock(GoogleIdTokenVerifierService::class);
        $verifier->shouldReceive('verifyIdToken')
            ->once()
            ->with('fake.google.id.token')
            ->andReturn([
                'sub' => 'google-sub-phase18-new',
                'email' => 'newmember@example.com',
                'email_verified' => true,
                'name' => 'أحمد علي',
            ]);
        $this->app->instance(GoogleIdTokenVerifierService::class, $verifier);

        $response = $this->withSession([
            'google_oauth_state' => 'valid-oauth-state-123',
            'website_intended_plan' => 'quarterly_membership',
        ])->get('/auth/google/callback?code=auth-code-123&state=valid-oauth-state-123');

        $response->assertRedirect('/plans/quarterly_membership/checkout');
        $this->assertAuthenticated('web');
        $this->assertDatabaseHas('users', [
            'google_sub' => 'google-sub-phase18-new',
            'email' => 'newmember@example.com',
            'account_status' => 'active',
        ]);
    }

    public function test_google_oauth_callback_maps_to_same_android_user_by_google_sub(): void
    {
        $androidUser = $this->createMember('android@example.com', 'shared-android-sub');

        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response(['id_token' => 'fake.id.token'], 200),
        ]);

        $verifier = Mockery::mock(GoogleIdTokenVerifierService::class);
        $verifier->shouldReceive('verifyIdToken')->once()->andReturn([
            'sub' => 'shared-android-sub',
            'email' => 'android@example.com',
            'email_verified' => true,
            'name' => 'Android User',
        ]);
        $this->app->instance(GoogleIdTokenVerifierService::class, $verifier);

        $this->withSession(['google_oauth_state' => 'state-ok'])
            ->get('/auth/google/callback?code=code-ok&state=state-ok')
            ->assertRedirect('/account');

        $this->assertAuthenticatedAs($androidUser, 'web');
    }

    public function test_google_oauth_callback_blocks_unverified_email(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response(['id_token' => 'fake.id.token'], 200),
        ]);

        $v1 = Mockery::mock(GoogleIdTokenVerifierService::class);
        $v1->shouldReceive('verifyIdToken')->once()->andReturn([
            'sub' => 'unverified-sub',
            'email' => 'unv@example.com',
            'email_verified' => false,
            'name' => 'Unverified',
        ]);
        $this->app->instance(GoogleIdTokenVerifierService::class, $v1);

        $this->withSession(['google_oauth_state' => 's1'])
            ->get('/auth/google/callback?code=c1&state=s1')
            ->assertStatus(403);
        $this->assertGuest('web');
    }

    public function test_google_oauth_callback_blocks_email_only_merge_without_matching_sub(): void
    {
        $this->createMember('taken@example.com', 'original-sub-1');

        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response(['id_token' => 'fake.id.token'], 200),
        ]);

        $v2 = Mockery::mock(GoogleIdTokenVerifierService::class);
        $v2->shouldReceive('verifyIdToken')->once()->andReturn([
            'sub' => 'different-attacker-sub',
            'email' => 'taken@example.com',
            'email_verified' => true,
            'name' => 'Attacker',
        ]);
        $this->app->instance(GoogleIdTokenVerifierService::class, $v2);

        $this->withSession(['google_oauth_state' => 's2'])
            ->get('/auth/google/callback?code=c2&state=s2')
            ->assertStatus(409);
        $this->assertGuest('web');
    }

    public function test_google_oauth_callback_blocks_suspended_users(): void
    {
        $this->createMember('suspended@example.com', 'suspended-sub-1', 'suspended');

        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response(['id_token' => 'fake.id.token'], 200),
        ]);

        $v3 = Mockery::mock(GoogleIdTokenVerifierService::class);
        $v3->shouldReceive('verifyIdToken')->once()->andReturn([
            'sub' => 'suspended-sub-1',
            'email' => 'suspended@example.com',
            'email_verified' => true,
            'name' => 'Suspended',
        ]);
        $this->app->instance(GoogleIdTokenVerifierService::class, $v3);

        $this->withSession(['google_oauth_state' => 's3'])
            ->get('/auth/google/callback?code=c3&state=s3')
            ->assertStatus(403);
        $this->assertGuest('web');
    }

    public function test_checkout_rejects_client_tampered_price_amount_or_user_id(): void
    {
        $member = $this->createMember('tamper@example.com', 'sub-tamper-1');

        $this->actingAs($member, 'web')
            ->post('/checkout', [
                'plan_code' => 'quarterly_membership',
                'price' => '1.00',
                'amount' => '1.00',
                'user_id' => 9999,
                'status' => 'succeeded',
            ])
            ->assertSessionHasErrors(['price', 'amount', 'user_id', 'status']);

        $this->assertDatabaseCount('payment_transactions', 0);
    }

    public function test_valid_quarterly_checkout_creates_server_priced_order_and_redirects_to_paymob(): void
    {
        $member = $this->createMember('buyer@example.com', 'sub-buyer-1');

        Http::fake([
            'https://accept.paymob.com/v1/intention/' => Http::response([
                'id' => 778899,
                'intention_order_id' => 998877,
                'client_secret' => 'egy_cs_test_quarterly_123',
            ], 201),
        ]);

        $response = $this->actingAs($member, 'web')
            ->post('/checkout', ['plan_code' => 'quarterly_membership']);

        $response->assertRedirect();
        $location = (string) $response->headers->get('Location');
        $this->assertStringContainsString('https://accept.paymob.com/unifiedcheckout/', $location);
        $this->assertStringContainsString('egy_cs_test_quarterly_123', $location);

        Http::assertSent(function ($request) {
            return $request->url() === 'https://accept.paymob.com/v1/intention/'
                && $request['amount'] === 60000
                && $request['currency'] === 'EGP'
                && str_contains((string) $request['redirection_url'], '/payment/return/NSB-PMB-')
                && str_contains((string) $request['notification_url'], '/api/v1/webhooks/paymob');
        });

        $tx = PaymentTransaction::firstOrFail();
        $this->assertSame($member->id, (int) $tx->user_id);
        $this->assertSame(60000, (int) $tx->amount_minor);
        $this->assertSame('600.00', (string) $tx->amount);
        $this->assertSame(PaymentTransaction::STATUS_PENDING, $tx->status);
    }

    public function test_payment_return_page_never_activates_pending_order_before_verified_webhook(): void
    {
        $member = $this->createMember('return@example.com', 'sub-return-1');
        $quarterly = SubscriptionPlan::where('code', 'quarterly_membership')->firstOrFail();

        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
            'internal_reference' => 'NSB-PMB-PENDINGRET1',
            'user_id' => $member->id,
            'subscription_plan_id' => $quarterly->id,
            'gateway' => 'paymob',
            'amount' => '600.00',
            'amount_minor' => 60000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
            'signature_verified' => false,
        ]);

        // Even with spoofed ?success=true query parameter, DB stays pending and user stays free
        $response = $this->actingAs($member, 'web')
            ->get('/payment/return/' . $tx->internal_reference . '?success=true');

        $response->assertStatus(200);
        $response->assertSee('طلب الدفع قيد المعالجة والتحقق');
        $this->assertFalse($member->fresh()->hasActiveSubscription());
    }

    public function test_verified_paymob_webhook_for_quarterly_plan_grants_three_calendar_months_and_syncs_mobile_api(): void
    {
        $this->travelTo(Carbon::parse('2026-01-15 10:00:00', 'UTC'));

        $member = $this->createMember('qbuyer@example.com', 'sub-qbuyer-1');
        $quarterly = SubscriptionPlan::where('code', 'quarterly_membership')->firstOrFail();

        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
            'internal_reference' => 'NSB-PMB-QUARTERLY1',
            'user_id' => $member->id,
            'subscription_plan_id' => $quarterly->id,
            'gateway' => 'paymob',
            'amount' => '600.00',
            'amount_minor' => 60000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
            'signature_verified' => false,
        ]);

        $obj = $this->buildPaymobCallbackObject([
            'id' => 910001,
            'amount_cents' => 60000,
            'success' => true,
            'pending' => false,
            'order' => ['id' => 810001, 'merchant_order_id' => $tx->internal_reference],
        ]);
        $hmac = PaymobGatewayService::computeHmac($obj, self::PAYMOB_HMAC_SECRET);

        $this->postJson('/api/v1/webhooks/paymob?hmac=' . $hmac, ['obj' => $obj])
            ->assertStatus(200);

        $this->assertTrue($member->fresh()->hasActiveSubscription());

        $sub = Subscription::where('user_id', $member->id)->firstOrFail();
        $this->assertSame('2026-04-15 10:00:00', $sub->ends_at->format('Y-m-d H:i:s'));

        // Mobile Sanctum API recognizes website-purchased membership seamlessly!
        $token = $member->createToken('android-app')->plainTextToken;
        $this->withToken($token)
            ->getJson('/api/v1/subscription')
            ->assertStatus(200)
            ->assertJsonPath('data.entitlement.has_active_subscription', true)
            ->assertJsonPath('data.entitlement.payment_channel', 'paymob');

        // Website Account Dashboard shows succeeded status & paid membership
        $this->actingAs($member, 'web')
            ->get('/account')
            ->assertStatus(200)
            ->assertSee('اشتراك فعّال')
            ->assertSee('مدفوع ومؤكد');

        $this->travelBack();
    }

    public function test_quarterly_renewal_stacks_after_existing_active_expiry(): void
    {
        $this->travelTo(Carbon::parse('2026-03-01 12:00:00', 'UTC'));

        $member = $this->createMember('stack@example.com', 'sub-stack-1');
        $quarterly = SubscriptionPlan::where('code', 'quarterly_membership')->firstOrFail();

        Subscription::create([
            'user_id' => $member->id,
            'subscription_plan_id' => $quarterly->id,
            'channel' => Subscription::CHANNEL_PAYMOB,
            'status' => Subscription::STATUS_ACTIVE,
            'starts_at' => now()->subDays(10),
            'ends_at' => Carbon::parse('2026-03-20 12:00:00', 'UTC'),
        ]);

        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
            'internal_reference' => 'NSB-PMB-RENEW3M1',
            'user_id' => $member->id,
            'subscription_plan_id' => $quarterly->id,
            'gateway' => 'paymob',
            'amount' => '600.00',
            'amount_minor' => 60000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
            'signature_verified' => false,
        ]);

        $obj = $this->buildPaymobCallbackObject([
            'id' => 910002,
            'amount_cents' => 60000,
            'success' => true,
            'pending' => false,
            'order' => ['id' => 810002, 'merchant_order_id' => $tx->internal_reference],
        ]);
        $hmac = PaymobGatewayService::computeHmac($obj, self::PAYMOB_HMAC_SECRET);

        $this->postJson('/api/v1/webhooks/paymob?hmac=' . $hmac, ['obj' => $obj])
            ->assertStatus(200);

        $sub = Subscription::where('user_id', $member->id)->firstOrFail();
        $this->assertSame('2026-06-20 12:00:00', $sub->ends_at->format('Y-m-d H:i:s'));

        $this->travelBack();
    }

    public function test_pending_order_cancellation_and_ownership_enforcement(): void
    {
        $owner = $this->createMember('owner@example.com', 'sub-owner-1');
        $other = $this->createMember('other@example.com', 'sub-other-1');
        $plan = SubscriptionPlan::where('code', 'monthly_membership')->firstOrFail();

        $pendingTx = PaymentTransaction::create([
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
            'internal_reference' => 'NSB-PMB-CANCELME1',
            'user_id' => $owner->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => 'paymob',
            'amount' => '250.00',
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
            'signature_verified' => false,
        ]);

        // Other user cannot poll or view return page or cancel owner's order
        $this->actingAs($other, 'web')->getJson('/orders/' . $pendingTx->internal_reference . '/status')->assertStatus(403);
        $this->actingAs($other, 'web')->get('/payment/return/' . $pendingTx->internal_reference)->assertStatus(403);
        $this->actingAs($other, 'web')->post('/orders/' . $pendingTx->internal_reference . '/cancel')->assertRedirect('/account');
        $this->assertSame(PaymentTransaction::STATUS_PENDING, $pendingTx->fresh()->status);

        // Owner polls safely (read-only) then cancels pending order
        $this->actingAs($owner, 'web')
            ->getJson('/orders/' . $pendingTx->internal_reference . '/status')
            ->assertStatus(200)
            ->assertJsonPath('data.transaction_status', 'pending')
            ->assertJsonPath('data.has_active_subscription', false);

        $this->actingAs($owner, 'web')
            ->post('/orders/' . $pendingTx->internal_reference . '/cancel')
            ->assertRedirect('/payment/return/' . $pendingTx->internal_reference);

        $pendingTx->refresh();
        $this->assertSame(PaymentTransaction::STATUS_CANCELLED, $pendingTx->status);
        $this->assertNotNull($pendingTx->cancelled_at);
    }

    public function test_refund_webhook_revokes_quarterly_entitlement_and_sha7nawy_stays_fail_closed(): void
    {
        $member = $this->createMember('refund@example.com', 'sub-refund-1');
        $quarterly = SubscriptionPlan::where('code', 'quarterly_membership')->firstOrFail();

        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
            'internal_reference' => 'NSB-PMB-REFUND3M',
            'user_id' => $member->id,
            'subscription_plan_id' => $quarterly->id,
            'gateway' => 'paymob',
            'amount' => '600.00',
            'amount_minor' => 60000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
            'signature_verified' => false,
        ]);

        $successObj = $this->buildPaymobCallbackObject([
            'id' => 920001,
            'amount_cents' => 60000,
            'success' => true,
            'pending' => false,
            'order' => ['id' => 820001, 'merchant_order_id' => $tx->internal_reference],
        ]);
        $this->postJson('/api/v1/webhooks/paymob?hmac=' . PaymobGatewayService::computeHmac($successObj, self::PAYMOB_HMAC_SECRET), [
            'obj' => $successObj,
            'event_id' => 'evt-succ-1',
        ])->assertStatus(200);

        $this->assertTrue($member->fresh()->hasActiveSubscription());

        $refundObj = $this->buildPaymobCallbackObject([
            'id' => 920001,
            'amount_cents' => 60000,
            'success' => true,
            'pending' => false,
            'is_refunded' => true,
            'order' => ['id' => 820001, 'merchant_order_id' => $tx->internal_reference],
        ]);
        $this->postJson('/api/v1/webhooks/paymob?hmac=' . PaymobGatewayService::computeHmac($refundObj, self::PAYMOB_HMAC_SECRET), [
            'obj' => $refundObj,
            'event_id' => 'evt-ref-1',
        ])->assertStatus(200);

        $this->assertFalse($member->fresh()->hasActiveSubscription());

        // Sha7nawy remains fail-closed even if DB gateway flag is switched on without spec
        PaymentSetting::where('id', 1)->update([
            'active_web_payment_gateway' => 'sha7nawy',
            'sha7nawy_configured' => true,
            'sha7nawy_integration_status' => 'ready',
        ]);

        $this->actingAs($member, 'web')
            ->post('/checkout', ['plan_code' => 'monthly_membership'])
            ->assertRedirect('/plans/monthly_membership/checkout')
            ->assertSessionHas('checkout_error');

        $this->assertFalse($member->fresh()->hasActiveSubscription());
    }

    private function createMember(string $email, string $googleSub, string $status = 'active'): User
    {
        return User::create([
            'google_sub' => $googleSub,
            'email' => $email,
            'email_verified' => true,
            'role' => 'member',
            'account_status' => $status,
            'profile_completed' => false,
            'last_active_at' => now(),
        ]);
    }

    private function createAdmin(string $role): Administrator
    {
        return Administrator::create([
            'name' => $role . ' Admin',
            'email' => $role . '-' . uniqid() . '@hazem.my',
            'password' => Hash::make('Secret@2026!'),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function buildPaymobCallbackObject(array $overrides = []): array
    {
        $base = [
            'id' => 999111,
            'amount_cents' => 60000,
            'created_at' => '2026-11-12T10:00:00.000000',
            'currency' => 'EGP',
            'error_occured' => false,
            'has_parent_transaction' => false,
            'integration_id' => 445566,
            'is_3d_secure' => true,
            'is_auth' => false,
            'is_capture' => false,
            'is_refunded' => false,
            'is_standalone_payment' => true,
            'is_voided' => false,
            'order' => [
                'id' => 888111,
                'merchant_order_id' => 'NSB-PMB-TEST',
            ],
            'owner' => 1001,
            'pending' => false,
            'source_data' => [
                'pan' => '2345',
                'sub_type' => 'MasterCard',
                'type' => 'card',
            ],
            'success' => true,
        ];

        return array_replace_recursive($base, $overrides);
    }
}
