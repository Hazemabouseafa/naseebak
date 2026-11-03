import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_management_provider.dart';
import '../widgets/profile_photo_uploader.dart';
import 'edit_profile_screen.dart';
import 'privacy_settings_screen.dart';
import '../../../messaging/data/services/realtime_messaging_service.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notification_center_screen.dart';
import '../../../notifications/presentation/screens/notification_preferences_screen.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/screens/my_subscription_screen.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../../subscription/presentation/widgets/subscription_status_widget.dart';

/// 18. My Profile Screen (ملفي الشخصي)
/// تعرض فقط البيانات الفعلية التي أدخلها العضو والمسترجعة من Laravel API.
/// لا تولّد أي بيانات وهمية، وتدعم حالات التحميل والخطأ والملف الفارغ،
/// وتوفر الأزرار الثلاثة المطلوبة: تعديل الملف الشخصي، تغيير الصورة الشخصية، وإعدادات الخصوصية.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileManagementProvider.notifier).loadOwnProfile();
      ref.read(subscriptionProvider.notifier).loadSubscriptionCenter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileManagementProvider);
    final profile = state.profile;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: state.isLoading
                ? null
                : () {
                    ref.read(profileManagementProvider.notifier).loadOwnProfile();
                  },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (state.isLoading && profile == null) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryBlue),
                    SizedBox(height: 14),
                    Text(
                      'جارٍ تحميل بيانات ملفك الشخصي...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (profile == null) {
              return _EmptyOrErrorProfileView(
                errorMessage: state.errorMessage,
                onRetry: () {
                  ref.read(profileManagementProvider.notifier).loadOwnProfile();
                },
                onCompleteProfile: () {
                  ref
                      .read(authControllerProvider.notifier)
                      .enterProfileRegistrationPreview();
                },
              );
            }

            final initialLetter = profile.fullName.trim().isNotEmpty
                ? profile.fullName.trim().substring(0, 1)
                : 'ن';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Feedback Banner (Success / Error)
                  if (state.successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtleBlue,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.primaryBlue,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.successMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 1. Profile Completion Indicator Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'نسبة اكتمال الملف الشخصي',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentYellow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${state.completionPercentage}%',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: (state.completionPercentage / 100)
                                .clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: Colors.white,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Identity & Photo Header Card (Inspired by Mockup Screen 08)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.surfaceSubtleBlue,
                                AppColors.surfaceSubtleYellow,
                              ],
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: Center(
                            child: ProfilePhotoUploader(
                              fallbackInitial: initialLetter,
                              radius: 46,
                              showChangeButton: true,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${profile.fullName} • ${profile.ageYears} سنة',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSubtleBlue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      profile.moderationStatusLabelAr,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${profile.region}، ${profile.countryOfResidence} (${profile.nationality})',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Primary Actions: Edit Profile & Privacy Settings
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      key: const Key('open_edit_profile_btn'),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const EditProfileScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('تعديل الملف الشخصي'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      key: const Key(
                                          'open_privacy_settings_btn'),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const PrivacySettingsScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.shield_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('إعدادات الخصوصية'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2b. Subscription Status Card (Screen 11 & MySubscriptionScreen access)
                  Consumer(
                    builder: (context, ref, _) {
                      final subState = ref.watch(subscriptionProvider);
                      return SubscriptionStatusWidget(
                        entitlement: subState.entitlement,
                        subscription: subState.currentSubscription,
                        onSubscribeTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SubscriptionScreen(),
                            ),
                          );
                        },
                        onManageTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MySubscriptionScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Detailed Profile Sections (Displays ONLY provided information)
                  _ProfileSectionCard(
                    title: 'المعلومات الأساسية والأسرية',
                    children: [
                      _ProfileDetailTile(
                        label: 'النوع',
                        value: profile.genderLabelAr,
                      ),
                      _ProfileDetailTile(
                        label: 'العمر والبرج',
                        value:
                            '${profile.ageYears} سنة • برج ${profile.zodiacSign}',
                      ),
                      _ProfileDetailTile(
                        label: 'الحالة الاجتماعية',
                        value: profile.maritalStatusLabelAr,
                      ),
                      _ProfileDetailTile(
                        label: 'هل سبق الزواج؟',
                        value: profile.previouslyMarried ? 'نعم' : 'لا',
                      ),
                      _ProfileDetailTile(
                        label: 'الأطفال',
                        value: profile.hasChildren
                            ? (profile.childrenCount > 0
                                ? 'نعم (${profile.childrenCount})'
                                : 'نعم')
                            : 'لا يوجد',
                      ),
                      _ProfileDetailTile(
                        label: 'الطول',
                        value: '${profile.heightCm} سم',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _ProfileSectionCard(
                    title: 'التعليم والعمل ونمط الحياة',
                    children: [
                      _ProfileDetailTile(
                        label: 'المؤهل الدراسي',
                        value: profile.educationLevelLabelAr,
                      ),
                      _ProfileDetailTile(
                        label: 'المهنة / العمل',
                        value: profile.occupation,
                      ),
                      _ProfileDetailTile(
                        label: 'حالة السكن',
                        value: profile.homeOwnershipLabelAr,
                      ),
                      _ProfileDetailTile(
                        label: 'التدخين',
                        value: profile.smokingStatusLabelAr,
                      ),
                      _ProfileDetailTile(
                        label: 'الجنسية',
                        value: profile.nationality,
                      ),
                      _ProfileDetailTile(
                        label: 'الإقامة والمنطقة',
                        value:
                            '${profile.countryOfResidence} — ${profile.region}',
                      ),
                    ],
                  ),

                  if (profile.hobbies.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الهوايات والاهتمامات',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.hobbies.map((hobby) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtleBlue,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  hobby,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Optional Biography (Displayed only if actually provided by user)
                  if (profile.bio != null &&
                      profile.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'نبذة عني',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile.bio!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Current Privacy Summary Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_person_outlined,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.isVisible
                                    ? 'ملفك الشخصي ظاهر في نتائج البحث'
                                    : 'ملفك الشخصي مخفي حالياً من نتائج البحث',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'خصوصية الصورة: ${profile.photoPrivacyLabelAr}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notification Center & Notification Preferences & Logout Actions
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('open_notification_center_btn'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NotificationCenterScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 18,
                                ),
                                label: const Text('مركز الإشعارات'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key(
                                  'open_notification_preferences_btn',
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NotificationPreferencesScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                ),
                                label: const Text('إعدادات الإشعارات'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('logout_account_btn'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                              color: AppColors.error.withOpacity(0.45),
                            ),
                          ),
                          onPressed: () async {
                            await ref
                                .read(notificationProvider.notifier)
                                .cleanupOnLogout();
                            ref
                                .read(realtimeMessagingServiceProvider)
                                .disconnect();
                            await ref
                                .read(authControllerProvider.notifier)
                                .signOut();
                          },
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileDetailTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrErrorProfileView extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onCompleteProfile;

  const _EmptyOrErrorProfileView({
    required this.errorMessage,
    required this.onRetry,
    required this.onCompleteProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            errorMessage != null
                ? Icons.cloud_off_rounded
                : Icons.person_add_alt_1_outlined,
            size: 48,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage != null
                ? 'تعذر استرجاع الملف الشخصي من الخادم'
                : 'لم تقم باستكمال ملفك الشخصي بعد',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ??
                'يعرض تطبيق نصيبك بياناتك الحقيقية فقط دون توليد أي بيانات افتراضية. يرجى إكمال ملفك الشخصي ليظهر هنا.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: onCompleteProfile,
            child: const Text('استكمال الملف الشخصي الآن'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
