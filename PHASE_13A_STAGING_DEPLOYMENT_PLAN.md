# نَصِيبُكَ — خطة النشر الشاملة لبيئة الاختبار المعزولة
# PHASE 13A: STAGING DEPLOYMENT PLAN & END-TO-END VERIFICATION RUNBOOK

**المنصة:** نَصِيبُكَ — Naseebak  
**الفرع البرمجي المخصص:** `phase-13a-vps-preflight-staging`  
**بيئة النشر المستهدفة:** Coolify Staging Application (معزولة بالكامل)  
**سقف الذاكرة الصارم (Hard Cap):** **800 MB** موزعة على 5 حاويات  

---

## 1. شروط البدء الإلزامية (Prerequisites to Proceed)

> [!IMPORTANT]
> **لا يُسمح بتنفيذ هذا المخطط على الخادم إلا بعد تحقق الشروط الثلاثة التالية:**
> 1. تأكيد مالك الخادم على نتائج فحص السعة المكتبي (`PHASE_13A_VPS_PREFLIGHT_REPORT.md`) بثبوت توفر **>= 1.5 GB ذاكرة حرة** ومساحة تخزين **>= 10 GB**.
> 2. توفير أسماء النطاقات الفرعية الموجهة لـ IP الخادم (`staging-api.YOUR_DOMAIN`, `staging-ws.YOUR_DOMAIN`).
> 3. موافقة صريحة من مالك المشروع على بدء النشر التجريبي في المرحلة 13B.

---

## 2. جدول الحاويات والموارد المعتمدة لبيئة Staging

```mermaid
graph TD
    subgraph Staging_Stack [حزمة بيئة Staging المحصورة — 800 MB Cap]
        PG[naseebak-staging-postgres<br/>PostgreSQL 16.4 Alpine<br/>Limit: 224 MB | shared_buffers=48MB]
        API[naseebak-staging-api<br/>PHP 8.3 FPM + Nginx :8080<br/>Limit: 256 MB | pm.max_children=3]
        WRK[naseebak-staging-worker<br/>Queue Worker<br/>Limit: 128 MB | worker_memory=96MB]
        RVB[naseebak-staging-reverb<br/>Laravel Reverb :8081<br/>Limit: 96 MB]
        SCH[naseebak-staging-scheduler<br/>Cron Loop (60s)<br/>Limit: 96 MB]
    end

    subgraph Coolify_Proxy [Coolify Traefik Proxy]
        Traefik[HTTPS / WSS Proxy :443]
    end

    Traefik -->|https://staging-api...| API
    Traefik -->|wss://staging-ws...| RVB
    API --> PG
    WRK --> PG
    SCH --> PG
    API -.->|private storage volume| VOL[(naseebak_staging_private_photos)]
    WRK -.->|private storage volume| VOL
    SCH -.->|private storage volume| VOL
    PG -.->|database volume| DVOL[(naseebak_staging_pgdata)]
```

---

## 3. خطوات النشر خطوة بخطوة (Step-by-Step Deployment Runbook)

### الخطوة 1: تجهيز التطبيق في Coolify
1. الدخول إلى لوحة Coolify والنقر على **Projects** > **New Project** وتسميته `Naseebak-Staging`.
2. اختيار **Docker Compose Application**.
3. تحديد مستودع Git والفرع المعتمد: `phase-13a-vps-preflight-staging` (أو بعد دمجه إلى `main`).
4. توجيه مسار الملف إلى:  
   `infrastructure/coolify/docker-compose.staging.yml`

### الخطوة 2: تكوين المتغيرات السرية البيئية (Staging Environment Secrets)
في قسم **Environment Variables** داخل كوليفاي، يتم تعبئة المتغيرات المستقلة:

```ini
STAGING_APP_KEY=base64:GENERATE_NEW_UNIQUE_KEY_HERE
STAGING_APP_URL=https://staging-api.YOUR_DOMAIN
STAGING_REVERB_PUBLIC_HOST=staging-ws.YOUR_DOMAIN
STAGING_DB_DATABASE=naseebak_staging
STAGING_DB_USERNAME=naseebak_staging_user
STAGING_DB_PASSWORD=GENERATE_NEW_SECURE_PASSWORD
STAGING_REVERB_APP_ID=nsb_stg_app
STAGING_REVERB_APP_KEY=nsb_stg_key
STAGING_REVERB_APP_SECRET=GENERATE_NEW_REVERB_SECRET
```

### الخطوة 3: البناء والتشغيل الأولي (Initial Build & Boot)
1. النقر على زر **Deploy** في Coolify لبناء صورة الحاويات وتشغيلها.
2. التحقق من أن حاوية قاعدة البيانات أصبحت سالمة وصحية:
   ```bash
   docker inspect --format='{{json .State.Health.Status}}' naseebak-staging-postgres
   ```
   *(النتيجة المطلوبة: `"healthy"`)*.

### الخطوة 4: ترحيل الجداول وتوليد حساب المشرف وبذور البيانات
يتم تنفيذ هذه الأوامر من داخل الحاوية المعزولة حصراً:
```bash
# 1. ترحيل جداول قاعدة البيانات (Migrations)
docker exec -it naseebak-staging-api php artisan migrate --force

# 2. توليد حساب المشرف الأكبر لبيئة Staging
docker exec -it naseebak-staging-api php artisan naseebak:provision-super-admin \
    --email="staging-admin@naseebak.app" \
    --name="مشرف الاختبار" \
    --password="SECURE_ADMIN_PASSWORD"

# 3. إدراج بذور الإعدادات والباقات المحدثة بصفحات السياسات الرسمية
docker exec -it naseebak-staging-api php artisan db:seed --force
```

