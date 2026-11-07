<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MemberResource\Pages;
use App\Models\Administrator;
use App\Models\User;
use App\Models\UserProfile;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Admin\AdminModerationService;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
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

class MemberResource extends Resource
{
    protected static ?string $model = User::class;
    protected static ?string $navigationIcon = 'heroicon-o-users';
    protected static ?string $navigationLabel = 'إدارة الأعضاء';
    protected static ?string $modelLabel = 'عضو';
    protected static ?string $pluralModelLabel = 'الأعضاء';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_USERS;
    protected static ?int $navigationSort = 1;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->where('role', 'member')
            ->with(['profile', 'activeSubscription']);
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
        /** @var ?Administrator $admin */
        $admin = Auth::guard('admin')->user();
        $canViewPrivateEmail = $admin && $admin->isSuperAdmin();

        return $infolist
            ->schema([
                Section::make('بيانات الحساب والعضوية')
                    ->columns(3)
                    ->schema([
                        TextEntry::make('id')->label('معرف العضو'),
                        TextEntry::make('profile.full_name')->label('الاسم الكامل'),
                        TextEntry::make('email')
                            ->label('البريد الإلكتروني (للمدير العام فقط)')
                            ->visible($canViewPrivateEmail),
                        TextEntry::make('account_status')
                            ->label('حالة الحساب')
                            ->badge()
                            ->formatStateUsing(fn (string $state) => match ($state) {
                                'active' => 'نشط',
                                'suspended' => 'موقوف',
                                'pending_deletion' => 'قيد الحذف',
                                default => $state,
                            }),
                        TextEntry::make('suspension_reason')
                            ->label('سبب الإيقاف')
                            ->visible(fn (User $record) => $record->account_status === 'suspended'),
                        TextEntry::make('created_at')->label('تاريخ التسجيل')->dateTime('Y-m-d H:i'),
                    ]),
                Section::make('الملف الشخصي')
                    ->columns(3)
                    ->schema([
                        TextEntry::make('profile.gender')
                            ->label('النوع')
                            ->formatStateUsing(fn (?string $state) => $state === 'male' ? 'ذكر' : ($state === 'female' ? 'أنثى' : '-')),
                        TextEntry::make('profile.age_years')->label('العمر (سنة)'),
                        TextEntry::make('profile.marital_status')->label('الحالة الاجتماعية'),
                        TextEntry::make('profile.education_level')->label('المؤهل الدراسي'),
                        TextEntry::make('profile.occupation')->label('الوظيفة'),
                        TextEntry::make('profile.nationality')->label('الجنسية'),
                        TextEntry::make('profile.country_of_residence')->label('بلد الإقامة'),
                        TextEntry::make('profile.region')->label('المنطقة / المحافظة'),
                        TextEntry::make('profile.moderation_status')->label('حالة مراجعة الملف'),
                        TextEntry::make('profile.bio')->label('النبذة التعريفية')->columnSpanFull(),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        /** @var ?Administrator $admin */
        $admin = Auth::guard('admin')->user();
        $isSuperAdmin = $admin && $admin->isSuperAdmin();

        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('المعرف')
                    ->sortable()
                    ->searchable(),
                Tables\Columns\TextColumn::make('profile.full_name')
                    ->label('الاسم الكامل')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('email')
                    ->label('البريد الإلكتروني')
                    ->searchable($isSuperAdmin)
                    ->toggleable(isToggledHiddenByDefault: !$isSuperAdmin)
                    ->visible($isSuperAdmin),
                Tables\Columns\TextColumn::make('profile.gender')
                    ->label('النوع')
                    ->formatStateUsing(fn (?string $state) => $state === 'male' ? 'ذكر' : ($state === 'female' ? 'أنثى' : 'غير مكتمل')),
                Tables\Columns\TextColumn::make('profile.age_years')
                    ->label('العمر')
                    ->sortable(),
                Tables\Columns\TextColumn::make('profile.marital_status')
                    ->label('الحالة الاجتماعية')
                    ->formatStateUsing(fn (?string $state) => match ($state) {
                        'single' => 'أعزب / عزباء',
                        'divorced' => 'مطلق / مطلقة',
                        'widowed' => 'أرمل / أرملة',
                        default => $state ?? '-',
                    }),
                Tables\Columns\TextColumn::make('profile.country_of_residence')
                    ->label('البلد / المحافظة')
                    ->formatStateUsing(fn (?string $state, User $record) => trim(($state ?? '') . ' - ' . ($record->profile?->region ?? ''), ' -')),
                Tables\Columns\TextColumn::make('profile.moderation_status')
                    ->label('حالة الملف')
                    ->badge()
                    ->color(fn (?string $state): string => match ($state) {
                        'approved' => 'success',
                        'pending' => 'warning',
                        'correction_requested' => 'info',
                        'rejected' => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (?string $state) => match ($state) {
                        'approved' => 'معتمد',
                        'pending' => 'قيد المراجعة',
                        'correction_requested' => 'مطلوب تعديل',
                        'rejected' => 'مرفوض',
                        default => 'غير مكتمل',
                    }),
                Tables\Columns\TextColumn::make('account_status')
                    ->label('حالة الحساب')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'active' => 'success',
                        'suspended' => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'active' => 'نشط',
                        'suspended' => 'موقوف',
                        default => $state,
                    }),
                Tables\Columns\IconColumn::make('profile.is_visible')
                    ->label('الظهور في البحث')
                    ->boolean()
                    ->getStateUsing(fn (User $record): bool => $record->account_status === 'active'
                        && (bool) $record->profile_completed
                        && ($record->profile?->isDiscoverableByMembers() ?? false)),
                Tables\Columns\IconColumn::make('activeSubscription.id')
                    ->label('اشتراك فعال')
                    ->boolean()
                    ->getStateUsing(fn (User $record): bool => $record->hasActiveSubscription()),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('تاريخ التسجيل')
                    ->dateTime('Y-m-d')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('account_status')
                    ->label('حالة الحساب')
                    ->options([
                        'active' => 'نشط',
                        'suspended' => 'موقوف',
                    ]),
                Tables\Filters\SelectFilter::make('gender')
                    ->label('النوع')
                    ->options([
                        'male' => 'ذكر',
                        'female' => 'أنثى',
                    ])
                    ->query(fn (Builder $query, array $data) => !empty($data['value'])
                        ? $query->whereHas('profile', fn ($q) => $q->where('gender', $data['value']))
                        : $query),
                Tables\Filters\SelectFilter::make('moderation_status')
                    ->label('حالة مراجعة الملف')
                    ->options([
                        'pending' => 'قيد المراجعة',
                        'approved' => 'معتمد',
                        'correction_requested' => 'مطلوب تعديل',
                        'rejected' => 'مرفوض',
                    ])
                    ->query(fn (Builder $query, array $data) => !empty($data['value'])
                        ? $query->whereHas('profile', fn ($q) => $q->where('moderation_status', $data['value']))
                        : $query),
                Tables\Filters\TernaryFilter::make('subscribed')
                    ->label('حالة الاشتراك')
                    ->queries(
                        true: fn (Builder $query) => $query->whereHas('subscriptions', fn ($q) => $q->whereIn('status', ['active', 'grace_period'])->where('ends_at', '>', now())),
                        false: fn (Builder $query) => $query->whereDoesntHave('subscriptions', fn ($q) => $q->whereIn('status', ['active', 'grace_period'])->where('ends_at', '>', now())),
                    ),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('عرض التفاصيل'),

                Tables\Actions\Action::make('approve_profile')
                    ->label('اعتماد الملف')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('اعتماد الملف الشخصي للعضو')
                    ->modalDescription('سيؤدي اعتماد الملف الشخصي إلى إظهار العضو فوراً في نتائج البحث والاكتشاف للأعضاء المؤهلين.')
                    ->visible(fn (User $record): bool => $record->profile !== null
                        && $record->profile->moderation_status !== UserProfile::STATUS_APPROVED)
                    ->action(function (User $record, AdminModerationService $service) {
                        if (!$record->profile) {
                            return;
                        }
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->moderateProfile($actor, $record->profile, UserProfile::STATUS_APPROVED);

                        Notification::make()
                            ->title('تم اعتماد الملف الشخصي وتفعيله في البحث بنجاح')
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('activate_manual_subscription')
                    ->label(fn (User $record): string => $record->hasActiveSubscription()
                        ? 'تمديد الاشتراك يدوياً'
                        : 'تفعيل اشتراك يدوي')
                    ->icon('heroicon-o-sparkles')
                    ->color('warning')
                    ->modalHeading(fn (User $record): string => $record->hasActiveSubscription()
                        ? 'تمديد اشتراك العضو يدوياً'
                        : 'تفعيل اشتراك يدوي للعضو')
                    ->modalDescription('يتيح هذا الإجراء منح العضو صلاحيات العضوية المميزة (إرسال طلبات التعارف والمحادثة الخاصة) فوراً.')
                    ->form([
                        Select::make('duration_days')
                            ->label('مدة الاشتراك')
                            ->options([
                                30 => 'شهر واحد (30 يوم)',
                                90 => '3 أشهر (90 يوم)',
                                180 => '6 أشهر (180 يوم)',
                                365 => 'سنة كاملة (365 يوم)',
                            ])
                            ->default(30)
                            ->required(),
                        Textarea::make('notes')
                            ->label('ملاحظات التفعيل الإداري (اختياري)')
                            ->placeholder('مثال: تفعيل اشتراك يدوي بعد التحويل أو كمنحة إدارية')
                            ->maxLength(500),
                    ])
                    ->action(function (User $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $sub = $service->activateManualSubscription(
                            actor: $actor,
                            member: $record,
                            durationDays: (int) ($data['duration_days'] ?? 30),
                            notes: $data['notes'] ?? null,
                        );

                        Notification::make()
                            ->title('تم تفعيل الاشتراك اليدوي للعضو بنجاح حتى ' . $sub->ends_at?->format('Y-m-d'))
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('revoke_subscription')
                    ->label('إلغاء الاشتراك')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('إلغاء الاشتراك الفعال للعضو')
                    ->modalDescription('سيتم إيقاف الاشتراك الفعال للعضو فوراً.')
                    ->visible(fn (User $record): bool => $record->hasActiveSubscription())
                    ->form([
                        Textarea::make('reason')
                            ->label('سبب إلغاء الاشتراك')
                            ->default('إلغاء الاشتراك يدوياً بواسطة الإدارة')
                            ->required()
                            ->maxLength(500),
                    ])
                    ->action(function (User $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->revokeMemberSubscriptions($actor, $record, $data['reason']);

                        Notification::make()
                            ->title('تم إلغاء اشتراك العضو بنجاح')
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('suspend')
                    ->label('إيقاف الحساب')
                    ->icon('heroicon-o-no-symbol')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('إيقاف حساب العضو')
                    ->modalDescription('سيؤدي هذا الإجراء إلى إيقاف الحساب فوراً وإخفائه من البحث وإلغاء جلسات الدخول النشطة.')
                    ->visible(fn (User $record) => $record->account_status === 'active')
                    ->form([
                        Textarea::make('reason')
                            ->label('سبب الإيقاف (إلزامي)')
                            ->required()
                            ->minLength(5)
                            ->maxLength(500),
                    ])
                    ->action(function (User $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->suspendMember($actor, $record, $data['reason']);

                        Notification::make()
                            ->title('تم إيقاف حساب العضو بنجاح')
                            ->success()
                            ->send();
                    }),

                Tables\Actions\Action::make('restore')
                    ->label('إعادة تفعيل الحساب')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn (User $record) => $record->account_status === 'suspended')
                    ->form([
                        Textarea::make('notes')
                            ->label('ملاحظات إعادة التفعيل')
                            ->maxLength(500),
                    ])
                    ->action(function (User $record, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $service->restoreMember($actor, $record, $data['notes'] ?? null);

                        Notification::make()
                            ->title('تمت إعادة تفعيل حساب العضو بنجاح')
                            ->success()
                            ->send();
                    }),
            ])
            ->bulkActions([
                Tables\Actions\BulkAction::make('approve_selected_profiles')
                    ->label('اعتماد الملفات المحددة للظهور في البحث')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->action(function (Collection $records, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $approvedCount = 0;

                        foreach ($records as $member) {
                            if ($member instanceof User && $member->profile && $member->profile->moderation_status !== UserProfile::STATUS_APPROVED) {
                                $service->moderateProfile($actor, $member->profile, UserProfile::STATUS_APPROVED);
                                $approvedCount++;
                            }
                        }

                        Notification::make()
                            ->title("تم اعتماد {$approvedCount} ملف شخصي بنجاح")
                            ->success()
                            ->send();
                    }),

                Tables\Actions\BulkAction::make('activate_manual_subscription_bulk')
                    ->label('تفعيل اشتراك يدوي للأعضاء المحددين')
                    ->icon('heroicon-o-sparkles')
                    ->color('warning')
                    ->form([
                        Select::make('duration_days')
                            ->label('مدة الاشتراك')
                            ->options([
                                30 => 'شهر واحد (30 يوم)',
                                90 => '3 أشهر (90 يوم)',
                                180 => '6 أشهر (180 يوم)',
                                365 => 'سنة كاملة (365 يوم)',
                            ])
                            ->default(30)
                            ->required(),
                        Textarea::make('notes')
                            ->label('ملاحظات التفعيل الإداري (اختياري)')
                            ->maxLength(500),
                    ])
                    ->action(function (Collection $records, array $data, AdminModerationService $service) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();
                        $activatedCount = 0;

                        foreach ($records as $member) {
                            if ($member instanceof User) {
                                $service->activateManualSubscription(
                                    actor: $actor,
                                    member: $member,
                                    durationDays: (int) ($data['duration_days'] ?? 30),
                                    notes: $data['notes'] ?? null,
                                );
                                $activatedCount++;
                            }
                        }

                        Notification::make()
                            ->title("تم تفعيل الاشتراك اليدوي لـ {$activatedCount} عضو بنجاح")
                            ->success()
                            ->send();
                    }),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListMembers::route('/'),
            'view' => Pages\ViewMember::route('/{record}'),
        ];
    }
}
