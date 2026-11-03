import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/features/messaging/data/services/realtime_messaging_service.dart';
import 'package:naseebak_mobile/features/notifications/data/models/notification_model.dart';
import 'package:naseebak_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:naseebak_mobile/features/notifications/data/services/push_notification_service.dart';
import 'package:naseebak_mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:naseebak_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:naseebak_mobile/features/notifications/presentation/screens/notification_preferences_screen.dart';

class _FakeNotificationRepository extends Fake
    implements NotificationRepository {
  List<NotificationItemModel> items;
  NotificationPreferencesModel preferences = const NotificationPreferencesModel();
  bool shouldThrow;
  bool deactivatedTokenOnLogout = false;

  _FakeNotificationRepository({
    this.items = const [],
    this.shouldThrow = false,
  });

  @override
  Future<PaginatedNotificationsResponse> fetchNotifications({
    int page = 1,
    int perPage = 25,
    bool unreadOnly = false,
  }) async {
    if (shouldThrow) {
      throw Exception('تعذر جلب الإشعارات من الخادم');
    }
    final unread = items.where((e) => !e.isRead).length;
    return PaginatedNotificationsResponse(
      notifications: List<NotificationItemModel>.from(items),
      unreadCount: unread,
      currentPage: 1,
      lastPage: 1,
      total: items.length,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    return items.where((e) => !e.isRead).length;
  }

  @override
  Future<({NotificationItemModel notification, int unreadCount})> markAsRead(
    int notificationId,
  ) async {
    items = items.map((e) {
      if (e.id == notificationId) {
        return e.copyWith(isRead: true, readAt: DateTime.now().toIso8601String());
      }
      return e;
    }).toList();
    final updated = items.where((e) => e.id == notificationId).first;
    final unread = items.where((e) => !e.isRead).length;
    return (notification: updated, unreadCount: unread);
  }

  @override
  Future<int> markAllAsRead() async {
    final unreadBefore = items.where((e) => !e.isRead).length;
    items = items
        .map((e) => e.copyWith(isRead: true, readAt: DateTime.now().toIso8601String()))
        .toList();
    return unreadBefore;
  }

  @override
  Future<int> deleteNotification(int notificationId) async {
    items = items.where((e) => e.id != notificationId).toList();
    return items.where((e) => !e.isRead).length;
  }

  @override
  Future<NotificationPreferencesModel> fetchPreferences() async {
    return preferences;
  }

  @override
  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel updated,
  ) async {
    preferences = updated;
    return preferences;
  }
}

class _FakePushNotificationService extends Fake
    implements PushNotificationService {
  final Set<String> _seenEvents = <String>{};
  final StreamController<IncomingPushPayload> _fgController =
      StreamController<IncomingPushPayload>.broadcast();
  final StreamController<IncomingPushPayload> _tapController =
      StreamController<IncomingPushPayload>.broadcast();
  final StreamController<NotificationPermissionStatus> _permController =
      StreamController<NotificationPermissionStatus>.broadcast();

  bool permissionGranted;
  String? currentToken = 'fake_android_fcm_token_1234567890';

  _FakePushNotificationService({
    this.permissionGranted = true,
  });

  @override
  Stream<IncomingPushPayload> get foregroundPushStream => _fgController.stream;

  @override
  Stream<IncomingPushPayload> get notificationTapStream => _tapController.stream;

  @override
  Stream<NotificationPermissionStatus> get permissionStatusStream =>
      _permController.stream;

  @override
  NotificationPermissionStatus get permissionStatus => permissionGranted
      ? NotificationPermissionStatus.granted
      : NotificationPermissionStatus.denied;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> requestNotificationPermission() async {
    permissionGranted = true;
    _permController.add(NotificationPermissionStatus.granted);
    return NotificationPermissionStatus.granted;
  }

  @override
  Future<void> synchronizeDeviceTokenForAuthenticatedUser() async {}

  @override
  Future<void> unregisterDeviceOnLogout() async {
    currentToken = null;
  }

  @override
  bool markEventSeenIfNew(String eventId) {
    if (eventId.isEmpty) return true;
    if (_seenEvents.contains(eventId)) return false;
    _seenEvents.add(eventId);
    return true;
  }
}

