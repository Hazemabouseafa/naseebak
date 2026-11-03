<?php

namespace App\Services\Payment;

use App\Models\PaymentSetting;
use App\Models\Subscription;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use DomainException;

class PaymentGatewayManager
{
    public function __construct(
        private readonly PaymobGatewayService $paymobGateway,
        private readonly Sha7nawyGatewayService $sha7nawyGateway,
    ) {}

    /**
     * Resolves a payment gateway adapter by explicit provider name ('paymob' or 'sha7nawy').
     * Used by webhook handlers and existing transaction verifiers so that pending transactions
     * created before a gateway switch continue to be processed by their original provider.
     */
    public function driver(string $provider): PaymentGatewayInterface
    {
        return match (strtolower(trim($provider))) {
            Subscription::CHANNEL_PAYMOB => $this->paymobGateway,
            Subscription::CHANNEL_SHA7NAWY => $this->sha7nawyGateway,
            default => throw new DomainException("بوابة الدفع الإلكترونية غير مدعومة: {$provider}"),
        };
    }

    /**
     * Resolves the currently active web payment gateway configured in PaymentSetting.
     * Used exclusively for new web checkout order creation.
     */
    public function getActiveWebGateway(): PaymentGatewayInterface
    {
        $setting = PaymentSetting::first();
        if (!$setting) {
            throw new DomainException('إعدادات بوابات الدفع الإلكترونية غير مهيأة حالياً.');
        }

        $activeProvider = $setting->active_web_payment_gateway;
        if (!in_array($activeProvider, PaymentSetting::ALLOWED_GATEWAYS, true)) {
            throw new DomainException('لم يتم تحديد بوابة دفع ويب نشطة صالحة.');
        }

        if (!$setting->isGatewayConfigured($activeProvider)) {
            throw new DomainException("بوابة الدفع النشطة حالياً ({$activeProvider}) غير مكتملة الإعدادات.");
        }

        return $this->driver($activeProvider);
    }
}
