import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/core/design_system/naseebak_design_system.dart';
import 'package:naseebak_mobile/features/auth/presentation/screens/google_sign_in_screen.dart';
import 'package:naseebak_mobile/features/auth/presentation/screens/welcome_screen.dart';
import 'package:naseebak_mobile/features/discovery/data/models/member_profile_model.dart';
import 'package:naseebak_mobile/features/discovery/data/models/search_preferences_model.dart';
import 'package:naseebak_mobile/features/discovery/data/repositories/discovery_repository.dart';
import 'package:naseebak_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/advanced_search_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/discovery_home_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/member_profile_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/search_results_screen.dart';
import 'package:naseebak_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:naseebak_mobile/features/profile/presentation/providers/profile_registration_provider.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/profile_registration_coordinator_screen.dart';

class _ShowcaseDiscoveryRepository extends Fake implements DiscoveryRepository {
  static const List<MemberCardModel> showcaseMembers = [
    MemberCardModel(
      userId: 101,
      fullName: 'نورة العتيبي',
      gender: 'female',
      ageYears: 26,
      maritalStatus: 'single',
      educationLevel: 'bachelor',
      occupation: 'مهندسة معمارية',
      smokingStatus: 'non_smoker',
      nationality: 'سعودية',
      countryOfResidence: 'السعودية',
      region: 'الرياض',
      photoPrivacy: 'public',
      photoAuthorized: true,
      isFavorited: true,
    ),
    MemberCardModel(
      userId: 102,
      fullName: 'سارة المنصور',
      gender: 'female',
      ageYears: 28,
      maritalStatus: 'single',
      educationLevel: 'master',
      occupation: 'طبيبة أسنان',
      smokingStatus: 'non_smoker',
      nationality: 'مصرية',
      countryOfResidence: 'مصر',
      region: 'القاهرة',
      photoPrivacy: 'subscribers_only',
      photoAuthorized: false,
      isFavorited: false,
    ),
    MemberCardModel(
      userId: 103,
      fullName: 'مريم الهاشمي',
      gender: 'female',
      ageYears: 25,
      maritalStatus: 'single',
      educationLevel: 'bachelor',
      occupation: 'مصممة داخلية',
      smokingStatus: 'non_smoker',
      nationality: 'إماراتية',
      countryOfResidence: 'الإمارات',
      region: 'دبي',
      photoPrivacy: 'public',
      photoAuthorized: true,
      isFavorited: false,
    ),
  ];

  static const MemberProfileDetailModel showcaseDetail =
      MemberProfileDetailModel(
    userId: 101,
    fullName: 'نورة العتيبي',
    gender: 'female',
    ageYears: 26,
    maritalStatus: 'single',
    educationLevel: 'bachelor',
    occupation: 'مهندسة معمارية',
    smokingStatus: 'non_smoker',
    nationality: 'سعودية',
    countryOfResidence: 'السعودية',
    region: 'الرياض',
    photoPrivacy: 'public',
    photoAuthorized: true,
    isFavorited: true,
    zodiacSign: 'الميزان',
    previouslyMarried: false,
    hasChildren: false,
    childrenCount: 0,
    heightCm: 166,
    homeOwnership: 'family_home',
    hobbies: ['القراءة', 'السفر', 'الفنون والتصميم', 'المشي والطبيعة'],
    bio:
        'أقدّر الحياة الأسرية المستقرة والاحترام المتبادل، وأبحث عن شريك حياة جاد يشاركني القيم والطموح لبناء بيت هادئ ومتفاهم.',
    viewerHasActiveSubscription: true,
    viewerCanSendMatchRequests: true,
    viewerCanSendMessages: true,
    matchmakingButtonState: 'available',
  );

  @override
  Future<({
    List<MemberCardModel> suggestedMembers,
    SearchPreferencesModel savedPreferences,
  })> fetchDiscoveryFeed() async {
    return (
      suggestedMembers: showcaseMembers,
      savedPreferences: const SearchPreferencesModel(
        gender: 'female',
        minAge: 24,
        maxAge: 32,
        maritalStatuses: ['single'],
        educationLevel: 'bachelor',
        smokingStatus: 'non_smoker',
        countryOfResidence: 'السعودية',
        region: 'الرياض',
      ),
    );
  }

