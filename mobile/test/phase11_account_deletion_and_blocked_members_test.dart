import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/core/constants/api_endpoints.dart';
import 'package:naseebak_mobile/features/auth/data/google_auth_repository.dart';
import 'package:naseebak_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:naseebak_mobile/features/discovery/data/models/blocked_member_model.dart';
import 'package:naseebak_mobile/features/discovery/data/repositories/discovery_repository.dart';
import 'package:naseebak_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:naseebak_mobile/features/messaging/data/services/realtime_messaging_service.dart';
import 'package:naseebak_mobile/features/notifications/data/services/push_notification_service.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/blocked_members_screen.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/delete_account_screen.dart';

class _FakeDiscoveryRepository extends Fake implements DiscoveryRepository {
  List<BlockedMemberModel> blockedList = [
    const BlockedMemberModel(
      id: 1,
      blockedUserId: 101,
      fullName: 'ريم العتيبي',
      gender: 'female',
      ageYears: 27,
      region: 'الرياض',
      countryOfResidence: 'السعودية',
      reason: 'حظر بناءً على رغبة المستخدم',
    ),
    const BlockedMemberModel(
      id: 2,
      blockedUserId: 102,
      fullName: 'سارة الدوسري',
      gender: 'female',
      ageYears: 24,
      region: 'جدة',
      countryOfResidence: 'السعودية',
      reason: 'سلوك غير لائق',
    ),
  ];

  int unblockCalledWith = -1;

  @override
  Future<List<BlockedMemberModel>> fetchBlockedMembers({int page = 1}) async {
    return blockedList;
  }

  @override
  Future<void> unblockMember(int memberUserId) async {
    unblockCalledWith = memberUserId;
    blockedList = blockedList
        .where((m) => m.blockedUserId != memberUserId)
        .toList();
  }
}

class _FakeGoogleAuthRepository extends Fake implements GoogleAuthRepository {
  bool deleteAccountCalled = false;
  String? lastConfirmation;
  String? lastReason;

  @override
  Future<Map<String, dynamic>> deleteAccount({
    required String confirmation,
    String? reason,
    String? notes,
  }) async {
    deleteAccountCalled = true;
    lastConfirmation = confirmation;
    lastReason = reason;
    return {
      'account_status': 'deleted',
      'google_play_subscriptions_url':
          'https://play.google.com/store/account/subscriptions',
    };
  }

  @override
  Future<void> signOut() async {}
}

class _FakeRealtimeMessagingService extends Fake
    implements RealtimeMessagingService {
  @override
  Future<void> disconnect() async {}

  @override
  Stream<ReverbEventMessage> get eventsStream => const Stream.empty();
}

