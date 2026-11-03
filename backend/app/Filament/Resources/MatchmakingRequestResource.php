<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MatchmakingRequestResource\Pages;
use App\Models\MatchmakingRequest;
use App\Providers\Filament\AdminPanelProvider;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class MatchmakingRequestResource extends Resource
{
    protected static ?string $model = MatchmakingRequest::class;
    protected static ?string $navigationIcon = 'heroicon-o-heart';
    protected static ?string $navigationLabel = 'طلبات التعارف';
    protected static ?string $modelLabel = 'طلب تعارف';
    protected static ?string $pluralModelLabel = 'طلبات التعارف';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_USERS;
    protected static ?int $navigationSort = 5;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['sender.profile', 'recipient.profile', 'conversation']);
    }

    public static function getNavigationBadge(): ?string
    {
        $pendingCount = MatchmakingRequest::where('status', MatchmakingRequest::STATUS_PENDING)->count();
        return $pendingCount > 0 ? (string) $pendingCount : null;
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return 'warning';
    }

    /**
     * Administrators and moderators are strictly prohibited from creating or impersonating matchmaking requests.
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
                    ->label('رقم الطلب')
                    ->sortable(),
                Tables\Columns\TextColumn::make('sender.profile.full_name')
                    ->label('المرسل')
                    ->searchable()
                    ->placeholder('عضو'),
                Tables\Columns\TextColumn::make('recipient.profile.full_name')
                    ->label('المستلم')
                    ->searchable()
                    ->placeholder('عضو'),
                Tables\Columns\TextColumn::make('status')
                    ->label('حالة الطلب')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'accepted' => 'success',
                        'pending' => 'warning',
                        'rejected', 'cancelled' => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'pending' => 'قيد الانتظار',
                        'accepted' => 'مقبول',
                        'rejected' => 'مرفوض',
                        'cancelled' => 'ملغى',
                        default => $state,
                    }),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('تاريخ الإرسال')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
                Tables\Columns\TextColumn::make('responded_at')
                    ->label('تاريخ الرد')
                    ->dateTime('Y-m-d H:i')
                    ->placeholder('لم يتم الرد بعد'),
                Tables\Columns\TextColumn::make('conversation.id')
                    ->label('رقم المحادثة المرتبطة')
                    ->placeholder('غير منشأة'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label('حالة الطلب')
                    ->options([
                        'pending' => 'قيد الانتظار',
                        'accepted' => 'مقبول',
                        'rejected' => 'مرفوض',
                        'cancelled' => 'ملغى',
                    ]),
            ])
            ->actions([])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListMatchmakingRequests::route('/'),
        ];
    }
}
