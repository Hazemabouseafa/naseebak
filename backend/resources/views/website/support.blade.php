@extends('layouts.website')

@section('title', 'الدعم والتواصل — نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container" style="max-width: 920px;">
            <div class="section-header" style="margin-bottom: 32px;">
                <span class="pill-badge">مركز المساعدة</span>
                <h1 class="section-title">الدعم والتواصل مع فريق نَصِيبُكَ</h1>
                <p class="section-subtitle">
                    فريق الدعم جاهز لمساعدتك في أي استفسار يخص حسابك أو اشتراكك أو عمليات الدفع عبر الموقع الإلكتروني.
                </p>
            </div>

            <div class="cards-grid-3" style="grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); margin-bottom: 28px;">
                <div class="surface-card">
                    <div class="feature-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path>
                            <polyline points="22,6 12,13 2,6"></polyline>
                        </svg>
                    </div>
                    <h2 class="feature-title">البريد الإلكتروني للدعم</h2>
                    <p class="feature-desc" style="margin-bottom: 14px;">
                        للاستفسارات التقنية أو مراجعة حالة معاملة دفع، تواصل معنا مباشرة مع إرفاق رقم المرجع إن وجد.
                    </p>
                    <a href="mailto:{{ $supportEmail }}" class="btn btn-primary btn-sm en-text">{{ $supportEmail }}</a>
                </div>

                @if($supportWhatsapp !== '')
                    <div class="surface-card">
                        <div class="feature-icon">
                            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path>
                            </svg>
                        </div>
                        <h2 class="feature-title">الدعم المباشر</h2>
                        <p class="feature-desc" style="margin-bottom: 14px;">
                            قناة الدعم المعتمدة لاستقبال بلاغات الأعضاء ومساعدتهم في تفعيل الحساب.
                        </p>
                        <span class="pill-badge en-text">{{ $supportWhatsapp }}</span>
                    </div>
                @endif

                <div class="surface-card">
                    <div class="feature-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
                        </svg>
                    </div>
                    <h2 class="feature-title">روابط قانونية سريعة</h2>
                    <ul style="list-style: none; display: flex; flex-direction: column; gap: 8px; font-size: 14px;">
                        <li><a href="{{ route('legal.subscription_terms') }}" style="color: var(--primary-blue); font-weight: 600;">شروط الاشتراك والتفعيل</a></li>
                        <li><a href="{{ route('legal.refund_policy') }}" style="color: var(--primary-blue); font-weight: 600;">سياسة الاسترداد</a></li>
                        <li><a href="{{ route('legal.privacy_policy') }}" style="color: var(--primary-blue); font-weight: 600;">سياسة الخصوصية</a></li>
                        <li><a href="{{ route('legal.delete_account') }}" style="color: var(--primary-blue); font-weight: 600;">طلب حذف الحساب والبيانات</a></li>
                    </ul>
                </div>
            </div>

            <div class="surface-card">
                <h2 class="feature-title" style="margin-bottom: 16px;">أسئلة شائعة</h2>
                <div style="display: flex; flex-direction: column; gap: 16px; font-size: 14.5px; color: var(--text-secondary);">
                    <div>
                        <strong style="color: var(--deep-navy); display: block; margin-bottom: 4px;">كيف يرتبط اشتراكي من الموقع بحسابي في تطبيق الأندرويد؟</strong>
                        عند تسجيل الدخول في الموقع بنفس حساب Google الذي تستخدمه في تطبيق نَصِيبُكَ، يتم مطابقة هويتك الفريدة وتُمنح الصلاحية تلقائياً على قاعدة بيانات المنصة فور تأكيد الدفع من البوابة المعتمدة.
                    </div>
                    <div>
                        <strong style="color: var(--deep-navy); display: block; margin-bottom: 4px;">ماذا يحدث إذا لم تظهر حالة الاشتراك فوراً بعد الدفع؟</strong>
                        قد تستغرق بوابة الدفع ثوانٍ معدودة لإرسال إشعار التحقق النهائي (Webhook). يمكنك تحديث صفحة «حسابي في نَصِيبُكَ» أو الضغط على زر إعادة التحقق في تطبيق الأندرويد.
                    </div>
                    <div>
                        <strong style="color: var(--deep-navy); display: block; margin-bottom: 4px;">ماذا لو كان حسابي ما زال بحاجة إلى استكمال الملف الشخصي؟</strong>
                        يظل اشتراكك محفوظاً وفعّالاً على حسابك؛ كل ما عليك فعله هو فتح التطبيق وإكمال ملفك الشخصي لاستخدام كافة المزايا.
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
