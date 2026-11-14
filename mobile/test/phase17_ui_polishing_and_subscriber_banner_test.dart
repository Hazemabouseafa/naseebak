import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:naseebak_mobile/core/design_system/naseebak_design_system.dart';
import 'package:naseebak_mobile/features/discovery/data/models/member_profile_model.dart';
import 'package:naseebak_mobile/features/discovery/data/models/search_preferences_model.dart';
import 'package:naseebak_mobile/features/discovery/data/repositories/discovery_repository.dart';
import 'package:naseebak_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/discovery_home_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/member_profile_screen.dart';
import 'package:naseebak_mobile/features/messaging/data/models/conversation_model.dart';
import 'package:naseebak_mobile/features/messaging/data/repositories/messaging_repository.dart';
import 'package:naseebak_mobile/features/messaging/data/services/realtime_messaging_service.dart';
import 'package:naseebak_mobile/features/messaging/presentation/screens/conversations_screen.dart';
import 'package:naseebak_mobile/features/profile/data/models/profile_model.dart';
import 'package:naseebak_mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:naseebak_mobile/features/profile/presentation/providers/profile_management_provider.dart';
import 'package:naseebak_mobile/features/subscription/data/models/subscription_model.dart';
import 'package:naseebak_mobile/features/subscription/data/repositories/subscription_repository.dart';
import 'package:naseebak_mobile/features/subscription/data/services/google_play_billing_service.dart';
import 'package:naseebak_mobile/features/subscription/presentation/providers/subscription_provider.dart';

class _FakeBillingClientService extends GooglePlayBillingClientService {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<StoreProductPricingModel?> querySubscriptionProduct(
    String productId,
  ) async =>
      null;

  @override
  Future<void> completePurchaseIfNeeded(PurchaseDetails purchase) async {}
}

class _FakeMessagingRepo extends Fake implements MessagingRepository {
  List<ConversationSummaryModel> convs = [];

  @override
  Future<({
    List<ConversationSummaryModel> conversations,
    int currentPage,
    bool hasMorePages,
    bool viewerHasActiveSubscription,
  })> fetchConversations({int page = 1, int perPage = 20}) async {
    return (
      conversations: convs,
      currentPage: 1,
      hasMorePages: false,
      viewerHasActiveSubscription: false,
    );
  }
}

class _FakeRealtimeService extends Fake implements RealtimeMessagingService {
  @override
  RealtimeConnectionState get connectionState =>
      RealtimeConnectionState.connected;

  @override
  Stream<RealtimeConnectionState> get connectionStateStream =>
      Stream.value(RealtimeConnectionState.connected);

  @override
  Stream<ReverbEventMessage> get eventsStream => const Stream.empty();

  @override
  Stream<void> get onReconnectedStream => const Stream.empty();
}

class _FakeSubscriptionRepo extends Fake implements SubscriptionRepository {
  SubscriptionOverviewResponse overview;
  _FakeSubscriptionRepo({required this.overview});

  @override
  Future<SubscriptionOverviewResponse> fetchSubscriptionOverview() async {
    return overview;
  }

  @override
  Future<List<SubscriptionPlanModel>> fetchPlans() async {
    return const [
      SubscriptionPlanModel(
        id: 1,
        code: 'monthly_membership',
        nameAr: 'العضوية الشهرية — نصيبك',
        durationDays: 30,
        googlePlayProductId: 'monthly',
        featuresAr: ['ميزات متقدمة'],
        renewalTermsAr: '',
        cancellationTermsAr: '',
      ),
    ];
  }

  @override
  Future<List<SubscriptionRecordModel>> fetchSubscriptionHistory() async => const [];
}

class _FakeDiscoveryRepo extends Fake implements DiscoveryRepository {
  // Valid 1x1 transparent PNG bytes for testing Image.memory rendering
  static final Uint8List validPngBytes = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<({List<MemberCardModel> suggestedMembers, SearchPreferencesModel savedPreferences})>
      fetchDiscoveryFeed() async => (
            suggestedMembers: const <MemberCardModel>[],
            savedPreferences: const SearchPreferencesModel(
              gender: 'female',
              minAge: 18,
              maxAge: 60,
            ),
          );

  @override
  Future<SearchPreferencesModel> fetchSavedSearchPreferences() async =>
      const SearchPreferencesModel(
        gender: 'female',
        minAge: 18,
        maxAge: 60,
      );

  @override
  Future<MemberProfileDetailModel> fetchMemberProfile(int targetUserId) async {
    return MemberProfileDetailModel(
      userId: targetUserId,
      fullName: 'مريم أحمد',
      gender: 'female',
      ageYears: 27,
      maritalStatus: 'single',
      educationLevel: 'bachelor',
      occupation: 'مهندسة برمجيات',
      smokingStatus: 'non_smoker',
      nationality: 'مصرية',
      countryOfResidence: 'مصر',
      region: 'القاهرة',
      photoPrivacy: 'public',
      photoAuthorized: true,
      primaryPhotoId: 501,
      primaryPhotoUrl: 'https://naseebak-api.hazem.my/api/v1/profile/photos/501/stream',
      isFavorited: false,
      zodiacSign: 'الجوزاء',
      previouslyMarried: false,
      hasChildren: false,
      childrenCount: 0,
      heightCm: 165,
      homeOwnership: 'owned',
      hobbies: const ['القراءة', 'السفر'],
      bio: 'أبحث عن شريك حياة ملتزم وطموح.',
      matchmakingButtonState: 'available',
      viewerHasActiveSubscription: true,
      viewerCanSendMatchRequests: true,
      viewerCanSendMessages: true,
    );
  }

