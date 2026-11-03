<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use App\Models\User;
use App\Models\UserPreference;
use App\Services\Auth\GoogleIdTokenVerifierService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class AuthController extends Controller
{
    public function __construct(
        private readonly GoogleIdTokenVerifierService $googleVerifier,
        private readonly SubscriptionEntitlementService $entitlementService,
    ) {}

    /**
     * POST /api/v1/auth/google
     *
     * Verifies the Google OpenID Connect ID Token server-side, finds or creates the User
     * in PostgreSQL using Google's stable `sub` identifier, enforces account suspension rules,
     * issues a Laravel Sanctum token, and returns profile completion & entitlement state.
     */
    public function loginWithGoogle(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_token' => ['required', 'string', 'min:50'],
            'device_name' => ['nullable', 'string', 'max:120'],
        ], [
            'id_token.required' => 'رمز مصادقة Google مطلوب.',
        ]);

        try {
            $verifiedIdentity = $this->googleVerifier->verifyIdToken($validated['id_token']);
        } catch (AuthenticationException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'INVALID_GOOGLE_TOKEN',
                'message' => $e->getMessage(),
            ], 401);
        } catch (RuntimeException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'GOOGLE_AUTH_MISCONFIGURED',
                'message' => $e->getMessage(),
            ], 503);
        }

        /** @var array{user: User, is_new_user: bool} $result */
        $result = DB::transaction(function () use ($verifiedIdentity) {
            $user = User::withTrashed()
                ->where('google_sub', $verifiedIdentity['sub'])
                ->first();

            $isNewUser = false;

            if (!$user) {
                $user = User::create([
                    'google_sub' => $verifiedIdentity['sub'],
                    'email' => $verifiedIdentity['email'],
                    'email_verified' => $verifiedIdentity['email_verified'],
                    'role' => 'member',
                    'account_status' => 'active',
                    'profile_completed' => false,
                    'last_active_at' => now(),
                ]);

                UserPreference::create([
                    'user_id' => $user->id,
                    'min_age' => 18,
                    'max_age' => 55,
                ]);

                $isNewUser = true;
            } else {
                if ($user->trashed()) {
                    // Prevent login to deleted accounts unless restored by support
                    return ['user' => $user, 'is_new_user' => false];
                }

                $user->update([
                    'email' => $verifiedIdentity['email'],
                    'email_verified' => $verifiedIdentity['email_verified'],
                    'last_active_at' => now(),
                ]);
            }

            return ['user' => $user, 'is_new_user' => $isNewUser];
        });

        $user = $result['user'];

        if ($user->trashed() || $user->account_status === 'deleted') {
            return response()->json([
                'status' => 'error',
                'code' => 'ACCOUNT_DELETED',
                'message' => 'تم حذف هذا الحساب مسبقاً ولا يمكن تسجيل الدخول به.',
            ], 403);
        }

        if ($user->isSuspended()) {
            // Revoke any existing tokens immediately
            $user->tokens()->delete();

            return response()->json([
                'status' => 'error',
                'code' => 'ACCOUNT_SUSPENDED',
                'message' => 'تم إيقاف حسابك لمخالفة شروط الاستخدام.',
                'suspension_reason' => $user->suspension_reason ?: 'تم تقييد الوصول إلى الحساب بقرار من الإدارة.',
            ], 403);
        }

        $deviceName = $validated['device_name'] ?? 'naseebak-android-client';
        $sanctumToken = $user->createToken($deviceName, ['mobile:access'])->plainTextToken;

        $user->load(['profile', 'photos', 'activeSubscription']);

        return response()->json([
            'status' => 'success',
            'message' => $result['is_new_user']
                ? 'تم إنشاء حسابك بنجاح. يرجى استكمال ملفك الشخصي.'
                : 'تم تسجيل الدخول بنجاح.',
            'data' => [
                'token' => $sanctumToken,
                'is_new_user' => $result['is_new_user'],
                'next_route' => $user->profile_completed ? 'home' : 'complete_profile',
                'google_Suggested_name' => $verifiedIdentity['name'],
                'user' => $this->formatAuthenticatedUser($user),
            ],
        ]);
    }

    /**
     * GET /api/v1/auth/me
     */
    public function me(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $user->update(['last_active_at' => now()]);
        $user->load(['profile', 'photos', 'preferences', 'activeSubscription']);

        return response()->json([
            'status' => 'success',
            'data' => [
                'next_route' => $user->profile_completed ? 'home' : 'complete_profile',
                'user' => $this->formatAuthenticatedUser($user),
            ],
        ]);
    }

    /**
     * POST /api/v1/auth/logout
     */
    public function logout(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        // Deregister FCM device token if supplied on logout
        if ($request->filled('fcm_token')) {
            $rawToken = trim((string) $request->input('fcm_token'));
            $fingerprint = DeviceToken::computeFingerprint($rawToken);
            DeviceToken::where('user_id', $user->id)
                ->where(function ($q) use ($rawToken, $fingerprint) {
                    $q->where('token_fingerprint', $fingerprint)
                        ->orWhere('fcm_token', $rawToken);
                })
                ->delete();
        }

        $user->currentAccessToken()?->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تم تسجيل الخروج بنجاح.',
        ]);
    }

    private function formatAuthenticatedUser(User $user): array
    {
        $entitlement = $this->entitlementService->getEntitlementPayload($user);
        $activeSub = $this->entitlementService->findHighestPrioritySubscription($user);

        return [
            'id' => $user->id,
            'email' => $user->email,
            'account_status' => $user->account_status,
            'profile_completed' => (bool) $user->profile_completed,
            'has_active_subscription' => $entitlement['has_active_subscription'],
            'can_send_match_requests' => $entitlement['can_send_match_requests'],
            'can_send_messages' => $entitlement['can_send_messages'],
            'entitlement' => $entitlement,
            'active_subscription' => ($activeSub && $activeSub->isCurrentlyEntitled()) ? [
                'status' => $activeSub->normalizedStatus(),
                'channel' => $activeSub->channel,
                'starts_at' => $activeSub->starts_at?->toIso8601String(),
                'ends_at' => $activeSub->effectiveExpirationAt()?->toIso8601String(),
                'grace_period_ends_at' => $activeSub->grace_period_ends_at?->toIso8601String(),
                'auto_renewing' => (bool) $activeSub->auto_renewing,
            ] : null,
            'profile' => $user->profile,
            'photos' => $user->photos,
        ];
    }
}
