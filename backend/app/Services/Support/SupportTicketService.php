<?php

namespace App\Services\Support;

use App\Exceptions\ApiBusinessException;
use App\Models\Administrator;
use App\Models\SupportTicket;
use App\Models\SupportTicketReply;
use App\Models\User;
use App\Services\Admin\AdminAuditService;
use App\Services\Notification\NotificationService;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SupportTicketService
{
    public function __construct(
        private readonly NotificationService $notificationService,
        private readonly AdminAuditService $adminAuditService,
    ) {}

    public function listUserTickets(
        User $user,
        ?string $type = null,
        ?string $status = null,
        int $perPage = 20
    ): LengthAwarePaginator {
        $query = SupportTicket::query()
            ->where('user_id', $user->id)
            ->with([
                'user.profile:id,user_id,full_name',
                'respondedByAdmin:id,name',
                'replies' => fn ($q) => $q->with([
                    'user:id,email',
                    'user.profile:id,user_id,full_name',
                    'administrator:id,name',
                ]),
            ])
            ->withCount('replies')
            ->orderByDesc('last_activity_at')
            ->orderByDesc('id');

        if ($type !== null && in_array($type, SupportTicket::TYPES, true)) {
            $query->where('type', $type);
        }

        if ($status !== null && in_array($status, SupportTicket::STATUSES, true)) {
            $query->where('status', $status);
        }

        return $query->paginate(min(50, max(1, $perPage)));
    }

    public function createTicket(User $user, array $validated): SupportTicket
    {
        if ($user->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'لا يمكن إرسال استفسار أو شكوى لحساب غير نشط.',
                403
            );
        }

        return DB::transaction(function () use ($user, $validated): SupportTicket {
            $now = now();
            $ticket = SupportTicket::create([
                'ticket_number' => 'TMP-' . Str::ulid(),
                'user_id' => $user->id,
                'type' => $validated['type'],
                'category' => $validated['category'],
                'subject' => trim((string) $validated['subject']),
                'message' => trim((string) $validated['message']),
                'status' => SupportTicket::STATUS_OPEN,
                'last_activity_at' => $now,
                'last_sender_type' => SupportTicket::SENDER_MEMBER,
            ]);

            $ticket->update([
                'ticket_number' => sprintf('NSB-%s-%05d', $now->format('ym'), $ticket->id),
            ]);

            return $ticket->fresh(['user.profile:id,user_id,full_name', 'replies', 'respondedByAdmin:id,name']);
        });
    }

    public function getUserTicketDetail(User $user, SupportTicket $ticket): SupportTicket
    {
        $this->assertOwnership($user, $ticket);

        $ticket->refresh();

        return $ticket->load([
            'user.profile:id,user_id,full_name',
            'respondedByAdmin:id,name',
            'replies.user:id,email',
            'replies.user.profile:id,user_id,full_name',
            'replies.administrator:id,name',
        ])->loadCount('replies');
    }

    public function addMemberReply(User $user, SupportTicket $ticket, string $body): SupportTicketReply
    {
        $this->assertOwnership($user, $ticket);

        if ($user->account_status !== 'active') {
            throw new ApiBusinessException(
                'ACCOUNT_NOT_ACTIVE',
                'لا يمكن إضافة رد من حساب غير نشط.',
                403
            );
        }

        if ($ticket->isClosed()) {
            throw new ApiBusinessException(
                'SUPPORT_TICKET_CLOSED',
                'تم إغلاق هذا الطلب ولا يمكن إضافة ردود جديدة عليه. يمكنك إرسال طلب جديد.',
                422
            );
        }

        $trimmed = trim($body);

        return DB::transaction(function () use ($user, $ticket, $trimmed): SupportTicketReply {
            $locked = SupportTicket::whereKey($ticket->id)->lockForUpdate()->firstOrFail();

            if ($locked->isClosed()) {
                throw new ApiBusinessException(
                    'SUPPORT_TICKET_CLOSED',
                    'تم إغلاق هذا الطلب ولا يمكن إضافة ردود جديدة عليه. يمكنك إرسال طلب جديد.',
                    422
                );
            }

            $reply = SupportTicketReply::create([
                'support_ticket_id' => $locked->id,
                'sender_type' => SupportTicketReply::SENDER_MEMBER,
                'user_id' => $user->id,
                'body' => $trimmed,
            ]);

            $nextStatus = $locked->status === SupportTicket::STATUS_ANSWERED
                ? SupportTicket::STATUS_IN_PROGRESS
                : $locked->status;

            $locked->update([
                'status' => $nextStatus,
                'last_activity_at' => now(),
                'last_sender_type' => SupportTicket::SENDER_MEMBER,
            ]);

            return $reply->load(['user:id,email', 'user.profile:id,user_id,full_name']);
        });
    }

    public function replyAsAdmin(
        Administrator $actor,
        SupportTicket $ticket,
        string $replyBody,
        string $newStatus = SupportTicket::STATUS_ANSWERED
    ): SupportTicketReply {
        if (!in_array($newStatus, SupportTicket::STATUSES, true)) {
            throw new ApiBusinessException(
                'INVALID_SUPPORT_TICKET_STATUS',
                'حالة التذكرة غير صالحة.',
                422
            );
        }

        $trimmed = trim($replyBody);
        if ($trimmed === '') {
            throw new ApiBusinessException(
                'EMPTY_ADMIN_REPLY',
                'يرجى كتابة نص الرد قبل الإرسال.',
                422
            );
        }

        $reply = DB::transaction(function () use ($actor, $ticket, $trimmed, $newStatus): SupportTicketReply {
            $locked = SupportTicket::whereKey($ticket->id)->lockForUpdate()->firstOrFail();
            $previous = [
                'status' => $locked->status,
                'responded_by_admin_id' => $locked->responded_by_admin_id,
                'admin_reply' => $locked->admin_reply,
            ];

            $reply = SupportTicketReply::create([
                'support_ticket_id' => $locked->id,
                'sender_type' => SupportTicketReply::SENDER_ADMIN,
                'administrator_id' => $actor->id,
                'body' => $trimmed,
            ]);

            $now = now();
            $updates = [
                'status' => $newStatus,
                'assigned_admin_id' => $locked->assigned_admin_id ?? $actor->id,
                'responded_by_admin_id' => $actor->id,
                'admin_reply' => $trimmed,
                'responded_at' => $now,
                'last_activity_at' => $now,
                'last_sender_type' => SupportTicket::SENDER_ADMIN,
                'closed_at' => $newStatus === SupportTicket::STATUS_CLOSED ? $now : null,
            ];

            $locked->update($updates);

            $this->adminAuditService->record(
                actor: $actor,
                action: 'support_ticket_replied',
                target: $locked,
                previousValues: $previous,
                newValues: [
                    'status' => $newStatus,
                    'reply_id' => $reply->id,
                ],
                reason: mb_substr($trimmed, 0, 250)
            );

            return $reply->load('administrator:id,name');
        });

        $ticket->refresh()->loadMissing('user');
        if ($ticket->user !== null) {
            $this->notificationService->notifySupportTicketReplied($ticket->user, $ticket, $reply);
        }

        return $reply;
    }

    public function updateStatusAsAdmin(
        Administrator $actor,
        SupportTicket $ticket,
        string $newStatus,
        ?string $note = null
    ): SupportTicket {
        if (!in_array($newStatus, SupportTicket::STATUSES, true)) {
            throw new ApiBusinessException(
                'INVALID_SUPPORT_TICKET_STATUS',
                'حالة التذكرة غير صالحة.',
                422
            );
        }

        return DB::transaction(function () use ($actor, $ticket, $newStatus, $note): SupportTicket {
            $locked = SupportTicket::whereKey($ticket->id)->lockForUpdate()->firstOrFail();
            $previous = ['status' => $locked->status];

            $locked->update([
                'status' => $newStatus,
                'assigned_admin_id' => $locked->assigned_admin_id ?? $actor->id,
                'closed_at' => $newStatus === SupportTicket::STATUS_CLOSED ? now() : null,
                'last_activity_at' => now(),
            ]);

            $this->adminAuditService->record(
                actor: $actor,
                action: 'support_ticket_status_updated',
                target: $locked,
                previousValues: $previous,
                newValues: ['status' => $newStatus],
                reason: $note ?: "تحديث حالة الطلب {$locked->ticket_number} إلى {$locked->statusLabel()}"
            );

            return $locked->fresh([
                'user.profile:id,user_id,full_name',
                'respondedByAdmin:id,name',
                'replies.administrator:id,name',
                'replies.user:id,email',
                'replies.user.profile:id,user_id,full_name',
            ]);
        });
    }

    private function assertOwnership(User $user, SupportTicket $ticket): void
    {
        if ((int) $ticket->user_id !== (int) $user->id) {
            throw new ApiBusinessException(
                'SUPPORT_TICKET_FORBIDDEN',
                'غير مصرح لك بالوصول إلى هذا الطلب.',
                403
            );
        }
    }
}
