<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiBusinessException;
use App\Http\Controllers\Controller;
use App\Models\SupportTicket;
use App\Models\SupportTicketReply;
use App\Models\User;
use App\Services\Support\SupportTicketService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SupportTicketController extends Controller
{
    public function __construct(
        private readonly SupportTicketService $supportTicketService,
    ) {}

    /**
     * GET /api/v1/support/tickets
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $validated = $request->validate([
            'type' => ['nullable', 'string', Rule::in(SupportTicket::TYPES)],
            'status' => ['nullable', 'string', Rule::in(SupportTicket::STATUSES)],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ], [
            'type.in' => 'نوع الطلب المحدد غير صالح.',
            'status.in' => 'حالة الطلب المحددة غير صالحة.',
        ]);

        $paginator = $this->supportTicketService->listUserTickets(
            user: $user,
            type: $validated['type'] ?? null,
            status: $validated['status'] ?? null,
            perPage: (int) ($validated['per_page'] ?? 20),
        );

        $tickets = collect($paginator->items())
            ->map(fn (SupportTicket $ticket) => $this->formatTicket($ticket, includeReplies: false))
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'tickets' => $tickets,
                'pagination' => [
                    'current_page' => $paginator->currentPage(),
                    'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(),
                    'total' => $paginator->total(),
                ],
            ],
        ]);
    }

    /**
     * POST /api/v1/support/tickets
     */
    public function store(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $validated = $request->validate([
            'type' => ['required', 'string', Rule::in(SupportTicket::TYPES)],
            'category' => ['required', 'string', Rule::in(SupportTicket::CATEGORIES)],
            'subject' => ['required', 'string', 'min:4', 'max:150'],
            'message' => ['required', 'string', 'min:10', 'max:3000'],
        ], [
            'type.required' => 'يرجى اختيار نوع الرسالة (استفسار أو شكوى).',
            'type.in' => 'نوع الرسالة المحدد غير صالح.',
            'category.required' => 'يرجى اختيار تصنيف الرسالة.',
            'category.in' => 'تصنيف الرسالة المحدد غير صالح.',
            'subject.required' => 'يرجى إدخال عنوان واضح للاستفسار أو الشكوى.',
            'subject.min' => 'عنوان الرسالة يجب أن لا يقل عن 4 أحرف.',
            'subject.max' => 'عنوان الرسالة يجب أن لا يتجاوز 150 حرفًا.',
            'message.required' => 'يرجى كتابة تفاصيل الاستفسار أو الشكوى.',
            'message.min' => 'تفاصيل الرسالة يجب أن لا تقل عن 10 أحرف.',
            'message.max' => 'تفاصيل الرسالة يجب أن لا تتجاوز 3000 حرف.',
        ]);

        try {
            $ticket = $this->supportTicketService->createTicket($user, $validated);
        } catch (ApiBusinessException $e) {
            return $this->businessError($e);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم إرسال طلبك إلى إدارة نَصِيبُكَ بنجاح، وسيتم الرد عليك في أقرب وقت.',
            'data' => [
                'ticket' => $this->formatTicket($ticket, includeReplies: true),
            ],
        ], 201);
    }

    /**
     * GET /api/v1/support/tickets/{supportTicket}
     */
    public function show(Request $request, SupportTicket $supportTicket): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        try {
            $ticket = $this->supportTicketService->getUserTicketDetail($user, $supportTicket);
        } catch (ApiBusinessException $e) {
            return $this->businessError($e);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'ticket' => $this->formatTicket($ticket, includeReplies: true),
            ],
        ]);
    }

    /**
     * POST /api/v1/support/tickets/{supportTicket}/replies
     */
    public function reply(Request $request, SupportTicket $supportTicket): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $validated = $request->validate([
            'body' => ['required', 'string', 'min:2', 'max:2000'],
        ], [
            'body.required' => 'يرجى كتابة نص الرد.',
            'body.min' => 'نص الرد يجب أن لا يقل عن حرفين.',
            'body.max' => 'نص الرد يجب أن لا يتجاوز 2000 حرف.',
        ]);

        try {
            $reply = $this->supportTicketService->addMemberReply($user, $supportTicket, $validated['body']);
            $ticket = $this->supportTicketService->getUserTicketDetail($user, $supportTicket);
        } catch (ApiBusinessException $e) {
            return $this->businessError($e);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم إرسال ردك بنجاح.',
            'data' => [
                'reply' => $this->formatReply($reply, $user),
                'ticket' => $this->formatTicket($ticket, includeReplies: true),
            ],
        ], 201);
    }

    private function businessError(ApiBusinessException $e): JsonResponse
    {
        return response()->json([
            'status' => 'error',
            'code' => $e->errorCode,
            'message' => $e->getMessage(),
        ], $e->httpStatus);
    }

    private function formatTicket(SupportTicket $ticket, bool $includeReplies): array
    {
        $payload = [
            'id' => $ticket->id,
            'ticket_number' => $ticket->ticket_number,
            'type' => $ticket->type,
            'type_label' => $ticket->typeLabel(),
            'category' => $ticket->category,
            'category_label' => $ticket->categoryLabel(),
            'subject' => $ticket->subject,
            'message' => $ticket->message,
            'status' => $ticket->status,
            'status_label' => $ticket->statusLabel(),
            'admin_reply' => $ticket->admin_reply,
            'responded_at' => $ticket->responded_at?->toIso8601String(),
            'last_activity_at' => $ticket->last_activity_at?->toIso8601String()
                ?? $ticket->created_at?->toIso8601String(),
            'last_sender_type' => $ticket->last_sender_type,
            'replies_count' => $ticket->replies_count ?? ($ticket->relationLoaded('replies') ? $ticket->replies->count() : 0),
            'closed_at' => $ticket->closed_at?->toIso8601String(),
            'created_at' => $ticket->created_at?->toIso8601String(),
        ];

        if ($includeReplies) {
            $owner = $ticket->user;
            $payload['replies'] = $ticket->replies
                ->map(fn (SupportTicketReply $reply) => $this->formatReply($reply, $owner))
                ->values();
        }

        return $payload;
    }

    private function formatReply(SupportTicketReply $reply, ?User $ticketOwner): array
    {
        $isAdmin = $reply->isFromAdmin();

        return [
            'id' => $reply->id,
            'sender_type' => $reply->sender_type,
            'sender_name' => $isAdmin
                ? 'إدارة نَصِيبُكَ'
                : ($reply->user?->profile?->full_name ?: $ticketOwner?->profile?->full_name ?: 'أنت'),
            'body' => $reply->body,
            'created_at' => $reply->created_at?->toIso8601String(),
        ];
    }
}
