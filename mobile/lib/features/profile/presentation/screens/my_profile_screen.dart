import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_management_provider.dart';
import '../widgets/profile_photo_uploader.dart';
import 'blocked_members_screen.dart';
import 'delete_account_screen.dart';
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

/// Screen 07 (Batch 2B) — My Profile Screen (`ملفي الشخصي`)
/// واجهة العضو الشخصية وإدارة حسابه بتصميم نَصِيبُكَ الفاخر (Astra Design System)
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NaseebakColors.backgroundBeige,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'ملفي الشخصي',
              subtitle: 'بياناتك الحقيقية وإعدادات حسابك في نَصِيبُكَ',
              trailing: [
                IconButton(
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  onPressed: state.isLoading
                      ? null
                      : () {
                          ref.read(profileManagementProvider.notifier).loadOwnProfile();
                        },
                ),
              ],
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isLoading && profile == null) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        NaseebakLoadingSkeleton(height: 120),
                        SizedBox(height: 14),
                        NaseebakLoadingSkeleton(height: 180),
                        SizedBox(height: 14),
                        NaseebakLoadingSkeleton(height: 200),
                      ],
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
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
                              color: NaseebakColors.accentGoldMuted.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: NaseebakColors.accentGold.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: NaseebakColors.accentGoldDark,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.successMessage!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: NaseebakColors.primaryNavyDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        if (state.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: NaseebakColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: NaseebakColors.error.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: NaseebakColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: NaseebakColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 1. Profile Completion Indicator Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: NaseebakColors.cardBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: NaseebakColors.borderLight),
                            boxShadow: const [
                              BoxShadow(
                                color: NaseebakColors.shadowColor,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: NaseebakColors.textDarkNavy,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NaseebakColors.accentGoldMuted.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: NaseebakColors.accentGold.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '${state.completionPercentage}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: NaseebakColors.accentGoldDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: (state.completionPercentage / 100)
                                      .clamp(0.0, 1.0),
                                  minHeight: 7,
                                  backgroundColor: NaseebakColors.backgroundBeige,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    NaseebakColors.accentGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Identity & Photo Header Card
                        Container(
                          decoration: BoxDecoration(
                            color: NaseebakColors.cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: NaseebakColors.borderLight),
                            boxShadow: const [
                              BoxShadow(
                                color: NaseebakColors.shadowColor,
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 22),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      NaseebakColors.primaryNavy.withOpacity(0.05),
                                      NaseebakColors.accentGoldMuted.withOpacity(0.3),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(19),
                                  ),
                                ),
                                child: Center(
                                  child: ProfilePhotoUploader(
                                    fallbackInitial: initialLetter,
                                    radius: 48,
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
                                              color: NaseebakColors.textDarkNavy,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: NaseebakColors.accentGoldMuted.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: NaseebakColors.accentGold.withOpacity(0.4),
                                            ),
                                          ),
                                          child: Text(
                                            profile.moderationStatusLabelAr,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: NaseebakColors.accentGoldDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: NaseebakColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${profile.region}، ${profile.countryOfResidence} (${profile.nationality})',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: NaseebakColors.textWarmGray,
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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: NaseebakColors.primaryNavy,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 11),
                                            ),
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
                                              size: 17,
                                            ),
                                            label: const Text(
                                              'تعديل الملف الشخصي',
                                              style: TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            key: const Key(
                                                'open_privacy_settings_btn'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: NaseebakColors.primaryNavy,
                                              side: const BorderSide(
                                                color: NaseebakColors.primaryNavy,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 11),
                                            ),
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
                                              size: 17,
                                            ),
                                            label: const Text(
                                              'إعدادات الخصوصية',
                                              style: TextStyle(fontWeight: FontWeight.w700),
                                            ),
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
                        const SizedBox(height: 14),

                        // Subscription Status Card
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
                        const SizedBox(height: 14),

                        // 3. Detailed Profile Sections
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
                              color: NaseebakColors.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: NaseebakColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الهوايات والاهتمامات',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: NaseebakColors.textDarkNavy,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: profile.hobbies.map((hobby) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NaseebakColors.accentGoldMuted.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: NaseebakColors.accentGold.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        hobby,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: NaseebakColors.primaryNavyDark,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (profile.bio != null &&
                            profile.bio!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: NaseebakColors.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: NaseebakColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'نبذة عني',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: NaseebakColors.textDarkNavy,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  profile.bio!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: NaseebakColors.textWarmGray,
                                    height: 1.75,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Grouped Settings Menu Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: NaseebakColors.cardBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: NaseebakColors.borderLight),
                            boxShadow: const [
                              BoxShadow(
                                color: NaseebakColors.shadowColor,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSettingsRow(
                                key: const Key('open_notification_center_btn'),
                                icon: Icons.notifications_none_rounded,
                                title: 'مركز الإشعارات',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NotificationCenterScreen(),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 16),
                              _buildSettingsRow(
                                key: const Key('open_notification_preferences_btn'),
                                icon: Icons.tune_rounded,
                                title: 'تفضيلات الإشعارات',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NotificationPreferencesScreen(),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 16),
                              _buildSettingsRow(
                                key: const Key('open_blocked_members_btn'),
                                icon: Icons.block_rounded,
                                title: 'الأعضاء المحظورون',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const BlockedMembersScreen(),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 16),
                              _buildSettingsRow(
                                key: const Key('open_delete_account_btn'),
                                icon: Icons.delete_outline_rounded,
                                title: 'حذف الحساب نهائيًا',
                                isDestructive: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const DeleteAccountScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                key: const Key('logout_account_btn'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: NaseebakColors.error,
                                  side: BorderSide(
                                    color: NaseebakColors.error.withOpacity(0.45),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                label: const Text(
                                  'تسجيل الخروج',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? NaseebakColors.error : NaseebakColors.primaryNavy,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDestructive
                      ? NaseebakColors.error
                      : NaseebakColors.textDarkNavy,
                ),
              ),
            ),
            Icon(
              Icons.arrow_back_ios_rounded,
              size: 14,
              color: isDestructive
                  ? NaseebakColors.error.withOpacity(0.6)
                  : NaseebakColors.textMuted,
            ),
          ],
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
        color: NaseebakColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NaseebakColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: NaseebakColors.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: NaseebakColors.textDarkNavy,
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
              color: NaseebakColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: NaseebakColors.textDarkNavy,
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
            color: NaseebakColors.primaryNavy,
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
              color: NaseebakColors.textDarkNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ??
                'يعرض تطبيق نَصِيبُكَ بياناتك الحقيقية فقط دون توليد أي بيانات افتراضية. يرجى إكمال ملفك الشخصي ليظهر هنا.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: NaseebakColors.textWarmGray,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NaseebakColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: onCompleteProfile,
            child: const Text(
              'استكمال الملف الشخصي الآن',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: NaseebakColors.primaryNavy,
              side: const BorderSide(color: NaseebakColors.primaryNavy),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
