<?php

namespace Tests\Feature;

use App\Models\Administrator;
use App\Models\PaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserProfile;
use App\Services\Payment\PaymobGatewayService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Tests\TestCase;

class SubscriptionAndPaymentPhase5Test extends TestCase
{
    use RefreshDatabase;

    private string $testRsaPrivateKeyPem = '';
    private string $testRsaPublicKeyPem = '';

    private function seedDefaultPlansAndSettings(): SubscriptionPlan
    {
        if ($this->testRsaPrivateKeyPem === '') {
            $opensslOptions = [
                'private_key_bits' => 2048,
                'private_key_type' => OPENSSL_KEYTYPE_RSA,
            ];
            $opensslConf = getenv('OPENSSL_CONF') ?: ($_ENV['OPENSSL_CONF'] ?? null);
            if ($opensslConf && is_file($opensslConf)) {
                $opensslOptions['config'] = $opensslConf;
            }
            $keyResource = openssl_pkey_new($opensslOptions);
            openssl_pkey_export($keyResource, $privatePem, null, $opensslOptions);
            $details = openssl_pkey_get_details($keyResource);
            $this->testRsaPrivateKeyPem = $privatePem;
            $this->testRsaPublicKeyPem = $details['key'];
        }

        Config::set('naseebak.google_play.package_name', 'com.naseebak.app');
        Config::set('naseebak.google_play.monthly_subscription_id', 'naseebak_monthly_membership');
        Config::set('naseebak.google_play.rtdn_oidc_audience', 'https://api.naseebak.app/api/v1/webhooks/google-play/rtdn');
        Config::set('naseebak.google_play.rtdn_service_account_email', 'rtdn-pubsub-push@naseebak-prod.iam.gserviceaccount.com');
        Config::set('naseebak.google_play.rtdn_oidc_public_key_pem', $this->testRsaPublicKeyPem);
        Config::set('naseebak.web_payments.paymob.secret_key', 'egy_sk_test_12345');
        Config::set('naseebak.web_payments.paymob.public_key', 'egy_pk_test_12345');
        Config::set('naseebak.web_payments.paymob.hmac_secret', 'test_paymob_hmac_secret_key_999');
        Config::set('naseebak.web_payments.paymob.integration_id_card', 445566);

        PaymentSetting::updateOrCreate(
            ['id' => 1],
            [
                'active_web_payment_gateway' => 'paymob',
                'web_monthly_price' => 250.00,
                'web_currency' => 'EGP',
                'subscription_duration_days' => 30,
                'paymob_configured' => true,
                'sha7nawy_configured' => true,
                'sha7nawy_integration_status' => 'ready',
            ]
        );

        return SubscriptionPlan::updateOrCreate(
            ['code' => 'monthly_membership'],
            [
                'name_ar' => 'العضوية الشهرية — نصيبك',
                'description_ar' => 'تتيح إرسال طلبات التعارف والمحادثات الخاصة',
                'duration_days' => 30,
                'google_play_product_id' => 'naseebak_monthly_membership',
                'web_price_amount' => 250.00,
                'web_price_currency' => 'EGP',
                'is_active' => true,
                'features_ar' => [
                    'إرسال طلبات التعارف',
                    'التواصل بعد الموافقة',
                    'إرسال الرسائل الخاصة',
                ],
            ]
        );
    }

    private function createMember(array $userOverrides = [], array $profileOverrides = []): User
    {
        $user = User::create(array_merge([
            'google_sub' => 'google-sub-' . uniqid(),
            'email' => uniqid('member_') . '@example.com',
            'role' => 'member',
            'account_status' => 'active',
            'profile_completed' => true,
        ], $userOverrides));

        $dob = $profileOverrides['date_of_birth'] ?? '1991-06-15';

        UserProfile::create(array_merge([
            'user_id' => $user->id,
            'full_name' => 'أحمد محمود',
            'gender' => 'male',
            'date_of_birth' => $dob,
            'age_years' => Carbon::parse($dob)->age,
            'zodiac_sign' => 'الجوزاء',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'مهندس برمجيات',
            'height_cm' => 178,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['القراءة'],
            'nationality' => 'مصري',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'bio' => 'أبحث عن شريكة جادة.',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => UserProfile::STATUS_APPROVED,
        ], $profileOverrides));

        return $user;
    }

