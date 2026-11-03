<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SubscriptionResource\Pages;
use App\Models\Subscription;
use App\Providers\Filament\AdminPanelProvider;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

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

    /**
     * Subscription entitlements are granted exclusively by verified payment flows, never manually created.
     */
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
                Tables\Columns\TextColumn::make('plan.name_ar')
                    ->label('الباقة'),
                Tables\Columns\TextColumn::make('channel')
                    ->label('قناة الدفع')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        Subscription::CHANNEL_GOOGLE_PLAY => 'Google Play Billing',
                        Subscription::CHANNEL_PAYMOB => 'Paymob (ويب)',
                        Subscription::CHANNEL_SHA7NAWY => 'Sha7nawy (ويب)',
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
                    ->label('آخر تحقق رسمي')
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
                    ->label('قناة الدفع')
                    ->options([
                        Subscription::CHANNEL_GOOGLE_PLAY => 'Google Play Billing',
                        Subscription::CHANNEL_PAYMOB => 'Paymob',
                        Subscription::CHANNEL_SHA7NAWY => 'Sha7nawy',
                    ]),
            ])
            ->actions([])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSubscriptions::route('/'),
        ];
    }
}
