# نصيبك — Naseebak
## Complete Android Matrimonial Platform (Flutter + Laravel + PostgreSQL + Filament + Google Sign-In + FCM)

### 1. Project Identity & Branding
- **Arabic Name:** نصيبك
- **English Identifier:** Naseebak
- **Language & Direction:** Arabic (`ar`), strictly RTL (`TextDirection.rtl`)
- **Age Policy:** Exclusively for adults aged **18 or older** (`>= 18` enforced in both Flutter UI and Laravel backend validation)
- **Approved Color Palette:**
  - Primary Background: `#FFFFFF`
  - Secondary Background: `#F5F8FC`
  - Primary Blue: `#145A9E`
  - Dark Blue: `#123D6A`
  - Accent Yellow: `#FFC43D`
  - Text Primary: `#1D2939`
- **Logo Asset Status:**
  - A minimalist, non-religious bride-and-groom placeholder logo (`NaseebakLogoBadge`) is implemented and clearly labeled as a placeholder design reference until the final approved production vector logo is supplied.

---

### 2. Repository Structure
```text
naseebak/
├── mobile/                  # Flutter Android Application (Material 3, Riverpod, Dio, Google Sign-In, FCM, Play Billing)
├── backend/                 # Laravel 11 REST API + Filament v3 Admin + Sanctum + Reverb + PostgreSQL Migrations
├── infrastructure/          # Shared Ubuntu VPS (4 GB RAM / 50 GB Disk) Nginx, Supervisor & Pre-Flight Inspection Scripts
│   ├── nginx/
│   ├── supervisor/
│   └── deployment/
├── design_reference/        # Preserved UI layout reference (wasal_ui_mockup.html & wasal_mockup_complete.png)
└── documentation/           # Phase-by-phase technical & deployment documentation
```

---

### 3. Phase 1 Implementation Summary
1. **PostgreSQL Database Schema (All 19 Required Entities):**
   - `users`, `user_profiles`, `user_photos`, `user_preferences`, `personal_access_tokens`
   - `subscription_plans`, `subscriptions`, `payment_transactions`, `payment_settings` (with `CHECK (active_web_payment_gateway IN ('paymob', 'sha7nawy'))`)
   - `matchmaking_requests`, `conversations`, `conversation_participants`, `messages`, `device_tokens`, `notifications`, `favorites`, `blocked_users`, `user_reports`, `app_settings`, `admin_audit_logs`
2. **Google Sign-In ONLY Authentication Architecture:**
   - Flutter `GoogleAuthRepository` obtains a Google OpenID Connect `idToken` and sends it over HTTPS to `POST /api/v1/auth/google`.
   - Laravel `GoogleIdTokenVerifierService` verifies the cryptographic signature, audience (`aud`), issuer (`iss`), and expiration (`exp`), extracts Google's stable `sub` identifier, checks account suspension status, and issues a Laravel Sanctum token.
   - Raw Google ID tokens are never written to application logs.
3. **Initial Profile Registration Screens (01 to 06):**
   - `01` Welcome Screen (`WelcomeScreen`)
   - `02` Google Sign-In Screen (`GoogleSignInScreen`)
   - `03` Basic Profile Information (`BasicProfileStepScreen`)
   - `04` Family, Education and Work (`FamilyEducationWorkStepScreen`)
   - `05` Additional Profile Details and Biography (`AdditionalDetailsStepScreen`)
   - `06` Profile Preview & Visibility Control (`ProfilePreviewStepScreen`)
   - Plus `SuspendedAccountScreen` and `07` `HomeDiscoveryPlaceholderScreen`.
