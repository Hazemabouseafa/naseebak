@extends('layouts.website')

@section('title', 'نتيجة عملية الدفع — نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container" style="max-width: 640px;">
            <div class="surface-card" style="text-align: center; padding: 36px 26px;">
                @if(session('status_notice'))
                    <div class="alert alert-info" style="text-align: right;">{{ session('status_notice') }}</div>
                @endif

                @if($state === 'success')
                    <div style="width: 64px; height: 64px; margin: 0 auto 16px; border-radius: 50%; background: var(--success-bg); color: #067647; display: flex; align-items: center; justify-content: center; font-size: 30px; font-weight: 700;">✓</div>
                    <h1 style="font-size: 24px; font-weight: 700; color: var(--deep-navy); margin-bottom: 8px;">تم تأكيد الدفع وتفعيل اشتراكك</h1>
                    <p style="font-size: 14.5px; color: var(--text-secondary); margin-bottom: 22px;">
                        تم التحقق من المعاملة من بوابة الدفع وتفعيل عضويتك على نفس حساب Google الخاص بتطبيق نَصِيبُكَ.
                    </p>
                @elseif($state === 'pending')
                    <div style="width: 64px; height: 64px; margin: 0 auto 16px; border-radius: 50%; background: var(--warning-bg); color: var(--warning); display: flex; align-items: center; justify-content: center; font-size: 26px; font-weight: 700;">⏳</div>
                    <h1 style="font-size: 24px; font-weight: 700; color: var(--deep-navy); margin-bottom: 8px;">طلب الدفع قيد المعالجة والتحقق</h1>
                    <p style="font-size: 14.5px; color: var(--text-secondary); margin-bottom: 22px;">
                        نحن بانتظار إشعار التأكيد النهائي الموقّع من بوابة الدفع. لا يتم تفعيل العضوية إلا بعد وصول التحقق الرسمي للخادم.
                    </p>
                @elseif($state === 'cancelled')
                    <div style="width: 64px; height: 64px; margin: 0 auto 16px; border-radius: 50%; background: #F2F4F7; color: #475467; display: flex; align-items: center; justify-content: center; font-size: 26px; font-weight: 700;">—</div>
                    <h1 style="font-size: 24px; font-weight: 700; color: var(--deep-navy); margin-bottom: 8px;">تم إلغاء عملية الدفع</h1>
                    <p style="font-size: 14.5px; color: var(--text-secondary); margin-bottom: 22px;">
                        أُلغي طلب الدفع ولم يتم تفعيل أي اشتراك. يمكنك المحاولة مرة أخرى متى شئت.
                    </p>
                @else
                    <div style="width: 64px; height: 64px; margin: 0 auto 16px; border-radius: 50%; background: var(--danger-bg); color: var(--danger); display: flex; align-items: center; justify-content: center; font-size: 28px; font-weight: 700;">✕</div>
                    <h1 style="font-size: 24px; font-weight: 700; color: var(--deep-navy); margin-bottom: 8px;">تعذر إتمام عملية الدفع</h1>
                    <p style="font-size: 14.5px; color: var(--text-secondary); margin-bottom: 22px;">
                        لم تكتمل المعاملة لدى بوابة الدفع (أو تم استردادها / تعليقها)، ولم يتم خصم اشتراك فعّال.
                    </p>
                @endif

                <div style="background: var(--bg-page); border: 1px solid var(--border-light); border-radius: 16px; padding: 18px; text-align: right; display: flex; flex-direction: column; gap: 10px; margin-bottom: 24px; font-size: 14px;">
                    <div style="display: flex; justify-content: space-between; gap: 12px;">
                        <span style="color: var(--text-secondary);">رقم المرجع:</span>
                        <strong class="en-text" style="color: var(--deep-navy);">{{ $transaction->internal_reference }}</strong>
                    </div>
                    <div style="display: flex; justify-content: space-between; gap: 12px;">
                        <span style="color: var(--text-secondary);">الباقة:</span>
                        <strong style="color: var(--deep-navy);">{{ $transaction->plan?->name_ar ?? 'باقة نَصِيبُكَ' }}</strong>
                    </div>
                    <div style="display: flex; justify-content: space-between; gap: 12px;">
                        <span style="color: var(--text-secondary);">المبلغ:</span>
                        <strong class="en-text" style="color: var(--deep-navy);">{{ $transaction->amount_minor > 0 ? \App\Models\SubscriptionPlan::formatMinorUnitsToDecimal((int) $transaction->amount_minor) : (string) $transaction->amount }} {{ $transaction->currency }}</strong>
                    </div>
                    @if($isOwnerSession && !empty($entitlement['has_active_subscription']) && !empty($entitlement['current_period_end']))
                        <div style="display: flex; justify-content: space-between; gap: 12px;">
                            <span style="color: var(--text-secondary);">صلاحية الاشتراك حتى:</span>
                            <strong class="en-text" style="color: #067647;">{{ \Carbon\Carbon::parse($entitlement['current_period_end'])->format('Y-m-d H:i') }}</strong>
                        </div>
                    @endif
                </div>

                <div style="display: flex; flex-wrap: wrap; justify-content: center; gap: 12px;">
                    @if($isOwnerSession)
                        <a href="{{ route('website.account') }}" class="btn btn-primary">الانتقال إلى حسابي في نَصِيبُكَ</a>
                    @else
                        <a href="{{ route('website.auth.google.redirect') }}" class="btn btn-primary">تسجيل الدخول بحساب Google لعرض حسابك</a>
                    @endif

                    @if($state === 'pending' && $isOwnerSession)
                        <form method="POST" action="{{ route('website.orders.cancel', ['reference' => $transaction->internal_reference]) }}">
                            @csrf
                            <button type="submit" class="btn btn-outline">إلغاء الطلب</button>
                        </form>
                    @elseif($state !== 'success')
                        <a href="{{ route('website.plans') }}" class="btn btn-outline">العودة لاختيار الباقة</a>
                    @endif
                </div>
            </div>
        </div>
    </section>
@endsection

@if($state === 'pending' && $isOwnerSession)
    @push('scripts')
        <script>
            (function () {
                var attempts = 0;
                var maxAttempts = 12;
                var statusUrl = @json(route('website.orders.status', ['reference' => $transaction->internal_reference]));
                var timer = setInterval(function () {
                    attempts += 1;
                    if (attempts > maxAttempts) {
                        clearInterval(timer);
                        return;
                    }
                    fetch(statusUrl, { headers: { 'Accept': 'application/json' }, credentials: 'same-origin' })
                        .then(function (r) { return r.ok ? r.json() : null; })
                        .then(function (payload) {
                            if (payload && payload.data && payload.data.transaction_status !== 'pending') {
                                clearInterval(timer);
                                window.location.reload();
                            }
                        })
                        .catch(function () {});
                }, 4000);
            })();
        </script>
    @endpush
@endif
