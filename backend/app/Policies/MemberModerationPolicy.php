<?php

namespace App\Policies;

use App\Models\Administrator;
use App\Models\User;
use App\Models\UserPhoto;
use App\Models\UserProfile;
use App\Models\UserReport;

class MemberModerationPolicy
{
    public function viewMembers(Administrator $actor): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }

    public function viewMemberPrivateEmail(Administrator $actor): bool
    {
        return $actor->isSuperAdmin();
    }

    public function suspendOrRestoreMember(Administrator $actor, User $member): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }

    public function deleteMember(Administrator $actor, User $member): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }

    public function moderateProfile(Administrator $actor, UserProfile $profile): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }

    public function moderatePhoto(Administrator $actor, UserPhoto $photo): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }

    public function handleReport(Administrator $actor, UserReport $report): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }
}
