<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Administrator;
use App\Models\AppSetting;
use App\Models\PaymentSetting;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Models\UserReport;
use App\Policies\AdministratorPolicy;
use App\Services\Admin\AdminAuditService;
use App\Services\Admin\AdminModerationService;
use App\Services\Profile\SecurePhotoStorageService;
use DomainException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\Rules\Password;
use InvalidArgumentException;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminOperationsController extends Controller
{
    public function __construct(
        private readonly AdminModerationService $moderationService,
        private readonly AdminAuditService $auditService,
        private readonly SecurePhotoStorageService $photoStorageService,
        private readonly AdministratorPolicy $administratorPolicy,
    ) {}

    /**
     * Authenticates an administrator with strict rate limiting (5 attempts per minute per email+IP).
     */
    public function login(Request $request): JsonResponse|RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $throttleKey = 'admin-login:' . strtolower($credentials['email']) . '|' . $request->ip();

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            return response()->json([
                'status' => 'error',
                'code' => 'TOO_MANY_LOGIN_ATTEMPTS',
                'message' => "تم تجاوز الحد المسموح لمحاولات تسجيل الدخول. يرجى المحاولة بعد {$seconds} ثانية.",
            ], 429);
        }

        /** @var ?Administrator $admin */
        $admin = Administrator::where('email', strtolower(trim($credentials['email'])))->first();

        if (!$admin || !Hash::check($credentials['password'], $admin->password)) {
            RateLimiter::hit($throttleKey, 60);

            return response()->json([
                'status' => 'error',
                'code' => 'INVALID_ADMIN_CREDENTIALS',
                'message' => 'بيانات الدخول غير صحيحة.',
            ], 422);
        }

        if (!$admin->is_active) {
            return response()->json([
                'status' => 'error',
                'code' => 'ADMIN_ACCOUNT_INACTIVE',
                'message' => 'حساب المدير موقوف حالياً.',
            ], 403);
        }

        RateLimiter::clear($throttleKey);

        Auth::guard('admin')->login($admin);
        if ($request->hasSession()) {
            $request->session()->regenerate();
            $request->session()->put('admin_mfa_verified', !$admin->mfa_enabled);
        }

        $admin->update([
            'last_login_at' => now(),
            'last_login_ip' => $request->ip(),
        ]);

        $this->auditService->record(
            actor: $admin,
            action: 'administrator.logged_in',
            target: $admin,
            reason: 'تسجيل دخول ناجح إلى لوحة تحكم نصيبك',
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'id' => $admin->id,
                'name' => $admin->name,
                'email' => $admin->email,
                'role' => $admin->role,
                'mfa_required' => $admin->mfa_enabled,
            ],
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        /** @var ?Administrator $admin */
        $admin = Auth::guard('admin')->user();
        if ($admin) {
            $this->auditService->record(
                actor: $admin,
                action: 'administrator.logged_out',
                target: $admin,
                reason: 'تسجيل خروج من لوحة تحكم نصيبك',
                ipAddress: $request->ip()
            );
        }

        Auth::guard('admin')->logout();
        if ($request->hasSession()) {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }

        return response()->json(['status' => 'success']);
    }

    /**
     * Streams a member's private profile photo exclusively to authenticated active administrators/moderators.
     */
    public function streamPhotoForModeration(UserPhoto $photo): StreamedResponse|JsonResponse
    {
        if (!$this->photoStorageService->exists($photo)) {
            return response()->json([
                'status' => 'error',
                'code' => 'PHOTO_FILE_MISSING',
                'message' => 'ملف الصورة غير موجود في وحدة التخزين الخاصة.',
            ], 404);
        }

        return $this->photoStorageService->streamPhoto($photo);
    }

    /**
     * Suspends a member account with mandatory reason.
     */
    public function suspendMember(Request $request, User $member): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'min:5', 'max:500'],
        ], [
            'reason.required' => 'يجب إدخال سبب واضح لإيقاف حساب العضو.',
            'reason.min' => 'سبب الإيقاف يجب ألا يقل عن 5 أحرف.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        $updated = $this->moderationService->suspendMember(
            actor: $actor,
            member: $member,
            reason: $validated['reason'],
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'user_id' => $updated->id,
                'account_status' => $updated->account_status,
                'suspension_reason' => $updated->suspension_reason,
            ],
        ]);
    }

    /**
     * Restores a suspended member account.
     */
    public function restoreMember(Request $request, User $member): JsonResponse
    {
        $validated = $request->validate([
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        $updated = $this->moderationService->restoreMember(
            actor: $actor,
            member: $member,
            notes: $validated['notes'] ?? null,
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'user_id' => $updated->id,
                'account_status' => $updated->account_status,
            ],
        ]);
    }

    /**
     * Deletes a member account from the platform and records an audit log entry.
     */
    public function deleteMember(Request $request, User $member): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        $result = $this->moderationService->deleteMember(
            actor: $actor,
            member: $member,
            reason: $validated['reason'] ?? null,
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => $result,
        ]);
    }

    /**
     * Moderates a member profile ('approved', 'rejected', 'correction_requested').
     */
    public function moderateProfile(Request $request, UserProfile $profile): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:approved,rejected,correction_requested'],
            'reason' => ['required_if:status,rejected,correction_requested', 'nullable', 'string', 'min:4', 'max:500'],
        ], [
            'reason.required_if' => 'يجب إدخال سبب الرفض أو الملاحظات المطلوبة لتعديل الملف الشخصي.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        $updated = $this->moderationService->moderateProfile(
            actor: $actor,
            profile: $profile,
            newStatus: $validated['status'],
            reason: $validated['reason'] ?? null,
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'profile_id' => $updated->id,
                'moderation_status' => $updated->moderation_status,
                'moderation_notes' => $updated->moderation_notes,
            ],
        ]);
    }

    /**
     * Moderates a member photo ('approved', 'rejected') or removes a prohibited image ('remove').
     */
    public function moderatePhoto(Request $request, UserPhoto $photo): JsonResponse
    {
        $validated = $request->validate([
            'action' => ['required', 'string', 'in:approved,rejected,remove'],
            'reason' => ['required_if:action,rejected,remove', 'nullable', 'string', 'min:4', 'max:500'],
        ], [
            'reason.required_if' => 'يجب إدخال سبب رفض الصورة أو حذفها.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        if ($validated['action'] === 'remove') {
            $this->moderationService->removeProhibitedPhoto(
                actor: $actor,
                photo: $photo,
                reason: $validated['reason'],
                ipAddress: $request->ip()
            );

            return response()->json([
                'status' => 'success',
                'data' => ['removed' => true],
            ]);
        }

        $updated = $this->moderationService->moderatePhoto(
            actor: $actor,
            photo: $photo,
            newStatus: $validated['action'],
            reason: $validated['reason'] ?? null,
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'photo_id' => $updated->id,
                'moderation_status' => $updated->moderation_status,
                'moderation_notes' => $updated->moderation_notes,
            ],
        ]);
    }

    /**
     * Reviews a user report without exposing private chat message bodies.
     */
    public function handleReport(Request $request, UserReport $report): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:under_review,resolved,rejected'],
            'resolution_notes' => ['required', 'string', 'min:4', 'max:1000'],
            'suspend_reported_member' => ['sometimes', 'boolean'],
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        $updated = $this->moderationService->handleReport(
            actor: $actor,
            report: $report,
            newStatus: $validated['status'],
            resolutionNotes: $validated['resolution_notes'],
            suspendReportedMember: (bool) ($validated['suspend_reported_member'] ?? false),
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'report_id' => $updated->id,
                'status' => $updated->status,
                'resolution_notes' => $updated->resolution_notes,
                'reviewed_by_admin_id' => $updated->reviewed_by_admin_id,
            ],
        ]);
    }

    /**
     * Updates monthly web subscription pricing in EGP (Super Admin only).
     */
    public function updateSubscriptionPricing(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'web_monthly_price' => ['required', 'numeric', 'gt:0', 'regex:/^\d+(\.\d{1,2})?$/'],
            'reason' => ['nullable', 'string', 'max:500'],
        ], [
            'web_monthly_price.gt' => 'سعر الاشتراك الشهري يجب أن يكون أكبر من الصفر.',
            'web_monthly_price.regex' => 'سعر الاشتراك الشهري يجب أن يكون رقماً صالحاً بحد أقصى منزلتين عشريتين.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();
        $setting = PaymentSetting::firstOrFail();

        $setting->updateMonthlyWebPriceAtomically(
            newPrice: $validated['web_monthly_price'],
            adminId: $actor->id,
            ipAddress: $request->ip(),
            reason: $validated['reason'] ?? null
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'web_monthly_price' => (string) $setting->web_monthly_price,
                'web_currency' => $setting->web_currency,
                'subscription_duration_days' => $setting->subscription_duration_days,
            ],
        ]);
    }

    /**
     * Updates a specific subscription plan's price, display title, or active status (Super Admin only).
     */
    public function updatePlanPricing(Request $request, string $planCode): JsonResponse
    {
        if (!in_array($planCode, ['monthly_membership', 'quarterly_membership'], true)) {
            return response()->json([
                'status' => 'error',
                'code' => 'UNSUPPORTED_PLAN_CODE',
                'message' => 'رمز الباقة غير مدعوم للتعديل.',
            ], 422);
        }

        $validated = $request->validate([
            'web_price_amount' => ['required', 'numeric', 'gt:0', 'regex:/^\d+(\.\d{1,2})?$/'],
            'name_ar' => ['nullable', 'string', 'max:80'],
            'is_active' => ['nullable', 'boolean'],
            'reason' => ['nullable', 'string', 'max:500'],
        ], [
            'web_price_amount.gt' => 'سعر الباقة يجب أن يكون أكبر من الصفر.',
            'web_price_amount.regex' => 'سعر الباقة يجب أن يكون رقماً صالحاً بحد أقصى منزلتين عشريتين.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();
        $setting = PaymentSetting::firstOrFail();

        $plan = $setting->updatePlanPricingAtomically(
            planCode: $planCode,
            newPrice: $validated['web_price_amount'],
            nameAr: $validated['name_ar'] ?? null,
            isActive: array_key_exists('is_active', $validated) ? (bool) $validated['is_active'] : null,
            adminId: $actor->id,
            ipAddress: $request->ip(),
            reason: $validated['reason'] ?? null
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'code' => $plan->code,
                'name_ar' => $plan->name_ar,
                'duration_months' => $plan->effectiveMonths(),
                'web_price_amount' => (string) $plan->web_price_amount,
                'price_minor' => $plan->effectivePriceMinor(),
                'currency' => $plan->web_price_currency,
                'is_active' => (bool) $plan->is_active,
            ],
        ]);
    }

    /**
     * Atomically switches the single active web payment gateway ('paymob' or 'sha7nawy') (Super Admin only).
     */
    public function switchPaymentGateway(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'active_web_payment_gateway' => ['required', 'string', 'in:paymob,sha7nawy'],
        ], [
            'active_web_payment_gateway.in' => 'بوابة الدفع المختارة غير مدعومة. القيم المسموحة: paymob أو sha7nawy فقط.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();
        $setting = PaymentSetting::firstOrFail();

        try {
            $setting->switchActiveGatewayAtomically(
                newGateway: $validated['active_web_payment_gateway'],
                actorId: $actor->id,
                ipAddress: $request->ip(),
                isAdministratorModel: true
            );
        } catch (DomainException|InvalidArgumentException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'GATEWAY_SWITCH_REJECTED',
                'message' => $e->getMessage(),
            ], 422);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'active_web_payment_gateway' => $setting->active_web_payment_gateway,
                'updated_by_admin_id' => $setting->updated_by_admin_id,
            ],
        ]);
    }

    /**
     * Updates general application settings (Super Admin only).
     * Never allows lowering minimum age below 18 or disabling Google Sign-In.
     */
    public function updateAppSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'app_display_name' => ['required', 'string', 'max:80'],
            'general_announcement_ar' => ['nullable', 'string', 'max:500'],
            'registration_enabled' => ['required', 'boolean'],
            'require_profile_moderation' => ['required', 'boolean'],
            'maintenance_mode' => ['required', 'boolean'],
            'support_email' => ['required', 'email', 'max:191'],
            'support_whatsapp' => ['nullable', 'string', 'max:40'],
            'privacy_policy_url' => ['required', 'url', 'max:255'],
            'terms_of_service_url' => ['required', 'url', 'max:255'],
            'account_deletion_url' => ['required', 'url', 'max:255'],
            'minimum_registration_age' => ['sometimes', 'integer', 'min:18'],
        ], [
            'minimum_registration_age.min' => 'لا يمكن تخفيض الحد الأدنى لسن التسجيل عن 18 عاماً تحت أي ظرف.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        DB::transaction(function () use ($validated, $actor, $request) {
            $settingsMap = [
                'platform_general' => [
                    'value' => [
                        'app_display_name' => $validated['app_display_name'],
                        'general_announcement_ar' => $validated['general_announcement_ar'] ?? null,
                        'registration_enabled' => (bool) $validated['registration_enabled'],
                        'maintenance_mode' => (bool) $validated['maintenance_mode'],
                        'support_email' => $validated['support_email'],
                        'support_whatsapp' => $validated['support_whatsapp'] ?? null,
                    ],
                    'description_ar' => 'الإعدادات العامة للتطبيق وحالة الصيانة والتواصل مع الدعم',
                ],
                'require_profile_moderation' => [
                    'value' => ['enabled' => (bool) $validated['require_profile_moderation']],
                    'description_ar' => 'مراجعة الملفات الشخصية الجديدة قبل ظهورها في نتائج البحث العام',
                ],
                'privacy_and_terms_urls' => [
                    'value' => [
                        'privacy_policy_url' => $validated['privacy_policy_url'],
                        'terms_of_service_url' => $validated['terms_of_service_url'],
                        'account_deletion_url' => $validated['account_deletion_url'],
                    ],
                    'description_ar' => 'روابط سياسة الخصوصية وشروط الاستخدام وحذف الحساب عبر الويب',
                ],
            ];

            foreach ($settingsMap as $key => $item) {
                $existing = AppSetting::where('setting_key', $key)->first();
                $previousValue = $existing?->setting_value;

                $record = AppSetting::updateOrCreate(
                    ['setting_key' => $key],
                    [
                        'setting_value' => $item['value'],
                        'description_ar' => $item['description_ar'],
                        'updated_by_admin_id' => $actor->id,
                    ]
                );

                $this->auditService->record(
                    actor: $actor,
                    action: 'app_setting.updated',
                    target: $record,
                    previousValues: $previousValue,
                    newValues: $item['value'],
                    reason: "تحديث إعداد التطبيق ({$key})",
                    ipAddress: $request->ip()
                );
            }
        });

        return response()->json([
            'status' => 'success',
            'message' => 'تم حفظ إعدادات التطبيق بنجاح.',
        ]);
    }

    /**
     * Creates or updates an Administrator account (Super Admin only).
     */
    public function createAdministrator(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'min:3', 'max:120'],
            'email' => ['required', 'email', 'max:191', 'unique:administrators,email'],
            'password' => ['required', Password::min(12)->mixedCase()->numbers()->symbols()],
            'role' => ['required', 'string', 'in:super_admin,moderator'],
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        $newAdmin = Administrator::create([
            'name' => trim($validated['name']),
            'email' => strtolower(trim($validated['email'])),
            'password' => Hash::make($validated['password']),
            'role' => $validated['role'],
            'is_active' => true,
        ]);

        $this->auditService->record(
            actor: $actor,
            action: 'administrator.created',
            target: $newAdmin,
            newValues: [
                'name' => $newAdmin->name,
                'email' => $newAdmin->email,
                'role' => $newAdmin->role,
            ],
            reason: "إنشاء حساب مدير جديد بدور {$newAdmin->role}",
            ipAddress: $request->ip()
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'id' => $newAdmin->id,
                'name' => $newAdmin->name,
                'email' => $newAdmin->email,
                'role' => $newAdmin->role,
            ],
        ], 201);
    }

    /**
     * Updates an Administrator's role or active status, enforcing final Super Admin protection.
     */
    public function updateAdministrator(Request $request, Administrator $administrator): JsonResponse
    {
        $validated = $request->validate([
            'role' => ['required', 'string', 'in:super_admin,moderator'],
            'is_active' => ['required', 'boolean'],
            'suspension_reason' => ['nullable', 'string', 'max:255'],
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        if (!$this->administratorPolicy->changeRoleOrStatus($actor, $administrator, $validated['role'], (bool) $validated['is_active'])) {
            return response()->json([
                'status' => 'error',
                'code' => 'FINAL_SUPER_ADMIN_PROTECTED',
                'message' => 'لا يمكن إيقاف أو تخفيض صلاحية المدير العام الوحيد النشط في النظام.',
            ], 422);
        }

        try {
            $previousRole = $administrator->role;
            $previousActive = $administrator->is_active;

            $administrator->update([
                'role' => $validated['role'],
                'is_active' => (bool) $validated['is_active'],
                'suspension_reason' => $validated['suspension_reason'] ?? null,
            ]);

            $this->auditService->record(
                actor: $actor,
                action: 'administrator.updated',
                target: $administrator,
                previousValues: [
                    'role' => $previousRole,
                    'is_active' => $previousActive,
                ],
                newValues: [
                    'role' => $administrator->role,
                    'is_active' => $administrator->is_active,
                ],
                reason: $validated['suspension_reason'] ?? 'تحديث صلاحيات أو حالة حساب المدير',
                ipAddress: $request->ip()
            );
        } catch (DomainException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'FINAL_SUPER_ADMIN_PROTECTED',
                'message' => $e->getMessage(),
            ], 422);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'id' => $administrator->id,
                'role' => $administrator->role,
                'is_active' => $administrator->is_active,
            ],
        ]);
    }

    /**
     * Previews an administrative announcement campaign and returns the eligible recipient count (Super Admin only).
     */
    public function previewAnnouncementCampaign(
        Request $request,
        \App\Services\Notification\NotificationService $notificationService
    ): JsonResponse {
        $validated = $request->validate([
            'title_ar' => ['required', 'string', 'min:3', 'max:160'],
            'body_ar' => ['required', 'string', 'min:5', 'max:500'],
            'audience' => ['required', 'string', 'in:all_eligible_members,active_subscribers,expired_subscribers'],
        ]);

        $count = $notificationService->countEligibleAudience($validated['audience']);

        return response()->json([
            'status' => 'success',
            'data' => [
                'preview' => [
                    'title_ar' => trim($validated['title_ar']),
                    'body_ar' => trim($validated['body_ar']),
                    'audience' => $validated['audience'],
                    'eligible_recipients_count' => $count,
                ],
            ],
        ]);
    }

    /**
     * Creates and queues an administrative announcement campaign (Super Admin only).
     * Requires explicit confirmation (`confirmed: true`) and writes an audit log.
     */
    public function sendAnnouncementCampaign(
        Request $request,
        \App\Services\Notification\NotificationService $notificationService
    ): JsonResponse {
        $validated = $request->validate([
            'title_ar' => ['required', 'string', 'min:3', 'max:160'],
            'body_ar' => ['required', 'string', 'min:5', 'max:500'],
            'audience' => ['required', 'string', 'in:all_eligible_members,active_subscribers,expired_subscribers'],
            'confirmed' => ['required', 'boolean', 'accepted'],
            'scheduled_at' => ['nullable', 'date'],
            'idempotency_key' => ['nullable', 'string', 'max:120'],
        ], [
            'confirmed.accepted' => 'يرجى تأكيد معاينة الإشعار وعدد المستلمين قبل الإرسال.',
        ]);

        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        try {
            $campaign = $notificationService->createAndQueueAnnouncementCampaign($actor, $validated);

            return response()->json([
                'status' => 'success',
                'message' => 'تمت جدولة حملة الإشعارات في قائمة الانتظار بنجاح.',
                'data' => [
                    'campaign' => [
                        'id' => $campaign->id,
                        'title_ar' => $campaign->title_ar,
                        'body_ar' => $campaign->body_ar,
                        'audience' => $campaign->audience,
                        'status' => $campaign->status,
                        'eligible_recipients_count' => $campaign->eligible_recipients_count,
                        'queued_count' => $campaign->queued_count,
                        'submitted_to_fcm_count' => $campaign->submitted_to_fcm_count,
                        'rejected_by_fcm_count' => $campaign->rejected_by_fcm_count,
                        'confirmed_read_count' => $campaign->confirmed_read_count,
                    ],
                ],
            ], 201);
        } catch (\App\Exceptions\ApiBusinessException $e) {
            return response()->json([
                'status' => 'error',
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
            ], $e->httpStatus);
        }
    }
}
