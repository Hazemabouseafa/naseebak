<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AdminAuditLogResource\Pages;
use App\Models\AdminAuditLog;
use App\Providers\Filament\AdminPanelProvider;
use Filament\Infolists\Components\KeyValueEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class AdminAuditLogResource extends Resource
{
    protected static ?string $model = AdminAuditLog::class;
    protected static ?string $navigationIcon = 'heroicon-o-clipboard-document-list';
    protected static ?string $navigationLabel = 'سجل النشاط الإداري';
    protected static ?string $modelLabel = 'سجل نشاط إداري';
    protected static ?string $pluralModelLabel = 'سجل النشاط الإداري';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_SYSTEM;
    protected static ?int $navigationSort = 3;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['administrator', 'adminUser']);
    }

    /**
     * Audit logs are strictly append-only and cannot be created, edited, or deleted from the UI.
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

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Section::make('تفاصيل العملية الإدارية المسجلة (غير قابلة للتعديل أو الحذف)')
                    ->columns(3)
                    ->schema([
                        TextEntry::make('id')->label('رقم السجل'),
                        TextEntry::make('administrator.name')
                            ->label('المدير / المشرف المنفذ')
                            ->placeholder('حساب نظام'),
                        TextEntry::make('action')->label('نوع العملية (Action)'),
                        TextEntry::make('target_type')->label('نوع الكيان المستهدف'),
                        TextEntry::make('target_id')->label('معرف الكيان المستهدف'),
                        TextEntry::make('ip_address')->label('عنوان IP'),
                        TextEntry::make('created_at')->label('توقيت التنفيذ')->dateTime('Y-m-d H:i:s'),
                        TextEntry::make('justification')->label('السبب / المبرر المسجل')->columnSpanFull(),
                        KeyValueEntry::make('previous_values')->label('القيم السابقة')->columnSpan(1),
                        KeyValueEntry::make('new_values')->label('القيم الجديدة')->columnSpan(2),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('رقم السجل')
                    ->sortable(),
                Tables\Columns\TextColumn::make('administrator.name')
                    ->label('المدير / المشرف')
                    ->searchable()
                    ->placeholder('نظام'),
                Tables\Columns\TextColumn::make('action')
                    ->label('العملية المنفذة')
                    ->badge()
                    ->searchable(),
                Tables\Columns\TextColumn::make('target_type')
                    ->label('الكيان المستهدف')
                    ->formatStateUsing(fn (?string $state) => $state ? class_basename($state) : '-'),
                Tables\Columns\TextColumn::make('target_id')
                    ->label('معرف الهدف')
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('justification')
                    ->label('السبب / التوضيح')
                    ->limit(50)
                    ->searchable(),
                Tables\Columns\TextColumn::make('ip_address')
                    ->label('عنوان IP')
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('التوقيت')
                    ->dateTime('Y-m-d H:i:s')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('action')
                    ->label('نوع العملية')
                    ->options([
                        'member.suspended' => 'إيقاف عضو',
                        'member.restored' => 'إعادة تفعيل عضو',
                        'profile.approved' => 'اعتماد ملف شخصي',
                        'profile.rejected' => 'رفض ملف شخصي',
                        'profile.correction_requested' => 'طلب تعديل ملف شخصي',
                        'photo.approved' => 'اعتماد صورة شخصية',
                        'photo.rejected' => 'رفض صورة شخصية',
                        'photo.removed' => 'حذف صورة مخالفة',
                        'report.under_review' => 'وضع بلاغ قيد المراجعة',
                        'report.resolved' => 'حل بلاغ',
                        'report.rejected' => 'رفض بلاغ',
                        'payment_gateway.switched' => 'تبديل بوابة الدفع',
                        'subscription_pricing.updated' => 'تحديث سعر الاشتراك',
                        'app_setting.updated' => 'تحديث إعدادات التطبيق',
                        'administrator.created' => 'إنشاء مدير / مشرف',
                        'administrator.updated' => 'تحديث صلاحية مدير / مشرف',
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('عرض التفاصيل'),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListAdminAuditLogs::route('/'),
            'view' => Pages\ViewAdminAuditLog::route('/{record}'),
        ];
    }
}
