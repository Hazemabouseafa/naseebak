<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 9. matchmaking_requests
        Schema::create('matchmaking_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('recipient_id')->constrained('users')->cascadeOnDelete();
            $table->string('status', 32)->default('pending')->index(); // pending, accepted, rejected, cancelled
            $table->timestampTz('responded_at')->nullable();
            $table->timestampsTz();

            // Prevent duplicate requests between the same sender and recipient
            $table->unique(['sender_id', 'recipient_id'], 'uq_matchmaking_sender_recipient');
            $table->index(['recipient_id', 'status']);
            $table->index(['sender_id', 'status']);
        });

        // 10. conversations
        Schema::create('conversations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('matchmaking_request_id')->unique()->constrained('matchmaking_requests')->cascadeOnDelete();
            $table->string('status', 32)->default('active')->index(); // active, blocked, closed
            $table->timestampTz('last_message_at')->nullable()->index();
            $table->timestampsTz();
        });

        // 11. conversation_participants
        Schema::create('conversation_participants', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('conversations')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedInteger('unread_count')->default(0);
            $table->timestampTz('last_read_at')->nullable();
            $table->timestampsTz();

            $table->unique(['conversation_id', 'user_id'], 'uq_conversation_participant');
            $table->index(['user_id', 'unread_count']);
        });

        // 12. messages (Text messages only - stored exclusively in PostgreSQL, NEVER sent in FCM payloads)
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('conversations')->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->text('body');
            $table->boolean('is_read')->default(false)->index();
            $table->timestampTz('read_at')->nullable();
            $table->timestampsTz();

            $table->index(['conversation_id', 'created_at'], 'idx_messages_conversation_timeline');
        });

        // 13. device_tokens (FCM Push Notification device tokens)
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('fcm_token', 512)->unique();
            $table->string('device_platform', 32)->default('android');
            $table->string('device_model', 120)->nullable();
            $table->boolean('is_valid')->default(true)->index();
            $table->timestampTz('last_registered_at')->useCurrent();
            $table->timestampsTz();

            $table->index(['user_id', 'is_valid']);
        });

        // 14. notifications (PostgreSQL notification records for generic FCM events & in-app center)
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->uuid('event_id')->unique();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('event_type', 64)->index();
            // Allowed event_types:
            // new_matchmaking_request, accepted_matchmaking_request, new_private_message,
            // subscription_activated, subscription_expiring_soon, subscription_expired, admin_announcement
            $table->string('title_ar', 160);
            $table->string('body_ar', 500);
            $table->string('reference_type', 64)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->boolean('is_read')->default(false)->index();
            $table->timestampTz('read_at')->nullable();
            $table->string('fcm_delivery_status', 32)->default('queued'); // queued, sent, failed, skipped_foreground, disabled_by_preference
            $table->timestampsTz();

            $table->index(['user_id', 'is_read', 'created_at']);
        });

        // 15. favorites
        Schema::create('favorites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('favorited_user_id')->constrained('users')->cascadeOnDelete();
            $table->timestampsTz();

            $table->unique(['user_id', 'favorited_user_id'], 'uq_user_favorite');
        });

        // 16. blocked_users
        Schema::create('blocked_users', function (Blueprint $table) {
            $table->id();
            $table->foreignId('blocker_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('blocked_id')->constrained('users')->cascadeOnDelete();
            $table->string('reason', 255)->nullable();
            $table->timestampsTz();

            $table->unique(['blocker_id', 'blocked_id'], 'uq_blocker_blocked');
            $table->index('blocked_id');
        });

        // 17. user_reports
        Schema::create('user_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reported_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('conversation_id')->nullable()->constrained('conversations')->nullOnDelete();
            $table->string('reason_category', 64)->index(); // inappropriate_behavior, fake_profile, harassment, scam_attempt, other
            $table->text('details');
            $table->string('status', 32)->default('pending')->index(); // pending, under_review, resolved, dismissed
            $table->text('resolution_notes')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampTz('reviewed_at')->nullable();
            $table->timestampsTz();
        });

        // 18. app_settings
        Schema::create('app_settings', function (Blueprint $table) {
            $table->id();
            $table->string('setting_key', 120)->unique();
            $table->jsonb('setting_value');
            $table->string('description_ar', 255)->nullable();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampsTz();
        });

        // 19. admin_audit_logs (Immutable audit trail for gateway switches, profile moderation, suspensions, and report reviews)
        Schema::create('admin_audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_user_id')->constrained('users')->restrictOnDelete();
            $table->string('action', 120)->index(); // e.g. payment_gateway.switched, profile.approved, user.suspended, report.reviewed
            $table->string('target_type', 120)->nullable();
            $table->unsignedBigInteger('target_id')->nullable();
            $table->jsonb('previous_values')->nullable();
            $table->jsonb('new_values')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->text('justification')->nullable();
            $table->timestampTz('created_at')->useCurrent()->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_audit_logs');
        Schema::dropIfExists('app_settings');
        Schema::dropIfExists('user_reports');
        Schema::dropIfExists('blocked_users');
        Schema::dropIfExists('favorites');
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('device_tokens');
        Schema::dropIfExists('messages');
        Schema::dropIfExists('conversation_participants');
        Schema::dropIfExists('conversations');
        Schema::dropIfExists('matchmaking_requests');
    }
};
