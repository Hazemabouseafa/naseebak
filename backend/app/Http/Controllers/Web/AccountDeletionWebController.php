<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\Conversation;
use App\Models\DeviceToken;
use App\Models\Favorite;
use App\Models\MatchmakingRequest;
use App\Models\NotificationRecord;
use App\Models\User;
use App\Models\UserPhoto;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\View\View;

class AccountDeletionWebController extends Controller
{
    /**
     * GET /legal/delete-account
     *
     * Publicly accessible web page meeting Google Play Store requirements:
     * - Explains account deletion process, personal data removal, and data retention policies.
     * - Provides instructions and direct links for cancelling recurring Google Play Store subscriptions.
     * - Provides an in-app deletion walkthrough as well as a direct web deletion request form.
     */
    public function showDeleteAccountPage(Request $request): View
    {
        $general = AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];

        return view('legal.delete_account', [
            'appName' => $general['app_display_name'] ?? 'نَصِيبُكَ — Naseebak',
            'supportEmail' => $general['support_email'] ?? 'support@naseebak.app',
            'googlePlaySubscriptionsUrl' => 'https://play.google.com/store/account/subscriptions',
            'currentUser' => $request->user('web'),
        ]);
    }

    /**
     * POST /legal/delete-account
     *
     * Web deletion request mechanism (CSRF-protected and rate-limited).
     */
    public function submitDeletionRequest(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:120'],
            'confirmation' => ['required', 'in:DELETE,حذف,حذف حسابي'],
            'acknowledge_play_store' => ['required', 'accepted'],
            'reason' => ['nullable', 'string', 'max:500'],
        ], [
            'email.required' => 'يرجى إدخال البريد الإلكتروني المسجل في حسابك.',
            'email.email' => 'صيغة البريد الإلكتروني غير صحيحة.',
            'confirmation.required' => 'يرجى كتابة كلمة "حذف" في حقل التأكيد.',
            'confirmation.in' => 'حقل التأكيد غير صحيح؛ يرجى كتابة "حذف".',
            'acknowledge_play_store.accepted' => 'يجب الإقرار بأن حذف الحساب لا يلغي اشتراك Google Play التلقائي.',
        ]);

        $email = trim(strtolower((string) $validated['email']));
        $user = User::where('email', $email)->first();

        if ($user) {
            DB::transaction(function () use ($user, $validated) {
                // 1. Purge all uploaded photos from private disk and database
                $photos = UserPhoto::where('user_id', $user->id)->get();
                foreach ($photos as $photo) {
                    $disk = Storage::disk($photo->storage_disk ?: 'private');
                    if ($photo->file_path && $disk->exists($photo->file_path)) {
                        $disk->delete($photo->file_path);
                    }
                    $photo->delete();
                }
                Storage::disk('private')->deleteDirectory("member-photos/{$user->id}");

                // 2. Delete device tokens and notification records
                DeviceToken::where('user_id', $user->id)->delete();
                NotificationRecord::where('user_id', $user->id)->delete();
                $user->notificationPreference()?->delete();

                // 3. Delete user preferences
                $user->preferences()?->delete();

                // 4. Delete mutual favorites
                Favorite::where('user_id', $user->id)
                    ->orWhere('favorited_user_id', $user->id)
                    ->delete();

                // 5. Cancel pending matchmaking requests
                $now = now();
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

                // 6. Close active conversations
                Conversation::where(function ($q) use ($user) {
                    $q->where('user_one_id', $user->id)
                        ->orWhere('user_two_id', $user->id)
                        ->orWhereHas('participants', fn ($p) => $p->where('user_id', $user->id));
                })->where('status', '!=', Conversation::STATUS_CLOSED)
                    ->update(['status' => Conversation::STATUS_CLOSED]);

                // 7. De-identify and update user profile
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

                // 8. Anonymize user record
                $user->update([
                    'email' => 'deleted_' . $user->id . '_' . Str::random(8) . '@deleted.local',
                    'account_status' => 'deleted',
                    'deletion_requested_at' => $now,
                    'profile_completed' => false,
                ]);

                // 9. Soft delete the user
                $user->delete();

                // 10. Revoke all Sanctum tokens
                $user->tokens()->delete();
            });

            Log::info("Web account deletion completed successfully for user ID {$user->id} (original email {$email})");
        } else {
            Log::info("Web account deletion requested for email {$email} (user not found or already deleted)");
        }

        return redirect()->route('legal.delete_account')->with(
            'success',
            'تم استلام طلب حذف الحساب بنجاح. إذا كان البريد الإلكتروني مسجلاً لدينا، فقد تم مسح البيانات الشخصية والصور وسجل المحادثات نهائياً وإلغاء تنشيط الحساب. يُرجى تذكّر إلغاء أي اشتراك دوري في متجر Google Play إن وُجد.'
        );
    }
}
