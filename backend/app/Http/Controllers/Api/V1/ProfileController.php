<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\CompleteProfileRequest;
use App\Http\Requests\Api\V1\UpdateProfileRequest;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserPreference;
use App\Models\UserProfile;
use App\Services\Matchmaking\MatchmakingService;
use App\Services\Profile\ProfileAccessControlService;
use App\Services\Profile\SecurePhotoStorageService;
use App\Services\Subscription\SubscriptionEntitlementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Symfony\Component\HttpFoundation\Response;

class ProfileController extends Controller
{
    public function __construct(
        private readonly SecurePhotoStorageService $photoStorageService,
        private readonly ProfileAccessControlService $accessControlService,
        private readonly SubscriptionEntitlementService $entitlementService,
        private readonly MatchmakingService $matchmakingService,
    ) {}

    /**
     * GET /api/v1/profile
     *
     * Retrieves the authenticated user's own profile, primary photo metadata,
     * privacy settings, real completion percentage, and subscription entitlement summary.
     * Ownership is determined strictly from $request->user().
     */
    public function showOwnProfile(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $user->load(['profile', 'photos']);

        $profile = $user->profile;
        $primaryPhoto = $user->photos->firstWhere('is_primary', true)
            ?? $user->photos->first();

        return response()->json([
            'status' => 'success',
            'data' => [
                'profile_completed' => (bool) $user->profile_completed,
                'completion_percentage' => $this->calculateCompletionPercentage($profile, $primaryPhoto),
                'profile' => $profile ? $this->formatProfilePayload($profile, $primaryPhoto) : null,
                'privacy' => [
                    'is_visible' => $profile ? (bool) $profile->is_visible : true,
                    'photo_privacy' => $profile?->photo_privacy ?? 'public',
                ],
                'entitlement' => $this->entitlementService->getEntitlementPayload($user),
            ],
        ]);
    }

    /**
     * POST /api/v1/profile/complete
     * Initial profile registration endpoint (Phase 1 & 2 compatible).
     */
    public function upsertProfile(CompleteProfileRequest $request): JsonResponse
    {
        return $this->persistProfileData($request->user(), $request->validated(), isInitialRegistration: true);
    }

