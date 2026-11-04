<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Mail\AccountDeletionVerificationMail;
use App\Models\AppSetting;
use App\Models\User;
use App\Services\Auth\AccountDeletionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\URL;
use Illuminate\View\View;

class AccountDeletionWebController extends Controller
{
    public function __construct(
        private readonly AccountDeletionService $deletionService
    ) {}

    /**
     * GET /legal/delete-account
     *
     * Publicly accessible web page meeting Google Play Store requirements:
     * - Explains account deletion process, personal data removal, and data retention policies.
     * - Provides instructions and direct links for cancelling recurring Google Play Store subscriptions.
     * - Provides an in-app deletion walkthrough as well as a direct web deletion request form.
     */
    public function showDeleteAccountPage(Request $request): View
    {
        $general = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];

        return view('legal.delete_account', [
            'appName' => $general['app_display_name'] ?? 'نَصِيبُكَ — Naseebak',
            'supportEmail' => $general['support_email'] ?? 'support@naseebak.app',
            'googlePlaySubscriptionsUrl' => 'https://play.google.com/store/account/subscriptions',
            'currentUser' => $request->user('web'),
        ]);
    }

    /**
     * POST /legal/delete-account
     *
     * Web deletion request mechanism with strict ownership verification:
     * - If submitted by an authenticated web user, directly verifies email match and executes deletion.
     * - If submitted by an unauthenticated guest, NEVER deletes the account immediately.
     *   Instead, generates a cryptographic signed URL and sends an ownership verification link to the verified email.
     * - Returns a generic, timing-safe confirmation notice to prevent email enumeration attacks.
     */
    public function submitDeletionRequest(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:120'],
            'confirmation' => ['required', 'in:DELETE,حذف,حذف حسابي'],
            'acknowledge_play_store' => ['required', 'accepted'],
            'reason' => ['nullable', 'string', 'max:500'],
        ], [
            'email.required' => 'يرجى إدخال البريد الإلكتروني المسجل في حسابك.',
            'email.email' => 'صيغة البريد الإلكتروني غير صحيحة.',
            'confirmation.required' => 'يرجى كتابة كلمة "حذف" في حقل التأكيد.',
            'confirmation.in' => 'حقل التأكيد غير صحيح؛ يرجى كتابة "حذف".',
            'acknowledge_play_store.accepted' => 'يجب الإقرار بأن حذف الحساب لا يلغي اشتراك Google Play التلقائي.',
        ]);

        $email = trim(strtolower((string) $validated['email']));
        $currentUser = $request->user('web');

        // Flow A: Authenticated web user directly deleting their own active account
        if ($currentUser !== null) {
            if (strtolower($currentUser->email) !== $email) {
                return redirect()->route('legal.delete_account')->withErrors([
                    'email' => 'البريد الإلكتروني المدخل لا يطابق حساب الجلسة النشطة الحالية.',
                ]);
            }

            $this->deletionService->executeUserDeletion(
                user: $currentUser,
                reason: $validated['reason'] ?? null,
                actor: 'web_authenticated_user'
            );

            Auth::guard('web')->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('legal.delete_account')->with(
                'success',
                'تم حذف حسابك بنجاح ومحو كافة بياناتك الشخصية والصور وسجل المحادثات نهائياً. يُرجى تذكّر إلغاء أي اشتراك دوري في متجر Google Play إن وُجد.'
            );
        }

        // Flow B: Unauthenticated guest request — Enforce email ownership verification via signed URL
        $user = User::where('email', $email)->first();

        if ($user && $user->account_status !== 'deleted' && !$user->trashed()) {
            $signedConfirmUrl = URL::temporarySignedRoute(
                'legal.confirm_delete_account',
                now()->addMinutes(30),
                ['id' => $user->id, 'hash' => sha1($user->email)]
            );

            Log::info("Web account deletion verification link generated for user ID {$user->id} (email {$email}): {$signedConfirmUrl}");

            // Send verification email (or log if mail driver is log)
            try {
                Mail::to($email)->send(new AccountDeletionVerificationMail($signedConfirmUrl, $email));
            } catch (\Throwable $e) {
                Log::warning("Failed to dispatch web deletion confirmation email to {$email}: {$e->getMessage()}");
            }
        } else {
            Log::info("Web account deletion request received for unverified/missing email: {$email}");
        }

        return redirect()->route('legal.delete_account')->with(
            'success',
            'إذا كان هذا البريد الإلكتروني مسجلاً لدينا، فقد تم إرسال رابط تأكيد الحذف الآمن إلى بريدك الإلكتروني. يُرجى التحقق من صندوق الوارد (أو مجلد الرسائل غير المرغوب فيها) والنقر على الرابط لإتمام الحذف النهائي. الرابط صالح لمدة 30 دقيقة حرصاً على أمان حسابك.'
        );
    }

    /**
     * GET /legal/confirm-delete-account/{id}/{hash}
     *
     * Signed URL verification landing page.
     */
    public function showConfirmDeletionPage(Request $request, int $id, string $hash): View
    {
        if (! $request->hasValidSignature()) {
            abort(403, 'رابط تأكيد حذف الحساب منتهي الصلاحية أو غير صالح.');
        }

        $user = User::findOrFail($id);

        if (sha1($user->email) !== $hash) {
            abort(403, 'بيانات التحقق من البريد الإلكتروني غير متطابقة.');
        }

        $emailParts = explode('@', $user->email);
        $maskedUser = substr($emailParts[0], 0, 2) . '***' . substr($emailParts[0], -1);
        $maskedEmail = $maskedUser . '@' . ($emailParts[1] ?? '');

        $submitUrl = URL::temporarySignedRoute(
            'legal.execute_confirmed_deletion',
            now()->addMinutes(15),
            ['id' => $user->id, 'hash' => $hash]
        );

        return view('legal.confirm_delete', [
            'user' => $user,
            'maskedEmail' => $maskedEmail,
            'submitUrl' => $submitUrl,
        ]);
    }

    /**
     * POST /legal/confirm-delete-account/{id}/{hash}
     *
     * Executes deletion once the signed verification link is confirmed.
     */
    public function executeConfirmedDeletion(Request $request, int $id, string $hash): RedirectResponse
    {
        if (! $request->hasValidSignature()) {
            abort(403, 'رابط تأكيد حذف الحساب منتهي الصلاحية أو غير صالح.');
        }

        $validated = $request->validate([
            'confirmation' => ['required', 'in:DELETE,حذف,حذف حسابي'],
        ], [
            'confirmation.required' => 'يرجى كتابة كلمة "حذف" لتأكيد حذف الحساب.',
            'confirmation.in' => 'حقل التأكيد غير صحيح؛ يرجى كتابة "حذف".',
        ]);

        $user = User::findOrFail($id);

        if (sha1($user->email) !== $hash) {
            abort(403, 'بيانات التحقق من البريد الإلكتروني غير متطابقة.');
        }

        $this->deletionService->executeUserDeletion(
            user: $user,
            reason: 'web_email_verified_confirmation',
            actor: 'web_verified_email'
        );

        return redirect()->route('legal.delete_account')->with(
            'success',
            'تم تأكيد هويتك وحذف حسابك وكافة بياناتك الشخصية والصور وسجل المحادثات نهائياً بنجاح. يُرجى تذكّر إلغاء أي اشتراك دوري في متجر Google Play إن وُجد.'
        );
    }
}
