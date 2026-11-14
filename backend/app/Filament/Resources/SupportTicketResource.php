<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SupportTicketResource\Pages;
use App\Models\Administrator;
use App\Models\SupportTicket;
use App\Models\SupportTicketReply;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Support\SupportTicketService;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

class SupportTicketResource extends Resource
{
    protected static ?string $model = SupportTicket::class;
    protected static ?string $navigationIcon = 'heroicon-o-chat-bubble-left-right';
    protected static ?string $navigationLabel = 'الاستفسارات والشكاوى';
    protected static ?string $modelLabel = 'طلب تواصل';
    protected static ?string $pluralModelLabel = 'الاستفسارات والشكاوى';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_USERS;
    protected static ?int $navigationSort = 5;

    public static function getNavigationBadge(): ?string
    {
        $pendingCount = SupportTicket::whereIn('status', SupportTicket::OPEN_STATUSES)->count();

        return $pendingCount > 0 ? (string) $pendingCount : null;
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return 'warning';
    }

    public static function canViewAny(): bool
    {
        $admin = Auth::guard('admin')->user();

        return $admin instanceof Administrator
            && (bool) $admin->is_active
            && in_array($admin->role, Administrator::ALLOWED_ROLES, true);
    }

    public static function canView(Model $record): bool
    {
        return self::canViewAny();
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit(Model $record): bool
    {
        return false;
    }

    public static function canDelete(Model $record): bool
    {
        return false;
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with(['user.profile', 'assignedAdmin', 'respondedByAdmin', 'replies.user.profile', 'replies.administrator'])
            ->withCount('replies');
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Section::make('بيانات الاستفسار أو الشكوى')
                    ->columns(3)
                    ->schema([
                        TextEntry::make('ticket_number')
                            ->label('رقم الطلب')
                            ->copyable()
                            ->badge()
                            ->color('primary'),
                        TextEntry::make('type')
                            ->label('النوع')
                            ->badge()
                            ->formatStateUsing(fn (string $state) => SupportTicket::typeLabels()[$state] ?? $state)
                            ->color(fn (string $state) => $state === SupportTicket::TYPE_COMPLAINT ? 'danger' : 'info'),
                        TextEntry::make('category')
                            ->label('التصنيف')
                            ->badge()
                            ->formatStateUsing(fn (string $state) => SupportTicket::categoryLabels()[$state] ?? $state)
                            ->color('gray'),
                        TextEntry::make('status')
                            ->label('الحالة الحالية')
                            ->badge()
                            ->formatStateUsing(fn (string $state) => SupportTicket::statusLabels()[$state] ?? $state)
                            ->color(fn (string $state) => match ($state) {
                                SupportTicket::STATUS_OPEN => 'warning',
                                SupportTicket::STATUS_IN_PROGRESS => 'info',
                                SupportTicket::STATUS_ANSWERED => 'success',
                                SupportTicket::STATUS_CLOSED => 'gray',
                                default => 'gray',
                            }),
                        TextEntry::make('user.profile.full_name')
                            ->label('العضو المرسل')
                            ->default('حساب غير متاح'),
                        TextEntry::make('user.email')
                            ->label('البريد الإلكتروني للعضو')
                            ->default('—'),
                        TextEntry::make('created_at')
                            ->label('تاريخ الإرسال')
                            ->dateTime('Y-m-d H:i'),
                        TextEntry::make('respondedByAdmin.name')
                            ->label('آخر مشرف قام بالرد')
                            ->default('لم يتم الرد بعد'),
                        TextEntry::make('responded_at')
                            ->label('تاريخ آخر رد إداري')
                            ->dateTime('Y-m-d H:i')
                            ->placeholder('لم يتم الرد بعد'),
                    ]),
                Section::make('الرسالة الأساسية من العضو')
                    ->schema([
                        TextEntry::make('subject')
                            ->label('العنوان')
                            ->weight('bold'),
                        TextEntry::make('message')
                            ->label('التفاصيل')
                            ->columnSpanFull(),
                    ]),
                Section::make('سجل الردود والمتابعة')
                    ->schema([
                        RepeatableEntry::make('replies')
                            ->label('المحادثة')
                            ->placeholder('لا توجد ردود إضافية بعد. استخدم زر "الرد على العضو" لإرسال رد الإدارة.')
                            ->columns(3)
                            ->schema([
                                TextEntry::make('sender_type')
                                    ->label('المرسل')
                                    ->badge()
                                    ->formatStateUsing(function (string $state, SupportTicketReply $record): string {
                                        if ($state === SupportTicketReply::SENDER_ADMIN) {
                                            $adminName = $record->administrator?->name;

                                            return $adminName ? "الإدارة ({$adminName})" : 'إدارة نَصِيبُكَ';
                                        }

                                        return $record->user?->profile?->full_name ?? 'العضو';
                                    })
                                    ->color(fn (string $state) => $state === SupportTicketReply::SENDER_ADMIN ? 'success' : 'info'),
                                TextEntry::make('created_at')
                                    ->label('التوقيت')
                                    ->dateTime('Y-m-d H:i'),
                                TextEntry::make('body')
                                    ->label('نص الرسالة')
                                    ->columnSpanFull(),
                            ]),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('ticket_number')
                    ->label('رقم الطلب')
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->weight('bold'),
                Tables\Columns\TextColumn::make('user.profile.full_name')
                    ->label('العضو')
                    ->searchable()
                    ->placeholder('عضو')
                    ->description(fn (SupportTicket $record) => $record->user?->email ?? ''),
                Tables\Columns\TextColumn::make('type')
                    ->label('النوع')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => SupportTicket::typeLabels()[$state] ?? $state)
                    ->color(fn (string $state) => $state === SupportTicket::TYPE_COMPLAINT ? 'danger' : 'info')
                    ->sortable(),
                Tables\Columns\TextColumn::make('category')
                    ->label('التصنيف')
                    ->formatStateUsing(fn (string $state) => SupportTicket::categoryLabels()[$state] ?? $state)
                    ->toggleable(),
                Tables\Columns\TextColumn::make('subject')
                    ->label('الموضوع')
                    ->searchable()
                    ->limit(40),
                Tables\Columns\TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => SupportTicket::statusLabels()[$state] ?? $state)
                    ->color(fn (string $state) => match ($state) {
                        SupportTicket::STATUS_OPEN => 'warning',
                        SupportTicket::STATUS_IN_PROGRESS => 'info',
                        SupportTicket::STATUS_ANSWERED => 'success',
                        SupportTicket::STATUS_CLOSED => 'gray',
                        default => 'gray',
                    })
                    ->sortable(),
                Tables\Columns\TextColumn::make('last_sender_type')
                    ->label('آخر مرسل')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => $state === SupportTicket::SENDER_ADMIN ? 'رد الإدارة' : 'بانتظار الإدارة')
                    ->color(fn (string $state) => $state === SupportTicket::SENDER_ADMIN ? 'success' : 'warning'),
                Tables\Columns\TextColumn::make('replies_count')
                    ->label('الردود')
                    ->numeric()
                    ->sortable(),
                Tables\Columns\TextColumn::make('last_activity_at')
                    ->label('آخر نشاط')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->defaultSort('last_activity_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('type')
                    ->label('النوع')
                    ->options(SupportTicket::typeLabels()),
                Tables\Filters\SelectFilter::make('status')
                    ->label('الحالة')
                    ->options(SupportTicket::statusLabels()),
                Tables\Filters\SelectFilter::make('category')
                    ->label('التصنيف')
                    ->options(SupportTicket::categoryLabels()),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('عرض'),
                Tables\Actions\Action::make('reply')
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

                        Notification::make()
                            ->success()
                            ->title('تم إرسال الرد وإشعار العضو بنجاح')
                            ->send();
                    }),
                Tables\Actions\Action::make('update_status')
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

                        Notification::make()
                            ->success()
                            ->title('تم تحديث حالة الطلب بنجاح')
                            ->send();
                    }),
            ])
            ->bulkActions([]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSupportTickets::route('/'),
            'view' => Pages\ViewSupportTicket::route('/{record}'),
        ];
    }
}
