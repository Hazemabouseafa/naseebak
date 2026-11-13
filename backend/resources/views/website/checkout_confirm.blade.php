@extends('layouts.website')

@section('title', 'تأكيد طلب الاشتراك — نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container" style="max-width: 680px;">
            <div class="surface-card" style="padding: 32px 26px;">
                <span class="pill-badge" style="margin-bottom: 12px;">مراجعة وتأكيد الطلب</span>
                <h1 style="font-size: 24px; font-weight: 700; color: var(--deep-navy); margin-bottom: 8px;">
                    تأكيد الاشتراك في {{ $plan->name_ar }}
                </h1>
                <p style="font-size: 14.5px; color: var(--text-secondary); margin-bottom: 22px;">
                    سيتم إنشاء طلب دفع رسمي محدد السعر من الخادم وربطه مباشرةً بحساب Google الخاص بك.
                </p>

                @if(session('checkout_error'))
                    <div class="alert alert-danger">{{ session('checkout_error') }}</div>
                @endif

                @if(!$gatewayReady)
                    <div class="alert alert-warning">
                        <strong>بوابة الدفع ({{ strtoupper($activeGateway) }}) غير جاهزة للتحصيل حالياً:</strong>
                        {{ $gatewayStatusLabel }}
                        @if(!empty($gatewayMissingItems))
                            <div style="font-size: 13px; margin-top: 6px; font-weight: 500;">
                                العناصر الناقصة: <span class="en-text">{{ implode('، ', $gatewayMissingItems) }}</span>
                            </div>
                        @endif
                    </div>
                @endif

                <div style="background: var(--bg-page); border: 1px solid var(--border-light); border-radius: 16px; padding: 20px; margin-bottom: 22px; display: flex; flex-direction: column; gap: 12px;">
                    <div style="display: flex; justify-content: space-between; align-items: center; font-size: 14.5px;">
                        <span style="color: var(--text-secondary);">حساب Google المرتبط:</span>
                        <strong class="en-text" style="color: var(--deep-navy);">{{ $user->email }}</strong>
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: center; font-size: 14.5px;">
                        <span style="color: var(--text-secondary);">الباقة المختارة:</span>
                        <strong style="color: var(--deep-navy);">{{ $plan->name_ar }}</strong>
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: center; font-size: 14.5px;">
                        <span style="color: var(--text-secondary);">المدة:</span>
                        <strong style="color: var(--deep-navy);">
                            {{ $plan->effectiveMonths() > 1 ? $plan->effectiveMonths() . ' أشهر ميلادية' : 'شهر ميلادي واحد' }}
                        </strong>
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: center; font-size: 14.5px;">
                        <span style="color: var(--text-secondary);">بوابة الدفع المعتمدة:</span>
                        <strong class="en-text" style="color: var(--deep-navy);">{{ strtoupper($activeGateway) }}</strong>
                    </div>
                    <div style="border-top: 1px solid var(--border-light); padding-top: 12px; display: flex; justify-content: space-between; align-items: baseline;">
                        <span style="font-weight: 700; color: var(--deep-navy);">المبلغ الإجمالي المعتمد:</span>
                        <strong style="font-size: 26px; color: var(--primary-blue);">
                            <span class="en-text">{{ $plan->formattedPrice() }}</span> {{ $plan->web_price_currency }}
                        </strong>
                    </div>
                </div>

                @if(!empty($entitlement['has_active_subscription']) && !empty($entitlement['current_period_end']))
                    <div class="alert alert-info">
                        لديك حالياً اشتراك فعّال حتى <strong class="en-text">{{ \Carbon\Carbon::parse($entitlement['current_period_end'])->format('Y-m-d') }}</strong>. ستُضاف مدة الباقة الجديدة بعد هذا التاريخ فور تأكيد الدفع.
                    </div>
                @endif

                <form method="POST" action="{{ route('website.checkout.store') }}">
                    @csrf
                    <input type="hidden" name="plan_code" value="{{ $plan->code }}">

                    <label style="display: flex; align-items: flex-start; gap: 10px; font-size: 13.5px; color: var(--text-secondary); margin-bottom: 20px; cursor: pointer;">
                        <input type="checkbox" required style="margin-top: 4px; width: 17px; height: 17px; accent-color: var(--primary-blue);">
                        <span>
                            أقر بمراجعة تفاصيل الباقة والموافقة على <a href="{{ route('legal.subscription_terms') }}" style="color: var(--primary-blue); font-weight: 700;">شروط الاشتراك</a> و<a href="{{ route('legal.refund_policy') }}" style="color: var(--primary-blue); font-weight: 700;">سياسة الاسترداد</a>، وأدرك أن تفعيل العضوية يتم بعد التحقق الرسمي من إشعار الدفع.
                        </span>
                    </label>

                    <div style="display: flex; flex-wrap: wrap; gap: 12px;">
                        <button type="submit" class="btn btn-primary btn-lg" style="flex: 1 1 240px;" {{ !$gatewayReady ? 'disabled' : '' }}>
                            الانتقال إلى صفحة الدفع الآمنة
                        </button>
                        <a href="{{ route('website.plans') }}" class="btn btn-outline btn-lg">العودة للباقات</a>
                    </div>
                </form>
            </div>
        </div>
    </section>
@endsection
