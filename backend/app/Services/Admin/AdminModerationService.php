<?php

namespace App\Services\Admin;

use App\Models\Administrator;
use App\Models\ModerationHistory;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Models\UserReport;
use App\Services\Auth\AccountDeletionService;
use App\Services\Profile\SecurePhotoStorageService;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use InvalidArgumentException;

class AdminModerationService
{
    public function __construct(
        private readonly AdminAuditService $auditService,
        private readonly SecurePhotoStorageService $photoStorageService,
    ) {}

    /**
     * Suspends a member account immediately, revoking all active Sanctum tokens,
     * hiding them from discovery/search, and recording an immutable audit entry.
     */
    public function suspendMember(
        Administrator $actor,
        User $member,
        string $reason,
        ?string $ipAddress = null
    ): User {
        $trimmedReason = trim($reason);
        if ($trimmedReason === '') {
            throw new InvalidArgumentException('يجب إدخال سبب واضح لإيقاف الحساب.');
        }

        return DB::transaction(function () use ($actor, $member, $trimmedReason, $ipAddress) {
            $previousStatus = $member->account_status;

            $member->update([
                'account_status' => 'suspended',
                'suspension_reason' => $trimmedReason,
                'suspended_at' => now(),
            ]);

            // Immediately revoke all active Sanctum tokens so the mobile session is terminated
            $member->tokens()->delete();

            $this->auditService->record(
                actor: $actor,
                action: 'member.suspended',
                target: $member,
                previousValues: ['account_status' => $previousStatus],
                newValues: [
                    'account_status' => 'suspended',
                    'suspension_reason' => $trimmedReason,
                ],
                reason: $trimmedReason,
                ipAddress: $ipAddress
            );

            return $member->refresh();
        });
    }

    /**
     * Restores a suspended member account to active status and records an audit log entry.
     */
    public function restoreMember(
        Administrator $actor,
        User $member,
        ?string $notes = null,
        ?string $ipAddress = null
    ): User {
        return DB::transaction(function () use ($actor, $member, $notes, $ipAddress) {
            $previousStatus = $member->account_status;
            $previousReason = $member->suspension_reason;

            $member->update([
                'account_status' => 'active',
                'suspension_reason' => null,
                'suspended_at' => null,
            ]);

            $this->auditService->record(
                actor: $actor,
                action: 'member.restored',
                target: $member,
                previousValues: [
                    'account_status' => $previousStatus,
                    'suspension_reason' => $previousReason,
                ],
                newValues: ['account_status' => 'active'],
                reason: $notes ?: 'إعادة تفعيل حساب العضو بعد المراجعة الإدارية',
                ipAddress: $ipAddress
            );

            return $member->refresh();
        });
    }

