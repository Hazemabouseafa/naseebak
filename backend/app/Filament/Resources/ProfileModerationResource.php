<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ProfileModerationResource\Pages;
use App\Models\Administrator;
use App\Models\UserProfile;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Admin\AdminModerationService;
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
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\Auth;

class ProfileModerationResource extends Resource
{
    protected static ?string $model = UserProfile::class;
    protected static ?string $navigationIcon = 'heroicon-o-identification';
    protected static ?string $navigationLabel = 'مراجعة الملفات الشخصية';
    protected static ?string $modelLabel = 'ملف شخصي';
    protected static ?string $pluralModelLabel = 'مراجعة الملفات الشخصية';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_USERS;
    protected static ?int $navigationSort = 2;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['user', 'moderatedByAdmin']);
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
                Section::make('محتوى الملف الشخصي للمراجعة')
                    ->columns(3)
                    ->schema([
                        TextEntry::make('user_id')->label('معرف العضو'),
                        TextEntry::make('full_name')->label('الاسم الكامل'),
                        TextEntry::make('gender')
                            ->label('النوع')
                            ->formatStateUsing(fn (string $state) => $state === 'male' ? 'ذكر' : 'أنثى'),
                        TextEntry::make('age_years')->label('العمر'),
                        TextEntry::make('marital_status')->label('الحالة الاجتماعية'),
                        TextEntry::make('education_level')->label('المؤهل العلمي'),
                        TextEntry::make('occupation')->label('الوظيفة'),
                        TextEntry::make('nationality')->label('الجنسية'),
                        TextEntry::make('country_of_residence')->label('بلد الإقامة'),
                        TextEntry::make('region')->label('المنطقة / المحافظة'),
                        TextEntry::make('moderation_status')->label('حالة المراجعة الحالية'),
                        TextEntry::make('moderation_notes')->label('ملاحظات المشرف السابقة'),
                        TextEntry::make('bio')->label('النبذة التعريفية (Bio)')->columnSpanFull(),
                    ]),
                Section::make('سجل قرارات المراجعة السابقة')
                    ->schema([
                        RepeatableEntry::make('moderationHistories')
                            ->label('السجل التاريخي')
                            ->columns(4)
                            ->schema([
                                TextEntry::make('administrator.name')->label('المشرف'),
                                TextEntry::make('previous_status')->label('الحالة السابقة'),
                                TextEntry::make('new_status')->label('الحالة الجديدة'),
                                TextEntry::make('reason')->label('السبب / الملاحظات'),
                                TextEntry::make('created_at')->label('التاريخ')->dateTime('Y-m-d H:i'),
                            ]),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('user_id')
                    ->label('معرف العضو')
                    ->sortable(),
                Tables\Columns\TextColumn::make('full_name')
                    ->label('الاسم الكامل')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('gender')
                    ->label('النوع')
                    ->formatStateUsing(fn (string $state) => $state === 'male' ? 'ذكر' : 'أنثى'),
                Tables\Columns\TextColumn::make('age_years')
                    ->label('العمر')
                    ->sortable(),
                Tables\Columns\TextColumn::make('occupation')
                    ->label('الوظيفة')
                    ->searchable(),
                Tables\Columns\TextColumn::make('bio')
                    ->label('النبذة التعريفية')
                    ->limit(50),
                Tables\Columns\TextColumn::make('moderation_status')
                    ->label('حالة المراجعة')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        UserProfile::STATUS_APPROVED => 'success',
                        UserProfile::STATUS_PENDING => 'warning',
                        UserProfile::STATUS_CORRECTION_REQUESTED => 'info',
                        UserProfile::STATUS_REJECTED => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        UserProfile::STATUS_APPROVED => 'معتمد',
                        UserProfile::STATUS_PENDING => 'قيد المراجعة',
                        UserProfile::STATUS_CORRECTION_REQUESTED => 'مطلوب تعديل',
                        UserProfile::STATUS_REJECTED => 'مرفوض',
                        default => $state,
                    }),
                Tables\Columns\TextColumn::make('moderatedByAdmin.name')
                    ->label('تمت المراجعة بواسطة')
                    ->placeholder('لم يُراجع بعد'),
                Tables\Columns\TextColumn::make('updated_at')
                    ->label('آخر تحديث')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('moderation_status')
                    ->label('حالة المراجعة')
                    ->default(UserProfile::STATUS_PENDING)
                    ->options([
                        UserProfile::STATUS_PENDING => 'قيد المراجعة',
                        UserProfile::STATUS_CORRECTION_REQUESTED => 'مطلوب تعديل',
                        UserProfile::STATUS_APPROVED => 'معتمد',
                        UserProfile::STATUS_REJECTED => 'مرفوض',
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('فحص الملف'),

                Tables\Actions\Action::make('approve')
                    ->label('اعتماد الملف')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn (UserProfile $record) => $record->moderation_status !== UserProfile::STATUS_APPROVED)
                    ->action(function (UserProfile $record, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->moderateProfile($actor, $record, UserProfile::STATUS_APPROVED);

                        Notification::make()
                            ->title('تم اعتماد الملف الشخصي بنجاح')
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('request_correction')
                    ->label('طلب تعديل البيانات')
                    ->icon('heroicon-o-pencil-square')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->form([
                        Textarea::make('reason')
                            ->label('التعديلات المطلوبة من العضو (إلزامي)')
                            ->required()
                            ->minLength(4)
                            ->maxLength(500),
                    ])
                    ->action(function (UserProfile $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->moderateProfile(
                            $actor,
                            $record,
                            UserProfile::STATUS_CORRECTION_REQUESTED,
                            $data['reason']
                        );

                        Notification::make()
                            ->title('تم إرسال طلب تعديل البيانات للعضو')
                            ->warning()
                            ->send();
                    }),

                Tables\Actions\Action::make('reject')
                    ->label('رفض الملف')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->form([
                        Textarea::make('reason')
                            ->label('سبب رفض الملف الشخصي (إلزامي)')
                            ->required()
                            ->minLength(4)
                            ->maxLength(500),
                    ])
                    ->action(function (UserProfile $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->moderateProfile(
                            $actor,
                            $record,
                            UserProfile::STATUS_REJECTED,
                            $data['reason']
                        );

                        Notification::make()
                            ->title('تم رفض الملف الشخصي وإخفاؤه من البحث')
                            ->danger()
                            ->send();
                    }),
            ])
            ->bulkActions([
                Tables\Actions\BulkAction::make('approve_selected')
                    ->label('اعتماد الملفات المحددة')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->action(function (Collection $records, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $approvedCount = 0;

                        foreach ($records as $profile) {
                            if ($profile instanceof UserProfile && $profile->moderation_status !== UserProfile::STATUS_APPROVED) {
                                $service->moderateProfile($actor, $profile, UserProfile::STATUS_APPROVED);
                                $approvedCount++;
                            }
                        }

                        Notification::make()
                            ->title("تم اعتماد {$approvedCount} ملف شخصي بنجاح")
                            ->success()
                            ->send();
                    }),
            ])
            ->defaultSort('updated_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListProfileModerations::route('/'),
            'view' => Pages\ViewProfileModeration::route('/{record}'),
        ];
    }
}
