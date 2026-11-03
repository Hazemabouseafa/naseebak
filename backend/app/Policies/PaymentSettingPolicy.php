<?php

namespace App\Policies;

use App\Models\Administrator;
use App\Models\PaymentSetting;

class PaymentSettingPolicy
{
    public function viewAny(Administrator $actor): bool
    {
        return $actor->isSuperAdmin();
    }

    public function view(Administrator $actor, PaymentSetting $setting): bool
    {
        return $actor->isSuperAdmin();
    }

    public function updatePricing(Administrator $actor): bool
    {
        return $actor->isSuperAdmin();
    }

    public function switchGateway(Administrator $actor): bool
    {
        return $actor->isSuperAdmin();
    }
}
