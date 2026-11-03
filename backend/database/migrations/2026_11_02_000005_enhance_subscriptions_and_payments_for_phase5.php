<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Additive fields on subscriptions for complete lifecycle & renewal tracking
        Schema::table('subscriptions', function (Blueprint $table) {
            $table->string('google_play_purchase_token_hash', 64)
                ->nullable()
                ->unique()
                ->after('google_play_purchase_token')
                ->comment('SHA-256 hash of Google Play purchase token for fast indexed lookup without exposing plaintext');

            $table->timestampTz('on_hold_at')
                ->nullable()
                ->after('grace_period_ends_at');

            $table->timestampTz('expired_at')
                ->nullable()
                ->after('cancelled_at');
        });

        // 2. Additive fields on payment_transactions for minor-unit amounts, internal reference, and webhook deduplication
        Schema::table('payment_transactions', function (Blueprint $table) {
            $table->string('internal_reference', 64)
                ->nullable()
                ->unique()
                ->after('idempotency_key')
                ->comment('Server-generated immutable order reference (e.g., NSB-ORD-...)');

            $table->unsignedBigInteger('amount_minor')
                ->nullable()
                ->after('amount')
                ->comment('Fixed amount snapshot in integer minor currency units (piastres/cents)');

            $table->timestampTz('paid_at')
                ->nullable()
                ->after('verified_at');
        });

        // 3. Provider Webhook Events table for strict idempotency & RTDN / Webhook replay protection
        Schema::create('payment_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 32)->index(); // google_play, paymob, sha7nawy
            $table->string('provider_event_id', 191);
            $table->string('event_type', 96)->nullable();
            $table->foreignId('payment_transaction_id')->nullable()->constrained('payment_transactions')->nullOnDelete();
            $table->foreignId('subscription_id')->nullable()->constrained('subscriptions')->nullOnDelete();
            $table->string('processing_status', 32)->default('processed')->index(); // processed, ignored_duplicate, failed
            $table->jsonb('sanitized_payload')->nullable();
            $table->timestampTz('processed_at')->useCurrent();
            $table->timestampsTz();

            $table->unique(['provider', 'provider_event_id'], 'uq_provider_webhook_event');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_webhook_events');

        Schema::table('payment_transactions', function (Blueprint $table) {
            $table->dropColumn(['paid_at', 'amount_minor', 'internal_reference']);
        });

        Schema::table('subscriptions', function (Blueprint $table) {
            $table->dropColumn(['expired_at', 'on_hold_at', 'google_play_purchase_token_hash']);
        });
    }
};
