# نصيبك — Naseebak
## Phase 3 Documentation: Complete Discovery, Advanced Search, Member Profiles & Favorites

### 1. Overview
Phase 3 implements the complete member discovery, advanced search, persistent search preferences, public member profile inspection, and favorites management system for **نصيبك (Naseebak)**:
- **Screen 07 (`الرئيسية` — `DiscoveryHomeScreen`):** Displays the Naseebak header, user greeting and profile shortcut, the primary search callout (`"ابحث عن شريك حياتك"` / `"ابدأ البحث"`), and `"أعضاء مقترحون"` populated strictly from real PostgreSQL records without fake profiles or artificial compatibility scores.
- **Screen 08 (`مواصفات شريك حياتك` — `AdvancedSearchScreen`):** Supports filtering by Gender (`ذكر` / `أنثى`), Age Range (`min_age >= 18`, `min_age <= max_age`), Marital Status (single or multi-select: `أعزب/عزباء`, `مطلق/مطلقة`, `أرمل/أرملة`), Education Level, Smoking Status (`الكل` / `غير مدخن` / `مدخن`), Occupation, Nationality, Country of Residence, and Region. Saves preferences in `user_preferences` and executes parameterized PostgreSQL queries.
- **Screen 09 (`نتائج البحث` — `SearchResultsScreen`):** Displays removable active filter chips, predefined deterministic sorting (`newest`, `age_asc`, `age_desc`), and server-side pagination (`20` members per page) with duplicate-request protection and empty/error/retry states.
- **Screen 10 (`الملف الشخصي` — `MemberProfileScreen`):** Displays permitted member details via `GET /api/v1/members/{targetUser}/profile` while protecting private fields (`email`, `google_sub`, `date_of_birth`) and enforcing photo privacy (`public`, `subscribers_only`, `accepted_matches_only`). Includes the primary **"طلب التعارف"** action (clearly communicating the monthly subscription requirement without creating fake requests or fake payments), secondary **"إضافة إلى المفضلة"** toggle, and real **"حظر العضو"** / **"الإبلاغ عن العضو"** safety actions.
- **Screen 16 (`المفضلة` — `FavoritesScreen`):** Displays saved members (`GET /api/v1/favorites`), supports adding/removing favorites (`POST / DELETE /api/v1/favorites/{member}`), local filtering within saved profiles, and empty state navigation (`"لم تقم بإضافة أي أعضاء إلى المفضلة بعد."` -> `"استكشف الأعضاء"`).

---

### 2. Mandatory PostgreSQL Search Exclusions (`MemberSearchQueryService`)
Every discovery, search, and favorites query enforces all 9 mandatory exclusions server-side:
1. Currently authenticated user (`user_id != $viewer->id`)
2. Suspended users (`users.account_status = 'active'`)
3. Banned / pending_deletion / deactivated accounts
4. Soft-deleted accounts (`users.deleted_at IS NULL` & `users.profile_completed = true`)
5. Hidden profiles (`user_profiles.is_visible = true`)
6. Unapproved profiles (`user_profiles.moderation_status = 'approved'`)
7. Underage users (`user_profiles.age_years >= 18` and `date_of_birth <= now() - 18 years`)
8. Members blocked by the current user (`NOT EXISTS` in `blocked_users`)
9. Members who have blocked the current user (`NOT EXISTS` in `blocked_users`)
