import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:naseebak_mobile/core/design_system/naseebak_design_system.dart';
import 'package:naseebak_mobile/features/subscription/data/models/subscription_model.dart';
import 'package:naseebak_mobile/features/subscription/data/repositories/subscription_repository.dart';
import 'package:naseebak_mobile/features/subscription/data/services/google_play_billing_service.dart';
import 'package:naseebak_mobile/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:naseebak_mobile/features/subscription/presentation/screens/my_subscription_screen.dart';
import 'package:naseebak_mobile/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:naseebak_mobile/features/subscription/presentation/widgets/subscription_status_widget.dart';

class FakeSubscriptionRepo extends Fake implements SubscriptionRepository {
  SubscriptionOverviewResponse overview;
  List<SubscriptionPlanModel> plans;
  List<SubscriptionRecordModel> history;
  bool shouldThrow;

  FakeSubscriptionRepo({
    required this.overview,
    this.plans = const [],
    this.history = const [],
    this.shouldThrow = false,
  });

  @override
  Future<SubscriptionOverviewResponse> fetchSubscriptionOverview() async {
    if (shouldThrow) {
      throw Exception('تعذر الاتصال بالخادم. يرجى التحقق من الشبكة.');
    }
    return overview;
  }

  @override
  Future<List<SubscriptionPlanModel>> fetchPlans() async {
    if (shouldThrow) {
      throw Exception('تعذر الاتصال بالخادم.');
    }
    return plans;
  }

  @override
  Future<List<SubscriptionRecordModel>> fetchSubscriptionHistory() async {
    return history;
  }
}

class FakeBillingGateway extends Fake implements GooglePlayBillingGateway {
  final StreamController<List<PurchaseDetails>> _stream =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;

  @override
  Future<bool> isAvailable() async => true;
}

