<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subscription_plans', function (Blueprint $table) {
            $table->string('google_play_product_id', 120)->nullable()->change();
            if (!Schema::hasColumn('subscription_plans', 'duration_months')) {
                $table->unsignedSmallInteger('duration_months')->default(1)->after('duration_days');
            }
            if (!Schema::hasColumn('subscription_plans', 'price_minor')) {
                $table->unsignedBigInteger('price_minor')->default(0)->after('web_price_amount');
            }
            if (!Schema::hasColumn('subscription_plans', 'sort_order')) {
                $table->unsignedSmallInteger('sort_order')->default(10)->after('is_active');
            }
        });

        Schema::table('payment_transactions', function (Blueprint $table) {
            if (!Schema::hasColumn('payment_transactions', 'cancelled_at')) {
                $table->timestamp('cancelled_at')->nullable()->after('failed_at');
            }
            if (!Schema::hasColumn('payment_transactions', 'expires_at')) {
                $table->timestamp('expires_at')->nullable()->after('cancelled_at');
            }
        });

        // Backfill price_minor, duration_months, and sort_order for existing plans without float math.
        $existingPlans = DB::table('subscription_plans')->get();
        foreach ($existingPlans as $plan) {
            $minor = $this->decimalToMinorUnits((string) $plan->web_price_amount);
            $durationMonths = $plan->code === 'quarterly_membership'
                ? 3
                : max(1, (int) round(((int) $plan->duration_days) / 30));
            $sortOrder = match ($plan->code) {
                'monthly_membership' => 1,
                'quarterly_membership' => 2,
                default => 10,
            };

            DB::table('subscription_plans')
                ->where('id', $plan->id)
                ->update([
                    'price_minor' => $minor,
                    'duration_months' => $durationMonths,
                    'sort_order' => $sortOrder,
                ]);
        }

        // Ensure quarterly_membership exists alongside monthly_membership for Phase 18 website plans.
        $hasQuarterly = DB::table('subscription_plans')->where('code', 'quarterly_membership')->exists();
        if (!$hasQuarterly) {
            $now = now();
            DB::table('subscription_plans')->insert([
                'code' => 'quarterly_membership',
                'name_ar' => 'الباقة الربع سنوية',
                'description_ar' => 'اشتراك كامل المزايا لمدة 3 أشهر ميلادية عبر الموقع الإلكتروني مع التفعيل التلقائي على التطبيق.',
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
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('payment_transactions', function (Blueprint $table) {
            if (Schema::hasColumn('payment_transactions', 'expires_at')) {
                $table->dropColumn('expires_at');
            }
            if (Schema::hasColumn('payment_transactions', 'cancelled_at')) {
                $table->dropColumn('cancelled_at');
            }
        });

        Schema::table('subscription_plans', function (Blueprint $table) {
            if (Schema::hasColumn('subscription_plans', 'sort_order')) {
                $table->dropColumn('sort_order');
            }
            if (Schema::hasColumn('subscription_plans', 'price_minor')) {
                $table->dropColumn('price_minor');
            }
            if (Schema::hasColumn('subscription_plans', 'duration_months')) {
                $table->dropColumn('duration_months');
            }
        });
    }

    private function decimalToMinorUnits(string $amount): int
    {
        $clean = trim($amount);
        if (preg_match('/^\d+(?:\.\d{1,2})?$/', $clean) !== 1) {
            return 0;
        }

        $parts = explode('.', $clean, 2);
        $major = (int) $parts[0];
        $minor = (int) str_pad($parts[1] ?? '0', 2, '0', STR_PAD_RIGHT);

        return ($major * 100) + $minor;
    }
};
