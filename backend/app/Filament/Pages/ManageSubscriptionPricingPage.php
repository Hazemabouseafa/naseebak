<?php

namespace App\Filament\Pages;

use App\Models\Administrator;
use App\Models\PaymentSetting;
use App\Models\SubscriptionPlan;
use App\Providers\Filament\AdminPanelProvider;
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

class ManageSubscriptionPricingPage extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-currency-dollar';
    protected static ?string $navigationLabel = 'إدارة باقات الاشتراك';
    protected static ?string $title = 'إدارة باقات وأسعار الاشتراك عبر الموقع الإلكتروني';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_BILLING;
    protected static ?int $navigationSort = 2;
    protected static string $view = 'filament.pages.manage-subscription-pricing';

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

        $setting = PaymentSetting::first();
        $monthly = SubscriptionPlan::where('code', 'monthly_membership')->first();
        $quarterly = SubscriptionPlan::where('code', 'quarterly_membership')->first();

        $this->form->fill([
            'monthly_name_ar' => $monthly?->name_ar ?? 'الباقة الشهرية',
            'web_monthly_price' => $monthly?->web_price_amount ?? ($setting?->web_monthly_price ?? '250.00'),
            'monthly_is_active' => (bool) ($monthly?->is_active ?? true),
            'quarterly_name_ar' => $quarterly?->name_ar ?? 'الباقة الربع سنوية',
            'quarterly_web_price' => $quarterly?->web_price_amount ?? '600.00',
            'quarterly_is_active' => (bool) ($quarterly?->is_active ?? true),
            'web_currency' => $setting?->web_currency ?? 'EGP',
            'google_play_product_id' => config('naseebak.google_play.monthly_subscription_id', 'naseebak_monthly_membership'),
            'reason' => '',
        ]);
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('الباقة الشهرية (شهر واحد — الموقع الإلكتروني فقط)')
                    ->description('تُستخدم هذه الإعدادات لطلبات الدفع الجديدة عبر الموقع الإلكتروني فقط ولا تغير الطلبات أو المعاملات السابقة.')
                    ->columns(2)
                    ->schema([
                        TextInput::make('monthly_name_ar')
                            ->label('اسم الباقة المعروض للمستخدمين')
                            ->required()
                            ->maxLength(80),

                        TextInput::make('web_monthly_price')
                            ->label('سعر الباقة الشهرية (ج.م - EGP)')
                            ->numeric()
                            ->minValue(0.01)
                            ->step(0.01)
                            ->required()
                            ->helperText('بحد أقصى منزلتين عشريتين.'),

                        Toggle::make('monthly_is_active')
                            ->label('الباقة الشهرية متاحة للاشتراك عبر الموقع')
                            ->columnSpanFull(),
                    ]),

                Section::make('الباقة الربع سنوية (3 أشهر ميلادية — الموقع الإلكتروني فقط)')
                    ->description('مدة الاشتراك 3 أشهر ميلادية من تاريخ التفعيل أو التمديد، وتُحتسب نسبة التوفير تلقائياً مقارنةً بالباقة الشهرية.')
                    ->columns(2)
                    ->schema([
                        TextInput::make('quarterly_name_ar')
                            ->label('اسم الباقة المعروض للمستخدمين')
                            ->required()
                            ->maxLength(80),

                        TextInput::make('quarterly_web_price')
                            ->label('سعر الباقة الربع سنوية (ج.م - EGP)')
                            ->numeric()
                            ->minValue(0.01)
                            ->step(0.01)
                            ->required()
                            ->helperText('بحد أقصى منزلتين عشريتين.'),

                        Toggle::make('quarterly_is_active')
                            ->label('الباقة الربع سنوية متاحة للاشتراك عبر الموقع')
                            ->columnSpanFull(),
                    ]),

                Section::make('إعدادات مرجعية وتدقيق التغيير')
                    ->columns(2)
                    ->schema([
                        TextInput::make('web_currency')
                            ->label('العملة المعتمدة')
                            ->disabled()
                            ->dehydrated(false),

                        TextInput::make('google_play_product_id')
                            ->label('معرف باقة Google Play المرجعي')
                            ->disabled()
                            ->dehydrated(false),

                        Textarea::make('reason')
                            ->label('سبب تعديل الباقات أو الأسعار (يُسجل في سجل النشاط الإداري)')
                            ->rows(2)
                            ->maxLength(500)
                            ->columnSpanFull(),
                    ]),
            ])
            ->statePath('data');
    }

    public function save(): void
    {
        abort_unless(self::canAccess(), 403);

        $validated = $this->form->getState();
        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();
        $setting = PaymentSetting::firstOrFail();

        $setting->updatePlanPricingAtomically(
            planCode: 'monthly_membership',
            newPrice: $validated['web_monthly_price'],
            nameAr: $validated['monthly_name_ar'],
            isActive: (bool) ($validated['monthly_is_active'] ?? true),
            adminId: $actor->id,
            ipAddress: request()?->ip(),
            reason: $validated['reason'] ?? null
        );

        if (SubscriptionPlan::where('code', 'quarterly_membership')->exists()) {
            $setting->updatePlanPricingAtomically(
                planCode: 'quarterly_membership',
                newPrice: $validated['quarterly_web_price'],
                nameAr: $validated['quarterly_name_ar'],
                isActive: (bool) ($validated['quarterly_is_active'] ?? true),
                adminId: $actor->id,
                ipAddress: request()?->ip(),
                reason: $validated['reason'] ?? null
            );
        }

        Notification::make()
            ->title('تم تحديث باقات الاشتراك والأسعار وتسجيل العملية في سجل النشاط')
            ->success()
            ->send();
    }
}
