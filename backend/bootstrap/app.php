<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->trustProxies(at: env('TRUSTED_PROXIES', '*'));
        $middleware->statefulApi();
        $middleware->alias([
            'active_account' => \App\Http\Middleware\EnsureAccountIsActive::class,
            'profile_completed' => \App\Http\Middleware\EnsureProfileIsCompleted::class,
            'subscribed' => \App\Http\Middleware\EnsureActiveSubscription::class,
            'admin_active' => \App\Http\Middleware\EnsureAdminAccountIsActive::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->shouldRenderJsonWhen(function (Request $request, Throwable $e) {
            return $request->is('api/*') || $request->is('admin/operations/*') || $request->expectsJson();
        });

        $exceptions->render(function (\Illuminate\Auth\AuthenticationException $e, Request $request) {
            if (in_array('admin', $e->guards(), true) || $request->is('admin/operations/*')) {
                return response()->json([
                    'status' => 'error',
                    'code' => 'ADMIN_UNAUTHENTICATED',
                    'message' => 'يجب تسجيل الدخول بحساب مشرف معتمد للوصول إلى لوحة التحكم.',
                ], 401);
            }
            return null;
        });
    })->create();
