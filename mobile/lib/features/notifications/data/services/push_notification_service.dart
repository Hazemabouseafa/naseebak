import 'dart:async';
import 'dart:collection';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/notification_repository.dart';

/// Top-level background message handler required by Firebase Messaging.
/// Executes in a separate background isolate on Android.
/// Never attempts UI navigation or unnecessary API calls from the background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Graceful no-op when google-services.json is not yet provisioned
  }
}

enum NotificationPermissionStatus {
  notDetermined,
  granted,
  denied,
  permanentlyDenied,
}

class IncomingPushPayload {
  final String eventId;
  final int? notificationId;
  final String eventType;
  final String titleAr;
  final String bodyAr;
  final String actionRoute;
  final Map<String, dynamic> routingMetadata;

  const IncomingPushPayload({
    required this.eventId,
    this.notificationId,
    required this.eventType,
    required this.titleAr,
    required this.bodyAr,
    required this.actionRoute,
    this.routingMetadata = const {},
  });

  factory IncomingPushPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notif = message.notification;

    return IncomingPushPayload(
      eventId: (data['event_id'] as String?) ?? (message.messageId ?? ''),
      notificationId: int.tryParse('${data['notification_id'] ?? ''}'),
      eventType: (data['event_type'] as String?) ?? 'admin_announcement',
      titleAr: notif?.title ?? (data['title_ar'] as String?) ?? 'نَصِيبُكَ',
      bodyAr: notif?.body ?? (data['body_ar'] as String?) ?? 'لديك إشعار جديد',
      actionRoute: (data['action_route'] as String?) ?? 'notification_center',
      routingMetadata: {
        if (data['request_id'] != null)
          'request_id': int.tryParse('${data['request_id']}') ?? data['request_id'],
        if (data['conversation_id'] != null)
          'conversation_id':
              int.tryParse('${data['conversation_id']}') ?? data['conversation_id'],
        if (data['reference_id'] != null)
          'reference_id':
              int.tryParse('${data['reference_id']}') ?? data['reference_id'],
        if (data['tab'] != null) 'tab': '${data['tab']}',
      },
    );
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(
    deviceTokenRepository: ref.watch(deviceTokenRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

class PushNotificationService {
  final DeviceTokenRepository _deviceTokenRepository;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final _foregroundController =
      StreamController<IncomingPushPayload>.broadcast();
  final _tapController = StreamController<IncomingPushPayload>.broadcast();
  final _permissionController =
      StreamController<NotificationPermissionStatus>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  /// Bounded FIFO set of seen event IDs for deduplicating Reverb + FCM events.
  final Queue<String> _seenEventIds = Queue<String>();
  static const int _maxSeenEvents = 250;

  bool _isFirebaseAvailable = false;
  bool _channelsCreated = false;
  String? _currentFcmToken;
  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;

  PushNotificationService({
    required DeviceTokenRepository deviceTokenRepository,
  }) : _deviceTokenRepository = deviceTokenRepository;

  Stream<IncomingPushPayload> get foregroundPushStream =>
      _foregroundController.stream;

  Stream<IncomingPushPayload> get notificationTapStream =>
      _tapController.stream;

  Stream<NotificationPermissionStatus> get permissionStatusStream =>
      _permissionController.stream;

  NotificationPermissionStatus get permissionStatus => _permissionStatus;

  bool get isFirebaseAvailable => _isFirebaseAvailable;

  /// Android 8.0+ Notification Channels (matchmaking_requests, private_messages, subscription_updates, announcements)
  static const List<AndroidNotificationChannel> androidChannels = [
    AndroidNotificationChannel(
      'matchmaking_requests',
      'طلبات التعارف',
      description: 'إشعارات طلبات التعارف الجديدة والمقبولة في نَصِيبُكَ',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'private_messages',
      'الرسائل الخاصة',
      description: 'إشعارات الرسائل النصية الخاصة بين الأعضاء المصرح لهم',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'subscription_updates',
      'تحديثات الاشتراك',
      description: 'إشعارات تفعيل وتجديد وانتهاء الاشتراك الشهري',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'announcements',
      'الإعلانات العامة',
      description: 'التنبيهات والإعلانات الإدارية العامة من منصة نَصِيبُكَ',
      importance: Importance.defaultImportance,
    ),
  ];

  /// Initializes Firebase Messaging, Android 8+ channels, and foreground/background/terminated listeners.
  Future<void> initialize() async {
    await _ensureAndroidNotificationChannels();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseAvailable = true;
    } catch (_) {
      // Firebase credentials (google-services.json) not yet provisioned in this environment;
      // application continues functioning normally without crashing.
      _isFirebaseAvailable = false;
      await _checkCurrentPermissionStatus();
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _checkCurrentPermissionStatus();

    _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final payload = IncomingPushPayload.fromRemoteMessage(message);
      _foregroundController.add(payload);
    });

    _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final payload = IncomingPushPayload.fromRemoteMessage(message);
      _tapController.add(payload);
    });

