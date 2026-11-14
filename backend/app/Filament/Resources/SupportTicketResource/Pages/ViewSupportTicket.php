<?php

namespace App\Filament\Resources\SupportTicketResource\Pages;

use App\Filament\Resources\SupportTicketResource;
use App\Models\Administrator;
use App\Models\SupportTicket;
use App\Services\Support\SupportTicketService;
use Filament\Actions;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ViewRecord;
use Illuminate\Support\Facades\Auth;

class ViewSupportTicket extends ViewRecord
{
    protected static string $resource = SupportTicketResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('reply')
                ->label('الرد على العضو')
                ->icon('heroicon-o-paper-airplane')
                ->color('primary')
                ->visible(fn (SupportTicket $record) => !$record->isClosed())
                ->form([
                    Textarea::make('reply_body')
                        ->label('نص الرد الذي سيصل للعضو')
                        ->required()
                        ->minLength(2)
                        ->maxLength(2000)
                        ->rows(4),
                    Select::make('status')
                        ->label('حالة الطلب بعد الرد')
                        ->options([
                            SupportTicket::STATUS_ANSWERED => 'تم الرد (يسمح بمتابعة العضو)',
                            SupportTicket::STATUS_CLOSED => 'تم الرد وإغلاق الطلب نهائيًا',
                        ])
                        ->default(SupportTicket::STATUS_ANSWERED)
                        ->required(),
                ])
                ->action(function (SupportTicket $record, array $data): void {
                    /** @var Administrator $actor */
                    $actor = Auth::guard('admin')->user();
                    app(SupportTicketService::class)->replyAsAdmin(
                        actor: $actor,
                        ticket: $record,
                        replyBody: (string) $data['reply_body'],
                        newStatus: (string) $data['status'],
                    );

                    $record->refresh();

                    Notification::make()
                        ->success()
                        ->title('تم إرسال الرد وإشعار العضو بنجاح')
                        ->send();
                }),
            Actions\Action::make('update_status')
                ->label('تغيير الحالة')
                ->icon('heroicon-o-arrow-path')
                ->color('gray')
                ->form([
                    Select::make('status')
                        ->label('الحالة الجديدة')
                        ->options(SupportTicket::statusLabels())
                        ->default(fn (SupportTicket $record) => $record->status)
                        ->required(),
                    Textarea::make('note')
                        ->label('ملاحظة إدارية لسجل التدقيق (اختياري)')
                        ->maxLength(500)
                        ->rows(2),
                ])
                ->action(function (SupportTicket $record, array $data): void {
                    /** @var Administrator $actor */
                    $actor = Auth::guard('admin')->user();
                    app(SupportTicketService::class)->updateStatusAsAdmin(
                        actor: $actor,
                        ticket: $record,
                        newStatus: (string) $data['status'],
                        note: $data['note'] ?? null,
                    );

                    $record->refresh();

                    Notification::make()
                        ->success()
                        ->title('تم تحديث حالة الطلب بنجاح')
                        ->send();
                }),
        ];
    }
}
