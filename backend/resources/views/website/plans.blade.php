@extends('layouts.website')

@section('title', 'باقات الاشتراك — نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container">
            <div class="section-header">
                <span class="pill-badge">عضوية نَصِيبُكَ عبر الموقع</span>
                <h1 class="section-title">اختر الباقة المناسبة لرحلتك في نَصِيبُكَ</h1>
                <p class="section-subtitle">
                    الاشتراكات تُدفع بأمان عبر الموقع الإلكتروني المرتبط بنفس حساب Google الخاص بك، وتنكشف صلاحياتك المدفوعة تلقائياً في تطبيق الأندرويد.
                </p>
            </div>

            @if($webUser)
                <div class="alert alert-info" style="max-width: 920px; margin: 0 auto 28px; display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px;">
                    <div>
                        مسجّل الدخول بحساب: <strong class="en-text">{{ $webUser->email }}</strong>
                        @if(!empty($entitlement['has_active_subscription']) && !empty($entitlement['current_period_end']))
                            — <span class="status-badge status-success">اشتراكك فعّال حتى {{ \Carbon\Carbon::parse($entitlement['current_period_end'])->format('Y-m-d') }}</span>
                        @else
                            — <span class="status-badge status-muted">عضوية مجانية</span>
                        @endif
                    </div>
                    <a href="{{ route('website.account') }}" class="btn btn-outline btn-sm">إدارة حسابي والفواتير</a>
                </div>
            @endif

            @php
                $activeGw = $setting->active_web_payment_gateway ?? 'paymob';
                $gwDiag = $diagnostics[$activeGw] ?? ['configured' => false, 'status_label_ar' => 'غير متاح'];
            @endphp

            @if(!$gwDiag['configured'])
                <div class="alert alert-warning" style="max-width: 920px; margin: 0 auto 28px;">
                    <strong>ملاحظة بوابة الدفع ({{ strtoupper($activeGw) }}):</strong>
                    {{ $gwDiag['status_label_ar'] }}
                </div>
            @endif

            <div class="pricing-grid">
                @forelse($plans as $plan)
                    @php
                        $isQuarterly = $plan->code === 'quarterly_membership';
                        $months = $plan->effectiveMonths();
                        $features = is_array($plan->features_ar) ? $plan->features_ar : [];
                    @endphp

                    <article class="plan-card {{ $isQuarterly ? 'featured' : '' }}">
                        <div>
                            <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 12px;">
                                <div>
                                    <h2 class="plan-name">{{ $plan->name_ar }}</h2>
                                    <div class="plan-duration">
                                        {{ $months > 1 ? "مدة التفعيل: {$months} أشهر ميلادية" : 'مدة التفعيل: شهر ميلادي واحد' }}
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

                        @if($webUser)
                            <a href="{{ route('website.checkout.confirm', ['planCode' => $plan->code]) }}" class="btn {{ $isQuarterly ? 'btn-gold' : 'btn-primary' }} btn-block">
                                المتابعة لتأكيد {{ $plan->name_ar }}
                            </a>
                        @else
                            <a href="{{ route('website.auth.google.redirect', ['plan' => $plan->code]) }}" class="btn {{ $isQuarterly ? 'btn-gold' : 'btn-primary' }} btn-block">
                                المتابعة باستخدام Google لاختيار الباقة
                            </a>
                        @endif
                    </article>
                @empty
                    <div class="surface-card" style="grid-column: 1 / -1; text-align: center;">
                        لا توجد باقات اشتراك متاحة حالياً.
                    </div>
                @endforelse
            </div>

            <div class="surface-card" style="max-width: 920px; margin: 32px auto 0; display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 16px;">
                <div style="font-size: 14px; color: var(--text-secondary);">
                    عند وجود اشتراك فعّال مسبقاً على حسابك عبر الموقع، تُضاف مدة الباقة الجديدة بعد تاريخ الانتهاء الحالي دون ضياع أي يوم متبقٍ.
                </div>
                <div style="display: flex; gap: 12px; flex-wrap: wrap; font-size: 13.5px; font-weight: 700;">
                    <a href="{{ route('legal.subscription_terms') }}" style="color: var(--primary-blue);">شروط الاشتراك</a>
                    <a href="{{ route('legal.refund_policy') }}" style="color: var(--primary-blue);">سياسة الاسترداد</a>
                </div>
            </div>
        </div>
    </section>
@endsection
