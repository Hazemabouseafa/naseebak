@extends('layouts.website')

@section('title', 'نَصِيبُكَ — كل حكاية جميلة ليها بداية')

@section('content')
    <section class="hero" id="about">
        <div class="container hero-grid">
            <div>
                <span class="pill-badge pill-badge-dark">
                    <span class="hero-trust-dot"></span>
                    منصة عربية للتعارف الجاد بهدف الزواج (+18)
                </span>

                <h1 class="hero-headline">
                    كل حكاية جميلة <span class="gold">ليها بداية</span>
                </h1>

                <p class="hero-copy">
                    نَصِيبُكَ مساحة للتعارف الجاد بهدف الزواج، تساعدك تكتشف أشخاص يشاركونك أهدافك وتبدأ رحلة تعارف بثقة وخصوصية.
                </p>

                <div class="hero-actions">
                    <a href="{{ route('website.plans') }}" class="btn btn-gold btn-lg">
                        استعراض باقات الاشتراك
                    </a>
                    @if($playStoreUrl)
                        <a href="{{ $playStoreUrl }}" target="_blank" rel="noopener noreferrer" class="btn btn-ghost-light btn-lg">
                            تحميل التطبيق للأندرويد
                        </a>
                    @else
                        <a href="#download" class="btn btn-ghost-light btn-lg">
                            تحميل التطبيق للأندرويد
                        </a>
                    @endif
                </div>

                <div class="hero-trust-row">
                    <span class="hero-trust-item">
                        <span class="hero-trust-dot"></span>
                        دخول آمن بحساب Google
                    </span>
                    <span class="hero-trust-item">
                        <span class="hero-trust-dot"></span>
                        مراجعة إدارية للملفات الشخصية
                    </span>
                    <span class="hero-trust-item">
                        <span class="hero-trust-dot"></span>
                        دفع إلكتروني موحد لحسابك في التطبيق
                    </span>
                </div>
            </div>

            <div class="hero-mockup-wrap" aria-label="معاينة واجهة تطبيق نَصِيبُكَ">
                <div class="phone-stage">
                    <div class="floating-badge top-badge">
                        <span class="floating-icon">
                            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
                            </svg>
                        </span>
                        <div>
                            <div style="color: var(--deep-navy);">خصوصية محمية</div>
                            <div style="font-size: 11px; color: var(--text-secondary); font-weight: 500;">تواصل بعد الموافقة المتبادلة</div>
                        </div>
                    </div>

                    <div class="phone-frame">
                        <div class="phone-screen">
                            <div class="phone-topbar">
                                <div class="phone-topbar-row">
                                    <div class="phone-mini-user">
                                        <img src="{{ asset('assets/images/naseebak-app-icon.png') }}" alt="نَصِيبُكَ" class="phone-mini-avatar">
                                        <div>
                                            <div style="font-size: 12px; font-weight: 700;">أهلاً بك في نَصِيبُكَ</div>
                                            <div style="font-size: 10px; opacity: 0.8;">الاستكشاف اليومي</div>
                                        </div>
                                    </div>
                                    <span style="font-size: 10px; background: rgba(232,180,77,0.25); color: #F7D488; padding: 3px 8px; border-radius: 999px; font-weight: 700;">عضوية فعّالة</span>
                                </div>
                                <div class="phone-search-pill">
                                    <span>بحث متقدم حسب البلد والاهتمامات</span>
                                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4">
                                        <circle cx="11" cy="11" r="8"></circle>
                                        <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                                    </svg>
                                </div>
                            </div>

                            <div class="phone-body">
                                <div class="mockup-card">
                                    <div class="mockup-member-head">
                                        <div class="mockup-avatar-circle">س</div>
                                        <div>
                                            <div class="mockup-member-name">عضو مؤهل للتعارف الجاد</div>
                                            <div class="mockup-member-meta">القاهرة • البحث عن شريك حياة</div>
                                        </div>
                                    </div>
                                    <div class="mockup-tags">
                                        <span class="mockup-tag">مؤهل جامعي</span>
                                        <span class="mockup-tag">توافق الاهتمامات</span>
                                        <span class="mockup-tag">ملف مراجَع</span>
                                    </div>
                                    <div class="mockup-cta">
                                        <span>إرسال طلب تعارف</span>
                                        <span>←</span>
                                    </div>
                                </div>

                                <div class="mockup-card" style="background: var(--surface-blue); border-color: #C7DBF4;">
                                    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px;">
                                        <span style="font-size: 12px; font-weight: 700; color: var(--deep-navy);">المحادثات الخاصة</span>
                                        <span style="font-size: 10.5px; color: var(--primary-blue); font-weight: 700;">بعد القبول فقط</span>
                                    </div>
                                    <div style="font-size: 11px; color: var(--text-secondary); line-height: 1.6;">
                                        تبدأ المحادثة فور موافقة الطرفين مع أدوات الإبلاغ والحظر لحماية احترامك.
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="floating-badge bottom-badge">
                        <span class="floating-icon">
                            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                                <rect x="2" y="5" width="20" height="14" rx="2"></rect>
                                <line x1="2" y1="10" x2="22" y2="10"></line>
                            </svg>
                        </span>
                        <div>
                            <div style="color: var(--deep-navy);">تفعيل فوري على التطبيق</div>
                            <div style="font-size: 11px; color: var(--text-secondary); font-weight: 500;">بنفس حساب Google</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class="section section-white" id="features">
        <div class="container">
            <div class="section-header">
                <span class="pill-badge">لماذا نَصِيبُكَ؟</span>
                <h2 class="section-title">تجربة عربية جادة تحترم وقتك وخصوصيتك</h2>
                <p class="section-subtitle">
                    صُمّمت كل ميزة داخل نَصِيبُكَ لتسهّل التعارف الهادف بعيداً عن الفوضى، مع أدوات تحكم واضحة لكل عضو.
                </p>
            </div>

            <div class="cards-grid-3">
                <article class="feature-card">
                    <div class="feature-icon">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                            <circle cx="9" cy="7" r="4"></circle>
                            <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                            <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
                        </svg>
                    </div>
                    <h3 class="feature-title">اكتشاف أشخاص مناسبين</h3>
                    <p class="feature-desc">
                        استعرض ملفات أعضاء يشاركونك نفس التوجه الجاد للارتباط بناءً على المعايير الأساسية التي تحددها في ملفك.
                    </p>
                </article>

                <article class="feature-card">
                    <div class="feature-icon">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="11" cy="11" r="8"></circle>
                            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                        </svg>
                    </div>
                    <h3 class="feature-title">البحث المتقدم</h3>
                    <p class="feature-desc">
                        تصفية دقيقة حسب الدولة والمدينة والفئة العمرية والمستوى التعليمي والحالة الاجتماعية للوصول لمن يناسبك بسهولة.
                    </p>
                </article>

                <article class="feature-card">
                    <div class="feature-icon">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                            <polyline points="22 4 12 14.01 9 11.01"></polyline>
                        </svg>
                    </div>
                    <h3 class="feature-title">طلبات التعارف</h3>
                    <p class="feature-desc">
                        إرسال واستقبال طلبات التعارف بوضوح تام، حيث لا يُفتح أي تواصل مباشر قبل موافقتك الصريحة على الطلب.
                    </p>
                </article>

                <article class="feature-card">
                    <div class="feature-icon">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
                        </svg>
                    </div>
                    <h3 class="feature-title">المحادثات الخاصة</h3>
                    <p class="feature-desc">
                        غرفة محادثة خاصة ومرتبة تبدأ بعد قبول طلب التعارف، وتُدار وفق صلاحيات اشتراكك الفعّال.
                    </p>
                </article>

                <article class="feature-card">
                    <div class="feature-icon">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
                            <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
                        </svg>
                    </div>
                    <h3 class="feature-title">حماية الخصوصية</h3>
                    <p class="feature-desc">
                        مراجعة إدارية للصور والملفات الشخصية، وإمكانية الحظر والإبلاغ وحذف الحساب بالكامل في أي وقت.
                    </p>
                </article>

                <article class="feature-card">
                    <div class="feature-icon">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="5" y="2" width="14" height="20" rx="2" ry="2"></rect>
                            <line x1="12" y1="18" x2="12.01" y2="18"></line>
                        </svg>
                    </div>
                    <h3 class="feature-title">تجربة عربية سهلة الاستخدام</h3>
                    <p class="feature-desc">
                        تصميم عربي أصيل متوافق مع جميع الشاشات، يجمع بين بساطة التصفح وسلاسة التنقل بين الاستكشاف والمحادثات.
                    </p>
                </article>
            </div>
        </div>
    </section>

    <section class="section" id="how-it-works">
        <div class="container">
            <div class="section-header">
                <span class="pill-badge">رحلة واضحة ومباشرة</span>
                <h2 class="section-title">كيف يعمل نَصِيبُكَ؟</h2>
                <p class="section-subtitle">
                    خمس خطوات بسيطة تبدأ بتسجيل دخول موثق وتستمر معك على التطبيق والموقع بنفس الحساب.
                </p>
            </div>

            <div class="steps-grid">
                <div class="step-card">
                    <div class="step-num">1</div>
                    <h3 class="step-title">إنشاء حساب باستخدام Google</h3>
                    <p class="step-desc">سجّل دخولك بسرعة وأمان بحساب Google لربط اشتراكك وبياناتك بهوية موحدة.</p>
                </div>

                <div class="step-card">
                    <div class="step-num">2</div>
                    <h3 class="step-title">استكمال الملف الشخصي</h3>
                    <p class="step-desc">أضف بياناتك واهتماماتك وتفضيلاتك ليظهر ملفك بشكل مناسب للأعضاء الجادين.</p>
                </div>

                <div class="step-card">
                    <div class="step-num">3</div>
                    <h3 class="step-title">اكتشاف الأعضاء</h3>
                    <p class="step-desc">تصفح الملفات المراجَعة واستخدم البحث المتقدم للوصول إلى الأشخاص الأنسب لك.</p>
                </div>

                <div class="step-card">
                    <div class="step-num">4</div>
                    <h3 class="step-title">إرسال طلبات التعارف</h3>
                    <p class="step-desc">أرسل طلب تعارف لمن ترى فيه توافقاً، وانتظر الموافقة المتبادلة لبدء الحوار.</p>
                </div>

                <div class="step-card">
                    <div class="step-num">5</div>
                    <h3 class="step-title">التواصل بعد الموافقة ووفق صلاحيات الاشتراك</h3>
                    <p class="step-desc">اشترك من الموقع ليُفعَّل حسابك تلقائياً داخل التطبيق وتستمتع بمزايا التواصل الكاملة.</p>
                </div>
            </div>
        </div>
    </section>

    <section class="section section-white" id="pricing">
        <div class="container">
            <div class="section-header">
                <span class="pill-badge">الاشتراكات</span>
                <h2 class="section-title">باقات واضحة بلا رسوم خفية</h2>
                <p class="section-subtitle">
                    اشترك عبر الموقع الرسمي بنفس حساب Google الذي تستخدمه في تطبيق الأندرويد، وسيتم تفعيل عضويتك تلقائياً فور تأكيد الدفع.
                </p>
            </div>

            <div class="pricing-grid">
                @forelse($plans as $plan)
                    @php
                        $isQuarterly = $plan->code === 'quarterly_membership';
                        $months = $plan->effectiveMonths();
                        $features = is_array($plan->features_ar) ? $plan->features_ar : [];
                    @endphp
                    <div class="plan-card {{ $isQuarterly ? 'featured' : '' }}">
                        <div>
                            <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 12px;">
                                <div>
                                    <h3 class="plan-name">{{ $plan->name_ar }}</h3>
                                    <div class="plan-duration">
                                        {{ $months > 1 ? "مدة الاشتراك: {$months} أشهر ميلادية" : 'مدة الاشتراك: شهر واحد' }}
                                    </div>
                                </div>
                                @if($isQuarterly && $savingsPercent)
                                    <span class="plan-savings-pill">وفر {{ $savingsPercent }}%</span>
                                @elseif($isQuarterly)
                                    <span class="plan-savings-pill">الباقة الأكثر توفيراً</span>
                                @endif
                            </div>

                            <div class="plan-price-row">
                                <span class="plan-price-val en-text">{{ $plan->formattedPrice() }}</span>
                                <span class="plan-price-curr">جنيه مصري ({{ $plan->web_price_currency }})</span>
                            </div>

                            @if($plan->description_ar)
                                <p style="font-size: 14px; color: var(--text-secondary); margin-bottom: 18px;">
                                    {{ $plan->description_ar }}
                                </p>
                            @endif

                            <ul class="plan-features">
                                @foreach($features as $feature)
                                    <li>
                                        <span class="check-dot">✓</span>
                                        <span>{{ $feature }}</span>
                                    </li>
                                @endforeach
                            </ul>
                        </div>

                        <a href="{{ route('website.plans') }}" class="btn {{ $isQuarterly ? 'btn-gold' : 'btn-primary' }} btn-block">
                            اختيار {{ $plan->name_ar }}
                        </a>
                    </div>
                @empty
                    <div class="surface-card" style="grid-column: 1 / -1; text-align: center;">
                        لا توجد باقات مفعلة حالياً. يرجى مراجعة الإدارة أو <a href="{{ route('website.support') }}" style="color: var(--primary-blue); font-weight: 700;">التواصل مع الدعم</a>.
                    </div>
                @endforelse
            </div>
        </div>
    </section>

    <section class="section" id="download">
        <div class="container">
            <div class="download-box">
                <div>
                    <h2>ابدأ تجربتك الآن على تطبيق نَصِيبُكَ</h2>
                    <p>
                        @if($playStoreUrl)
                            حمّل تطبيق نَصِيبُكَ للأندرويد وسجّل الدخول بنفس حساب Google لربط ملفك الشخصي واشتراكك تلقائياً.
                        @else
                            سيتم إتاحة رابط التحميل الرسمي على Google Play فور اعتماده من لوحة الإدارة. يمكنك من الآن مراجعة الباقات وإدارة حسابك عبر الموقع.
                        @endif
                    </p>
                </div>

                <div style="display: flex; flex-wrap: wrap; gap: 12px;">
                    @if($playStoreUrl)
                        <a href="{{ $playStoreUrl }}" target="_blank" rel="noopener noreferrer" class="btn btn-gold btn-lg">
                            تحميل من Google Play
                        </a>
                    @else
                        <span class="btn btn-ghost-light btn-lg" style="cursor: default;">
                            رابط Google Play قيد التجهيز
                        </span>
                    @endif
                    <a href="{{ route('website.plans') }}" class="btn btn-outline btn-lg">
                        عرض باقات الاشتراك
                    </a>
                </div>
            </div>
        </div>
    </section>
@endsection
