# نصيبك — Naseebak
## Phase 2 Documentation: Complete Profile Management, Photo Upload & Privacy Controls

### 1. Overview
Phase 2 implements the complete end-to-end profile management system for **نصيبك (Naseebak)** across the Laravel REST API, PostgreSQL database, private storage engine, and Flutter Android RTL UI:
- **Screen 18 (`ملفي الشخصي` — `MyProfileScreen`):** Displays only the real information provided by the authenticated member, a profile completion percentage bar, current privacy status summary, and quick actions for **تعديل الملف الشخصي**, **تغيير الصورة الشخصية**, and **إعدادات الخصوصية**.
- **Screen 19 (`تعديل الملف الشخصي` — `EditProfileScreen`):** Prepopulates all 17 profile fields from the member's saved profile, detects unsaved changes on back navigation, enforces 18+ age verification and marital status consistency rules, and saves via `PATCH /api/v1/profile`.
- **Screen 21 (`إعدادات الخصوصية` — `PrivacySettingsScreen`):** Controls profile search visibility (`is_visible`: show/hide) and photo visibility (`photo_privacy`: `public`, `subscribers_only`, `accepted_matches_only`), persisted in PostgreSQL and enforced immediately on the backend.
- **Secure Photo Upload & Streaming (`ProfilePhotoUploader` + `SecurePhotoStorageService`):** Compresses images to `<= 1080px` and `<= 2 MB`, verifies binary image headers (`getimagesize`), strips EXIF/GPS location metadata by re-encoding the image buffer, stores files with random UUID filenames in Laravel's `private` disk, deletes replaced primary photos to prevent orphan files, and streams photos only through the authenticated `GET /api/v1/profile/photos/{photo}/stream` endpoint with `Cache-Control: private, no-store`.

---

### 2. Backend REST API Endpoints (Phase 2)
| Method | Endpoint | Middleware | Purpose |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/profile` | `auth:sanctum`, `active_account` | Retrieve authenticated user's own profile, completion %, primary photo metadata, and privacy settings |
| `PATCH` | `/api/v1/profile` | `auth:sanctum`, `active_account`, `throttle:20,1` | Update authenticated user's profile fields (ownership strictly bound to `$request->user()`, `user_id` prohibited in payload) |
| `POST` | `/api/v1/profile/photo` | `auth:sanctum`, `active_account`, `throttle:10,1` | Upload, sanitize (strip EXIF), resize (`<= 1080px`), and store primary photo in `private` disk while purging replaced orphan files |
| `GET` | `/api/v1/profile/photos/{photo}/stream` | `auth:sanctum`, `active_account` | Authenticated binary image stream enforcing block status, hidden profile rules, and `photo_privacy` (`public`, `subscribers_only`, `accepted_matches_only`) |
| `GET` | `/api/v1/profile/privacy` | `auth:sanctum`, `active_account` | Retrieve current `is_visible` and `photo_privacy` settings |
| `PATCH` | `/api/v1/profile/privacy` | `auth:sanctum`, `active_account`, `throttle:30,1` | Immediately update `is_visible` and `photo_privacy` in PostgreSQL |
| `GET` | `/api/v1/members/{targetUser}/profile` | `auth:sanctum`, `active_account` | View another member's profile with server-side enforcement of blocks, hidden profile (`is_visible = false`), and photo privacy |
