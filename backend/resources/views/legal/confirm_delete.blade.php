<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>نَصِيبُكَ — تأكيد حذف الحساب نهائياً</title>
    <style>
        :root {
            --bg-page: #F8FAFC;
            --bg-card: #FFFFFF;
            --primary-navy: #123D6A;
            --primary-blue: #145A9E;
            --accent-gold: #C59A3F;
            --text-dark: #0F172A;
            --text-muted: #475569;
            --border-color: #E2E8F0;
            --danger-red: #DC2626;
            --danger-bg: #FEF2F2;
            --danger-border: #FCA5A5;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Cairo', 'Tajawal', system-ui, -apple-system, sans-serif;
            background-color: var(--bg-page);
            color: var(--text-dark);
            line-height: 1.75;
            padding: 40px 16px;
        }
        .container {
            max-width: 620px;
            margin: 0 auto;
        }
        .header-banner {
            background: linear-gradient(135deg, var(--primary-navy), var(--primary-blue));
            color: #FFFFFF;
            border-radius: 20px;
            padding: 28px 24px;
            text-align: center;
            margin-bottom: 24px;
            box-shadow: 0 4px 14px rgba(18, 61, 106, 0.12);
        }
        .app-title {
            font-size: 24px;
            font-weight: 800;
            margin-bottom: 6px;
        }
        .card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 18px;
            padding: 28px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
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
        .email-badge {
            display: inline-block;
            background: #EFF6FF;
            color: var(--primary-navy);
            padding: 6px 14px;
            border-radius: 20px;
            font-weight: 700;
            font-size: 14px;
            margin: 8px 0;
            border: 1px solid #BFDBFE;
            direction: ltr;
        }
        .btn-danger {
            background: var(--danger-red);
            color: #FFFFFF;
            border: none;
            border-radius: 12px;
            padding: 14px 20px;
            font-size: 15px;
            font-weight: 700;
            width: 100%;
            cursor: pointer;
            transition: opacity 0.2s;
            margin-top: 16px;
        }
        .btn-danger:hover {
            opacity: 0.9;
        }
        .btn-cancel {
            display: block;
            text-align: center;
            background: transparent;
            color: var(--text-muted);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 12px 20px;
            font-size: 14px;
            font-weight: 600;
            text-decoration: none;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header-banner">
            <h1 class="app-title">نَصِيبُكَ — تأكيد ملكية البريد وحذف الحساب</h1>
            <p style="font-size: 13.5px; color: #E2E8F0;">تم التحقق من صحة رابط الأمان الخاص بك</p>
        </div>

        <div class="card">
            <h2 style="font-size: 18px; color: var(--primary-navy); margin-bottom: 12px;">هل أنت متأكد من رغبتك في حذف هذا الحساب نهائياً؟</h2>
            <p style="font-size: 14px; color: var(--text-muted); margin-bottom: 12px;">
                أنت على وشك حذف الحساب المرتبط بالبريد الإلكتروني الموثق أدناه:
            </p>

            <div style="text-align: center; margin: 12px 0;">
                <span class="email-badge">{{ $maskedEmail }}</span>
            </div>

            <div class="alert-danger" style="margin-top: 16px;">
                <strong>⚠️ تنبيه:</strong> هذا الإجراء نهائي ولا يمكن التراجع عنه. سيتم محو الصور، وإلغاء الجلسات، وإغلاق المحادثات، ونزع الصفة الشخصية عن ملفك نهائياً. كما يُرجى تذكّر إلغاء أي اشتراك في متجر Google Play بشكل مستقل.
            </div>

            <form action="{{ $submitUrl }}" method="POST">
                @csrf
                <div style="margin-bottom: 16px;">
                    <label for="confirmation" style="display: block; font-size: 13.5px; font-weight: 700; margin-bottom: 8px;">
                        لتأكيد الحذف النهائي، اكتب كلمة "حذف" في الحقل أدناه:
                    </label>
                    <input type="text" id="confirmation" name="confirmation" required placeholder="حذف" style="width: 100%; padding: 12px; border: 1px solid var(--border-color); border-radius: 10px; font-size: 14px;">
                </div>

                <button type="submit" class="btn-danger">
                    تأكيد حذف الحساب نهائياً الآن
                </button>
                <a href="{{ route('legal.delete_account') }}" class="btn-cancel">
                    إلغاء والعودة
                </a>
            </form>
        </div>
    </div>
</body>
</html>
