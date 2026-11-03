import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../../core/widgets/naseebak_logo_badge.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notification_center_screen.dart';
import '../../../profile/presentation/providers/profile_management_provider.dart';
import '../../../profile/presentation/providers/profile_registration_provider.dart';
import '../providers/discovery_provider.dart';
import 'advanced_search_screen.dart';
import 'favorites_screen.dart';
import 'member_profile_screen.dart';

/// 07. Home & Discovery Screen (شاشة اكتشف الرئيسية — تصميم Astra Screen 07)
/// تتضمن الهيدر الكحلي المنحني مع شعار نصيبك وأيقونة الإشعارات وعنوان "اكتشف"
/// و"ابدأ رحلة البحث عن شريك حياتك"، وشريط البحث السريع والفلاتر، وبطاقات الأعضاء المقترحين.
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
        rawName.trim().isNotEmpty ? rawName.trim() : 'عضو نَصِيبُكَ';

    return Scaffold(
      backgroundColor: AppColors.softBackground,
      body: RefreshIndicator(
        color: AppColors.primaryNavy,
        onRefresh: () =>
            ref.read(discoveryProvider.notifier).loadDiscoveryFeed(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1. Astra Deep Navy Curved Header Banner
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppColors.primaryNavy,
                    AppColors.deepNavy,
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Bar: Logo + "اكتشف" + Favorites & Notification Icons
                      Row(
                        children: [
                          const NaseebakLogoBadge(
                            size: 38,
                            showText: false,
                            lightText: true,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اكتشف',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  'ابدأ رحلة البحث عن شريك حياتك',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.goldAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('home_open_favorites_btn'),
                            tooltip: 'المفضلة',
                            onPressed: _openFavorites,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.10),
                            ),
                            icon: const Icon(
                              Icons.favorite_border_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Consumer(
                            builder: (context, ref, _) {
                              final unreadCount = ref.watch(
                                notificationProvider
                                    .select((s) => s.unreadCount),
                              );
                              return IconButton(
                                key: const Key('home_open_notifications_btn'),
                                tooltip: 'الإشعارات',
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.10),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NotificationCenterScreen(),
                                    ),
                                  );
                                },
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Colors.white,
                                      size: 22,
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
                                            color: AppColors.goldAccent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppColors.primaryNavy,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryNavy,
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
                      ),
                      const SizedBox(height: 18),

                      // Search & Filter Bar inside Navy Header (Astra Screen 07)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              key: const Key('home_start_search_btn'),
                              onTap: _openAdvancedSearch,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                height: 48,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color: AppColors.primaryNavy,
                                      size: 21,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'ابحث عن شريك حياتك حسب المواصفات...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily:
                                              NaseebakTypography.fontFamily,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: _openAdvancedSearch,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.goldAccent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.primaryNavy,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Main Body Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quick Profile Greeting Card
                  InkWell(
                    onTap: widget.onOpenMyProfileTab,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.subtleBorder),
                        boxShadow: NaseebakSpacing.subtleCardShadow,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 21,
                            backgroundColor: AppColors.creamHighlight,
                            child: Text(
                              displayName.substring(0, 1),
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'مرحبًا بك في نَصِيبُكَ',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'أهلًا، $displayName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'ملفي الشخصي',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Quick Filter Chips Row (Astra Screen 07)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickFilterPill(
                          label: 'الكل',
                          isSelected: true,
                          onTap: _openAdvancedSearch,
                        ),
                        const SizedBox(width: 8),
                        _QuickFilterPill(
                          label: 'الفئة العمرية',
                          icon: Icons.cake_outlined,
                          onTap: _openAdvancedSearch,
                        ),
                        const SizedBox(width: 8),
                        _QuickFilterPill(
                          label: 'الحالة الاجتماعية',
                          icon: Icons.favorite_border_rounded,
                          onTap: _openAdvancedSearch,
                        ),
                        const SizedBox(width: 8),
                        _QuickFilterPill(
                          label: 'المؤهل والعمل',
                          icon: Icons.school_outlined,
                          onTap: _openAdvancedSearch,
                        ),
                        const SizedBox(width: 8),
                        _QuickFilterPill(
                          label: 'المنطقة والإقامة',
                          icon: Icons.location_on_outlined,
                          onTap: _openAdvancedSearch,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Suggested Members Section Header
                  NaseebakSectionHeader(
                    title: 'أعضاء مقترحون',
                    actionLabel: 'بحث متقدم ←',
                    onActionTap: _openAdvancedSearch,
                  ),
                  const SizedBox(height: 10),

                  // Suggested Members List / Loading / Error / Empty States
                  if (discoveryState.isLoadingDiscovery)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 46),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    )
                  else if (discoveryState.discoveryError != null &&
                      discoveryState.suggestedMembers.isEmpty)
                    NaseebakEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: discoveryState.discoveryError!,
                      subtitle:
                          'يرجى التحقق من الاتصال بالخادم أو ضبط معايير البحث.',
                      actionButton: Row(
                        children: [
                          Expanded(
                            child: NaseebakSecondaryButton(
                              label: 'إعادة المحاولة',
                              onPressed: () {
                                ref
                                    .read(discoveryProvider.notifier)
                                    .loadDiscoveryFeed();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NaseebakPrimaryButton(
                              label: 'ضبط البحث',
                              onPressed: _openAdvancedSearch,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (discoveryState.suggestedMembers.isEmpty)
                    NaseebakEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'لا يوجد أعضاء متاحون حاليًا',
                      subtitle:
                          'يمكنك تعديل مواصفات البحث لتوسيع نطاق النتائج المتاحة.',
                      actionButton: NaseebakSecondaryButton(
                        buttonKey:
                            const Key('empty_discovery_adjust_search_btn'),
                        label: 'تعديل مواصفات البحث',
                        icon: const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: AppColors.primaryNavy,
                        ),
                        onPressed: _openAdvancedSearch,
                      ),
                    )
                  else
                    ...discoveryState.suggestedMembers.map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: MemberCard(
                          member: member,
                          onTapViewProfile: () =>
                              _openMemberProfile(member.userId),
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

                  const SizedBox(height: 12),

                  // Privacy & Safety Footer Strip
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.subtleBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 19,
                          color: AppColors.primaryNavy,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تُعرض فقط الملفات المعتمدة والنشطة للبالغين (+18) مع احترام تام لإعدادات الخصوصية.',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
          ],
        ),
      ),
    );
  }
}

class _QuickFilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickFilterPill({
    required this.label,
    this.icon,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.subtleBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.goldAccent : AppColors.primaryNavy,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
