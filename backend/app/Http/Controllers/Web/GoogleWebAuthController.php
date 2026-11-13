<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\SubscriptionPlan;
use App\Services\Auth\GoogleIdTokenVerifierService;
use App\Services\Auth\GoogleUserResolverService;
use DomainException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\View\View;

class GoogleWebAuthController extends Controller
{
    private const GOOGLE_AUTH_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth';
    private const GOOGLE_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';

    public function __construct(
        private readonly GoogleIdTokenVerifierService $googleVerifier,
        private readonly GoogleUserResolverService $userResolver,
    ) {}

    public function showLogin(Request $request): View|RedirectResponse
    {
        $intendedPlan = $this->sanitizeIntendedPlan($request->query('plan'));
        if ($intendedPlan !== null && $request->hasSession()) {
            $request->session()->put('website_intended_plan', $intendedPlan);
        }

        if (Auth::guard('web')->check()) {
            return $intendedPlan !== null
                ? redirect()->route('website.checkout.confirm', ['planCode' => $intendedPlan])
                : redirect()->route('website.account');
        }

        $clientId = (string) config('naseebak.google_auth.web_client_id');
        $clientSecret = (string) config('naseebak.google_auth.web_client_secret');

        return view('website.login', [
            'intendedPlan' => $intendedPlan ?? $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
            'oauthConfigured' => $clientId !== '' && $clientSecret !== '',
            'googleWebClientId' => $clientId,
            'errorMessage' => $request->session()->get('auth_error'),
        ]);
    }

    public function redirect(Request $request): RedirectResponse|Response
    {
        $intendedPlan = $this->sanitizeIntendedPlan($request->query('plan'));
        if ($intendedPlan !== null && $request->hasSession()) {
            $request->session()->put('website_intended_plan', $intendedPlan);
        }

        if (Auth::guard('web')->check()) {
            return $intendedPlan !== null
                ? redirect()->route('website.checkout.confirm', ['planCode' => $intendedPlan])
                : redirect()->route('website.account');
        }

        $clientId = trim((string) config('naseebak.google_auth.web_client_id'));
        $clientSecret = trim((string) config('naseebak.google_auth.web_client_secret'));

        if ($clientId === '' || $clientSecret === '') {
            return response()->view('website.login', [
                'intendedPlan' => $intendedPlan,
                'oauthConfigured' => false,
                'googleWebClientId' => $clientId,
                'errorMessage' => 'إعدادات الربط الخادمي مع Google OAuth (GOOGLE_WEB_CLIENT_SECRET) غير مكتملة على هذا الخادم بعد.',
            ], 503);
        }

        $state = Str::random(48);
        $request->session()->put('google_oauth_state', $state);

        $redirectUri = $this->resolveRedirectUri();

        $query = http_build_query([
            'client_id' => $clientId,
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'scope' => 'openid email profile',
            'state' => $state,
            'prompt' => 'select_account',
            'access_type' => 'online',
        ]);

        return redirect()->away(self::GOOGLE_AUTH_ENDPOINT . '?' . $query);
    }

