# نَصِيبُكَ — دليل وقائمة التحقق لنشر بيئة الاختبار المعزولة (Staging)
# NASEEBAK STAGING DEPLOYMENT CHECKLIST & ENVIRONMENT RUNBOOK

**الهدف:** إعداد ونشر بيئة تجريبية معزولة تماماً (Isolated Staging Environment) على خادم VPS المشترك بنظام Ubuntu دون المساس بالتطبيقات الأخرى للعملاء أو تعريض الموارد للخطر.  
**الخادم المستهدف:** Ubuntu VPS (4 GB RAM, 50 GB Storage) مشغل لنظام Coolify.  
**إجمالي ميزانية الذاكرة القصوى للمشروع في Staging:** 800 ميجابايت (سقف أقصى محكم).  

---

## 1. قواعد الأمان الإلزامية (Non-Negotiable Safety Rules)

> [!CAUTION]
> **قواعد حماية الخادم المشترك (Shared Production VPS Rules):**
> 1. **ممنوع بتاتاً تنفيذ أي أمر تفريغ عام لـ Docker:** لا تنفذ أبداً `docker system prune`, `docker volume prune`, أو `docker network prune`.
> 2. **ممنوع إعادة تثبيت Coolify أو إعادة ضبط إعداداته:** لا تقم بإعادة تشغيل خدمات كوليفاي الأساسية إلا بعد موافقة صريحة.
> 3. **ممنوع المساس بقواعد الجدار الناري (UFW Firewall):** منفذ PostgreSQL الداخلي 5432 يجب أن يبقى معزولاً داخل شبكة Docker الداخلية ولا يُفتح للعامة.
> 4. **عزل كامل لمجلدات البيانات (Volumes):** كافة مجلدات التخزين يجب أن تبدأ بالبادئة `naseebak_staging_`.

---

## 2. جدول الموارد والحدود القصوى للحاويات (Resource Limits)

| الحاوية | الدور | الحد الأقصى للذاكرة (Memory Limit) | الحد الأقصى للمعالج (CPU Limit) | سياسة إعادة التشغيل |
| :--- | :--- | :---: | :---: | :---: |
| `naseebak-staging-postgres` | قاعدة بيانات PostgreSQL 16.4 | **256 MB** | 0.50 CPU | `unless-stopped` |
| `naseebak-staging-api` | واجهة HTTP + Nginx + PHP 8.3 FPM | **256 MB** | 0.50 CPU | `unless-stopped` |
| `naseebak-staging-worker` | معالج طوابير المهام والإشعارات | **160 MB** | 0.25 CPU | `unless-stopped` |
| `naseebak-staging-reverb` | خادم اتصالات الويب الحية (WebSockets) | **128 MB** | 0.25 CPU | `unless-stopped` |
| **المجموع الكلي** | **بيئة Staging بالكامل** | **800 MB** | **1.50 CPU** | *(متبقي > 3.2 GB لتطبيقات العملاء الأخرى)* |

---

## 3. قائمة المتغيرات البيئية المطلوبة لبيئة Staging (`.env.staging`)

يجب إعداد المتغيرات السرية التالية داخل واجهة Coolify لمشروع Staging:

```ini
# Core Configuration
CONTAINER_ROLE=app
APP_NAME="نَصِيبُكَ (Staging)"
APP_ENV=staging
APP_DEBUG=false
APP_KEY=base64:GENERATE_UNIQUE_KEY_HERE
APP_URL=https://staging-api.naseebak.app
APP_TIMEZONE=UTC
APP_LOCALE=ar
LOG_CHANNEL=daily
LOG_LEVEL=info

# Database Isolation (Completely separate database & credentials)
DB_CONNECTION=pgsql
DB_HOST=naseebak-staging-postgres
DB_PORT=5432
DB_DATABASE=naseebak_staging
DB_USERNAME=naseebak_staging_user
STAGING_DB_PASSWORD=GENERATE_SECURE_PASSWORD_HERE

# Storage & Filesystem
FILESYSTEM_DISK=private
PRIVATE_STORAGE_ROOT=/var/www/html/storage/app/private

# Driver Settings
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=database
SESSION_SECURE_COOKIE=true
SESSION_HTTP_ONLY=true
SESSION_SAME_SITE=lax
TRUSTED_PROXIES="*"

# WebSockets (Laravel Reverb)
BROADCAST_CONNECTION=reverb
STAGING_REVERB_APP_ID=nsb_stg_reverb_app
STAGING_REVERB_APP_KEY=nsb_stg_reverb_key
STAGING_REVERB_APP_SECRET=GENERATE_REVERB_SECRET_HERE
STAGING_REVERB_PUBLIC_HOST=staging-ws.naseebak.app
REVERB_HOST=naseebak-staging-reverb
REVERB_PORT=8081
REVERB_SCHEME=http

# Google & Payment Gateways (Sandbox / Test Mode)
GOOGLE_PLAY_PACKAGE_NAME=com.naseebak.app
GOOGLE_PLAY_MONTHLY_SUBSCRIPTION_ID=naseebak_monthly_membership
GOOGLE_ANDROID_CLIENT_ID=STAGING_ANDROID_CLIENT_ID
GOOGLE_WEB_CLIENT_ID=STAGING_WEB_CLIENT_ID
PAYMOB_SANDBOX_MODE=true
```

