<?php

namespace App\Services\Auth;

use App\Models\AppSetting;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;

class GoogleUserResolverService
{
    /**
     * Resolves an existing active member or creates a new member account strictly
     * using Google's verified stable subject identifier (`google_sub`).
     *
     * Never merges accounts solely on email address without a matching verified `google_sub`.
     *
     * @param array{sub: string, email: string, email_verified: bool, name: ?string} $claims
     * @return array{user: User, is_new_user: bool, http_status?: int}
     */
    public function resolveOrCreateMember(array $claims): array
    {
        if (!($claims['email_verified'] ?? false)) {
            throw new DomainException('يجب أن يكون البريد الإلكتروني لحساب Google مؤكداً قبل تسجيل الدخول.', 403);
        }

        $googleSub = trim((string) ($claims['sub'] ?? ''));
        $email = mb_strtolower(trim((string) ($claims['email'] ?? '')));

        if ($googleSub === '' || $email === '') {
            throw new DomainException('بيانات هوية Google غير مكتملة.', 422);
        }

        return DB::transaction(function () use ($googleSub, $email) {
            /** @var ?User $user */
            $user = User::withTrashed()
                ->where('google_sub', $googleSub)
                ->lockForUpdate()
                ->first();

            if ($user !== null) {
                if ($user->trashed() || $user->account_status === 'deleted') {
                    throw new DomainException('هذا الحساب تم حذفه ولا يمكن استخدامه مجدداً.', 403);
                }

                if ($user->account_status !== 'active') {
                    throw new DomainException('تم تعليق هذا الحساب من الإدارة. يرجى التواصل مع الدعم الفني.', 403);
                }

                $updates = [
                    'email_verified' => true,
                    'last_active_at' => now(),
                ];

                if ($user->email !== $email) {
                    $emailTakenByAnother = User::withTrashed()
                        ->where('email', $email)
                        ->where('id', '!=', $user->id)
                        ->exists();

                    if (!$emailTakenByAnother) {
                        $updates['email'] = $email;
                    }
                }

                $user->update($updates);

                return [
                    'user' => $user->fresh(),
                    'is_new_user' => false,
                ];
            }

            // Fail-closed: never silently merge onto an existing account matching only email
            $existingWithSameEmail = User::withTrashed()
                ->where('email', $email)
                ->exists();

            if ($existingWithSameEmail) {
                throw new DomainException('يوجد حساب مسجل بهذا البريد الإلكتروني بهوية Google مختلفة ولا يمكن دمجه تلقائياً.', 409);
            }

            $generalSettings = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];
            $registrationEnabled = (bool) ($generalSettings['registration_enabled'] ?? true);

            if (!$registrationEnabled) {
                throw new DomainException('تسجيل الحسابات الجديدة متوقف مؤقتاً من الإدارة.', 403);
            }

            $newUser = User::create([
                'google_sub' => $googleSub,
                'email' => $email,
                'email_verified' => true,
                'role' => 'member',
                'account_status' => 'active',
                'profile_completed' => false,
                'last_active_at' => now(),
            ]);

            return [
                'user' => $newUser,
                'is_new_user' => true,
            ];
        });
    }
}
