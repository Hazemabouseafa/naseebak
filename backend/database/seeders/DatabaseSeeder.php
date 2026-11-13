<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Seed initial payment settings if not already present (preserve existing admin configuration)
        if (!DB::table('payment_settings')->where('id', 1)->exists()) {
            DB::table('payment_settings')->insert([
                'id' => 1,
                'active_web_payment_gateway' => 'paymob',
                'web_monthly_price' => 250.00,
                'web_currency' => 'EGP',
                'subscription_duration_days' => 30,
                'paymob_configured' => false,
                'sha7nawy_configured' => false,
                'sha7nawy_integration_status' => 'pending_credentials',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        // 2. Seed monthly & quarterly subscription plans if not already present (preserve admin pricing overrides)
        if (!DB::table('subscription_plans')->where('code', 'monthly_membership')->exists()) {
            DB::table('subscription_plans')->insert([
                'code' => 'monthly_membership',
                'name_ar' => 'الباقة الشهرية',
                'description_ar' => 'اشتراك كامل المزايا لمدة شهر ميلادي واحد عبر الموقع الإلكتروني مع التفعيل التلقائي على التطبيق.',
                'duration_days' => 30,
                'duration_months' => 1,
                'google_play_product_id' => config('naseebak.google_play.monthly_subscription_id', 'naseebak_monthly_membership'),
                'web_price_amount' => '250.00',
                'price_minor' => 25000,
                'web_price_currency' => 'EGP',
                'is_active' => true,
                'sort_order' => 1,
                'features_ar' => json_encode([
                    'البحث المتقدم بجميع المعايير المتاحة',
                    'إرسال طلبات التعارف للأعضاء',
                    'المحادثة الخاصة بعد موافقة الطرف الآخر',
                    'إدارة الاشتراك بسهولة وأمان',
                ], JSON_UNESCAPED_UNICODE),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        if (!DB::table('subscription_plans')->where('code', 'quarterly_membership')->exists()) {
            DB::table('subscription_plans')->insert([
                'code' => 'quarterly_membership',
                'name_ar' => 'الباقة الربع سنوية',
                'description_ar' => 'اشتراك كامل المزايا لمدة 3 أشهر ميلادية عبر الموقع الإلكتروني مع توفير واضح مقارنة بالباقة الشهرية.',
                'duration_days' => 90,
                'duration_months' => 3,
                'google_play_product_id' => null,
                'web_price_amount' => '600.00',
                'price_minor' => 60000,
                'web_price_currency' => 'EGP',
                'is_active' => true,
                'sort_order' => 2,
                'features_ar' => json_encode([
                    'تواصل كامل بعد الموافقة على طلبات التعارف لمدة 3 أشهر',
                    'استخدام البحث المتقدم ومعايير التوافق بدون قيود العضوية المجانية',
                    'ظهور أولوية وشارة العضو المشترك خلال فترة التفعيل',
                    'توفير واضح مقارنة بالتجديد الشهري المتكرر',
                ], JSON_UNESCAPED_UNICODE),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        // 3. Seed core application settings
        $defaultSettings = [
            [
                'setting_key' => 'minimum_registration_age',
                'setting_value' => json_encode(['years' => 18]),
                'description_ar' => 'الحد الأدنى لسن التسجيل في تطبيق نصيبك (للبالغين فقط 18+)',
            ],
            [
                'setting_key' => 'require_profile_moderation',
                'setting_value' => json_encode(['enabled' => true]),
                'description_ar' => 'مراجعة الملفات الشخصية الجديدة قبل ظهورها في نتائج البحث العام',
            ],
            [
                'setting_key' => 'privacy_and_terms_urls',
                'setting_value' => json_encode([
                    'privacy_policy_url' => url('/legal/privacy-policy'),
                    'terms_of_service_url' => url('/legal/terms-of-service'),
                    'child_safety_url' => url('/legal/child-safety'),
                    'account_deletion_url' => url('/legal/delete-account'),
                ]),
                'description_ar' => 'روابط سياسة الخصوصية وشروط الاستخدام وحذف الحساب عبر الويب',
            ],
        ];

        foreach ($defaultSettings as $setting) {
            DB::table('app_settings')->updateOrInsert(
                ['setting_key' => $setting['setting_key']],
                array_merge($setting, ['created_at' => now(), 'updated_at' => now()])
            );
        }

        // 4. Seed initial super administrator
        \App\Models\Administrator::updateOrCreate(
            ['email' => env('INITIAL_SUPER_ADMIN_EMAIL', 'admin@hazem.my')],
            [
                'name' => env('INITIAL_SUPER_ADMIN_NAME', 'Hazem'),
                'password' => env('INITIAL_SUPER_ADMIN_PASSWORD', 'Naseebak@2026Admin!'),
                'role' => \App\Models\Administrator::ROLE_SUPER_ADMIN,
                'is_active' => true,
                'mfa_enabled' => false,
            ]
        );
    }
}
