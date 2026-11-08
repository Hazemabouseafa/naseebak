<?php

namespace App\Services\Profile;

use App\Models\BlockedUser;
use App\Models\MatchmakingRequest;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;

class ProfileAccessControlService
{
    /**
     * Determines if $viewer is blocked by or has blocked $targetUser.
     */
    public function isBlockedBetween(int $viewerUserId, int $targetUserId): bool
    {
        if ($viewerUserId === $targetUserId) {
            return false;
        }

        return BlockedUser::where(function ($query) use ($viewerUserId, $targetUserId) {
            $query->where('blocker_id', $viewerUserId)
                ->where('blocked_id', $targetUserId);
        })->orWhere(function ($query) use ($viewerUserId, $targetUserId) {
            $query->where('blocker_id', $targetUserId)
                ->where('blocked_id', $viewerUserId);
        })->exists();
    }

    /**
     * Determines if $viewer has an accepted matchmaking request with $targetUser.
     */
    public function hasAcceptedMatchWith(int $viewerUserId, int $targetUserId): bool
    {
        if ($viewerUserId === $targetUserId) {
            return true;
        }

        return MatchmakingRequest::where('status', 'accepted')
            ->where(function ($query) use ($viewerUserId, $targetUserId) {
                $query->where(function ($q) use ($viewerUserId, $targetUserId) {
                    $q->where('sender_id', $viewerUserId)
                        ->where('recipient_id', $targetUserId);
                })->orWhere(function ($q) use ($viewerUserId, $targetUserId) {
                    $q->where('sender_id', $targetUserId)
                        ->where('recipient_id', $viewerUserId);
                });
            })
            ->exists();
    }

    /**
     * Checks whether $viewer can view $targetUser's profile at all.
     * - Users can ALWAYS view their own profile.
     * - Administrators/Moderators can view profiles for moderation.
     * - Suspended or inactive viewers cannot access anything.
     * - Blocked users cannot view each other's profiles.
     * - Hidden profiles (is_visible = false) cannot be viewed by regular members unless an accepted match exists.
     */
    public function canViewProfile(User $viewer, User $targetUser, ?UserProfile $targetProfile = null): bool
    {
        if ($viewer->account_status !== 'active') {
            return false;
        }

        if ($viewer->id === $targetUser->id) {
            return true;
        }

        if (in_array($viewer->role, ['super_admin', 'moderator'], true)) {
            return true;
        }

        if ($targetUser->account_status !== 'active') {
            return false;
        }

        if ($this->isBlockedBetween($viewer->id, $targetUser->id)) {
            return false;
        }

        $profile = $targetProfile ?? $targetUser->profile;
        if (!$profile) {
            return false;
        }

        // Hidden profiles are excluded from search & discovery unless the two members already have an accepted match
        if (!$profile->is_visible && !$this->hasAcceptedMatchWith($viewer->id, $targetUser->id)) {
            return false;
        }

        return true;
    }

    /**
     * Enforces photo visibility rules server-side:
     * - Owner can ALWAYS view their own photos.
     * - Admins/Moderators can view photos for moderation.
     * - Blocked or suspended users are strictly denied.
     * - If profile is hidden and no accepted match exists, denied.
     * - Photo privacy modes:
     *   1. 'public' -> All authenticated active members
     *   2. 'subscribers_only' -> Only members with an active paid subscription (or accepted match)
     *   3. 'accepted_matches_only' -> Only members with an accepted matchmaking request
     */
    public function canAccessPhoto(User $viewer, UserPhoto $photo): bool
    {
        if ($viewer->account_status !== 'active') {
            return false;
        }

        if ($viewer->id === $photo->user_id) {
            return true;
        }

        if (in_array($viewer->role, ['super_admin', 'moderator'], true)) {
            return true;
        }

        // Unapproved or rejected photos are NEVER visible to other regular members
        if (!$photo->isModerationApprovedForDisplay()) {
            return false;
        }

        $owner = $photo->user;
        if (!$owner || $owner->account_status !== 'active') {
            return false;
        }

        $ownerProfile = $owner->profile;
        if (!$this->canViewProfile($viewer, $owner, $ownerProfile)) {
            return false;
        }

        $photoPrivacy = $ownerProfile?->photo_privacy ?? 'public';

        return match ($photoPrivacy) {
            'public' => true,
            'subscribers_only' => $viewer->hasActiveSubscription()
                || $this->hasAcceptedMatchWith($viewer->id, $owner->id),
            'accepted_matches_only' => $this->hasAcceptedMatchWith($viewer->id, $owner->id),
            default => false,
        };
    }
}
