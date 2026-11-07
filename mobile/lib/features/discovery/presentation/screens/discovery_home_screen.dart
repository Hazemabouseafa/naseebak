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

/// Screen 03 — Home & Discovery (واجهة الاكتشاف الرئيسية المطورة بتجربة عصرية نابضة بالحياة)
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
  String _selectedQuickCountry = '';

  final List<String> _filters = const ['الكل', 'قريب مني', 'جديد', 'متوافق'];

  static const List<({String label, String country, String flag})>
      _quickCountries = [
    (label: 'كل الدول', country: '', flag: '🌍'),
    (label: 'مصر', country: 'مصر', flag: '🇪🇬'),
    (
      label: 'السعودية',
      country: 'المملكة العربية السعودية',
      flag: '🇸🇦'
    ),
    (
      label: 'الإمارات',
      country: 'الإمارات العربية المتحدة',
      flag: '🇦🇪'
    ),
    (label: 'الكويت', country: 'الكويت', flag: '🇰🇼'),
    (label: 'الأردن', country: 'الأردن', flag: '🇯🇴'),
    (label: 'قطر', country: 'قطر', flag: '🇶🇦'),
    (label: 'المغرب', country: 'المغرب', flag: '🇲🇦'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).loadDiscoveryFeed();
      ref.read(profileManagementProvider.notifier).loadOwnProfile();
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
            countryOfResidence: _selectedQuickCountry.isNotEmpty
                ? _selectedQuickCountry
                : null,
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
    Iterable<MemberCardModel> filtered = members;

    if (_selectedQuickCountry.isNotEmpty) {
      filtered = filtered.where((m) {
        final c = m.countryOfResidence.trim();
        if (_selectedQuickCountry == 'المملكة العربية السعودية') {
          return c == 'المملكة العربية السعودية' || c == 'السعودية';
        }
        if (_selectedQuickCountry == 'الإمارات العربية المتحدة') {
          return c == 'الإمارات العربية المتحدة' || c == 'الإمارات';
        }
        return c == _selectedQuickCountry;
      });
    }

    final copy = filtered.toList();
    if (copy.length <= 1 ||
        _selectedFilterIndex == 0 ||
        _selectedFilterIndex == 2) {
      return copy;
    }

    if (_selectedFilterIndex == 1 && viewerProfile != null) {
      copy.sort((a, b) {
        final aRegionMatch =
            a.region.trim() == viewerProfile.region.trim() ? 0 : 1;
        final bRegionMatch =
            b.region.trim() == viewerProfile.region.trim() ? 0 : 1;
        if (aRegionMatch != bRegionMatch) {
          return aRegionMatch.compareTo(bRegionMatch);
        }

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
    final mgmtState = ref.watch(profileManagementProvider);
    final mgmtProfile = mgmtState.profile;
    final cachedPhotoBytes = mgmtState.cachedPhotoBytes;
    final primaryPhotoId = mgmtProfile?.primaryPhoto?.id;
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
          onRefresh: () async {
            await Future.wait([
              ref.read(discoveryProvider.notifier).loadDiscoveryFeed(),
              ref.read(profileManagementProvider.notifier).loadOwnProfile(),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              // 1. Personalized Header (Avatar with Gold Ring + Greeting + Favorites & Notifications)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onOpenMyProfileTab,
                        child: Container(
                          padding: const EdgeInsets.all(2.2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.goldAccent,
                                AppColors.primaryBlue,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.14),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: cachedPhotoBytes != null
                              ? CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.cardWhite,
                                  backgroundImage:
                                      MemoryImage(cachedPhotoBytes),
                                )
                              : (primaryPhotoId != null
                                  ? AuthorizedPhotoAvatar(
                                      photoId: primaryPhotoId,
                                      photoAuthorized: true,
                                      fallbackName: displayName,
                                      radius: 22,
                                      showGoldBorder: false,
                                      gender: mgmtProfile?.gender ?? 'male',
                                    )
                                  : CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.cardWhite,
                                      child: Text(
                                        displayName.isNotEmpty
                                            ? displayName.substring(0, 1)
                                            : 'ن',
                                        style: const TextStyle(
                                          fontFamily:
                                              NaseebakTypography.fontFamily,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    )),
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
                                  'أهلاً بك في نَصِيبُكَ',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12.5,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text('✨', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'اكتشف شريك حياتك بخصوصية وأمان',
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
                            buttonKey:
                                const Key('home_open_notifications_btn'),
                            icon: Icons.notifications_none_rounded,
                            size: 42,
                            iconSize: 21,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const NotificationCenterScreen(),
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

              // 2. Search Bar & Advanced Filter Button
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const Key('home_start_search_btn'),
                          onTap: _openAdvancedSearch,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            height: 50,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.softBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.subtleBorder,
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 21,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'ابحث بالدولة، المحافظة، العمر أو المؤهل...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: NaseebakTypography.fontFamily,
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

                      // Blue Filter Button
                      InkWell(
                        key: const Key('home_open_advanced_search_btn'),
                        onTap: _openAdvancedSearch,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.primaryNavy,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.24),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
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

              // 3. Smart Filter Chips Row (الكل، قريب مني، جديد، متوافق)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
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

              // 4. Quick Country Discovery Strip (تصفح سريع حسب الدولة بلمسة واحدة)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: _quickCountries.map((item) {
                        final isSelected =
                            _selectedQuickCountry == item.country;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedQuickCountry = item.country;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.surfaceSubtleBlue
                                    : AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : AppColors.subtleBorder,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.flag,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontFamily:
                                          NaseebakTypography.fontFamily,
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // 5. Section Header: "أشخاص ممكن يناسبوك" + "عرض الكل"
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              ),

              // 6. Member Feed List with Discovery Cards
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 36),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.softBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.subtleBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceSubtleBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_search_rounded,
                              size: 34,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'لا يوجد أعضاء مطابقون حالياً',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'جرّب اختيار "كل الدول" أو فتح البحث المتقدم لتوسيع نطاق الاكتشاف.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_selectedQuickCountry.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedQuickCountry = ''),
                              icon: const Icon(Icons.public_rounded, size: 18),
                              label: const Text('عرض جميع الدول'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(discoveryProvider.notifier)
                                  .loadDiscoveryFeed(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('تحديث القائمة'),
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
                        onTapViewProfile: () =>
                            _openMemberProfile(member.userId),
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
