<?php

namespace App\Console\Commands;

use App\Models\AdminAuditLog;
use App\Models\Administrator;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

class ProvisionSuperAdminCommand extends Command
{
    protected $signature = 'naseebak:make-super-admin
                            {--name= : الاسم الكامل للمدير العام}
                            {--email= : البريد الإلكتروني للمدير العام}
                            {--password= : كلمة مرور المدير العام (12 حرفاً على الأقل وتتضمن حروف كبيرة وصغيرة وأرقام ورموز)}';

    protected $description = 'إنشاء حساب المدير العام الأول (Super Administrator) للوحة تحكم نصيبك بشكل آمن عبر الطرفية دون كلمات مرور ثابتة في الكود';

    public function handle(): int
    {
        $this->info('=== نصيبك (Naseebak) — إعداد حساب المدير العام (Super Administrator) ===');

        $name = $this->option('name') ?: $this->ask('أدخل الاسم الكامل للمدير العام');
        $email = $this->option('email') ?: $this->ask('أدخل البريد الإلكتروني للمدير العام');
        $password = $this->option('password') ?: $this->secret('أدخل كلمة مرور قوية (12 حرفاً على الأقل وتحتوي على حروف كبيرة وصغيرة وأرقام ورموز)');
        $passwordConfirmation = $this->option('password') ?: $this->secret('أعد إدخال كلمة المرور للتأكيد');

        $validator = Validator::make([
            'name' => $name,
            'email' => $email,
            'password' => $password,
            'password_confirmation' => $passwordConfirmation,
        ], [
            'name' => ['required', 'string', 'min:3', 'max:120'],
            'email' => ['required', 'email:rfc', 'max:191', 'unique:administrators,email'],
            'password' => [
                'required',
                'confirmed',
                Password::min(12)->mixedCase()->numbers()->symbols(),
            ],
        ]);

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }
            return self::FAILURE;
        }

        $admin = Administrator::create([
            'name' => trim($name),
            'email' => strtolower(trim($email)),
            'password' => Hash::make($password),
            'role' => Administrator::ROLE_SUPER_ADMIN,
            'is_active' => true,
            'mfa_enabled' => false,
        ]);

        AdminAuditLog::create([
            'administrator_id' => $admin->id,
            'action' => 'administrator.provisioned_cli',
            'target_type' => Administrator::class,
            'target_id' => $admin->id,
            'previous_values' => null,
            'new_values' => [
                'name' => $admin->name,
                'email' => $admin->email,
                'role' => $admin->role,
            ],
            'ip_address' => '127.0.0.1',
            'justification' => 'إنشاء حساب المدير العام عبر أمر Artisan CLI الآمن',
            'created_at' => now(),
        ]);

        $this->info("تم إنشاء حساب المدير العام بنجاح: {$admin->email} (المعرف #{$admin->id})");
        return self::SUCCESS;
    }
}
