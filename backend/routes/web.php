<?php

use App\Http\Controllers\Admin\AdminOperationsController;
use App\Http\Controllers\Api\V1\HealthCheckController;
use App\Http\Controllers\Web\AccountDeletionWebController;
use App\Http\Controllers\Web\GoogleWebAuthController;
use App\Http\Controllers\Web\WebsiteCheckoutController;
use App\Http\Controllers\Web\WebsiteController;
use App\Http\Controllers\Web\WebSubscriptionPortalController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Naseebak Web & Administration Routes
|--------------------------------------------------------------------------
| 1. Filament Admin Panel mounts at /admin using the 'admin' session guard.
| 2. Official Website & Web Subscription Checkout use Google Sign-In
|    ('google_sub' matching) and the 'web' session guard.
*/

Route::get('/', [WebsiteController::class, 'landing'])->name('website.home');
Route::get('/support', [WebsiteController::class, 'support'])->name('website.support');
Route::get('/plans', [WebsiteCheckoutController::class, 'plans'])->name('website.plans');

// Website Google OAuth 2.0 Authentication
Route::get('/login', [GoogleWebAuthController::class, 'showLogin'])->name('website.login');
Route::get('/auth/google/redirect', [GoogleWebAuthController::class, 'redirect'])
    ->middleware('throttle:30,1')
    ->name('website.auth.google.redirect');
Route::get('/auth/google/callback', [GoogleWebAuthController::class, 'callback'])
    ->middleware('throttle:30,1')
    ->name('website.auth.google.callback');
Route::post('/auth/logout', [GoogleWebAuthController::class, 'logout'])
    ->name('website.auth.logout');

// Payment gateway browser return page (reads authoritative DB status only)
Route::get('/payment/return/{reference}', [WebsiteCheckoutController::class, 'paymentReturn'])
    ->name('website.payment.return');

// Authenticated Customer Website Dashboard & Web Checkout
Route::middleware(['auth:web', 'active_account'])->group(function () {
    Route::get('/account', [WebsiteCheckoutController::class, 'account'])->name('website.account');
    Route::get('/plans/{planCode}/checkout', [WebsiteCheckoutController::class, 'confirmOrder'])
        ->name('website.checkout.confirm');
    Route::post('/checkout', [WebsiteCheckoutController::class, 'createOrder'])
        ->middleware('throttle:15,1')
        ->name('website.checkout.store');
    Route::get('/orders/{reference}/status', [WebsiteCheckoutController::class, 'orderStatus'])
        ->name('website.orders.status');
    Route::post('/orders/{reference}/cancel', [WebsiteCheckoutController::class, 'cancelOrder'])
        ->middleware('throttle:15,1')
        ->name('website.orders.cancel');
});

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
    Route::get('/subscription-terms', [WebsiteController::class, 'subscriptionTerms'])
        ->name('legal.subscription_terms');
    Route::get('/refund-policy', [WebsiteController::class, 'refundPolicy'])
        ->name('legal.refund_policy');
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

        Route::delete('/members/{member}', [AdminOperationsController::class, 'deleteMember'])
            ->whereNumber('member')
            ->name('admin.operations.members.delete');

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

            Route::put('/settings/plans/{planCode}', [AdminOperationsController::class, 'updatePlanPricing'])
                ->name('admin.operations.settings.plan_pricing');

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
