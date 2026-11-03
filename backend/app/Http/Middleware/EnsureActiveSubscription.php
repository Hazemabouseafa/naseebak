<?php

namespace App\Http\Middleware;

use App\Services\Subscription\SubscriptionEntitlementService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureActiveSubscription
{
    public function __construct(
        private readonly SubscriptionEntitlementService $entitlementService
    ) {}

    /**
     * Enforce server-side subscription entitlement before allowing matchmaking requests or outgoing messages.
     * Returns HTTP 403 with code 'SUBSCRIPTION_REQUIRED' when the user lacks an active verified entitlement.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || !$this->entitlementService->hasActiveSubscription($user)) {
            return response()->json([
                'status' => 'error',
                'code' => 'SUBSCRIPTION_REQUIRED',
                'message' => 'يتطلب هذا الإجراء اشتراكاً شهرياً نشطاً في تطبيق نصيبك.',
                'requires_subscription' => true,
            ], 403);
        }

        return $next($request);
    }
}
