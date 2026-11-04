<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>نَصِيبُكَ — حذف الحساب والبيانات الشخصية</title>
    <style>
        :root {
            --bg-page: #F8FAFC;
            --bg-card: #FFFFFF;
            --primary-navy: #123D6A;
            --primary-blue: #145A9E;
            --accent-gold: #C59A3F;
            --accent-gold-light: #FDF8E8;
            --text-dark: #0F172A;
            --text-muted: #475569;
            --border-color: #E2E8F0;
            --danger-red: #DC2626;
            --danger-bg: #FEF2F2;
            --danger-border: #FCA5A5;
            --success-green: #16A34A;
            --success-bg: #F0FDF4;
            --success-border: #86EFAC;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Cairo', 'Tajawal', system-ui, -apple-system, sans-serif;
            background-color: var(--bg-page);
            color: var(--text-dark);
            line-height: 1.75;
            padding: 32px 16px;
        }
        .container {
            max-width: 720px;
            margin: 0 auto;
        }
        .header-banner {
            background: linear-gradient(135deg, var(--primary-navy), var(--primary-blue));
            color: #FFFFFF;
            border-radius: 20px;
            padding: 32px 24px;
            text-align: center;
            margin-bottom: 24px;
            box-shadow: 0 4px 14px rgba(18, 61, 106, 0.12);
        }
        .app-title {
            font-size: 26px;
            font-weight: 800;
            letter-spacing: -0.5px;
            margin-bottom: 6px;
        }
        .page-subtitle {
            font-size: 14.5px;
            color: #E2E8F0;
        }
        .card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 18px;
            padding: 24px 28px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
        }
        .card-title {
            font-size: 17px;
            font-weight: 800;
            color: var(--primary-navy);
            margin-bottom: 14px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .alert-success {
            background: var(--success-bg);
            border: 1px solid var(--success-border);
            color: #14532D;
            padding: 16px 20px;
            border-radius: 14px;
            font-size: 14px;
            margin-bottom: 20px;
        }
        .alert-danger {
            background: var(--danger-bg);
            border: 1px solid var(--danger-border);
            color: #7F1D1D;
            padding: 16px 20px;
            border-radius: 14px;
            font-size: 14px;
            margin-bottom: 20px;
        }
        .warning-box {
            background: var(--accent-gold-light);
            border: 1px solid #E5C378;
            color: #785412;
            padding: 18px 20px;
            border-radius: 14px;
            margin-bottom: 20px;
            font-size: 13.5px;
        }
        .warning-box strong {
            display: block;
            font-size: 14.5px;
            margin-bottom: 6px;
            color: #5B3C00;
        }
        .warning-box a {
            color: var(--primary-blue);
            font-weight: 700;
            text-decoration: underline;
        }
        ul.bullet-list {
            padding-right: 20px;
            margin-bottom: 14px;
            color: var(--text-muted);
            font-size: 14px;
        }
        ul.bullet-list li {
            margin-bottom: 8px;
        }
        .form-group {
            margin-bottom: 18px;
        }
        label {
            display: block;
            font-size: 13.5px;
            font-weight: 700;
            color: var(--text-dark);
            margin-bottom: 6px;
        }
        input[type="text"],
        input[type="email"],
        textarea {
            width: 100%;
            padding: 12px 14px;
            border: 1px solid var(--border-color);
            border-radius: 10px;
            font-size: 14px;
            font-family: inherit;
            color: var(--text-dark);
            background: #FFFFFF;
        }
        input:focus, textarea:focus {
            outline: none;
            border-color: var(--primary-blue);
            box-shadow: 0 0 0 3px rgba(20, 90, 158, 0.15);
        }
        .checkbox-container {
            display: flex;
            align-items: flex-start;
            gap: 10px;
            margin-bottom: 18px;
            font-size: 13px;
            color: var(--text-dark);
        }
        .checkbox-container input[type="checkbox"] {
            margin-top: 4px;
            width: 18px;
            height: 18px;
            accent-color: var(--danger-red);
        }
        .btn-danger {
            display: inline-block;
            width: 100%;
            background: var(--danger-red);
            color: #FFFFFF;
            font-weight: 700;
            font-size: 15px;
            padding: 14px;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            transition: background 0.2s;
            text-align: center;
        }
        .btn-danger:hover {
            background: #B91C1C;
        }
        .inapp-steps {
            background: #F1F5F9;
            border-radius: 12px;
            padding: 16px 20px;
            margin-top: 12px;
            font-size: 13.5px;
            color: var(--text-muted);
        }
        .inapp-steps ol {
            padding-right: 20px;
            margin-top: 6px;
        }
        .inapp-steps li {
            margin-bottom: 4px;
        }
        .footer-note {
            text-align: center;
            font-size: 12.5px;
            color: var(--text-muted);
            margin-top: 24px;
        }
        .footer-note a {
            color: var(--primary-blue);
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header Banner -->
        <div class="header-banner">
            <h1 class="app-title">نَصِيبُكَ — Naseebak</h1>
            <p class="page-subtitle">سياسة حذف الحساب والبيانات الشخصية وفق متطلبات حماية الخصوصية وGoogle Play</p>
        </div>

        @if (session('success'))
            <div class="alert-success">
                {{ session('success') }}
            </div>
        @endif

        @if ($errors->any())
            <div class="alert-danger">
                <strong>يرجى تصحيح الأخطاء التالية:</strong>
                <ul style="padding-right: 20px; margin-top: 6px;">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <!-- Google Play Subscription Notice -->
        <div class="warning-box">
            <strong>⚠️ تنبيه هام جدًا بشأن اشتراكات متجر Google Play:</strong>
            حذف حسابك داخل تطبيق نَصِيبُكَ أو عبر هذا النموذج <strong>لا يلغي</strong> اشتراك Google Play الدوري المسجل على حسابك في Google. متجر Google Play هو الجهة المسؤولة عن الفوترة والتجديد الدوري.
            <br>
            لإلغاء التجديد التلقائي ومنع أي استقطاع قادم، يرجى زيارة قسم الاشتراكات في متجر Google Play مباشرة:
            <br>
            <a href="{{ $googlePlaySubscriptionsUrl }}" target="_blank" rel="noopener noreferrer">
                إدارة وإلغاء اشتراكات Google Play &larr;
            </a>
        </div>

        <!-- Section 1: Data Deletion Policy -->
        <div class="card">
            <h2 class="card-title">1. البيانات التي يتم مسحها نهائيًا عند الحذف</h2>
            <p style="font-size: 14px; color: var(--text-muted); margin-bottom: 12px;">
                عند تنفيذ طلب حذف الحساب، يقوم خادم نَصِيبُكَ بمسح وإزالة البيانات التالية بصورة فورية وغير قابلة للاسترجاع:
            </p>
            <ul class="bullet-list">
                <li><strong>الصور الشخصية:</strong> يتم مسح كافة ملفات الصور المرفوعة من وحدة التخزين المشفرة وحذف سجلاتها.</li>
                <li><strong>الملف الشخصي:</strong> إلغاء الاسم، النبذة الشخصية، التفضيلات، ومحو أي بيانات تعريفية.</li>
                <li><strong>المحادثات الخاصة:</strong> إغلاق المحادثات وفصل الربط مع العضو الآخر وإلغاء صلاحية الوصول إليها.</li>
                <li><strong>طلبات التعارف والمفضلة:</strong> إلغاء وحذف كافة طلبات التعارف المعلقة وقوائم المفضلة المتبادلة.</li>
                <li><strong>رموز الأجهزة والجلسات:</strong> إلغاء كافة رموز المصادقة (Sanctum Tokens) ورموز الإشعارات (FCM Device Tokens).</li>
            </ul>

            <h2 class="card-title" style="margin-top: 18px;">2. البيانات التي قد يتم الاحتفاظ بها</h2>
            <p style="font-size: 14px; color: var(--text-muted);">
                قد نحتفظ بسجلات المعاملات المالية السابقة (رقم المعاملة، التاريخ، القيمة) فقط للمدة التي تفرضها القوانين الضريبية والمصرفية واللوائح التنظيمية ذات الصلة، مع نزع الصفة الشخصية عنها تماماً وفصلها عن هويتك.
            </p>
        </div>

        <!-- Section 2: In-App Deletion -->
        <div class="card">
            <h2 class="card-title">3. الطريقة الأسرع: الحذف الفوري من داخل التطبيق</h2>
            <p style="font-size: 14px; color: var(--text-muted);">
                يمكنك حذف حسابك فوراً وبشكل ذاتي في أي وقت من خلال تطبيق نَصِيبُكَ لنظام أندرويد عبر الخطوات التالية:
            </p>
            <div class="inapp-steps">
                <ol>
                    <li>افتح تطبيق <strong>نَصِيبُكَ</strong>.</li>
                    <li>انتقل إلى تبويب <strong>الملف الشخصي</strong> ثم اختر <strong>الأمان والخصوصية</strong>.</li>
                    <li>اضغط على خيار <strong>حذف الحساب</strong> في أسفل الشاشة.</li>
                    <li>أكّد فهمك لإلغاء اشتراك Google Play، واكتب كلمة <strong>"حذف"</strong>، ثم اضغط على زر التأكيد النهائي.</li>
                </ol>
            </div>
        </div>

        <!-- Section 3: Web Deletion Request Form -->
        <div class="card">
            <h2 class="card-title">4. تقديم طلب حذف الحساب عبر الويب</h2>
            <p style="font-size: 14px; color: var(--text-muted); margin-bottom: 16px;">
                إذا لم يعد بإمكانك الوصول إلى التطبيق أو قمت بإلغاء تثبيته، يمكنك تقديم طلب حذف الحساب وكافة بياناتك الشخصية عبر هذا النموذج:
            </p>

            <form action="{{ route('legal.delete_account.submit') }}" method="POST">
                @csrf

                <div class="form-group">
                    <label for="email">البريد الإلكتروني المسجل في الحساب (Google Account):</label>
                    <input type="email" id="email" name="email" value="{{ old('email', $currentUser?->email) }}" required placeholder="example@gmail.com">
                </div>

                <div class="form-group">
                    <label for="confirmation">لتأكيد الحذف النهائي، اكتب كلمة "حذف":</label>
                    <input type="text" id="confirmation" name="confirmation" required placeholder="حذف">
                </div>

                <div class="form-group">
                    <label for="reason">سبب الحذف (اختياري):</label>
                    <textarea id="reason" name="reason" rows="3" placeholder="أخبرنا عن سبب رغبتك في حذف الحساب لمساعدتنا في تحسين الخدمة...">{{ old('reason') }}</textarea>
                </div>

                <div class="checkbox-container">
                    <input type="checkbox" id="acknowledge_play_store" name="acknowledge_play_store" value="1" {{ old('acknowledge_play_store') ? 'checked' : '' }} required>
                    <label for="acknowledge_play_store" style="font-weight: normal; margin-bottom: 0;">
                        أدرك تمامًا أن هذا الإجراء نهائي ولا رجعة فيه، وأنه يجب عليّ إلغاء أي اشتراك نشط عبر متجر <strong>Google Play</strong> بشكل مستقل لمنع تجديد الرسوم الدورية.
                    </label>
                </div>

                <button type="submit" class="btn-danger">
                    تأكيد وإرسال طلب الحذف النهائي للحساب والبيانات
                </button>
            </form>
        </div>

        <!-- Footer -->
        <div class="footer-note">
            إذا واجهتك أي صعوبة، يُرجى التواصل مع فريق الدعم الفني عبر:
            <a href="mailto:{{ $supportEmail }}">{{ $supportEmail }}</a>
            <br>
            جميع الحقوق محفوظة &copy; {{ date('Y') }} نَصِيبُكَ — Naseebak Platform
        </div>
    </div>
</body>
</html>
