# نَصِيبُكَ — قائمة الامتثال الشاملة لسياسات متجر Google Play
# GOOGLE PLAY POLICY & COMPLIANCE READINESS CHECKLIST

**التطبيق:** نَصِيبُكَ — Naseebak  
**النوع:** تطبيق تعارف شرعي وزواج إسلامي للأعضاء البالغين (Adult Matrimonial / Matchmaking)  
**الحزمة البرمجية (Package ID):** `com.naseebak.app`  
**تاريخ المراجعة والتدقيق:** نوفمبر 2026  
**الإصدار المستهدف:** Android 14+ (API Level 34)  

---

## 1. ملخص حالة الامتثال (Compliance Status Overview)

| متطلب السياسة | البند في Google Play | حالة التطبيق المصدري | المتطلب المتبقي على مالك حساب المطور |
| :--- | :--- | :---: | :--- |
| **الحد الأدنى للسن (18+)** | Families & Age Restrictions | **ممتثل 100% برمجياً** | تعيين الفئة العمرية 18+ في Play Console |
| **معايير سلامة الأطفال ومكافحة الاستغلال** | Child Sexual Abuse Material (CSAM/CSAE) | **ممتثل 100% برمجياً وموثق** | تقديم إقرار سلامة الأطفال ورابط السياسة |
| **حذف الحساب والبيانات** | Account Deletion Policy | **ممتثل 100% برمجياً وعبر الويب** | إضافة رابط الويب الرسمي في Play Console |
| **سياسة الخصوصية وأمان البيانات** | Privacy Policy & Data Safety | **ممتثل 100% ومكتمل** | ملء نموذج Data Safety Form في Console |
| **الفوترة والاشتراكات** | Payments & Google Play Billing | **ممتثل 100% (حصري عبر Play)** | إنشاء السلعة وإعداد RTDN Pub/Sub |
| **آليات الإبلاغ والحظر** | User-Generated Content (UGC) | **ممتثل 100% (إبلاغ وحظر فوري)** | — |

---

## 2. التدقيق التفصيلي حسب متطلبات Google Play

### أ. سياسة الفئة العمرية وحظر القُصّر (Age Restrictions & 18+ Exclusivity)
* [x] **التحقق التقني من تاريخ الميلاد:** يتحقق الخادم في [`CompleteProfileRequest`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Requests/Api/V1/CompleteProfileRequest.php) و[`UpdateProfileRequest`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Requests/Api/V1/UpdateProfileRequest.php) من أن عمر المستخدم لا يقل عن 18 عاماً باليوم والشهر والسنة (`before_or_equal:now()-18years`).
* [x] **حظر تسجيل القُصّر:** يتم رفض أي طلب لمن هم دون 18 عاماً فوراً برمز 422 مع رسالة واضحة: *"تطبيق نصيبك مخصص للبالغين من عمر 18 عاماً فأكثر فقط"*.
* [ ] **إجراء مالك الحساب في Play Console:** في قسم **Target audience and content**، اختر الفئة العمرية **18 and older** فقط، وأكّد أن التطبيق لا يستهدف الأطفال بشكل غير مقصود (*"Could your store listing appeal to children? No"*).

### ب. معايير سلامة الأطفال ومكافحة الاستغلال (Child Safety & Anti-CSAE Standards)
* [x] **سياسة عدم التسامح المطلق (Zero-Tolerance Policy):** تم نشر وثيقة رسمية عامة على مسار [`/legal/child-safety`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/resources/views/legal/child_safety.blade.php).
* [x] **بريد إلكتروني مخصص لسلامة الأطفال:** تم توثيق ونشر عنوان الاتصال الرسمي `child-safety@naseebak.app`.
* [x] **بروتوكول الإبلاغ الدولي:** تتضمن الوثيقة التزاماً صريحاً بالإبلاغ الفوري إلى السلطات الأمنية والمركز الوطني للأطفال المفقودين والمستغلين (NCMEC).
* [x] **التدقيق الإداري الصارم للصور:** تخضع جميع الصور للمراجعة الإدارية البشرية مع منع وجود أي قُصّر ونزع بيانات EXIF الجغرافية.
* [ ] **إجراء مالك الحساب في Play Console:** في قسم **App content > Child Safety Standards**، ضع الرابط: `https://YOUR_DOMAIN/legal/child-safety`.

