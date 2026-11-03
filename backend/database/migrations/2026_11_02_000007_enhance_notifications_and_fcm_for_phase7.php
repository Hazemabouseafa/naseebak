<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Enhance device_tokens with deterministic SHA-256 fingerprint & lifecycle tracking
        Schema::table('device_tokens', function (Blueprint $table) {
            if (!Schema::hasColumn('device_tokens', 'token_fingerprint')) {
                $table->string('token_fingerprint', 64)->nullable()->after('user_id');
                $table->unique('token_fingerprint', 'uq_device_tokens_fingerprint');
            }
            if (!Schema::hasColumn('device_tokens', 'app_version')) {
                $table->string('app_version', 32)->nullable()->after('device_model');
            }
            if (!Schema::hasColumn('device_tokens', 'os_version')) {
                $table->string('os_version', 32)->nullable()->after('app_version');
            }
            if (!Schema::hasColumn('device_tokens', 'invalidated_reason')) {
                $table->string('invalidated_reason', 120)->nullable()->after('is_valid');
            }
            if (!Schema::hasColumn('device_tokens', 'invalidated_at')) {
                $table->timestampTz('invalidated_at')->nullable()->after('invalidated_reason');
            }
            if (!Schema::hasColumn('device_tokens', 'last_delivery_attempt_at')) {
                $table->timestampTz('last_delivery_attempt_at')->nullable()->after('last_registered_at');
            }
        });

        // 2. Enhance notifications table with deduplication key, allowlisted routing metadata, and delivery tracking
        Schema::table('notifications', function (Blueprint $table) {
            if (!Schema::hasColumn('notifications', 'deduplication_key')) {
                $table->string('deduplication_key', 191)->nullable()->after('event_id');
                $table->unique(['user_id', 'deduplication_key'], 'uq_notifications_user_dedup_key');
            }
            if (!Schema::hasColumn('notifications', 'action_route')) {
                $table->string('action_route', 64)->nullable()->after('reference_id');
            }
            if (!Schema::hasColumn('notifications', 'routing_metadata')) {
                $table->jsonb('routing_metadata')->nullable()->after('action_route');
            }
            if (!Schema::hasColumn('notifications', 'campaign_id')) {
                $table->unsignedBigInteger('campaign_id')->nullable()->index()->after('routing_metadata');
            }
            if (!Schema::hasColumn('notifications', 'delivery_attempts')) {
                $table->unsignedSmallInteger('delivery_attempts')->default(0)->after('fcm_delivery_status');
            }
            if (!Schema::hasColumn('notifications', 'last_delivery_attempt_at')) {
                $table->timestampTz('last_delivery_attempt_at')->nullable()->after('delivery_attempts');
            }
            if (!Schema::hasColumn('notifications', 'fcm_submitted_at')) {
                $table->timestampTz('fcm_submitted_at')->nullable()->after('last_delivery_attempt_at');
            }
            if (!Schema::hasColumn('notifications', 'fcm_error_code')) {
                $table->string('fcm_error_code', 64)->nullable()->after('fcm_submitted_at');
            }
        });

        // 3. notification_preferences (Per-member notification category preferences, separate from Android OS permissions)
        if (!Schema::hasTable('notification_preferences')) {
            Schema::create('notification_preferences', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
                $table->boolean('matchmaking_requests_enabled')->default(true);
                $table->boolean('messages_enabled')->default(true);
                $table->boolean('subscriptions_enabled')->default(true);
                $table->boolean('announcements_enabled')->default(true);
                $table->timestampsTz();
            });
        }

        // 4. announcement_campaigns (Administrative notifications & campaigns managed from Filament)
        if (!Schema::hasTable('announcement_campaigns')) {
            Schema::create('announcement_campaigns', function (Blueprint $table) {
                $table->id();
                $table->foreignId('created_by_admin_id')->nullable()->constrained('administrators')->nullOnDelete();
                $table->string('title_ar', 160);
                $table->string('body_ar', 500);
                $table->string('audience', 48)->index(); // all_eligible_members, active_subscribers, expired_subscribers
                $table->string('action_route', 64)->default('notification_center');
                $table->string('status', 32)->default('draft')->index(); // draft, scheduled, queued, processing, completed, cancelled
                $table->timestampTz('scheduled_at')->nullable()->index();
                $table->timestampTz('dispatched_at')->nullable();
                $table->timestampTz('completed_at')->nullable();
                $table->unsignedInteger('eligible_recipients_count')->default(0);
                $table->unsignedInteger('queued_count')->default(0);
                $table->unsignedInteger('submitted_to_fcm_count')->default(0);
                $table->unsignedInteger('rejected_by_fcm_count')->default(0);
                $table->unsignedInteger('confirmed_read_count')->default(0);
                $table->string('idempotency_key', 120)->unique();
                $table->timestampsTz();
            });
        }

        // 5. notification_delivery_attempts (Bounded FCM HTTP v1 delivery attempt audit log)
        if (!Schema::hasTable('notification_delivery_attempts')) {
            Schema::create('notification_delivery_attempts', function (Blueprint $table) {
                $table->id();
                $table->foreignId('notification_id')->constrained('notifications')->cascadeOnDelete();
                $table->foreignId('device_token_id')->nullable()->constrained('device_tokens')->nullOnDelete();
                $table->unsignedSmallInteger('attempt_number')->default(1);
                $table->string('status', 32)->index(); // submitted_to_fcm, rejected_by_fcm, failed_transient, invalid_token_removed
                $table->unsignedSmallInteger('http_status')->nullable();
                $table->string('fcm_error_code', 64)->nullable();
                $table->string('fcm_message_id', 191)->nullable();
                $table->timestampTz('attempted_at')->useCurrent()->index();

                $table->index(['notification_id', 'attempted_at'], 'idx_notif_delivery_attempts_lookup');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_delivery_attempts');
        Schema::dropIfExists('announcement_campaigns');
        Schema::dropIfExists('notification_preferences');

        Schema::table('notifications', function (Blueprint $table) {
            if (Schema::hasColumn('notifications', 'deduplication_key')) {
                $table->dropUnique('uq_notifications_user_dedup_key');
                $table->dropColumn([
                    'deduplication_key',
                    'action_route',
                    'routing_metadata',
                    'campaign_id',
                    'delivery_attempts',
                    'last_delivery_attempt_at',
                    'fcm_submitted_at',
                    'fcm_error_code',
                ]);
            }
        });

        Schema::table('device_tokens', function (Blueprint $table) {
            if (Schema::hasColumn('device_tokens', 'token_fingerprint')) {
                $table->dropUnique('uq_device_tokens_fingerprint');
                $table->dropColumn([
                    'token_fingerprint',
                    'app_version',
                    'os_version',
                    'invalidated_reason',
                    'invalidated_at',
                    'last_delivery_attempt_at',
                ]);
            }
        });
    }
};
