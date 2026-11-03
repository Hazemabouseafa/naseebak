<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 5. subscription_plans
        Schema::create('subscription_plans', function (Blueprint $table) {
            $table->id();
            $table->string('code', 64)->unique(); // e.g. monthly_membership
            $table->string('name_ar', 120);
            $table->text('description_ar')->nullable();
            $table->unsignedSmallInteger('duration_days')->default(30);
            $table->string('google_play_product_id', 128)->unique();
            $table->decimal('web_price_amount', 10, 2)->comment('Web channel price managed by Admin in Filament');
            $table->string('web_price_currency', 8)->default('EGP');
            $table->boolean('is_active')->default(true)->index();
            $table->jsonb('features_ar')->nullable();
            $table->timestampsTz();
        });

        // 6. subscriptions (Server-side entitlement source of truth)
        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('subscription_plan_id')->constrained('subscription_plans')->restrictOnDelete();
            $table->string('channel', 32)->index(); // google_play, paymob, sha7nawy
            $table->string('status', 32)->index(); // active, pending_payment, expired, cancelled, grace_period, refunded, revoked
            $table->string('external_subscription_id', 255)->nullable()->index();
            $table->text('google_play_purchase_token')->nullable()->unique();
            $table->boolean('auto_renewing')->default(false);
            $table->timestampTz('starts_at')->nullable()->index();
            $table->timestampTz('ends_at')->nullable()->index();
            $table->timestampTz('grace_period_ends_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampTz('last_verified_at')->nullable();
            $table->jsonb('verification_metadata')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'status', 'ends_at'], 'idx_subscriptions_entitlement_lookup');
        });

        // 7. payment_transactions (Idempotent payment & webhook verification log)
        Schema::create('payment_transactions', function (Blueprint $table) {
            $table->id();
            $table->uuid('idempotency_key')->unique();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('subscription_id')->nullable()->constrained('subscriptions')->nullOnDelete();
            $table->foreignId('subscription_plan_id')->constrained('subscription_plans')->restrictOnDelete();
            $table->string('gateway', 32)->index(); // google_play, paymob, sha7nawy
            $table->string('gateway_transaction_id', 191)->nullable()->index();
            $table->string('gateway_order_id', 191)->nullable()->index();
            $table->decimal('amount', 10, 2)->nullable()->comment('Nullable for Google Play if localized price is fetched dynamically');
            $table->string('currency', 8)->nullable();
            $table->string('status', 32)->default('pending')->index(); // pending, succeeded, failed, refunded, disputed
            $table->boolean('signature_verified')->default(false);
            $table->timestampTz('verified_at')->nullable();
            $table->jsonb('gateway_response_summary')->nullable();
            $table->timestampsTz();

            $table->unique(['gateway', 'gateway_transaction_id'], 'uq_gateway_transaction');
        });

        // 8. payment_settings (Single atomic active_web_payment_gateway configuration)
        Schema::create('payment_settings', function (Blueprint $table) {
            $table->id();
            $table->string('active_web_payment_gateway', 32)->default('paymob'); // Allowed: paymob | sha7nawy
            $table->decimal('web_monthly_price', 10, 2)->default(250.00);
            $table->string('web_currency', 8)->default('EGP');
            $table->unsignedSmallInteger('subscription_duration_days')->default(30);
            $table->boolean('paymob_configured')->default(false);
            $table->boolean('sha7nawy_configured')->default(false);
            $table->string('sha7nawy_integration_status', 32)->default('pending_credentials'); // pending_credentials, ready, disabled
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampsTz();
        });

        // PostgreSQL CHECK constraint to guarantee active_web_payment_gateway is strictly 'paymob' or 'sha7nawy'
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE payment_settings ADD CONSTRAINT chk_active_web_payment_gateway CHECK (active_web_payment_gateway IN ('paymob', 'sha7nawy'))");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_settings');
        Schema::dropIfExists('payment_transactions');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('subscription_plans');
    }
};