### ج. حذف الحساب والبيانات (Account Deletion Requirement)
* [x] **الحذف الفوري من داخل التطبيق:** متوفر عبر شاشة [`DeleteAccountScreen`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/mobile/lib/features/profile/presentation/screens/delete_account_screen.dart) ويتطلب كتابة كلمة "حذف" وإقرار اشتراك جوجل بلاي، مع استدعاء `DELETE /api/v1/auth/account`.
* [x] **صفحة ويب خارجية عامة ومستقلة:** متوفرة عبر [`/legal/delete-account`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/resources/views/legal/delete_account.blade.php) تتيح للمستخدمين الذين ألغوا تثبيت التطبيق طلب حذف حساباتهم.
* [x] **التحقق الأمني من ملكية البريد:** تم تأمين صفحة الويب بروابط تأكيد موقعة ومؤقتة تشفيرياً (`URL::temporarySignedRoute`) لضمان عدم إمكانية قيام أي شخص بحذف حساب آخر.
* [x] **مسح البيانات الفيزيائية والشخصية:** مسح فوري لملفات الصور من وحدة التخزين، إلغاء رموز المصادقة والإشعارات، إلغاء طلبات التعارف، إغلاق المحادثات، ونزع الصفة الشخصية.
* [x] **تحذير اشتراك متجر Google Play:** إشعار بارز وتنبيه صريح مع رابط مباشر لصفحة إدارة الاشتراكات: `https://play.google.com/store/account/subscriptions`.
* [ ] **إجراء مالك الحساب في Play Console:** في قسم **App content > Account deletion**، ضع رابط الحذف الخارجي: `https://YOUR_DOMAIN/legal/delete-account`.

### د. سياسة الخصوصية وإعلان أمان البيانات (Privacy Policy & Data Safety Form)
* [x] **سياسة خصوصية معتمدة ومتاحة للعامة:** منشورة عبر المسار [`/legal/privacy-policy`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/resources/views/legal/privacy_policy.blade.php).
* [x] **شروط الخدمة والاستخدام:** منشورة عبر المسار [`/legal/terms-of-service`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/resources/views/legal/terms_of_service.blade.php).
* [ ] **إجراء مالك الحساب في Play Console (نموذج أمان البيانات - Data Safety Section):**
  - **بيانات الموقع الجغرافي:** لا يتم جمع موقع GPS الدقيق (يتم فقط جمع اسم المنطقة/المدينة نصياً من اختيار المستخدم).
  - **البيانات الشخصية (Personal info):**
    - الاسم (`Name`) — لغرض وظائف التطبيق (`App functionality`).
    - البريد الإلكتروني (`Email address`) — للمصادقة وإدارة الحساب (`Account management`).
    - تاريخ الميلاد والنوع والحالة الاجتماعية (`Age/Gender/Marital info`) — لغرض التوافق والتعارف الشرعي (`App functionality`).
  - **الصور ومقاطع الفيديو (Photos & Videos):**
    - الصور الشخصية (`Photos`) — مرفوعة بموافقة المستخدم لملفه الشخصي، وتخزن مشفرة ويمكن حذفها في أي وقت.
  - **الرسائل (Messages):**
    - الرسائل النصية الخاصة (`In-app messages`) — مشفرة أثناء النقل ومقتصرة على طرفي المحادثة بعد القبول المتبادل.
  - **المعلومات المالية (Financial info):**
    - سجل الشراء (`Purchase history`) — عبر Google Play Billing حصرياً على التطبيق المحمول.
  - **المعرّفات (Device or other IDs):**
    - معرّف FCM Device Token — لتسليم الإشعارات (`Push Notifications`).
  - **تشفير البيانات:** كافة البيانات مشفرة أثناء النقل (`HTTPS / TLS 1.3`).
  - **آلية طلب الحذف:** نعم، يوفر التطبيق وسيلة للمستخدم لطلب حذف كافة بياناته.