  @override
  Future<SearchPreferencesModel> fetchSavedSearchPreferences() async =>
      const SearchPreferencesModel(
        gender: 'female',
        minAge: 24,
        maxAge: 32,
        maritalStatuses: ['single'],
        educationLevel: 'bachelor',
        smokingStatus: 'non_smoker',
        countryOfResidence: 'السعودية',
        region: 'الرياض',
      );

  @override
  Future<PaginatedMembersResponse> searchMembers({
    required SearchPreferencesModel filters,
    required int page,
    int perPage = 20,
    bool savePreferences = false,
  }) async {
    return const PaginatedMembersResponse(
      members: showcaseMembers,
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 3,
      hasMorePages: false,
    );
  }

  @override
  Future<MemberProfileDetailModel> fetchMemberProfile(int targetUserId) async =>
      showcaseDetail;

  @override
  Future<List<MemberCardModel>> fetchFavorites() async => showcaseMembers;

  @override
  Future<Uint8List> fetchAuthorizedPhotoBytes(int photoId) async =>
      Uint8List(0);
}

class _FakeNotificationRepository extends Fake
    implements NotificationRepository {
  @override
  Future<int> fetchUnreadCount() async => 3;
}

Future<void> _loadBundledFontsForTest() async {
  final fontFiles = [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ];

  final ibmLoader = FontLoader('IBMPlexSansArabic');
  for (final path in fontFiles) {
    final bytes = await File(path).readAsBytes();
    ibmLoader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await ibmLoader.load();

  final sdkMaterialFont = File(
    r'C:\Users\w.i\.gemini\antigravity\scratch\tools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );
  if (await sdkMaterialFont.exists()) {
    final iconBytes = await sdkMaterialFont.readAsBytes();
    final iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(iconBytes).buffer)),
    );
    await iconLoader.load();
  }
}

Widget _buildFramedScreen({
  required GlobalKey boundaryKey,
  required Widget child,
  bool darkStatusBar = false,
  Widget? bottomNav,
}) {
  return RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: darkStatusBar ? AppColors.primaryNavy : AppColors.cardWhite,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '9:41',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: darkStatusBar
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_alt_rounded,
                        size: 14,
                        color: darkStatusBar
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.wifi_rounded,
                        size: 14,
                        color: darkStatusBar
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.battery_full_rounded,
                        size: 14,
                        color: darkStatusBar
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: child),
            if (bottomNav != null) bottomNav,
          ],
        ),
        ),
      ),
    ),
  );
}

Future<void> _captureGoldenPng({
  required WidgetTester tester,
  required GlobalKey boundaryKey,
  required String outputPath,
}) async {
  // Start loading any Image assets without awaiting inside runAsync
  for (final element in find.byType(Image).evaluate()) {
    final widget = element.widget as Image;
    precacheImage(widget.image, element);
  }
  await tester.pumpAndSettle();

  final previousAutoUpdate = autoUpdateGoldenFiles;
  autoUpdateGoldenFiles = true;
  try {
    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile(outputPath),
    );
  } finally {
    autoUpdateGoldenFiles = previousAutoUpdate;
  }
}

