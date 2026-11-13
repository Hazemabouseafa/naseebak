@extends('layouts.website')

@section('title', 'تسجيل الدخول — نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container" style="max-width: 560px;">
            <div class="surface-card" style="text-align: center; padding: 36px 28px;">
                <img src="{{ asset('assets/images/naseebak-app-icon.png') }}" alt="نَصِيبُكَ" style="width: 68px; height: 68px; border-radius: 18px; margin-bottom: 16px; border: 1px solid var(--border-light); box-shadow: var(--shadow-sm);">

                <h1 style="font-size: 26px; font-weight: 700; color: var(--deep-navy); margin-bottom: 8px;">
                    المتابعة بحسابك في نَصِيبُكَ
                </h1>
                <p style="font-size: 14.5px; color: var(--text-secondary); line-height: 1.8; margin-bottom: 24px;">
                    استخدم نفس حساب Google المرتبط بتطبيق نَصِيبُكَ على الأندرويد لربط اشتراكك تلقائياً والوصول إلى لوحة حسابك.
                </p>

                @if(!empty($errorMessage))
                    <div class="alert alert-danger" style="text-align: right;">
                        {{ $errorMessage }}
                    </div>
                @endif

                @if($oauthConfigured)
                    <a href="{{ route('website.auth.google.redirect', $intendedPlan ? ['plan' => $intendedPlan] : []) }}" class="btn btn-primary btn-lg btn-block" style="margin-bottom: 14px;">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                            <path d="M21.35 11.1h-9.17v2.73h6.51c-.33 3.81-3.5 5.44-6.5 5.44C8.36 19.27 5 16.25 5 12c0-4.1 3.2-7.27 7.2-7.27 3.09 0 4.9 1.97 4.9 1.97L19 4.72S16.56 2 12.1 2C6.42 2 2 6.48 2 12s4.42 10 10.1 10c5.26 0 9.63-3.7 9.63-9.8 0-.6-.06-.9-.38-1.1z"/>
                        </svg>
                        المتابعة باستخدام Google
                    </a>
                @else
                    <div class="alert alert-warning" style="text-align: right;">
                        خدمة تسجيل الدخول عبر Google OAuth على الويب بانتظار استكمال إعداد <code>GOOGLE_WEB_CLIENT_SECRET</code> في الخادم.
                    </div>
                @endif

                @if($intendedPlan)
                    <p style="font-size: 13px; color: var(--text-secondary); margin-top: 8px;">
                        بعد إتمام تسجيل الدخول سيتم تحويلك مباشرة لتأكيد طلب الاشتراك المختار.
                    </p>
                @endif

                <div style="margin-top: 22px; padding-top: 18px; border-top: 1px solid var(--border-light); font-size: 13px; color: var(--text-secondary);">
                    بتسجيل دخولك فأنت توافق على <a href="{{ route('legal.terms_of_service') }}" style="color: var(--primary-blue); font-weight: 600;">شروط الاستخدام</a> و<a href="{{ route('legal.privacy_policy') }}" style="color: var(--primary-blue); font-weight: 600;">سياسة الخصوصية</a>.
                </div>
            </div>
        </div>
    </section>
@endsection
