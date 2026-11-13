# PHASE 18 REPORT — الموقع الرسمي والدفع الإلكتروني وإدارة الاشتراكات لمنصة نَصِيبُكَ

**التاريخ:** 2026-11-12  
**المشروع:** نَصِيبُكَ (Naseebak) — `Hazemabouseafa/naseebak` (`staging`)  
**الحالة:** مكتمل محلياً ومُختبَر بالكامل (`175` اختباراً ناجحاً، `937` تأكيداً) — **لم يتم النشر التلقائي أو الدفع إلى GitHub/VPS التزاماً بالتعليمات.**

---

## 1. ملخص تنفيذي وحفظ البنية الحالية

تم بناء الموقع الرسمي لمنصة **نَصِيبُكَ** وإتاحة شراء الاشتراكات عبر الموقع داخل **نفس مشروع Laravel 12** (`backend/`) المتصل بنفس قاعدة بيانات **PostgreSQL** ونفس جدول المستخدمين (`users`) ونفس لوحة التحكم **Filament 3** (`/admin`).

- **لم يُنشأ** أي مشروع Next.js/React منفصل أو قاعدة بيانات ثانية أو خادم إضافي يستهلك موارد الـ VPS.
- **تم التحقق من `Dockerfile`**: بيئة التشغيل مبنية على Nginx + PHP-FPM دون Node.js في صورة الإنتاج؛ لذلك بُنيت واجهة الموقع بـ **Laravel Blade + CSS مستقل** (`public/assets/css/naseebak-website.css`) مع استضافة خطوط **IBM Plex Sans Arabic** وشعارات وهوية نَصِيبُكَ محلياً داخل `public/assets/`.
- تطبيق الأندرويد (`mobile/`) يقرأ نفس اشتراكات المستخدم الموحّدة عبر `GET /api/v1/subscription` و`GET /api/v1/subscription/entitlement`.

---

## 2. الهوية البصرية والأصول المنقولة

- **الألوان المعتمدة:**
  - Primary Blue: `#184A8C`
  - Deep Navy: `#123D6A`
  - Premium Gold: `#E8B44D`
  - White / Background / Text: `#FFFFFF` / `#F5F8FC` / `#1D2939` / `#667085`
- **الخطوط والأصول المنسوخة إلى `backend/public/assets/`:**
  - `fonts/IBMPlexSansArabic-{Regular,Medium,SemiBold,Bold}.ttf` + دعم `Inter` للأرقام والمحتوى الإنجليزي.
  - `images/naseebak-logo.png`, `images/naseebak-app-icon.png`, `images/naseebak-emblem.png`, `images/naseebak-heart-mark.png`.
- **اتجاه العرض:** تصميم عربي أصيل (`lang="ar" dir="rtl"`) متجاوب بالكامل مع شاشات الهواتف والحواسيب مع قائمة جانبية للموبايل، ودون أي إحصائيات أو شهادات مستخدمين مختلقة أو روابط متجر وهمية.

---

## 3. الصفحات والمسارات المنفذة (`routes/web.php`)

| الصفحة / الوظيفة | المسار (`Route`) | اسم المسار | وحدة التحكم |
|---|---|---|---|
| الصفحة الرئيسية للموقع | `GET /` | `website.home` | `WebsiteController@landing` |
| صفحة باقات الاشتراك | `GET /plans` | `website.plans` | `WebsiteCheckoutController@plans` |
| صفحة الدعم والتواصل | `GET /support` | `website.support` | `WebsiteController@support` |
| شروط الاشتراك | `GET /legal/subscription-terms` | `legal.subscription_terms` | `WebsiteController@subscriptionTerms` |
| سياسة الاسترداد | `GET /legal/refund-policy` | `legal.refund_policy` | `WebsiteController@refundPolicy` |
| تسجيل الدخول (واجهة / OAuth) | `GET /login` | `website.login` | `GoogleWebAuthController@showLogin` |
| بدء Google OAuth 2.0 | `GET /auth/google/redirect` | `website.auth.google.redirect` | `GoogleWebAuthController@redirect` |
| استجابة Google OAuth 2.0 | `GET /auth/google/callback` | `website.auth.google.callback` | `GoogleWebAuthController@callback` |
| تسجيل الخروج | `POST /auth/logout` | `website.auth.logout` | `GoogleWebAuthController@logout` |
| لوحة حساب العميل | `GET /account` | `website.account` | `WebsiteCheckoutController@account` |
| تأكيد طلب الباقة | `GET /plans/{planCode}/checkout` | `website.checkout.confirm` | `WebsiteCheckoutController@confirmOrder` |
| إنشاء طلب دفع موثّق | `POST /checkout` | `website.checkout.store` | `WebsiteCheckoutController@createOrder` |
| صفحة نتيجة الدفع | `GET /payment/return/{reference}` | `website.payment.return` | `WebsiteCheckoutController@paymentReturn` |
| متابعة حالة الطلب (قراءة فقط) | `GET /orders/{reference}/status` | `website.orders.status` | `WebsiteCheckoutController@orderStatus` |
| إلغاء طلب قيد الانتظار | `POST /orders/{reference}/cancel` | `website.orders.cancel` | `WebsiteCheckoutController@cancelOrder` |
| تحديث تسعير باقة (سوبر أدمن) | `PUT /admin/operations/settings/plans/{planCode}` | `admin.operations.settings.plan_pricing` | `AdminOperationsController@updatePlanPricing` |

