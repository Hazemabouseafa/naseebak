<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PaymentTransactionResource\Pages;
use App\Models\PaymentTransaction;
use App\Providers\Filament\AdminPanelProvider;
use Filament\Forms\Components\DatePicker;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class PaymentTransactionResource extends Resource
{
    protected static ?string $model = PaymentTransaction::class;
    protected static ?string $navigationIcon = 'heroicon-o-banknotes';
    protected static ?string $navigationLabel = 'سجل المدفوعات';
    protected static ?string $modelLabel = 'عملية دفع';
    protected static ?string $pluralModelLabel = 'سجل المدفوعات';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_BILLING;
    protected static ?int $navigationSort = 3;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['user.profile', 'subscription']);
    }

    /**
     * Payment transaction logs are strictly read-only financial records.
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
                    ->label('رقم العملية')
                    ->sortable()
                    ->searchable(),
                Tables\Columns\TextColumn::make('internal_reference')
                    ->label('المرجع الداخلي')
                    ->searchable()
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('gateway_transaction_id')
                    ->label('معرف عملية البوابة')
                    ->searchable()
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('user.profile.full_name')
                    ->label('العضو')
                    ->searchable()
                    ->placeholder('عضو'),
                Tables\Columns\TextColumn::make('gateway')
                    ->label('مزود الدفع')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'google_play' => 'Google Play',
                        'paymob' => 'Paymob',
                        'sha7nawy' => 'Sha7nawy',
                        default => $state,
                    }),
                Tables\Columns\TextColumn::make('amount')
                    ->label('المبلغ')
                    ->formatStateUsing(fn ($state, PaymentTransaction $record) => $state !== null
                        ? number_format((float) $state, 2) . ' ' . ($record->currency ?? 'EGP')
                        : 'سعر متجر Google Play'),
                Tables\Columns\TextColumn::make('status')
                    ->label('حالة الدفع')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'succeeded' => 'success',
                        'pending' => 'warning',
                        'failed', 'refunded', 'disputed' => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'succeeded' => 'ناجحة',
                        'pending' => 'قيد المعالجة',
                        'failed' => 'فاشلة',
                        'refunded' => 'مستردة',
                        'disputed' => 'متنازع عليها',
                        default => $state,
                    }),
                Tables\Columns\IconColumn::make('signature_verified')
                    ->label('توقيع رقمي موثق')
                    ->boolean(),
                Tables\Columns\TextColumn::make('verified_at')
                    ->label('تاريخ التوثيق')
                    ->dateTime('Y-m-d H:i')
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('تاريخ الإنشاء')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('gateway')
                    ->label('بوابة الدفع')
                    ->options([
                        'google_play' => 'Google Play',
                        'paymob' => 'Paymob',
                        'sha7nawy' => 'Sha7nawy',
                    ]),
                Tables\Filters\SelectFilter::make('status')
                    ->label('حالة العملية')
                    ->options([
                        'succeeded' => 'ناجحة',
                        'pending' => 'قيد المعالجة',
                        'failed' => 'فاشلة',
                        'refunded' => 'مستردة',
                    ]),
                Tables\Filters\TernaryFilter::make('signature_verified')
                    ->label('حالة التوقيع الرقمي'),
                Tables\Filters\Filter::make('created_at')
                    ->label('نطاق التاريخ')
                    ->form([
                        DatePicker::make('from')->label('من تاريخ'),
                        DatePicker::make('until')->label('إلى تاريخ'),
                    ])
                    ->query(function (Builder $query, array $data): Builder {
                        return $query
                            ->when($data['from'] ?? null, fn (Builder $q, $date) => $q->whereDate('created_at', '>=', $date))
                            ->when($data['until'] ?? null, fn (Builder $q, $date) => $q->whereDate('created_at', '<=', $date));
                    }),
            ])
            ->actions([])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPaymentTransactions::route('/'),
        ];
    }
}
