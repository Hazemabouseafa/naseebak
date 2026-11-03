<?php

namespace App\Policies;

use App\Models\Administrator;
use App\Models\AppSetting;

class AppSettingPolicy
{
    public function viewAny(Administrator $actor): bool
    {
        return $actor->isSuperAdmin();
    }

    public function update(Administrator $actor, ?AppSetting $setting = null): bool
    {
        return $actor->isSuperAdmin();
    }
}