> **ملاحظة التوافق:** تم الحفاظ على مسارات `/legal/{privacy-policy,terms-of-service,child-safety,delete-account,confirm-delete-account}` وبوابة `/membership/*` القائمة مسبقاً دون كسر.

---

## 4. قاعدة البيانات والباقات والعمليات المالية الدقيقة

### 4.1 الهجرة التراكمية (`Migration`)
- الملف: `backend/database/migrations/2026_11_12_000008_enhance_plans_and_orders_for_website_phase18.php`
  - تعديل `subscription_plans.google_play_product_id` لتصبح قابلة لأن تكون `NULL` (حتى لا يُجبر الموقع على اختلاق SKU وهمي للباقة الربع سنوية على Google Play).
  - إضافة أعمدة: `duration_months`، `price_minor` (`unsignedBigInteger`)، `sort_order` إلى `subscription_plans` مع ترحيل القيم الحالية بدقة ودون حسابات عشرية (`float`).
  - إدراج/ضمان وجود الباقتين:
    1. **`monthly_membership` (`الباقة الشهرية`)**: مدة `1` شهر ميلادي (`250.00 EGP` = `25000` قرشاً).
    2. **`quarterly_membership` (`الباقة الربع سنوية`)**: مدة `3` أشهر ميلادية (`600.00 EGP` = `60000` قرشاً) بنسبة توفير محسوبة فعلياً `20%`.
  - إضافة `cancelled_at` و`expires_at` على `payment_transactions` لدعم حالات الإلغاء وانتهاء الصلاحية.

### 4.2 إلغاء الحسابات العشرية المالية (`Zero Float Money Math`)
- أُضيفت دوال حسابية صحيحة داخل `App\Models\SubscriptionPlan`:
  - `parseDecimalToMinorUnits()`
  - `formatMinorUnitsToDecimal()`
  - `effectivePriceMinor()`
  - `effectiveMonths()`
  - `computeSavingsPercentVsMonthly()`
- طُبّقت في `WebsiteCheckoutService`، `PaymobGatewayService`، `Sha7nawyGatewayService`، و`PaymentSetting` لضمان إرسال `amount_cents` / `amount_minor` كأعداد صحيحة دقيقة دون أخطاء تقريب.

### 4.3 إصلاح تفعيل وتمديد واسترداد الباقات متعددة الأشهر
- عُدّل `SubscriptionEntitlementService`:
  - في `activateOrExtendFromVerifiedWebTransaction()`: احتساب `$monthsToGrant = max(1, $plan->effectiveMonths())` عبر `addCalendarMonths($baseStart, $monthsToGrant)` لتمنح الباقة الربع سنوية **3 أشهر ميلادية** كاملة وتُكدّس التمديد بعد تاريخ الانتهاء الحالي إذا كان الاشتراك سارياً.
  - في `revokeOrRecalculateOnRefund()`: احتساب إجمالي الأشهر الممنوحة من المعاملات الناجحة المتبقية لكل معاملة بحسب باقتها (`effectiveMonths()`) بدلاً من افتراض شهر واحد لكل معاملة.

---

## 5. المصادقة الموحدة عبر Google على الويب

