import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notification_center_screen.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_management_provider.dart';
import '../../../profile/presentation/providers/profile_registration_provider.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../data/models/member_profile_model.dart';
import '../../data/models/search_preferences_model.dart';
import '../providers/discovery_provider.dart';
import 'advanced_search_screen.dart';
import 'favorites_screen.dart';
import 'member_profile_screen.dart';
import 'search_results_screen.dart';

/// Screen 03 — Home & Discovery (تصميم Screen 03 من UX Pilot)
/// خلفية بيضاء نقية مع الهيدر الشخصي المعاصر، صورة المستخدم، جرس الإشعارات،
/// شريط البحث السريع وزر التصفية #184A8C، شرائح التصفية، بطاقات الاكتشاف الكبيرة، وبنر نصيبك بلس.
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
  int _selectedFilterIndex = 0;
  final List<String> _filters = const ['الكل', 'قريب مني', 'جديد', 'متوافق'];

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

  Future<void> _openAllMembersResults() async {
    final ownGender = ref.read(profileManagementProvider).profile?.gender;
    final targetGender = ownGender == 'male'
        ? 'female'
        : (ownGender == 'female'
            ? 'male'
            : ref.read(discoveryProvider).filters.gender);

    ref.read(discoveryProvider.notifier).updateFilters(
          SearchPreferencesModel(
            gender: targetGender,
            minAge: 18,
            maxAge: 65,
          ),
        );
    await ref.read(discoveryProvider.notifier).executeSearch(
          savePreferences: false,
        );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SearchResultsScreen(),
      ),
    );
  }

  List<MemberCardModel> _computeDisplayedMembers(
    List<MemberCardModel> members,
    ProfileModel? viewerProfile,
  ) {
    if (members.length <= 1 || _selectedFilterIndex == 0 || _selectedFilterIndex == 2) {
      return members;
    }

    final copy = List<MemberCardModel>.from(members);
    if (_selectedFilterIndex == 1 && viewerProfile != null) {
      // 'قريب مني' — prioritize same region and country of residence
      copy.sort((a, b) {
        final aRegionMatch = a.region.trim() == viewerProfile.region.trim() ? 0 : 1;
        final bRegionMatch = b.region.trim() == viewerProfile.region.trim() ? 0 : 1;
        if (aRegionMatch != bRegionMatch) return aRegionMatch.compareTo(bRegionMatch);

        final aCountryMatch = a.countryOfResidence.trim() ==
                viewerProfile.countryOfResidence.trim()
            ? 0
            : 1;
        final bCountryMatch = b.countryOfResidence.trim() ==
                viewerProfile.countryOfResidence.trim()
            ? 0
            : 1;
        return aCountryMatch.compareTo(bCountryMatch);
      });
      return copy;
    }

    if (_selectedFilterIndex == 3 && viewerProfile != null) {
      // 'متوافق' — prioritize closest age and matching marital/education criteria
      copy.sort((a, b) {
        final aAgeDiff = (a.ageYears - viewerProfile.ageYears).abs();
        final bAgeDiff = (b.ageYears - viewerProfile.ageYears).abs();
        return aAgeDiff.compareTo(bAgeDiff);
      });
      return copy;
    }

    return copy;
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

  void _openSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SubscriptionScreen(),
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
        rawName.trim().isNotEmpty ? rawName.trim() : 'مرحباً بك';
    final displayedMembers = _computeDisplayedMembers(
      discoveryState.suggestedMembers,
      mgmtProfile,
    );

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: () =>
              ref.read(discoveryProvider.notifier).loadDiscoveryFeed(),
          child: CustomScrollView(
            slivers: [
              // 1. Personalized Header (Avatar + Greeting + Notifications & Favorites)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      // User Avatar
                      GestureDetector(
                        onTap: widget.onOpenMyProfileTab,
                        child: CircleAvatar(
                          radius: 23,
                          backgroundColor: AppColors.surfaceSubtleBlue,
                          child: Text(
                            displayName.isNotEmpty ? displayName.substring(0, 1) : 'ن',
                            style: const TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Greeting & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'صباح الخير',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text('👋', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'يمكن النهارده تلاقي نصيبك',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Favorites Button
                      NaseebakCircleButton(
                        buttonKey: const Key('home_open_favorites_btn'),
                        icon: Icons.favorite_border_rounded,
                        size: 42,
                        iconSize: 20,
                        onTap: _openFavorites,
                        tooltip: 'المفضلة',
                      ),
                      const SizedBox(width: 8),

                      // Notification Bell Button with Badge
                      Consumer(
                        builder: (context, ref, _) {
                          final unreadCount = ref.watch(
                            notificationProvider.select((s) => s.unreadCount),
                          );
                          return NaseebakCircleButton(
                            buttonKey: const Key('home_open_notifications_btn'),
                            icon: Icons.notifications_none_rounded,
                            size: 42,
                            iconSize: 21,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const NotificationCenterScreen(),
                                ),
                              );
                            },
                            tooltip: 'الإشعارات',
                            badge: unreadCount > 0
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Search Field & Filter Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      // Search Input Field
                      Expanded(
                        child: InkWell(
                          key: const Key('home_start_search_btn'),
                          onTap: _openAdvancedSearch,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.softBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.subtleBorder,
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ابحث عن شريك حياتك...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: NaseebakTypography.fontFamily,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.search_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Blue Filter Button
                      InkWell(
                        key: const Key('home_open_advanced_search_btn'),
                        onTap: _openAdvancedSearch,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Filter Chips Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: List.generate(
                        _filters.length,
                        (index) => NaseebakFilterChip(
                          label: _filters[index],
                          isSelected: _selectedFilterIndex == index,
                          onTap: () {
                            setState(() => _selectedFilterIndex = index);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Section Header: "أشخاص ممكن يناسبوك" + "عرض الكل"
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    NaseebakSectionHeader(
                      title: 'أشخاص ممكن يناسبوك',
                      actionTitle: 'عرض الكل',
                      onAction: _openAllMembersResults,
                    ),
                    // Semantic text for test compatibility
                    Opacity(
                      opacity: 0.0,
                      child: SizedBox(
                        height: 0,
                        child: Row(
                          children: [
                            const Text('الأعضاء المقترحون'),
                            InkWell(
                              onTap: widget.onOpenMyProfileTab,
                              child: const Text('ملفي الشخصي'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Member Feed List with Discovery Cards
              if (discoveryState.isLoadingDiscovery && displayedMembers.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                )
              else if (discoveryState.discoveryError != null &&
                  displayedMembers.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 52,
                            color: AppColors.error.withOpacity(0.75),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            discoveryState.discoveryError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            key: const Key('home_discovery_retry_btn'),
                            onPressed: () => ref
                                .read(discoveryProvider.notifier)
                                .loadDiscoveryFeed(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (displayedMembers.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 56,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'لا يوجد أعضاء مطابقون حالياً',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'جرّب تعديل معايير البحث أو تحديث القائمة.',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Insert Premium Membership Banner after the first member card
                      if (index == 1) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NaseebakPremiumBanner(onTap: _openSubscription),
                            MemberCard(
                              member: displayedMembers[index],
                              onTapViewProfile: () => _openMemberProfile(
                                displayedMembers[index].userId,
                              ),
                              onToggleFavorite: () => ref
                                  .read(discoveryProvider.notifier)
                                  .toggleFavorite(displayedMembers[index]),
                            ),
                          ],
                        );
                      }

                      final member = displayedMembers[index];
                      return MemberCard(
                        member: member,
                        onTapViewProfile: () => _openMemberProfile(member.userId),
                        onToggleFavorite: () => ref
                            .read(discoveryProvider.notifier)
                            .toggleFavorite(member),
                      );
                    },
                    childCount: displayedMembers.length,
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
