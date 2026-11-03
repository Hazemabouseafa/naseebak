import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/discovery_provider.dart';
import 'advanced_search_screen.dart';
import 'member_profile_screen.dart';

/// 09. Search Results Screen (نتائج البحث — تصميم Astra)
/// تعرض نتائج البحث المفلترة على خادم PostgreSQL مع:
/// - شرائح الفلاتر النشطة القابلة للإزالة (Removable Chips)
/// - خيارات الترتيب المحددة مسبقاً (الأحدث انضماماً، العمر تصاعدياً، العمر تنازلياً)
/// - التحميل التدريجي (Pagination: 20 عضو في الصفحة) مع بطاقات Astra الفاخرة.
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
      backgroundColor: AppColors.softBackground,
      appBar: NaseebakAppBar(
        title: 'نتائج البحث',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            key: const Key('results_modify_filters_btn'),
            tooltip: 'تعديل البحث',
            onPressed: _openFilterEditor,
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.primaryNavy,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Summary & Sort Selector Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                border: const Border(
                  bottom: BorderSide(color: AppColors.subtleBorder),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNavy.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${state.totalMatching} ملفًا مطابقًا لمعاييرك',
                          style: const TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
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
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.creamHighlight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.goldAccent.withOpacity(0.5),
                            ),
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
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 17,
                                color: AppColors.primaryNavy,
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
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryNavy,
                              ),
                              backgroundColor: AppColors.softBackground,
                              deleteIconColor: AppColors.primaryNavy,
                              side: const BorderSide(
                                color: AppColors.subtleBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
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
                            color: AppColors.primaryNavy,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'جارٍ البحث عن الأعضاء المطابقين...',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 13.5,
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
                      child: Center(
                        child: NaseebakEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: state.searchError!,
                          subtitle:
                              'حدث تعذر أثناء تحميل النتائج، يرجى المحاولة مرة أخرى.',
                          actionButton: NaseebakPrimaryButton(
                            label: 'إعادة المحاولة',
                            onPressed: () {
                              ref
                                  .read(discoveryProvider.notifier)
                                  .executeSearch(savePreferences: false);
                            },
                          ),
                        ),
                      ),
                    );
                  }

                  if (state.searchResults.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: NaseebakEmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'لم نجد أعضاء مطابقين لمعايير البحث الحالية.',
                          subtitle:
                              'جرّب تخفيف بعض القيود مثل الفئة العمرية أو المنطقة للوصول إلى نتائج أوسع.',
                          actionButton: NaseebakPrimaryButton(
                            buttonKey:
                                const Key('empty_results_modify_search_btn'),
                            icon: const Icon(
                              Icons.tune_rounded,
                              size: 19,
                              color: AppColors.goldAccent,
                            ),
                            label: 'تعديل البحث',
                            onPressed: _openFilterEditor,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                    itemCount: state.searchResults.length + 1,
                    itemBuilder: (context, index) {
                      if (index < state.searchResults.length) {
                        final member = state.searchResults[index];
                        return Padding(
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
                        );
                      }

                      // Footer: Pagination Loading / Pagination Error / End-of-Results Notice
                      if (state.isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryNavy,
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  state.paginationError!,
                                  style: const TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
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
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.subtleBorder),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 17,
                                color: AppColors.primaryNavy,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'تم عرض جميع الملفات المطابقة والمسموح بنشرها.',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
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
