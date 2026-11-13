@extends('layouts.website')

@section('title', 'سياسة الاسترداد — نَصِيبُكَ')

@section('content')
    <section class="section">
        <div class="container" style="max-width: 860px;">
            <div class="surface-card">
                <span class="pill-badge" style="margin-bottom: 14px;">الوثائق القانونية</span>
                <h1 class="section-title" style="text-align: right; margin-top: 0;">سياسة الاسترداد وإلغاء المعاملات</h1>
                <p style="font-size: 14px; color: var(--text-secondary); margin-bottom: 24px;">
                    آخر تحديث: {{ date('Y-m-d') }} — توضح هذه السياسة الضوابط المعتمدة عند إلغاء أو استرداد أو النزاع على معاملات الدفع الإلكتروني عبر الموقع.
                </p>

                <div style="display: flex; flex-direction: column; gap: 18px; font-size: 15px; line-height: 1.85; color: var(--text-primary);">
                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">1. المعاملات الملغاة أو غير المكتملة</h2>
                        <p style="color: var(--text-secondary);">
                            إذا قام المستخدم بإلغاء الطلب قبل الدفع أو تعثّر إتمام الدفع لدى بوابة الدفع الإلكتروني، تظل المعاملة غير مفعّلة ولا يُمنح أي اشتراك مقابلها، ولا يُخصم أي مبلغ ما لم تصدر موافقة ناجحة من البوابة.
                        </p>
                    </div>

                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">2. طلبات الاسترداد</h2>
                        <p style="color: var(--text-secondary);">
                            في حال وجود خطأ تقني مزدوج في الخصم أو عدم تفعيل الاشتراك رغم خصم المبلغ، يرجى التواصل مع الدعم الفني خلال مدة معقولة مع تزويدنا بالبريد الإلكتروني لحساب Google والرقم المرجعي للمعاملة لمراجعتها عبر سجلات البوابة المعتمدة.
                        </p>
                    </div>

                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">3. أثر الاسترداد أو الاعتراض المالي على العضوية</h2>
                        <p style="color: var(--text-secondary);">
                            عند تسجيل استرداد مالي معتمد أو نزاع مالي (Dispute) من بوابة الدفع على أي معاملة، يقوم النظام تلقائياً بإلغاء الصلاحية الممنوحة عن تلك المعاملة وإعادة احتساب مدة الاشتراك الفعالة وفق المعاملات الصحيحة المتبقية فقط.
                        </p>
                    </div>

                    <div>
                        <h2 style="font-size: 18px; color: var(--deep-navy); margin-bottom: 6px;">4. قناة تقديم الطلب</h2>
                        <p style="color: var(--text-secondary);">
                            تُرسل طلبات المراجعة والاسترداد إلى:
                            <a href="mailto:{{ $supportEmail }}" class="en-text" style="color: var(--primary-blue); font-weight: 700;">{{ $supportEmail }}</a>.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
