<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BroadcastAuthController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\DeviceTokenController;
use App\Http\Controllers\Api\V1\DiscoveryController;
use App\Http\Controllers\Api\V1\FavoriteController;
use App\Http\Controllers\Api\V1\HealthCheckController;
use App\Http\Controllers\Api\V1\MatchmakingRequestController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\NotificationPreferenceController;
use App\Http\Controllers\Api\V1\PaymentWebhookController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\SubscriptionController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Naseebak REST API v1 Routes
|--------------------------------------------------------------------------
| Authentication: Google Sign-In OpenID Connect ID Token -> Laravel Sanctum
*/

Route::prefix('v1')->group(function () {
    // Public Health & Version check (safe readiness probe for Coolify & uptime monitors)
    Route::get('/health', [HealthCheckController::class, 'publicHealth']);

    // 1. Google OAuth / OpenID Connect Sign-In (Rate-limited)
    Route::post('/auth/google', [AuthController::class, 'loginWithGoogle'])
        ->middleware('throttle:15,1');

    // 2. External Payment Provider Webhooks & Google Play RTDN (Server-to-Server, Signature Verified)
    Route::post('/webhooks/paymob', [PaymentWebhookController::class, 'handlePaymobWebhook'])
        ->middleware('throttle:60,1');
    Route::post('/webhooks/sha7nawy', [PaymentWebhookController::class, 'handleSha7nawyWebhook'])
        ->middleware('throttle:60,1');
    Route::post('/webhooks/google-play/rtdn', [PaymentWebhookController::class, 'handleGooglePlayRtdn'])
        ->middleware('throttle:120,1');

    // Authenticated Routes (Sanctum + Active Account Verification)
    Route::middleware(['auth:sanctum', 'active_account'])->group(function () {
        // Session & Identity
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::delete('/auth/account', [AuthController::class, 'deleteAccount'])
            ->middleware('throttle:5,1');

        // Phase 1 & Phase 2: Complete Profile Management API
        Route::get('/profile', [ProfileController::class, 'showOwnProfile']);
        Route::patch('/profile', [ProfileController::class, 'updateProfile'])
            ->middleware('throttle:20,1');
        Route::post('/profile/complete', [ProfileController::class, 'upsertProfile'])
            ->middleware('throttle:20,1');

        // Profile Photo Upload & Authenticated Private Streaming
        Route::post('/profile/photo', [ProfileController::class, 'uploadPhoto'])
            ->middleware('throttle:10,1');
        Route::get('/profile/photos/{photo}/stream', [ProfileController::class, 'streamProtectedPhoto'])
            ->whereNumber('photo');

        // Profile & Photo Privacy Settings
        Route::get('/profile/privacy', [ProfileController::class, 'getPrivacy']);
        Route::patch('/profile/privacy', [ProfileController::class, 'updatePrivacy'])
            ->middleware('throttle:30,1');

        // Phase 3: Discovery, Advanced Search, Saved Preferences & Member Profiles
        Route::get('/discovery', [DiscoveryController::class, 'index']);
        Route::get('/members/search', [DiscoveryController::class, 'search'])
            ->middleware('throttle:60,1');
        Route::get('/search/preferences', [DiscoveryController::class, 'getSearchPreferences']);
        Route::put('/search/preferences', [DiscoveryController::class, 'updateSearchPreferences'])
            ->middleware('throttle:30,1');

        Route::get('/members/{targetUser}/profile', [ProfileController::class, 'showMemberProfile'])
            ->whereNumber('targetUser');

        // Phase 3: Favorites Management
        Route::get('/favorites', [FavoriteController::class, 'index']);
        Route::post('/favorites/{member}', [FavoriteController::class, 'store'])
            ->whereNumber('member')
            ->middleware('throttle:30,1');
        Route::delete('/favorites/{member}', [FavoriteController::class, 'destroy'])
            ->whereNumber('member')
            ->middleware('throttle:30,1');

        // Safety Actions on Member Profile & Chat (Block & Report — Rate-limited)
        Route::get('/blocked-members', [FavoriteController::class, 'blockedMembers'])
            ->middleware('throttle:30,1');
        Route::post('/members/{member}/block', [FavoriteController::class, 'blockMember'])
            ->whereNumber('member')
            ->middleware('throttle:20,1');
        Route::delete('/members/{member}/block', [FavoriteController::class, 'unblockMember'])
            ->whereNumber('member')
            ->middleware('throttle:20,1');
        Route::post('/members/{member}/report', [FavoriteController::class, 'reportMember'])
            ->whereNumber('member')
            ->middleware('throttle:10,1');

        // Phase 5: Unified Subscription & Google Play Billing Verification API
        Route::get('/subscription', [SubscriptionController::class, 'show']);
        Route::get('/subscription/plans', [SubscriptionController::class, 'plans']);
        Route::get('/subscription/entitlement', [SubscriptionController::class, 'entitlement']);
        Route::post('/subscription/google-play/verify', [SubscriptionController::class, 'verifyGooglePlayPurchase'])
            ->middleware('throttle:20,1');
        Route::get('/subscription/history', [SubscriptionController::class, 'history']);

        // Phase 6: Matchmaking Requests API
        Route::get('/matchmaking/requests', [MatchmakingRequestController::class, 'index']);
        Route::get('/matchmaking/requests/sent', [MatchmakingRequestController::class, 'sent']);
        Route::get('/matchmaking/requests/incoming', [MatchmakingRequestController::class, 'incoming']);
        Route::post('/matchmaking/requests', [MatchmakingRequestController::class, 'store'])
            ->middleware('throttle:20,1');
        Route::get('/matchmaking/requests/{matchmakingRequest}', [MatchmakingRequestController::class, 'show'])
            ->whereNumber('matchmakingRequest');
        Route::post('/matchmaking/requests/{matchmakingRequest}/accept', [MatchmakingRequestController::class, 'accept'])
            ->whereNumber('matchmakingRequest')
            ->middleware('throttle:30,1');
        Route::post('/matchmaking/requests/{matchmakingRequest}/reject', [MatchmakingRequestController::class, 'reject'])
            ->whereNumber('matchmakingRequest')
            ->middleware('throttle:30,1');
        Route::post('/matchmaking/requests/{matchmakingRequest}/cancel', [MatchmakingRequestController::class, 'cancel'])
            ->whereNumber('matchmakingRequest')
            ->middleware('throttle:30,1');

        // Phase 6: Authorized Private Conversations & Messaging API
        Route::get('/conversations', [ConversationController::class, 'index']);
        Route::get('/conversations/{conversation}', [ConversationController::class, 'show'])
            ->whereNumber('conversation');
        Route::get('/conversations/{conversation}/messages', [ConversationController::class, 'messages'])
            ->whereNumber('conversation');
        Route::post('/conversations/{conversation}/messages', [ConversationController::class, 'sendMessage'])
            ->whereNumber('conversation')
            ->middleware('throttle:60,1');
        Route::post('/conversations/{conversation}/read', [ConversationController::class, 'markRead'])
            ->whereNumber('conversation')
            ->middleware('throttle:60,1');

        // Phase 6: Sanctum-Authenticated Laravel Reverb Private Channel Authorization
        Route::post('/broadcasting/auth', [BroadcastAuthController::class, 'authenticate'])
            ->middleware('throttle:60,1');

        // Phase 7: FCM Device Registration Token Management
        Route::post('/devices/register', [DeviceTokenController::class, 'register'])
            ->middleware('throttle:30,1');
        Route::delete('/devices/unregister', [DeviceTokenController::class, 'unregister'])
            ->middleware('throttle:30,1');

        // Phase 7: In-App Notification Center API
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
        Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead'])
            ->middleware('throttle:30,1');
        Route::post('/notifications/{notification}/read', [NotificationController::class, 'markRead'])
            ->whereNumber('notification')
            ->middleware('throttle:60,1');
        Route::delete('/notifications/{notification}', [NotificationController::class, 'destroy'])
            ->whereNumber('notification')
            ->middleware('throttle:30,1');

        // Phase 7: Notification Preferences API
        Route::get('/notification-preferences', [NotificationPreferenceController::class, 'show']);
        Route::patch('/notification-preferences', [NotificationPreferenceController::class, 'update'])
            ->middleware('throttle:30,1');

        // Phase 5 Paid-Entitlement Gate Check
        Route::middleware(['profile_completed', 'subscribed'])->group(function () {
            Route::post('/subscription/authorized-contact-check', fn () => response()->json([
                'status' => 'success',
                'can_initiate_contact' => true,
            ]));
        });
    });
});
