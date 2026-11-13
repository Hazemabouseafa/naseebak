<?php

namespace App\Services\Subscription;

use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SubscriptionEntitlementService
{
    public const WEB_CHANNELS = [
        Subscription::CHANNEL_PAYMOB,
        Subscription::CHANNEL_SHA7NAWY,
    ];

    /**
     * Evaluates and returns the authoritative unified server-side subscription entitlement for a member
     * calculated across all independently verified subscription periods (Google Play and Web).
     * Never trusts client-supplied state; checks verified status and current UTC time directly.
     */
    public function getEntitlementPayload(User $user): array
    {
        $activeSub = $this->findHighestPrioritySubscription($user);

        $hasActive = $activeSub !== null
            && $user->account_status === 'active'
            && $activeSub->isCurrentlyEntitled();

        $canCommunicate = $hasActive && (bool) $user->profile_completed;

        return [
            'has_active_subscription' => $hasActive,
            'subscription_status' => $activeSub ? $activeSub->normalizedStatus() : 'none',
            'payment_channel' => $activeSub?->channel,
            'current_period_end' => $activeSub?->effectiveExpirationAt()?->toIso8601String(),
            'auto_renewing' => $activeSub ? (bool) $activeSub->auto_renewing : false,
            'can_send_match_requests' => $canCommunicate,
            'can_send_messages' => $canCommunicate,
        ];
    }

    /**
     * Reusable server-side authorization checks for Phase 5 & Phase 6.
     */
    public function hasActiveSubscription(User $user): bool
    {
        return (bool) $this->getEntitlementPayload($user)['has_active_subscription'];
    }

    public function canSendMatchRequest(User $user): bool
    {
        return (bool) $this->getEntitlementPayload($user)['can_send_match_requests'];
    }

    public function canSendMessage(User $user): bool
    {
        return (bool) $this->getEntitlementPayload($user)['can_send_messages'];
    }

    /**
     * Adds consistent calendar months without day-of-month overflow.
     *
     * Examples:
     * - 2026-01-15 + 1 month  => 2026-02-15
     * - 2026-02-15 + 1 month  => 2026-03-15
     * - 2026-01-31 + 1 month  => 2026-02-28 (or 2028-02-29 in leap year)
     * - 2026-03-31 + 1 month  => 2026-04-30
     */
    public function addCalendarMonths(CarbonInterface $start, int $months = 1): Carbon
    {
        return Carbon::instance($start)->copy()->addMonthsNoOverflow(max(1, $months));
    }

    /**
     * Finds the member's highest-priority independent subscription across all providers,
     * automatically marking any past-due active/cancelled/grace records as 'expired'
     * if their authoritative validity window has elapsed.
     *
     * When overlapping web and Google Play subscriptions exist, returns the entitled
     * subscription with the furthest effective expiration timestamp.
     */
    public function findHighestPrioritySubscription(User $user): ?Subscription
    {
        $subscriptions = Subscription::where('user_id', $user->id)
            ->with('plan')
            ->orderByDesc('ends_at')
            ->orderByDesc('id')
            ->get();

        if ($subscriptions->isEmpty()) {
            return null;
        }

        $now = now();

        // First pass: synchronize any record whose validity window has elapsed
        foreach ($subscriptions as $sub) {
            $normalized = $sub->normalizedStatus();
            if (in_array($normalized, [Subscription::STATUS_ACTIVE, Subscription::STATUS_CANCELLED], true)) {
                if ($sub->ends_at !== null && $sub->ends_at->lessThanOrEqualTo($now)) {
                    $sub->update([
                        'status' => Subscription::STATUS_EXPIRED,
                        'auto_renewing' => false,
                        'expired_at' => $sub->expired_at ?? $sub->ends_at,
                    ]);
                }
            } elseif ($normalized === Subscription::STATUS_IN_GRACE_PERIOD) {
                $graceEnd = $sub->grace_period_ends_at ?? $sub->ends_at;
                if ($graceEnd !== null && $graceEnd->lessThanOrEqualTo($now)) {
                    $sub->update([
                        'status' => Subscription::STATUS_EXPIRED,
                        'auto_renewing' => false,
                        'expired_at' => $sub->expired_at ?? $graceEnd,
                    ]);
                }
            }
        }

        // Second pass: among all currently entitled independent subscriptions, pick the one with the latest effective expiration
        $entitledSubscriptions = $subscriptions
            ->filter(fn (Subscription $sub) => $sub->isCurrentlyEntitled())
            ->sortByDesc(fn (Subscription $sub) => $sub->effectiveExpirationAt()?->getTimestamp() ?? 0);

        if ($entitledSubscriptions->isNotEmpty()) {
            return $entitledSubscriptions->first();
        }

        // Otherwise return the most recent subscription record (e.g. on_hold, expired, pending, refunded, revoked)
        return $subscriptions
            ->sortByDesc(fn (Subscription $sub) => $sub->effectiveExpirationAt()?->getTimestamp() ?? $sub->id)
            ->first();
    }

    /**
     * Grants or extends a web subscription after a verified payment transaction (Paymob or Sha7nawy).
     *
     * Rules:
     * - Locked inside a database transaction (`lockForUpdate()`).
     * - Prevents duplicate activation if the transaction (or another record with the same gateway_transaction_id)
     *   was already linked & fulfilled.
     * - Uses a consistent calendar-month billing period (`addMonthsNoOverflow(1)`), handling 28/29/30/31-day
     *   months and month-end dates without unintended overflow.
     * - Never modifies Google Play provider records when a user purchases a separate web subscription.
     * - Preserves existing valid web periods by extending from `max(now, currentWebSub->ends_at)`.
     */
    public function activateOrExtendFromVerifiedWebTransaction(PaymentTransaction $transaction): Subscription
    {
        return DB::transaction(function () use ($transaction) {
            /** @var PaymentTransaction $lockedTx */
            $lockedTx = PaymentTransaction::where('id', $transaction->id)
                ->lockForUpdate()
                ->firstOrFail();

            if (!in_array($lockedTx->gateway, self::WEB_CHANNELS, true)) {
                throw new DomainException('قناة الدفع هذه ليست بوابة دفع ويب صالحة.');
            }

            if ($lockedTx->status !== PaymentTransaction::STATUS_SUCCEEDED || !$lockedTx->signature_verified) {
                throw new DomainException('لا يمكن تفعيل الاشتراك من عملية دفع غير موثقة أو غير مكتملة.');
            }

            // 1. Idempotency check: if this transaction already granted a subscription, return it without double-extending
            if ($lockedTx->subscription_id !== null) {
                $existingSub = Subscription::where('id', $lockedTx->subscription_id)->lockForUpdate()->first();
                if ($existingSub !== null) {
                    $grantedIds = (array) data_get($existingSub->verification_metadata, 'granted_transaction_ids', []);
                    $lastGrantedId = data_get($existingSub->verification_metadata, 'last_granted_transaction_id');
                    if ($lastGrantedId === $lockedTx->id || in_array($lockedTx->id, $grantedIds, true)) {
                        return $existingSub;
                    }
                }
            }

            // 2. Prevent duplicate payment processing if another transaction row with the same gateway_transaction_id already granted a subscription
            if ($lockedTx->gateway_transaction_id !== null && $lockedTx->gateway_transaction_id !== '') {
                $duplicateFulfilledTx = PaymentTransaction::where('gateway', $lockedTx->gateway)
                    ->where('gateway_transaction_id', $lockedTx->gateway_transaction_id)
                    ->where('id', '!=', $lockedTx->id)
                    ->whereNotNull('subscription_id')
                    ->lockForUpdate()
                    ->first();

                if ($duplicateFulfilledTx !== null) {
                    $existingSub = Subscription::where('id', $duplicateFulfilledTx->subscription_id)->lockForUpdate()->first();
                    if ($existingSub !== null) {
                        $lockedTx->update(['subscription_id' => $existingSub->id]);
                        return $existingSub;
                    }
                }
            }

            $user = User::withTrashed()->where('id', $lockedTx->user_id)->lockForUpdate()->firstOrFail();
            if ($user->trashed() || $user->account_status === 'deleted') {
                throw new DomainException('لا يمكن تفعيل أو تجديد اشتراك لحساب تم حذفه نهائياً.');
            }
            $plan = SubscriptionPlan::findOrFail($lockedTx->subscription_plan_id);

            $now = now();

            // Only inspect existing active WEB subscriptions; NEVER modify Google Play provider records!
            $currentActiveWebSub = Subscription::where('user_id', $user->id)
                ->whereIn('channel', self::WEB_CHANNELS)
                ->whereIn('status', Subscription::ENTITLED_STATUSES)
                ->where('ends_at', '>', $now)
                ->orderByDesc('ends_at')
                ->lockForUpdate()
                ->first();

            $baseStart = ($currentActiveWebSub !== null && $currentActiveWebSub->ends_at->greaterThan($now))
                ? $currentActiveWebSub->ends_at->copy()
                : $now->copy();

            $monthsToGrant = max(1, $plan->effectiveMonths());
            $newEndsAt = $this->addCalendarMonths($baseStart, $monthsToGrant);

            if ($currentActiveWebSub !== null && $currentActiveWebSub->channel === $lockedTx->gateway) {
                $metadata = $currentActiveWebSub->verification_metadata ?? [];
                $grantedIds = array_values(array_unique(array_merge(
                    (array) ($metadata['granted_transaction_ids'] ?? []),
                    [$lockedTx->id]
                )));
                $grantedPeriods = (array) ($metadata['granted_periods'] ?? []);
                $grantedPeriods[(string) $lockedTx->id] = [
                    'previous_ends_at' => $currentActiveWebSub->ends_at?->toIso8601String(),
                    'granted_ends_at' => $newEndsAt->toIso8601String(),
                    'granted_months' => $monthsToGrant,
                    'plan_code' => $plan->code,
                ];

                $metadata['last_granted_transaction_id'] = $lockedTx->id;
                $metadata['last_internal_reference'] = $lockedTx->internal_reference;
                $metadata['granted_transaction_ids'] = $grantedIds;
                $metadata['granted_periods'] = $grantedPeriods;

                $currentActiveWebSub->update([
                    'subscription_plan_id' => $plan->id,
                    'status' => Subscription::STATUS_ACTIVE,
                    'ends_at' => $newEndsAt,
                    'cancelled_at' => null,
                    'expired_at' => null,
                    'last_verified_at' => $now,
                    'verification_metadata' => $metadata,
                ]);

                $subscription = $currentActiveWebSub;
            } else {
                $subscription = Subscription::create([
                    'user_id' => $user->id,
                    'subscription_plan_id' => $plan->id,
                    'channel' => $lockedTx->gateway,
                    'status' => Subscription::STATUS_ACTIVE,
                    'external_subscription_id' => $lockedTx->gateway_transaction_id ?? $lockedTx->internal_reference,
                    'auto_renewing' => false,
                    'starts_at' => $currentActiveWebSub ? $now : $baseStart,
                    'ends_at' => $newEndsAt,
                    'last_verified_at' => $now,
                    'verification_metadata' => [
                        'last_granted_transaction_id' => $lockedTx->id,
                        'last_internal_reference' => $lockedTx->internal_reference,
                        'granted_transaction_ids' => [$lockedTx->id],
                        'granted_periods' => [
                            (string) $lockedTx->id => [
                                'previous_ends_at' => $currentActiveWebSub?->ends_at?->toIso8601String(),
                                'granted_ends_at' => $newEndsAt->toIso8601String(),
                                'granted_months' => $monthsToGrant,
                                'plan_code' => $plan->code,
                            ],
                        ],
                        'extended_from_previous_subscription_id' => $currentActiveWebSub?->id,
                    ],
                ]);
            }

            $lockedTx->update([
                'subscription_id' => $subscription->id,
            ]);

            $refreshed = $subscription->refresh();

            DB::afterCommit(function () use ($refreshed) {
                app(\App\Services\Notification\NotificationService::class)
                    ->notifySubscriptionActivated($refreshed);
            });

            return $refreshed;
        });
    }

    /**
     * Synchronizes a Google Play subscription record strictly from the authoritative
     * state and expiration returned by Google Play Developer API (`purchases.subscriptionsv2.get`).
     *
     * Rules:
     * - Uses the exact verified expiration (`ends_at`) returned by Google Play Developer API.
     * - Never independently extends a Google Play subscription by adding 30 days.
     * - Respects Google Play renewal, cancellation, grace-period, hold, and revocation states.
     * - Never modifies separate web subscription records.
     * - Prevents replay of a purchase token across unrelated user accounts.
     */
    public function syncVerifiedGooglePlayPurchase(
        User $user,
        SubscriptionPlan $plan,
        string $purchaseToken,
        array $verifiedGooglePlayState
    ): Subscription {
        $tokenHash = hash('sha256', trim($purchaseToken));

        if (empty($verifiedGooglePlayState['ends_at'])) {
            throw new DomainException('تاريخ انتهاء الصلاحية الموثق من Google Play مفقود ولا يمكن افتراضه محلياً.');
        }

        return DB::transaction(function () use ($user, $plan, $purchaseToken, $tokenHash, $verifiedGooglePlayState) {
            $lockedUser = User::withTrashed()->where('id', $user->id)->lockForUpdate()->firstOrFail();

            if ($lockedUser->trashed() || $lockedUser->account_status === 'deleted') {
                $mappedStatus = $verifiedGooglePlayState['mapped_status'] ?? Subscription::STATUS_PENDING;
                if (in_array($mappedStatus, [Subscription::STATUS_ACTIVE, Subscription::STATUS_IN_GRACE_PERIOD], true)) {
                    throw new DomainException('لا يمكن إعادة تفعيل أو تجديد اشتراك لحساب تم حذفه مسبقاً.');
                }
            }

            $existingByToken = Subscription::where('google_play_purchase_token_hash', $tokenHash)
                ->orWhere('google_play_purchase_token', $purchaseToken)
                ->lockForUpdate()
                ->first();

            // Prevent replay of a Google Play purchase token across a different user account
            if ($existingByToken !== null && (int) $existingByToken->user_id !== (int) $lockedUser->id) {
                throw new DomainException('رمز الشراء هذا مرتبط بحساب عضو آخر ولا يمكن إعادة استخدامه.');
            }

            $mappedStatus = $verifiedGooglePlayState['mapped_status'] ?? Subscription::STATUS_PENDING;
            $startsAt = isset($verifiedGooglePlayState['starts_at'])
                ? Carbon::parse($verifiedGooglePlayState['starts_at'])
                : ($existingByToken?->starts_at ?? now());

            // Strictly use the authoritative expiration returned by Google Play Developer API
            $authoritativeGoogleExpiryAt = Carbon::parse($verifiedGooglePlayState['ends_at']);

            $graceEndsAt = isset($verifiedGooglePlayState['grace_period_ends_at'])
                ? Carbon::parse($verifiedGooglePlayState['grace_period_ends_at'])
                : null;
            $autoRenewing = (bool) ($verifiedGooglePlayState['auto_renewing'] ?? false);
            $externalOrderId = (string) ($verifiedGooglePlayState['external_subscription_id'] ?? ('GPA.' . substr($tokenHash, 0, 16)));

            $payload = [
                'user_id' => $lockedUser->id,
                'subscription_plan_id' => $plan->id,
                'channel' => Subscription::CHANNEL_GOOGLE_PLAY,
                'status' => $mappedStatus,
                'external_subscription_id' => $externalOrderId,
                'google_play_purchase_token' => $purchaseToken,
                'google_play_purchase_token_hash' => $tokenHash,
                'auto_renewing' => $autoRenewing,
                'starts_at' => $startsAt,
                'ends_at' => $authoritativeGoogleExpiryAt,
                'grace_period_ends_at' => $graceEndsAt,
                'on_hold_at' => $mappedStatus === Subscription::STATUS_ON_HOLD
                    ? ($existingByToken?->on_hold_at ?? now())
                    : null,
                'cancelled_at' => $mappedStatus === Subscription::STATUS_CANCELLED
                    ? ($existingByToken?->cancelled_at ?? now())
                    : null,
                'expired_at' => $mappedStatus === Subscription::STATUS_EXPIRED
                    ? ($existingByToken?->expired_at ?? $authoritativeGoogleExpiryAt)
                    : null,
                'revoked_at' => in_array($mappedStatus, [Subscription::STATUS_REFUNDED, Subscription::STATUS_REVOKED], true)
                    ? ($existingByToken?->revoked_at ?? now())
                    : null,
                'last_verified_at' => now(),
                'verification_metadata' => [
                    'product_id' => $verifiedGooglePlayState['product_id'] ?? $plan->google_play_product_id,
                    'subscription_state' => $verifiedGooglePlayState['raw_subscription_state'] ?? null,
                    'acknowledgement_state' => $verifiedGooglePlayState['acknowledgement_state'] ?? null,
                    'authoritative_expiry_time' => $authoritativeGoogleExpiryAt->toIso8601String(),
                ],
            ];

            if ($existingByToken !== null) {
                $existingByToken->update($payload);
                $subscription = $existingByToken->refresh();
            } else {
                $subscription = Subscription::create($payload);
            }

            // Record idempotent payment transaction for the Google Play order
            PaymentTransaction::updateOrCreate(
                [
                    'gateway' => Subscription::CHANNEL_GOOGLE_PLAY,
                    'gateway_transaction_id' => $externalOrderId,
                ],
                [
                    'idempotency_key' => (string) Str::uuid(),
                    'internal_reference' => 'NSB-GP-' . strtoupper(substr($tokenHash, 0, 14)),
                    'user_id' => $lockedUser->id,
                    'subscription_id' => $subscription->id,
                    'subscription_plan_id' => $plan->id,
                    'gateway_order_id' => $externalOrderId,
                    'amount' => $verifiedGooglePlayState['amount'] ?? null,
                    'amount_minor' => $verifiedGooglePlayState['amount_minor'] ?? null,
                    'currency' => $verifiedGooglePlayState['currency'] ?? null,
                    'status' => in_array($mappedStatus, [Subscription::STATUS_REFUNDED, Subscription::STATUS_REVOKED], true)
                        ? PaymentTransaction::STATUS_REFUNDED
                        : (in_array($mappedStatus, [Subscription::STATUS_ACTIVE, Subscription::STATUS_CANCELLED, Subscription::STATUS_IN_GRACE_PERIOD], true)
                            ? PaymentTransaction::STATUS_SUCCEEDED
                            : PaymentTransaction::STATUS_PENDING),
                    'signature_verified' => true,
                    'verified_at' => now(),
                    'paid_at' => now(),
                    'gateway_response_summary' => [
                        'subscription_state' => $verifiedGooglePlayState['raw_subscription_state'] ?? null,
                        'acknowledgement_state' => $verifiedGooglePlayState['acknowledgement_state'] ?? null,
                    ],
                ]
            );

            DB::afterCommit(function () use ($subscription, $lockedUser) {
                if ($lockedUser->trashed() || $lockedUser->account_status === 'deleted') {
                    return;
                }
                $notifService = app(\App\Services\Notification\NotificationService::class);
                if ($subscription->isCurrentlyEntitled()) {
                    $notifService->notifySubscriptionActivated($subscription);
                } elseif ($subscription->normalizedStatus() === Subscription::STATUS_EXPIRED) {
                    $notifService->notifySubscriptionExpiredIfNoOtherEntitlement($lockedUser, $subscription);
                }
            });

            return $subscription;
        });
    }

    /**
     * Handles a verified refund or revocation of a payment transaction,
     * recalculating or revoking the associated subscription entitlement using
     * calendar-month periods without affecting independent overlapping subscriptions.
     */
    public function revokeOrRecalculateOnRefund(PaymentTransaction $transaction, string $reason = 'refunded'): void
    {
        DB::transaction(function () use ($transaction, $reason) {
            /** @var PaymentTransaction $lockedTx */
            $lockedTx = PaymentTransaction::where('id', $transaction->id)->lockForUpdate()->firstOrFail();

            if ($lockedTx->status === PaymentTransaction::STATUS_REFUNDED) {
                return;
            }

            $lockedTx->update([
                'status' => PaymentTransaction::STATUS_REFUNDED,
            ]);

            if ($lockedTx->subscription_id === null) {
                return;
            }

            /** @var ?Subscription $sub */
            $sub = Subscription::where('id', $lockedTx->subscription_id)->lockForUpdate()->first();
            if ($sub === null) {
                return;
            }

            $remainingSucceededCount = PaymentTransaction::where('subscription_id', $sub->id)
                ->where('id', '!=', $lockedTx->id)
                ->where('status', PaymentTransaction::STATUS_SUCCEEDED)
                ->where('signature_verified', true)
                ->count();

            if ($remainingSucceededCount === 0) {
                $sub->update([
                    'status' => $reason === 'revoked' ? Subscription::STATUS_REVOKED : Subscription::STATUS_REFUNDED,
                    'auto_renewing' => false,
                    'ends_at' => now(),
                    'revoked_at' => now(),
                    'last_verified_at' => now(),
                ]);
                return;
            }

            // Recalculate end date using recorded previous_ends_at snapshot or calendar-month replay from starts_at
            $recordedPreviousEnd = data_get(
                $sub->verification_metadata,
                "granted_periods.{$lockedTx->id}.previous_ends_at"
            );

            if (is_string($recordedPreviousEnd) && $recordedPreviousEnd !== '') {
                $recalculatedEnd = Carbon::parse($recordedPreviousEnd);
            } else {
                $baseStart = $sub->starts_at ? $sub->starts_at->copy() : now();
                $remainingMonths = PaymentTransaction::with('plan')
                    ->where('subscription_id', $sub->id)
                    ->where('status', PaymentTransaction::STATUS_SUCCEEDED)
                    ->where('signature_verified', true)
                    ->get()
                    ->sum(fn (PaymentTransaction $tx): int => max(1, $tx->plan?->effectiveMonths() ?? 1));

                $recalculatedEnd = $this->addCalendarMonths($baseStart, max(1, (int) $remainingMonths));
            }

            if ($recalculatedEnd->lessThanOrEqualTo(now())) {
                $sub->update([
                    'status' => $reason === 'revoked' ? Subscription::STATUS_REVOKED : Subscription::STATUS_REFUNDED,
                    'auto_renewing' => false,
                    'ends_at' => now(),
                    'revoked_at' => now(),
                    'last_verified_at' => now(),
                ]);
            } else {
                $sub->update([
                    'ends_at' => $recalculatedEnd,
                    'last_verified_at' => now(),
                ]);
            }
        });
    }

    /**
     * Batch-processes expired subscriptions for the Laravel Scheduler while preserving
     * all member accounts, profiles, matchmaking requests, and conversation histories.
     * Also dispatches expiration notifications ONLY when no other subscription grants access.
     */
    public function expireElapsedSubscriptionsBatch(): int
    {
        $now = now();
        $expiredCount = 0;

        $dueActiveOrCancelled = Subscription::whereIn('status', [
            Subscription::STATUS_ACTIVE,
            Subscription::STATUS_CANCELLED,
        ])
            ->whereNotNull('ends_at')
            ->where('ends_at', '<=', $now)
            ->get();

        $dueGrace = Subscription::whereIn('status', [
            Subscription::STATUS_IN_GRACE_PERIOD,
            Subscription::STATUS_GRACE_PERIOD_ALIAS,
        ])
            ->where(function ($query) use ($now) {
                $query->where(function ($q) use ($now) {
                    $q->whereNotNull('grace_period_ends_at')
                        ->where('grace_period_ends_at', '<=', $now);
                })->orWhere(function ($q) use ($now) {
                    $q->whereNull('grace_period_ends_at')
                        ->whereNotNull('ends_at')
                        ->where('ends_at', '<=', $now);
                });
            })
            ->get();

        $allDue = $dueActiveOrCancelled->concat($dueGrace)->unique('id');
        $notifService = app(\App\Services\Notification\NotificationService::class);

        foreach ($allDue as $sub) {
            $sub->update([
                'status' => Subscription::STATUS_EXPIRED,
                'auto_renewing' => false,
                'expired_at' => $now,
            ]);
            $expiredCount++;

            $user = User::find($sub->user_id);
            if ($user !== null) {
                $notifService->notifySubscriptionExpiredIfNoOtherEntitlement($user, $sub);
            }
        }

        return $expiredCount;
    }

    /**
     * Scans active subscriptions approaching expiration within the configured reminder window
     * and dispatches deduplicated reminder notifications (skipping auto-renewing Google Play subscriptions).
     */
    public function dispatchApproachingExpirationRemindersBatch(): int
    {
        $reminderDays = max(1, (int) config('naseebak.notifications.subscription_expiry_reminder_days', 3));
        $now = now();
        $windowEnd = $now->copy()->addDays($reminderDays);

        $candidates = Subscription::whereIn('status', [
            Subscription::STATUS_ACTIVE,
            Subscription::STATUS_CANCELLED,
        ])
            ->whereNotNull('ends_at')
            ->where('ends_at', '>', $now)
            ->where('ends_at', '<=', $windowEnd)
            ->get();

        $notifService = app(\App\Services\Notification\NotificationService::class);
        $sentReminders = 0;

        foreach ($candidates as $sub) {
            $record = $notifService->notifySubscriptionExpiringSoon($sub);
            if ($record !== null) {
                $sentReminders++;
            }
        }

        return $sentReminders;
    }
}
