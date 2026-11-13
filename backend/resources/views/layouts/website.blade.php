<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'نَصِيبُكَ — كل حكاية جميلة ليها بداية')</title>
    <meta name="description" content="@yield('meta_description', 'نَصِيبُكَ مساحة للتعارف الجاد بهدف الزواج، تساعدك تكتشف أشخاص يشاركونك أهدافك وتبدأ رحلة تعارف بثقة وخصوصية.')">
    <link rel="icon" type="image/png" href="{{ asset('assets/images/naseebak-app-icon.png') }}">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="{{ asset('assets/css/naseebak-website.css') }}?v={{ file_exists(public_path('assets/css/naseebak-website.css')) ? filemtime(public_path('assets/css/naseebak-website.css')) : '1' }}">
    @stack('head')
</head>
<body>
    @php
        $webUser = Auth::guard('web')->user();
        $supportData = \App\Models\AppSetting::where('setting_key', 'platform_general')->first()?->setting_value ?? [];
        $footerSupportEmail = $supportData['support_email'] ?? 'support@naseebak.app';
    @endphp

    <header class="site-header">
        <div class="container nav-inner">
            <a href="{{ route('website.home') }}" class="brand-link">
                <img src="{{ asset('assets/images/naseebak-app-icon.png') }}" alt="شعار نَصِيبُكَ" class="brand-logo-img">
                <span class="brand-text">
                    <span class="brand-name-ar">نَصِيبُكَ</span>
                    <span class="brand-sub en-text">Naseebak</span>
                </span>
            </a>

            <nav class="nav-links" aria-label="التنقل الرئيسي">
                <a href="{{ route('website.home') }}#about" class="nav-link">عن نَصِيبُكَ</a>
                <a href="{{ route('website.home') }}#features" class="nav-link">المزايا</a>
                <a href="{{ route('website.home') }}#how-it-works" class="nav-link">كيف يعمل</a>
                <a href="{{ route('website.plans') }}" class="nav-link {{ request()->routeIs('website.plans*') ? 'active' : '' }}">باقات الاشتراك</a>
                <a href="{{ route('website.support') }}" class="nav-link {{ request()->routeIs('website.support') ? 'active' : '' }}">الدعم والتواصل</a>
            </nav>

            <div class="nav-actions">
                @if($webUser)
                    <a href="{{ route('website.account') }}" class="btn btn-outline btn-sm">
                        حسابي في نَصِيبُكَ
                    </a>
                    <a href="{{ route('website.plans') }}" class="btn btn-primary btn-sm">
                        باقات الاشتراك
                    </a>
                @else
                    <a href="{{ route('website.auth.google.redirect') }}" class="btn btn-outline btn-sm">
                        المتابعة باستخدام Google
                    </a>
                    <a href="{{ route('website.plans') }}" class="btn btn-primary btn-sm">
                        اشترك الآن
                    </a>
                @endif
            </div>

            <button type="button" class="mobile-menu-btn" id="mobile-menu-toggle" aria-label="فتح القائمة" aria-expanded="false">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
                    <line x1="3" y1="6" x2="21" y2="6"></line>
                    <line x1="3" y1="12" x2="21" y2="12"></line>
                    <line x1="3" y1="18" x2="21" y2="18"></line>
                </svg>
            </button>
        </div>

        <div class="mobile-drawer" id="mobile-drawer">
            <div class="mobile-drawer-links">
                <a href="{{ route('website.home') }}#about">عن نَصِيبُكَ</a>
                <a href="{{ route('website.home') }}#features">المزايا</a>
                <a href="{{ route('website.home') }}#how-it-works">كيف يعمل</a>
                <a href="{{ route('website.plans') }}">باقات الاشتراك</a>
                <a href="{{ route('website.support') }}">الدعم والتواصل</a>
                @if($webUser)
                    <a href="{{ route('website.account') }}">حسابي في نَصِيبُكَ</a>
                @endif
            </div>
            <div style="display: flex; flex-direction: column; gap: 10px;">
                @if($webUser)
                    <a href="{{ route('website.account') }}" class="btn btn-primary btn-block">حسابي في نَصِيبُكَ</a>
                @else
                    <a href="{{ route('website.auth.google.redirect') }}" class="btn btn-outline btn-block">المتابعة باستخدام Google</a>
                    <a href="{{ route('website.plans') }}" class="btn btn-primary btn-block">اشترك الآن</a>
                @endif
            </div>
        </div>
    </header>

    <main>
        @yield('content')
    </main>

    <footer class="site-footer">
        <div class="container">
            <div class="footer-grid">
                <div>
                    <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 14px;">
                        <img src="{{ asset('assets/images/naseebak-app-icon.png') }}" alt="نَصِيبُكَ" style="width: 44px; height: 44px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.2);">
                        <div>
                            <div style="font-size: 20px; font-weight: 700; color: #FFFFFF;">نَصِيبُكَ</div>
                            <div style="font-size: 12px; color: var(--premium-gold);">كل حكاية جميلة ليها بداية</div>
                        </div>
                    </div>
                    <p style="font-size: 14px; line-height: 1.8; color: rgba(255,255,255,0.78); max-width: 340px;">
                        نَصِيبُكَ مساحة للتعارف الجاد بهدف الزواج، مصممة ببيئة عربية محترمة تضع الخصوصية والأمان في المقدمة للراشدين (+18).
                    </p>
                </div>

                <div>
                    <div class="footer-title">المنصة</div>
                    <ul class="footer-links">
                        <li><a href="{{ route('website.home') }}#about">عن نَصِيبُكَ</a></li>
                        <li><a href="{{ route('website.home') }}#features">مزايا التطبيق</a></li>
                        <li><a href="{{ route('website.home') }}#how-it-works">كيف يعمل التطبيق</a></li>
                        <li><a href="{{ route('website.plans') }}">باقات الاشتراك</a></li>
                    </ul>
                </div>

                <div>
                    <div class="footer-title">السياسات والشروط</div>
                    <ul class="footer-links">
                        <li><a href="{{ route('legal.privacy_policy') }}">سياسة الخصوصية</a></li>
                        <li><a href="{{ route('legal.terms_of_service') }}">شروط الاستخدام</a></li>
                        <li><a href="{{ route('legal.subscription_terms') }}">شروط الاشتراك</a></li>
                        <li><a href="{{ route('legal.refund_policy') }}">سياسة الاسترداد</a></li>
                        <li><a href="{{ route('legal.delete_account') }}">حذف الحساب والبيانات</a></li>
                    </ul>
                </div>

                <div>
                    <div class="footer-title">الدعم والتواصل</div>
                    <ul class="footer-links">
                        <li><a href="{{ route('website.support') }}">مركز المساعدة والتواصل</a></li>
                        <li><a href="mailto:{{ $footerSupportEmail }}">{{ $footerSupportEmail }}</a></li>
                        @if($webUser)
                            <li><a href="{{ route('website.account') }}">حسابي في نَصِيبُكَ</a></li>
                        @else
                            <li><a href="{{ route('website.auth.google.redirect') }}">تسجيل الدخول عبر Google</a></li>
                        @endif
                    </ul>
                </div>
            </div>

            <div class="footer-bottom">
                <div>جميع الحقوق محفوظة &copy; {{ date('Y') }} نَصِيبُكَ — <span class="en-text">Naseebak</span></div>
                <div>الاشتراكات تُدفع وتُفعل عبر الموقع الإلكتروني المرتبط بنفس حسابك في التطبيق.</div>
            </div>
        </div>
    </footer>

    <script>
        (function () {
            var toggle = document.getElementById('mobile-menu-toggle');
            var drawer = document.getElementById('mobile-drawer');
            if (toggle && drawer) {
                toggle.addEventListener('click', function () {
                    var open = drawer.classList.toggle('open');
                    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
                });
                drawer.querySelectorAll('a').forEach(function (link) {
                    link.addEventListener('click', function () {
                        drawer.classList.remove('open');
                        toggle.setAttribute('aria-expanded', 'false');
                    });
                });
            }
        })();
    </script>
    @stack('scripts')
</body>
</html>