- **`GoogleUserResolverService`**: خدمة موحدة تستخدمها `GoogleWebAuthController` و`WebSubscriptionPortalController` لمطابقة العضو أو إنشائه بصرامة عبر **`google_sub`** المؤكد عبر `GoogleIdTokenVerifierService`.
- **ضمانات الأمان المنفذة:**
  - رفض البريد غير المؤكد (`email_verified !== true`) -> `403`.
  - رفض دمج الحسابات اعتماداً على البريد فقط عند اختلاف `google_sub` -> `409`.
  - منع دخول الحسابات الموقوفة أو المحذوفة (`suspended` / `deleted`) -> `403`.
  - توليد والتحقق من OAuth `state` بـ `hash_equals` وحمايتها ضد CSRF وOpen Redirect (قائمة بيضاء `monthly_membership` و`quarterly_membership` فقط للباقة المقصودة).
  - توجيه الضيوف غير المسجلين إلى `website.login` (`GET /login`) عبر `redirectGuestsTo` في `bootstrap/app.php`.

---

## 6. بوابات الدفع والتحقق والضوابط الإدارية في Filament

### 6.1 `PaymobGatewayService`
- يستخدم `SubscriptionPlan::parseDecimalToMinorUnits()` بدقة تامة.
- يمرّر `redirection_url` (`/payment/return/{reference}`) و`notification_url` (`/api/v1/webhooks/paymob`) لـ Paymob `/v1/intention/`.
- يعالج إشعار `pending` بشكل صحيح دون تحويله بالخطأ إلى `failed`، ولا يفعّل أي عضوية قبل التحقق من توقيع `HMAC-SHA512` على جميع الحقول الـ 20 ومطابقة المبلغ بالقرش والعملة والمرجع.

### 6.2 `Sha7nawyGatewayService` (قيد الانتظار — موثق بأمان)
- يظل مغلقاً تشغيلياً (**Fail-Closed**) برمز `SHA7NAWY_SPECIFICATION_PENDING`: لا تُرسل طلبات HTTP غير موثقة ولا تُقبل إشعارات Webhook غير موقعة، ولا تُفعّل أي عضوية وهمية. تم إظهار حالته ومتطلباته الناقصة بوضوح في لوحة الإدارة.

### 6.3 لوحة تحكم Filament 3 (`AdminPanelProvider`)
- **`ManageSubscriptionPricingPage` (`إدارة باقات الاشتراك`):** إدارة كلتا الباقتين (الاسم المعروض، السعر بالـ EGP، حالة التفعيل عبر الموقع، سبب التعديل) مع تسجيل تدقيقي إلزامي في `admin_audit_logs` ودون تعديل أي طلبات تاريخية سابقة.
- **`ManagePaymentGatewaysPage` (`إعدادات بوابات الدفع`):** يعرض حالة الجاهزية غير السرية (`gatewayDiagnostics()`) مع زر **"فحص جاهزية الربط الآن"** دون كشف أي مفاتيح سرية.
- **`ManageApplicationSettingsPage` (`إعدادات التطبيق`):** إضافة حقل اختياري لرابط المتجر الرسمي `google_play_store_url`.

---

## 7. مراجعة توافق تطبيق الأندرويد (`mobile/`) مع سياسة Google Play

- تم فحص كافة ملفات `mobile/lib/**/*.dart`: لا يحتوي تطبيق الأندرويد على أي روابط لـ Paymob أو Sha7nawy أو صفحات دفع أو شراء عبر الويب (`/plans`, `/checkout`, `/membership`).
- تطبيق الأندرويد يعمل بنموذج الاستهلاك الموحد لقراءة حالة العضوية (`GET /api/v1/subscription` و`/entitlement`): أي مستخدم يشتري باقته عبر الموقع بنفس حساب Google يجد عضويته فعّالة تلقائياً في التطبيق.
- *(ملاحظة للنشر على Google Play لاحقاً: عند اعتماد استراتيجية الدفع عبر الموقع حصراً أو الاستهلاك فقط، يجب التأكد قبل رفع النسخة على Google Play Console من إزالة أو تعطيل مسار Google Play Billing داخل Flutter إن لم يكن مطلوباً في إصدار المتجر، والالتزام الصارم بعدم وضع أي روابط شراء خارجية داخل التطبيق).*

---

## 8. نتائج الاختبارات الآلية والتحقق بعد آخر تعديل

