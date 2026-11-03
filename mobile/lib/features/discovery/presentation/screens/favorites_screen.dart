import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/discovery_provider.dart';
import '../widgets/member_card.dart';
import 'advanced_search_screen.dart';
import 'member_profile_screen.dart';

/// 16. Favorites Screen (المفضلة)
/// تتيح للعضو عرض الأعضاء الذين قام بحفظهم في المفضلة، البحث المحلي السريع داخل المفضلة،
/// فتح الملف الشخصي لأي عضو، أو إزالته من المفضلة.
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

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'رجوع',
        ),
        title: const Text('المفضلة'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: state.isLoadingFavorites
                ? null
                : () {
                    ref.read(discoveryProvider.notifier).loadFavorites();
                  },
            icon: const Icon(Icons.refresh_rounded, size: 20),
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
            if (state.isLoadingFavorites && state.favorites.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              );
            }

            if (state.favoritesError != null && state.favorites.isEmpty) {
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
                      state.favoritesError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(discoveryProvider.notifier).loadFavorites();
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            if (state.favorites.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 52,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'لم تقم بإضافة أي أعضاء إلى المفضلة بعد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يمكنك حفظ الملفات الشخصية التي تثير اهتمامك أثناء التصفح للرجوع إليها بسهولة في أي وقت.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      key: const Key('empty_favorites_explore_btn'),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const AdvancedSearchScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.explore_outlined, size: 19),
                      label: const Text('استكشف الأعضاء'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.favorites.length > 2)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'ابحث بالاسم أو المنطقة داخل المفضلة...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                      onChanged: (val) => setState(() => _localQuery = val),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    itemCount: filteredFavorites.length,
                    itemBuilder: (context, index) {
                      final member = filteredFavorites[index];
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
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
