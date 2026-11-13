@extends('layouts.website')

@section('title', 'حسابي في نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container" style="max-width: 980px;">
            @if(session('account_error'))
                <div class="alert alert-danger">{{ session('account_error') }}</div>
            @endif
            @if(session('status_notice'))
                <div class="alert alert-info">{{ session('status_notice') }}</div>
            @endif

            <div class="surface-card" style="margin-bottom: 24px;">
                <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-start; gap: 18px;">
                    <div>
                        <span class="pill-badge" style="margin-bottom: 10px;">حسابي في نَصِيبُكَ</span>
                        <h1 style="font-size: 24px; font-weight: 700; color: var(--deep-navy); margin-bottom: 6px;">
                            {{ $user->profile?->full_name ?: 'عضو نَصِيبُكَ' }}
                        </h1>
                        <p style="font-size: 14px; color: var(--text-secondary);">
                            البريد المرتبط بحساب Google: <strong class="en-text">{{ $user->email }}</strong>
                        </p>
                    </div>

                    <div style="display: flex; flex-wrap: wrap; gap: 10px;">
                        <a href="{{ route('website.plans') }}" class="btn btn-primary btn-sm">
                            {{ !empty($entitlement['has_active_subscription']) ? 'ترقية أو تمديد الاشتراك' : 'اختيار باقة اشتراك' }}
                        </a>
                        <form method="POST" action="{{ route('website.auth.logout') }}">
                            @csrf
                            <button type="submit" class="btn btn-outline btn-sm">تسجيل الخروج</button>
                        </form>
                    </div>
                </div>

                @if(!$user->profile_completed)
                    <div class="alert alert-info" style="margin-top: 18px; margin-bottom: 0;">
                        ملفك الشخصي ما زال قيد الاستكمال في تطبيق نَصِيبُكَ على الأندرويد. يمكنك الاشتراك الآن وتفعيل العضوية فوراً، ثم فتح التطبيق لإكمال ملفك الشخصي والبدء بالتعارف.
                    </div>
                @endif
            </div>

            <div class="surface-card" style="margin-bottom: 24px;">
                <h2 style="font-size: 18px; font-weight: 700; color: var(--deep-navy); margin-bottom: 16px;">
                    حالة الاشتراك الحالية
                </h2>

                @if(!empty($entitlement['has_active_subscription']))
                    @php
                        $sourceLabel = match ($entitlement['payment_channel'] ?? '') {
                            'paymob' => 'الموقع الإلكتروني (Paymob)',
                            'sha7nawy' => 'الموقع الإلكتروني (Sha7nawy)',
                            'google_play' => 'متجر Google Play',
                            'admin_manual' => 'تفعيل إداري مباشر',
                            default => $entitlement['payment_channel'] ?? 'الموقع الإلكتروني',
                        };
                    @endphp
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; background: var(--surface-blue); border: 1px solid #C7DBF4; border-radius: 16px; padding: 20px;">
                        <div>
                            <div style="font-size: 12.5px; color: var(--text-secondary); margin-bottom: 4px;">الحالة</div>
                            <span class="status-badge status-success">اشتراك فعّال</span>
                        </div>
                        <div>
                            <div style="font-size: 12.5px; color: var(--text-secondary); margin-bottom: 4px;">الباقة</div>
                            <strong style="color: var(--deep-navy);">{{ $activePlanName ?? 'عضوية نَصِيبُكَ' }}</strong>
                        </div>
                        <div>
                            <div style="font-size: 12.5px; color: var(--text-secondary); margin-bottom: 4px;">قناة التفعيل</div>
                            <strong style="color: var(--deep-navy);">{{ $sourceLabel }}</strong>
                        </div>
                        <div>
                            <div style="font-size: 12.5px; color: var(--text-secondary); margin-bottom: 4px;">صالح حتى</div>
                            <strong class="en-text" style="color: var(--deep-navy);">
                                {{ !empty($entitlement['current_period_end']) ? \Carbon\Carbon::parse($entitlement['current_period_end'])->format('Y-m-d H:i') : '-' }}
                            </strong>
                        </div>
                    </div>
                @else
                    <div style="display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 14px; background: var(--bg-page); border: 1px solid var(--border-light); border-radius: 16px; padding: 20px;">
                        <div>
                            <span class="status-badge status-muted" style="margin-bottom: 6px;">لا يوجد اشتراك مدفوع نشط حالياً</span>
                            <p style="font-size: 14px; color: var(--text-secondary);">
                                يمكنك تفعيل الباقة الشهرية أو الربع سنوية من هنا ليتم ربطها تلقائياً بحسابك في تطبيق الأندرويد.
                            </p>
                        </div>
                        <a href="{{ route('website.plans') }}" class="btn btn-gold">اشترك الآن</a>
                    </div>
                @endif
            </div>

            <div class="surface-card">
                <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 16px;">
                    <h2 style="font-size: 18px; font-weight: 700; color: var(--deep-navy);">سجل الطلبات والمدفوعات</h2>
                    <span style="font-size: 13px; color: var(--text-secondary);">آخر 25 عملية</span>
                </div>

                @if($transactions->isEmpty())
                    <p style="font-size: 14.5px; color: var(--text-secondary); padding: 12px 0;">
                        لا توجد عمليات دفع مسجلة على حسابك حتى الآن.
                    </p>
                @else
                    <div class="table-wrap">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th>رقم المرجع</th>
                                    <th>الباقة</th>
                                    <th>المبلغ</th>
                                    <th>البوابة</th>
                                    <th>الحالة</th>
                                    <th>التاريخ</th>
                                    <th>إجراء</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach($transactions as $tx)
                                    @php
                                        [$badgeClass, $statusLabel] = match ($tx->status) {
                                            'succeeded' => ['status-success', 'مدفوع ومؤكد'],
                                            'pending' => ['status-pending', 'قيد الانتظار'],
                                            'cancelled' => ['status-muted', 'ملغي'],
                                            'refunded' => ['status-danger', 'مسترد'],
                                            'disputed' => ['status-danger', 'متنازع عليه'],
                                            'expired' => ['status-muted', 'منتهي الصلاحية'],
                                            default => ['status-danger', 'فشل الدفع'],
                                        };
                                    @endphp
                                    <tr>
                                        <td class="en-text" style="font-weight: 600;">{{ $tx->internal_reference }}</td>
                                        <td>{{ $tx->plan?->name_ar ?? 'باقة نَصِيبُكَ' }}</td>
                                        <td class="en-text" style="font-weight: 700;">{{ $tx->amount_minor > 0 ? \App\Models\SubscriptionPlan::formatMinorUnitsToDecimal((int) $tx->amount_minor) : (string) $tx->amount }} {{ $tx->currency }}</td>
                                        <td class="en-text">{{ strtoupper($tx->gateway) }}</td>
                                        <td><span class="status-badge {{ $badgeClass }}">{{ $statusLabel }}</span></td>
                                        <td class="en-text">{{ $tx->created_at?->format('Y-m-d H:i') }}</td>
                                        <td>
                                            @if($tx->status === 'pending')
                                                <div style="display: flex; gap: 8px; align-items: center;">
                                                    <a href="{{ route('website.payment.return', ['reference' => $tx->internal_reference]) }}" style="color: var(--primary-blue); font-weight: 700; font-size: 13px;">الحالة</a>
                                                    <form method="POST" action="{{ route('website.orders.cancel', ['reference' => $tx->internal_reference]) }}">
                                                        @csrf
                                                        <button type="submit" style="background: none; border: none; color: var(--danger); font-weight: 700; font-size: 13px; cursor: pointer; font-family: inherit;">إلغاء</button>
                                                    </form>
                                                </div>
                                            @else
                                                <a href="{{ route('website.payment.return', ['reference' => $tx->internal_reference]) }}" style="color: var(--primary-blue); font-weight: 700; font-size: 13px;">عرض</a>
                                            @endif
                                        </td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                @endif
            </div>
        </div>
    </section>
@endsection
