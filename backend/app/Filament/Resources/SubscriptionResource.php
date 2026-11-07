<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SubscriptionResource\Pages;
use App\Models\Administrator;
use App\Models\Subscription;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Admin\AdminModerationService;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

class SubscriptionResource extends Resource
{
    protected static ?string $model = Subscription::class;
    protected static ?string $navigationIcon = 'heroicon-o-credit-card';
    protected static ?string $navigationLabel = 'الاشتراكات';
    protected static ?string $modelLabel = 'اشتراك';
    protected static ?string $pluralModelLabel = 'الاشتراكات';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_BILLING;
    protected static ?int $navigationSort = 1;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['user.profile', 'plan']);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit($record): bool
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
                    ->label('رقم الاشتراك')
                    ->sortable(),
                Tables\Columns\TextColumn::make('user.profile.full_name')
                    ->label('العضو')
                    ->searchable()
                    ->placeholder('عضو'),
                Tables\Columns\TextColumn::make('user.email')
                    ->label('البريد الإلكتروني')
                    ->searchable()
                    ->toggleable(),
                Tables\Columns\TextColumn::make('plan.name_ar')
                    ->label('الباقة'),
                Tables\Columns\TextColumn::make('channel')
                    ->label('قناة الدفع / التفعيل')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        Subscription::CHANNEL_GOOGLE_PLAY => 'Google Play Billing',
                        Subscription::CHANNEL_PAYMOB => 'Paymob (ويب)',
                        Subscription::CHANNEL_SHA7NAWY => 'Sha7nawy (ويب)',
                        Subscription::CHANNEL_ADMIN_MANUAL => 'تفعيل يدوي (الإدارة)',
                        default => $state,
                    }),
                Tables\Columns\TextColumn::make('status')
                    ->label('حالة الاشتراك')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        Subscription::STATUS_ACTIVE => 'success',
                        Subscription::STATUS_IN_GRACE_PERIOD, Subscription::STATUS_GRACE_PERIOD_ALIAS, Subscription::STATUS_CANCELLED => 'warning',
                        Subscription::STATUS_PENDING, Subscription::STATUS_PENDING_PAYMENT, Subscription::STATUS_ON_HOLD => 'info',
                        Subscription::STATUS_EXPIRED, Subscription::STATUS_REFUNDED, Subscription::STATUS_REVOKED => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        Subscription::STATUS_ACTIVE => 'نشط',
                        Subscription::STATUS_IN_GRACE_PERIOD, Subscription::STATUS_GRACE_PERIOD_ALIAS => 'فترة سماح',
                        Subscription::STATUS_ON_HOLD => 'معلق (On Hold)',
                        Subscription::STATUS_PENDING, Subscription::STATUS_PENDING_PAYMENT => 'بانتظار الدفع',
                        Subscription::STATUS_CANCELLED => 'ملغى التجديد (ساري لنهاية الفترة)',
                        Subscription::STATUS_EXPIRED => 'منتهي',
                        Subscription::STATUS_REFUNDED => 'مسترد',
                        Subscription::STATUS_REVOKED => 'مسحوب',
                        default => $state,
                    }),
                Tables\Columns\IconColumn::make('auto_renewing')
                    ->label('تجديد تلقائي')
                    ->boolean(),
                Tables\Columns\TextColumn::make('starts_at')
                    ->label('تاريخ البدء')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
                Tables\Columns\TextColumn::make('ends_at')
                    ->label('نهاية الفترة الحالية')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
                Tables\Columns\TextColumn::make('last_verified_at')
                    ->label('آخر تحقق / تفعيل')
                    ->dateTime('Y-m-d H:i')
                    ->placeholder('-'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label('حالة الاشتراك')
                    ->options([
                        Subscription::STATUS_ACTIVE => 'نشط',
                        Subscription::STATUS_IN_GRACE_PERIOD => 'فترة سماح',
                        Subscription::STATUS_ON_HOLD => 'معلق (On Hold)',
                        Subscription::STATUS_PENDING => 'بانتظار الدفع',
                        Subscription::STATUS_CANCELLED => 'ملغى التجديد',
                        Subscription::STATUS_EXPIRED => 'منتهي',
                        Subscription::STATUS_REFUNDED => 'مسترد',
                        Subscription::STATUS_REVOKED => 'مسحوب',
                    ]),
                Tables\Filters\SelectFilter::make('channel')
                    ->label('قناة الدفع / التفعيل')
                    ->options([
                        Subscription::CHANNEL_ADMIN_MANUAL => 'تفعيل يدوي (الإدارة)',
                        Subscription::CHANNEL_GOOGLE_PLAY => 'Google Play Billing',
                        Subscription::CHANNEL_PAYMOB => 'Paymob',
                        Subscription::CHANNEL_SHA7NAWY => 'Sha7nawy',
                    ]),
            ])
            ->actions([
                Tables\Actions\Action::make('extend_manual')
                    ->label('تفعيل / تمديد يدوياً')
                    ->icon('heroicon-o-sparkles')
                    ->color('warning')
                    ->form([
                        Select::make('duration_days')
                            ->label('مدة التفعيل / التمديد')
                            ->options([
                                30 => 'شهر واحد (30 يوم)',
                                90 => '3 أشهر (90 يوم)',
                                180 => '6 أشهر (180 يوم)',
                                365 => 'سنة كاملة (365 يوم)',
                            ])
                            ->default(30)
                            ->required(),
                        Textarea::make('notes')
                            ->label('ملاحظات (اختياري)')
                            ->maxLength(500),
                    ])
                    ->action(function (Subscription $record, array $data, AdminModerationService $service) {
                        if (!$record->user) {
                            return;
                        }
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $sub = $service->activateManualSubscription(
                            actor: $actor,
                            member: $record->user,
                            durationDays: (int) ($data['duration_days'] ?? 30),
                            notes: $data['notes'] ?? null,
                        );

                        Notification::make()
                            ->title('تم تفعيل / تمديد الاشتراك بنجاح حتى ' . $sub->ends_at?->format('Y-m-d'))
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('revoke_subscription_row')
                    ->label('إلغاء الاشتراك')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->visible(fn (Subscription $record): bool => $record->isCurrentlyEntitled())
                    ->form([
                        Textarea::make('reason')
                            ->label('سبب الإلغاء')
                            ->default('إلغاء الاشتراك يدوياً من لوحة التحكم')
                            ->required()
                            ->maxLength(500),
                    ])
                    ->action(function (Subscription $record, array $data, AdminModerationService $service) {
                        if (!$record->user) {
                            return;
                        }
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->revokeMemberSubscriptions($actor, $record->user, $data['reason']);

                        Notification::make()
                            ->title('تم إلغاء الاشتراك بنجاح')
                            ->success()
                            ->send();
                    }),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSubscriptions::route('/'),
        ];
    }
}