    /**
     * Moderates a member profile: 'approved', 'rejected', or 'correction_requested'.
     * Rejecting or requesting corrections requires a mandatory reason.
     */
    public function moderateProfile(
        Administrator $actor,
        UserProfile $profile,
        string $newStatus,
        ?string $reason = null,
        ?string $ipAddress = null
    ): UserProfile {
        if (!in_array($newStatus, UserProfile::ALLOWED_MODERATION_STATUSES, true)) {
            throw new InvalidArgumentException("حالة مراجعة غير صالحة: {$newStatus}");
        }

        $trimmedReason = trim((string) $reason);
        if (in_array($newStatus, [UserProfile::STATUS_REJECTED, UserProfile::STATUS_CORRECTION_REQUESTED], true) && $trimmedReason === '') {
            throw new InvalidArgumentException('يجب كتابة سبب واضح عند رفض الملف الشخصي أو طلب تعديله.');
        }

        return DB::transaction(function () use ($actor, $profile, $newStatus, $trimmedReason, $ipAddress) {
            $previousStatus = $profile->moderation_status;

            $profile->update([
                'moderation_status' => $newStatus,
                'moderation_notes' => $trimmedReason !== '' ? $trimmedReason : null,
                'moderated_by_admin_id' => $actor->id,
                'moderated_at' => now(),
            ]);

            if ($newStatus === UserProfile::STATUS_APPROVED && $profile->user) {
                $profile->user->update([
                    'profile_completed' => true,
                ]);
            }

            ModerationHistory::create([
                'administrator_id' => $actor->id,
                'target_type' => UserProfile::class,
                'target_id' => $profile->id,
                'previous_status' => $previousStatus,
                'new_status' => $newStatus,
                'reason' => $trimmedReason !== '' ? $trimmedReason : 'تمت الموافقة على الملف الشخصي',
                'created_at' => now(),
            ]);

            $actionName = match ($newStatus) {
                UserProfile::STATUS_APPROVED => 'profile.approved',
                UserProfile::STATUS_REJECTED => 'profile.rejected',
                UserProfile::STATUS_CORRECTION_REQUESTED => 'profile.correction_requested',
                default => 'profile.moderated',
            };

            $this->auditService->record(
                actor: $actor,
                action: $actionName,
                target: $profile,
                previousValues: ['moderation_status' => $previousStatus],
                newValues: [
                    'moderation_status' => $newStatus,
                    'moderation_notes' => $trimmedReason !== '' ? $trimmedReason : null,
                ],
                reason: $trimmedReason !== '' ? $trimmedReason : 'اعتماد الملف الشخصي للظهور في البحث',
                ipAddress: $ipAddress
            );

            if ($profile->user && $profile->user->account_status === 'active') {
                try {
                    $notifTitle = match ($newStatus) {
                        UserProfile::STATUS_APPROVED => 'تم اعتماد ملفك الشخصي',
                        UserProfile::STATUS_CORRECTION_REQUESTED => 'ملاحظة لمراجعة ملفك الشخصي',
                        UserProfile::STATUS_REJECTED => 'تحديث حالة الملف الشخصي',
                        default => 'تحديث الملف الشخصي',
                    };
                    $notifBody = match ($newStatus) {
                        UserProfile::STATUS_APPROVED => 'تمت مراجعة واعتماد ملفك الشخصي بنجاح وهو متاح الآن للظهور والتعارف.',
                        default => $trimmedReason !== '' ? $trimmedReason : 'يرجى مراجعة بيانات ملفك الشخصي.',
                    };
                    app(\App\Services\Notification\NotificationService::class)->createAndDispatchNotification(
                        recipient: $profile->user,
                        eventType: \App\Models\NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT,
                        titleAr: $notifTitle,
                        bodyAr: $notifBody,
                        deduplicationKey: "profile_mod:{$profile->id}:{$newStatus}:" . now()->format('YmdHi'),
                        actionRoute: \App\Models\NotificationRecord::ROUTE_NOTIFICATION_CENTER,
                        referenceType: 'user_profile',
                        referenceId: (int) $profile->id
                    );
                } catch (\Throwable) {
                }
            }

            return $profile->refresh();
        });
    }

    /**
     * Moderates a member's uploaded photo ('approved' or 'rejected').
     */
    public function moderatePhoto(
        Administrator $actor,
        UserPhoto $photo,
        string $newStatus,
        ?string $reason = null,
        ?string $ipAddress = null
    ): UserPhoto {
        if (!in_array($newStatus, [UserPhoto::STATUS_APPROVED, UserPhoto::STATUS_REJECTED], true)) {
            throw new InvalidArgumentException("حالة مراجعة الصورة غير صالحة: {$newStatus}");
        }

        $trimmedReason = trim((string) $reason);
        if ($newStatus === UserPhoto::STATUS_REJECTED && $trimmedReason === '') {
            throw new InvalidArgumentException('يجب كتابة سبب رفض الصورة الشخصية.');
        }

        return DB::transaction(function () use ($actor, $photo, $newStatus, $trimmedReason, $ipAddress) {
            $previousStatus = $photo->moderation_status;

            $photo->update([
                'moderation_status' => $newStatus,
                'moderation_notes' => $trimmedReason !== '' ? $trimmedReason : null,
                'moderated_by_admin_id' => $actor->id,
                'moderated_at' => now(),
            ]);

            ModerationHistory::create([
                'administrator_id' => $actor->id,
                'target_type' => UserPhoto::class,
                'target_id' => $photo->id,
                'previous_status' => $previousStatus,
                'new_status' => $newStatus,
                'reason' => $trimmedReason !== '' ? $trimmedReason : 'تمت الموافقة على الصورة الشخصية',
                'created_at' => now(),
            ]);

            $this->auditService->record(
                actor: $actor,
                action: $newStatus === UserPhoto::STATUS_APPROVED ? 'photo.approved' : 'photo.rejected',
                target: $photo,
                previousValues: ['moderation_status' => $previousStatus],
                newValues: [
                    'moderation_status' => $newStatus,
                    'moderation_notes' => $trimmedReason !== '' ? $trimmedReason : null,
                ],
                reason: $trimmedReason !== '' ? $trimmedReason : 'اعتماد الصورة الشخصية',
                ipAddress: $ipAddress
            );

            if ($photo->user && $photo->user->account_status === 'active') {
                try {
                    $notifTitle = $newStatus === UserPhoto::STATUS_APPROVED
                        ? 'تم اعتماد صورتك الشخصية'
                        : 'تحديث بخصوص صورتك الشخصية';
                    $notifBody = $newStatus === UserPhoto::STATUS_APPROVED
                        ? 'تمت الموافقة على صورتك الشخصية بنجاح في نَصِيبُكَ.'
                        : ($trimmedReason !== '' ? $trimmedReason : 'يرجى رفع صورة شخصية واضحة ومطابقة لمعايير المنصة.');
                    app(\App\Services\Notification\NotificationService::class)->createAndDispatchNotification(
                        recipient: $photo->user,
                        eventType: \App\Models\NotificationRecord::TYPE_ADMIN_ANNOUNCEMENT,
                        titleAr: $notifTitle,
                        bodyAr: $notifBody,
                        deduplicationKey: "photo_mod:{$photo->id}:{$newStatus}:" . now()->format('YmdHi'),
                        actionRoute: \App\Models\NotificationRecord::ROUTE_NOTIFICATION_CENTER,
                        referenceType: 'user_photo',
                        referenceId: (int) $photo->id
                    );
                } catch (\Throwable) {
                }
            }

            return $photo->refresh();
        });
    }