| الاختبار / الفحص | النتيجة الفعلية | التفاصيل |
|---|---|---|
| اختبارات المرحلة 18 الجديدة (`Phase18WebsiteAndPaymentsTest`) | **20 passed (110 assertions)** | تغطي الصفحة الرئيسية، الباقات والتوفير، صفحات السياسات والدعم، إدارة الأسعار بالـ Minor Units، Google OAuth (`state`, `google_sub`, منع الدمج بالبريد، الموقوفين)، رفض التلاعب بالأسعار، Paymob Intention، Webhook الربع سنوي + التمديد التراكمي + تزامن API الموبايل، الإلغاء، الاسترداد، وFail-Closed لبوابة شحناوي |
| الاختبارات الخلفية الشاملة (`php artisan test` بالكامل) | **175 passed (937 assertions)** | نجاح جميع المجموعات الاختبارية الـ 12 (Phases 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 18) بعد التعديلات النهائية بنسبة 100% دون أي فشل أو تخطي |
| ترجمة القوالب وفحص المسارات | **نجحت بالكامل** | `php artisan view:cache && view:clear` و`php artisan route:list` بدون أخطاء |

---

## 9. الملفات المضافة والمعدلة

### ملفات جديدة
- `backend/public/assets/css/naseebak-website.css`
- `backend/public/assets/fonts/IBMPlexSansArabic-{Regular,Medium,SemiBold,Bold}.ttf`
- `backend/public/assets/images/naseebak-{logo,app-icon,emblem,heart-mark}.png`
- `backend/database/migrations/2026_11_12_000008_enhance_plans_and_orders_for_website_phase18.php`
- `backend/app/Services/Auth/GoogleUserResolverService.php`
- `backend/app/Services/Payment/WebsiteCheckoutService.php`
- `backend/app/Http/Controllers/Web/WebsiteController.php`
- `backend/app/Http/Controllers/Web/GoogleWebAuthController.php`
- `backend/app/Http/Controllers/Web/WebsiteCheckoutController.php`
- `backend/resources/views/layouts/website.blade.php`
- `backend/resources/views/website/{landing,plans,login,account,checkout_confirm,payment_result,support}.blade.php`
- `backend/resources/views/legal/{subscription_terms,refund_policy}.blade.php`
- `backend/tests/Feature/Phase18WebsiteAndPaymentsTest.php`
- `PHASE_18_NASEEBAK_WEBSITE_AND_PAYMENTS_REPORT.md`

### ملفات محدثة
- `backend/.env.staging.example`, `backend/config/naseebak.php`, `backend/bootstrap/app.php`, `backend/routes/web.php`
- `backend/database/seeders/DatabaseSeeder.php`
- `backend/app/Models/{SubscriptionPlan,PaymentSetting,PaymentTransaction}.php`
- `backend/app/Services/Subscription/SubscriptionEntitlementService.php`
- `backend/app/Services/Payment/{PaymobGatewayService,Sha7nawyGatewayService}.php`
- `backend/app/Http/Controllers/Web/WebSubscriptionPortalController.php`
- `backend/app/Http/Controllers/Admin/AdminOperationsController.php`
- `backend/app/Filament/Pages/{ManageSubscriptionPricingPage,ManagePaymentGatewaysPage,ManageApplicationSettingsPage}.php`
- `backend/resources/views/filament/pages/manage-payment-gateways.blade.php`

---

## 10. متطلبات ما قبل التشغيل الإنتاجي (`Pre-Deploy Checklist` — غير منشورة تلقائياً)

1. إضافة **`GOOGLE_WEB_CLIENT_SECRET`** و**`GOOGLE_WEB_REDIRECT_URI=https://<domain>/auth/google/callback`** في `.env` على الخادم وتسجيل رابط الـ Callback في Google Cloud Console.
2. استكمال متغيرات **Paymob** (`PAYMOB_API_KEY`, `PAYMOB_SECRET_KEY`, `PAYMOB_PUBLIC_KEY`, `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID_CARD`) وضبط Webhook Paymob على `https://<domain>/api/v1/webhooks/paymob`.
3. تشغيل `php artisan migrate --force` (وبحسب الحاجة `php artisan db:seed --force` أو تحديث الباقة الربع سنوية مباشرة من `/admin/manage-subscription-pricing-page`).
4. تزويد التوثيق الرسمي ومفاتيح **Sha7nawy** متى ما تقرر تفعيلها مستقبلاً.
5. عند نشر التطبيق على Google Play، إدخال رابط المتجر الرسمي من صفحة **إعدادات التطبيق** في لوحة الإدارة أو عبر `GOOGLE_PLAY_STORE_URL`.
6. *(تنبيه بيئة الفحص)*: لم تتوفر أداة متصفح رسومية لالتقاط صور شاشة آلية داخل هذا الجلسة، وقد تم التحقق الكامل من القوالب برمجياً وعبر اختبارات HTTP.
