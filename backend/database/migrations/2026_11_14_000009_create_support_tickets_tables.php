<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_tickets', function (Blueprint $table) {
            $table->id();
            $table->string('ticket_number', 32)->unique();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type', 32); // inquiry | complaint
            $table->string('category', 64);
            $table->string('subject', 160);
            $table->text('message');
            $table->string('status', 32)->default('open'); // open | in_progress | answered | closed
            $table->foreignId('assigned_admin_id')->nullable()->constrained('administrators')->nullOnDelete();
            $table->foreignId('responded_by_admin_id')->nullable()->constrained('administrators')->nullOnDelete();
            $table->text('admin_reply')->nullable();
            $table->timestampTz('responded_at')->nullable();
            $table->timestampTz('last_activity_at')->useCurrent();
            $table->string('last_sender_type', 24)->default('member'); // member | admin
            $table->timestampTz('closed_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'status', 'last_activity_at'], 'support_tickets_user_status_activity_idx');
            $table->index(['status', 'last_activity_at'], 'support_tickets_status_activity_idx');
            $table->index(['type', 'status'], 'support_tickets_type_status_idx');
        });

        Schema::create('support_ticket_replies', function (Blueprint $table) {
            $table->id();
            $table->foreignId('support_ticket_id')->constrained('support_tickets')->cascadeOnDelete();
            $table->string('sender_type', 24); // member | admin
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('administrator_id')->nullable()->constrained('administrators')->nullOnDelete();
            $table->text('body');
            $table->timestampsTz();

            $table->index(['support_ticket_id', 'created_at'], 'support_ticket_replies_ticket_created_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_ticket_replies');
        Schema::dropIfExists('support_tickets');
    }
};