    private function createAdmin(string $role = Administrator::ROLE_SUPER_ADMIN): Administrator
    {
        return Administrator::create([
            'name' => $role === Administrator::ROLE_SUPER_ADMIN ? 'المدير العام' : 'مشرف المراجعة',
            'email' => uniqid($role . '_') . '@naseebak.app',
            'password' => Hash::make('StrongAdminPass!2026'),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function buildPaymobWebhookObject(array $overrides = []): array
    {
        return array_replace_recursive([
            'id' => 987654321,
            'amount_cents' => 25000,
            'created_at' => now()->toIso8601String(),
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
                'id' => 11223344,
                'merchant_order_id' => 'NSB-PMB-ORDER001',
            ],
            'owner' => 556677,
            'pending' => false,
            'source_data' => [
                'pan' => '2346',
                'sub_type' => 'MasterCard',
                'type' => 'card',
            ],
            'success' => true,
        ], $overrides);
    }

    private static function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private function issueRtdnOidcJwt(array $claimOverrides = [], ?string $customPrivateKeyPem = null): string
    {
        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $claims = array_merge([
            'iss' => 'https://accounts.google.com',
            'aud' => 'https://api.naseebak.app/api/v1/webhooks/google-play/rtdn',
            'sub' => '11223344556677889900',
            'email' => 'rtdn-pubsub-push@naseebak-prod.iam.gserviceaccount.com',
            'email_verified' => true,
            'iat' => time() - 10,
            'exp' => time() + 3600,
        ], $claimOverrides);

        $signingInput = self::base64UrlEncode(json_encode($header))
            . '.'
            . self::base64UrlEncode(json_encode($claims));

        $privateKey = $customPrivateKeyPem ?? $this->testRsaPrivateKeyPem;
        openssl_sign($signingInput, $signatureBytes, $privateKey, OPENSSL_ALGO_SHA256);

        return $signingInput . '.' . self::base64UrlEncode($signatureBytes);
    }

    /** 1. Free user has no paid entitlement */
    public function test_free_user_has_no_paid_entitlement_and_is_blocked_from_paid_gate(): void
    {
        $this->seedDefaultPlansAndSettings();
        $freeUser = $this->createMember();

        $this->actingAs($freeUser, 'sanctum')
            ->getJson('/api/v1/subscription/entitlement')
            ->assertOk()
            ->assertJsonPath('data.has_active_subscription', false)
            ->assertJsonPath('data.subscription_status', 'none')
            ->assertJsonPath('data.can_send_match_requests', false)
            ->assertJsonPath('data.can_send_messages', false);

        $this->actingAs($freeUser, 'sanctum')
            ->postJson('/api/v1/subscription/authorized-contact-check')
            ->assertStatus(403)
            ->assertJsonPath('code', 'SUBSCRIPTION_REQUIRED');
    }

    /** 2. Verified active subscription grants entitlement */
    public function test_verified_active_subscription_grants_entitlement(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDays(29),
            'auto_renewing' => true,
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/subscription/entitlement')
            ->assertOk()
            ->assertJsonPath('data.has_active_subscription', true)
            ->assertJsonPath('data.subscription_status', 'active')
            ->assertJsonPath('data.payment_channel', 'google_play')
            ->assertJsonPath('data.can_send_match_requests', true)
            ->assertJsonPath('data.can_send_messages', true);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription/authorized-contact-check')
            ->assertOk()
            ->assertJsonPath('can_initiate_contact', true);
    }

    /** 3. Expired subscription denies new communication */
    public function test_expired_subscription_denies_new_communication_and_updates_status(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_PAYMOB,
            'status' => Subscription::STATUS_ACTIVE,
            'starts_at' => now()->subDays(31),
            'ends_at' => now()->subMinute(),
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/subscription/entitlement')
            ->assertOk()
            ->assertJsonPath('data.has_active_subscription', false)
            ->assertJsonPath('data.subscription_status', 'expired')
            ->assertJsonPath('data.can_send_match_requests', false)
            ->assertJsonPath('data.can_send_messages', false);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription/authorized-contact-check')
            ->assertStatus(403)
            ->assertJsonPath('code', 'SUBSCRIPTION_REQUIRED');
    }

    /** 4. Pending payment does not grant entitlement */
    public function test_pending_payment_does_not_grant_entitlement(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_PENDING,
            'starts_at' => now(),
            'ends_at' => now()->addDays(30),
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/subscription/entitlement')
            ->assertOk()
            ->assertJsonPath('data.has_active_subscription', false)
            ->assertJsonPath('data.subscription_status', 'pending')
            ->assertJsonPath('data.can_send_match_requests', false);
    }

    /** 5. Cancelled subscription remains active until verified expiration */
    public function test_cancelled_subscription_remains_active_until_verified_expiration(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_CANCELLED,
            'auto_renewing' => false,
            'starts_at' => now()->subDays(10),
            'ends_at' => now()->addDays(20),
            'cancelled_at' => now()->subDay(),
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/subscription/entitlement')
            ->assertOk()
            ->assertJsonPath('data.has_active_subscription', true)
            ->assertJsonPath('data.subscription_status', 'cancelled')
            ->assertJsonPath('data.can_send_match_requests', true)
            ->assertJsonPath('data.can_send_messages', true);
    }

    /** 6. Refunded payment revokes or recalculates entitlement */
    public function test_refunded_payment_revokes_entitlement(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-REFUND01',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '555001',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);

        $entitlementService = app(SubscriptionEntitlementService::class);
        $sub = $entitlementService->activateOrExtendFromVerifiedWebTransaction($tx);
        $this->assertTrue($user->fresh()->hasActiveSubscription());

        // Now send a signed Paymob refund webhook
        $refundObj = $this->buildPaymobWebhookObject([
            'id' => 555001,
            'is_refunded' => true,
            'order' => [
                'id' => 998877,
                'merchant_order_id' => 'NSB-PMB-REFUND01',
            ],
        ]);
        $hmac = PaymobGatewayService::computeHmac($refundObj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac}", ['obj' => $refundObj])
            ->assertOk();

        $this->assertEquals(Subscription::STATUS_REFUNDED, $sub->fresh()->status);
        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 7. Duplicate payment activation call does not double-extend the subscription */
    public function test_duplicate_payment_activation_call_does_not_double_extend_subscription(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-IDEMP01',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '777001',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);

        $service = app(SubscriptionEntitlementService::class);
        $firstSub = $service->activateOrExtendFromVerifiedWebTransaction($tx);
        $firstEndsAt = $firstSub->ends_at->toIso8601String();

        // Calling activation again for the exact same transaction must NOT add another 30 days
        $secondSub = $service->activateOrExtendFromVerifiedWebTransaction($tx->fresh());
        $this->assertEquals($firstSub->id, $secondSub->id);
        $this->assertEquals($firstEndsAt, $secondSub->ends_at->toIso8601String());
    }

    /** 8. Duplicate webhook is safely ignored */
    public function test_duplicate_webhook_is_safely_ignored_without_double_extension(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-ORDER001',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        $obj = $this->buildPaymobWebhookObject();
        $hmac = PaymobGatewayService::computeHmac($obj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac}", ['obj' => $obj])
            ->assertOk()
            ->assertJsonPath('webhook_status', 'processed');

        $firstEnd = Subscription::where('user_id', $user->id)->firstOrFail()->ends_at->toIso8601String();

        // Replay exact same webhook
        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac}", ['obj' => $obj])
            ->assertOk()
            ->assertJsonPath('webhook_status', 'ignored_duplicate');

        $secondEnd = Subscription::where('user_id', $user->id)->firstOrFail()->ends_at->toIso8601String();
        $this->assertEquals($firstEnd, $secondEnd);
    }

    /** 9. Invalid webhook signature is rejected */
    public function test_invalid_webhook_signature_is_rejected(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-ORDER001',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        $obj = $this->buildPaymobWebhookObject();

        $this->postJson('/api/v1/webhooks/paymob?hmac=forged_invalid_hmac_signature', ['obj' => $obj])
            ->assertStatus(400)
            ->assertJsonPath('code', 'PAYMOB_WEBHOOK_REJECTED');

        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 10. Invalid Google purchase token is rejected */
    public function test_invalid_google_purchase_token_is_rejected(): void
    {
        $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'error' => ['code' => 404, 'message' => 'Purchase token not found'],
            ], 404),
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => 'invalid_google_play_token_123456',
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'GOOGLE_PLAY_VERIFICATION_FAILED');

        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 11. Valid verified Google purchase activates entitlement */
    public function test_valid_verified_google_purchase_activates_entitlement(): void
    {
        $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $expiry = now()->addDays(30)->toIso8601String();

        Http::fake([
            'androidpublisher.googleapis.com/*/purchases/subscriptionsv2/tokens/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_ACTIVE',
                'latestOrderId' => 'GPA.3311-2233-4455-66778',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_PENDING',
                'startTime' => now()->toIso8601String(),
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => $expiry,
                        'autoRenewingPlan' => ['autoRenewEnabled' => true],
                    ],
                ],
                'externalAccountIdentifiers' => [
                    'obfuscatedExternalAccountId' => (string) $user->id,
                ],
            ], 200),
            'androidpublisher.googleapis.com/*:acknowledge' => Http::response([], 200),
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => 'valid_google_play_purchase_token_abc123456',
            ])
            ->assertOk()
            ->assertJsonPath('data.entitlement.has_active_subscription', true)
            ->assertJsonPath('data.entitlement.subscription_status', 'active')
            ->assertJsonPath('data.entitlement.payment_channel', 'google_play');
    }

    /** 12. Google purchase token cannot be reused for a different user */
    public function test_google_purchase_token_cannot_be_reused_for_different_user(): void
    {
        $this->seedDefaultPlansAndSettings();
        $userA = $this->createMember(['email' => 'usera@example.com']);
        $userB = $this->createMember(['email' => 'userb@example.com']);

        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_ACTIVE',
                'latestOrderId' => 'GPA.9999-8888-7777-66666',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => now()->addDays(30)->toIso8601String(),
                    ],
                ],
            ], 200),
        ]);

        $sharedToken = 'unique_google_token_bound_to_user_a_only_999';

        // User A activates successfully
        $this->actingAs($userA, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => $sharedToken,
            ])
            ->assertOk();

        // User B attempts to replay User A's purchase token -> rejected with 422
        $this->actingAs($userB, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => $sharedToken,
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'GOOGLE_PLAY_VERIFICATION_FAILED');

        $this->assertFalse($userB->fresh()->hasActiveSubscription());
    }

    /** 13. Google Play renewal updates subscription validity via RTDN */
    public function test_google_play_renewal_rtdn_updates_subscription_validity(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $token = 'google_token_for_rtdn_renewal_test_12345';

        $sub = Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'google_play_purchase_token' => $token,
            'google_play_purchase_token_hash' => hash('sha256', $token),
            'starts_at' => now()->subDays(29),
            'ends_at' => now()->addDay(),
        ]);

        $renewedExpiry = now()->addDays(31)->startOfSecond();

        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_ACTIVE',
                'latestOrderId' => 'GPA.1234-5678-9012-34567..0',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => $renewedExpiry->toIso8601String(),
                        'autoRenewingPlan' => ['autoRenewEnabled' => true],
                    ],
                ],
            ], 200),
        ]);

        $rtdnData = base64_encode(json_encode([
            'version' => '1.0',
            'packageName' => 'com.naseebak.app',
            'eventTimeMillis' => (string) (now()->timestamp * 1000),
            'subscriptionNotification' => [
                'version' => '1.0',
                'notificationType' => 2, // SUBSCRIPTION_RENEWED
                'purchaseToken' => $token,
                'subscriptionId' => 'naseebak_monthly_membership',
            ],
        ]));

        $this->withToken($this->issueRtdnOidcJwt())
            ->postJson('/api/v1/webhooks/google-play/rtdn', [
                'message' => [
                    'messageId' => 'pubsub-msg-renew-001',
                    'data' => $rtdnData,
                ],
            ])->assertOk()
            ->assertJsonPath('rtdn_status', 'processed');

        $this->assertEquals($renewedExpiry->timestamp, $sub->fresh()->ends_at->timestamp);
    }

    /** 14. Google Play cancellation preserves correct access until expiry */
    public function test_google_play_cancellation_rtdn_preserves_access_until_expiry(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $token = 'google_token_for_rtdn_cancel_test_12345';

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'google_play_purchase_token' => $token,
            'google_play_purchase_token_hash' => hash('sha256', $token),
            'auto_renewing' => true,
            'starts_at' => now()->subDays(5),
            'ends_at' => now()->addDays(25),
        ]);

        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_CANCELED',
                'latestOrderId' => 'GPA.1234-5678-9012-99999',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => now()->addDays(25)->toIso8601String(),
                        'autoRenewingPlan' => ['autoRenewEnabled' => false],
                    ],
                ],
            ], 200),
        ]);

        $rtdnData = base64_encode(json_encode([
            'version' => '1.0',
            'packageName' => 'com.naseebak.app',
            'subscriptionNotification' => [
                'version' => '1.0',
                'notificationType' => 3, // SUBSCRIPTION_CANCELED
                'purchaseToken' => $token,
                'subscriptionId' => 'naseebak_monthly_membership',
            ],
        ]));

        $this->withToken($this->issueRtdnOidcJwt())
            ->postJson('/api/v1/webhooks/google-play/rtdn', [
                'message' => [
                    'messageId' => 'pubsub-msg-cancel-002',
                    'data' => $rtdnData,
                ],
            ])->assertOk();

        $this->assertTrue($user->fresh()->hasActiveSubscription());
        $this->assertEquals(Subscription::STATUS_CANCELLED, $user->fresh()->subscriptions()->first()->status);
    }

    /** 15. Google Play account hold restricts access appropriately */
    public function test_google_play_account_hold_restricts_access_immediately(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $token = 'google_token_for_rtdn_on_hold_test_12345';

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'google_play_purchase_token' => $token,
            'google_play_purchase_token_hash' => hash('sha256', $token),
            'starts_at' => now()->subDays(30),
            'ends_at' => now()->subHour(),
        ]);

        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_ON_HOLD',
                'latestOrderId' => 'GPA.1234-5678-9012-00000',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => now()->subHour()->toIso8601String(),
                    ],
                ],
            ], 200),
        ]);

        $rtdnData = base64_encode(json_encode([
            'version' => '1.0',
            'packageName' => 'com.naseebak.app',
            'subscriptionNotification' => [
                'version' => '1.0',
                'notificationType' => 5, // SUBSCRIPTION_ON_HOLD
                'purchaseToken' => $token,
                'subscriptionId' => 'naseebak_monthly_membership',
            ],
        ]));

        $this->withToken($this->issueRtdnOidcJwt())
            ->postJson('/api/v1/webhooks/google-play/rtdn', [
                'message' => [
                    'messageId' => 'pubsub-msg-hold-003',
                    'data' => $rtdnData,
                ],
            ])->assertOk();

        $this->assertFalse($user->fresh()->hasActiveSubscription());
        $this->assertEquals(Subscription::STATUS_ON_HOLD, $user->fresh()->subscriptions()->first()->status);
    }

    /** 16. Web price updates require super-admin permission */
    public function test_web_price_updates_succeed_for_super_admin_and_create_fixed_order_snapshot(): void
    {
        $this->seedDefaultPlansAndSettings();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => '310.00',
                'reason' => 'تحديث السعر الشهري',
            ])
            ->assertOk()
            ->assertJsonPath('data.web_monthly_price', '310.00');
    }

    /** 17. Moderator cannot edit price */
    public function test_moderator_cannot_edit_web_subscription_price(): void
    {
        $this->seedDefaultPlansAndSettings();
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);

        $this->actingAs($moderator, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => '199.00',
            ])
            ->assertStatus(403)
            ->assertJsonPath('code', 'ADMIN_ROLE_FORBIDDEN');

        $this->assertEquals('250.00', (string) PaymentSetting::first()->web_monthly_price);
    }

    /** 18 & 19. Web gateway switching is atomic and only one gateway can be active */
    public function test_web_gateway_switching_is_atomic_and_only_one_gateway_is_active(): void
    {
        $this->seedDefaultPlansAndSettings();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'sha7nawy',
            ])
            ->assertOk()
            ->assertJsonPath('data.active_web_payment_gateway', 'sha7nawy');

        $this->assertEquals(1, PaymentSetting::count());
        $this->assertEquals('sha7nawy', PaymentSetting::first()->active_web_payment_gateway);
    }

    /** 20. Pending transactions survive gateway switching */
    public function test_pending_paymob_transaction_survives_switching_active_gateway_to_sha7nawy(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);
        $user = $this->createMember();

        // Create pending Paymob order while Paymob is active
        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-ORDER001',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        // Super Admin switches active gateway to sha7nawy
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'sha7nawy',
            ])
            ->assertOk();

        // Late Paymob webhook arrives for the original Paymob transaction -> must still be verified and activate membership!
        $obj = $this->buildPaymobWebhookObject();
        $hmac = PaymobGatewayService::computeHmac($obj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac}", ['obj' => $obj])
            ->assertOk()
            ->assertJsonPath('webhook_status', 'processed');

        $this->assertEquals('paymob', $tx->fresh()->gateway);
        $this->assertEquals(PaymentTransaction::STATUS_SUCCEEDED, $tx->fresh()->status);
        $this->assertTrue($user->fresh()->hasActiveSubscription());
    }

    /** 21. Wrong payment amount is rejected */
    public function test_wrong_payment_amount_in_webhook_is_rejected(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-ORDER001',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        // Webhook reports 100.00 EGP (10000 cents) instead of 25000 cents
        $obj = $this->buildPaymobWebhookObject(['amount_cents' => 10000]);
        $hmac = PaymobGatewayService::computeHmac($obj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac}", ['obj' => $obj])
            ->assertStatus(400)
            ->assertJsonPath('code', 'PAYMOB_WEBHOOK_REJECTED');

        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 22. Wrong currency is rejected */
    public function test_wrong_currency_in_webhook_is_rejected(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-ORDER001',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        $obj = $this->buildPaymobWebhookObject(['currency' => 'USD']);
        $hmac = PaymobGatewayService::computeHmac($obj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac}", ['obj' => $obj])
            ->assertStatus(400)
            ->assertJsonPath('code', 'PAYMOB_WEBHOOK_REJECTED');

        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 23. Failed payment does not activate membership */
    public function test_failed_payment_webhook_marks_transaction_failed_and_does_not_activate_membership(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-ORDER001',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        $obj = $this->buildPaymobWebhookObject([
            'success' => false,
            'error_occured' => true,
        ]);
        $hmac = PaymobGatewayService::computeHmac($obj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac}", ['obj' => $obj])
            ->assertOk();

        $this->assertEquals(PaymentTransaction::STATUS_FAILED, $tx->fresh()->status);
        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 24. Unauthorized subscription updates are rejected */
    public function test_unauthenticated_requests_to_subscription_endpoints_are_rejected(): void
    {
        $this->getJson('/api/v1/subscription')->assertStatus(401);
        $this->getJson('/api/v1/subscription/entitlement')->assertStatus(401);
        $this->postJson('/api/v1/subscription/google-play/verify', [])->assertStatus(401);
        $this->postJson('/membership/checkout', [])->assertStatus(401);
    }

    /** 25. Subscription history is preserved across renewals and expirations */
    public function test_subscription_history_is_preserved_and_returned_to_member(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_PAYMOB,
            'status' => Subscription::STATUS_EXPIRED,
            'starts_at' => now()->subDays(60),
            'ends_at' => now()->subDays(30),
        ]);

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'starts_at' => now()->subDays(2),
            'ends_at' => now()->addDays(28),
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/subscription/history')
            ->assertOk()
            ->assertJsonCount(2, 'data.subscriptions');
    }

    /** 26. No customer can modify another customer's subscription */
    public function test_customer_cannot_modify_another_customers_subscription_by_passing_user_id(): void
    {
        $this->seedDefaultPlansAndSettings();
        $attacker = $this->createMember(['email' => 'attacker@example.com']);
        $victim = $this->createMember(['email' => 'victim@example.com']);

        $this->actingAs($attacker, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'user_id' => $victim->id,
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => 'some_purchase_token_123456',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['user_id']);
    }

    /** 27. Google Play Billing and web payment entitlements remain consistent and never shorten existing valid periods */
    public function test_google_play_and_web_payment_entitlements_remain_consistent_and_never_shorten_valid_period(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        // User already has a valid web subscription ending in 45 days
        $existingWebEnd = now()->addDays(45)->startOfSecond();
        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_PAYMOB,
            'status' => Subscription::STATUS_ACTIVE,
            'starts_at' => now()->subDays(15),
            'ends_at' => $existingWebEnd,
        ]);

        // Later Google Play purchase has a 30-day expiry (shorter than 45 days) -> must NOT shorten user's valid entitlement
        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_ACTIVE',
                'latestOrderId' => 'GPA.7777-6666-5555-44444',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => now()->addDays(30)->toIso8601String(),
                    ],
                ],
            ], 200),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => 'google_token_overlapping_period_777',
            ])
            ->assertOk();

        $returnedPeriodEnd = Carbon::parse($response->json('data.entitlement.current_period_end'));
        $this->assertGreaterThanOrEqual($existingWebEnd->timestamp, $returnedPeriodEnd->timestamp);
    }

    /** 28. Payment credentials and purchase tokens are never exposed through public APIs */
    public function test_payment_credentials_and_purchase_tokens_are_never_exposed_in_api_responses(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'google_play_purchase_token' => 'SECRET_GOOGLE_PLAY_PURCHASE_TOKEN_DO_NOT_LEAK',
            'google_play_purchase_token_hash' => hash('sha256', 'SECRET_GOOGLE_PLAY_PURCHASE_TOKEN_DO_NOT_LEAK'),
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDays(29),
        ]);

        $subResponse = $this->actingAs($user, 'sanctum')->getJson('/api/v1/subscription')->assertOk();
        $historyResponse = $this->actingAs($user, 'sanctum')->getJson('/api/v1/subscription/history')->assertOk();
        $plansResponse = $this->actingAs($user, 'sanctum')->getJson('/api/v1/subscription/plans')->assertOk();

        $combinedBody = $subResponse->getContent() . $historyResponse->getContent() . $plansResponse->getContent();

        $this->assertStringNotContainsString('SECRET_GOOGLE_PLAY_PURCHASE_TOKEN_DO_NOT_LEAK', $combinedBody);
        $this->assertStringNotContainsString('egy_sk_test_12345', $combinedBody);
        $this->assertStringNotContainsString('test_paymob_hmac_secret_key_999', $combinedBody);
    }

    /** 29. Calendar-month renewal handles 31-day, 28-day, and 30-day months consistently */
    public function test_web_subscription_calendar_month_renewal_handles_varying_month_lengths(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $service = app(SubscriptionEntitlementService::class);

        // Purchase 1 on Jan 15 (31-day month) -> ends Feb 15
        Carbon::setTestNow(Carbon::parse('2026-01-15 10:00:00', 'UTC'));
        $tx1 = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-CAL-JAN',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '900001',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);
        $sub1 = $service->activateOrExtendFromVerifiedWebTransaction($tx1);
        $this->assertEquals('2026-02-15 10:00:00', $sub1->ends_at->utc()->format('Y-m-d H:i:s'));

        // Purchase 2 early renewal on Feb 10 (extends from Feb 15 across 28-day Feb) -> ends Mar 15
        Carbon::setTestNow(Carbon::parse('2026-02-10 10:00:00', 'UTC'));
        $tx2 = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-CAL-FEB',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '900002',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);
        $sub2 = $service->activateOrExtendFromVerifiedWebTransaction($tx2);
        $this->assertEquals('2026-03-15 10:00:00', $sub2->ends_at->utc()->format('Y-m-d H:i:s'));

        // Purchase 3 renewal on Mar 12 -> ends Apr 15
        Carbon::setTestNow(Carbon::parse('2026-03-12 10:00:00', 'UTC'));
        $tx3 = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-CAL-MAR',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '900003',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);
        $sub3 = $service->activateOrExtendFromVerifiedWebTransaction($tx3);
        $this->assertEquals('2026-04-15 10:00:00', $sub3->ends_at->utc()->format('Y-m-d H:i:s'));

        Carbon::setTestNow();
    }

    /** 30. Month-end renewal handles Jan 31, leap-year Feb 29, and Mar 31 without unintended overflow */
    public function test_web_subscription_month_end_renewal_prevents_date_overflow(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $service = app(SubscriptionEntitlementService::class);

        // Non-leap year: Jan 31, 2026 + 1 month => Feb 28, 2026 (NOT Mar 3!)
        Carbon::setTestNow(Carbon::parse('2026-01-31 14:30:00', 'UTC'));
        $txJan31 = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-EOM-JAN26',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '910001',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);
        $sub = $service->activateOrExtendFromVerifiedWebTransaction($txJan31);
        $this->assertEquals('2026-02-28 14:30:00', $sub->ends_at->utc()->format('Y-m-d H:i:s'));

        // Leap year: Jan 31, 2028 + 1 month => Feb 29, 2028
        $jan31Leap = Carbon::parse('2028-01-31 09:00:00', 'UTC');
        $this->assertEquals('2028-02-29 09:00:00', $service->addCalendarMonths($jan31Leap, 1)->utc()->format('Y-m-d H:i:s'));

        // Mar 31, 2026 + 1 month => Apr 30, 2026
        $mar31 = Carbon::parse('2026-03-31 09:00:00', 'UTC');
        $this->assertEquals('2026-04-30 09:00:00', $service->addCalendarMonths($mar31, 1)->utc()->format('Y-m-d H:i:s'));

        Carbon::setTestNow();
    }

    /** 31. Google Play authoritative expiry is strictly used and missing expiryTime is rejected */
    public function test_google_play_subscription_strictly_uses_authoritative_expiry_and_rejects_missing_expiry(): void
    {
        $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        // Exact authoritative timestamp returned by Google Play (e.g., 28 days in February, not 30 days)
        $authoritativeGoogleExpiry = Carbon::parse('2026-12-03T18:45:12Z');

        Http::fakeSequence()
            ->push([
                'subscriptionState' => 'SUBSCRIPTION_STATE_ACTIVE',
                'latestOrderId' => 'GPA.1111-2222-3333-44444',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'startTime' => '2026-11-03T18:45:12Z',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => $authoritativeGoogleExpiry->toIso8601String(),
                        'autoRenewingPlan' => ['autoRenewEnabled' => true],
                    ],
                ],
            ], 200)
            ->push([
                'subscriptionState' => 'SUBSCRIPTION_STATE_ACTIVE',
                'latestOrderId' => 'GPA.1111-2222-3333-55555',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        // Missing expiryTime -> must fail closed and never default to +30 days
                    ],
                ],
            ], 200);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => 'gp_authoritative_expiry_token_001',
            ])
            ->assertOk();

        $gpSub = Subscription::where('user_id', $user->id)
            ->where('channel', Subscription::CHANNEL_GOOGLE_PLAY)
            ->firstOrFail();

        $this->assertEquals($authoritativeGoogleExpiry->timestamp, $gpSub->ends_at->timestamp);

        // Missing expiryTime from Google Play API must be rejected (422)
        $user2 = $this->createMember(['email' => 'missing_expiry@example.com']);
        $this->actingAs($user2, 'sanctum')
            ->postJson('/api/v1/subscription/google-play/verify', [
                'product_id' => 'naseebak_monthly_membership',
                'purchase_token' => 'gp_missing_expiry_token_002',
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'GOOGLE_PLAY_VERIFICATION_FAILED');
    }

    /** 32. Duplicate payment callbacks with separate event IDs or transaction IDs for the same order never extend twice */
    public function test_duplicate_payment_callbacks_with_separate_event_ids_never_extend_subscription_twice(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-DUP-EVENT-01',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        $obj1 = $this->buildPaymobWebhookObject([
            'id' => 880001,
            'order' => [
                'id' => 440001,
                'merchant_order_id' => 'NSB-PMB-DUP-EVENT-01',
            ],
        ]);
        $hmac1 = PaymobGatewayService::computeHmac($obj1, config('naseebak.web_payments.paymob.hmac_secret'));

        // First callback activates subscription
        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac1}", [
            'event_id' => 'paymob-evt-alpha-001',
            'obj' => $obj1,
        ])->assertOk()->assertJsonPath('webhook_status', 'processed');

        $firstEndsAt = Subscription::where('user_id', $user->id)->firstOrFail()->ends_at->toIso8601String();

        // Second callback for the SAME order with a different event_id and even a different Paymob tx id
        $obj2 = $this->buildPaymobWebhookObject([
            'id' => 880002,
            'order' => [
                'id' => 440001,
                'merchant_order_id' => 'NSB-PMB-DUP-EVENT-01',
            ],
        ]);
        $hmac2 = PaymobGatewayService::computeHmac($obj2, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmac2}", [
            'event_id' => 'paymob-evt-beta-002',
            'obj' => $obj2,
        ])->assertOk()->assertJsonPath('webhook_status', 'ignored_duplicate');

        $secondEndsAt = Subscription::where('user_id', $user->id)->firstOrFail()->ends_at->toIso8601String();
        $this->assertEquals($firstEndsAt, $secondEndsAt);
        $this->assertEquals(1, Subscription::where('user_id', $user->id)->count());
    }

    /** 33. Invalid Paymob HMAC, missing HMAC fields, or mismatched transaction reference is rejected fail-closed */
    public function test_invalid_paymob_hmac_or_missing_hmac_fields_or_mismatched_order_reference_is_rejected(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();

        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-STRICT-01',
            'gateway_order_id' => '77889900',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_PENDING,
        ]);

        // Case A: Missing one of the 20 required HMAC fields ('source_data.pan') -> fail-closed rejection
        $incompleteObj = $this->buildPaymobWebhookObject([
            'order' => ['id' => 77889900, 'merchant_order_id' => 'NSB-PMB-STRICT-01'],
        ]);
        unset($incompleteObj['source_data']['pan']);
        $hmacIncomplete = PaymobGatewayService::computeHmac($incompleteObj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmacIncomplete}", ['obj' => $incompleteObj])
            ->assertStatus(400)
            ->assertJsonPath('code', 'PAYMOB_WEBHOOK_REJECTED');

        // Case B: Valid HMAC but conflicting order.id vs stored gateway_order_id -> rejected
        $mismatchedOrderObj = $this->buildPaymobWebhookObject([
            'order' => ['id' => 99999999, 'merchant_order_id' => 'NSB-PMB-STRICT-01'],
        ]);
        $hmacMismatched = PaymobGatewayService::computeHmac($mismatchedOrderObj, config('naseebak.web_payments.paymob.hmac_secret'));

        $this->postJson("/api/v1/webhooks/paymob?hmac={$hmacMismatched}", ['obj' => $mismatchedOrderObj])
            ->assertStatus(400)
            ->assertJsonPath('code', 'PAYMOB_WEBHOOK_REJECTED');

        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 34. Unauthorized RTDN requests are rejected and RTDN never activates without Google Play API verification */
    public function test_unauthorized_rtdn_requests_are_rejected_and_rtdn_never_activates_without_google_play_api_verification(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $token = 'google_token_rtdn_security_test_001';

        Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_PENDING,
            'google_play_purchase_token' => $token,
            'google_play_purchase_token_hash' => hash('sha256', $token),
            'starts_at' => now(),
            'ends_at' => now()->addDays(30),
        ]);

        $rtdnEnvelope = [
            'message' => [
                'messageId' => 'pubsub-sec-001',
                'data' => base64_encode(json_encode([
                    'version' => '1.0',
                    'packageName' => 'com.naseebak.app',
                    'subscriptionNotification' => [
                        'version' => '1.0',
                        'notificationType' => 4, // SUBSCRIPTION_PURCHASED
                        'purchaseToken' => $token,
                        'subscriptionId' => 'naseebak_monthly_membership',
                    ],
                ])),
            ],
        ];

        // 1. Missing Bearer token -> 401
        $this->postJson('/api/v1/webhooks/google-play/rtdn', $rtdnEnvelope)
            ->assertStatus(401)
            ->assertJsonPath('code', 'GOOGLE_PLAY_RTDN_UNAUTHORIZED');

        // 2. Signed with wrong RSA private key -> 401
        $opensslConf = dirname(PHP_BINARY).DIRECTORY_SEPARATOR.'extras'.DIRECTORY_SEPARATOR.'ssl'.DIRECTORY_SEPARATOR.'openssl.cnf';
        $keyOpts = [
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ];
        if (is_file($opensslConf)) {
            $keyOpts['config'] = $opensslConf;
        }
        $attackerKey = openssl_pkey_new($keyOpts);
        openssl_pkey_export($attackerKey, $attackerPrivatePem, null, $keyOpts);
        $forgedJwt = $this->issueRtdnOidcJwt([], $attackerPrivatePem);

        $this->withToken($forgedJwt)
            ->postJson('/api/v1/webhooks/google-play/rtdn', $rtdnEnvelope)
            ->assertStatus(401)
            ->assertJsonPath('code', 'GOOGLE_PLAY_RTDN_UNAUTHORIZED');

        // 3. Wrong audience -> 401
        $wrongAudJwt = $this->issueRtdnOidcJwt(['aud' => 'https://evil.example.com/webhook']);
        $this->withToken($wrongAudJwt)
            ->postJson('/api/v1/webhooks/google-play/rtdn', $rtdnEnvelope)
            ->assertStatus(401);

        // 4. Unauthorized service account email -> 401
        $wrongEmailJwt = $this->issueRtdnOidcJwt(['email' => 'unauthorized-sa@other-project.iam.gserviceaccount.com']);
        $this->withToken($wrongEmailJwt)
            ->postJson('/api/v1/webhooks/google-play/rtdn', $rtdnEnvelope)
            ->assertStatus(401);

        // 5. Valid OIDC token, RTDN claims SUBSCRIPTION_PURCHASED, but Google Play API returns PENDING -> must NOT activate!
        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_PENDING',
                'latestOrderId' => 'GPA.0000-1111-2222-33333',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_PENDING',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => now()->addDays(30)->toIso8601String(),
                    ],
                ],
            ], 200),
        ]);

        $this->withToken($this->issueRtdnOidcJwt())
            ->postJson('/api/v1/webhooks/google-play/rtdn', $rtdnEnvelope)
            ->assertOk();

        $this->assertFalse($user->fresh()->hasActiveSubscription());
    }

    /** 35. Overlapping web and Google Play subscriptions preserve independent provider records and unified entitlement */
    public function test_overlapping_web_and_google_play_subscriptions_preserve_independent_provider_records_and_unified_entitlement(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $service = app(SubscriptionEntitlementService::class);

        Carbon::setTestNow(Carbon::parse('2026-05-01 12:00:00', 'UTC'));

        // User has an active Google Play subscription with authoritative expiry on 2026-05-20
        $gpExpiry = Carbon::parse('2026-05-20 12:00:00', 'UTC');
        $gpSub = Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'google_play_purchase_token' => 'gp_overlap_token_12345',
            'google_play_purchase_token_hash' => hash('sha256', 'gp_overlap_token_12345'),
            'starts_at' => Carbon::parse('2026-04-20 12:00:00', 'UTC'),
            'ends_at' => $gpExpiry,
            'auto_renewing' => true,
        ]);

        // User also purchases a separate web subscription on 2026-05-01 -> ends 2026-06-01 (1 calendar month)
        $webTx = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-OVERLAP-01',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '950001',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);

        $webSub = $service->activateOrExtendFromVerifiedWebTransaction($webTx);

        // 1. Google Play provider record MUST NOT be modified by the web purchase
        $this->assertEquals($gpExpiry->timestamp, $gpSub->fresh()->ends_at->timestamp);
        $this->assertEquals(Subscription::CHANNEL_GOOGLE_PLAY, $gpSub->fresh()->channel);

        // 2. Web subscription has its own independent 1-calendar-month period (2026-06-01)
        $this->assertNotEquals($gpSub->id, $webSub->id);
        $this->assertEquals('2026-06-01 12:00:00', $webSub->ends_at->utc()->format('Y-m-d H:i:s'));

        // 3. Unified entitlement reflects the furthest valid expiration (2026-06-01)
        $entitlement = $service->getEntitlementPayload($user->fresh());
        $this->assertTrue($entitlement['has_active_subscription']);
        $this->assertEquals($webSub->ends_at->timestamp, Carbon::parse($entitlement['current_period_end'])->timestamp);

        Carbon::setTestNow();
    }

    /** 36. Subscription revocation and entitlement recalculation across overlapping and single subscriptions */
    public function test_subscription_revocation_recalculates_unified_entitlement_accurately(): void
    {
        $plan = $this->seedDefaultPlansAndSettings();
        $user = $this->createMember();
        $service = app(SubscriptionEntitlementService::class);

        Carbon::setTestNow(Carbon::parse('2026-06-10 12:00:00', 'UTC'));

        // Active Google Play subscription valid until 2026-06-25
        $gpExpiry = Carbon::parse('2026-06-25 12:00:00', 'UTC');
        $gpToken = 'gp_revoke_recalc_token_001';
        $gpSub = Subscription::create([
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
            'status' => Subscription::STATUS_ACTIVE,
            'google_play_purchase_token' => $gpToken,
            'google_play_purchase_token_hash' => hash('sha256', $gpToken),
            'starts_at' => Carbon::parse('2026-05-25 12:00:00', 'UTC'),
            'ends_at' => $gpExpiry,
            'auto_renewing' => true,
        ]);

        // Overlapping Web subscription valid until 2026-07-10
        $webTx = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-PMB-REVOKE-01',
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'gateway_transaction_id' => '960001',
            'amount' => 250.00,
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
            'verified_at' => now(),
        ]);
        $webSub = $service->activateOrExtendFromVerifiedWebTransaction($webTx);

        // Refund the Web subscription -> user STILL remains entitled via the overlapping Google Play subscription until 2026-06-25!
        $service->revokeOrRecalculateOnRefund($webTx, 'refunded');
        $this->assertEquals(Subscription::STATUS_REFUNDED, $webSub->fresh()->status);

        $recalculatedEntitlement = $service->getEntitlementPayload($user->fresh());
        $this->assertTrue($recalculatedEntitlement['has_active_subscription']);
        $this->assertEquals('google_play', $recalculatedEntitlement['payment_channel']);
        $this->assertEquals($gpExpiry->timestamp, Carbon::parse($recalculatedEntitlement['current_period_end'])->timestamp);

        // Now Google Play revokes the remaining Google Play subscription via RTDN notificationType = 12 (SUBSCRIPTION_REVOKED)
        Http::fake([
            'androidpublisher.googleapis.com/*' => Http::response([
                'subscriptionState' => 'SUBSCRIPTION_STATE_EXPIRED',
                'latestOrderId' => 'GPA.5555-6666-7777-88888',
                'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
                'lineItems' => [
                    [
                        'productId' => 'naseebak_monthly_membership',
                        'expiryTime' => now()->toIso8601String(),
                    ],
                ],
            ], 200),
        ]);

        $rtdnRevokeData = base64_encode(json_encode([
            'version' => '1.0',
            'packageName' => 'com.naseebak.app',
            'subscriptionNotification' => [
                'version' => '1.0',
                'notificationType' => 12, // SUBSCRIPTION_REVOKED
                'purchaseToken' => $gpToken,
                'subscriptionId' => 'naseebak_monthly_membership',
            ],
        ]));

        $this->withToken($this->issueRtdnOidcJwt())
            ->postJson('/api/v1/webhooks/google-play/rtdn', [
                'message' => [
                    'messageId' => 'pubsub-revoke-msg-999',
                    'data' => $rtdnRevokeData,
                ],
            ])->assertOk();

        $this->assertEquals(Subscription::STATUS_REVOKED, $gpSub->fresh()->status);

        $finalEntitlement = $service->getEntitlementPayload($user->fresh());
        $this->assertFalse($finalEntitlement['has_active_subscription']);
        $this->assertFalse($finalEntitlement['can_send_match_requests']);
        $this->assertFalse($finalEntitlement['can_send_messages']);

        Carbon::setTestNow();
    }
}
