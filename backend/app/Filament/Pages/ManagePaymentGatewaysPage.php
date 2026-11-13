<?php

namespace App\Filament\Pages;

use App\Models\Administrator;
use App\Models\PaymentSetting;
use App\Providers\Filament\AdminPanelProvider;
use DomainException;
use Filament\Forms\Components\Radio;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Facades\Auth;
use InvalidArgumentException;

class ManagePaymentGatewaysPage extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-adjustments-horizontal';
    protected static ?string $navigationLabel = 'إعدادات بوابات الدفع';
    protected static ?string $title = 'إدارة بوابات الدفع الإلكترونية (Paymob / Sha7nawy)';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_BILLING;
    protected static ?int $navigationSort = 4;
    protected static string $view = 'filament.pages.manage-payment-gateways';

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

        $this->refreshFormState();
    }

    protected function refreshFormState(): void
    {
        $setting = PaymentSetting::first();
        $diagnostics = $setting?->gatewayDiagnostics() ?? [];

        $paymobDetails = ($diagnostics['paymob']['status_label_ar'] ?? '')
            . (!empty($diagnostics['paymob']['missing_items'])
                ? ' — ينقص: ' . implode(', ', $diagnostics['paymob']['missing_items'])
                : '');

        $shaDetails = ($diagnostics['sha7nawy']['status_label_ar'] ?? '')
            . (!empty($diagnostics['sha7nawy']['missing_items'])
                ? ' — المتطلبات الناقصة: ' . implode(', ', $diagnostics['sha7nawy']['missing_items'])
                : '');

        $this->form->fill([
            'active_web_payment_gateway' => $setting?->active_web_payment_gateway ?? 'paymob',
            'paymob_status' => $paymobDetails,
            'sha7nawy_status' => $shaDetails,
            'last_updated_at' => $setting?->updated_at?->format('Y-m-d H:i:s') ?? '-',
            'last_updated_by' => $setting?->updatedByAdmin?->name ?? 'النظام الافتراضي',
        ]);
    }

    public function checkReadiness(): void
    {
        abort_unless(self::canAccess(), 403);

        $this->refreshFormState();

        Notification::make()
            ->title('تم فحص جاهزية متغيرات البيئة لبوابات الدفع دون كشف المفاتيح السرية')
            ->info()
            ->send();
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('بوابة الدفع الإلكترونية النشطة حالياً (بوابة واحدة فقط في نفس الوقت)')
                    ->description('يسمح النظام بتفعيل بوابة دفع ويب واحدة فقط في كل مرة (Paymob أو Sha7nawy). تُحفظ المفاتيح السرية في متغيرات البيئة المشفرة ولا تُعرض نصياً.')
                    ->columns(2)
                    ->schema([
                        Radio::make('active_web_payment_gateway')
                            ->label('اختر بوابة الدفع الإلكترونية النشطة')
                            ->options([
                                'paymob' => 'بوابة Paymob (البطاقات البنكية والمحافظ الإلكترونية)',
                                'sha7nawy' => 'بوابة شحناوي — Sha7nawy (https://gate.sha7nawy.com)',
                            ])
                            ->required()
                            ->columnSpanFull(),

                        TextInput::make('paymob_status')
                            ->label('حالة ربط Paymob')
                            ->disabled()
                            ->dehydrated(false),

                        TextInput::make('sha7nawy_status')
                            ->label('حالة ربط Sha7nawy')
                            ->disabled()
                            ->dehydrated(false),

                        TextInput::make('last_updated_by')
                            ->label('آخر تعديل بواسطة')
                            ->disabled()
                            ->dehydrated(false),

                        TextInput::make('last_updated_at')
                            ->label('توقيت آخر تبديل')
                            ->disabled()
                            ->dehydrated(false),
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

        try {
            $setting->switchActiveGatewayAtomically(
                newGateway: $validated['active_web_payment_gateway'],
                actorId: $actor->id,
                ipAddress: request()?->ip(),
                isAdministratorModel: true
            );

            Notification::make()
                ->title('تم تبديل بوابة الدفع الإلكترونية النشطة بنجاح')
                ->success()
                ->send();
        } catch (DomainException|InvalidArgumentException $e) {
            Notification::make()
                ->title('تعذر تبديل بوابة الدفع')
                ->body($e->getMessage())
                ->danger()
                ->send();
        }
    }
}
