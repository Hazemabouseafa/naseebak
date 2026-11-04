<?php

namespace Tests\Feature;

use App\Mail\AccountDeletionVerificationMail;
use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Services\Subscription\SubscriptionEntitlementService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;
use Tests\TestCase;

class Phase12ProductionReadinessAndSecurityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('private');
        Mail::fake();
    }

    /**
     * 1. Public legal documentation routes return 200 and contain required compliance disclosures
     */
    public function test_google_play_legal_and_compliance_pages_are_accessible(): void
    {
        // Privacy Policy
        $privacy = $this->get('/legal/privacy-policy');
        $privacy->assertStatus(200);
        $privacy->assertSee('سياسة الخصوصية');
        $privacy->assertSee('18');
        $privacy->assertSee('Google Play');

        // Terms of Service
        $terms = $this->get('/legal/terms-of-service');
        $terms->assertStatus(200);
        $terms->assertSee('شروط الخدمة');
        $terms->assertSee('18');
        $terms->assertSee('الزواج');

        // Child Safety & Anti-CSAE Standards
        $childSafety = $this->get('/legal/child-safety');
        $childSafety->assertStatus(200);
        $childSafety->assertSee('معايير سلامة الأطفال');
        $childSafety->assertSee('Zero-Tolerance');
        $childSafety->assertSee('child-safety@naseebak.app');
    }

    /**
     * 2. Unauthenticated web deletion request sends signed verification link and NEVER deletes user directly
     */
    public function test_guest_web_deletion_request_requires_email_ownership_verification(): void
    {
        $victim = $this->createActiveMember('victim@example.com');
        $photoPath = "member-photos/{$victim->id}/photo.jpg";
        Storage::disk('private')->put($photoPath, 'fake-photo-content');
        UserPhoto::create([
            'user_id' => $victim->id,
            'storage_disk' => 'private',
            'file_path' => $photoPath,
            'file_size_bytes' => 1024,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        // Malicious guest submits victim's email
        $response = $this->post('/legal/delete-account', [
            'email' => 'victim@example.com',
            'confirmation' => 'حذف',
            'acknowledge_play_store' => '1',
            'reason' => 'Malicious deletion attempt',
        ]);

        $response->assertRedirect('/legal/delete-account');
        $response->assertSessionHas('success');

        // VICTIM ACCOUNT MUST STILL EXIST! (Not deleted!)
        $this->assertDatabaseHas('users', [
            'id' => $victim->id,
            'email' => 'victim@example.com',
            'account_status' => 'active',
            'deleted_at' => null,
        ]);
        $this->assertDatabaseHas('user_photos', [
            'user_id' => $victim->id,
        ]);
        Storage::disk('private')->assertExists($photoPath);

        // Verification email was sent with a signed URL
        Mail::assertSent(AccountDeletionVerificationMail::class, function ($mail) use ($victim) {
            return $mail->hasTo($victim->email);
        });
    }

    /**
     * 3. Confirming web deletion with a valid signed link deletes the account securely
     */
    public function test_confirming_web_deletion_with_valid_signed_url_purges_user_and_photos(): void
    {
        $user = $this->createActiveMember('legit@example.com');
        $photoPath = "member-photos/{$user->id}/portrait.jpg";
        Storage::disk('private')->put($photoPath, 'portrait-binary');
        UserPhoto::create([
            'user_id' => $user->id,
            'storage_disk' => 'private',
            'file_path' => $photoPath,
            'file_size_bytes' => 1024,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        $signedGetUrl = URL::temporarySignedRoute(
            'legal.confirm_delete_account',
            now()->addMinutes(30),
            ['id' => $user->id, 'hash' => sha1('legit@example.com')]
        );

        // Landing on confirm page
        $landing = $this->get($signedGetUrl);
        $landing->assertStatus(200);
        $landing->assertSee('تأكيد حذف الحساب نهائياً');

        // Tampered signature must fail 403
        $tamperedUrl = $signedGetUrl . '&tampered=1';
        $this->get($tamperedUrl)->assertStatus(403);

        // Execute confirmed deletion with valid signature
        $signedPostUrl = URL::temporarySignedRoute(
            'legal.execute_confirmed_deletion',
            now()->addMinutes(15),
            ['id' => $user->id, 'hash' => sha1('legit@example.com')]
        );

        $confirmResponse = $this->post($signedPostUrl, [
            'confirmation' => 'حذف',
        ]);

        $confirmResponse->assertRedirect('/legal/delete-account');
        $confirmResponse->assertSessionHas('success');

        // User is now de-identified and soft-deleted
        $this->assertSoftDeleted('users', ['id' => $user->id]);
        $this->assertDatabaseMissing('user_photos', ['user_id' => $user->id]);
        Storage::disk('private')->assertMissing($photoPath);
    }

    /**
     * 4. Authenticated web user can directly delete their own account
     */
    public function test_authenticated_web_user_can_delete_own_account(): void
    {
        $user = $this->createActiveMember('webuser@example.com');

        $response = $this->actingAs($user, 'web')
            ->post('/legal/delete-account', [
                'email' => 'webuser@example.com',
                'confirmation' => 'DELETE',
                'acknowledge_play_store' => '1',
            ]);

        $response->assertRedirect('/legal/delete-account');
        $this->assertSoftDeleted('users', ['id' => $user->id]);
        $this->assertGuest('web');
    }

    /**
     * 5. Delayed payment webhook cannot reactivate or extend a deleted user's subscription
     */
    public function test_delayed_payment_webhook_cannot_reactivate_deleted_user(): void
    {
        $user = $this->createActiveMember('deleted_payer@example.com');
        $plan = $this->createSubscriptionPlan();

        // Soft-delete user
        $user->update(['account_status' => 'deleted']);
        $user->delete();

        // Create succeeded payment transaction
        $tx = PaymentTransaction::create([
            'idempotency_key' => (string) Str::uuid(),
            'internal_reference' => 'NSB-TEST-' . Str::random(10),
            'user_id' => $user->id,
            'subscription_plan_id' => $plan->id,
            'gateway' => Subscription::CHANNEL_PAYMOB,
            'amount' => '250.00',
            'amount_minor' => 25000,
            'currency' => 'EGP',
            'status' => PaymentTransaction::STATUS_SUCCEEDED,
            'signature_verified' => true,
        ]);

        $service = app(SubscriptionEntitlementService::class);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('لا يمكن تفعيل أو تجديد اشتراك لحساب تم حذفه نهائياً.');

        $service->activateOrExtendFromVerifiedWebTransaction($tx);
    }

    /**
     * 6. Orphaned photos purge command cleans up disk files for deleted users
     */
    public function test_purge_orphaned_photos_artisan_command_removes_deleted_user_directories(): void
    {
        $disk = Storage::disk('private');

        // Create active user with valid photo
        $activeUser = $this->createActiveMember('active_photos@example.com');
        $activeDir = "member-photos/{$activeUser->id}";
        $activeFile = "{$activeDir}/portrait.jpg";
        $disk->put($activeFile, 'valid');
        UserPhoto::create([
            'user_id' => $activeUser->id,
            'storage_disk' => 'private',
            'file_path' => $activeFile,
            'file_size_bytes' => 1024,
            'is_primary' => true,
            'moderation_status' => 'approved',
        ]);

        // Create orphaned directory belonging to deleted user ID 9999
        $orphanedDir = "member-photos/9999";
        $orphanedFile = "{$orphanedDir}/old.jpg";
        $disk->put($orphanedFile, 'stranded');

        $disk->assertExists($activeFile);
        $disk->assertExists($orphanedFile);

        // Run artisan cleanup command
        $exitCode = Artisan::call('naseebak:purge-orphaned-photos');
        $this->assertSame(0, $exitCode);

        // Active file preserved, orphaned directory wiped
        $disk->assertExists($activeFile);
        $disk->assertMissing($orphanedFile);
        $disk->assertMissing($orphanedDir);
    }

    private function createActiveMember(string $email): User
    {
        $user = User::create([
            'email' => $email,
            'google_sub' => 'sub_' . Str::random(16),
            'account_status' => 'active',
            'profile_completed' => true,
        ]);

        UserProfile::create([
            'user_id' => $user->id,
            'full_name' => 'عضو تجريبي',
            'gender' => 'male',
            'date_of_birth' => '1995-05-15',
            'age_years' => 31,
            'zodiac_sign' => 'Taurus',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'education_level' => 'bachelor',
            'occupation' => 'مهندس برمجيات',
            'height_cm' => 178,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['القراءة', 'الرياضة'],
            'nationality' => 'سعودي',
            'country_of_residence' => 'السعودية',
            'region' => 'الرياض',
            'bio' => 'ملف تجريبي للاختبار',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => 'approved',
        ]);

        return $user;
    }

    private function createSubscriptionPlan(): SubscriptionPlan
    {
        return SubscriptionPlan::create([
            'code' => 'monthly_membership_' . Str::random(6),
            'name_ar' => 'العضوية الشهرية',
            'description_ar' => 'وصف تجريبي',
            'duration_days' => 30,
            'google_play_product_id' => 'naseebak_monthly_membership',
            'web_price_amount' => 250.00,
            'web_price_currency' => 'EGP',
            'is_active' => true,
            'features_ar' => ['إرسال طلبات التعارف', 'المحادثة الخاصة'],
        ]);
    }
}
