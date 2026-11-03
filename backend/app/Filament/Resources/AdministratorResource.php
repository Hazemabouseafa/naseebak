<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AdministratorResource\Pages;
use App\Models\Administrator;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Admin\AdminAuditService;
use DomainException;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class AdministratorResource extends Resource
{
    protected static ?string $model = Administrator::class;
    protected static ?string $navigationIcon = 'heroicon-o-shield-check';
    protected static ?string $navigationLabel = 'المديرون والصلاحيات';
    protected static ?string $modelLabel = 'مدير / مشرف';
    protected static ?string $pluralModelLabel = 'المديرون والصلاحيات';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_SYSTEM;
    protected static ?int $navigationSort = 2;

    public static function canAccess(): bool
    {
        /** @var ?Administrator $admin */
        $admin = Auth::guard('admin')->user();
        return $admin !== null && $admin->isSuperAdmin();
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('بيانات حساب المدير أو المشرف')
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->label('الاسم الكامل')
                            ->required()
                            ->minLength(3)
                            ->maxLength(120),

                        Forms\Components\TextInput::make('email')
                            ->label('البريد الإلكتروني الرسمي')
                            ->email()
                            ->required()
                            ->unique(ignoreRecord: true)
                            ->maxLength(191),

                        Forms\Components\Select::make('role')
                            ->label('مستوى الصلاحية (الدور)')
                            ->options([
                                Administrator::ROLE_SUPER_ADMIN => 'مدير عام (Super Administrator)',
                                Administrator::ROLE_MODERATOR => 'مشرف مراجعة وأمان (Moderator)',
                            ])
                            ->required()
                            ->default(Administrator::ROLE_MODERATOR),

                        Forms\Components\Toggle::make('is_active')
                            ->label('الحساب نشط')
                            ->default(true),

                        Forms\Components\TextInput::make('password')
                            ->label('كلمة المرور')
                            ->password()
                            ->revealable()
                            ->rule(Password::min(12)->mixedCase()->numbers()->symbols())
                            ->dehydrateStateUsing(fn (string $state): string => Hash::make($state))
                            ->dehydrated(fn (?string $state): bool => filled($state))
                            ->required(fn (string $operation): bool => $operation === 'create')
                            ->helperText('يجب ألا تقل عن 12 حرفاً وتشمل حروفاً كبيرة وصغيرة وأرقاماً ورموزاً.'),

                        Forms\Components\Toggle::make('mfa_enabled')
                            ->label('تفعيل التحقق الثنائي (MFA)')
                            ->default(false),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('المعرف')
                    ->sortable(),
                Tables\Columns\TextColumn::make('name')
                    ->label('الاسم الكامل')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('email')
                    ->label('البريد الإلكتروني')
                    ->searchable(),
                Tables\Columns\TextColumn::make('role')
                    ->label('الدور الإداري')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        Administrator::ROLE_SUPER_ADMIN => 'primary',
                        Administrator::ROLE_MODERATOR => 'warning',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        Administrator::ROLE_SUPER_ADMIN => 'مدير عام (Super Admin)',
                        Administrator::ROLE_MODERATOR => 'مشرف (Moderator)',
                        default => $state,
                    }),
                Tables\Columns\IconColumn::make('is_active')
                    ->label('نشط')
                    ->boolean(),
                Tables\Columns\IconColumn::make('mfa_enabled')
                    ->label('MFA')
                    ->boolean(),
                Tables\Columns\TextColumn::make('last_login_at')
                    ->label('آخر تسجيل دخول')
                    ->dateTime('Y-m-d H:i')
                    ->placeholder('لم يسجل الدخول بعد'),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('تاريخ الإنشاء')
                    ->dateTime('Y-m-d')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('role')
                    ->label('الدور')
                    ->options([
                        Administrator::ROLE_SUPER_ADMIN => 'مدير عام',
                        Administrator::ROLE_MODERATOR => 'مشرف',
                    ]),
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label('حالة الحساب'),
            ])
            ->actions([
                Tables\Actions\EditAction::make()->label('تعديل'),

                Tables\Actions\Action::make('toggle_active')
                    ->label(fn (Administrator $record) => $record->is_active ? 'إيقاف المشرف' : 'تفعيل المشرف')
                    ->color(fn (Administrator $record) => $record->is_active ? 'danger' : 'success')
                    ->requiresConfirmation()
                    ->action(function (Administrator $record, AdminAuditService $auditService) {
                        /** @var Administrator $actor */
                        $actor = Auth::guard('admin')->user();

                        try {
                            $newState = !$record->is_active;
                            $record->update(['is_active' => $newState]);

                            $auditService->record(
                                actor: $actor,
                                action: $newState ? 'administrator.activated' : 'administrator.suspended',
                                target: $record,
                                newValues: ['is_active' => $newState],
                                reason: $newState ? 'إعادة تفعيل حساب المشرف' : 'إيقاف حساب المشرف'
                            );

                            Notification::make()
                                ->title('تم تحديث حالة حساب المشرف')
                                ->success()
                                ->send();
                        } catch (DomainException $e) {
                            Notification::make()
                                ->title('عملية غير مسموحة')
                                ->body($e->getMessage())
                                ->danger()
                                ->send();
                        }
                    }),
            ])
            ->defaultSort('id', 'asc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListAdministrators::route('/'),
            'create' => Pages\CreateAdministrator::route('/create'),
            'edit' => Pages\EditAdministrator::route('/{record}/edit'),
        ];
    }
}