    /**
     * PATCH /api/v1/profile
     * Updates the authenticated user's profile fields (Screen 19: Edit Profile).
     * Never trusts any client-supplied user_id.
     */
    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        return $this->persistProfileData($request->user(), $request->validated(), isInitialRegistration: false);
    }

    /**
     * POST /api/v1/profile/photo
     *
     * Authenticated multipart image upload:
     * - Validates actual binary image content (not just file extension)
     * - Enforces max 2 MB upload size
     * - Strips EXIF/GPS metadata and caps resolution to 1080px
     * - Stores in private Laravel storage with random UUID filename
     * - Deletes replaced primary photo file so no orphan files remain
     */
    public function uploadPhoto(Request $request): JsonResponse
    {
        $maxSizeKb = (int) config('naseebak.uploads.max_photo_size_kb', 2048);

        $request->validate([
            'photo' => [
                'required',
                'file',
                'image',
                'mimetypes:image/jpeg,image/png,image/webp',
                "max:{$maxSizeKb}",
            ],
            'is_primary' => ['sometimes', 'boolean'],
        ], [
            'photo.required' => 'يرجى اختيار الصورة الشخصية.',
            'photo.image' => 'الملف المرفوع يجب أن يكون صورة حقيقية صالحة.',
            'photo.mimetypes' => 'صيغة الصورة غير مدعومة. الصيغ المسموحة: JPEG و PNG و WebP فقط.',
            'photo.max' => 'حجم الصورة يتجاوز الحد الأقصى المسموح به (2 ميجابايت).',
        ]);

        /** @var User $user */
        $user = $request->user();
        $isPrimary = $request->boolean('is_primary', true);

        try {
            $photo = $this->photoStorageService->storeSanitizedProfilePhoto(
                $user,
                $request->file('photo'),
                $isPrimary
            );
        } catch (RuntimeException $e) {
            return response()->json([
                'status' => 'error',
                'code' => 'INVALID_IMAGE_CONTENT',
                'message' => $e->getMessage(),
            ], 422);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم رفع الصورة الشخصية وحفظها بأمان.',
            'data' => [
                'photo' => [
                    'id' => $photo->id,
                    'is_primary' => $photo->is_primary,
                    'mime_type' => $photo->mime_type,
                    'file_size_bytes' => $photo->file_size_bytes,
                    'moderation_status' => $photo->moderation_status,
                    'stream_url' => url("/api/v1/profile/photos/{$photo->id}/stream"),
                ],
            ],
        ], 201);
    }

    /**
     * GET /api/v1/profile/privacy
     * Retrieves the authenticated user's current profile & photo privacy settings.
     */
    public function getPrivacy(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $profile = $user->profile;

        return response()->json([
            'status' => 'success',
            'data' => [
                'is_visible' => $profile ? (bool) $profile->is_visible : true,
                'photo_privacy' => $profile?->photo_privacy ?? 'public',
                'allowed_photo_privacy_options' => [
                    'public' => 'جميع الأعضاء المسجلين',
                    'subscribers_only' => 'الأعضاء المشتركون فقط',
                    'accepted_matches_only' => 'من تم قبول طلب التعارف معهم فقط',
                ],
            ],
        ]);
    }

    /**
     * PATCH /api/v1/profile/privacy
     * Updates profile search visibility and photo access privacy immediately.
     */
    public function updatePrivacy(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'is_visible' => ['required', 'boolean'],
            'photo_privacy' => ['required', 'in:public,subscribers_only,accepted_matches_only'],
        ], [
            'is_visible.required' => 'يرجى تحديد حالة ظهور الملف الشخصي في البحث.',
            'photo_privacy.required' => 'يرجى تحديد مستوى خصوصية الصورة الشخصية.',
            'photo_privacy.in' => 'خيار خصوصية الصورة غير صالح.',
        ]);

        /** @var User $user */
        $user = $request->user();
        $profile = $user->profile;

        if (!$profile) {
            return response()->json([
                'status' => 'error',
                'code' => 'PROFILE_NOT_FOUND',
                'message' => 'يرجى استكمال الملف الشخصي أولاً قبل تعديل إعدادات الخصوصية.',
            ], 404);
        }

        $profile->update([
            'is_visible' => (bool) $validated['is_visible'],
            'photo_privacy' => $validated['photo_privacy'],
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث إعدادات الخصوصية فوراً بنجاح.',
            'data' => [
                'is_visible' => (bool) $profile->is_visible,
                'photo_privacy' => $profile->photo_privacy,
            ],
        ]);
    }

    /**
     * GET /api/v1/profile/photos/{photo}/stream
     *
     * Streams a private profile photo ONLY after verifying:
     * 1. Requesting user's authentication & active status
     * 2. Block status & profile visibility rules
     * 3. Photo privacy level ('public', 'subscribers_only', 'accepted_matches_only')
     * 4. Path traversal safety
     * Includes strict Cache-Control: private, no-store headers so revoked access is immediate.
     */
    public function streamProtectedPhoto(Request $request, UserPhoto $photo): Response
    {
        /** @var User $viewer */
        $viewer = $request->user();
        $photo->loadMissing(['user.profile']);

        if (!$this->accessControlService->canAccessPhoto($viewer, $photo)) {
            return response()->json([
                'status' => 'error',
                'code' => 'PHOTO_ACCESS_FORBIDDEN',
                'message' => 'غير مصرح لك بعرض هذه الصورة الشخصية وفقاً لإعدادات الخصوصية لصاحب الملف.',
            ], 403);
        }

        if (!$this->photoStorageService->isSafeRelativePhotoPath($photo->file_path)) {
            return response()->json([
                'status' => 'error',
                'code' => 'INVALID_PHOTO_PATH',
                'message' => 'مسار الصورة غير صالح.',
            ], 404);
        }

        $disk = Storage::disk($photo->storage_disk ?: 'private');
        if (!$disk->exists($photo->file_path)) {
            return response()->json([
                'status' => 'error',
                'code' => 'PHOTO_NOT_FOUND',
                'message' => 'ملف الصورة غير موجود.',
            ], 404);
        }

        $binaryContent = $disk->get($photo->file_path);

        return response($binaryContent, 200, [
            'Content-Type' => $photo->mime_type ?: 'image/jpeg',
            'Content-Length' => (string) strlen($binaryContent),
            'Cache-Control' => 'private, no-store, no-cache, must-revalidate, max-age=0',
            'Pragma' => 'no-cache',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    /**
     * GET /api/v1/members/{targetUser}/profile
     *
     * Public/Protected member profile view enforcing:
     * - Blocked user restrictions
     * - Hidden profile (is_visible = false) enforcement
     * - Photo privacy enforcement
     * - Never exposes private User fields (email, google_sub, etc.)
     */
    public function showMemberProfile(Request $request, User $targetUser): JsonResponse
    {
        /** @var User $viewer */
        $viewer = $request->user();
        $targetUser->load(['profile', 'photos']);

        $targetProfile = $targetUser->profile;

        // Public member profile requires target profile to be approved and adult (18+), unless viewer is owner/admin
        $isOwnerOrAdmin = $viewer->id === $targetUser->id
            || in_array($viewer->role, ['super_admin', 'moderator'], true);

        if (
            !$targetProfile
            || (!$isOwnerOrAdmin && (!$targetProfile->isModerationApprovedForDiscovery() || $targetProfile->age_years < 18))
            || !$this->accessControlService->canViewProfile($viewer, $targetUser, $targetProfile)
        ) {
            return response()->json([
                'status' => 'error',
                'code' => 'PROFILE_UNAVAILABLE',
                'message' => 'هذا الملف الشخصي غير متاح للعرض.',
            ], 403);
        }

        $primaryPhoto = $targetUser->photos->firstWhere('is_primary', true)
            ?? $targetUser->photos->first();

        $canSeePhoto = $primaryPhoto
            ? $this->accessControlService->canAccessPhoto($viewer, $primaryPhoto)
            : false;

        $isFavorited = \App\Models\Favorite::where('user_id', $viewer->id)
            ->where('favorited_user_id', $targetUser->id)
            ->exists();

        $matchmakingContext = $this->matchmakingService->getRelationshipContext($viewer, $targetUser);
        $entitlementPayload = $this->entitlementService->getEntitlementPayload($viewer);

        return response()->json([
            'status' => 'success',
            'data' => [
                'member' => [
                    'user_id' => $targetUser->id,
                    'full_name' => $targetProfile->full_name,
                    'gender' => $targetProfile->gender,
                    'age_years' => UserProfile::calculateAgeYears($targetProfile->date_of_birth),
                    'zodiac_sign' => $targetProfile->zodiac_sign,
                    'marital_status' => $targetProfile->marital_status,
                    'previously_married' => (bool) $targetProfile->previously_married,
                    'has_children' => (bool) $targetProfile->has_children,
                    'children_count' => (int) $targetProfile->children_count,
                    'education_level' => $targetProfile->education_level,
                    'occupation' => $targetProfile->occupation,
                    'height_cm' => (int) $targetProfile->height_cm,
                    'smoking_status' => $targetProfile->smoking_status,
                    'home_ownership' => $targetProfile->home_ownership,
                    'hobbies' => $targetProfile->hobbies ?? [],
                    'nationality' => $targetProfile->nationality,
                    'country_of_residence' => $targetProfile->country_of_residence,
                    'region' => $targetProfile->region,
                    'bio' => $targetProfile->bio,
                    'photo_privacy' => $targetProfile->photo_privacy,
                    'photo_authorized' => $canSeePhoto,
                    'primary_photo_id' => ($primaryPhoto && $canSeePhoto) ? (int) $primaryPhoto->id : null,
                    'primary_photo_url' => ($primaryPhoto && $canSeePhoto)
                        ? url("/api/v1/profile/photos/{$primaryPhoto->id}/stream")
                        : null,
                    'is_favorited' => $isFavorited,
                ],
                'matchmaking' => $matchmakingContext,
                'viewer_entitlement' => [
                    'has_active_subscription' => $entitlementPayload['has_active_subscription'],
                    'can_send_match_requests' => $entitlementPayload['can_send_match_requests'],
                    'can_send_messages' => $entitlementPayload['can_send_messages'],
                ],
            ],
        ]);
    }

    private function persistProfileData(User $user, array $validated, bool $isInitialRegistration): JsonResponse
    {
        $dob = $validated['date_of_birth'];
        $ageYears = UserProfile::calculateAgeYears($dob);
        $calculatedZodiac = UserProfile::calculateArabicZodiacSign($dob);

        $profile = DB::transaction(function () use ($user, $validated, $ageYears, $calculatedZodiac) {
            $hasChildren = (bool) $validated['has_children'];
            $existingProfile = $user->profile;

            // Preserve 'approved' status when an already-approved member updates their profile fields
            if ($existingProfile?->moderation_status === UserProfile::STATUS_APPROVED) {
                $nextModerationStatus = UserProfile::STATUS_APPROVED;
            } elseif (!UserProfile::isModerationRequired() && $existingProfile?->moderation_status !== UserProfile::STATUS_REJECTED) {
                $nextModerationStatus = UserProfile::STATUS_APPROVED;
            } else {
                $nextModerationStatus = UserProfile::STATUS_PENDING;
            }

            $profile = UserProfile::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'full_name' => trim($validated['full_name']),
                    'gender' => $validated['gender'],
                    'date_of_birth' => $validated['date_of_birth'],
                    'age_years' => $ageYears,
                    'zodiac_sign' => !empty($validated['zodiac_sign'])
                        ? $validated['zodiac_sign']
                        : $calculatedZodiac,
                    'marital_status' => $validated['marital_status'],
                    'previously_married' => (bool) $validated['previously_married'],
                    'has_children' => $hasChildren,
                    'children_count' => $hasChildren ? (int) ($validated['children_count'] ?? 1) : 0,
                    'education_level' => $validated['education_level'],
                    'occupation' => trim($validated['occupation']),
                    'height_cm' => (int) $validated['height_cm'],
                    'smoking_status' => $validated['smoking_status'],
                    'home_ownership' => $validated['home_ownership'],
                    'hobbies' => array_values($validated['hobbies']),
                    'nationality' => trim($validated['nationality']),
                    'country_of_residence' => trim($validated['country_of_residence']),
                    'region' => trim($validated['region']),
                    'bio' => isset($validated['bio']) && trim($validated['bio']) !== ''
                        ? trim($validated['bio'])
                        : null,
                    'is_visible' => array_key_exists('is_visible', $validated)
                        ? (bool) $validated['is_visible']
                        : ($existingProfile ? (bool) $existingProfile->is_visible : true),
                    'photo_privacy' => $validated['photo_privacy']
                        ?? ($existingProfile?->photo_privacy ?? 'public'),
                    'moderation_status' => $nextModerationStatus,
                ]
            );

            $user->update([
                'profile_completed' => true,
                'last_active_at' => now(),
            ]);

            $oppositeGender = $validated['gender'] === 'male'
                ? 'female'
                : ($validated['gender'] === 'female' ? 'male' : null);

            if ($oppositeGender !== null) {
                $existingPref = UserPreference::where('user_id', $user->id)->first();
                if ($existingPref === null) {
                    UserPreference::create([
                        'user_id' => $user->id,
                        'preferred_gender' => $oppositeGender,
                        'min_age' => 18,
                        'max_age' => 65,
                    ]);
                } elseif (empty($existingPref->preferred_gender) || $existingPref->preferred_gender === $validated['gender']) {
                    $existingPref->update([
                        'preferred_gender' => $oppositeGender,
                    ]);
                }
            }

            return $profile;
        });

        $primaryPhoto = $user->photos()->where('is_primary', true)->first()
            ?? $user->photos()->first();

        return response()->json([
            'status' => 'success',
            'message' => $isInitialRegistration
                ? 'تم حفظ ملفك الشخصي بنجاح وإرساله للمراجعة.'
                : 'تم حفظ التعديلات على ملفك الشخصي بنجاح.',
            'data' => [
                'profile_completed' => true,
                'completion_percentage' => $this->calculateCompletionPercentage($profile, $primaryPhoto),
                'profile' => $this->formatProfilePayload($profile, $primaryPhoto),
            ],
        ]);
    }

    private function formatProfilePayload(UserProfile $profile, ?UserPhoto $primaryPhoto): array
    {
        return [
            'id' => $profile->id,
            'user_id' => $profile->user_id,
            'full_name' => $profile->full_name,
            'gender' => $profile->gender,
            'date_of_birth' => $profile->date_of_birth?->format('Y-m-d'),
            'age_years' => UserProfile::calculateAgeYears($profile->date_of_birth),
            'zodiac_sign' => $profile->zodiac_sign,
            'marital_status' => $profile->marital_status,
            'previously_married' => (bool) $profile->previously_married,
            'has_children' => (bool) $profile->has_children,
            'children_count' => (int) $profile->children_count,
            'education_level' => $profile->education_level,
            'occupation' => $profile->occupation,
            'height_cm' => (int) $profile->height_cm,
            'smoking_status' => $profile->smoking_status,
            'home_ownership' => $profile->home_ownership,
            'hobbies' => $profile->hobbies ?? [],
            'nationality' => $profile->nationality,
            'country_of_residence' => $profile->country_of_residence,
            'region' => $profile->region,
            'bio' => $profile->bio,
            'is_visible' => (bool) $profile->is_visible,
            'photo_privacy' => $profile->photo_privacy,
            'moderation_status' => $profile->moderation_status,
            'primary_photo' => $primaryPhoto ? [
                'id' => $primaryPhoto->id,
                'mime_type' => $primaryPhoto->mime_type,
                'file_size_bytes' => $primaryPhoto->file_size_bytes,
                'moderation_status' => $primaryPhoto->moderation_status,
                'stream_url' => url("/api/v1/profile/photos/{$primaryPhoto->id}/stream"),
            ] : null,
        ];
    }

    private function calculateCompletionPercentage(?UserProfile $profile, ?UserPhoto $primaryPhoto): int
    {
        if (!$profile) {
            return 0;
        }

        $score = 0;
        $totalChecks = 10;

        if (!empty($profile->full_name)) $score++;
        if ($profile->date_of_birth !== null) $score++;
        if (!empty($profile->marital_status)) $score++;
        if (!empty($profile->education_level)) $score++;
        if (!empty($profile->occupation)) $score++;
        if ($profile->height_cm >= 120) $score++;
        if (!empty($profile->hobbies)) $score++;
        if (!empty($profile->nationality) && !empty($profile->country_of_residence) && !empty($profile->region)) $score++;
        if (!empty($profile->bio)) $score++;
        if ($primaryPhoto !== null) $score++;

        return (int) round(($score / $totalChecks) * 100);
    }
}