class _FakePushNotificationService extends Fake
    implements PushNotificationService {
  @override
  Future<void> unregisterDeviceOnLogout() async {}

  @override
  NotificationPermissionStatus get permissionStatus =>
      NotificationPermissionStatus.granted;

  @override
  Stream<NotificationPermissionStatus> get permissionStatusStream =>
      const Stream.empty();

  @override
  Stream<IncomingPushPayload> get foregroundPushStream =>
      const Stream.empty();

  @override
  Future<bool> initialize() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 11 — Account Deletion & Blocked Members Tests', () {
    test('ApiEndpoints defines account deletion and blocked members paths', () {
      expect(ApiEndpoints.authDeleteAccount, '/auth/account');
      expect(ApiEndpoints.blockedMembers, '/blocked-members');
      expect(ApiEndpoints.unblockMember(99), '/members/99/block');
    });

    test('BlockedMemberModel parses JSON properly and provides safe fallbacks', () {
      final json = {
        'id': 5,
        'blocked_user_id': 88,
        'full_name': 'محمد عبد الله',
        'gender': 'male',
        'age_years': 32,
        'region': 'الدمام',
        'country_of_residence': 'السعودية',
        'reason': 'مخالفة',
        'blocked_at': '2026-11-04T00:00:00.000Z',
        'unblock_allowed': true,
      };

      final model = BlockedMemberModel.fromJson(json);
      expect(model.id, 5);
      expect(model.blockedUserId, 88);
      expect(model.fullName, 'محمد عبد الله');
      expect(model.gender, 'male');
      expect(model.ageYears, 32);
      expect(model.unblockAllowed, true);
    });

    testWidgets('BlockedMembersScreen renders real blocked members and handles unblocking dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeDiscoveryRepo = _FakeDiscoveryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRepositoryProvider.overrideWithValue(fakeDiscoveryRepo),
          ],
          child: const MaterialApp(
            home: BlockedMembersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and items
      expect(find.text('الأعضاء المحظورون'), findsOneWidget);
      expect(find.text('ريم العتيبي'), findsOneWidget);
      expect(find.text('سارة الدوسري'), findsOneWidget);
      expect(find.text('إجمالي المحظورين: 2'), findsOneWidget);

      // Tap unblock button on member 101
      final unblockBtn = find.byKey(const Key('unblock_btn_101'));
      expect(unblockBtn, findsOneWidget);
      await tester.tap(unblockBtn);
      await tester.pumpAndSettle();

      // Verify unblock dialog opens
      expect(find.text('إلغاء حظر العضو؟'), findsOneWidget);
      expect(find.text('نعم، إلغاء الحظر'), findsOneWidget);

      // Confirm unblock
      await tester.tap(find.text('نعم، إلغاء الحظر'));
      await tester.pumpAndSettle();

      // Verify repository was called
      expect(fakeDiscoveryRepo.unblockCalledWith, 101);
      // Member 101 is removed, only member 102 remains
      expect(find.text('ريم العتيبي'), findsNothing);
      expect(find.text('سارة الدوسري'), findsOneWidget);
      expect(find.text('إجمالي المحظورين: 1'), findsOneWidget);
    });

    testWidgets('DeleteAccountScreen enforces confirmation word and executes deletion API',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeAuthRepo = _FakeGoogleAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAuthRepositoryProvider.overrideWithValue(fakeAuthRepo),
            realtimeMessagingServiceProvider
                .overrideWithValue(_FakeRealtimeMessagingService()),
            pushNotificationServiceProvider
                .overrideWithValue(_FakePushNotificationService()),
          ],
          child: const MaterialApp(
            home: DeleteAccountScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('حذف الحساب'), findsWidgets);
      final btnFinder = find.byKey(const Key('confirm_delete_account_btn'));
      expect(btnFinder, findsOneWidget);

      // Submit button is disabled by default
      final submitButton = tester.widget<ElevatedButton>(btnFinder);
      expect(submitButton.onPressed, isNull);

      // Scroll to checkbox and check the Play Store acknowledgement checkbox
      final checkboxFinder = find.byKey(const Key('play_store_acknowledge_checkbox'));
      expect(checkboxFinder, findsOneWidget);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Enter confirmation word "حذف" into the designated confirmation input
      final confirmInputFinder =
          find.byKey(const Key('delete_account_confirmation_input'));
      expect(confirmInputFinder, findsOneWidget);
      await tester.ensureVisible(confirmInputFinder);
      await tester.enterText(confirmInputFinder, 'حذف');
      await tester.pumpAndSettle();

      // Now the button should be enabled
      final enabledSubmitButton = tester.widget<ElevatedButton>(btnFinder);
      expect(enabledSubmitButton.onPressed, isNotNull);

      // Tap submit button to open final confirmation dialog
      await tester.ensureVisible(btnFinder);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(find.text('تأكيد حذف الحساب نهائيًا؟'), findsOneWidget);
      expect(find.text('نعم، احذف حسابي'), findsOneWidget);

      // Confirm deletion in dialog
      await tester.tap(find.text('نعم، احذف حسابي'));
      await tester.pumpAndSettle();

      // Verify authoritative deleteAccount was executed
      expect(fakeAuthRepo.deleteAccountCalled, true);
      expect(fakeAuthRepo.lastConfirmation, 'حذف');
    });
  });
}