    /**
     * Permanently removes a prohibited member photo from private disk and database,
     * recording an audit log and moderation history entry.
     */
    public function removeProhibitedPhoto(
        Administrator $actor,
        UserPhoto $photo,
        string $reason,
        ?string $ipAddress = null
    ): void {
        $trimmedReason = trim($reason);
        if ($trimmedReason === '') {
            throw new InvalidArgumentException('يجب كتابة سبب حذف الصورة المخالفة.');
        }

        DB::transaction(function () use ($actor, $photo, $trimmedReason, $ipAddress) {
            $photoId = $photo->id;
            $userId = $photo->user_id;
            $previousStatus = $photo->moderation_status;
            $filePath = $photo->file_path;

            ModerationHistory::create([
                'administrator_id' => $actor->id,
                'target_type' => UserPhoto::class,
                'target_id' => $photoId,
                'previous_status' => $previousStatus,
                'new_status' => 'removed',
                'reason' => $trimmedReason,
                'created_at' => now(),
            ]);

            $this->auditService->record(
                actor: $actor,
                action: 'photo.removed',
                target: $photo,
                previousValues: [
                    'user_id' => $userId,
                    'file_path' => $filePath,
                    'moderation_status' => $previousStatus,
                ],
                newValues: ['status' => 'deleted_from_private_storage'],
                reason: $trimmedReason,
                ipAddress: $ipAddress
            );

            $this->photoStorageService->deletePhoto($photo);
        });
    }

    /**
     * Reviews and updates a UserReport ('under_review', 'resolved', 'rejected')
     * and optionally suspends the reported member.
     */
    public function handleReport(
        Administrator $actor,
        UserReport $report,
        string $newStatus,
        string $resolutionNotes,
        bool $suspendReportedMember = false,
        ?string $ipAddress = null
    ): UserReport {
        $allowedStatuses = [
            UserReport::STATUS_UNDER_REVIEW,
            UserReport::STATUS_RESOLVED,
            UserReport::STATUS_REJECTED,
        ];

        if (!in_array($newStatus, $allowedStatuses, true)) {
            throw new InvalidArgumentException("حالة البلاغ غير صالحة: {$newStatus}");
        }

        $trimmedNotes = trim($resolutionNotes);
        if ($trimmedNotes === '') {
            throw new InvalidArgumentException('يجب تسجيل ملاحظات المراجعة أو قرار الفصل في البلاغ.');
        }

        return DB::transaction(function () use ($actor, $report, $newStatus, $trimmedNotes, $suspendReportedMember, $ipAddress) {
            $previousStatus = $report->status;

            $report->update([
                'status' => $newStatus,
                'assigned_moderator_id' => $report->assigned_moderator_id ?? $actor->id,
                'resolution_notes' => $trimmedNotes,
                'reviewed_by_admin_id' => $actor->id,
                'reviewed_at' => now(),
            ]);

            if ($suspendReportedMember && $report->reportedUser) {
                $this->suspendMember(
                    actor: $actor,
                    member: $report->reportedUser,
                    reason: "إيقاف بناءً على البلاغ رقم #{$report->id}: {$trimmedNotes}",
                    ipAddress: $ipAddress
                );
            }

            $this->auditService->record(
                actor: $actor,
                action: "report.{$newStatus}",
                target: $report,
                previousValues: ['status' => $previousStatus],
                newValues: [
                    'status' => $newStatus,
                    'resolution_notes' => $trimmedNotes,
                    'suspended_reported_member' => $suspendReportedMember,
                ],
                reason: $trimmedNotes,
                ipAddress: $ipAddress
            );

            return $report->refresh();
        });
    }

