<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\PaymentSetting;
use App\Models\SubscriptionPlan;
use Illuminate\Support\Collection;
use Illuminate\View\View;

class WebsiteController extends Controller
{
    public function landing(): View
    {
        $plans = $this->loadPublicPlans();
        $monthlyPlan = $plans->firstWhere('code', 'monthly_membership');
        $quarterlyPlan = $plans->firstWhere('code', 'quarterly_membership');

        $savingsPercent = SubscriptionPlan::computeSavingsPercentVsMonthly($monthlyPlan, $quarterlyPlan);
        $general = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];
        $playStoreUrl = trim((string) ($general['google_play_store_url'] ?? config('naseebak.google_play.store_url') ?? ''));

        return view('website.landing', [
            'plans' => $plans,
            'monthlyPlan' => $monthlyPlan,
            'quarterlyPlan' => $quarterlyPlan,
            'savingsPercent' => $savingsPercent,
            'playStoreUrl' => $playStoreUrl !== '' ? $playStoreUrl : null,
            'supportEmail' => $general['support_email'] ?? 'support@naseebak.app',
        ]);
    }

    public function support(): View
    {
        $general = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];
        $paymentSetting = PaymentSetting::current();

        return view('website.support', [
            'supportEmail' => $general['support_email'] ?? 'support@naseebak.app',
            'supportWhatsapp' => trim((string) ($general['support_whatsapp'] ?? '')),
            'activeGateway' => $paymentSetting->active_web_payment_gateway,
        ]);
    }

    public function subscriptionTerms(): View
    {
        $general = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];

        return view('legal.subscription_terms', [
            'plans' => $this->loadPublicPlans(),
            'supportEmail' => $general['support_email'] ?? 'support@naseebak.app',
        ]);
    }

    public function refundPolicy(): View
    {
        $general = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];

        return view('legal.refund_policy', [
            'supportEmail' => $general['support_email'] ?? 'support@naseebak.app',
        ]);
    }

    /**
     * @return Collection<int, SubscriptionPlan>
     */
    protected function loadPublicPlans(): Collection
    {
        return SubscriptionPlan::query()
            ->where('is_active', true)
            ->whereIn('code', ['monthly_membership', 'quarterly_membership'])
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();
    }
}
