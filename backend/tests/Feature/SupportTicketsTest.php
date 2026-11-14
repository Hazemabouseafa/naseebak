<?php

namespace Tests\Feature;

use App\Filament\Resources\SupportTicketResource;
use App\Filament\Resources\SupportTicketResource\Pages\ListSupportTickets;
use App\Filament\Resources\SupportTicketResource\Pages\ViewSupportTicket;
use App\Filament\Widgets\PlatformStatsOverviewWidget;
use App\Models\AdminAuditLog;
use App\Models\Administrator;
use App\Models\NotificationRecord;
use App\Models\SupportTicket;
use App\Models\SupportTicketReply;
use App\Models\User;
use App\Models\UserProfile;
use App\Services\Auth\AccountDeletionService;
use App\Services\Support\SupportTicketService;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Livewire\Livewire;
use Tests\TestCase;

class SupportTicketsTest extends TestCase
{
    use RefreshDatabase;

    public function test_unauthenticated_requests_to_support_endpoints_are_rejected(): void
    {
        $this->getJson('/api/v1/support/tickets')->assertStatus(401);
        $this->postJson('/api/v1/support/tickets', [])->assertStatus(401);
        $this->getJson('/api/v1/support/tickets/1')->assertStatus(401);
        $this->postJson('/api/v1/support/tickets/1/replies', [])->assertStatus(401);
    }

