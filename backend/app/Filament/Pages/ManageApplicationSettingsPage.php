<?php

namespace App\Filament\Pages;

use App\Models\Administrator;
use App\Models\AppSetting;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Admin\AdminAuditService;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class ManageApplicationSettingsPage extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';
    protected static ?string $navigationLabel = 'إعدادات التطبيق';
    protected static ?string $title = 'إعدادات تطبيق نصيبك وسياسات التشغيل';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_SYSTEM;
    protected static ?int $navigationSort = 1;
    protected static string $view = 'filament.pages.manage-application-settings';

    public ?array $data = [];

    public static function canAccess(): bool
    {
        /** @var ?Administrator $admin */
        $admin = Auth::guard('admin')->user();
        return $admin !== null && $admin->isSuperAdmin();
    }

    public function mount(): void
    {
        abort_unless(self::canAccess(), 403);

        $general = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];
        $moderation = AppSetting::where('setting_key', 'require_profile_moderation')->first()?->setting_value ?? ['enabled' => true];
        $urls = AppSetting::where('setting_key', 'privacy_and_terms_urls')->first()?->setting_value ?? [];

        $this->form->fill([
            'app_display_name' => $general['app_display_name'] ?? 'نصيبك',
            'general_announcement_ar' => $general['general_announcement_ar'] ?? '',
            'registration_enabled' => (bool) ($general['registration_enabled'] ?? true),
            'require_profile_moderation' => (bool) ($moderation['enabled'] ?? true),
            'maintenance_mode' => (bool) ($general['maintenance_mode'] ?? false),
            'support_email' => $general['support_email'] ?? 'support@naseebak.app',
            'support_whatsapp' => $general['support_whatsapp'] ?? '',
            'privacy_policy_url' => $urls['privacy_policy_url'] ?? 'https://api.example.com/legal/privacy-policy',
            'terms_of_service_url' => $urls['terms_of_service_url'] ?? 'https://api.example.com/legal/terms',
            'account_deletion_url' => $urls['account_deletion_url'] ?? url('/legal/delete-account'),
            'minimum_registration_age' => 18,
        ]);
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('الهوية العامة وحالة التشغيل')
                    ->columns(2)
                    ->schema([
                        TextInput::make('app_display_name')
                            ->label('الاسم المعروض للتطبيق')
                            ->required()
                            ->maxLength(80),

                        TextInput::make('minimum_registration_age')
                            ->label('الحد الأدنى لسن التسجيل (قانوني غير قابل للتخفيض)')
                            ->disabled()
                            ->dehydrated(false),

                        Toggle::make('registration_enabled')
                            ->label('السماح بتسجيل أعضاء جدد عبر Google Sign-In'),

                        Toggle::make('require_profile_moderation')
                            ->label('إلزام مراجعة الملفات الشخصية قبل ظهورها في البحث'),

                        Toggle::make('maintenance_mode')
                            ->label('تفعيل وضع الصيانة المؤقت للتطبيق'),

                        Textarea::make('general_announcement_ar')
                            ->label('رسالة أو تنبيه إداري عام للأعضاء (إعداد لإشعارات المرحلة السابعة)')
                            ->rows(2)
                            ->maxLength(500)
                            ->columnSpanFull(),
                    ]),
                Section::make('بيانات الدعم الفني والروابط القانونية')
                    ->columns(2)
                    ->schema([
                        TextInput::make('support_email')
                            ->label('البريد الإلكتروني للدعم الفني')
                            ->email()
                            ->required(),

                        TextInput::make('support_whatsapp')
                            ->label('رقم تواصل الدعم الفني (اختياري)')
                            ->maxLength(40),

                        TextInput::make('privacy_policy_url')
                            ->label('رابط سياسة الخصوصية')
                            ->url()
                            ->required(),

                        TextInput::make('terms_of_service_url')
                            ->label('رابط شروط وأحكام الاستخدام')
                            ->url()
                            ->required(),

                        TextInput::make('account_deletion_url')
                            ->label('رابط صفحة طلب حذف الحساب والبيانات')
                            ->url()
                            ->required()
                            ->columnSpanFull(),
                    ]),
            ])
            ->statePath('data');
    }

    public function save(AdminAuditService $auditService): void
    {
        abort_unless(self::canAccess(), 403);

        $validated = $this->form->getState();
        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        DB::transaction(function () use ($validated, $actor, $auditService) {
            $record = AppSetting::updateOrCreate(
                ['setting_key' => 'platform_general'],
                [
                    'setting_value' => [
                        'app_display_name' => $validated['app_display_name'],
                        'general_announcement_ar' => $validated['general_announcement_ar'] ?? null,
                        'registration_enabled' => (bool) $validated['registration_enabled'],
                        'maintenance_mode' => (bool) $validated['maintenance_mode'],
                        'support_email' => $validated['support_email'],
                        'support_whatsapp' => $validated['support_whatsapp'] ?? null,
                    ],
                    'description_ar' => 'الإعدادات العامة للتطبيق وحالة الصيانة والتواصل مع الدعم',
                    'updated_by_admin_id' => $actor->id,
                ]
            );

            $auditService->record(
                actor: $actor,
                action: 'app_setting.updated',
                target: $record,
                newValues: $record->setting_value,
                reason: 'تحديث الإعدادات العامة للتطبيق من لوحة التحكم'
            );
        });

        Notification::make()
            ->title('تم حفظ إعدادات تطبيق نصيبك بنجاح')
            ->success()
            ->send();
    }
}