### الخطوة 5: الفحص الصحي والتأكيدي الفوري (Health Verification)
1. فحص استجابة الواجهة البرمجية عبر HTTPS:
   ```bash
   curl -fsS https://staging-api.YOUR_DOMAIN/api/v1/health
   ```
   *(الاستجابة المطلوبة: `{"status":"ok",...}`)*
2. فحص استقرار الذاكرة بعد التشغيل:
   ```bash
   docker stats --no-stream naseebak-staging-postgres naseebak-staging-api naseebak-staging-worker naseebak-staging-reverb naseebak-staging-scheduler
   ```
   *(التأكد من أن المجموع اللحظي لا يتجاوز ~350 - 450 MB)*.

---

## 4. خطة الاختبار الميداني الشاملة عبر 18 مساراً وظيفياً (The 18-Step Staging Test Matrix)

| # | مسار الاختبار (Workflow) | طريقة التحقق في Staging | المتطلبات الإضافية | التصنيف |
| :---: | :--- | :--- | :--- | :---: |
| **1** | **تسجيل الدخول بـ Google** | تسجيل الدخول في تطبيق فلاتر واستلام Sanctum Token | ربط Google Android Client ID و SHA-1 | **REQUIRES CREDENTIALS** |
| **2** | **إنشاء الملف الشخصي (18+)** | استكمال الخطوات الـ 4 والتحقق من حساب السن والبرج | تطبيق محمول أو Postman | **READY / VERIFIED LOCALLY** |
| **3** | **رفع صورة شخصية خاصة** | رفع صورة وفحص حذف بيانات EXIF والتخزين المشفر | تطبيق محمول | **READY / VERIFIED LOCALLY** |
| **4** | **استكشاف وتصفح الأعضاء** | فتح الشاشة الرئيسية والتحقق من الترقيم والفلترة | تطبيق محمول | **READY / VERIFIED LOCALLY** |
| **5** | **البحث المتقدم** | تطبيق فلاتر العمر، الجنسية، الحالة الاجتماعية | تطبيق محمول | **READY / VERIFIED LOCALLY** |
| **6** | **إضافة وإزالة المفضلة** | الضغط على زر الإعجاب والتحقق من شاشة المفضلة | تطبيق محمول | **READY / VERIFIED LOCALLY** |
| **7** | **إرسال طلب تعارف** | إرسال طلب لعضو آخر والتحقق من خصم الصلاحية | يتطلب حسابين تجريبيين | **READY / VERIFIED LOCALLY** |
| **8** | **قبول طلب التعارف** | قبول الطلب من الطرف الآخر وفتح شاشة المحادثة | يتطلب حسابين تجريبيين | **READY / VERIFIED LOCALLY** |
| **9** | **المراسلة الفورية المباشرة** | إرسال رسائل نصية لحظية عبر Reverb WebSockets | متصفح أو تطبيقان متصلان | **READY / VERIFIED LOCALLY** |
| **10** | **إشعارات الدفع (FCM)** | قفل التطبيق وإرسال رسالة للتأكد من وصول الإشعار | ملف `google-services.json` صالح | **REQUIRES CREDENTIALS** |
| **11** | **شراء اشتراك Google Play** | شراء العضوية الشهرية بحساب License Tester | إعداد السلعة في Play Console | **REQUIRES LIVE TESTING** |
| **12** | **انتهاء صلاحية الاشتراك** | تقديم وقت انتهاء الاشتراك وملاحظة حظر الإرسال | تعديل السجل أو انتظار دورة 5 دقائق | **READY / VERIFIED LOCALLY** |
| **13** | **حظر عضو** | حظر الطرف الآخر والتحقق من حجب الشات والطلبات | تطبيق محمول | **READY / VERIFIED LOCALLY** |
| **14** | **إلغاء حظر عضو** | استرجاع قائمة المحظورين وإلغاء الحظر وتأكيد الرسائل | تطبيق محمول | **READY / VERIFIED LOCALLY** |
| **15** | **الإبلاغ عن عضو** | تقديم بلاغ مع تحديد السبب وفحصه في لوحة الإدارة | لوحة تحكم Filament | **READY / VERIFIED LOCALLY** |
| **16** | **حذف الحساب داخل التطبيق** | كتابة "حذف" وتأكيد المسح الفوري للبيانات | تطبيق محمول | **READY / VERIFIED LOCALLY** |
| **17** | **إلغاء رموز الوصول والجلسات** | التأكد من رفض الرمز القديم برمز 401/403 | اختبار فوري بعد الحذف | **READY / VERIFIED LOCALLY** |
| **18** | **التحقق من تنظيف الصور** | التأكد من مسح مجلد الصور من `naseebak_staging_private_photos` | فحص القرص الفيزيائي | **READY / VERIFIED LOCALLY** |

---

## 5. خطة الطوارئ والتراجع الفوري (Emergency Rollback Protocol)

إذا لوحظ أي ارتفاع مفاجئ في استهلاك الموارد أو تأثر مواقع العملاء الأخرى:
1. **أمر الإيقاف الفوري الآمن (Non-Destructive Stop):**
   ```bash
   docker stop naseebak-staging-scheduler naseebak-staging-worker naseebak-staging-reverb naseebak-staging-api naseebak-staging-postgres
   ```
2. **التحقق من تعافي موارد الخادم:**
   ```bash
   free -h
   docker ps
   ```
3. **عدم المساس بالبيانات:** تبقى وحدات التخزين `naseebak_staging_pgdata` محفوظة دون حذف حتى معالجة السبب واستئناف العمل.
