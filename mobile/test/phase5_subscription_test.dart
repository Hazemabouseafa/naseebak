import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:naseebak_mobile/core/network/api_client.dart';
import 'package:naseebak_mobile/core/storage/secure_session_storage.dart';
import 'package:naseebak_mobile/core/theme/app_theme.dart';
import 'package:naseebak_mobile/features/subscription/data/models/subscription_model.dart';
import 'package:naseebak_mobile/features/subscription/data/repositories/subscription_repository.dart';
import 'package:naseebak_mobile/features/subscription/data/services/google_play_billing_service.dart';
import 'package:naseebak_mobile/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:naseebak_mobile/features/subscription/presentation/screens/my_subscription_screen.dart';
import 'package:naseebak_mobile/features/subscription/presentation/screens/subscription_screen.dart';

class FakeSubscriptionRepository extends SubscriptionRepository {
  SubscriptionOverviewResponse overviewResponse;
  List<SubscriptionPlanModel> plansResponse;
  List<SubscriptionRecordModel> historyResponse;
  bool throwOnVerify;

  FakeSubscriptionRepository({
    required this.overviewResponse,
    required this.plansResponse,
    this.historyResponse = const [],
    this.throwOnVerify = false,
  }) : super(
          apiClient: ApiClient(sessionStorage: const SecureSessionStorage()),
        );

  @override
  Future<SubscriptionOverviewResponse> fetchSubscriptionOverview() async {
    return overviewResponse;
  }

  @override
  Future<List<SubscriptionPlanModel>> fetchPlans() async {
    return plansResponse;
  }

  @override
  Future<List<SubscriptionRecordModel>> fetchSubscriptionHistory() async {
    return historyResponse;
  }

  @override
  Future<SubscriptionOverviewResponse> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    String? packageName,
  }) async {
    if (throwOnVerify) {
      throw Exception('تعذر التحقق من صلاحية عملية الشراء لدى متجر Google Play.');
    }
    return overviewResponse;
  }
}

class FakeGooglePlayBillingClientService extends GooglePlayBillingClientService {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  StoreProductPricingModel? mockPricing;
  bool shouldThrowOnPurchase;

  FakeGooglePlayBillingClientService({
    this.mockPricing,
    this.shouldThrowOnPurchase = false,
  });

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<StoreProductPricingModel?> querySubscriptionProduct(
    String productId,
  ) async {
    return mockPricing;
  }

  @override
  Future<bool> startSubscriptionPurchase({
    required String productId,
    String? obfuscatedAccountId,
  }) async {
    if (shouldThrowOnPurchase) {
      throw Exception('فشل الاتصال بخدمة الفوترة في متجر Google Play.');
    }
    return true;
  }

  @override
  Future<void> completePurchaseIfNeeded(PurchaseDetails purchase) async {}
}

Widget _wrapRtlTestApp(
  Widget child, {
  required FakeSubscriptionRepository fakeRepo,
  required FakeGooglePlayBillingClientService fakeBilling,
}) {
  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(fakeRepo),
      googlePlayBillingServiceProvider.overrideWithValue(fakeBilling),
      purchaseVerificationServiceProvider.overrideWithValue(
        PurchaseVerificationService(repository: fakeRepo),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, widget) => Directionality(
        textDirection: TextDirection.rtl,
        child: widget ?? const SizedBox.shrink(),
      ),
      home: child,
    ),
  );
}

