<?php

namespace Tests\Feature;

use App\Filament\Resources\AdministratorResource;
use App\Filament\Resources\AdminAuditLogResource;
use App\Filament\Pages\ManageApplicationSettingsPage;
use App\Filament\Pages\ManagePaymentGatewaysPage;
use App\Filament\Pages\ManageSubscriptionPricingPage;
use App\Filament\Widgets\PlatformStatsOverviewWidget;
use App\Models\AdminAuditLog;
use App\Models\Administrator;
use App\Models\AppSetting;
use App\Models\Conversation;
use App\Models\MatchmakingRequest;
use App\Models\Message;
use App\Models\ModerationHistory;
use App\Models\PaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Models\UserReport;
use Carbon\Carbon;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminDashboardPhase4Test extends TestCase
{
    use RefreshDatabase;

    private function seedDefaultPaymentAndSubscriptionPlan(): SubscriptionPlan
    {
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
                'description_ar' => 'عضوية شهرية كاملة',
                'duration_days' => 30,
                'google_play_product_id' => 'naseebak_monthly_membership',
                'web_price_amount' => 250.00,
                'web_price_currency' => 'EGP',
                'is_active' => true,
            ]
        );
    }

    private function createAdmin(string $role = Administrator::ROLE_SUPER_ADMIN, array $overrides = []): Administrator
    {
        return Administrator::create(array_merge([
            'name' => $role === Administrator::ROLE_SUPER_ADMIN ? 'مدير النظام العام' : 'مشرف المراجعة',
            'email' => uniqid($role . '_') . '@naseebak.app',
            'password' => Hash::make('StrongAdminPass!2026'),
            'role' => $role,
            'is_active' => true,
            'mfa_enabled' => false,
        ], $overrides));
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

        $dob = $profileOverrides['date_of_birth'] ?? '1992-05-15';

        UserProfile::create(array_merge([
            'user_id' => $user->id,
            'full_name' => 'كريم عبد الله',
            'gender' => 'male',
            'date_of_birth' => $dob,
            'age_years' => Carbon::parse($dob)->age,
            'zodiac_sign' => 'الثور',
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

    /** 1. Unauthenticated access to /admin and admin operations is blocked */
    public function test_unauthenticated_access_to_admin_routes_is_blocked(): void
    {
        $member = $this->createMember();

        $this->postJson("/admin/operations/members/{$member->id}/suspend", [
            'reason' => 'محاولة بدون تسجيل دخول',
        ])->assertStatus(401)
            ->assertJsonPath('code', 'ADMIN_UNAUTHENTICATED');

        $this->putJson('/admin/operations/settings/pricing', [
            'web_monthly_price' => 300,
        ])->assertStatus(401);
    }

    /** 2. Regular member access to /admin is blocked */
    public function test_regular_member_access_to_admin_is_blocked(): void
    {
        $regularMember = $this->createMember();

        // Even if authenticated via 'sanctum' or 'web', the 'admin' guard rejects regular User models
        $this->actingAs($regularMember, 'sanctum')
            ->postJson("/admin/operations/members/{$regularMember->id}/suspend", [
                'reason' => 'محاولة عضو عادي الوصول للوحة التحكم',
            ])
            ->assertStatus(401)
            ->assertJsonPath('code', 'ADMIN_UNAUTHENTICATED');
    }

    /** 3. Suspended administrator cannot log in or perform operations */
    public function test_suspended_administrator_cannot_log_in_or_perform_actions(): void
    {
        $suspendedAdmin = $this->createAdmin(Administrator::ROLE_MODERATOR, [
            'email' => 'suspended.mod@naseebak.app',
            'password' => Hash::make('StrongAdminPass!2026'),
            'is_active' => false,
        ]);

        $this->postJson('/admin/operations/login', [
            'email' => 'suspended.mod@naseebak.app',
            'password' => 'StrongAdminPass!2026',
        ])->assertStatus(403)
            ->assertJsonPath('code', 'ADMIN_ACCOUNT_INACTIVE');

        $member = $this->createMember();
        $this->actingAs($suspendedAdmin, 'admin')
            ->postJson("/admin/operations/members/{$member->id}/suspend", [
                'reason' => 'محاولة من مشرف موقوف',
            ])
            ->assertStatus(403)
            ->assertJsonPath('code', 'ADMIN_ACCOUNT_SUSPENDED');
    }

    /** 4. Super Admin login succeeds and records audit trail */
    public function test_super_admin_login_succeeds_and_records_audit_log(): void
    {
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN, [
            'email' => 'boss@naseebak.app',
            'password' => Hash::make('StrongAdminPass!2026'),
        ]);

        $this->postJson('/admin/operations/login', [
            'email' => 'boss@naseebak.app',
            'password' => 'StrongAdminPass!2026',
        ])->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.role', Administrator::ROLE_SUPER_ADMIN);

        $this->assertDatabaseHas('admin_audit_logs', [
            'administrator_id' => $superAdmin->id,
            'action' => 'administrator.logged_in',
        ]);
    }

    /** 5. Moderator can access moderation resources */
    public function test_moderator_can_access_moderation_endpoints(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $member = $this->createMember([], ['moderation_status' => UserProfile::STATUS_PENDING]);

        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/profiles/{$member->profile->id}/moderate", [
                'status' => UserProfile::STATUS_APPROVED,
            ])
            ->assertOk()
            ->assertJsonPath('data.moderation_status', UserProfile::STATUS_APPROVED);
    }

    /** 6. Moderator cannot access payment gateway settings */
    public function test_moderator_cannot_access_payment_gateway_settings(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);

        $this->actingAs($moderator, 'admin');
        $this->assertFalse(ManagePaymentGatewaysPage::canAccess());

        $this->actingAs($moderator, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'sha7nawy',
            ])
            ->assertStatus(403)
            ->assertJsonPath('code', 'ADMIN_ROLE_FORBIDDEN');
    }

    /** 7. Moderator cannot access subscription pricing settings */
    public function test_moderator_cannot_access_subscription_pricing_settings(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);

        $this->actingAs($moderator, 'admin');
        $this->assertFalse(ManageSubscriptionPricingPage::canAccess());

        $this->actingAs($moderator, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => 300.00,
            ])
            ->assertStatus(403)
            ->assertJsonPath('code', 'ADMIN_ROLE_FORBIDDEN');
    }

    /** 8. Moderator cannot access administrator management */
    public function test_moderator_cannot_access_administrator_management(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);

        $this->actingAs($moderator, 'admin');
        $this->assertFalse(AdministratorResource::canAccess());

        $this->actingAs($moderator, 'admin')
            ->postJson('/admin/operations/administrators', [
                'name' => 'مشرف جديد',
                'email' => 'new.mod@naseebak.app',
                'password' => 'StrongAdminPass!2026',
                'role' => Administrator::ROLE_MODERATOR,
            ])
            ->assertStatus(403)
            ->assertJsonPath('code', 'ADMIN_ROLE_FORBIDDEN');
    }

    /** 9. Moderator cannot modify application settings */
    public function test_moderator_cannot_modify_application_settings(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);

        $this->actingAs($moderator, 'admin');
        $this->assertFalse(ManageApplicationSettingsPage::canAccess());

        $this->actingAs($moderator, 'admin')
            ->putJson('/admin/operations/settings/application', [
                'app_display_name' => 'نصيبك',
                'registration_enabled' => true,
                'require_profile_moderation' => true,
                'maintenance_mode' => false,
                'support_email' => 'support@naseebak.app',
                'privacy_policy_url' => 'https://api.example.com/privacy',
                'terms_of_service_url' => 'https://api.example.com/terms',
                'account_deletion_url' => 'https://api.example.com/delete',
            ])
            ->assertStatus(403)
            ->assertJsonPath('code', 'ADMIN_ROLE_FORBIDDEN');
    }

    /** 10. Approving a pending profile makes it eligible for member discovery */
    public function test_approving_pending_profile_makes_it_eligible_for_member_discovery(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $viewer = $this->createMember([], ['gender' => 'female', 'full_name' => 'سارة أحمد']);
        $pendingCandidate = $this->createMember([], [
            'gender' => 'male',
            'full_name' => 'محمود حسن',
            'moderation_status' => UserProfile::STATUS_PENDING,
        ]);

        // Before approval: candidate does NOT appear in member search
        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');

        // Moderator approves profile
        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/profiles/{$pendingCandidate->profile->id}/moderate", [
                'status' => UserProfile::STATUS_APPROVED,
            ])
            ->assertOk();

        // After approval: candidate immediately appears in member search
        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(1, 'data.members')
            ->assertJsonPath('data.members.0.user_id', $pendingCandidate->id);

        $this->assertDatabaseHas('moderation_histories', [
            'administrator_id' => $moderator->id,
            'target_type' => UserProfile::class,
            'target_id' => $pendingCandidate->profile->id,
            'new_status' => UserProfile::STATUS_APPROVED,
        ]);
    }

    /** 11. Rejecting a profile hides it from member discovery */
    public function test_rejecting_profile_requires_reason_and_hides_it_from_member_discovery(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $viewer = $this->createMember([], ['gender' => 'female']);
        $candidate = $this->createMember([], [
            'gender' => 'male',
            'moderation_status' => UserProfile::STATUS_APPROVED,
        ]);

        // Rejection without reason is rejected with 422
        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/profiles/{$candidate->profile->id}/moderate", [
                'status' => UserProfile::STATUS_REJECTED,
                'reason' => '',
            ])
            ->assertStatus(422);

        // Rejection with valid reason succeeds
        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/profiles/{$candidate->profile->id}/moderate", [
                'status' => UserProfile::STATUS_REJECTED,
                'reason' => 'بيانات غير حقيقية ومخالفة لشروط الاستخدام',
            ])
            ->assertOk()
            ->assertJsonPath('data.moderation_status', UserProfile::STATUS_REJECTED);

        // Candidate is now hidden from discovery/search
        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');
    }

    /** 12. Suspending a member immediately blocks member API access and hides from discovery */
    public function test_suspending_member_immediately_blocks_api_access_and_hides_from_search(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $viewer = $this->createMember([], ['gender' => 'female']);
        $targetMember = $this->createMember([], ['gender' => 'male']);

        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/members/{$targetMember->id}/suspend", [
                'reason' => 'إرسال رسائل مزعجة ومخالفة قواعد المنصة',
            ])
            ->assertOk()
            ->assertJsonPath('data.account_status', 'suspended');

        // Suspended member is blocked by EnsureAccountIsActive middleware on API
        $this->actingAs($targetMember->fresh(), 'sanctum')
            ->getJson('/api/v1/discovery')
            ->assertStatus(403);

        // Suspended member is hidden from other members' search results
        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');
    }

    /** 13. Restoring a suspended member restores account status */
    public function test_restoring_suspended_member_restores_active_status_and_api_access(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $member = $this->createMember([
            'account_status' => 'suspended',
            'suspension_reason' => 'إيقاف مؤقت للمراجعة',
        ]);

        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/members/{$member->id}/restore", [
                'notes' => 'تم التحقق من الحساب وإعادة التفعيل',
            ])
            ->assertOk()
            ->assertJsonPath('data.account_status', 'active');

        $this->actingAs($member->fresh(), 'sanctum')
            ->getJson('/api/v1/discovery')
            ->assertOk();
    }

    /** 14. Suspending a member requires a reason */
    public function test_suspending_member_requires_a_valid_reason(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $member = $this->createMember();

        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/members/{$member->id}/suspend", [
                'reason' => '',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['reason']);

        $this->assertEquals('active', $member->fresh()->account_status);
    }

    /** 15. Photo moderation approval and rejection work correctly */
    public function test_photo_moderation_approval_and_rejection_control_member_visibility(): void
    {
        Storage::fake('private');
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $owner = $this->createMember([], ['gender' => 'male', 'photo_privacy' => 'public']);
        $viewer = $this->createMember([], ['gender' => 'female']);

        $path = "member-photos/{$owner->id}/" . Str::uuid() . ".jpg";
        Storage::disk('private')->put($path, 'fake-jpeg-bytes');

        $photo = UserPhoto::create([
            'user_id' => $owner->id,
            'storage_disk' => 'private',
            'file_path' => $path,
            'mime_type' => 'image/jpeg',
            'file_size_bytes' => 15,
            'is_primary' => true,
            'moderation_status' => UserPhoto::STATUS_PENDING,
        ]);

        // Unapproved photo is hidden from other members even when photo_privacy is public
        $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertStatus(403);

        // Moderator can stream the private photo for moderation review
        $this->actingAs($moderator, 'admin')
            ->get("/admin/operations/photos/{$photo->id}/stream")
            ->assertOk();

        // Moderator approves the photo -> now visible to other members
        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/photos/{$photo->id}/moderate", [
                'action' => UserPhoto::STATUS_APPROVED,
            ])
            ->assertOk()
            ->assertJsonPath('data.moderation_status', UserPhoto::STATUS_APPROVED);

        $this->actingAs($viewer, 'sanctum')
            ->get("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertOk();

        // Moderator rejects the photo with reason -> immediately hidden from other members again
        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/photos/{$photo->id}/moderate", [
                'action' => UserPhoto::STATUS_REJECTED,
                'reason' => 'الصورة غير واضحة ولا تخص صاحب الحساب',
            ])
            ->assertOk()
            ->assertJsonPath('data.moderation_status', UserPhoto::STATUS_REJECTED);

        $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/profile/photos/{$photo->id}/stream")
            ->assertStatus(403);
    }

    /** 16. Report status transitions work and are audited (without exposing private chat messages) */
    public function test_report_status_transitions_work_and_are_audited_without_exposing_private_messages(): void
    {
        $moderator = $this->createAdmin(Administrator::ROLE_MODERATOR);
        $reporter = $this->createMember([], ['gender' => 'female', 'full_name' => 'مريم سامي']);
        $offender = $this->createMember([], ['gender' => 'male', 'full_name' => 'طارق نبيل']);

        $matchRequest = MatchmakingRequest::create([
            'sender_id' => $offender->id,
            'recipient_id' => $reporter->id,
            'status' => 'accepted',
            'responded_at' => now(),
        ]);

        $conversation = Conversation::create([
            'matchmaking_request_id' => $matchRequest->id,
            'status' => 'active',
        ]);

        Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $offender->id,
            'body' => 'نص رسالة خاصة سرية لا يجب أن يظهر في استجابة إدارة البلاغات',
        ]);

        $report = UserReport::create([
            'reporter_id' => $reporter->id,
            'reported_user_id' => $offender->id,
            'conversation_id' => $conversation->id,
            'reason_category' => 'harassment',
            'details' => 'إساءة لفظية متكررة',
            'status' => UserReport::STATUS_PENDING,
        ]);

        // Transition to under_review
        $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/reports/{$report->id}/handle", [
                'status' => UserReport::STATUS_UNDER_REVIEW,
                'resolution_notes' => 'جاري فحص سجل البلاغات السابقة للعضو',
            ])
            ->assertOk()
            ->assertJsonPath('data.status', UserReport::STATUS_UNDER_REVIEW);

        // Transition to resolved + suspend offending member
        $response = $this->actingAs($moderator, 'admin')
            ->postJson("/admin/operations/reports/{$report->id}/handle", [
                'status' => UserReport::STATUS_RESOLVED,
                'resolution_notes' => 'ثبتت المخالفة وتم إيقاف حساب العضو المسيء',
                'suspend_reported_member' => true,
            ])
            ->assertOk()
            ->assertJsonPath('data.status', UserReport::STATUS_RESOLVED);

        // Verify private message content is never leaked in report handling response
        $this->assertStringNotContainsString(
            'نص رسالة خاصة سرية',
            $response->getContent()
        );

        $this->assertEquals('suspended', $offender->fresh()->account_status);
        $this->assertDatabaseHas('admin_audit_logs', [
            'administrator_id' => $moderator->id,
            'action' => 'report.resolved',
            'target_id' => $report->id,
        ]);
    }

    /** 17. Subscription price update validates positive decimal input */
    public function test_subscription_price_update_validates_positive_decimal_input(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        // Negative or zero prices are rejected
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => 0,
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['web_monthly_price']);

        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => -150,
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['web_monthly_price']);

        // More than 2 decimal places rejected
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => '299.999',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['web_monthly_price']);

        // Valid positive 2-decimal price succeeds
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => '325.50',
                'reason' => 'تحديث السعر الشهري للربع الجديد',
            ])
            ->assertOk()
            ->assertJsonPath('data.web_monthly_price', '325.50');

        $this->assertEquals('325.50', (string) PaymentSetting::first()->web_monthly_price);
        $this->assertEquals('325.50', (string) SubscriptionPlan::where('code', 'monthly_membership')->first()->web_price_amount);
    }

    /** 18. Subscription price update creates an audit log entry */
    public function test_subscription_price_update_creates_audit_log_entry(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/pricing', [
                'web_monthly_price' => '280.00',
                'reason' => 'تعديل تسعير باقة الويب',
            ])
            ->assertOk();

        $audit = AdminAuditLog::where('action', 'subscription_pricing.updated')->latest('id')->first();
        $this->assertNotNull($audit);
        $this->assertEquals($superAdmin->id, $audit->administrator_id);
        $this->assertEquals('250.00', $audit->previous_values['web_monthly_price']);
        $this->assertEquals('280.00', $audit->new_values['web_monthly_price']);
    }

    /** 19. Active web payment gateway switches atomically between paymob and sha7nawy */
    public function test_active_web_payment_gateway_switches_atomically_between_paymob_and_sha7nawy(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $this->assertEquals('paymob', PaymentSetting::first()->active_web_payment_gateway);

        // Switch to sha7nawy
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'sha7nawy',
            ])
            ->assertOk()
            ->assertJsonPath('data.active_web_payment_gateway', 'sha7nawy');

        $this->assertEquals('sha7nawy', PaymentSetting::first()->active_web_payment_gateway);

        // Switch back to paymob
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'paymob',
            ])
            ->assertOk()
            ->assertJsonPath('data.active_web_payment_gateway', 'paymob');

        $this->assertEquals('paymob', PaymentSetting::first()->active_web_payment_gateway);
    }

    /** 20. Invalid payment gateway values are rejected */
    public function test_invalid_or_unconfigured_payment_gateway_values_are_rejected(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        // Unsupported provider name rejected
        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'stripe',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['active_web_payment_gateway']);

        // Unconfigured sha7nawy provider rejected safely without changing active gateway
        PaymentSetting::first()->update([
            'active_web_payment_gateway' => 'paymob',
            'sha7nawy_configured' => false,
            'sha7nawy_integration_status' => 'pending_credentials',
        ]);

        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'sha7nawy',
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'GATEWAY_SWITCH_REJECTED');

        $this->assertEquals('paymob', PaymentSetting::first()->active_web_payment_gateway);
    }

    /** 21. Payment gateway switch creates an audit log entry */
    public function test_payment_gateway_switch_creates_audit_log_entry(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $this->actingAs($superAdmin, 'admin')
            ->putJson('/admin/operations/settings/payment-gateway', [
                'active_web_payment_gateway' => 'sha7nawy',
            ])
            ->assertOk();

        $audit = AdminAuditLog::where('action', 'payment_gateway.switched')->latest('id')->first();
        $this->assertNotNull($audit);
        $this->assertEquals($superAdmin->id, $audit->administrator_id);
        $this->assertEquals('paymob', $audit->previous_values['active_web_payment_gateway']);
        $this->assertEquals('sha7nawy', $audit->new_values['active_web_payment_gateway']);
    }

    /** 22. Audit log records cannot be edited or deleted */
    public function test_audit_log_records_are_append_only_and_cannot_be_edited_or_deleted(): void
    {
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $log = AdminAuditLog::create([
            'administrator_id' => $superAdmin->id,
            'action' => 'system.test_event',
            'justification' => 'اختبار عدم قابلية التعديل أو الحذف',
            'created_at' => now(),
        ]);

        $this->assertFalse(AdminAuditLogResource::canCreate());
        $this->assertFalse(AdminAuditLogResource::canEdit($log));
        $this->assertFalse(AdminAuditLogResource::canDelete($log));

        $this->expectException(DomainException::class);
        $log->update(['justification' => 'محاولة تزوير السجل']);
    }

    public function test_audit_log_record_deletion_throws_domain_exception(): void
    {
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $log = AdminAuditLog::create([
            'administrator_id' => $superAdmin->id,
            'action' => 'system.test_delete',
            'justification' => 'اختبار منع الحذف',
            'created_at' => now(),
        ]);

        $this->expectException(DomainException::class);
        $log->delete();
    }

    /** 23. Final active Super Admin cannot be deleted or demoted */
    public function test_final_active_super_admin_cannot_be_deleted_suspended_or_demoted(): void
    {
        $soleSuperAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        // Attempt to demote sole Super Admin via HTTP endpoint
        $this->actingAs($soleSuperAdmin, 'admin')
            ->patchJson("/admin/operations/administrators/{$soleSuperAdmin->id}", [
                'role' => Administrator::ROLE_MODERATOR,
                'is_active' => true,
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'FINAL_SUPER_ADMIN_PROTECTED');

        // Attempt to suspend sole Super Admin via HTTP endpoint
        $this->actingAs($soleSuperAdmin, 'admin')
            ->patchJson("/admin/operations/administrators/{$soleSuperAdmin->id}", [
                'role' => Administrator::ROLE_SUPER_ADMIN,
                'is_active' => false,
            ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'FINAL_SUPER_ADMIN_PROTECTED');

        // Attempt direct model deletion throws DomainException
        $this->expectException(DomainException::class);
        $soleSuperAdmin->delete();
    }

    /** 24. Dashboard statistics match database state */
    public function test_dashboard_statistics_accurately_match_postgresql_database_state(): void
    {
        $plan = $this->seedDefaultPaymentAndSubscriptionPlan();

        // Create 2 active approved members and 1 suspended pending member
        $member1 = $this->createMember([], ['gender' => 'male', 'moderation_status' => UserProfile::STATUS_APPROVED]);
        $member2 = $this->createMember([], ['gender' => 'female', 'moderation_status' => UserProfile::STATUS_APPROVED]);
        $member3 = $this->createMember(
            ['account_status' => 'suspended'],
            ['gender' => 'male', 'moderation_status' => UserProfile::STATUS_PENDING]
        );

        // Create 1 active subscription and 1 expired subscription
        $activeSub = Subscription::create([
            'user_id' => $member1->id,
            'subscription_plan_id' => $plan->id,
            'channel' => 'paymob',
            'status' => 'active',
            'starts_at' => now()->subDays(5),
            'ends_at' => now()->addDays(25),
        ]);

        Subscription::create([
            'user_id' => $member2->id,
            'subscription_plan_id' => $plan->id,
            'channel' => 'sha7nawy',
            'status' => 'expired',
            'starts_at' => now()->subDays(40),
            'ends_at' => now()->subDays(10),
        ]);

        // Create 1 verified succeeded payment (250 EGP) and 1 unverified/pending payment (500 EGP - must be excluded!)
        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'user_id' => $member1->id,
            'subscription_id' => $activeSub->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => 'paymob',
            'gateway_transaction_id' => 'PMB-1001',
            'amount' => 250.00,
            'currency' => 'EGP',
            'status' => 'succeeded',
            'signature_verified' => true,
            'verified_at' => now(),
        ]);

        PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'user_id' => $member2->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => 'paymob',
            'gateway_transaction_id' => 'PMB-UNVERIFIED-1002',
            'amount' => 500.00,
            'currency' => 'EGP',
            'status' => 'succeeded',
            'signature_verified' => false,
        ]);

        // Create 1 open report and 1 resolved report
        UserReport::create([
            'reporter_id' => $member2->id,
            'reported_user_id' => $member3->id,
            'reason_category' => 'fake_profile',
            'details' => 'بيانات غير صحيحة',
            'status' => UserReport::STATUS_PENDING,
        ]);

        UserReport::create([
            'reporter_id' => $member1->id,
            'reported_user_id' => $member3->id,
            'reason_category' => 'other',
            'details' => 'بلاغ قديم تم حله',
            'status' => UserReport::STATUS_RESOLVED,
        ]);

        $metrics = PlatformStatsOverviewWidget::computeMetrics();

        $this->assertEquals(3, $metrics['total_members']);
        $this->assertEquals(3, $metrics['new_members_7d']);
        $this->assertEquals(2, $metrics['active_members']);
        $this->assertEquals(1, $metrics['pending_profiles']);
        $this->assertEquals(1, $metrics['active_subscriptions']);
        $this->assertEquals(1, $metrics['expired_subscriptions']);
        $this->assertEquals(250.00, $metrics['verified_payments_total']);
        $this->assertEquals(1, $metrics['open_reports']);
    }

    /** 25. Admin can manually activate, extend, and revoke member subscriptions from Filament Dashboard */
    public function test_admin_can_manually_activate_extend_and_revoke_member_subscription(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);
        $member = $this->createMember([], ['gender' => 'male']);

        $this->assertFalse($member->hasActiveSubscription());

        $service = app(\App\Services\Admin\AdminModerationService::class);
        $sub = $service->activateManualSubscription(
            actor: $superAdmin,
            member: $member,
            durationDays: 30,
            notes: 'تفعيل اشتراك يدوي من لوحة التحكم'
        );

        $this->assertEquals(Subscription::STATUS_ACTIVE, $sub->status);
        $this->assertEquals(Subscription::CHANNEL_ADMIN_MANUAL, $sub->channel);
        $this->assertTrue($member->fresh()->hasActiveSubscription());

        // Extend by another 60 days
        $extended = $service->activateManualSubscription(
            actor: $superAdmin,
            member: $member->fresh(),
            durationDays: 60,
            notes: 'تمديد إضافي'
        );
        $this->assertEquals($sub->id, $extended->id);
        $this->assertTrue($extended->ends_at->greaterThan(now()->addDays(85)));

        // Revoke subscription
        $revokedCount = $service->revokeMemberSubscriptions(
            actor: $superAdmin,
            member: $member->fresh(),
            reason: 'إلغاء الاشتراك يدوياً'
        );
        $this->assertEquals(1, $revokedCount);
        $this->assertFalse($member->fresh()->hasActiveSubscription());
    }

    /** 26. Admin can delete a member from the Filament Dashboard and audit log is recorded */
    public function test_admin_can_delete_member_from_dashboard_and_records_audit_log(): void
    {
        $this->seedDefaultPaymentAndSubscriptionPlan();
        $superAdmin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);
        $viewer = $this->createMember([], ['gender' => 'female', 'full_name' => 'هدى محمود']);
        $targetMember = $this->createMember([
            'google_sub' => 'google-sub-to-delete-999',
            'email' => 'delete.me@example.com',
        ], [
            'gender' => 'male',
            'full_name' => 'رامي عادل',
            'moderation_status' => UserProfile::STATUS_APPROVED,
        ]);

        $this->actingAs($superAdmin, 'admin');
        $this->assertTrue(\App\Filament\Resources\MemberResource::canDelete($targetMember));

        // Before deletion: member appears in MemberResource query and in discovery search
        $this->assertEquals(
            1,
            \App\Filament\Resources\MemberResource::getEloquentQuery()->where('id', $targetMember->id)->count()
        );

        // Delete member via admin operation endpoint
        $this->actingAs($superAdmin, 'admin')
            ->deleteJson("/admin/operations/members/{$targetMember->id}", [
                'reason' => 'حذف حساب تجريبي من لوحة التحكم',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.status', 'deleted')
            ->assertJsonPath('data.user_id', $targetMember->id);

        // Verify member is soft-deleted and hidden from Filament MemberResource table query
        $this->assertSoftDeleted('users', ['id' => $targetMember->id]);
        $this->assertEquals(
            0,
            \App\Filament\Resources\MemberResource::getEloquentQuery()->where('id', $targetMember->id)->count()
        );

        // Verify google_sub and email were anonymized so the Google account is freed
        $deletedRow = User::withTrashed()->find($targetMember->id);
        $this->assertNotNull($deletedRow);
        $this->assertEquals('deleted', $deletedRow->account_status);
        $this->assertNotEquals('google-sub-to-delete-999', $deletedRow->google_sub);
        $this->assertNotEquals('delete.me@example.com', $deletedRow->email);

        // Verify member no longer appears in search results for other members
        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/members/search')
            ->assertOk()
            ->assertJsonCount(0, 'data.members');

        // Verify immutable AdminAuditLog entry was recorded
        $this->assertDatabaseHas('admin_audit_logs', [
            'administrator_id' => $superAdmin->id,
            'action' => 'member.deleted',
            'target_id' => $targetMember->id,
            'justification' => 'حذف حساب تجريبي من لوحة التحكم',
        ]);
    }
}
