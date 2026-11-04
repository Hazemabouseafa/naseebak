<?php

use App\Http\Controllers\Admin\AdminOperationsController;
use App\Http\Controllers\Api\V1\HealthCheckController;
use App\Http\Controllers\Web\AccountDeletionWebController;
use App\Http\Controllers\Web\WebSubscriptionPortalController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Naseebak Web & Administration Routes
|--------------------------------------------------------------------------
| 1. Filament Admin Panel mounts at /admin using the 'admin' session guard.
| 2. Separate Web Customer Subscription Portal mounts at /membership using
|    Google OpenID Connect ('google_sub' matching) and the 'web' session guard.
*/

Route::get('/', fn () => response()->json([
    'app' => 'نصيبك — Naseebak Platform',
    'admin_dashboard' => url('/admin'),
    'legal_delete_account' => url('/legal/delete-account'),
]));

// Google Play Compliance & Legal Documentation
Route::prefix('legal')->group(function () {
    Route::get('/delete-account', [AccountDeletionWebController::class, 'showDeleteAccountPage'])
        ->name('legal.delete_account');
    Route::post('/delete-account', [AccountDeletionWebController::class, 'submitDeletionRequest'])
        ->middleware('throttle:5,1')
        ->name('legal.delete_account.submit');
    Route::get('/confirm-delete-account/{id}/{hash}', [AccountDeletionWebController::class, 'showConfirmDeletionPage'])
        ->name('legal.confirm_delete_account');
    Route::post('/confirm-delete-account/{id}/{hash}', [AccountDeletionWebController::class, 'executeConfirmedDeletion'])
        ->middleware('throttle:5,1')
        ->name('legal.execute_confirmed_deletion');

    Route::view('/privacy-policy', 'legal.privacy_policy')
        ->name('legal.privacy_policy');
    Route::view('/terms-of-service', 'legal.terms_of_service')
        ->name('legal.terms_of_service');
    Route::view('/child-safety', 'legal.child_safety')
        ->name('legal.child_safety');
});

// Separate Web Customer Subscription Portal (Paymob / Sha7nawy Web Checkout)
Route::prefix('membership')->group(function () {
    Route::get('/', [WebSubscriptionPortalController::class, 'showPortal'])
        ->name('membership.portal');

    Route::post('/auth/google', [WebSubscriptionPortalController::class, 'loginWithGoogle'])
        ->middleware('throttle:15,1')
        ->name('membership.auth.google');

    Route::middleware(['auth:web,sanctum', 'active_account'])->group(function () {
        Route::get('/status', [WebSubscriptionPortalController::class, 'status'])
            ->name('membership.status');

        Route::post('/checkout', [WebSubscriptionPortalController::class, 'createCheckoutSession'])
            ->middleware('throttle:15,1')
            ->name('membership.checkout');
    });
});

Route::prefix('admin/operations')->group(function () {
    // Rate-limited administrator login
    Route::post('/login', [AdminOperationsController::class, 'login'])
        ->middleware('throttle:5,1')
        ->name('admin.operations.login');

    // Authenticated Administrator & Moderator actions
    Route::middleware(['auth:admin', 'admin_active'])->group(function () {
        Route::get('/health', [HealthCheckController::class, 'adminDiagnostics'])
            ->name('admin.operations.health');

        Route::post('/logout', [AdminOperationsController::class, 'logout'])
            ->name('admin.operations.logout');

        // Private photo preview stream for moderation
        Route::get('/photos/{photo}/stream', [AdminOperationsController::class, 'streamPhotoForModeration'])
            ->whereNumber('photo')
            ->name('admin.operations.photos.stream');

        // Member account suspension & restoration
        Route::post('/members/{member}/suspend', [AdminOperationsController::class, 'suspendMember'])
            ->whereNumber('member')
            ->name('admin.operations.members.suspend');

        Route::post('/members/{member}/restore', [AdminOperationsController::class, 'restoreMember'])
            ->whereNumber('member')
            ->name('admin.operations.members.restore');

        // Profile moderation (Approve, Reject, Request Correction)
        Route::post('/profiles/{profile}/moderate', [AdminOperationsController::class, 'moderateProfile'])
            ->whereNumber('profile')
            ->name('admin.operations.profiles.moderate');

        // Photo moderation (Approve, Reject, Remove prohibited file)
        Route::post('/photos/{photo}/moderate', [AdminOperationsController::class, 'moderatePhoto'])
            ->whereNumber('photo')
            ->name('admin.operations.photos.moderate');

        // User reports moderation
        Route::post('/reports/{report}/handle', [AdminOperationsController::class, 'handleReport'])
            ->whereNumber('report')
            ->name('admin.operations.reports.handle');

        // Super Admin ONLY endpoints
        Route::middleware('admin_active:super_admin')->group(function () {
            Route::put('/settings/pricing', [AdminOperationsController::class, 'updateSubscriptionPricing'])
                ->name('admin.operations.settings.pricing');

            Route::put('/settings/payment-gateway', [AdminOperationsController::class, 'switchPaymentGateway'])
                ->name('admin.operations.settings.payment_gateway');

            Route::put('/settings/application', [AdminOperationsController::class, 'updateAppSettings'])
                ->name('admin.operations.settings.application');

            Route::post('/administrators', [AdminOperationsController::class, 'createAdministrator'])
                ->name('admin.operations.administrators.store');

            Route::patch('/administrators/{administrator}', [AdminOperationsController::class, 'updateAdministrator'])
                ->whereNumber('administrator')
                ->name('admin.operations.administrators.update');

            Route::post('/notifications/campaigns/preview', [AdminOperationsController::class, 'previewAnnouncementCampaign'])
                ->name('admin.operations.notifications.preview');

            Route::post('/notifications/campaigns', [AdminOperationsController::class, 'sendAnnouncementCampaign'])
                ->middleware('throttle:10,1')
                ->name('admin.operations.notifications.send');
        });
    });
});
