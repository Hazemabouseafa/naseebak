<?php

namespace App\Http\Middleware;

use App\Models\Administrator;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdminAccountIsActive
{
    /**
     * Ensures the authenticated administrator in the 'admin' guard is active,
     * belongs to the Administrator model (never a regular Google Sign-In member),
     * and enforces MFA session verification if MFA is enabled on the account.
     */
    public function handle(Request $request, Closure $next, ?string $requiredRole = null): Response
    {
        $admin = Auth::guard('admin')->user();

        if (!$admin instanceof Administrator) {
            if ($request->expectsJson()) {
                return response()->json([
                    'status' => 'error',
                    'code' => 'ADMIN_UNAUTHENTICATED',
                    'message' => 'يرجى تسجيل الدخول بحساب مدير معتمد للوصول إلى لوحة تحكم نصيبك.',
                ], 401);
            }

            return redirect()->guest('/admin/login');
        }

        if (!$admin->is_active || !in_array($admin->role, Administrator::ALLOWED_ROLES, true)) {
            Auth::guard('admin')->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            if ($request->expectsJson()) {
                return response()->json([
                    'status' => 'error',
                    'code' => 'ADMIN_ACCOUNT_SUSPENDED',
                    'message' => 'تم إيقاف حساب المدير هذا. لا يمكن الوصول إلى لوحة التحكم.',
                ], 403);
            }

            return redirect('/admin/login')->withErrors([
                'email' => 'تم إيقاف حساب المدير هذا.',
            ]);
        }

        // Enforce MFA verification when MFA is enabled on the administrator account
        if ($admin->mfa_enabled && !$request->session()->get('admin_mfa_verified', false) && !$request->is('admin/mfa*')) {
            if ($request->expectsJson()) {
                return response()->json([
                    'status' => 'error',
                    'code' => 'ADMIN_MFA_REQUIRED',
                    'message' => 'يتطلب الوصول التحقق الثنائي (MFA).',
                ], 403);
            }

            return redirect('/admin/mfa-challenge');
        }

        if ($requiredRole !== null && !$admin->hasRoleOrHigher($requiredRole)) {
            if ($request->expectsJson()) {
                return response()->json([
                    'status' => 'error',
                    'code' => 'ADMIN_ROLE_FORBIDDEN',
                    'message' => 'ليس لديك الصلاحية الكافية لتنفيذ هذا الإجراء الإداري.',
                ], 403);
            }

            abort(403, 'ليس لديك الصلاحية الكافية للوصول إلى هذا القسم.');
        }

        return $next($request);
    }
}
