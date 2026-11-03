<?php

namespace App\Services\Auth;

use Google\Client as GoogleClient;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

class GoogleIdTokenVerifierService
{
    /**
     * Verify a Google OpenID Connect ID Token using Google's official library.
     *
     * Verifies:
     * 1. Cryptographic signature against Google's JWK public keys
     * 2. Audience (aud) matches configured Android / Web OAuth Client IDs
     * 3. Issuer (iss) is accounts.google.com or https://accounts.google.com
     * 4. Token expiration (exp) and issued-at (iat)
     * 5. Presence of stable 'sub' subject identifier
     *
     * SECURITY RULE: Never log raw Google authentication tokens.
     *
     * @param string $idToken Raw Google ID token from Flutter client
     * @return array{sub: string, email: string, email_verified: bool, name: ?string}
     * @throws AuthenticationException
     */
    public function verifyIdToken(string $idToken): array
    {
        $webClientId = config('naseebak.google_auth.web_client_id');
        $androidClientId = config('naseebak.google_auth.android_client_id');
        $allowedIssuers = config('naseebak.google_auth.allowed_issuers', [
            'accounts.google.com',
            'https://accounts.google.com',
        ]);

        if (empty($webClientId) && empty($androidClientId)) {
            Log::critical('Google OAuth Client IDs are not configured on the server.');
            throw new RuntimeException('إعدادات مصادقة Google غير مكتملة على الخادم.');
        }

        try {
            $client = new GoogleClient([
                'client_id' => $webClientId ?: $androidClientId,
            ]);

            $payload = $client->verifyIdToken($idToken);
        } catch (Throwable $e) {
            // Do NOT log $idToken under any circumstances
            Log::warning('Google ID token verification exception', [
                'error_class' => get_class($e),
                'error_message' => $e->getMessage(),
            ]);
            throw new AuthenticationException('تعذر التحقق من صلاحية جلسة Google. يرجى المحاولة مرة أخرى.');
        }

        if (!is_array($payload)) {
            throw new AuthenticationException('رمز المصادقة من Google غير صالح أو منتهي الصلاحية.');
        }

        // Verify issuer explicitly
        $issuer = $payload['iss'] ?? '';
        if (!in_array($issuer, $allowedIssuers, true)) {
            throw new AuthenticationException('مصدر رمز المصادقة غير موثوق.');
        }

        // Verify audience against configured client IDs
        $allowedAudiences = array_values(array_filter([$webClientId, $androidClientId]));
        $audience = $payload['aud'] ?? '';
        if (!in_array($audience, $allowedAudiences, true)) {
            throw new AuthenticationException('معرّف تطبيق Google غير مطابق.');
        }

        // Verify expiration
        $expiration = (int) ($payload['exp'] ?? 0);
        if ($expiration <= time()) {
            throw new AuthenticationException('انتهت صلاحية جلسة التحقق من Google.');
        }

        // Extract Google's stable subject identifier
        $googleSub = trim((string) ($payload['sub'] ?? ''));
        $email = strtolower(trim((string) ($payload['email'] ?? '')));

        if ($googleSub === '' || $email === '') {
            throw new AuthenticationException('بيانات الحساب المستلمة من Google غير مكتملة.');
        }

        return [
            'sub' => $googleSub,
            'email' => $email,
            'email_verified' => (bool) ($payload['email_verified'] ?? true),
            'name' => isset($payload['name']) ? trim((string) $payload['name']) : null,
        ];
    }
}
