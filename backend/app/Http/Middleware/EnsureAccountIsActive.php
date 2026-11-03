<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAccountIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'code' => 'UNAUTHENTICATED',
                'message' => 'يرجى تسجيل الدخول للمتابعة.',
            ], 401);
        }

        if ($user->account_status === 'suspended') {
            return response()->json([
                'status' => 'error',
                'code' => 'ACCOUNT_SUSPENDED',
                'message' => 'تم تقييد هذا الحساب من قِبل الإدارة لمخالفة شروط الاستخدام.',
                'suspension_reason' => $user->suspension_reason ?: 'مخالفة سياسات الاستخدام والأمان في تطبيق نصيبك.',
            ], 403);
        }

        if ($user->account_status !== 'active') {
            return response()->json([
                'status' => 'error',
                'code' => 'ACCOUNT_INACTIVE',
                'message' => 'هذا الحساب غير نشط حالياً.',
            ], 403);
        }

        return $next($request);
    }
}