    public function test_member_can_create_inquiry_and_complaint_and_list_with_filters(): void
    {
        $member = $this->createMember('member1@example.com', 'sub-member-1', 'أحمد سعيد');
        Sanctum::actingAs($member);

        // Validation error check
        $this->postJson('/api/v1/support/tickets', [
            'type' => 'inquiry',
            'category' => 'general',
            'subject' => 'س',
            'message' => 'قصير',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['subject', 'message']);

        // Create inquiry
        $inquiryRes = $this->postJson('/api/v1/support/tickets', [
            'type' => SupportTicket::TYPE_INQUIRY,
            'category' => SupportTicket::CATEGORY_SUBSCRIPTION,
            'subject' => 'استفسار حول تفعيل العضوية',
            'message' => 'السلام عليكم، قمت بالتسجيل وأرغب في معرفة كيفية مراجعة حالة العضوية الخاصة بي.',
        ]);

        $inquiryRes->assertStatus(201)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.ticket.type', 'inquiry')
            ->assertJsonPath('data.ticket.status', 'open')
            ->assertJsonPath('data.ticket.category', 'subscription');

        $ticketNumber = $inquiryRes->json('data.ticket.ticket_number');
        $this->assertStringStartsWith('NSB-', (string) $ticketNumber);

        // Create complaint
        $complaintRes = $this->postJson('/api/v1/support/tickets', [
            'type' => SupportTicket::TYPE_COMPLAINT,
            'category' => SupportTicket::CATEGORY_TECHNICAL,
            'subject' => 'مشكلة في وصول الإشعارات',
            'message' => 'ألاحظ تأخرًا في ظهور بعض الإشعارات داخل التطبيق أرجو المراجعة.',
        ]);

        $complaintRes->assertStatus(201)
            ->assertJsonPath('data.ticket.type', 'complaint')
            ->assertJsonPath('data.ticket.category', 'technical');

        // List all tickets
        $allRes = $this->getJson('/api/v1/support/tickets');
        $allRes->assertStatus(200)
            ->assertJsonCount(2, 'data.tickets');

        // Filter by complaint
        $complaintsOnly = $this->getJson('/api/v1/support/tickets?type=complaint');
        $complaintsOnly->assertStatus(200)
            ->assertJsonCount(1, 'data.tickets')
            ->assertJsonPath('data.tickets.0.type', 'complaint');

        // Filter by inquiry
        $inquiriesOnly = $this->getJson('/api/v1/support/tickets?type=inquiry');
        $inquiriesOnly->assertStatus(200)
            ->assertJsonCount(1, 'data.tickets')
            ->assertJsonPath('data.tickets.0.type', 'inquiry');
    }

    public function test_member_cannot_view_or_reply_to_another_members_ticket(): void
    {
        $owner = $this->createMember('owner@example.com', 'sub-owner', 'سارة محمد');
        $other = $this->createMember('other@example.com', 'sub-other', 'خالد حسن');

        $ticket = app(SupportTicketService::class)->createTicket($owner, [
            'type' => SupportTicket::TYPE_COMPLAINT,
            'category' => SupportTicket::CATEGORY_ACCOUNT,
            'subject' => 'شكوى بخصوص بيانات الحساب',
            'message' => 'تفاصيل الشكوى الخاصة بالعضو الأول فقط ولا يجب لغيره الاطلاع عليها.',
        ]);

        Sanctum::actingAs($other);

        $this->getJson("/api/v1/support/tickets/{$ticket->id}")
            ->assertStatus(403)
            ->assertJsonPath('code', 'SUPPORT_TICKET_FORBIDDEN');

        $this->postJson("/api/v1/support/tickets/{$ticket->id}/replies", [
            'body' => 'محاولة رد غير مصرح بها',
        ])->assertStatus(403)
            ->assertJsonPath('code', 'SUPPORT_TICKET_FORBIDDEN');
    }

    public function test_admin_reply_updates_ticket_creates_audit_log_and_dispatches_support_notification(): void
    {
        $member = $this->createMember('notify.member@example.com', 'sub-notify-1', 'مريم عادل');
        $admin = $this->createAdmin(Administrator::ROLE_MODERATOR);

        $ticket = app(SupportTicketService::class)->createTicket($member, [
            'type' => SupportTicket::TYPE_INQUIRY,
            'category' => SupportTicket::CATEGORY_GENERAL,
            'subject' => 'استفسار عن مراجعة الصورة الشخصية',
            'message' => 'متى يتم اعتماد الصورة الشخصية الجديدة بعد رفعها من صفحة الملف الشخصي؟',
        ]);

        $reply = app(SupportTicketService::class)->replyAsAdmin(
            actor: $admin,
            ticket: $ticket,
            replyBody: 'أهلًا بك، تتم مراجعة الصور الشخصية خلال ساعات قليلة من فريق الإدارة.',
            newStatus: SupportTicket::STATUS_ANSWERED,
        );

        $ticket->refresh();
        $this->assertSame(SupportTicket::STATUS_ANSWERED, $ticket->status);
        $this->assertSame(SupportTicket::SENDER_ADMIN, $ticket->last_sender_type);
        $this->assertSame($admin->id, (int) $ticket->responded_by_admin_id);
        $this->assertNotNull($ticket->responded_at);
        $this->assertSame(SupportTicketReply::SENDER_ADMIN, $reply->sender_type);

        // Audit log recorded
        $this->assertDatabaseHas('admin_audit_logs', [
            'administrator_id' => $admin->id,
            'action' => 'support_ticket_replied',
            'target_type' => SupportTicket::class,
            'target_id' => $ticket->id,
        ]);

        // Notification dispatched to member with support_ticket deep link metadata
        $notification = NotificationRecord::where('user_id', $member->id)
            ->where('event_type', NotificationRecord::TYPE_SUPPORT_REPLY)
            ->first();

        $this->assertNotNull($notification);
        $this->assertSame(NotificationRecord::ROUTE_SUPPORT_TICKET, $notification->action_route);
        $this->assertSame($ticket->id, (int) $notification->reference_id);
        $this->assertSame($ticket->id, (int) ($notification->routing_metadata['ticket_id'] ?? 0));
    }

    public function test_member_can_follow_up_on_answered_ticket_and_closed_ticket_blocks_new_replies(): void
    {
        $member = $this->createMember('thread.member@example.com', 'sub-thread-1', 'طارق نبيل');
        $admin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);
        $service = app(SupportTicketService::class);

        $ticket = $service->createTicket($member, [
            'type' => SupportTicket::TYPE_INQUIRY,
            'category' => SupportTicket::CATEGORY_TECHNICAL,
            'subject' => 'سؤال حول تحديث البيانات',
            'message' => 'هل يمكن تعديل المدينة بعد إتمام التسجيل الأولي في التطبيق؟',
        ]);

        $service->replyAsAdmin($admin, $ticket, 'نعم يمكنك تعديلها من شاشة تعديل الملف الشخصي.', SupportTicket::STATUS_ANSWERED);

        Sanctum::actingAs($member);
        $replyRes = $this->postJson("/api/v1/support/tickets/{$ticket->id}/replies", [
            'body' => 'شكرًا لكم، تم العثور على الخيار ولكن لدي سؤال إضافي حول صورة الحساب.',
        ]);

        $replyRes->assertStatus(201)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.ticket.status', SupportTicket::STATUS_IN_PROGRESS)
            ->assertJsonPath('data.ticket.last_sender_type', SupportTicket::SENDER_MEMBER)
            ->assertJsonCount(2, 'data.ticket.replies');

        // Admin closes ticket
        $service->replyAsAdmin($admin, $ticket->fresh(), 'تم اعتماد التحديث وإغلاق التذكرة.', SupportTicket::STATUS_CLOSED);

        $closedRes = $this->postJson("/api/v1/support/tickets/{$ticket->id}/replies", [
            'body' => 'محاولة رد بعد الإغلاق',
        ]);
        $closedRes->assertStatus(422)
            ->assertJsonPath('code', 'SUPPORT_TICKET_CLOSED');
    }

