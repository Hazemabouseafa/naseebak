# نَصِيبُكَ — دليل وقائمة تحقق الخدمات السحابية والخارجية
# PHASE 13A: EXTERNAL SERVICES, CREDENTIALS & INTEGRATION CHECKLIST

**المنصة:** نَصِيبُكَ — Naseebak  
**معرّف التطبيق (Package ID):** `com.naseebak.app`  
**الفرع البرمجي:** `phase-13a-vps-preflight-staging`  
**تاريخ التحديث:** نوفمبر 2026  

---

## 1. مصفوفة تصنيف الخدمات الخارجية (External Integration Matrix)

| الخدمة الخارجية | الوظيفة الأساسية | حالة الكود المحلي | المتطلب الخارجي المتبقي | التصنيف |
| :--- | :--- | :---: | :--- | :---: |
| **Google Sign-In** | المصادقة الموحدة عبر حساب Google | **100% VERIFIED** | إنشاء OAuth Client IDs وربط بصمات SHA | **REQUIRES CREDENTIALS** |
| **Google Play Billing** | الفوترة المعتمدة للاشتراك الشهري | **100% VERIFIED** | إنشاء باقة الاشتراك في Play Console | **REQUIRES CREDENTIALS** |
| **Google Cloud Pub/Sub (RTDN)** | إشعارات التجديد والإلغاء اللحظية | **100% VERIFIED** | منح الصلاحية لخدمة Google الرسمية | **REQUIRES CREDENTIALS** |
| **Firebase Cloud Messaging** | إشعارات الدفع المشفرة على أندرويد | **100% VERIFIED** | ملف `google-services.json` ومفتاح الخدمة | **REQUIRES CREDENTIALS** |
| **Paymob Web Payments** | بوابة اشتراكات الويب المستقلة | **100% VERIFIED** | مفاتيح Sandbox و HMAC Secret | **REQUIRES CREDENTIALS** |
| **إعدادات النطاقات و DNS** | التوجيه والشهادات الرقمية SSL | **100% VERIFIED** | توجيه السجلات A إلى IP الخادم | **REQUIRES ACTUAL ACCESS** |

---

## 2. تفاصيل متطلبات Google Sign-In

### أ. بيانات الحزمة والبصمات الرقمية المستخرجة رسمياً (Extracted Fingerprints)
* **اسم الحزمة (Package Name):** `com.naseebak.app`
* **بصمة شهادة التطوير (Debug Keystore SHA-1):**
  `67:6F:17:E7:9C:02:FC:8C:42:30:06:4E:B2:6E:0E:BE:CA:5D:5C:95`
* **بصمة شهادة التطوير (Debug Keystore SHA-256):**
  `6E:26:02:A4:0E:EA:00:28:B9:E5:76:12:24:72:EF:C2:5E:AC:9B:2D:13:15:6F:64:2A:59:E5:07:49:97:BF:A0`

### ب. الخطوات المطلوبة في Google Cloud Console
1. الانتقال إلى **Google Cloud Console** > **APIs & Services** > **Credentials**.
2. إنشاء **OAuth 2.0 Client ID** من نوع **Android**:
   - إدخال Package Name: `com.naseebak.app`
   - لصق بصمة SHA-1 أعلاه.
3. إنشاء **OAuth 2.0 Client ID** آخر من نوع **Web application** (لاستخدامه كـ Audience لتوثيق الرمز في الخادم الخلفي).
4. تزويد الخادم بالمعرف: `GOOGLE_WEB_CLIENT_ID` و `GOOGLE_ANDROID_CLIENT_ID`.

---

## 3. تفاصيل متطلبات Google Play Billing & RTDN

### أ. إعداد باقة الاشتراك الشهري (Subscription Product)
* **معرّف المنتج (Product ID):** `naseebak_monthly_membership`
* **الخطة الأساسية (Base Plan ID):** `p1m` (Month-to-month auto-renewing)
* **فترة السماح (Grace Period):** تفعيل فترة سماح 7 أيام (Grace Period).
* **تعليق الحساب (Account Hold):** تفعيل تعليق الحساب حتى 30 يوماً عند تعثر الدفع.

