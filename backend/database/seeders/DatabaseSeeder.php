<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Seed initial payment settings (single active_web_payment_gateway configuration)
        DB::table('payment_settings')->updateOrInsert(
            ['id' => 1],
            [
                'active_web_payment_gateway' => 'paymob',
                'web_monthly_price' => 250.00,
                'web_currency' => 'EGP',
                'subscription_duration_days' => 30,
                'paymob_configured' => false,
                'sha7nawy_configured' => false,
                'sha7nawy_integration_status' => 'pending_credentials',
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        // 2. Seed monthly subscription plan
        DB::table('subscription_plans')->updateOrInsert(
            ['code' => 'monthly_membership'],
            [
                'name_ar' => 'العضوية الشهرية — نصيبك',
                'description_ar' => 'تتيح لك العضوية الشهرية إرسال طلبات التعارف وبدء المحادثات الخاصة بعد قبول الطرف الآخر.',
                'duration_days' => 30,
                'google_play_product_id' => config('naseebak.google_play.monthly_subscription_id', 'naseebak_monthly_membership'),
                'web_price_amount' => 250.00,
                'web_price_currency' => 'EGP',
                'is_active' => true,
                'features_ar' => json_encode([
                    'البحث بجميع المعايير المتاحة',
                    'إرسال طلبات التعارف للأعضاء',
                    'المحادثة الخاصة بعد موافقة الطرف الآخر',
                    'إدارة الاشتراك بسهولة وأمان',
                ], JSON_UNESCAPED_UNICODE),
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

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
    }
}
