<?php

namespace App\Policies;

use App\Models\Administrator;

class AdministratorPolicy
{
    public function viewAny(Administrator $actor): bool
    {
        return $actor->isSuperAdmin();
    }

    public function view(Administrator $actor, Administrator $target): bool
    {
        return $actor->isSuperAdmin();
    }

    public function create(Administrator $actor): bool
    {
        return $actor->isSuperAdmin();
    }

    public function update(Administrator $actor, Administrator $target): bool
    {
        return $actor->isSuperAdmin();
    }

    /**
     * Prevents self-role escalation and prevents deactivating/demoting the final active Super Admin.
     */
    public function changeRoleOrStatus(Administrator $actor, Administrator $target, string $newRole, bool $newIsActive): bool
    {
        if (!$actor->isSuperAdmin()) {
            return false;
        }

        if ($target->role === Administrator::ROLE_SUPER_ADMIN && ($newRole !== Administrator::ROLE_SUPER_ADMIN || !$newIsActive)) {
            $otherActiveSuperAdmins = Administrator::where('role', Administrator::ROLE_SUPER_ADMIN)
                ->where('is_active', true)
                ->where('id', '!=', $target->id)
                ->count();

            if ($otherActiveSuperAdmins === 0) {
                return false;
            }
        }

        return true;
    }

    public function delete(Administrator $actor, Administrator $target): bool
    {
        if (!$actor->isSuperAdmin()) {
            return false;
        }

        if ($actor->id === $target->id) {
            return false;
        }

        if ($target->role === Administrator::ROLE_SUPER_ADMIN && $target->is_active) {
            $otherActiveSuperAdmins = Administrator::where('role', Administrator::ROLE_SUPER_ADMIN)
                ->where('is_active', true)
                ->where('id', '!=', $target->id)
                ->count();

            if ($otherActiveSuperAdmins === 0) {
                return false;
            }
        }

        return true;
    }
}
