import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../messaging/data/services/realtime_messaging_service.dart';
import '../../../messaging/presentation/providers/messaging_provider.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/push_notification_service.dart';

class NotificationState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<NotificationItemModel> notifications;
  final int unreadCount;
  final int currentPage;
  final bool hasMorePages;
  final String? errorMessage;

  final bool isLoadingPreferences;
  final bool isSavingPreferences;
  final NotificationPreferencesModel preferences;
  final String? preferencesError;

  final NotificationPermissionStatus permissionStatus;
  final bool permissionBannerDismissed;

  const NotificationState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.currentPage = 1,
    this.hasMorePages = false,
    this.errorMessage,
    this.isLoadingPreferences = false,
    this.isSavingPreferences = false,
    this.preferences = const NotificationPreferencesModel(),
    this.preferencesError,
    this.permissionStatus = NotificationPermissionStatus.notDetermined,
    this.permissionBannerDismissed = false,
  });

  NotificationState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<NotificationItemModel>? notifications,
    int? unreadCount,
    int? currentPage,
    bool? hasMorePages,
    String? errorMessage,
    bool clearError = false,
    bool? isLoadingPreferences,
    bool? isSavingPreferences,
    NotificationPreferencesModel? preferences,
    String? preferencesError,
    bool clearPreferencesError = false,
    NotificationPermissionStatus? permissionStatus,
    bool? permissionBannerDismissed,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      currentPage: currentPage ?? this.currentPage,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoadingPreferences: isLoadingPreferences ?? this.isLoadingPreferences,
      isSavingPreferences: isSavingPreferences ?? this.isSavingPreferences,
      preferences: preferences ?? this.preferences,
      preferencesError: clearPreferencesError
          ? null
          : (preferencesError ?? this.preferencesError),
      permissionStatus: permissionStatus ?? this.permissionStatus,
      permissionBannerDismissed:
          permissionBannerDismissed ?? this.permissionBannerDismissed,
    );
  }

  bool get isMarkingAllRead => isLoading;
  bool get isUpdatingPreferences => isSavingPreferences;
  bool get isSystemPermissionGranted =>
      permissionStatus == NotificationPermissionStatus.granted;
}