    /**
     * Manually activates or extends a member's subscription directly from the Filament Admin Dashboard.
     */
    public function activateManualSubscription(
        Administrator $actor,
        User $member,
        int $durationDays = 30,
        ?int $planId = null,
        ?string $notes = null,
        ?string $ipAddress = null
    ): Subscription {
        $effectiveDays = max(1, min(1825, $durationDays));

        return DB::transaction(function () use ($actor, $member, $effectiveDays, $planId, $notes, $ipAddress) {
            $plan = $planId ? SubscriptionPlan::find($planId) : null;
            if (!$plan) {
                $plan = SubscriptionPlan::where('is_active', true)->orderBy('id')->first();
            }
            if (!$plan) {
                $plan = SubscriptionPlan::updateOrCreate(
                    ['code' => 'monthly_membership'],
                    [
                        'name_ar' => 'العضوية الشهرية — نصيبك بلس',
                        'description_ar' => 'اشتراك كامل يتيح إرسال طلبات التعارف والمحادثات الخاصة',
                        'duration_days' => 30,
                        'google_play_product_id' => 'naseebak_monthly_membership',
                        'web_price_amount' => 250.00,
                        'web_price_currency' => 'EGP',
                        'is_active' => true,
                        'features_ar' => [
                            'إرسال واستقبال طلبات التعارف بلا حدود',
                            'فتح المحادثات الخاصة الفورية مع الأعضاء المتوافقين',
                            'أولوية الظهور في نتائج البحث والاكتشاف',
                        ],
                    ]
                );
            }

            $existingActive = $member->subscriptions()
                ->whereIn('status', Subscription::ENTITLED_STATUSES)
                ->where('ends_at', '>', now())
                ->latest('ends_at')
                ->first();

            $reasonText = trim((string) $notes) !== ''
                ? trim((string) $notes)
                : "تفعيل اشتراك يدوي من لوحة التحكم لمدة {$effectiveDays} يوم";

            if ($existingActive) {
                $previousEndsAt = $existingActive->ends_at?->toIso8601String();
                $newEndsAt = $existingActive->ends_at->copy()->addDays($effectiveDays);
                $meta = is_array($existingActive->verification_metadata)
                    ? $existingActive->verification_metadata
                    : [];
                $meta['manual_extension_by_admin_id'] = $actor->id;
                $meta['manual_extension_by_admin_name'] = $actor->name;
                $meta['manual_extension_days'] = $effectiveDays;
                $meta['manual_extension_notes'] = $reasonText;
                $meta['manual_extension_at'] = now()->toIso8601String();

                $existingActive->update([
                    'status' => Subscription::STATUS_ACTIVE,
                    'ends_at' => $newEndsAt,
                    'last_verified_at' => now(),
                    'verification_metadata' => $meta,
                ]);

                $this->auditService->record(
                    actor: $actor,
                    action: 'subscription.manual_extended',
                    target: $existingActive,
                    previousValues: ['ends_at' => $previousEndsAt],
                    newValues: [
                        'status' => Subscription::STATUS_ACTIVE,
                        'ends_at' => $newEndsAt->toIso8601String(),
                        'added_days' => $effectiveDays,
                    ],
                    reason: $reasonText,
                    ipAddress: $ipAddress
                );

                $refreshedExisting = $existingActive->refresh();

                try {
                    app(\App\Services\Notification\NotificationService::class)
                        ->notifySubscriptionActivated($refreshedExisting);
                } catch (\Throwable) {
                }

                return $refreshedExisting;
            }

            $startsAt = now();
            $endsAt = $startsAt->copy()->addDays($effectiveDays);

            $subscription = Subscription::create([
                'user_id' => $member->id,
                'subscription_plan_id' => $plan->id,
                'channel' => Subscription::CHANNEL_ADMIN_MANUAL,
                'status' => Subscription::STATUS_ACTIVE,
                'external_subscription_id' => 'ADM-MAN-' . strtoupper(Str::random(10)),
                'auto_renewing' => false,
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'last_verified_at' => $startsAt,
                'verification_metadata' => [
                    'activated_by_admin_id' => $actor->id,
                    'activated_by_admin_name' => $actor->name,
                    'duration_days' => $effectiveDays,
                    'notes' => $reasonText,
                    'activated_at' => $startsAt->toIso8601String(),
                ],
            ]);

            $this->auditService->record(
                actor: $actor,
                action: 'subscription.manual_activated',
                target: $subscription,
                previousValues: null,
                newValues: [
                    'user_id' => $member->id,
                    'channel' => Subscription::CHANNEL_ADMIN_MANUAL,
                    'status' => Subscription::STATUS_ACTIVE,
                    'duration_days' => $effectiveDays,
                    'ends_at' => $endsAt->toIso8601String(),
                ],
                reason: $reasonText,
                ipAddress: $ipAddress
            );

            try {
                app(\App\Services\Notification\NotificationService::class)
                    ->notifySubscriptionActivated($subscription);
            } catch (\Throwable) {
            }

            return $subscription;
        });
    }

