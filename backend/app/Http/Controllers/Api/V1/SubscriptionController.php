<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Subscription\GooglePlayBillingService;
use App\Services\Subscription\SubscriptionEntitlementService;
use DomainException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class SubscriptionController extends Controller
{
    public function __construct(
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly GooglePlayBillingService $googlePlayService,
    ) {}

    /**
     * GET /api/v1/subscription
     *
     * Returns the authenticated member's current subscription details, active plan,
     * and authoritative server-side entitlement flags.
     * Never exposes raw purchase tokens or provider credentials.
     */
    public function show(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $currentSub = $this->entitlementService->findHighestPrioritySubscription($user);
        $entitlement = $this->entitlementService->getEntitlementPayload($user);

        return response()->json([
            'status' => 'success',
            'data' => [
                'entitlement' => $entitlement,
                'subscription' => $currentSub ? $this->formatSubscriptionRecord($currentSub) : null,
                'google_play_manage_url' => 'https://play.google.com/store/account/subscriptions?package='
                    . urlencode((string) config('naseebak.google_play.package_name', 'com.naseebak.app')),
            ],
        ]);
    }

    /**
     * GET /api/v1/subscription/plans
     *
     * Returns active subscription plans for the mobile app (with configurable Google Play product ID;
     * localized Google Play price is queried by Flutter directly from Google Play Billing).
     */
    public function plans(): JsonResponse
    {
        $plans = SubscriptionPlan::where('is_active', true)
            ->orderBy('id')
            ->get()
            ->map(fn (SubscriptionPlan $plan) => [
                'id' => $plan->id,
                'code' => $plan->code,
                'name_ar' => $plan->name_ar,
                'description_ar' => $plan->description_ar,
                'duration_days' => (int) $plan->duration_days,
                'google_play_product_id' => $plan->google_play_product_id,
                'features_ar' => $plan->features_ar ?? [
                    'إرسال طلبات التعارف',
                    'التواصل بعد الموافقة',
                    'إرسال الرسائل الخاصة',
                ],
                'renewal_terms_ar' => 'يتجدد الاشتراك شهرياً تلقائياً عبر حسابك في Google Play ما لم يتم إلغاؤه قبل 24 ساعة على الأقل من نهاية الفترة الحالية.',
                'cancellation_terms_ar' => 'يمكنك إدارة أو إلغاء اشتراكك في أي وقت من إعدادات الاشتراكات في متجر Google Play، ويستمر صلاحية الاشتراك حتى نهاية الفترة المدفوعة.',
            ]);

        return response()->json([
            'status' => 'success',
            'data' => [
                'plans' => $plans,
            ],
        ]);
    }

    /**
     * GET /api/v1/subscription/entitlement
     *
     * Returns the exact server-calculated entitlement payload required by Section 8:
     * - has_active_subscription
     * - subscription_status
     * - payment_channel
     * - current_period_end
     * - can_send_match_requests
     * - can_send_messages
     */
    public function entitlement(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'data' => $this->entitlementService->getEntitlementPayload($user),
        ]);
    }

    /**
     * POST /api/v1/subscription/google-play/verify
     *
     * Verifies a Google Play Billing purchase token server-side using Google Play Developer API (`subscriptionsv2`).
     * Strictly prohibits `user_id` in the request payload so no member can activate or modify another member's subscription.
     */
    public function verifyGooglePlayPurchase(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => ['prohibited'],
            'product_id' => ['required', 'string', 'max:128'],
            'purchase_token' => ['required', 'string', 'min:12', 'max:1024'],
            'package_name' => ['nullable', 'string', 'max:128'],
        ], [
            'user_id.prohibited' => 'لا يُسمح بتمرير معرف المستخدم يدوياً؛ يتم تحديد الهوية تلقائياً من الجلسة الموثقة.',
            'product_id.required' => 'معرف باقة الاشتراك مطلوب.',
            'purchase_token.required' => 'رمز التحقق من عملية الشراء مطلوب.',
        ]);

        /** @var User $user */
        $user = $request->user();

        try {
            $subscription = $this->googlePlayService->verifyAndSyncPurchaseForUser(
                user: $user,
                productId: $validated['product_id'],
                purchaseToken: $validated['purchase_token'],
                packageName: $validated['package_name'] ?? null
            );
        } catch (DomainException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'GOOGLE_PLAY_VERIFICATION_FAILED',
                'message' => $e->getMessage(),
            ], 422);
        } catch (RuntimeException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'GOOGLE_PLAY_SERVICE_UNAVAILABLE',
                'message' => $e->getMessage(),
            ], 503);
        }

        $subscription->loadMissing('plan');

        return response()->json([
            'status' => 'success',
            'message' => $subscription->isCurrentlyEntitled()
                ? 'تم التحقق من عملية الشراء وتفعيل اشتراكك الشهري بنجاح.'
                : 'تم استلام حالة الاشتراك من متجر Google Play.',
            'data' => [
                'entitlement' => $this->entitlementService->getEntitlementPayload($user),
                'subscription' => $this->formatSubscriptionRecord($subscription),
            ],
        ]);
    }

    /**
     * GET /api/v1/subscription/history
     *
     * Returns the authenticated member's own subscription and verified payment history.
     * Never exposes raw purchase tokens or internal gateway secrets.
     */
    public function history(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $subscriptions = Subscription::where('user_id', $user->id)
            ->with('plan')
            ->orderByDesc('created_at')
            ->limit(25)
            ->get()
            ->map(fn (Subscription $sub) => $this->formatSubscriptionRecord($sub));

        return response()->json([
            'status' => 'success',
            'data' => [
                'subscriptions' => $subscriptions,
            ],
        ]);
    }

    private function formatSubscriptionRecord(Subscription $sub): array
    {
        return [
            'id' => $sub->id,
            'plan_code' => $sub->plan?->code ?? 'monthly_membership',
            'plan_name_ar' => $sub->plan?->name_ar ?? 'العضوية الشهرية — نصيبك',
            'channel' => $sub->channel,
            'channel_label_ar' => match ($sub->channel) {
                Subscription::CHANNEL_GOOGLE_PLAY => 'متجر Google Play',
                Subscription::CHANNEL_PAYMOB => 'الدفع الإلكتروني عبر الويب (Paymob)',
                Subscription::CHANNEL_SHA7NAWY => 'الدفع الإلكتروني عبر الويب (شحناوي)',
                default => $sub->channel,
            },
            'status' => $sub->normalizedStatus(),
            'status_label_ar' => match ($sub->normalizedStatus()) {
                Subscription::STATUS_ACTIVE => 'نشط',
                Subscription::STATUS_CANCELLED => 'ملغى التجديد (ساري حتى نهاية الفترة)',
                Subscription::STATUS_IN_GRACE_PERIOD => 'فترة سماح لتحديث وسيلة الدفع',
                Subscription::STATUS_ON_HOLD => 'معلق مؤقتاً بسبب تعذر تحصيل الدفعة',
                Subscription::STATUS_PENDING => 'بانتظار تأكيد الدفع',
                Subscription::STATUS_EXPIRED => 'منتهي الصلاحية',
                Subscription::STATUS_REFUNDED => 'مسترد',
                Subscription::STATUS_REVOKED => 'ملغى من المزود',
                default => $sub->status,
            },
            'is_currently_entitled' => $sub->isCurrentlyEntitled(),
            'auto_renewing' => (bool) $sub->auto_renewing,
            'starts_at' => $sub->starts_at?->toIso8601String(),
            'current_period_end' => $sub->effectiveExpirationAt()?->toIso8601String(),
            'cancelled_at' => $sub->cancelled_at?->toIso8601String(),
            'last_verified_at' => $sub->last_verified_at?->toIso8601String(),
        ];
    }
}