typedef NotificationCenterState = NotificationState;

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(
    repository: ref.watch(notificationRepositoryProvider),
    pushService: ref.watch(pushNotificationServiceProvider),
    realtimeService: ref.watch(realtimeMessagingServiceProvider),
    readActiveConversationId: () =>
        ref.read(messagingProvider).activeConversationId,
  );
});

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  final PushNotificationService _pushService;
  final RealtimeMessagingService _realtimeService;
  final int? Function() _readActiveConversationId;

  StreamSubscription<ReverbEventMessage>? _reverbSub;
  StreamSubscription<IncomingPushPayload>? _foregroundPushSub;
  StreamSubscription<NotificationPermissionStatus>? _permissionSub;

  NotificationNotifier({
    required NotificationRepository repository,
    required PushNotificationService pushService,
    required RealtimeMessagingService realtimeService,
    required int? Function() readActiveConversationId,
  })  : _repository = repository,
        _pushService = pushService,
        _realtimeService = realtimeService,
        _readActiveConversationId = readActiveConversationId,
        super(NotificationState(
          permissionStatus: pushService.permissionStatus,
        )) {
    _reverbSub = _realtimeService.eventsStream.listen(_handleReverbEvent);
    _foregroundPushSub =
        _pushService.foregroundPushStream.listen(_handleForegroundPush);
    _permissionSub = _pushService.permissionStatusStream.listen((nextStatus) {
      state = state.copyWith(permissionStatus: nextStatus);
    });
  }

  /// Initializes FCM channels, listeners, and registers the current device token after sign-in.
  Future<void> initializeForAuthenticatedUser() async {
    await _pushService.initialize();
    state = state.copyWith(permissionStatus: _pushService.permissionStatus);
    await _pushService.synchronizeDeviceTokenForAuthenticatedUser();
    await refreshUnreadCount();
  }

  /// Requests Android 13+ runtime notification permission when user taps "تفعيل الإشعارات".
  Future<NotificationPermissionStatus> requestPermission() async {
    final status = await _pushService.requestNotificationPermission();
    state = state.copyWith(permissionStatus: status);
    if (status == NotificationPermissionStatus.granted) {
      await _pushService.synchronizeDeviceTokenForAuthenticatedUser();
    }
    return status;
  }

  void dismissPermissionBanner() {
    state = state.copyWith(permissionBannerDismissed: true);
  }

  Future<NotificationPermissionStatus> requestNotificationPermission() =>
      requestPermission();

  Future<void> fetchNotifications({
    bool refresh = false,
    bool loadMore = false,
  }) =>
      loadNotifications(loadMore: loadMore);

  Future<void> markNotificationAsRead(int notificationId) =>
      markAsRead(notificationId);

  Future<void> markAllNotificationsAsRead() => markAllAsRead();

  Future<void> loadNotifications({bool loadMore = false}) async {
    if (loadMore) {
      if (state.isLoading || state.isLoadingMore || !state.hasMorePages) {
        return;
      }
      state = state.copyWith(isLoadingMore: true, clearError: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    final targetPage = loadMore ? state.currentPage + 1 : 1;

    try {
      final res = await _repository.fetchNotifications(page: targetPage);
      final merged = loadMore
          ? _deduplicateNotifications([
              ...state.notifications,
              ...res.notifications,
            ])
          : res.notifications;

      for (final item in res.notifications) {
        _pushService.markEventSeenIfNew(item.eventId);
      }

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        notifications: merged,
        unreadCount: res.unreadCount,
        currentPage: res.currentPage,
        hasMorePages: res.hasMorePages,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: _extractError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: 'تعذر تحميل قائمة الإشعارات حالياً.',
      );
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _repository.fetchUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final res = await _repository.markAsRead(notificationId);
      final updatedList = state.notifications.map((n) {
        if (n.id == notificationId) {
          return res.notification;
        }
        return n;
      }).toList();

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: res.unreadCount,
      );
    } catch (_) {
      // Optimistic local fallback
      final updatedList = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      final nextUnread =
          updatedList.where((n) => !n.isRead).length;
      state = state.copyWith(
        notifications: updatedList,
        unreadCount: nextUnread,
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      final updatedList =
          state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(
        notifications: updatedList,
        unreadCount: 0,
      );
    } on DioException catch (e) {
      state = state.copyWith(errorMessage: _extractError(e));
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'تعذر تحديث حالة الإشعارات حالياً.',
      );
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      final unreadCount = await _repository.deleteNotification(notificationId);
      final remaining =
          state.notifications.where((n) => n.id != notificationId).toList();
      state = state.copyWith(
        notifications: remaining,
        unreadCount: unreadCount,
      );
    } on DioException catch (e) {
      state = state.copyWith(errorMessage: _extractError(e));
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'تعذر حذف الإشعار حالياً.',
      );
    }
  }

  Future<void> loadPreferences() async {
    state = state.copyWith(
      isLoadingPreferences: true,
      clearPreferencesError: true,
    );
    try {
      final prefs = await _repository.fetchPreferences();
      state = state.copyWith(
        isLoadingPreferences: false,
        preferences: prefs,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoadingPreferences: false,
        preferencesError: _extractError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingPreferences: false,
        preferencesError: 'تعذر تحميل إعدادات الإشعارات.',
      );
    }
  }

  Future<bool> updatePreferences({
    NotificationPreferencesModel? updated,
    bool? matchmakingRequestsEnabled,
    bool? messagesEnabled,
    bool? subscriptionsEnabled,
    bool? announcementsEnabled,
  }) async {
    final targetPrefs = updated ??
        state.preferences.copyWith(
          matchmakingRequestsEnabled: matchmakingRequestsEnabled,
          messagesEnabled: messagesEnabled,
          subscriptionsEnabled: subscriptionsEnabled,
          announcementsEnabled: announcementsEnabled,
        );
    state = state.copyWith(
      isSavingPreferences: true,
      preferences: targetPrefs,
      clearPreferencesError: true,
    );
    try {
      final saved = await _repository.updatePreferences(targetPrefs);
      state = state.copyWith(
        isSavingPreferences: false,
        preferences: saved,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSavingPreferences: false,
        preferencesError: _extractError(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSavingPreferences: false,
        preferencesError: 'تعذر حفظ إعدادات الإشعارات حالياً.',
      );
      return false;
    }
  }

  /// Unregisters the device token and clears all user-specific notification state on logout.
  Future<void> cleanupOnLogout() async {
    await _pushService.unregisterDeviceOnLogout();
    state = const NotificationState();
  }

  void _handleReverbEvent(ReverbEventMessage event) {
    if (event.event != 'notification.created') return;

    final incoming = NotificationItemModel.fromJson(event.data);
    if (!_pushService.markEventSeenIfNew(incoming.eventId)) {
      return;
    }

    // If the user is actively viewing the exact conversation for this new message notification,
    // suppress duplicate unread badge / alert and mark it read automatically.
    final activeConvId = _readActiveConversationId();
    final notifConvId =
        (incoming.routingMetadata['conversation_id'] as num?)?.toInt() ??
            incoming.referenceId;

    if (incoming.eventType == 'new_private_message' &&
        activeConvId != null &&
        notifConvId == activeConvId) {
      final readItem = incoming.copyWith(isRead: true);
      state = state.copyWith(
        notifications: _deduplicateNotifications([
          readItem,
          ...state.notifications,
        ]),
      );
      if (incoming.id > 0) {
        _repository.markAsRead(incoming.id);
      }
      return;
    }

    state = state.copyWith(
      notifications: _deduplicateNotifications([
        incoming,
        ...state.notifications,
      ]),
      unreadCount: state.unreadCount + (incoming.isRead ? 0 : 1),
    );
  }

  void _handleForegroundPush(IncomingPushPayload payload) {
    // Event-ID deduplication prevents duplicate alerts when both Reverb and FCM deliver the same event
    if (!_pushService.markEventSeenIfNew(payload.eventId)) {
      return;
    }

    final activeConvId = _readActiveConversationId();
    final rawConvId = payload.routingMetadata['conversation_id'];
    final notifConvId =
        rawConvId is int ? rawConvId : int.tryParse('${rawConvId ?? ''}');

    if (payload.eventType == 'new_private_message' &&
        activeConvId != null &&
        notifConvId == activeConvId) {
      return;
    }

    final item = NotificationItemModel(
      id: payload.notificationId ?? DateTime.now().millisecondsSinceEpoch,
      eventId: payload.eventId,
      eventType: payload.eventType,
      titleAr: payload.titleAr,
      bodyAr: payload.bodyAr,
      actionRoute: payload.actionRoute,
      routingMetadata: payload.routingMetadata,
      isRead: false,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    state = state.copyWith(
      notifications: _deduplicateNotifications([
        item,
        ...state.notifications,
      ]),
      unreadCount: state.unreadCount + 1,
    );

    _pushService.showForegroundSystemNotification(payload);
  }

  List<NotificationItemModel> _deduplicateNotifications(
    List<NotificationItemModel> items,
  ) {
    final byKey = <String, NotificationItemModel>{};
    for (final item in items) {
      final key = item.eventId.isNotEmpty ? 'evt:${item.eventId}' : 'id:${item.id}';
      byKey.putIfAbsent(key, () => item);
    }
    return byKey.values.toList();
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'تعذر الاتصال بخادم نَصِيبُكَ. يرجى التحقق من اتصال الإنترنت.';
  }

  @override
  void dispose() {
    _reverbSub?.cancel();
    _foregroundPushSub?.cancel();
    _permissionSub?.cancel();
    super.dispose();
  }
}
