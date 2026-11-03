<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\PaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Auth\GoogleIdTokenVerifierService;
use App\Services\Payment\PaymentGatewayManager;
use App\Services\Subscription\SubscriptionEntitlementService;
use DomainException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Contracts\View\View;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use RuntimeException;

/**
 * Separate Web Customer Subscription Portal Controller.
 *
 * Strictly isolated from:
 * 1. The Google Play-distributed Android app (no external checkout links are injected into the Play app).
 * 2. The Filament Administrator panel (`/admin` guard).
 *
 * Customers authenticate using Google OpenID Connect (`google_sub` subject identifier matching,
 * never trusting email address alone).
 */
class WebSubscriptionPortalController extends Controller
{
    public function __construct(
        private readonly GoogleIdTokenVerifierService $googleVerifier,
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly PaymentGatewayManager $gatewayManager,
    ) {}

    /**
     * GET /membership
     *
     * Renders the Arabic RTL Web Customer Subscription Portal interface.
     */
    public function showPortal(Request $request): View
    {
        /** @var User|null $user */
        $user = Auth::guard('web')->user();
        $setting = PaymentSetting::first();
        $plan = SubscriptionPlan::where('code', 'monthly_membership')->where('is_active', true)->first();

        return view('membership.portal', [
            'user' => $user,
            'entitlement' => $user ? $this->entitlementService->getEntitlementPayload($user) : null,
            'plan' => $plan,
            'setting' => $setting,
            'googleWebClientId' => config('naseebak.auth.google_web_client_id'),
        ]);
    }

    /**
     * POST /membership/auth/google
     *
     * Authenticates an existing member on the web customer portal using a verified Google ID token
     * matched strictly by Google's stable `sub` identifier (`google_sub`).
     */
    public function loginWithGoogle(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_token' => ['required', 'string', 'min:50'],
        ]);

        try {
            $verified = $this->googleVerifier->verifyIdToken($validated['id_token']);
        } catch (AuthenticationException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'INVALID_GOOGLE_TOKEN',
                'message' => $e->getMessage(),
            ], 401);
        }

        // Link strictly via Google's stable subject identifier ('google_sub'), NEVER by email alone
        $user = User::where('google_sub', $verified['sub'])->first();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'code' => 'MEMBER_ACCOUNT_NOT_FOUND',
                'message' => 'يرجى إنشاء حسابك أولاً عبر تطبيق نصيبك قبل إدارة الاشتراك عبر البوابة الإلكترونية.',
            ], 404);
        }

        if ($user->account_status !== 'active') {
            return response()->json([
                'status' => 'error',
                'code' => 'ACCOUNT_NOT_ACTIVE',
                'message' => 'هذا الحساب موقوف أو غير نشط حالياً.',
            ], 403);
        }

        Auth::guard('web')->login($user);
        if ($request->hasSession()) {
            $request->session()->regenerate();
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'user_id' => $user->id,
                'entitlement' => $this->entitlementService->getEntitlementPayload($user),
            ],
        ]);
    }

    /**
     * GET /membership/status
     *
     * Displays the web customer's current subscription status, active web plan,
     * current web price in EGP, active web payment gateway, and verified payment history.
     */
    public function status(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::guard('web')->user() ?? $request->user();
        $setting = PaymentSetting::first();
        $plan = SubscriptionPlan::where('code', 'monthly_membership')->where('is_active', true)->first();

        $transactions = PaymentTransaction::where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->limit(20)
            ->get()
            ->map(fn (PaymentTransaction $tx) => [
                'internal_reference' => $tx->internal_reference,
                'gateway' => $tx->gateway,
                'amount' => (string) $tx->amount,
                'currency' => $tx->currency,
                'status' => $tx->status,
                'signature_verified' => (bool) $tx->signature_verified,
                'paid_at' => $tx->paid_at?->toIso8601String(),
                'created_at' => $tx->created_at?->toIso8601String(),
            ]);

        return response()->json([
            'status' => 'success',
            'data' => [
                'entitlement' => $this->entitlementService->getEntitlementPayload($user),
                'web_plan' => $plan ? [
                    'code' => $plan->code,
                    'name_ar' => $plan->name_ar,
                    'duration_days' => (int) $plan->duration_days,
                    'web_monthly_price' => (string) ($setting?->web_monthly_price ?? $plan->web_price_amount),
                    'currency' => $setting?->web_currency ?? 'EGP',
                    'active_gateway' => $setting?->active_web_payment_gateway ?? 'paymob',
                    'renewal_instructions_ar' => 'الاشتراك عبر بوابة الدفع الإلكترونية يغطي 30 يوماً كاملة ولا يقوم بسحب تلقائي متكرر من البطاقة؛ يمكنك تجديد اشتراكك يدوياً بأمان عند انتهاء الفترة أو قبلها مع إضافة الأيام الجديدة إلى رصيدك الحالي.',
                ] : null,
                'payment_history' => $transactions,
            ],
        ]);
    }

    /**
     * POST /membership/checkout
     *
     * Creates a server-side payment order with a fixed EGP amount snapshot using the single
     * currently active web payment gateway ('paymob' or 'sha7nawy').
     * Rejects any client-supplied price or user_id.
     */
    public function createCheckoutSession(Request $request): JsonResponse
    {
        $request->validate([
            'user_id' => ['prohibited'],
            'amount' => ['prohibited'],
            'price' => ['prohibited'],
        ], [
            'user_id.prohibited' => 'لا يُسمح بتمرير معرف المستخدم من المتصفح.',
            'amount.prohibited' => 'يتم تحديد سعر الاشتراك حصرياً من الخادم.',
            'price.prohibited' => 'يتم تحديد سعر الاشتراك حصرياً من الخادم.',
        ]);

        /** @var User $user */
        $user = Auth::guard('web')->user() ?? $request->user();
        if (!$user || $user->account_status !== 'active') {
            return response()->json([
                'status' => 'error',
                'code' => 'UNAUTHENTICATED',
                'message' => 'يرجى تسجيل الدخول للمتابعة إلى الدفع.',
            ], 401);
        }

        $setting = PaymentSetting::first();
        $plan = SubscriptionPlan::where('code', 'monthly_membership')->where('is_active', true)->first();

        if (!$setting || !$plan) {
            return response()->json([
                'status' => 'error',
                'code' => 'PLAN_UNAVAILABLE',
                'message' => 'باقة الاشتراك الشهري غير متاحة حالياً.',
            ], 503);
        }

        // Fixed server-side price snapshot at order creation time
        $fixedPriceEgp = (string) $setting->web_monthly_price;

        try {
            $gateway = $this->gatewayManager->getActiveWebGateway();
            $checkoutResult = $gateway->createPayment($user, $plan, $fixedPriceEgp);
        } catch (DomainException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'PAYMENT_GATEWAY_UNAVAILABLE',
                'message' => $e->getMessage(),
            ], 422);
        } catch (RuntimeException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'PAYMENT_CREATION_FAILED',
                'message' => $e->getMessage(),
            ], 503);
        }

        /** @var PaymentTransaction $tx */
        $tx = $checkoutResult['transaction'];

        return response()->json([
            'status' => 'success',
            'data' => [
                'internal_reference' => $tx->internal_reference,
                'gateway' => $tx->gateway,
                'fixed_amount' => (string) $tx->amount,
                'amount_minor' => (int) $tx->amount_minor,
                'currency' => $tx->currency,
                'checkout_url' => $checkoutResult['checkout_url'],
            ],
        ], 201);
    }
}
