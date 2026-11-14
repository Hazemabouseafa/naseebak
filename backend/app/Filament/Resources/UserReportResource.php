<?php

namespace App\Filament\Resources;

use App\Filament\Resources\UserReportResource\Pages;
use App\Models\Administrator;
use App\Models\UserReport;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Admin\AdminModerationService;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Toggle;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

class UserReportResource extends Resource
{
    protected static ?string $model = UserReport::class;
    protected static ?string $navigationIcon = 'heroicon-o-shield-exclamation';
    protected static ?string $navigationLabel = 'بلاغات الأعضاء';
    protected static ?string $modelLabel = 'بلاغ عضو';
    protected static ?string $pluralModelLabel = 'بلاغات الأعضاء';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_USERS;
    protected static ?int $navigationSort = 4;

    public static function getEloquentQuery(): Builder
    {
        // Privacy safeguard: Never eager-load or expose private chat messages (`conversation.messages`)
        return parent::getEloquentQuery()
            ->with(['reporter.profile', 'reportedUser.profile', 'assignedModerator', 'reviewedByAdmin']);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canDelete($record): bool
    {
        return false;
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Section::make('تفاصيل البلاغ (مع حماية خصوصية الرسائل الخاصة)')
                    ->columns(3)
                    ->schema([
                        TextEntry::make('id')->label('رقم البلاغ'),
                        TextEntry::make('reporter.profile.full_name')->label('العضو المُبلِّغ'),
                        TextEntry::make('reportedUser.profile.full_name')->label('العضو المُبلَّغ عنه'),
                        TextEntry::make('reason_category')
                            ->label('تصنيف البلاغ')
                            ->formatStateUsing(fn (string $state) => match ($state) {
                                'inappropriate_behavior' => 'سلوك غير لائق',
                                'fake_profile' => 'ملف غير حقيقي / مضلل',
                                'harassment' => 'إزعاج أو مضايقة',
                                'scam_attempt' => 'محاولة احتيال أو طلب أموال',
                                default => 'أخرى',
                            }),
                        TextEntry::make('status')
                            ->label('حالة البلاغ')
                            ->badge(),
                        TextEntry::make('created_at')->label('تاريخ البلاغ')->dateTime('Y-m-d H:i'),
                        TextEntry::make('details')->label('وصف البلاغ المقدم من العضو')->columnSpanFull(),
                        TextEntry::make('resolution_notes')->label('ملاحظات وقرار المشرف')->columnSpanFull(),
                        TextEntry::make('reviewedByAdmin.name')->label('تمت المراجعة بواسطة'),
                        TextEntry::make('reviewed_at')->label('تاريخ المراجعة')->dateTime('Y-m-d H:i'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('رقم البلاغ')
                    ->sortable(),
                Tables\Columns\TextColumn::make('reporter.profile.full_name')
                    ->label('المُبلِّغ')
                    ->searchable()
                    ->placeholder('عضو'),
                Tables\Columns\TextColumn::make('reportedUser.profile.full_name')
                    ->label('المُبلَّغ عنه')
                    ->searchable()
                    ->placeholder('عضو'),
                Tables\Columns\TextColumn::make('reason_category')
                    ->label('سبب البلاغ')
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'inappropriate_behavior' => 'سلوك غير لائق',
                        'fake_profile' => 'ملف غير حقيقي',
                        'harassment' => 'إزعاج أو مضايقة',
                        'scam_attempt' => 'محاولة احتيال',
                        default => 'أخرى',
                    }),
                Tables\Columns\TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        UserReport::STATUS_PENDING => 'danger',
                        UserReport::STATUS_UNDER_REVIEW => 'warning',
                        UserReport::STATUS_RESOLVED => 'success',
                        UserReport::STATUS_REJECTED, UserReport::STATUS_DISMISSED => 'gray',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        UserReport::STATUS_PENDING => 'جديد (قيد الانتظار)',
                        UserReport::STATUS_UNDER_REVIEW => 'قيد المراجعة',
                        UserReport::STATUS_RESOLVED => 'تم الحل',
                        UserReport::STATUS_REJECTED, UserReport::STATUS_DISMISSED => 'مرفوض / محفوظ',
                        default => $state,
                    }),
                Tables\Columns\TextColumn::make('assignedModerator.name')
                    ->label('المشرف المسؤول')
                    ->placeholder('غير معين'),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('تاريخ الإرسال')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label('حالة البلاغ')
                    ->options([
                        UserReport::STATUS_PENDING => 'جديد (قيد الانتظار)',
                        UserReport::STATUS_UNDER_REVIEW => 'قيد المراجعة',
                        UserReport::STATUS_RESOLVED => 'تم الحل',
                        UserReport::STATUS_REJECTED => 'مرفوض',
                    ]),
                Tables\Filters\SelectFilter::make('reason_category')
                    ->label('تصنيف البلاغ')
                    ->options([
                        'inappropriate_behavior' => 'سلوك غير لائق',
                        'fake_profile' => 'ملف غير حقيقي',
                        'harassment' => 'إزعاج أو مضايقة',
                        'scam_attempt' => 'محاولة احتيال',
                        'other' => 'أخرى',
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('عرض البلاغ'),

                Tables\Actions\Action::make('handle_report')
                    ->label('اتخاذ إجراء')
                    ->icon('heroicon-o-clipboard-document-check')
                    ->color('primary')
                    ->requiresConfirmation()
                    ->form([
                        Select::make('status')
                            ->label('تحديث حالة البلاغ')
                            ->options([
                                UserReport::STATUS_UNDER_REVIEW => 'قيد المراجعة (Under Review)',
                                UserReport::STATUS_RESOLVED => 'تم الحل (Resolved)',
                                UserReport::STATUS_REJECTED => 'رفض البلاغ لعدم ثبوت المخالفة (Rejected)',
                            ])
                            ->required(),
                        Textarea::make('resolution_notes')
                            ->label('ملاحظات المشرف وقرار المراجعة (إلزامي)')
                            ->required()
                            ->minLength(4)
                            ->maxLength(1000),
                        Toggle::make('suspend_reported_member')
                            ->label('إيقاف حساب العضو المُبلَّغ عنه فوراً')
                            ->default(false),
                    ])
                    ->action(function (UserReport $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->handleReport(
                            actor: $actor,
                            report: $record,
                            newStatus: $data['status'],
                            resolutionNotes: $data['resolution_notes'],
                            suspendReportedMember: (bool) ($data['suspend_reported_member'] ?? false)
                        );

                        Notification::make()
                            ->title('تم حفظ قرار مراجعة البلاغ بنجاح')
                            ->success()
                            ->send();
                    }),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListUserReports::route('/'),
            'view' => Pages\ViewUserReport::route('/{record}'),
        ];
    }
}
