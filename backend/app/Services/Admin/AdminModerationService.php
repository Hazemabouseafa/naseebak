<?php

namespace App\Services\Admin;

use App\Models\Administrator;
use App\Models\ModerationHistory;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Models\UserReport;
use App\Services\Profile\SecurePhotoStorageService;
use DomainException;
use Illuminate\Support\Facades\DB;
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
}