void main() {
  const defaultPlan = SubscriptionPlanModel(
    id: 1,
    code: 'monthly_membership',
    nameAr: 'العضوية الشهرية — نصيبك',
    durationDays: 30,
    googlePlayProductId: 'naseebak_monthly_membership',
    featuresAr: [
      'إرسال طلبات التعارف',
      'التواصل بعد الموافقة',
      'إرسال الرسائل الخاصة',
    ],
    renewalTermsAr: 'يتجدد الاشتراك شهرياً عبر Google Play.',
    cancellationTermsAr: 'يمكنك الإلغاء في أي وقت من إعدادات Google Play.',
  );

  const defaultStorePrice = StoreProductPricingModel(
    productId: 'naseebak_monthly_membership',
    title: 'العضوية الشهرية — نصيبك',
    description: 'اشتراك شهري',
    formattedPrice: '250.00 ج.م',
    rawPrice: 250.0,
    currencyCode: 'EGP',
  );

  testWidgets(
      '1 & 8. SubscriptionScreen renders Arabic RTL content, benefits, and localized Google Play price',
      (WidgetTester tester) async {
    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.freeDefault(),
        googlePlayManageUrl:
            'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
    );
    final billing = FakeGooglePlayBillingClientService(
      mockPricing: defaultStorePrice,
    );

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const SubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(SubscriptionScreen))),
        TextDirection.rtl);
    expect(find.text('الاشتراك الشهري'), findsOneWidget);
    expect(find.text('فعّل اشتراكك وابدأ التواصل'), findsOneWidget);
    expect(
      find.text(
        'اشترك شهريًا لإرسال طلبات التعارف والتواصل مع الأعضاء بعد قبول الطلب.',
      ),
      findsOneWidget,
    );
    expect(find.text('إرسال طلبات التعارف'), findsOneWidget);
    expect(find.text('التواصل بعد الموافقة'), findsOneWidget);
    expect(find.text('إرسال الرسائل الخاصة'), findsOneWidget);
    expect(find.byKey(const Key('localized_store_price')), findsOneWidget);
    expect(find.text('250.00 ج.م'), findsOneWidget);
    expect(find.byKey(const Key('subscribe_now_btn')), findsOneWidget);
  });

  testWidgets(
      '2. SubscriptionScreen displays unavailable state without fake price when Google Play product is unavailable',
      (WidgetTester tester) async {
    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.freeDefault(),
        googlePlayManageUrl:
            'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
    );
    final billing = FakeGooglePlayBillingClientService(mockPricing: null);

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const SubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('product_unavailable_state')), findsOneWidget);
    expect(find.byKey(const Key('localized_store_price')), findsNothing);
  });

  testWidgets('3. SubscriptionScreen displays purchase error banner on failure',
      (WidgetTester tester) async {
    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.freeDefault(),
        googlePlayManageUrl:
            'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
    );
    final billing = FakeGooglePlayBillingClientService(
      mockPricing: defaultStorePrice,
      shouldThrowOnPurchase: true,
    );

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const SubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('subscribe_now_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscribe_now_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscription_error_banner')), findsOneWidget);
    expect(
      find.textContaining('فشل الاتصال بخدمة الفوترة في متجر Google Play'),
      findsOneWidget,
    );
  });

  testWidgets(
      '4, 5 & 6. MySubscriptionScreen displays active subscription, expired subscription, and status refresh',
      (WidgetTester tester) async {
    final activeRecord = SubscriptionRecordModel(
      id: 10,
      planCode: 'monthly_membership',
      planNameAr: 'العضوية الشهرية — نصيبك',
      channel: 'google_play',
      channelLabelAr: 'متجر Google Play',
      status: 'active',
      statusLabelAr: 'نشط',
      isCurrentlyEntitled: true,
      autoRenewing: true,
      startsAt: DateTime(2026, 11, 1),
      currentPeriodEnd: DateTime(2026, 12, 1),
    );

    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: const SubscriptionEntitlementModel(
          hasActiveSubscription: true,
          subscriptionStatus: 'active',
          paymentChannel: 'google_play',
          canSendMatchRequests: true,
          canSendMessages: true,
        ),
        currentSubscription: activeRecord,
        googlePlayManageUrl:
            'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
      historyResponse: [activeRecord],
    );
    final billing = FakeGooglePlayBillingClientService(
      mockPricing: defaultStorePrice,
    );

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const MySubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اشتراكي'), findsOneWidget);
    expect(
      find.byKey(const Key('current_subscription_status_badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manage_google_play_subscription_btn')),
      findsOneWidget,
    );

    // Simulate expiration and tap refresh
    final expiredRecord = SubscriptionRecordModel(
      id: 10,
      planCode: 'monthly_membership',
      planNameAr: 'العضوية الشهرية — نصيبك',
      channel: 'google_play',
      channelLabelAr: 'متجر Google Play',
      status: 'expired',
      statusLabelAr: 'منتهي الصلاحية',
      isCurrentlyEntitled: false,
      autoRenewing: false,
      startsAt: DateTime(2026, 10, 1),
      currentPeriodEnd: DateTime(2026, 11, 1),
    );
    repo.overviewResponse = SubscriptionOverviewResponse(
      entitlement: const SubscriptionEntitlementModel(
        hasActiveSubscription: false,
        subscriptionStatus: 'expired',
        paymentChannel: 'google_play',
        canSendMatchRequests: false,
        canSendMessages: false,
      ),
      currentSubscription: expiredRecord,
      googlePlayManageUrl:
          'https://play.google.com/store/account/subscriptions',
    );

    await tester.tap(find.byKey(const Key('refresh_my_subscription_btn')));
    await tester.pumpAndSettle();

    expect(find.text('منتهي الصلاحية'), findsWidgets);
  });

  testWidgets('7. SubscriptionScreen handles pending purchase verification state',
      (WidgetTester tester) async {
    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.freeDefault(),
        googlePlayManageUrl:
            'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
    );
    final billing = FakeGooglePlayBillingClientService(
      mockPricing: defaultStorePrice,
    );

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const SubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    // Emit a pending purchase event from Google Play Billing stream
    billing.controller.add([
      PurchaseDetails(
        productID: 'naseebak_monthly_membership',
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local',
          serverVerificationData: 'pending_token_12345',
          source: 'google_play',
        ),
        transactionDate: '1700000000',
        status: PurchaseStatus.pending,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscription_status_banner')), findsOneWidget);
    expect(
      find.textContaining('عملية الدفع قيد المعالجة لدى متجر Google Play'),
      findsOneWidget,
    );
  });
}
