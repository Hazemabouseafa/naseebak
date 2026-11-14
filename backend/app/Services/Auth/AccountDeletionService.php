<?php

namespace App\Services\Auth;

use App\Models\Conversation;
use App\Models\DeviceToken;
use App\Models\Favorite;
use App\Models\MatchmakingRequest;
use App\Models\NotificationRecord;
use App\Models\User;
use App\Models\UserPhoto;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class AccountDeletionService
{
    /**
     * Executes atomic de-identification, soft-deletion, and registers a post-commit
     * idempotent filesystem cleanup callback for physical photos.
     *
     * Guarantee:
     * - Database transaction commits before filesystem deletion begins (DB::afterCommit).
     * - If the database transaction rolls back, files on disk are untouched.
     * - If a filesystem file deletion encounters a transient error, it is safely logged
     *   without rolling back or corrupting the committed database state.
     * - Idempotent: safe to invoke multiple times without errors.
     */
    public function executeUserDeletion(User $user, ?string $reason = null, string $actor = 'user'): array
    {
        $now = now();

        // 1. Gather all photo paths for post-commit physical cleanup
        $photos = UserPhoto::where('user_id', $user->id)->get();
        $photoCleanupList = [];
        foreach ($photos as $photo) {
            if ($photo->file_path) {
                $photoCleanupList[] = [
                    'disk' => $photo->storage_disk ?: 'private',
                    'path' => $photo->file_path,
                ];
            }
        }

        DB::transaction(function () use ($user, $photoCleanupList, $now) {
            // A. Remove photo database records
            UserPhoto::where('user_id', $user->id)->delete();

            // B. Delete device tokens and notification records
            DeviceToken::where('user_id', $user->id)->delete();
            NotificationRecord::where('user_id', $user->id)->delete();
            $user->notificationPreference()?->delete();

            // C. Delete user preferences
            $user->preferences()?->delete();

            // D. Delete mutual favorites
            Favorite::where('user_id', $user->id)
                ->orWhere('favorited_user_id', $user->id)
                ->delete();

            // E. Cancel pending matchmaking requests in either direction
            MatchmakingRequest::where('status', MatchmakingRequest::STATUS_PENDING)
                ->where(function ($q) use ($user) {
                    $q->where('sender_id', $user->id)
                        ->orWhere('recipient_id', $user->id);
                })
                ->update([
                    'status' => MatchmakingRequest::STATUS_CANCELLED,
                    'cancelled_at' => $now,
                    'responded_at' => $now,
                ]);

            // F. Close active conversations involving the user
            Conversation::where(function ($q) use ($user) {
                $q->where('user_one_id', $user->id)
                    ->orWhere('user_two_id', $user->id)
                    ->orWhereHas('participants', fn ($p) => $p->where('user_id', $user->id));
            })->where('status', '!=', Conversation::STATUS_CLOSED)
                ->update(['status' => Conversation::STATUS_CLOSED]);

            // Close open support tickets belonging to the deleted user so they do not stay pending for admins
            \App\Models\SupportTicket::where('user_id', $user->id)
                ->where('status', '!=', \App\Models\SupportTicket::STATUS_CLOSED)
                ->update([
                    'status' => \App\Models\SupportTicket::STATUS_CLOSED,
                    'closed_at' => now(),
                ]);

            // G. De-identify and update user profile
            if ($user->profile) {
                $user->profile->update([
                    'full_name' => 'عضو محذوف',
                    'bio' => null,
                    'occupation' => 'غير محدد',
                    'hobbies' => null,
                    'is_visible' => false,
                    'photo_privacy' => 'public',
                    'moderation_status' => 'rejected',
                ]);
            }

            // H. Anonymize user record and mark deleted
            $user->update([
                'email' => 'deleted_' . $user->id . '_' . Str::random(8) . '@deleted.local',
                'account_status' => 'deleted',
                'deletion_requested_at' => $now,
                'profile_completed' => false,
            ]);

            // I. Soft delete the user
            $user->delete();

            // J. Revoke all Sanctum tokens
            $user->tokens()->delete();

            // K. Register post-commit filesystem cleanup (executes only when DB transaction commits)
            DB::afterCommit(function () use ($user, $photoCleanupList) {
                foreach ($photoCleanupList as $item) {
                    try {
                        $disk = Storage::disk($item['disk']);
                        if ($disk->exists($item['path'])) {
                            $disk->delete($item['path']);
                        }
                    } catch (\Throwable $e) {
                        Log::warning("Post-commit photo deletion failed for path {$item['path']}: {$e->getMessage()}");
                    }
                }

                try {
                    Storage::disk('private')->deleteDirectory("member-photos/{$user->id}");
                } catch (\Throwable $e) {
                    Log::warning("Post-commit directory deletion failed for member-photos/{$user->id}: {$e->getMessage()}");
                }
            });
        });

        Log::info("Account deletion completed for user ID {$user->id} by actor [{$actor}], reason: {$reason}");

        return [
            'status' => 'deleted',
            'user_id' => $user->id,
            'deleted_at' => $now->toIso8601String(),
        ];
    }
}