    /**
     * Revokes all currently active subscriptions for a member from the Admin Dashboard.
     */
    public function revokeMemberSubscriptions(
        Administrator $actor,
        User $member,
        string $reason,
        ?string $ipAddress = null
    ): int {
        $trimmedReason = trim($reason) !== '' ? trim($reason) : 'إلغاء الاشتراك يدوياً من لوحة التحكم';

        return DB::transaction(function () use ($actor, $member, $trimmedReason, $ipAddress) {
            $activeSubscriptions = $member->subscriptions()
                ->whereIn('status', Subscription::ENTITLED_STATUSES)
                ->where('ends_at', '>', now())
                ->get();

            $revokedCount = 0;
            foreach ($activeSubscriptions as $sub) {
                $previousStatus = $sub->status;
                $sub->update([
                    'status' => Subscription::STATUS_REVOKED,
                    'revoked_at' => now(),
                    'auto_renewing' => false,
                ]);

                $this->auditService->record(
                    actor: $actor,
                    action: 'subscription.manual_revoked',
                    target: $sub,
                    previousValues: ['status' => $previousStatus],
                    newValues: ['status' => Subscription::STATUS_REVOKED],
                    reason: $trimmedReason,
                    ipAddress: $ipAddress
                );
                $revokedCount++;
            }

            return $revokedCount;
        });
    }

    /**
     * Deletes a member account from the Admin Dashboard:
     * - Revokes active subscriptions and Sanctum tokens
     * - Deletes private photos from storage and database
     * - Cancels pending matchmaking requests & closes conversations
     * - Anonymizes profile, email, and google_sub (allowing fresh re-registration if needed)
     * - Soft-deletes the User record and writes an immutable AdminAuditLog entry
     */
    public function deleteMember(
        Administrator $actor,
        User $member,
        ?string $reason = null,
        ?string $ipAddress = null
    ): array {
        $effectiveReason = trim((string) $reason) !== ''
            ? trim((string) $reason)
            : 'حذف حساب العضو من لوحة التحكم بواسطة الإدارة';

        return DB::transaction(function () use ($actor, $member, $effectiveReason, $ipAddress) {
            $previousStatus = $member->account_status;
            $previousFullName = $member->profile?->full_name;
            $memberId = $member->id;

            // Revoke any active subscriptions before deleting the member
            $member->subscriptions()
                ->whereIn('status', Subscription::ENTITLED_STATUSES)
                ->update([
                    'status' => Subscription::STATUS_REVOKED,
                    'revoked_at' => now(),
                    'auto_renewing' => false,
                ]);

            $result = app(AccountDeletionService::class)->executeUserDeletion(
                user: $member,
                reason: $effectiveReason,
                actor: "admin:{$actor->id}"
            );

            // Anonymize google_sub as well when deleted by admin so the Google email is freed if needed
            User::withTrashed()
                ->where('id', $memberId)
                ->update([
                    'google_sub' => 'deleted_' . $memberId . '_' . Str::random(12),
                ]);

            $this->auditService->record(
                actor: $actor,
                action: 'member.deleted',
                target: $member,
                previousValues: [
                    'account_status' => $previousStatus,
                    'full_name' => $previousFullName,
                ],
                newValues: [
                    'account_status' => 'deleted',
                ],
                reason: $effectiveReason,
                ipAddress: $ipAddress
            );

            return $result;
        });
    }
}