  @override
  Future<Uint8List> fetchAuthorizedPhotoBytes(int photoId) async {
    return validPngBytes;
  }
}

class _FakeProfileRepo extends Fake implements ProfileRepository {
  @override
  Future<ProfileResponseBundle> fetchOwnProfile() async {
    return const ProfileResponseBundle(
      profileCompleted: false,
      completionPercentage: 0,
      profile: null,
      isVisible: true,
      photoPrivacy: 'blurred',
    );
  }
}

void main() {
  group('Phase 17 — UI Polishing, Typography, Buttons & Subscription Banner Tests', () {
    test('1. AppTheme typography is set to Cairo with IBM Plex Sans fallback', () {
      expect(AppTheme.fontFamily, 'Cairo');
      expect(AppTheme.fontFamilyFallback, contains('IBMPlexSansArabic'));
      expect(NaseebakTypography.fontFamily, 'Cairo');
    });

    testWidgets('2. NaseebakPrimaryButton renders with gradient, radius 18, and custom label', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NaseebakPrimaryButton(
                label: 'تأكيد التسجيل',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('تأكيد التسجيل'), findsOneWidget);
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18));
      expect(decoration.gradient, isNotNull);

      await tester.tap(find.text('تأكيد التسجيل'));
      expect(tapped, isTrue);
    });

    testWidgets('3. NaseebakSecondaryButton renders with white background, radius 18, and border', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NaseebakSecondaryButton(
                label: 'إلغاء الأمر',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('إلغاء الأمر'), findsOneWidget);
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(OutlinedButton),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18));

      await tester.tap(find.text('إلغاء الأمر'));
      expect(tapped, isTrue);
    });

    testWidgets('4. ConversationsScreen displays upgrade banner for unsubscribed users', (tester) async {
      final fakeSub = _FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );
      final fakeMsg = _FakeMessagingRepo();
      final fakeRt = _FakeRealtimeService();
      final fakeBilling = _FakeBillingClientService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(fakeSub),
            googlePlayBillingServiceProvider.overrideWithValue(fakeBilling),
            messagingRepositoryProvider.overrideWithValue(fakeMsg),
            realtimeMessagingServiceProvider.overrideWithValue(fakeRt),
          ],
          child: const MaterialApp(
            home: ConversationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner should be visible for free/unsubscribed user
      expect(find.text('رقّ حسابك لفتح ميزات الدردشة المتقدمة'), findsOneWidget);
      expect(find.text('ترقية'), findsOneWidget);
    });

    testWidgets('5. ConversationsScreen HIDES upgrade banner when user has active subscription', (tester) async {
      final fakeSub = _FakeSubscriptionRepo(
        overview: const SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel(
            hasActiveSubscription: true,
            subscriptionStatus: 'active',
            paymentChannel: 'manual_admin',
            currentPeriodEnd: null,
            autoRenewing: false,
            canSendMatchRequests: true,
            canSendMessages: true,
          ),
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );
      final fakeMsg = _FakeMessagingRepo();
      final fakeRt = _FakeRealtimeService();
      final fakeBilling = _FakeBillingClientService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(fakeSub),
            googlePlayBillingServiceProvider.overrideWithValue(fakeBilling),
            messagingRepositoryProvider.overrideWithValue(fakeMsg),
            realtimeMessagingServiceProvider.overrideWithValue(fakeRt),
          ],
          child: const MaterialApp(
            home: ConversationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner MUST be hidden for subscribed user!
      expect(find.text('رقّ حسابك لفتح ميزات الدردشة المتقدمة'), findsNothing);
      expect(find.text('ترقية'), findsNothing);
    });

    testWidgets('6. DiscoveryHomeScreen Section Header has 20px horizontal padding preventing overflow', (tester) async {
      final fakeDisc = _FakeDiscoveryRepo();
      final fakeProf = _FakeProfileRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(fakeDisc),
            profileRepositoryProvider.overrideWithValue(fakeProf),
          ],
          child: MaterialApp(
            home: DiscoveryHomeScreen(
              onOpenMyProfileTab: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أشخاص ممكن يناسبوك'), findsOneWidget);
      expect(find.text('عرض الكل'), findsOneWidget);

      // Verify NaseebakSectionHeader is wrapped inside a Padding with horizontal: 20
      final paddingFinder = find.ancestor(
        of: find.byType(NaseebakSectionHeader),
        matching: find.byType(Padding),
      );
      expect(paddingFinder, findsWidgets);

      final paddingWidget = tester.widget<Padding>(paddingFinder.first);
      expect(paddingWidget.padding, const EdgeInsets.symmetric(horizontal: 20, vertical: 8));
    });

    testWidgets('7. MemberProfileScreen displays profile owner photo inside hero photo container when photoAuthorized is true', (tester) async {
      final fakeDisc = _FakeDiscoveryRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(fakeDisc),
          ],
          child: const MaterialApp(
            home: MemberProfileScreen(memberUserId: 77),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify profile owner name & hero photo container are displayed
      expect(find.textContaining('مريم أحمد'), findsOneWidget);
      expect(find.byKey(const Key('member_profile_hero_photo_container')), findsOneWidget);
      expect(find.byKey(const Key('member_profile_hero_photo_77')), findsOneWidget);

      // Verify the actual Image widget is rendered inside the hero photo container
      final heroImageFinder = find.descendant(
        of: find.byKey(const Key('member_profile_hero_photo_container')),
        matching: find.byType(Image),
      );
      expect(heroImageFinder, findsOneWidget);
    });
  });
}