### هـ. سياسة الفوترة والاشتراكات (Payments & Billing Anti-Steering)
* [x] **استخدام حصري لـ Google Play Billing:** التطبيق المخصص لأندرويد يستخدم مكتبة `in_app_purchase` لتوثيق وتجديد العضوية الشهرية عبر متجر Google Play حصرياً.
* [x] **خلو التطبيق من أي روابط فوترة بديلة أو تحايل:** تم فحص الكود المصدري للتطبيق المحمول والتأكد من عدم وجود أي زر أو رابط يوجه المستخدمين إلى بوابات دفع خارجية مثل Paymob أو Sha7nawy داخل تطبيق أندرويد (بوابات الويب مقتصرة تماماً على بوابة المشتركين عبر متصفح الويب `web portal`).
* [x] **التوثيق السحابي للخادم وتأكيد الشراء:** الخادم يقوم بالتحقق الموثوق عبر Android Publisher API وتأكيد الشراء (`acknowledge`) خلال 3 أيام لمنع الإلغاء التلقائي.

### و. إدارة المحتوى المنشأ من قِبل المستخدمين (User-Generated Content - UGC)
* [x] **شروط استخدام صارمة تمنع الإساءة والابتزاز والمحتوى غير اللائق:** معروضة ومشار إليها عند تسجيل الدخول وفي شروط الخدمة.
* [x] **نظام إبلاغ فوري عن الأعضاء:** متوفر في الملف الشخصي وفي شاشة المحادثة (`Report Member Dialog`).
* [x] **نظام حظر فوري للأعضاء:** يتيح للعضو حظر أي عضو آخر فورياً، مما يمنعه من إرسال طلبات التعارف أو الرسائل، مع إمكانية إدارة قائمة المحظورين وإلغاء الحظر.
* [x] **لوحة إشراف وتدقيق إداري (Filament Admin Panel):** تتيح للمشرفين مراجعة البلاغات فورياً، فحص الصور قبل النشر، وتجميد أو حظر الحسابات المخالفة.

---

## 3. قائمة المهام التنفيذية المطلوبة من مالك حساب Google Play Console

يجب على مالك الحساب (Account Owner) إكمال البنود التالية داخل لوحة التحكم قبل إرسال التطبيق للمراجعة النهائية:

1. **إدخال روابط السياسات في Play Console:**
   - رابط سياسة الخصوصية: `https://[YOUR_PRODUCTION_DOMAIN]/legal/privacy-policy`
   - رابط حذف الحساب: `https://[YOUR_PRODUCTION_DOMAIN]/legal/delete-account`
   - رابط معايير سلامة الأطفال: `https://[YOUR_PRODUCTION_DOMAIN]/legal/child-safety`
2. **إعداد باقة الاشتراك الشهري (Subscription Product Setup):**
   - المعرّف البرمجي (Product ID): `naseebak_monthly_membership`
   - نوع الفوترة: تجديد تلقائي شهري (Monthly Auto-Renewing).
   - التفعيل وتحديد الأسعار حسب الدول المستهدفة (مصر، السعودية، الخليج العربي، إلخ).
3. **ربط إشعارات المطورين في الوقت الفعلي (Real-Time Developer Notifications - RTDN):**
   - إنشاء موضوع Google Cloud Pub/Sub (`projects/[PROJECT_ID]/topics/play-rtdn`).
   - منح الصلاحية لخدمة جوجل: `google-play-developer-notifications@system.gserviceaccount.com` بصلاحية `Pub/Sub Publisher`.
   - إعداد Push Subscription يشير إلى: `https://[YOUR_PRODUCTION_DOMAIN]/api/v1/webhooks/google-play/rtdn`.
   - تفعيل خيار التحقق من توقيع Google Service Account OIDC.
4. **تعبئة نموذج المحتوى والعمر (Content Rating & Target Audience):**
   - الإجابة على استبيان IARC والحصول على تصنيف مناسب للبالغين (+18 أو Parental Guidance حسب الدولة).
   - اختيار الفئة المستهدفة: 18 سنة فما فوق فقط.
5. **تعبئة نموذج أمان البيانات (Data Safety Form):**
   - مطابقة البيانات الموضحة في البند (2-د) أعلاه.
6. **توفير بيانات حساب تجريبي للمراجعين (App Review Credentials):**
   - إنشاء حساب تجريبي مكتمل (معتمد إدارياً ومفعل به عضوية تجريبية) وتزويد فريق مراجعة Google Play ببيانات الدخول في قسم **App access**.
