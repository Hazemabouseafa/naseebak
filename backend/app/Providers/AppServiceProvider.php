<?php

namespace App\Providers;

use App\Listeners\DomainNotificationEventSubscriber;
use App\Models\AdminAuditLog;
use App\Models\Administrator;
use App\Models\AppSetting;
use App\Models\PaymentSetting;
use App\Policies\AdminAuditLogPolicy;
use App\Policies\AdministratorPolicy;
use App\Policies\AppSettingPolicy;
use App\Policies\PaymentSettingPolicy;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        if ($this->app->environment(['production', 'staging']) || config('naseebak.force_https', false)) {
            URL::forceScheme('https');
        }

        Gate::policy(Administrator::class, AdministratorPolicy::class);
        Gate::policy(PaymentSetting::class, PaymentSettingPolicy::class);
        Gate::policy(AppSetting::class, AppSettingPolicy::class);
        Gate::policy(AdminAuditLog::class, AdminAuditLogPolicy::class);

        Event::subscribe(DomainNotificationEventSubscriber::class);
    }
}