### ب. حسابات الاختبار المجانية (License Testing)
1. في Google Play Console > **Setup** > **License testing**.
2. إضافة عناوين Gmail الخاصة بالمطورين والمختبرين.
3. تتيح هذه الميزة اختبار دورة الاشتراك الكاملة مجاناً مع تقليص وقت التجديد من شهر إلى **5 دقائق** لاختبار كافة الحالات (تجديد، إلغاء، استعادة، تعليق).

### ج. إعداد إشعارات المطورين الفورية (Real-Time Developer Notifications - RTDN)
1. في Google Cloud Console > **Pub/Sub** > **Topics**: إنشاء موضوع باسم `play-rtdn`.
2. **منح صلاحية النشر لخدمة Google Play حصراً:**
   > [!IMPORTANT]
   > يجب منح دور `Pub/Sub Publisher` إلى الحساب الخدمي الرسمي التابع لـ Google حصراً:  
   > `google-play-developer-notifications@system.gserviceaccount.com`  
   > *(يُحظر منح هذه الصلاحية لحسابات غير معنية لضمان أمان الإشعارات)*.
3. إنشاء **Subscription** من نوع **Push**:
   - Endpoint URL: `https://staging-api.YOUR_DOMAIN/api/v1/webhooks/google-play/rtdn`
   - تفعيل خيار **Enable authentication** واختيار خدمة معتمدة لتوليد رمز OIDC Bearer Token.

---

## 4. تفاصيل متطلبات Firebase Cloud Messaging (FCM HTTP v1)

1. في **Firebase Console**، فتح المشروع وإضافة تطبيق Android بمعرف `com.naseebak.app` وبصمة SHA-1.
2. تحميل ملف `google-services.json` ووضعه داخل مجلد `mobile/android/app/`.
3. توليد مفتاح خدمة Firebase خاص:
   - الانتقال إلى **Project Settings** > **Service accounts**.
   - النقر على **Generate new private key**.
   - حفظ الملف باسم آمن على الخادم وتحديد مساره في `.env`:  
     `FCM_SERVICE_ACCOUNT_JSON_PATH=/path/to/firebase-adminsdk.json`
     `FCM_PROJECT_ID=your-firebase-project-id`

---

## 5. تفاصيل متطلبات بوابة Paymob (Web Checkout)

> [!NOTE]
> بوابات الدفع الإلكتروني عبر الويب مخصصة حصرياً لبوابة المشتركين عبر المتصفح (`/membership`)، ولا توجد أي روابط لها داخل تطبيق أندرويد للامتثال الصارم لسياسات Google Play.

المتغيرات المطلوبة في بيئة Staging (وضع Sandbox التجريبي):
* `PAYMOB_API_KEY`: مفتاح الواجهة البرمجية في بيئة الاختبار.
* `PAYMOB_PUBLIC_KEY`: المفتاح العام لـ Unified Checkout.
* `PAYMOB_SECRET_KEY`: المفتاح السري المخصص للطلبات.
* `PAYMOB_INTEGRATION_ID_CARD`: معرف الربط الخاص بالبطاقات التجريبية.
* `PAYMOB_HMAC_SECRET`: الرمز السري المستخدم لحساب والتحقق من توقيع HMAC-SHA512.
* رابط الـ Webhook: `https://staging-api.YOUR_DOMAIN/api/v1/webhooks/paymob`.

---

## 6. تفاصيل إعدادات النطاقات والشهادات الرقمية (Domains & SSL)

يجب توجيه سجلات DNS التالية لدى مزود النطاق إلى عنوان IP خادم VPS المشترك:

| النطاق الفرعي المطلوب | نوع السجل | القيمة المستهدفة | الغرض والخدمة |
| :--- | :---: | :---: | :--- |
| `staging-api.YOUR_DOMAIN` | `A` | `[VPS_IP_ADDRESS]` | واجهة REST API الخلفية، لوحة Filament، وصفحات الحذف والسياسات |
| `staging-ws.YOUR_DOMAIN` | `A` | `[VPS_IP_ADDRESS]` | اتصالات الويب الحية Laravel Reverb (WSS) |

*يقوم خادم Traefik المدمج في Coolify بتوليد شهادات SSL المجانية من Let's Encrypt تلقائياً بمجرد انتشار سجلات DNS.*
