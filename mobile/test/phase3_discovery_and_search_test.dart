import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/features/discovery/data/models/member_profile_model.dart';
import 'package:naseebak_mobile/features/discovery/data/models/search_preferences_model.dart';
import 'package:naseebak_mobile/features/discovery/data/repositories/discovery_repository.dart';
import 'package:naseebak_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/advanced_search_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/favorites_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/search_results_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/widgets/member_card.dart';

class _FakeDiscoveryRepository extends Fake implements DiscoveryRepository {
  @override
  Future<List<MemberCardModel>> fetchFavorites() async => const [];
}

void main() {
  group('Phase 3 — Discovery, Advanced Search, Member Cards & Favorites Tests', () {
    test('SearchPreferencesModel validates age >= 18 and minAge <= maxAge and builds active filter chips', () {
      const invalidUnderage = SearchPreferencesModel(minAge: 16, maxAge: 30);
      expect(invalidUnderage.validate(), contains('18'));

      const invalidRange = SearchPreferencesModel(minAge: 45, maxAge: 30);
      expect(invalidRange.validate(), isNotNull);

      const validFilters = SearchPreferencesModel(
        gender: 'male',
        minAge: 30,
        maxAge: 45,
        maritalStatuses: ['single', 'divorced'],
        educationLevel: 'bachelor',
        smokingStatus: 'non_smoker',
        occupation: 'مهندس',
        nationality: 'مصري',
      );
      expect(validFilters.validate(), isNull);
      expect(validFilters.activeFilterChips.length, greaterThanOrEqualTo(6));
    });

    testWidgets('MemberCard renders Arabic RTL member details and favorite button',
        (WidgetTester tester) async {
      bool viewProfileTapped = false;
      bool favoriteTapped = false;

      const sampleMember = MemberCardModel(
        userId: 42,
        fullName: 'أحمد محمود',
        gender: 'male',
        ageYears: 38,
        maritalStatus: 'single',
        educationLevel: 'bachelor',
        occupation: 'مهندس مدني',
        smokingStatus: 'non_smoker',
        nationality: 'مصري',
        countryOfResidence: 'مصر',
        region: 'القاهرة',
        photoPrivacy: 'subscribers_only',
        photoAuthorized: false,
        isFavorited: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: Scaffold(
                body: MemberCard(
                  member: sampleMember,
                  onTapViewProfile: () => viewProfileTapped = true,
                  onToggleFavorite: () => favoriteTapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('أحمد محمود • 38 سنة'), findsOneWidget);
      expect(find.text('أعزب · القاهرة، مصر'), findsOneWidget);
      expect(find.text('عرض الملف'), findsOneWidget);
      expect(find.text('الصورة بإذن صاحب الملف'), findsOneWidget);

      await tester.tap(find.text('عرض الملف'));
      expect(viewProfileTapped, isTrue);

      await tester.tap(find.byKey(const Key('favorite_toggle_btn_42')));
      expect(favoriteTapped, isTrue);
    });

    testWidgets('Screen 08 (AdvancedSearchScreen), Screen 09 (SearchResultsScreen empty state) & Screen 16 (FavoritesScreen empty state) render accurately in RTL',
        (WidgetTester tester) async {
      final fakeRepo = _FakeDiscoveryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: AdvancedSearchScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مواصفات شريك حياتك'), findsOneWidget);
      expect(find.text('عرض النتائج'), findsOneWidget);
      expect(find.text('إعادة تعيين'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: SearchResultsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نتائج البحث'), findsOneWidget);
      expect(find.text('لم نجد أعضاء مطابقين لمعايير البحث الحالية.'), findsOneWidget);
      expect(find.text('تعديل البحث'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: FavoritesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المفضلة'), findsOneWidget);
      expect(find.text('لم تقم بإضافة أي أعضاء إلى المفضلة بعد.'), findsOneWidget);
      expect(find.text('استكشف الأعضاء'), findsOneWidget);
    });
  });
}