    // Check if the app was launched from a terminated state via a notification tap
    try {
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        final payload = IncomingPushPayload.fromRemoteMessage(initialMessage);
        _tapController.add(payload);
      }
    } catch (_) {}
  }

  /// Requests Android 13+ POST_NOTIFICATIONS runtime permission after authentication.
  /// Never blocks registration, browsing, or messaging if denied.
  Future<NotificationPermissionStatus> requestNotificationPermission() async {
    if (!_isFirebaseAvailable) {
      try {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          _updatePermissionStatus(
            (granted ?? true)
                ? NotificationPermissionStatus.granted
                : NotificationPermissionStatus.denied,
          );
          return _permissionStatus;
        }
      } catch (_) {}
      _updatePermissionStatus(NotificationPermissionStatus.granted);
      return _permissionStatus;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final mapped = _mapAuthorizationStatus(settings.authorizationStatus);
      _updatePermissionStatus(mapped);
      return mapped;
    } catch (_) {
      _updatePermissionStatus(NotificationPermissionStatus.denied);
      return _permissionStatus;
    }
  }

  Future<NotificationPermissionStatus> _checkCurrentPermissionStatus() async {
    if (!_isFirebaseAvailable) {
      try {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final enabled = await androidPlugin.areNotificationsEnabled();
          if (enabled == true) {
            _updatePermissionStatus(NotificationPermissionStatus.granted);
          }
          return _permissionStatus;
        }
      } catch (_) {}
      return _permissionStatus;
    }

    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final mapped = _mapAuthorizationStatus(settings.authorizationStatus);
      _updatePermissionStatus(mapped);
      return mapped;
    } catch (_) {
      return _permissionStatus;
    }
  }

  /// Obtains the current FCM registration token, registers it with the authenticated Laravel user,
  /// and subscribes to token refresh events. Never logs raw FCM tokens.
  Future<void> synchronizeDeviceTokenForAuthenticatedUser() async {
    if (!_isFirebaseAvailable) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        _currentFcmToken = token.trim();
        await _deviceTokenRepository.registerDeviceToken(
          fcmToken: _currentFcmToken!,
          devicePlatform: 'android',
        );
      }

      _onTokenRefreshSub?.cancel();
      _onTokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
        if (newToken.trim().isNotEmpty) {
          _currentFcmToken = newToken.trim();
          _deviceTokenRepository.registerDeviceToken(
            fcmToken: _currentFcmToken!,
            devicePlatform: 'android',
          );
        }
      });
    } catch (_) {
      // Token registration failures are non-fatal to app usage
    }
  }

  /// Unregisters the current device token from the user's account upon logout.
  Future<void> unregisterDeviceOnLogout() async {
    _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub = null;

    try {
      await _deviceTokenRepository.unregisterDeviceToken(
        fcmToken: _currentFcmToken,
      );
    } catch (_) {}

    _currentFcmToken = null;
    _seenEventIds.clear();
  }

  /// Deduplicates events across Laravel Reverb and FCM using `event_id`.
  /// Returns `true` if this `eventId` is new and should be processed; `false` if already seen.
  bool markEventSeenIfNew(String eventId) {
    final normalized = eventId.trim();
    if (normalized.isEmpty) return true;

    if (_seenEventIds.contains(normalized)) {
      return false;
    }

    _seenEventIds.addLast(normalized);
    while (_seenEventIds.length > _maxSeenEvents) {
      _seenEventIds.removeFirst();
    }
    return true;
  }

  /// Displays a privacy-conscious local notification when the app is in the foreground
  /// and the user is NOT actively viewing the target conversation.
  Future<void> showForegroundSystemNotification(
    IncomingPushPayload payload,
  ) async {
    if (!_channelsCreated) {
      await _ensureAndroidNotificationChannels();
    }

    final channelId = switch (payload.eventType) {
      'new_matchmaking_request' ||
      'accepted_matchmaking_request' ||
      'rejected_matchmaking_request' =>
        'matchmaking_requests',
      'new_private_message' => 'private_messages',
      'subscription_activated' ||
      'subscription_expiring_soon' ||
      'subscription_expired' =>
        'subscription_updates',
      _ => 'announcements',
    };

    final channelName = switch (channelId) {
      'matchmaking_requests' => 'طلبات التعارف',
      'private_messages' => 'الرسائل الخاصة',
      'subscription_updates' => 'تحديثات الاشتراك',
      _ => 'الإعلانات العامة',
    };

    try {
      await _localNotifications.show(
        payload.eventId.hashCode,
        payload.titleAr,
        payload.bodyAr,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: channelId == 'announcements'
                ? Importance.defaultImportance
                : Importance.high,
            priority: channelId == 'announcements'
                ? Priority.defaultPriority
                : Priority.high,
            visibility: NotificationVisibility.private,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _ensureAndroidNotificationChannels() async {
    if (_channelsCreated) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit),
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        for (final channel in androidChannels) {
          await androidPlugin.createNotificationChannel(channel);
        }
      }
      _channelsCreated = true;
    } catch (_) {}
  }

  NotificationPermissionStatus _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        NotificationPermissionStatus.granted,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      AuthorizationStatus.notDetermined =>
        NotificationPermissionStatus.notDetermined,
    };
  }

  void _updatePermissionStatus(NotificationPermissionStatus next) {
    _permissionStatus = next;
    _permissionController.add(next);
  }

  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _foregroundController.close();
    _tapController.close();
    _permissionController.close();
  }
}
