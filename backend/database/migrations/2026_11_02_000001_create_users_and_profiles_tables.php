<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. users (Private account & authentication state - NO passwords, Google OAuth only)
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('google_sub', 128)->unique()->comment('Stable Google OpenID Connect subject identifier');
            $table->string('email')->unique();
            $table->boolean('email_verified')->default(true);
            $table->string('role', 32)->default('member')->index(); // member, moderator, super_admin
            $table->string('account_status', 32)->default('active')->index(); // active, suspended, pending_deletion, deleted
            $table->text('suspension_reason')->nullable();
            $table->timestampTz('suspended_at')->nullable();
            $table->boolean('profile_completed')->default(false)->index();
            $table->string('admin_password_hash')->nullable()->comment('Used exclusively for Filament Admin Dashboard authentication with MFA');
            $table->text('mfa_secret')->nullable();
            $table->timestampTz('last_active_at')->nullable()->index();
            $table->timestampTz('deletion_requested_at')->nullable();
            $table->timestampsTz();
            $table->softDeletesTz();
        });

        // 2. user_profiles (Public / Matchmaking profile data separated from private account credentials)
        Schema::create('user_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('full_name', 120);
            $table->string('gender', 16)->index(); // male, female
            $table->date('date_of_birth')->index();
            $table->unsignedSmallInteger('age_years')->index();
            $table->string('zodiac_sign', 32)->index();
            $table->string('marital_status', 32)->index(); // single, divorced, widowed
            $table->boolean('previously_married')->default(false);
            $table->boolean('has_children')->default(false);
            $table->unsignedTinyInteger('children_count')->default(0);
            $table->string('education_level', 64)->index(); // high_school, diploma, bachelor, master, doctorate, other
            $table->string('occupation', 120)->index();
            $table->unsignedSmallInteger('height_cm')->index();
            $table->string('smoking_status', 32)->index(); // non_smoker, smoker, occasional
            $table->string('home_ownership', 32)->default('not_specified'); // owned, rented, family_home, not_specified
            $table->jsonb('hobbies')->nullable();
            $table->string('nationality', 64)->index();
            $table->string('country_of_residence', 64)->index();
            $table->string('region', 80)->index();
            $table->text('bio')->nullable();
            $table->boolean('is_visible')->default(true)->index();
            $table->string('photo_privacy', 32)->default('public')-> comment('public, subscribers_only, accepted_matches_only');
            $table->string('moderation_status', 32)->default('pending')->index(); // pending, approved, rejected
            $table->text('moderation_notes')->nullable();
            $table->foreignId('moderated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampTz('moderated_at')->nullable();
            $table->timestampsTz();

            // Composite index for high-frequency member discovery & search queries
            $table->index(
                ['moderation_status', 'is_visible', 'gender', 'age_years', 'marital_status'],
                'idx_profiles_discovery_search'
            );
            $table->index(['country_of_residence', 'region'], 'idx_profiles_location');
        });

        // 3. user_photos
        Schema::create('user_photos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('storage_disk', 32)->default('private');
            $table->string('file_path');
            $table->string('mime_type', 64)->default('image/jpeg');
            $table->unsignedInteger('file_size_bytes');
            $table->boolean('is_primary')->default(false)->index();
            $table->string('moderation_status', 32)->default('pending')->index(); // pending, approved, rejected
            $table->timestampsTz();

            $table->index(['user_id', 'is_primary']);
        });

        // 4. user_preferences (Saved search filters & notification preferences)
        Schema::create('user_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('preferred_gender', 16)->nullable();
            $table->unsignedSmallInteger('min_age')->default(18);
            $table->unsignedSmallInteger('max_age')->default(60);
            $table->jsonb('marital_statuses')->nullable();
            $table->string('education_level', 64)->nullable();
            $table->string('smoking_status', 32)->nullable();
            $table->string('occupation', 120)->nullable();
            $table->string('nationality', 64)->nullable();
            $table->string('country_of_residence', 64)->nullable();
            $table->string('region', 80)->nullable();
            // Notification preferences
            $table->boolean('notify_new_requests')->default(true);
            $table->boolean('notify_accepted_requests')->default(true);
            $table->boolean('notify_new_messages')->default(true);
            $table->boolean('notify_subscription_alerts')->default(true);
            $table->boolean('notify_announcements')->default(true);
            $table->timestampsTz();
        });

        // 5. Laravel Sanctum Personal Access Tokens & Sessions
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->morphs('tokenable');
            $table->string('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampTz('expires_at')->nullable();
            $table->timestampsTz();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('personal_access_tokens');
        Schema::dropIfExists('user_preferences');
        Schema::dropIfExists('user_photos');
        Schema::dropIfExists('user_profiles');
        Schema::dropIfExists('users');
    }
};
