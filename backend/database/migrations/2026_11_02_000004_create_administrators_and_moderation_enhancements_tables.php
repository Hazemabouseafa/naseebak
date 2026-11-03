<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Dedicated Administrators table (separate authentication boundary from Google Sign-In members)
        Schema::create('administrators', function (Blueprint $table) {
            $table->id();
            $table->string('name', 120);
            $table->string('email')->unique();
            $table->string('password');
            $table->string('role', 32)->default('moderator')->index(); // super_admin, moderator
            $table->boolean('is_active')->default(true)->index();
            $table->boolean('mfa_enabled')->default(false);
            $table->text('mfa_secret')->nullable();
            $table->jsonb('mfa_recovery_codes')->nullable();
            $table->timestampTz('mfa_verified_at')->nullable();
            $table->timestampTz('last_login_at')->nullable();
            $table->string('last_login_ip', 45)->nullable();
            $table->string('suspension_reason', 255)->nullable();
            $table->rememberToken();
            $table->timestampsTz();
        });

        // 2. Moderation Histories table (immutable history of profile & photo moderation decisions)
        Schema::create('moderation_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('administrator_id')->nullable()->constrained('administrators')->nullOnDelete();
            $table->string('target_type', 120)->index(); // App\Models\UserProfile, App\Models\UserPhoto, App\Models\UserReport
            $table->unsignedBigInteger('target_id')->index();
            $table->string('previous_status', 32)->nullable();
            $table->string('new_status', 32)->index();
            $table->text('reason')->nullable();
            $table->timestampTz('created_at')->useCurrent()->index();

            $table->index(['target_type', 'target_id'], 'idx_moderation_histories_target');
        });

        // 3. Additive moderation columns on user_profiles
        Schema::table('user_profiles', function (Blueprint $table) {
            $table->foreignId('moderated_by_admin_id')
                ->nullable()
                ->after('moderated_by')
                ->constrained('administrators')
                ->nullOnDelete();
        });

        // 4. Additive moderation columns on user_photos
        Schema::table('user_photos', function (Blueprint $table) {
            $table->text('moderation_notes')->nullable()->after('moderation_status');
            $table->foreignId('moderated_by_admin_id')
                ->nullable()
                ->after('moderation_notes')
                ->constrained('administrators')
                ->nullOnDelete();
            $table->timestampTz('moderated_at')->nullable()->after('moderated_by_admin_id');
        });

        // 5. Additive moderation columns on user_reports
        Schema::table('user_reports', function (Blueprint $table) {
            $table->foreignId('assigned_moderator_id')
                ->nullable()
                ->after('status')
                ->constrained('administrators')
                ->nullOnDelete();
            $table->foreignId('reviewed_by_admin_id')
                ->nullable()
                ->after('reviewed_by')
                ->constrained('administrators')
                ->nullOnDelete();
        });

        // 6. Additive administrator reference on payment_settings and app_settings
        Schema::table('payment_settings', function (Blueprint $table) {
            $table->foreignId('updated_by_admin_id')
                ->nullable()
                ->after('updated_by')
                ->constrained('administrators')
                ->nullOnDelete();
        });

        Schema::table('app_settings', function (Blueprint $table) {
            $table->foreignId('updated_by_admin_id')
                ->nullable()
                ->after('updated_by')
                ->constrained('administrators')
                ->nullOnDelete();
        });

        // 7. Update admin_audit_logs to reference administrators while preserving existing records
        Schema::table('admin_audit_logs', function (Blueprint $table) {
            $table->unsignedBigInteger('admin_user_id')->nullable()->change();
            $table->foreignId('administrator_id')
                ->nullable()
                ->after('id')
                ->constrained('administrators')
                ->restrictOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('admin_audit_logs', function (Blueprint $table) {
            $table->dropConstrainedForeignId('administrator_id');
        });

        Schema::table('app_settings', function (Blueprint $table) {
            $table->dropConstrainedForeignId('updated_by_admin_id');
        });

        Schema::table('payment_settings', function (Blueprint $table) {
            $table->dropConstrainedForeignId('updated_by_admin_id');
        });

        Schema::table('user_reports', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reviewed_by_admin_id');
            $table->dropConstrainedForeignId('assigned_moderator_id');
        });

        Schema::table('user_photos', function (Blueprint $table) {
            $table->dropColumn('moderated_at');
            $table->dropConstrainedForeignId('moderated_by_admin_id');
            $table->dropColumn('moderation_notes');
        });

        Schema::table('user_profiles', function (Blueprint $table) {
            $table->dropConstrainedForeignId('moderated_by_admin_id');
        });

        Schema::dropIfExists('moderation_histories');
        Schema::dropIfExists('administrators');
    }
};
