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
  bool throwOnOverview;

  FakeSubscriptionRepository({
    required this.overviewResponse,
    required this.plansResponse,
    this.historyResponse = const [],
    this.throwOnOverview = false,
  }) : super(
          apiClient: ApiClient(sessionStorage: const SecureSessionStorage()),
        );

  @override
  Future<SubscriptionOverviewResponse> fetchSubscriptionOverview() async {
    if (throwOnOverview) {
      throw Exception('تعذر الاتصال بالخادم. يرجى التحقق من الشبكة.');
    }
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
}

class FakeGooglePlayBillingClientService extends GooglePlayBillingClientService {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
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
    nameAr: 'الباقة الشهرية',
    durationDays: 30,
    googlePlayProductId: 'naseebak_monthly_membership',
    featuresAr: [
      'التواصل بعد قبول طلب التعارف.',
      'استخدام مميزات التواصل المتاحة.',
      'متابعة حالة العضوية وتاريخ انتهائها.',
    ],
    renewalTermsAr: 'تتوفر الاشتراكات عبر الموقع الرسمي.',
    cancellationTermsAr: 'تتم إدارة الاشتراكات عبر الموقع الرسمي.',
  );

  testWidgets(
      '1 & 8. SubscriptionScreen renders Arabic RTL content, benefits, and website guidance',
      (WidgetTester tester) async {
    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.freeDefault(),
        googlePlayManageUrl: 'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
    );
    final billing = FakeGooglePlayBillingClientService();

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
    expect(find.text('عضويتي في نَصِيبُكَ'), findsOneWidget);
    expect(find.text('عضويتك غير نشطة حاليًا'), findsOneWidget);
    expect(
      find.text(
        'تقدر تكتشف الأعضاء وتستخدم المميزات المتاحة لحسابك، وللتواصل عبر المحادثات تحتاج عضوية فعّالة.',
      ),
      findsOneWidget,
    );
    expect(find.text('التواصل بعد قبول طلب التعارف.'), findsOneWidget);
    expect(find.text('استخدام مميزات التواصل المتاحة.'), findsOneWidget);
    expect(find.text('متابعة حالة العضوية وتاريخ انتهائها.'), findsOneWidget);
    expect(find.byKey(const Key('non_interactive_domain_text')), findsOneWidget);
    expect(find.text('naseebak.hazem.my'), findsOneWidget);
    expect(find.byKey(const Key('refresh_membership_status_btn')), findsOneWidget);
    expect(find.text('تحديث حالة العضوية'), findsOneWidget);
  });

  testWidgets(
      '2. SubscriptionScreen displays error state with Retry button when network fails',
      (WidgetTester tester) async {
    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.freeDefault(),
        googlePlayManageUrl: 'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
      throwOnOverview: true,
    );
    final billing = FakeGooglePlayBillingClientService();

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const SubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('membership_error_state')), findsOneWidget);
    expect(find.text('تعذر الاتصال بالخادم'), findsOneWidget);
    expect(find.byKey(const Key('retry_membership_btn')), findsOneWidget);
  });

  testWidgets(
      '3. MySubscriptionScreen displays active membership, plan name, and expiry date',
      (WidgetTester tester) async {
    final activeRecord = SubscriptionRecordModel(
      id: 10,
      planCode: 'monthly_membership',
      planNameAr: 'الباقة الشهرية',
      channel: 'web_paymob',
      channelLabelAr: 'بوابة الدفع الإلكتروني',
      status: 'active',
      statusLabelAr: 'نشط ومفعل',
      isCurrentlyEntitled: true,
      autoRenewing: false,
      startsAt: DateTime(2026, 11, 1),
      currentPeriodEnd: DateTime(2026, 12, 1),
    );

    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: const SubscriptionEntitlementModel(
          hasActiveSubscription: true,
          subscriptionStatus: 'active',
          paymentChannel: 'web_paymob',
          canSendMatchRequests: true,
          canSendMessages: true,
        ),
        currentSubscription: activeRecord,
        googlePlayManageUrl: 'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
      historyResponse: [activeRecord],
    );
    final billing = FakeGooglePlayBillingClientService();

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const MySubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('عضويتي في نَصِيبُكَ'), findsOneWidget);
    expect(find.text('عضويتك فعّالة ✨'), findsOneWidget);
    expect(find.byKey(const Key('membership_plan_name')), findsOneWidget);
    expect(find.text('الباقة الشهرية'), findsWidgets);
    expect(find.byKey(const Key('membership_expiry_date')), findsOneWidget);
    expect(find.text('2026-12-01'), findsOneWidget);
    expect(find.text('نشط ومفعل'), findsOneWidget);
  });

  testWidgets(
      '4. SubscriptionScreen displays expired membership state with real date',
      (WidgetTester tester) async {
    final expiredRecord = SubscriptionRecordModel(
      id: 10,
      planCode: 'monthly_membership',
      planNameAr: 'الباقة الشهرية',
      channel: 'web_paymob',
      channelLabelAr: 'بوابة الدفع الإلكتروني',
      status: 'expired',
      statusLabelAr: 'منتهي الصلاحية',
      isCurrentlyEntitled: false,
      autoRenewing: false,
      startsAt: DateTime(2026, 10, 1),
      currentPeriodEnd: DateTime(2026, 11, 1),
    );

    final repo = FakeSubscriptionRepository(
      overviewResponse: SubscriptionOverviewResponse(
        entitlement: const SubscriptionEntitlementModel(
          hasActiveSubscription: false,
          subscriptionStatus: 'expired',
          paymentChannel: 'web_paymob',
          canSendMatchRequests: false,
          canSendMessages: false,
        ),
        currentSubscription: expiredRecord,
        googlePlayManageUrl: 'https://play.google.com/store/account/subscriptions',
      ),
      plansResponse: const [defaultPlan],
      historyResponse: [expiredRecord],
    );
    final billing = FakeGooglePlayBillingClientService();

    await tester.pumpWidget(
      _wrapRtlTestApp(
        const SubscriptionScreen(),
        fakeRepo: repo,
        fakeBilling: billing,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('انتهت صلاحية عضويتك'), findsOneWidget);
    expect(find.text('انتهت في: 2026-11-01'), findsOneWidget);
    expect(find.text('naseebak.hazem.my'), findsOneWidget);
    expect(find.byKey(const Key('refresh_membership_status_btn')), findsOneWidget);
  });
}