    public function callback(Request $request): RedirectResponse|Response
    {
        if ($request->filled('error')) {
            return response()->view('website.login', [
                'intendedPlan' => $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
                'oauthConfigured' => true,
                'googleWebClientId' => (string) config('naseebak.google_auth.web_client_id'),
                'errorMessage' => 'تم إلغاء تسجيل الدخول عبر Google أو تعذر تفويض الحساب.',
            ], 400);
        }

        $expectedState = (string) $request->session()->pull('google_oauth_state', '');
        $providedState = (string) $request->query('state', '');

        if ($expectedState === '' || $providedState === '' || !hash_equals($expectedState, $providedState)) {
            return response()->view('website.login', [
                'intendedPlan' => $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
                'oauthConfigured' => true,
                'googleWebClientId' => (string) config('naseebak.google_auth.web_client_id'),
                'errorMessage' => 'تعذر التحقق الأمني من جلسة تسجيل الدخول عبر Google. يرجى إعادة المحاولة من البداية.',
            ], 403);
        }

        $code = trim((string) $request->query('code', ''));
        $clientId = trim((string) config('naseebak.google_auth.web_client_id'));
        $clientSecret = trim((string) config('naseebak.google_auth.web_client_secret'));

        if ($code === '' || $clientId === '' || $clientSecret === '') {
            return response()->view('website.login', [
                'intendedPlan' => $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
                'oauthConfigured' => $clientId !== '' && $clientSecret !== '',
                'googleWebClientId' => $clientId,
                'errorMessage' => 'بيانات تفويض Google OAuth غير مكتملة.',
            ], 400);
        }

        $tokenResponse = Http::asForm()
            ->acceptJson()
            ->timeout(12)
            ->post(self::GOOGLE_TOKEN_ENDPOINT, [
                'code' => $code,
                'client_id' => $clientId,
                'client_secret' => $clientSecret,
                'redirect_uri' => $this->resolveRedirectUri(),
                'grant_type' => 'authorization_code',
            ]);

        if (!$tokenResponse->successful()) {
            Log::warning('Google Web OAuth token exchange failed', [
                'http_status' => $tokenResponse->status(),
            ]);

            return response()->view('website.login', [
                'intendedPlan' => $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
                'oauthConfigured' => true,
                'googleWebClientId' => $clientId,
                'errorMessage' => 'تعذر إتمام الاتصال بخوادم Google للتحقق من الجلسة. يرجى المحاولة مجدداً.',
            ], 502);
        }

        $idToken = trim((string) ($tokenResponse->json('id_token') ?? ''));
        if ($idToken === '') {
            return response()->view('website.login', [
                'intendedPlan' => $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
                'oauthConfigured' => true,
                'googleWebClientId' => $clientId,
                'errorMessage' => 'استجابة Google لا تحتوي على رمز هوية موثق (ID Token).',
            ], 401);
        }

        try {
            $claims = $this->googleVerifier->verifyIdToken($idToken);
            $resolved = $this->userResolver->resolveOrCreateMember($claims);
            $user = $resolved['user'];
        } catch (AuthenticationException $e) {
            return response()->view('website.login', [
                'intendedPlan' => $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
                'oauthConfigured' => true,
                'googleWebClientId' => $clientId,
                'errorMessage' => $e->getMessage(),
            ], 401);
        } catch (DomainException $e) {
            $status = in_array((int) $e->getCode(), [403, 409, 422], true) ? (int) $e->getCode() : 403;

            return response()->view('website.login', [
                'intendedPlan' => $this->sanitizeIntendedPlan($request->session()->get('website_intended_plan')),
                'oauthConfigured' => true,
                'googleWebClientId' => $clientId,
                'errorMessage' => $e->getMessage(),
            ], $status);
        }

        Auth::guard('web')->login($user, remember: false);
        $request->session()->regenerate();

        $intendedPlan = $this->sanitizeIntendedPlan($request->session()->pull('website_intended_plan'));
        if ($intendedPlan !== null) {
            $activePlanExists = SubscriptionPlan::where('code', $intendedPlan)
                ->where('is_active', true)
                ->exists();

            if ($activePlanExists) {
                return redirect()->route('website.checkout.confirm', ['planCode' => $intendedPlan]);
            }
        }

        return redirect()->route('website.account');
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('website.home');
    }

    private function resolveRedirectUri(): string
    {
        $configured = trim((string) config('naseebak.google_auth.web_redirect_uri'));

        return $configured !== '' ? $configured : route('website.auth.google.callback');
    }

    private function sanitizeIntendedPlan(mixed $plan): ?string
    {
        $code = is_string($plan) ? trim($plan) : '';

        return in_array($code, ['monthly_membership', 'quarterly_membership'], true)
            ? $code
            : null;
    }
}
