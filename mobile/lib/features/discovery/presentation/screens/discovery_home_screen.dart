import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/naseebak_logo_badge.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notification_center_screen.dart';
import '../../../profile/presentation/providers/profile_management_provider.dart';
import '../../../profile/presentation/providers/profile_registration_provider.dart';
import '../providers/discovery_provider.dart';
import '../widgets/member_card.dart';
import 'advanced_search_screen.dart';
import 'favorites_screen.dart';
import 'member_profile_screen.dart';

/// 07. Home & Discovery Screen (الرئيسية)
/// تعرض ترحيب تطبيق "نصيبك"، بطاقة "ابحث عن شريك حياتك" مع زر "ابدأ البحث"،
/// وقسم "أعضاء مقترحون" المستمد حصراً من قاعدة البيانات الحقيقية دون أي حسابات وهمية أو نسب توافق مصطنعة.
class DiscoveryHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenMyProfileTab;

  const DiscoveryHomeScreen({
    super.key,
    required this.onOpenMyProfileTab,
  });

  @override
  ConsumerState<DiscoveryHomeScreen> createState() =>
      _DiscoveryHomeScreenState();
}

class _DiscoveryHomeScreenState extends ConsumerState<DiscoveryHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).loadDiscoveryFeed();
    });
  }

  void _openAdvancedSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdvancedSearchScreen(),
      ),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FavoritesScreen(),
      ),
    );
  }

  void _openMemberProfile(int userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(memberUserId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);
    final mgmtProfile = ref.watch(profileManagementProvider).profile;
    final regDraft = ref.watch(profileRegistrationProvider).draft;
    final rawName = mgmtProfile?.fullName ?? regDraft.fullName;
    final displayName =
        rawName.trim().isNotEmpty ? rawName.trim() : 'عضو نصيبك';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('الرئيسية'),
        leadingWidth: 130,
        leading: const Padding(
          padding: EdgeInsetsDirectional.only(start: 14),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: NaseebakLogoBadge(
              size: 32,
              showText: true,
            ),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('home_open_favorites_btn'),
            tooltip: 'المفضلة',
            onPressed: _openFavorites,
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.primaryBlue,
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(
                notificationProvider.select((s) => s.unreadCount),
              );
              return IconButton(
                key: const Key('home_open_notifications_btn'),
                tooltip: 'الإشعارات',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationCenterScreen(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentYellow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.darkBlue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: () =>
              ref.read(discoveryProvider.notifier).loadDiscoveryFeed(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              // 1. Header Greeting & Profile Shortcut
              InkWell(
                onTap: widget.onOpenMyProfileTab,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.surfaceSubtleBlue,
                        child: Text(
                          displayName.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مرحبًا بك في نصيبك',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'أهلًا، $displayName',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'ملفي الشخصي',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Main Search Hero Card ("ابحث عن شريك حياتك")
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.darkBlue,
                      AppColors.primaryBlue,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'تعارف جاد ومحترم',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ابحث عن شريك حياتك',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'حدد المواصفات المناسبة لك وابدأ البحث.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.92),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      key: const Key('home_start_search_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentYellow,
                        foregroundColor: AppColors.darkBlue,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: _openAdvancedSearch,
                      icon: const Icon(Icons.search_rounded, size: 20),
                      label: const Text(
                        'ابدأ البحث',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 3. Suggested Members Section Header ("أعضاء مقترحون")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'أعضاء مقترحون',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: _openAdvancedSearch,
                    child: const Text(
                      'تخصيص المواصفات ←',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 4. Suggested Members List / Loading / Error / Empty States
              if (discoveryState.isLoadingDiscovery)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                )
              else if (discoveryState.discoveryError != null &&
                  discoveryState.suggestedMembers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 38,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        discoveryState.discoveryError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                ref
                                    .read(discoveryProvider.notifier)
                                    .loadDiscoveryFeed();
                              },
                              child: const Text('إعادة المحاولة'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _openAdvancedSearch,
                              child: const Text('ضبط معايير البحث'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else if (discoveryState.suggestedMembers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 42,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لا يوجد أعضاء متاحون حاليًا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'يمكنك تعديل مواصفات البحث لتوسيع نطاق النتائج المتاحة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        key: const Key('empty_discovery_adjust_search_btn'),
                        onPressed: _openAdvancedSearch,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('تعديل مواصفات البحث'),
                      ),
                    ],
                  ),
                )
              else
                ...discoveryState.suggestedMembers.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MemberCard(
                      member: member,
                      onTapViewProfile: () => _openMemberProfile(member.userId),
                      onToggleFavorite: () async {
                        final err = await ref
                            .read(discoveryProvider.notifier)
                            .toggleFavorite(member);
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.error,
                              content: Text(err),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              // 5. Privacy & Safety Footer Strip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تُعرض فقط الملفات المعتمدة والنشطة للبالغين (+18) مع احترام تام لإعدادات الخصوصية.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
