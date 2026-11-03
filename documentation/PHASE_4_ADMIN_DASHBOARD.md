# نصيبك — NASEEBAK: PHASE 4 IMPLEMENTATION REPORT
## Complete Web Administration Dashboard (`لوحة تحكم نصيبك`)

---

## 1. Filament Version & Compatibility Assessment

### Selected Package & Compatibility Matrix
- **Framework:** `laravel/framework: ^11.31` ([composer.json](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/composer.json))
- **PHP Requirement:** `^8.2`
- **Filament Package:** `filament/filament: ^3.2` (Note: In the official Filament ecosystem for Laravel 11 and PHP 8.2+, the v3.2+ release series is the current stable major series; Filament v5 does not exist in Packagist stable releases yet. All panel providers, resources, infolists, widgets, and custom pages are authored against official Filament Panel Builder APIs).

### Installation & Provisioning Commands (for Production / VPS Environment)
```bash
cd backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan db:seed --force
php artisan filament:assets

# Provision the initial Super Administrator interactively (no hardcoded credentials):
php artisan naseebak:make-super-admin
```

---

## 2. Administrator Authentication Boundary & Role Matrix

### Dedicated Authentication Boundary
- **Guard:** `admin` (`session` driver, `administrators` Eloquent provider) defined in [auth.php](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/config/auth.php).
- **Model & Table:** [`Administrator`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Models/Administrator.php) (`administrators` table created in [2026_11_02_000004_create_administrators_and_moderation_enhancements_tables.php](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/database/migrations/2026_11_02_000004_create_administrators_and_moderation_enhancements_tables.php)).
- **Isolation from Mobile Members:** Regular mobile users (`users` table) authenticate exclusively via Google Sign-In + Laravel Sanctum (`sanctum` guard) and can never authenticate against the `admin` guard or access `/admin`.
- **Middleware Protection:** [`EnsureAdminAccountIsActive`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Http/Middleware/EnsureAdminAccountIsActive.php) verifies active status, role membership (`super_admin` or `moderator`), MFA session verification when `mfa_enabled = true`, and role-level authorization on every request.

### Role Permission Matrix
| Capability / Module | `super_admin` | `moderator` | Enforced By |
| :--- | :---: | :---: | :--- |
| Access Dashboard Overview (`لوحة المعلومات`) | Yes | Yes | [`AdminPanelProvider`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Providers/Filament/AdminPanelProvider.php) |
| View & Filter Members (`إدارة الأعضاء`) | Yes (incl. email) | Yes (email hidden) | [`MemberResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/MemberResource.php) |
| Suspend / Restore Member Account | Yes | Yes | [`AdminModerationService`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Services/Admin/AdminModerationService.php) |
| Moderate Profiles (`مراجعة الملفات الشخصية`) | Yes | Yes | [`ProfileModerationResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/ProfileModerationResource.php) |
| Moderate / Remove Photos (`مراجعة الصور`) | Yes | Yes | [`PhotoModerationResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/PhotoModerationResource.php) |
| Handle User Reports (`البلاغات والشكاوى`) | Yes | Yes | [`UserReportResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/UserReportResource.php) |
| Monitor Matchmaking Requests (`طلبات التعارف`) | Read-Only | Read-Only | [`MatchmakingRequestResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/MatchmakingRequestResource.php) |
| View Subscriptions & Payment History | Read-Only | Read-Only | [`SubscriptionResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/SubscriptionResource.php) |
| Update Monthly Web Subscription Price (`أسعار الاشتراك`) | **Yes** | **No (403)** | [`ManageSubscriptionPricingPage`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Pages/ManageSubscriptionPricingPage.php) |
| Switch Active Web Payment Gateway (`إعدادات بوابات الدفع`) | **Yes** | **No (403)** | [`ManagePaymentGatewaysPage`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Pages/ManagePaymentGatewaysPage.php) |
| Modify Application Settings (`إعدادات التطبيق`) | **Yes** | **No (403)** | [`ManageApplicationSettingsPage`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Pages/ManageApplicationSettingsPage.php) |
| Manage Administrators & Roles (`المديرون والصلاحيات`) | **Yes** | **No (403)** | [`AdministratorResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/AdministratorResource.php) |
| View Admin Audit Log (`سجل النشاط الإداري`) | Read-Only | Read-Only | [`AdminAuditLogResource`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Filament/Resources/AdminAuditLogResource.php) |

---

## 3. Atomic Payment Gateway Switching & Pricing Controls

- **Single Active Gateway Rule:** `payment_settings.active_web_payment_gateway` only permits `paymob` or `sha7nawy` (enforced by validation, model constant `PaymentSetting::ALLOWED_GATEWAYS`, and PostgreSQL `CHECK` constraint `chk_active_web_payment_gateway`).
- **Atomic Row-Locked Switch:** [`PaymentSetting::switchActiveGatewayAtomically`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Models/PaymentSetting.php#L67-L115) executes inside `DB::transaction()` with `lockForUpdate()`, verifies `isGatewayConfigured($newGateway)` before allowing activation, updates `active_web_payment_gateway`, and writes an immutable `payment_gateway.switched` record to `admin_audit_logs`.
- **Web Subscription Pricing:** [`PaymentSetting::updateMonthlyWebPriceAtomically`](file:///C:/Users/w.i/.gemini/antigravity/scratch/naseebak/backend/app/Models/PaymentSetting.php#L121-L176) validates positive numeric values (`> 0`) with at most 2 decimal places, updates `payment_settings.web_monthly_price` and `subscription_plans.web_price_amount` for future web checkouts, preserves historical transactions and Google Play Billing product pricing, and records `subscription_pricing.updated` in `admin_audit_logs`.
