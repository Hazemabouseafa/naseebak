<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

// Recurring production maintenance tasks (executed via single scheduler container/cron once per minute):
// 1. Subscription expiration checks, 3-day approaching expiry reminders (deduplicated),
//    scheduled announcement campaign dispatch, and old notification/delivery log cleanup:
Schedule::command('naseebak:expire-subscriptions')
    ->everyFiveMinutes()
    ->withoutOverlapping(10)
    ->onOneServer();

// 2. Daily pruning of expired Sanctum personal access tokens:
Schedule::command('sanctum:prune-expired --hours=24')
    ->dailyAt('03:15')
    ->withoutOverlapping(15)
    ->onOneServer();
