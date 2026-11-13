<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\PaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Payment\WebsiteCheckoutService;
use App\Services\Subscription\SubscriptionEntitlementService;
use DomainException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;
use RuntimeException;

class WebsiteCheckoutController extends Controller
{
    public function __construct(
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly WebsiteCheckoutService $checkoutService,
    ) {}

    /**
     * PAGE 02 — GET /plans
     */
    public function plans(): View
    {
        $plans = SubscriptionPlan::query()
            ->where('is_active', true)
            ->whereIn('code', WebsiteCheckoutService::SUPPORTED_WEB_PLAN_CODES)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        $monthlyPlan = $plans->firstWhere('code', 'monthly_membership');
        $quarterlyPlan = $plans->firstWhere('code', 'quarterly_membership');
        $savingsPercent = SubscriptionPlan::computeSavingsPercentVsMonthly($monthlyPlan, $quarterlyPlan);

        $setting = PaymentSetting::current();
        $diagnostics = $setting->gatewayDiagnostics();
        /** @var ?User $webUser */
        $webUser = Auth::guard('web')->user();

        return view('website.plans', [
            'plans' => $plans,
            'monthlyPlan' => $monthlyPlan,
            'quarterlyPlan' => $quarterlyPlan,
            'savingsPercent' => $savingsPercent,
            'setting' => $setting,
            'diagnostics' => $diagnostics,
            'webUser' => $webUser,
            'entitlement' => $webUser ? $this->entitlementService->getEntitlementPayload($webUser) : null,
        ]);
    }

    /**
     * PAGE 03 — GET /account (protected by auth:web + active_account)
     */
    public function account(Request $request): View
    {
        /** @var User $user */
        $user = Auth::guard('web')->user();
        $user->load('profile');

        $entitlement = $this->entitlementService->getEntitlementPayload($user);
        $activeSub = $this->entitlementService->findHighestPrioritySubscription($user)?->loadMissing('plan');
        $transactions = PaymentTransaction::with('plan')
            ->where('user_id', $user->id)
            ->orderByDesc('id')
            ->limit(25)
            ->get();

        $setting = PaymentSetting::current();

        return view('website.account', [
            'user' => $user,
            'entitlement' => $entitlement,
            'activePlanName' => $activeSub?->plan?->name_ar,
            'transactions' => $transactions,
            'setting' => $setting,
        ]);
    }

    /**
     * PAGE 04 Step 1 — GET /plans/{planCode}/checkout
     */
    public function confirmOrder(Request $request, string $planCode): View
    {
        if (!in_array($planCode, WebsiteCheckoutService::SUPPORTED_WEB_PLAN_CODES, true)) {
            abort(404);
        }

        $plan = SubscriptionPlan::where('code', $planCode)
            ->where('is_active', true)
            ->firstOrFail();

        /** @var User $user */
        $user = Auth::guard('web')->user();
        $user->load('profile');

        $setting = PaymentSetting::current();
        $diagnostics = $setting->gatewayDiagnostics();
        $activeGateway = $setting->active_web_payment_gateway;
        $gatewayInfo = $diagnostics[$activeGateway] ?? ['configured' => false, 'status_label_ar' => 'غير متاح'];

        return view('website.checkout_confirm', [
            'plan' => $plan,
            'user' => $user,
            'entitlement' => $this->entitlementService->getEntitlementPayload($user),
            'setting' => $setting,
            'activeGateway' => $activeGateway,
            'gatewayReady' => (bool) ($gatewayInfo['configured'] ?? false),
            'gatewayStatusLabel' => (string) ($gatewayInfo['status_label_ar'] ?? ''),
            'gatewayMissingItems' => (array) ($gatewayInfo['missing_items'] ?? []),
        ]);
    }

    /**
     * PAGE 04 Step 2 — POST /checkout
     */
    public function createOrder(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'plan_code' => ['required', 'string', 'in:monthly_membership,quarterly_membership'],
            'user_id' => ['prohibited'],
            'amount' => ['prohibited'],
            'price' => ['prohibited'],
            'amount_minor' => ['prohibited'],
            'status' => ['prohibited'],
        ], [
            'user_id.prohibited' => 'لا يُسمح بتمرير معرف المستخدم من المتصفح.',
            'amount.prohibited' => 'السعر يُحدد حصرياً من الخادم.',
            'price.prohibited' => 'السعر يُحدد حصرياً من الخادم.',
        ]);

        /** @var User $user */
        $user = Auth::guard('web')->user();

        try {
            $checkoutResult = $this->checkoutService->initiateCheckout($user, $validated['plan_code']);

            return redirect()->away($checkoutResult['checkout_url']);
        } catch (DomainException|RuntimeException $e) {
            return redirect()
                ->route('website.checkout.confirm', ['planCode' => $validated['plan_code']])
                ->with('checkout_error', $e->getMessage());
        }
    }

    /**
     * PAGE 05 — GET /payment/return/{reference}
     */
    public function paymentReturn(Request $request, string $reference): View
    {
        $transaction = PaymentTransaction::with(['plan', 'user'])
            ->where('internal_reference', $reference)
            ->firstOrFail();

        /** @var ?User $webUser */
        $webUser = Auth::guard('web')->user();
        if ($webUser !== null && (int) $webUser->id !== (int) $transaction->user_id) {
            abort(403);
        }

        // Strict PostgreSQL database state ONLY — never activate or trust return query parameters.
        $state = $this->checkoutService->resolveReturnState($transaction);
        $isOwnerSession = $webUser !== null && (int) $webUser->id === (int) $transaction->user_id;

        return view('website.payment_result', [
            'transaction' => $transaction,
            'state' => $state,
            'isOwnerSession' => $isOwnerSession,
            'entitlement' => $isOwnerSession ? $this->entitlementService->getEntitlementPayload($webUser) : null,
        ]);
    }

    /**
     * GET /orders/{reference}/status (Polling JSON — owner only, strictly read-only)
     */
    public function orderStatus(Request $request, string $reference): JsonResponse
    {
        /** @var User $user */
        $user = Auth::guard('web')->user();
        $transaction = PaymentTransaction::where('internal_reference', $reference)->firstOrFail();

        if ((int) $transaction->user_id !== (int) $user->id) {
            abort(403);
        }

        $entitlement = $this->entitlementService->getEntitlementPayload($user);

        return response()->json([
            'status' => 'success',
            'data' => [
                'internal_reference' => $transaction->internal_reference,
                'transaction_status' => $transaction->status,
                'return_state' => $this->checkoutService->resolveReturnState($transaction),
                'has_active_subscription' => (bool) ($entitlement['has_active_subscription'] ?? false),
                'subscription_ends_at' => $entitlement['current_period_end'] ?? null,
            ],
        ]);
    }

    /**
     * POST /orders/{reference}/cancel (User cancels a PENDING unpaid order only)
     */
    public function cancelOrder(Request $request, string $reference): RedirectResponse
    {
        /** @var User $user */
        $user = Auth::guard('web')->user();

        try {
            $this->checkoutService->cancelPendingOrderForUser($user, $reference);

            return redirect()
                ->route('website.payment.return', ['reference' => $reference])
                ->with('status_notice', 'تم إلغاء طلب الدفع غير المدفوع بناءً على طلبك.');
        } catch (DomainException $e) {
            return redirect()
                ->route('website.account')
                ->with('account_error', $e->getMessage());
        }
    }
}
