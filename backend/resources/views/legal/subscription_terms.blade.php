@extends('layouts.website')

@section('title', 'شروط الاشتراك والتفعيل — نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container" style="max-width: 860px;">
            <div class="surface-card">
                <span class="pill-badge" style="margin-bottom: 14px;">الوثائق القانونية</span>
                <h1 class="section-title" style="text-align: right; margin-top: 0;">شروط الاشتراك والعضوية في نَصِيبُكَ</h1>
                <p style="font-size: 14px; color: var(--text-secondary); margin-bottom: 24px;">
                    آخر تحديث: {{ date('Y-m-d') }} — تنطبق هذه الشروط على جميع الاشتراكات المدفوعة عبر الموقع الإلكتروني الرسمي لمنصة نَصِيبُكَ.
                </p>

                <div style="display: flex; flex-direction: column; gap: 18px; font-size: 15px; line-height: 1.85; color: var(--text-primary);">
                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">1. طبيعة الاشتراك وقناة الدفع</h2>
                        <p style="color: var(--text-secondary);">
                            تتم عمليات شراء باقات الاشتراك عبر الموقع الإلكتروني الرسمي لنَصِيبُكَ حصراً من خلال بوابات الدفع الإلكتروني المعتمدة. وبعد التحقق الآمن من الدفع من الخادم، يُفعّل الاشتراك تلقائياً على حساب المستخدم الموحد ليعمل داخل تطبيق نَصِيبُكَ على الأندرويد عند تسجيل الدخول بنفس حساب Google.
                        </p>
                    </div>

                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">2. الباقات والمدد المعتمدة</h2>
                        <p style="color: var(--text-secondary);">
                            تتيح المنصة باقتين أساسيتين محددتين من الإدارة: الباقة الشهرية (شهر ميلادي واحد من تاريخ التفعيل أو نهاية الاشتراك الساري) والباقة الربع سنوية (ثلاثة أشهر ميلادية). تُعرض الأسعار الفعلية بالعملة المحددة قبل إتمام الدفع ولا تتضمن أي رسوم خفية من المنصة.
                        </p>
                    </div>

                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">3. تفعيل العضوية وتمديدها</h2>
                        <p style="color: var(--text-secondary);">
                            لا يُعتبر الدفع مكتملًا بمجرد العودة من صفحة البوابة، بل يعتمد التفعيل النهائي على التحقق التشفيري من إشعار الخادم (Webhook) المرسل من بوابة الدفع. وفي حال وجود اشتراك سارٍ، تُضاف مدة الباقة الجديدة بعد تاريخ الانتهاء الحالي دون إهدار المدة المتبقية.
                        </p>
                    </div>

                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">4. الالتزام بالسياسات والاستخدام الجاد</h2>
                        <p style="color: var(--text-secondary);">
                            يخضع استخدام مزايا العضوية لالتزام العضو بشروط الاستخدام وسياسة الخصوصية ومعايير السلامة. وتحتفظ إدارة نَصِيبُكَ بحق تعليق الحسابات المخالفة عند ثبوت إساءة الاستخدام وفقاً لإجراءات المراجعة المعتمدة.
                        </p>
                    </div>

                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">5. التواصل والاستفسار</h2>
                        <p style="color: var(--text-secondary);">
                            لأي استفسار حول حالة اشتراكك، يمكنك التواصل عبر البريد:
                            <a href="mailto:{{ $supportEmail }}" class="en-text" style="color: var(--primary-blue); font-weight: 700;">{{ $supportEmail }}</a>.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