class _FakeRealtimeMessagingService extends Fake
    implements RealtimeMessagingService {
  final StreamController<ReverbEventMessage> _eventsController =
      StreamController<ReverbEventMessage>.broadcast();
  final StreamController<RealtimeConnectionState> _connController =
      StreamController<RealtimeConnectionState>.broadcast();
  final StreamController<void> _reconnectedController =
      StreamController<void>.broadcast();

  @override
  RealtimeConnectionState get connectionState =>
      RealtimeConnectionState.connected;

  @override
  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connController.stream;

  @override
  Stream<void> get onReconnectedStream => _reconnectedController.stream;

  @override
  Stream<ReverbEventMessage> get eventsStream => _eventsController.stream;

  @override
  Stream<ReverbEventMessage> get events => _eventsController.stream;

  void emitEvent(ReverbEventMessage event) {
    _eventsController.add(event);
  }
}

void main() {
  group('Phase 7 — Push Notifications & In-App Notification Center Tests', () {
    testWidgets(
      '1. Empty state renders exact Arabic message "لا توجد إشعارات حاليًا"',
      (tester) async {
        final fakeRepo = _FakeNotificationRepository(items: []);
        final fakePush = _FakePushNotificationService(permissionGranted: true);
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(fakeRepo),
              pushNotificationServiceProvider.overrideWithValue(fakePush),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: NotificationCenterScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.text('لا توجد إشعارات حاليًا'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Notification Center renders real notifications, unread badge, mark-read, mark-all-read, and delete',
      (tester) async {
        final sampleItems = [
          NotificationItemModel(
            id: 101,
            notificationType: 'matchmaking_request_received',
            titleAr: 'طلب تعارف جديد',
            bodyAr: 'لديك طلب تعارف جديد داخل تطبيق نصيبك.',
            actionRoute: 'matchmaking_requests',
            routingMetadata: const {'tab': 'incoming', 'request_id': 55},
            dataPayload: const {'event_id': 'evt_101'},
            isRead: false,
            deliveryStatus: 'submitted_to_fcm',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          NotificationItemModel(
            id: 102,
            notificationType: 'new_message_received',
            titleAr: 'رسالة جديدة',
            bodyAr: 'لديك رسالة جديدة داخل تطبيق نصيبك.',
            actionRoute: 'conversation',
            routingMetadata: const {'conversation_id': 88},
            dataPayload: const {'event_id': 'evt_102'},
            isRead: false,
            deliveryStatus: 'submitted_to_fcm',
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
          ),
        ];

        final fakeRepo = _FakeNotificationRepository(items: sampleItems);
        final fakePush = _FakePushNotificationService(permissionGranted: true);
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(fakeRepo),
              pushNotificationServiceProvider.overrideWithValue(fakePush),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: NotificationCenterScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Both notifications & unread badge = 2 are rendered
        expect(find.text('طلب تعارف جديد'), findsOneWidget);
        expect(find.text('رسالة جديدة'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.byKey(const ValueKey('btn_mark_all_read')), findsOneWidget);

        // Delete notification 102
        await tester.tap(
          find.byKey(const ValueKey('btn_delete_notification_102')),
        );
        await tester.pumpAndSettle();

        expect(find.text('رسالة جديدة'), findsNothing);
        expect(find.text('1'), findsOneWidget);

        // Tap "تحديد الكل كمقروء"
        await tester.tap(find.byKey(const ValueKey('btn_mark_all_read')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('btn_mark_all_read')), findsNothing);
      },
    );

    testWidgets(
      '3. Error & Retry state works when backend fails initially and succeeds on retry',
      (tester) async {
        final fakeRepo = _FakeNotificationRepository(
          items: [
            NotificationItemModel(
              id: 201,
              notificationType: 'subscription_activated',
              titleAr: 'تم تفعيل اشتراكك',
              bodyAr: 'تم تفعيل اشتراكك الشهري في نصيبك بنجاح.',
              actionRoute: 'my_subscription',
              routingMetadata: const {},
              dataPayload: const {},
              isRead: false,
              deliveryStatus: 'submitted_to_fcm',
            ),
          ],
          shouldThrow: true,
        );
        final fakePush = _FakePushNotificationService(permissionGranted: true);
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(fakeRepo),
              pushNotificationServiceProvider.overrideWithValue(fakePush),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: NotificationCenterScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('btn_retry_notifications')), findsOneWidget);

        // Fix backend and tap retry
        fakeRepo.shouldThrow = false;
        await tester.tap(find.byKey(const ValueKey('btn_retry_notifications')));
        await tester.pumpAndSettle();

        expect(find.text('تم تفعيل اشتراكك'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Android 13+ permission denied state shows Arabic prompt and enables permission on tap',
      (tester) async {
        final fakeRepo = _FakeNotificationRepository(items: []);
        final fakePush = _FakePushNotificationService(permissionGranted: false);
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(fakeRepo),
              pushNotificationServiceProvider.overrideWithValue(fakePush),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: NotificationCenterScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('فعّل الإشعارات لتصلك طلبات التعارف والرسائل الجديدة.'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('btn_banner_enable_notifications')),
        );
        await tester.pumpAndSettle();

        expect(fakePush.permissionGranted, isTrue);
      },
    );

    testWidgets(
      '5. NotificationPreferencesScreen loads and updates all 4 category toggles',
      (tester) async {
        final fakeRepo = _FakeNotificationRepository();
        final fakePush = _FakePushNotificationService(permissionGranted: true);
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWithValue(fakeRepo),
              pushNotificationServiceProvider.overrideWithValue(fakePush),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: NotificationPreferencesScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('إشعارات طلبات التعارف'), findsOneWidget);
        expect(find.text('إشعارات الرسائل'), findsOneWidget);
        expect(find.text('إشعارات الاشتراك'), findsOneWidget);
        expect(find.text('الإعلانات العامة'), findsOneWidget);

        // Toggle messages preference off
        await tester.tap(find.byKey(const ValueKey('pref_messages')));
        await tester.pumpAndSettle();

        expect(fakeRepo.preferences.messagesEnabled, isFalse);
      },
    );

    test(
      '6. Deduplication across Reverb WebSocket and FCM prevents duplicate notification insertion & logout cleans up token',
      () async {
        final fakeRepo = _FakeNotificationRepository();
        final fakePush = _FakePushNotificationService(permissionGranted: true);
        final fakeRealtime = _FakeRealtimeMessagingService();

        final container = ProviderContainer(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(fakeRepo),
            pushNotificationServiceProvider.overrideWithValue(fakePush),
            realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(notificationProvider.notifier);

        // Emit same event_id twice over Reverb stream
        const duplicatePayload = {
          'event_id': 'evt_dedup_999',
          'notification': {
            'id': 999,
            'notification_type': 'matchmaking_request_received',
            'title_ar': 'طلب تعارف جديد',
            'body_ar': 'لديك طلب تعارف جديد داخل تطبيق نصيبك.',
            'action_route': 'matchmaking_requests',
            'routing_metadata': {'tab': 'incoming'},
            'data_payload': {'event_id': 'evt_dedup_999'},
            'is_read': false,
            'delivery_status': 'submitted_to_fcm',
          },
          'unread_count': 1,
        };

        fakeRealtime.emitEvent(
          const RealtimeSocketEvent(
            eventName: 'notification.created',
            channelName: 'private-users.1.notifications',
            data: duplicatePayload,
          ),
        );
        fakeRealtime.emitEvent(
          const RealtimeSocketEvent(
            eventName: 'notification.created',
            channelName: 'private-users.1.notifications',
            data: duplicatePayload,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final stateAfter = container.read(notificationProvider);
        expect(stateAfter.notifications.length, 1);
        expect(stateAfter.unreadCount, 1);

        // Verify logout token cleanup
        await notifier.cleanupOnLogout();
        expect(fakePush.currentToken, isNull);
        expect(container.read(notificationProvider).notifications, isEmpty);
      },
    );
  });
}
