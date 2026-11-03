<?php

namespace App\Policies;

use App\Models\AdminAuditLog;
use App\Models\Administrator;

class AdminAuditLogPolicy
{
    public function viewAny(Administrator $actor): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }

    public function view(Administrator $actor, AdminAuditLog $log): bool
    {
        return $actor->isSuperAdmin() || $actor->isModerator();
    }

    public function create(Administrator $actor): bool
    {
        return false;
    }

    public function update(Administrator $actor, AdminAuditLog $log): bool
    {
        return false;
    }

    public function delete(Administrator $actor, AdminAuditLog $log): bool
    {
        return false;
    }
}
