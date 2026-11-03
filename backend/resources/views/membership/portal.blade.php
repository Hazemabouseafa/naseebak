<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>نصيبك — بوابة الاشتراك الشهري للأعضاء</title>
    <style>
        :root {
            --bg-primary: #FFFFFF;
            --blue-primary: #145A9E;
            --blue-dark: #123D6A;
            --accent-yellow: #FFC43D;
            --bg-secondary: #F5F8FC;
            --text-primary: #1D2939;
            --text-muted: #667085;
            --border-color: #D0D5DD;
            --success: #16A34A;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Cairo', 'Tajawal', system-ui, -apple-system, sans-serif;
            background-color: var(--bg-secondary);
            color: var(--text-primary);
            line-height: 1.7;
            padding: 24px 16px;
        }
        .container {
            max-width: 680px;
            margin: 0 auto;
        }
        .card {
            background: var(--bg-primary);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(18, 61, 106, 0.05);
        }
        .header-banner {
            background: linear-gradient(135deg, var(--blue-dark), var(--blue-primary));
            color: #FFFFFF;
            border-radius: 18px;
            padding: 28px 24px;
            margin-bottom: 20px;
            text-align: center;
        }
        .badge {
            display: inline-block;
            background: var(--accent-yellow);
            color: var(--blue-dark);
            font-weight: 700;
            padding: 4px 14px;
            border-radius: 999px;
            font-size: 13px;
            margin-bottom: 12px;
        }
        .price-tag {
            font-size: 32px;
            font-weight: 800;
            margin: 8px 0;
        }
        .btn-primary {
            display: block;
            width: 100%;
            background: var(--blue-primary);
            color: #FFFFFF;
            font-weight: 700;
            font-size: 16px;
            padding: 14px 20px;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            text-align: center;
            text-decoration: none;
        }
        .btn-primary:hover {
            background: var(--blue-dark);
        }
        .notice {
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 14px 16px;
            font-size: 14px;
            color: var(--text-muted);
            margin-top: 16px;
        }
        ul.benefits {
            list-style: none;
            margin: 16px 0;
        }
        ul.benefits li {
            padding: 8px 0;
            border-bottom: 1px solid #EAECF0;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header-banner">
            <span class="badge">بوابة الأعضاء المستقلة — نصيبك</span>
            <h1>الاشتراك الشهري الشامل</h1>
            <div class="price-tag">
                {{ $setting?->web_monthly_price ?? $plan?->web_price_amount ?? '199.00' }}
                {{ $setting?->web_currency ?? 'EGP' }} / 30 يوماً
            </div>
            <p>بوابة الدفع المعتمدة حالياً: {{ ($setting?->active_web_payment_gateway ?? 'paymob') === 'paymob' ? 'Paymob' : 'Sha7nawy' }}</p>
        </div>

        <div class="card">
            <h2>مزايا العضوية الشهرية</h2>
            <ul class="benefits">
                <li>✓ إرسال طلبات تعارف غير محدودة للأعضاء المناسبين</li>
                <li>✓ المراسلة الخاصة المباشرة بعد قبول طلب التعارف</li>
                <li>✓ أولوية الظهور في نتائج البحث والاكتشاف</li>
                <li>✓ تفعيل فوري على حسابك في نصيبك بمجرد تأكيد الدفع من الخادم</li>
            </ul>

            <div class="notice">
                <strong>تعليمات التجديد عبر الويب:</strong>
                الاشتراك عبر بوابة الدفع الإلكترونية يغطي 30 يوماً كاملة ولا يقوم بسحب تلقائي متكرر من البطاقة؛ يمكنك تجديد اشتراكك يدوياً بأمان عند انتهاء الفترة أو قبلها مع إضافة الأيام الجديدة إلى رصيدك الحالي دون خسارة أي أيام متبقية.
            </div>
        </div>

        @if($user && $entitlement)
            <div class="card">
                <h2>حالة اشتراكك الحالية</h2>
                <p><strong>الحساب:</strong> {{ $user->email }}</p>
                <p><strong>حالة العضوية:</strong> {{ $entitlement['has_active_subscription'] ? 'نشط' : 'غير مشترك' }} ({{ $entitlement['subscription_status'] }})</p>
                @if(!empty($entitlement['current_period_end']))
                    <p><strong>صالح حتى:</strong> {{ $entitlement['current_period_end'] }}</p>
                @endif
                <div style="margin-top: 18px;">
                    <button id="checkout-btn" class="btn-primary" type="button">
                        {{ $entitlement['has_active_subscription'] ? 'تمديد الاشتراك لشهر تقويمي إضافي' : 'إتمام الدفع وتفعيل الاشتراك الآن' }}
                    </button>
                </div>
            </div>
        @else
            <div class="card">
                <h2>تسجيل الدخول بحساب Google المرتبط بتطبيق نصيبك</h2>
                <p style="color: var(--text-muted); margin: 10px 0 16px;">
                    يتم ربط الاشتراك بحسابك بأمان تام عبر المعرّف الفريد لحساب Google (`google_sub`).
                </p>
                <div id="google-signin-Section">
                    <p style="font-size: 13px; color: var(--text-muted);">
                        معرّف عميل Google Web OAuth: <code>{{ $googleWebClientId ?: 'GOOGLE_WEB_CLIENT_ID' }}</code>
                    </p>
                </div>
            </div>
        @endif
    </div>
</body>
</html>
