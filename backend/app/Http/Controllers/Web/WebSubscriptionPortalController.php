<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\PaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Auth\GoogleIdTokenVerifierService;
use App\Services\Auth\GoogleUserResolverService;
use App\Services\Payment\WebsiteCheckoutService;
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
        private readonly GoogleUserResolverService $userResolver,
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly WebsiteCheckoutService $checkoutService,
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
            'googleWebClientId' => config('naseebak.google_auth.web_client_id'),
        ]);
    }

    /**
     * POST /membership/auth/google
     *
     * Authenticates a member on the web customer portal using a verified Google ID token
     * matched strictly by Google's stable `sub` identifier (`google_sub`).
     */
    public function loginWithGoogle(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_token' => ['required', 'string', 'min:50'],
        ]);

        try {
            $verified = $this->googleVerifier->verifyIdToken($validated['id_token']);
            $resolved = $this->userResolver->resolveOrCreateMember($verified);
            $user = $resolved['user'];
        } catch (AuthenticationException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'INVALID_GOOGLE_TOKEN',
                'message' => $e->getMessage(),
            ], 401);
        } catch (DomainException $e) {
            $status = in_array((int) $e->getCode(), [403, 409, 422], true) ? (int) $e->getCode() : 403;

            return response()->json([
                'status' => 'error',
                'code' => 'GOOGLE_LOGIN_REJECTED',
                'message' => $e->getMessage(),
            ], $status);
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
        $validated = $request->validate([
            'plan_code' => ['nullable', 'string', 'in:monthly_membership,quarterly_membership'],
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

        $planCode = $validated['plan_code'] ?? 'monthly_membership';

        try {
            $checkoutResult = $this->checkoutService->initiateCheckout($user, $planCode);
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
