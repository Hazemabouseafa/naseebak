<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Enhance matchmaking_requests with canonical user pair columns and cancelled_at
        Schema::table('matchmaking_requests', function (Blueprint $table) {
            if (!Schema::hasColumn('matchmaking_requests', 'user_low_id')) {
                $table->unsignedBigInteger('user_low_id')->nullable()->after('recipient_id');
            }
            if (!Schema::hasColumn('matchmaking_requests', 'user_high_id')) {
                $table->unsignedBigInteger('user_high_id')->nullable()->after('user_low_id');
            }
            if (!Schema::hasColumn('matchmaking_requests', 'cancelled_at')) {
                $table->timestampTz('cancelled_at')->nullable()->after('responded_at');
            }

            $table->index(['user_low_id', 'user_high_id', 'status'], 'idx_matchmaking_canonical_pair_status');
        });

        // Backfill canonical pair IDs for any existing rows
        DB::table('matchmaking_requests')
            ->whereNull('user_low_id')
            ->orderBy('id')
            ->each(function ($row) {
                $low = min((int) $row->sender_id, (int) $row->recipient_id);
                $high = max((int) $row->sender_id, (int) $row->recipient_id);
                DB::table('matchmaking_requests')
                    ->where('id', $row->id)
                    ->update([
                        'user_low_id' => $low,
                        'user_high_id' => $high,
                    ]);
            });

        // 2. Enhance conversations with canonical participant pair uniqueness and last_message_id
        Schema::table('conversations', function (Blueprint $table) {
            if (!Schema::hasColumn('conversations', 'user_one_id')) {
                $table->foreignId('user_one_id')->nullable()->after('matchmaking_request_id')->constrained('users')->cascadeOnDelete();
            }
            if (!Schema::hasColumn('conversations', 'user_two_id')) {
                $table->foreignId('user_two_id')->nullable()->after('user_one_id')->constrained('users')->cascadeOnDelete();
            }
            if (!Schema::hasColumn('conversations', 'last_message_id')) {
                $table->unsignedBigInteger('last_message_id')->nullable()->after('last_message_at')->index();
            }

            $table->unique(['user_one_id', 'user_two_id'], 'uq_conversations_canonical_user_pair');
            $table->index(['status', 'last_message_at'], 'idx_conversations_status_activity');
        });

        // 3. Enhance conversation_participants with cursor-based read & delivery markers
        Schema::table('conversation_participants', function (Blueprint $table) {
            if (!Schema::hasColumn('conversation_participants', 'last_read_message_id')) {
                $table->unsignedBigInteger('last_read_message_id')->nullable()->after('unread_count')->index();
            }
            if (!Schema::hasColumn('conversation_participants', 'last_delivered_message_id')) {
                $table->unsignedBigInteger('last_delivered_message_id')->nullable()->after('last_read_at');
            }
            if (!Schema::hasColumn('conversation_participants', 'last_delivered_at')) {
                $table->timestampTz('last_delivered_at')->nullable()->after('last_delivered_message_id');
            }
        });

        // 4. Enhance messages with client_message_id idempotency key, delivered_at, and cursor index
        Schema::table('messages', function (Blueprint $table) {
            if (!Schema::hasColumn('messages', 'client_message_id')) {
                $table->string('client_message_id', 100)->nullable()->after('sender_id');
            }
            if (!Schema::hasColumn('messages', 'delivered_at')) {
                $table->timestampTz('delivered_at')->nullable()->after('is_read');
            }

            $table->unique(
                ['conversation_id', 'sender_id', 'client_message_id'],
                'uq_messages_conv_sender_client_id'
            );
            $table->index(['conversation_id', 'id'], 'idx_messages_conversation_id_cursor');
        });

        // 5. Enhance user_reports with optional message_id reference for scoped chat reporting
        Schema::table('user_reports', function (Blueprint $table) {
            if (!Schema::hasColumn('user_reports', 'message_id')) {
                $table->foreignId('message_id')
                    ->nullable()
                    ->after('conversation_id')
                    ->constrained('messages')
                    ->nullOnDelete();
            }
        });
    }

    public function down(): void
    {
        Schema::table('user_reports', function (Blueprint $table) {
            if (Schema::hasColumn('user_reports', 'message_id')) {
                $table->dropConstrainedForeignId('message_id');
            }
        });

        Schema::table('messages', function (Blueprint $table) {
            $table->dropUnique('uq_messages_conv_sender_client_id');
            $table->dropIndex('idx_messages_conversation_id_cursor');
            $table->dropColumn(['client_message_id', 'delivered_at']);
        });

        Schema::table('conversation_participants', function (Blueprint $table) {
            $table->dropColumn(['last_read_message_id', 'last_delivered_message_id', 'last_delivered_at']);
        });

        Schema::table('conversations', function (Blueprint $table) {
            $table->dropUnique('uq_conversations_canonical_user_pair');
            $table->dropIndex('idx_conversations_status_activity');
            $table->dropConstrainedForeignId('user_one_id');
            $table->dropConstrainedForeignId('user_two_id');
            $table->dropColumn('last_message_id');
        });

        Schema::table('matchmaking_requests', function (Blueprint $table) {
            $table->dropIndex('idx_matchmaking_canonical_pair_status');
            $table->dropColumn(['user_low_id', 'user_high_id', 'cancelled_at']);
        });
    }
};