---

## 4. خطوات النشر الآمن خطوة بخطوة (Step-by-Step Deployment Runbook)

### المرحلة 1: التحقق القبلي من صحة الخادم المشترك (Pre-Deployment Health Check)
1. الاتصال بالخادم عبر SSH وفحص استهلاك الذاكرة والمساحة التخزينية الحالية:
   ```bash
   free -h
   df -h
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   ```
   *التأكد من توفر ما لا يقل عن 1.2 جيجابايت ذاكرة حرة ومساحة تخزين تفوق 10 جيجابايت.*

### المرحلة 2: إنشاء التطبيق وشبكة العمل في Coolify
1. في لوحة تحكم Coolify، اختر **Projects** ثم أنشئ مشروعاً جديداً باسم **Naseebak-Staging**.
2. اختر **Docker Compose Application** واربط مستودع الأكواد المصدري بفرع النشر التجريبي.
3. وجّه مسار ملف Docker Compose إلى:  
   [`infrastructure/coolify/docker-compose.staging.yml`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/infrastructure/coolify/docker-compose.staging.yml)
4. أضف المتغيرات البيئية السرية (الموضحة في القسم 3 أعلاه).

### المرحلة 3: التشغيل الأولي وبناء الحاويات
1. انقر على **Deploy** لبناء وتشغيل الحاويات الأربع.
2. التأكد من أن حاوية قاعدة البيانات أصبحت في حالة `healthy`:
   ```bash
   docker inspect --format='{{json .State.Health.Status}}' naseebak-staging-postgres
   ```
   *(يجب أن يرجع `"healthy"`)*.

### المرحلة 4: تنفيذ الهجرات البرمجية والبذور الأولية (Migrations & Seeding)
1. تنفيذ ترحيل الجداول داخل حاوية `naseebak-staging-api` المعزولة:
   ```bash
   docker exec -it naseebak-staging-api php artisan migrate --force
   ```
2. توليد حساب المشرف الأكبر لبيئة Staging:
   ```bash
   docker exec -it naseebak-staging-api php artisan naseebak:provision-super-admin \
       --email="staging-admin@naseebak.app" \
       --name="مشرف الاختبار" \
       --password="CHANGE_SECURE_PASSWORD"
   ```
3. تشغيل بذور الإعدادات الأساسية والباقات:
   ```bash
   docker exec -it naseebak-staging-api php artisan db:seed --force
   ```

### المرحلة 5: التحقق البعدي الوظيفي (Post-Deployment Verification)
* [ ] **فحص نقطة الفحص الصحي العام:**
  `curl -fsS https://staging-api.naseebak.app/api/v1/health`  
  *(الاستجابة المتوقعة: `{"status":"ok",...}`)*
* [ ] **فحص تشغيل معالج الطوابير:**
  `docker exec -it naseebak-staging-worker pgrep -f "artisan queue:work"`
* [ ] **فحص خادم الويب سوكت (Reverb):**
  الاتصال بالمنفذ 443 عبر النطاق `staging-ws.naseebak.app` والتحقق من مصافحة WebSocket بنجاح.
* [ ] **فحص لوحة المشرفين:**
  تسجيل الدخول إلى `https://staging-api.naseebak.app/admin`.

---

## 5. خطة استعادة الحالة والتراجع في حال الطوارئ (Rollback Plan)

في حال حدوث أي ضغط غير متوقع على الذاكرة أو أي تعارض مع التطبيقات الأخرى:
1. إيقاف بيئة Staging فوراً دون حذف أي أحجام تخزين:
   ```bash
   docker compose -f infrastructure/coolify/docker-compose.staging.yml stop
   ```
2. استعادة حالة استهلاك الخادم للتحقق من سلامة التطبيقات الأخرى:
   ```bash
   docker stats --no-stream
   ```
3. لا تقم أبداً بحذف مجلدات البيانات `naseebak_staging_pgdata` قبل التأكد من أخذ نسخة احتياطية إن تطلب الأمر.
