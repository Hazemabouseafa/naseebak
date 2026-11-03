<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PhotoModerationResource\Pages;
use App\Models\Administrator;
use App\Models\UserPhoto;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Admin\AdminModerationService;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

class PhotoModerationResource extends Resource
{
    protected static ?string $model = UserPhoto::class;
    protected static ?string $navigationIcon = 'heroicon-o-photo';
    protected static ?string $navigationLabel = 'مراجعة الصور';
    protected static ?string $modelLabel = 'صورة شخصية';
    protected static ?string $pluralModelLabel = 'مراجعة الصور الشخصية';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_USERS;
    protected static ?int $navigationSort = 3;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['user.profile', 'moderatedByAdmin']);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canDelete($record): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('رقم الصورة')
                    ->sortable(),
                Tables\Columns\ImageColumn::make('preview')
                    ->label('معاينة الصورة (تخزين خاص)')
                    ->getStateUsing(fn (UserPhoto $record) => route('admin.operations.photos.stream', ['photo' => $record->id]))
                    ->height(64)
                    ->circular(),
                Tables\Columns\TextColumn::make('user.profile.full_name')
                    ->label('اسم العضو')
                    ->searchable()
                    ->placeholder('عضو بدون ملف'),
                Tables\Columns\TextColumn::make('user_id')
                    ->label('معرف العضو')
                    ->sortable(),
                Tables\Columns\TextColumn::make('user.profile.photo_privacy')
                    ->label('إعداد خصوصية العضو')
                    ->formatStateUsing(fn (?string $state) => match ($state) {
                        'public' => 'للجميع',
                        'subscribers_only' => 'للمشتركين فقط',
                        'accepted_matches_only' => 'بعد قبول التعارف فقط',
                        default => '-',
                    }),
                Tables\Columns\TextColumn::make('moderation_status')
                    ->label('حالة المراجعة')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        UserPhoto::STATUS_APPROVED => 'success',
                        UserPhoto::STATUS_PENDING => 'warning',
                        UserPhoto::STATUS_REJECTED => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        UserPhoto::STATUS_APPROVED => 'معتمدة',
                        UserPhoto::STATUS_PENDING => 'قيد المراجعة',
                        UserPhoto::STATUS_REJECTED => 'مرفوضة',
                        default => $state,
                    }),
                Tables\Columns\TextColumn::make('moderation_notes')
                    ->label('ملاحظات المشرف')
                    ->limit(40)
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('moderatedByAdmin.name')
                    ->label('المشرف المراجع')
                    ->placeholder('لم تُراجع بعد'),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('تاريخ الرفع')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('moderation_status')
                    ->label('حالة المراجعة')
                    ->default(UserPhoto::STATUS_PENDING)
                    ->options([
                        UserPhoto::STATUS_PENDING => 'قيد المراجعة',
                        UserPhoto::STATUS_APPROVED => 'معتمدة',
                        UserPhoto::STATUS_REJECTED => 'مرفوضة',
                    ]),
            ])
            ->actions([
                Tables\Actions\Action::make('approve_photo')
                    ->label('اعتماد الصورة')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn (UserPhoto $record) => $record->moderation_status !== UserPhoto::STATUS_APPROVED)
                    ->action(function (UserPhoto $record, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->moderatePhoto($actor, $record, UserPhoto::STATUS_APPROVED);

                        Notification::make()
                            ->title('تم اعتماد الصورة الشخصية بنجاح')
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('reject_photo')
                    ->label('رفض الصورة')
                    ->icon('heroicon-o-x-circle')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->form([
                        Textarea::make('reason')
                            ->label('سبب رفض الصورة (إلزامي)')
                            ->required()
                            ->minLength(4)
                            ->maxLength(500),
                    ])
                    ->action(function (UserPhoto $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->moderatePhoto($actor, $record, UserPhoto::STATUS_REJECTED, $data['reason']);

                        Notification::make()
                            ->title('تم رفض الصورة وإخفاؤها عن الأعضاء')
                            ->warning()
                            ->send();
                    }),

                Tables\Actions\Action::make('remove_photo')
                    ->label('حذف الصورة المخالفة نهائياً')
                    ->icon('heroicon-o-trash')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('حذف الصورة المخالفة نهائياً من الخادم')
                    ->modalDescription('سيتم مسح ملف الصورة من وحدة التخزين الخاصة وتسجيل العملية في سجل النشاط الإداري.')
                    ->form([
                        Textarea::make('reason')
                            ->label('سبب الحذف النهائي للصورة (إلزامي)')
                            ->required()
                            ->minLength(4)
                            ->maxLength(500),
                    ])
                    ->action(function (UserPhoto $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->removeProhibitedPhoto($actor, $record, $data['reason']);

                        Notification::make()
                            ->title('تم حذف الصورة المخالفة نهائياً من الخادم')
                            ->danger()
                            ->send();
                    }),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPhotoModerations::route('/'),
        ];
    }
}
