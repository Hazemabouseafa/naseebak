import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/discovery_provider.dart';
import '../widgets/member_card.dart';
import 'advanced_search_screen.dart';
import 'member_profile_screen.dart';

/// 09. Search Results Screen (نتائج البحث)
/// تعرض نتائج البحث المفلترة على خادم PostgreSQL مع:
/// - شرائح الفلاتر النشطة القابلة للإزالة (Removable Chips)
/// - خيارات الترتيب المحددة مسبقاً (الأحدث انضماماً، العمر تصاعدياً، العمر تنازلياً)
/// - التحميل التدريجي (Pagination: 20 عضو في الصفحة) مع منع الطلبات المكررة
/// - حالات التحميل الأولي، تحميل الصفحات، عدم وجود نتائج، خطأ الاتصال، ونهاية النتائج.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 180) {
      ref.read(discoveryProvider.notifier).loadNextSearchPage();
    }
  }

  void _openFilterEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdvancedSearchScreen(openedFromResults: true),
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
    final state = ref.watch(discoveryProvider);
    final activeChips = state.filters.activeFilterChips;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'رجوع',
        ),
        title: const Text('نتائج البحث'),
        actions: [
          IconButton(
            key: const Key('results_modify_filters_btn'),
            tooltip: 'تعديل البحث',
            onPressed: _openFilterEditor,
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Summary & Sort Selector Bar (Matching Mockup Screen 07)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              color: AppColors.backgroundPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${state.totalMatching} ملفًا مطابقًا لمعاييرك',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      PopupMenuButton<String>(
                        key: const Key('search_results_sort_menu'),
                        initialValue: state.filters.sort,
                        onSelected: (sortValue) {
                          ref
                              .read(discoveryProvider.notifier)
                              .changeSortOrder(sortValue);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'newest',
                            child: Text('الأحدث انضمامًا'),
                          ),
                          PopupMenuItem(
                            value: 'age_asc',
                            child: Text('العمر: من الأصغر للأكبر'),
                          ),
                          PopupMenuItem(
                            value: 'age_desc',
                            child: Text('العمر: من الأكبر للأصغر'),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtleBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                switch (state.filters.sort) {
                                  'age_asc' => 'العمر تصاعديًا',
                                  'age_desc' => 'العمر تنازليًا',
                                  _ => 'الأحدث انضمامًا',
                                },
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Removable Active Search Filter Chips
                  if (activeChips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: activeChips.map((chip) {
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: InputChip(
                              key: Key('active_filter_chip_${chip.key}'),
                              label: Text(chip.labelAr),
                              labelStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                              backgroundColor: AppColors.surfaceSubtleBlue,
                              deleteIconColor: AppColors.primaryBlue,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onDeleted: () {
                                ref
                                    .read(discoveryProvider.notifier)
                                    .removeFilterChipAndRefresh(chip.key);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),

            // 3. Results Body: Initial Loading / Error / Empty / Paginated List
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isSearchingInitial) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primaryBlue,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'جارٍ البحث عن الأعضاء المطابقين...',
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

                  if (state.searchError != null &&
                      state.searchResults.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 46,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.searchError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(discoveryProvider.notifier)
                                  .executeSearch(savePreferences: false);
                            },
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state.searchResults.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.person_search_outlined,
                            size: 52,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'لم نجد أعضاء مطابقين لمعايير البحث الحالية.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'جرّب تخفيف بعض القيود مثل الفئة العمرية أو المنطقة للوصول إلى نتائج أوسع.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            key: const Key('empty_results_modify_search_btn'),
                            onPressed: _openFilterEditor,
                            icon: const Icon(Icons.tune_rounded, size: 19),
                            label: const Text('تعديل البحث'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    itemCount: state.searchResults.length + 1,
                    itemBuilder: (context, index) {
                      if (index < state.searchResults.length) {
                        final member = state.searchResults[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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
                        );
                      }

                      // Footer: Pagination Loading / Pagination Error / End-of-Results Notice
                      if (state.isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        );
                      }

                      if (state.paginationError != null) {
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  state.paginationError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(discoveryProvider.notifier)
                                      .loadNextSearchPage();
                                },
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!state.hasMorePages) {
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تم عرض جميع الملفات المطابقة والمسموح بنشرها.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
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
