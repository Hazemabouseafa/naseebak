import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/discovery_provider.dart';
import 'advanced_search_screen.dart';
import 'member_profile_screen.dart';

/// Screen 03 (Batch 2A) — Favorites Screen (`المفضلة`)
/// تصميم Astra الفاخر لقائمة الأعضاء المفضلين مع البحث المحلي السريع،
/// بطاقات الأعضاء الملكية، وحالة الفراغ الزخرفية.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _localQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).loadFavorites();
    });
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
    final state = ref.watch(discoveryProvider);
    final filteredFavorites = _localQuery.trim().isEmpty
        ? state.favorites
        : state.favorites.where((m) {
            final q = _localQuery.trim();
            return m.fullName.contains(q) ||
                m.region.contains(q) ||
                m.occupation.contains(q);
          }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cardWhite,
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          centerTitle: true,
          leading: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: NaseebakCircleButton(
                icon: Icons.arrow_forward_rounded,
                size: 40,
                iconSize: 20,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'رجوع',
              ),
            ),
          ),
          title: const Text(
            'المفضلة',
            style: TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: NaseebakCircleButton(
                icon: Icons.refresh_rounded,
                size: 40,
                iconSize: 20,
                onTap: state.isLoadingFavorites
                    ? null
                    : () => ref.read(discoveryProvider.notifier).loadFavorites(),
                tooltip: 'تحديث',
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'الأشخاص الذين لفتوا انتباهك',
                style: TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isLoadingFavorites && state.favorites.isEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: 4,
                      itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: NaseebakLoadingSkeleton(
                          height: 140,
                          radius: 20,
                        ),
                      ),
                    );
                  }

                  if (state.favoritesError != null && state.favorites.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: NaseebakCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  size: 30,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                state.favoritesError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () {
                                  ref
                                      .read(discoveryProvider.notifier)
                                      .loadFavorites();
                                },
                                child: const Text(
                                  'إعادة المحاولة',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (state.favorites.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(26),
                        child: NaseebakEmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: 'قائمة المفضلة فارغة',
                          subtitle: 'لم تقم بإضافة أي أعضاء إلى المفضلة بعد.',
                          action: ElevatedButton.icon(
                            key: const Key('empty_favorites_explore_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AdvancedSearchScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.explore_outlined,
                              size: 19,
                              color: AppColors.goldAccent,
                            ),
                            label: const Text(
                              'استكشف الأعضاء',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      if (state.favorites.length > 2)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.subtleBorder,
                              ),
                              boxShadow: NaseebakSpacing.subtleCardShadow,
                            ),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText:
                                    'ابحث بالاسم أو المنطقة داخل المفضلة...',
                                hintStyle: TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: AppColors.primaryNavy,
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (val) =>
                                  setState(() => _localQuery = val),
                            ),
                          ),
                        ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: filteredFavorites.length,
                          itemBuilder: (context, index) {
                            final member = filteredFavorites[index];
                            return MemberCard(
                              member: member,
                              isGridMode: true,
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
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