void main() {
  setUpAll(() async {
    await _loadBundledFontsForTest();
  });

  group('Batch 1 — Multi-Viewport Responsive Verification (360dp, 393dp, 430dp)',
      () {
    const widths = [360.0, 393.0, 430.0];

    for (final width in widths) {
      testWidgets(
        'All 7 Batch 1 Screens render with zero overflow at ${width.toInt()}dp width',
        (tester) async {
          tester.view.physicalSize = Size(width * 3.0, 840 * 3.0);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final fakeDiscovery = _ShowcaseDiscoveryRepository();
          final fakeNotifications = _FakeNotificationRepository();

          final screens = <Widget>[
            const WelcomeScreen(),
            const GoogleSignInScreen(),
            const ProfileRegistrationCoordinatorScreen(),
            DiscoveryHomeScreen(onOpenMyProfileTab: () {}),
            const AdvancedSearchScreen(),
            const SearchResultsScreen(),
            const MemberProfileScreen(memberUserId: 101),
          ];

          for (final screen in screens) {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  discoveryRepositoryProvider.overrideWithValue(fakeDiscovery),
                  notificationRepositoryProvider
                      .overrideWithValue(fakeNotifications),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: Directionality(
                    textDirection: TextDirection.rtl,
                    child: screen,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  });

  testWidgets(
    'Batch 1 — Capture Real Flutter Screenshots of All 7 Redesigned Astra Screens',
    (tester) async {
      tester.view.physicalSize = const Size(393 * 2.5, 852 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const outDir = '../../documentation/ui-redesign';
      final fakeDiscovery = _ShowcaseDiscoveryRepository();
      final fakeNotifications = _FakeNotificationRepository();

      // 1. Screen 1 — Splash / Welcome Screen
      final key1 = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: _buildFramedScreen(
            boundaryKey: key1,
            darkStatusBar: true,
            child: const WelcomeScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key1,
        outputPath: '$outDir/01_splash_welcome.png',
      );

      // 2. Screen 2 — Google Sign-In Screen
      final key2 = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: _buildFramedScreen(
            boundaryKey: key2,
            child: const GoogleSignInScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key2,
        outputPath: '$outDir/02_google_sign_in.png',
      );

      // 3. Screen 3 (Step 1..4) — Profile Registration 4-Step Flow
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final regNotifier = container.read(profileRegistrationProvider.notifier);
      regNotifier.updateDraft(
        container.read(profileRegistrationProvider).draft.copyWith(
              fullName: 'أحمد العتيبي',
              gender: 'male',
              dateOfBirth: DateTime(1994, 5, 14),
              maritalStatus: 'single',
              occupation: 'مهندس برمجيات',
              nationality: 'سعودي',
              countryOfResidence: 'السعودية',
              region: 'الرياض',
              hobbies: const ['القراءة', 'السفر', 'الرياضة'],
              bio:
                  'أبحث عن شريكة حياة تقدر الاحترام المتبادل والحياة الأسرية المستقرة.',
            ),
      );

      final key3Step1 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key3Step1,
            child: const ProfileRegistrationCoordinatorScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key3Step1,
        outputPath: '$outDir/03_registration_step1_personal.png',
      );

      regNotifier.validateAndAdvanceFromStep1();
      await tester.pumpAndSettle();
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key3Step1,
        outputPath: '$outDir/04_registration_step2_family_work.png',
      );

      regNotifier.validateAndAdvanceFromStep2();
      await tester.pumpAndSettle();
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key3Step1,
        outputPath: '$outDir/05_registration_step3_details_bio.png',
      );

      regNotifier.validateAndAdvanceFromStep3();
      await tester.pumpAndSettle();
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key3Step1,
        outputPath: '$outDir/06_registration_step4_preview.png',
      );

      // 4. Screen 4 — Discovery Home
      final discoveryContainer = ProviderContainer(
        overrides: [
          discoveryRepositoryProvider.overrideWithValue(fakeDiscovery),
          notificationRepositoryProvider.overrideWithValue(fakeNotifications),
        ],
      );
      addTearDown(discoveryContainer.dispose);
      await discoveryContainer
          .read(discoveryProvider.notifier)
          .loadDiscoveryFeed();
      await discoveryContainer
          .read(discoveryProvider.notifier)
          .loadSavedPreferences();
      await discoveryContainer
          .read(discoveryProvider.notifier)
          .executeSearch(savePreferences: false);

      final key4 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: discoveryContainer,
          child: _buildFramedScreen(
            boundaryKey: key4,
            darkStatusBar: true,
            bottomNav: NaseebakBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
            child: DiscoveryHomeScreen(onOpenMyProfileTab: () {}),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key4,
        outputPath: '$outDir/07_discovery_home.png',
      );

      // 5. Screen 5 — Advanced Search
      final key5 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: discoveryContainer,
          child: _buildFramedScreen(
            boundaryKey: key5,
            child: const AdvancedSearchScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key5,
        outputPath: '$outDir/08_advanced_search.png',
      );

      // 6. Screen 6 — Search Results
      final key6 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: discoveryContainer,
          child: _buildFramedScreen(
            boundaryKey: key6,
            child: const SearchResultsScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key6,
        outputPath: '$outDir/09_search_results.png',
      );

      // 7. Screen 7 — Member Profile
      final key7 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: discoveryContainer,
          child: _buildFramedScreen(
            boundaryKey: key7,
            child: const MemberProfileScreen(memberUserId: 101),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key7,
        outputPath: '$outDir/10_member_profile.png',
      );
    },
  );
}
