<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureProfileIsCompleted
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || !$user->profile_completed || !$user->profile) {
            return response()->json([
                'status' => 'error',
                'code' => 'PROFILE_INCOMPLETE',
                'message' => 'يرجى استكمال بيانات ملفك الشخصي أولاً للمتابعة.',
            ], 403);
        }

        return $next($request);
    }
}