    public function test_filament_support_tickets_resource_and_dashboard_stats_work_end_to_end(): void
    {
        $member = $this->createMember('filament.member@example.com', 'sub-fil-1', 'ندى إبراهيم');
        $admin = $this->createAdmin(Administrator::ROLE_SUPER_ADMIN);

        $ticket = app(SupportTicketService::class)->createTicket($member, [
            'type' => SupportTicket::TYPE_COMPLAINT,
            'category' => SupportTicket::CATEGORY_BEHAVIOR,
            'subject' => 'شكوى متعلقة بالتعامل',
            'message' => 'أرجو مراجعة الشكوى المرسلة من التطبيق والتواصل معي بخصوصها.',
        ]);

        $this->assertSame('1', SupportTicketResource::getNavigationBadge());
        $metrics = PlatformStatsOverviewWidget::computeMetrics();
        $this->assertSame(1, $metrics['open_support_tickets']);

        // HTTP rendering of Filament index & view pages
        $this->actingAs($admin, 'admin')
            ->get('/admin/support-tickets')
            ->assertStatus(200)
            ->assertSee($ticket->ticket_number);

        $this->actingAs($admin, 'admin')
            ->get("/admin/support-tickets/{$ticket->id}")
            ->assertStatus(200)
            ->assertSee($ticket->subject);

        // Livewire ViewSupportTicket reply action
        Filament::setCurrentPanel(Filament::getPanel('admin'));

        Livewire::actingAs($admin, 'admin')
            ->test(ListSupportTickets::class)
            ->assertCanSeeTableRecords([$ticket]);

        Livewire::actingAs($admin, 'admin')
            ->test(ViewSupportTicket::class, ['record' => $ticket->getRouteKey()])
            ->callAction('reply', data: [
                'reply_body' => 'تم استلام شكواك وجارٍ اتخاذ اللازم من الإدارة.',
                'status' => SupportTicket::STATUS_ANSWERED,
            ])
            ->assertHasNoActionErrors();

        $ticket->refresh();
        $this->assertSame(SupportTicket::STATUS_ANSWERED, $ticket->status);
        $this->assertNull(SupportTicketResource::getNavigationBadge());
        $this->assertSame(0, PlatformStatsOverviewWidget::computeMetrics()['open_support_tickets']);
    }

    public function test_account_deletion_closes_open_support_tickets_for_deleted_member(): void
    {
        $member = $this->createMember('delete.support@example.com', 'sub-del-sup', 'ياسر فؤاد');

        $ticket = app(SupportTicketService::class)->createTicket($member, [
            'type' => SupportTicket::TYPE_INQUIRY,
            'category' => SupportTicket::CATEGORY_GENERAL,
            'subject' => 'استفسار قبل حذف الحساب',
            'message' => 'أرغب في معرفة سياسة الاحتفاظ بالبيانات بعد إغلاق الحساب.',
        ]);

        $this->assertSame(1, PlatformStatsOverviewWidget::computeMetrics()['open_support_tickets']);

        app(AccountDeletionService::class)->executeUserDeletion($member, 'user requested deletion');

        $ticket->refresh();
        $this->assertSame(SupportTicket::STATUS_CLOSED, $ticket->status);
        $this->assertNotNull($ticket->closed_at);
        $this->assertSame(0, PlatformStatsOverviewWidget::computeMetrics()['open_support_tickets']);
    }

    private function createMember(string $email, string $googleSub, string $fullName): User
    {
        $user = User::create([
            'google_sub' => $googleSub,
            'email' => $email,
            'email_verified' => true,
            'role' => 'member',
            'account_status' => 'active',
            'profile_completed' => true,
            'last_active_at' => now(),
        ]);

        UserProfile::create([
            'user_id' => $user->id,
            'full_name' => $fullName,
            'gender' => 'male',
            'date_of_birth' => '1993-04-12',
            'age_years' => 33,
            'zodiac_sign' => 'الحمل',
            'marital_status' => 'single',
            'previously_married' => false,
            'has_children' => false,
            'children_count' => 0,
            'education_level' => 'bachelor',
            'occupation' => 'محاسب',
            'height_cm' => 178,
            'smoking_status' => 'non_smoker',
            'home_ownership' => 'owned',
            'hobbies' => ['القراءة'],
            'nationality' => 'مصر',
            'country_of_residence' => 'مصر',
            'region' => 'القاهرة',
            'is_visible' => true,
            'photo_privacy' => 'public',
            'moderation_status' => 'approved',
        ]);

        return $user->fresh(['profile']);
    }

    private function createAdmin(string $role): Administrator
    {
        return Administrator::create([
            'name' => 'مشرف الدعم',
            'email' => $role . '-' . uniqid() . '@hazem.my',
            'password' => Hash::make('Secret@2026!'),
            'role' => $role,
            'is_active' => true,
        ]);
    }
}