Widget _wrapTestApp(
  Widget child, {
  required FakeSubscriptionRepo repo,
}) {
  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repo),
      googlePlayBillingServiceProvider.overrideWithValue(
        GooglePlayBillingClientService(gateway: FakeBillingGateway()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('Phase 19 — Google Play Compliant Membership Screen Redesign Tests', () {
    testWidgets('1. Inactive member sees correct copywriting, benefits, and domain',
        (tester) async {
      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          currentSubscription: null,
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Screen title
      expect(find.text('عضويتي في نَصِيبُكَ'), findsOneWidget);

      // Inactive title and description
      expect(find.text('عضويتك غير نشطة حاليًا'), findsOneWidget);
      expect(
        find.textContaining('تقدر تكتشف الأعضاء وتستخدم المميزات المتاحة لحسابك'),
        findsOneWidget,
      );

      // Benefits section and 3 backend-supported benefits
      expect(find.text('مميزات العضوية'), findsOneWidget);
      expect(find.text('التواصل بعد قبول طلب التعارف.'), findsOneWidget);
      expect(find.text('استخدام مميزات التواصل المتاحة.'), findsOneWidget);
      expect(find.text('متابعة حالة العضوية وتاريخ انتهائها.'), findsOneWidget);

      // How membership works and website guidance
      expect(find.text('كيف تعمل العضوية؟'), findsOneWidget);
      expect(
        find.textContaining('الاشتراكات غير متاحة للشراء من داخل التطبيق'),
        findsOneWidget,
      );
      expect(
        find.textContaining('يمكنك الاشتراك من خلال موقع نَصِيبُكَ الرسمي'),
        findsOneWidget,
      );

      // Plain non-interactive domain
      expect(find.byKey(const Key('non_interactive_domain_text')), findsOneWidget);
      expect(find.text('naseebak.hazem.my'), findsOneWidget);

      // Additional text
      expect(
        find.textContaining('بعد تفعيل العضوية على نفس حسابك، يمكنك تحديث حالة العضوية هنا.'),
        findsOneWidget,
      );

      // Single functional button: "تحديث حالة العضوية"
      expect(find.byKey(const Key('refresh_membership_status_btn')), findsOneWidget);
      expect(find.text('تحديث حالة العضوية'), findsOneWidget);

      // Verify NO purchase buttons or Google Play error messages exist
      expect(find.text('اشترك الآن'), findsNothing);
      expect(find.textContaining('باقة الاشتراك غير متاحة'), findsNothing);
    });

    testWidgets('2. Active member sees active membership card, plan, and expiration date',
        (tester) async {
      final activeSub = SubscriptionRecordModel(
        id: 101,
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

      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel(
            hasActiveSubscription: true,
            subscriptionStatus: 'active',
            paymentChannel: 'web_paymob',
            currentPeriodEnd: DateTime(2026, 12, 1),
            autoRenewing: false,
            canSendMatchRequests: true,
            canSendMessages: true,
          ),
          currentSubscription: activeSub,
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Active title and positive message
      expect(find.text('عضويتك فعّالة ✨'), findsOneWidget);
      expect(
        find.textContaining('تقدر دلوقتي تستفيد من مميزات التواصل المتاحة لعضويتك.'),
        findsOneWidget,
      );

      // Real API plan name and expiration date
      expect(find.byKey(const Key('membership_plan_name')), findsOneWidget);
      expect(find.text('الباقة الشهرية'), findsWidgets);
      expect(find.byKey(const Key('membership_expiry_date')), findsOneWidget);
      expect(find.text('2026-12-01'), findsOneWidget);

      // Status indicator
      expect(find.text('نشط ومفعل'), findsOneWidget);

      // Functional refresh button
      expect(find.byKey(const Key('refresh_membership_status_btn')), findsOneWidget);
      expect(find.text('تحديث حالة العضوية'), findsOneWidget);

      // Verify NO purchase buttons exist
      expect(find.text('اشترك الآن'), findsNothing);
    });

    testWidgets('3. Expired member sees expired membership state with real date',
        (tester) async {
      final expiredSub = SubscriptionRecordModel(
        id: 102,
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

      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: const SubscriptionEntitlementModel(
            hasActiveSubscription: false,
            subscriptionStatus: 'expired',
            paymentChannel: 'web_paymob',
            canSendMatchRequests: false,
            canSendMessages: false,
          ),
          currentSubscription: expiredSub,
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Expired title
      expect(find.text('انتهت صلاحية عضويتك'), findsOneWidget);
      expect(find.text('انتهت في: 2026-11-01'), findsOneWidget);
      expect(
        find.textContaining('يمكنك متابعة استخدام المميزات المتاحة بدون عضوية.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('لتفعيل فترة جديدة، تتوفر الاشتراكات عبر الموقع الرسمي لنَصِيبُكَ.'),
        findsOneWidget,
      );

      // Plain domain and refresh button
      expect(find.text('naseebak.hazem.my'), findsOneWidget);
      expect(find.byKey(const Key('refresh_membership_status_btn')), findsOneWidget);
      expect(find.text('تحديث حالة العضوية'), findsOneWidget);
    });

    testWidgets('4. Refresh button fetches latest backend entitlement from Laravel API',
        (tester) async {
      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          currentSubscription: null,
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('عضويتك غير نشطة حاليًا'), findsOneWidget);

      // Simulate member subscribing on the website and tapping refresh in app
      repo.overview = SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel(
          hasActiveSubscription: true,
          subscriptionStatus: 'active',
          paymentChannel: 'web_paymob',
          currentPeriodEnd: DateTime(2026, 12, 15),
          autoRenewing: false,
          canSendMatchRequests: true,
          canSendMessages: true,
        ),
        currentSubscription: SubscriptionRecordModel(
          id: 200,
          planCode: 'quarterly_membership',
          planNameAr: 'الباقة الربع سنوية',
          channel: 'web_paymob',
          channelLabelAr: 'بوابة الدفع الإلكتروني',
          status: 'active',
          statusLabelAr: 'نشط',
          isCurrentlyEntitled: true,
          autoRenewing: false,
          startsAt: DateTime(2026, 9, 15),
          currentPeriodEnd: DateTime(2026, 12, 15),
        ),
        googlePlayManageUrl: 'https://play.google.com',
      );

      await tester.ensureVisible(find.byKey(const Key('refresh_membership_status_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('refresh_membership_status_btn')));
      await tester.pumpAndSettle();

      // UI updates immediately to Active Membership State
      expect(find.text('عضويتك فعّالة ✨'), findsOneWidget);
      expect(find.text('الباقة الربع سنوية'), findsWidgets);
      expect(find.text('2026-12-15'), findsOneWidget);
    });

    testWidgets('5. Network failure displays error state with Retry and does NOT display inactive state',
        (tester) async {
      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          googlePlayManageUrl: 'https://play.google.com',
        ),
        shouldThrow: true,
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Error state must be shown
      expect(find.byKey(const Key('membership_error_state')), findsOneWidget);
      expect(find.text('تعذر الاتصال بالخادم'), findsOneWidget);
      expect(find.byKey(const Key('retry_membership_btn')), findsOneWidget);

      // Inactive state must NOT be shown when network fails
      expect(find.text('عضويتك غير نشطة حاليًا'), findsNothing);

      // Tap Retry after fixing connection
      repo.shouldThrow = false;
      await tester.tap(find.byKey(const Key('retry_membership_btn')));
      await tester.pumpAndSettle();

      // Inactive state now loads cleanly after network is restored
      expect(find.text('عضويتك غير نشطة حاليًا'), findsOneWidget);
    });

    testWidgets('6. Strict Consumption-Only Compliance: NO checkout buttons or clickable external links',
        (tester) async {
      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Ensure NO purchase or pay buttons
      expect(find.text('اشترك الآن'), findsNothing);
      expect(find.text('ادفع الآن'), findsNothing);
      expect(find.text('شراء'), findsNothing);
      expect(find.byKey(const Key('subscribe_now_btn')), findsNothing);

      // Domain container is not an inkwell or button
      final domainContainer = tester.widget<Container>(
        find.byKey(const Key('non_interactive_domain_text')),
      );
      expect(domainContainer, isNotNull);
      // Ensure no ancestor InkWell or GestureDetector on the domain box
      expect(
        find.ancestor(
          of: find.byKey(const Key('non_interactive_domain_text')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('7. No Google Play Billing error messages remain in UI',
        (tester) async {
      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('متجر Google Play'), findsNothing);
      expect(find.textContaining('باقة الاشتراك غير متاحة'), findsNothing);
      expect(find.textContaining('فشل الاتصال بخدمة الفوترة'), findsNothing);
    });

    testWidgets('8. RTL rendering is strictly enforced on Membership Screen',
        (tester) async {
      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const SubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      final directionality = Directionality.of(
        tester.element(find.byType(Scaffold)),
      );
      expect(directionality, TextDirection.rtl);
    });

    testWidgets('9. MySubscriptionScreen renders unified Membership Screen',
        (tester) async {
      final repo = FakeSubscriptionRepo(
        overview: SubscriptionOverviewResponse(
          entitlement: SubscriptionEntitlementModel.freeDefault(),
          googlePlayManageUrl: 'https://play.google.com',
        ),
      );

      await tester.pumpWidget(_wrapTestApp(const MySubscriptionScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Renders the exact same unified membership screen
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.text('عضويتي في نَصِيبُكَ'), findsOneWidget);
      expect(find.text('عضويتك غير نشطة حاليًا'), findsOneWidget);
    });

    testWidgets('10. SubscriptionStatusWidget in profile menu safely navigates to Membership Screen',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SubscriptionStatusWidget(
              entitlement: SubscriptionEntitlementModel.freeDefault(),
              onManageTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('status_widget_manage_btn')), findsOneWidget);
      expect(find.text('عضويتي في نَصِيبُكَ'), findsOneWidget);

      // Verify old "اشترك الآن" button is removed
      expect(find.text('اشترك الآن'), findsNothing);

      await tester.tap(find.byKey(const Key('status_widget_manage_btn')));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('11. NaseebakPremiumBanner button has safe "عضويتي" label and triggers callback',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: NaseebakPremiumBanner(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('عضويتي'), findsOneWidget);
      expect(find.text('اكتشف الاشتراك'), findsNothing);

      await tester.tap(find.text('عضويتي'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}
