<?php

namespace App\Services\Payment\Contracts;

use App\Models\PaymentTransaction;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Http\Request;

interface PaymentGatewayInterface
{
    /**
     * Returns the canonical provider identifier ('paymob' or 'sha7nawy').
     */
    public function getProviderName(): string;

    /**
     * Creates a server-side payment order with a fixed amount snapshot (in EGP and minor units)
     * and returns the hosted checkout redirect URL and transaction record.
     *
     * @return array{transaction: PaymentTransaction, checkout_url: string}
     */
    public function createPayment(User $user, SubscriptionPlan $plan, string $fixedPriceEgp): array;

    /**
     * Verifies a payment transaction directly or via callback parameters.
     */
    public function verifyPayment(PaymentTransaction $transaction, array $verificationData = []): PaymentTransaction;

    /**
     * Handles an incoming server-to-server webhook from the payment provider,
     * enforcing cryptographic signature verification, amount/currency matching,
     * idempotency deduplication, and subscription activation/refund updates.
     *
     * @return array{status: string, transaction: ?PaymentTransaction}
     */
    public function handleWebhook(Request $request): array;

    /**
     * Retrieves the authoritative payment status for an internal transaction.
     */
    public function getPaymentStatus(PaymentTransaction $transaction): string;
}
