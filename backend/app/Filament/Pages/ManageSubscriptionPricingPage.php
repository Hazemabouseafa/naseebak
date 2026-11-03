<?php

namespace App\Filament\Pages;

use App\Models\Administrator;
use App\Models\PaymentSetting;
use App\Providers\Filament\AdminPanelProvider;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
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
    protected static ?string $navigationLabel = 'أسعار الاشتراك';
    protected static ?string $title = 'إدارة أسعار الاشتراك الشهري عبر الويب';
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
        $this->form->fill([
            'web_monthly_price' => $setting?->web_monthly_price ?? '250.00',
            'web_currency' => $setting?->web_currency ?? 'EGP',
            'subscription_duration_days' => $setting?->subscription_duration_days ?? 30,
            'google_play_product_id' => config('naseebak.google_play.monthly_subscription_id', 'naseebak_monthly_membership'),
            'reason' => '',
        ]);
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('تسعير العضوية الشهرية عبر الويب (Paymob / Sha7nawy)')
                    ->description('يُستخدم هذا السعر في عمليات الدفع الجديدة عبر بوابات الدفع الإلكترونية فقط، ولا يؤثر على أسعار متجر Google Play أو المعاملات السابقة.')
                    ->columns(2)
                    ->schema([
                        TextInput::make('web_monthly_price')
                            ->label('سعر الاشتراك الشهري (ج.م - EGP)')
                            ->numeric()
                            ->minValue(0.01)
                            ->step(0.01)
                            ->required()
                            ->helperText('يجب أن يكون السعر أكبر من الصفر وبحد أقصى منزلتين عشريتين.'),

                        TextInput::make('web_currency')
                            ->label('العملة المعتمدة')
                            ->disabled()
                            ->dehydrated(false),

                        TextInput::make('subscription_duration_days')
                            ->label('مدة الاشتراك (بالأيام)')
                            ->disabled()
                            ->dehydrated(false),

                        TextInput::make('google_play_product_id')
                            ->label('معرف باقة Google Play (يُدار السعر عبر Google Play Console)')
                            ->disabled()
                            ->dehydrated(false),

                        Textarea::make('reason')
                            ->label('سبب تعديل السعر (يُسجل في سجل النشاط الإداري)')
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

        $setting->updateMonthlyWebPriceAtomically(
            newPrice: $validated['web_monthly_price'],
            adminId: $actor->id,
            ipAddress: request()?->ip(),
            reason: $validated['reason'] ?? null
        );

        Notification::make()
            ->title('تم تحديث سعر الاشتراك الشهري عبر الويب وتسجيل العملية في سجل النشاط')
            ->success()
            ->send();
    }
}
