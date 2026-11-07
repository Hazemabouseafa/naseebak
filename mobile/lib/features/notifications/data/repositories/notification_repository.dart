import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/notification_model.dart';

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepository(apiClient: ref.watch(apiClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(apiClient: ref.watch(apiClientProvider));
});

class DeviceTokenRepository {
  final ApiClient _apiClient;

  const DeviceTokenRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// POST /api/v1/devices/register
  /// Associates the current device's FCM registration token with the authenticated Laravel user.
  /// Never logs raw FCM tokens.
  Future<void> registerDeviceToken({
    required String fcmToken,
    String devicePlatform = 'android',
    String? deviceModel,
    String? appVersion,
    String? osVersion,
  }) async {
    final trimmed = fcmToken.trim();
    if (trimmed.isEmpty) return;

    await _apiClient.dio.post<Map<String, dynamic>>(
      ApiEndpoints.devicesRegister,
      data: {
        'fcm_token': trimmed,
        'device_platform': devicePlatform,
        if (deviceModel != null) 'device_model': deviceModel,
        if (appVersion != null) 'app_version': appVersion,
        if (osVersion != null) 'os_version': osVersion,
      },
    );
  }

  /// DELETE /api/v1/devices/unregister
  /// Unregisters the current device token when the user signs out.
  Future<void> unregisterDeviceToken({String? fcmToken}) async {
    await _apiClient.dio.delete<Map<String, dynamic>>(
      ApiEndpoints.devicesUnregister,
      data: {
        if (fcmToken != null && fcmToken.trim().isNotEmpty)
          'fcm_token': fcmToken.trim(),
      },
    );
  }
}

class NotificationRepository {
  final ApiClient _apiClient;
  final Set<int> _localReadIds = <int>{};
  final Set<int> _localDeletedIds = <int>{};

  NotificationRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map) {
      final inner = body['data'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
      return Map<String, dynamic>.from(body);
    }
    return const <String, dynamic>{};
  }

  /// GET /api/v1/notifications
  Future<PaginatedNotificationsResponse> fetchNotifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    final response = await _apiClient.dio.get<dynamic>(
      ApiEndpoints.notifications,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (unreadOnly) 'unread_only': 1,
      },
    );

    final data = _extractDataMap(response.data);
    final parsed = PaginatedNotificationsResponse.fromJson(data);

    if (page == 1 && parsed.notifications.isEmpty) {
      final fallbackItems = await _buildClientActivityNotifications();
      if (fallbackItems.isNotEmpty) {
        final unread = fallbackItems.where((n) => !n.isRead).length;
        return PaginatedNotificationsResponse(
          notifications: fallbackItems,
          unreadCount: unread,
          currentPage: 1,
          lastPage: 1,
          perPage: perPage,
          total: fallbackItems.length,
          hasMorePages: false,
        );
      }
    }

    return parsed;
  }

  /// Builds real activity notifications from matchmaking requests, conversations,
  /// and active subscription if the server `notifications` table returned empty.
  Future<List<NotificationItemModel>> _buildClientActivityNotifications() async {
    final synthesized = <NotificationItemModel>[];

    // 1. Matchmaking requests (incoming pending & accepted)
    try {
      final reqRes = await _apiClient.dio.get<dynamic>(
        ApiEndpoints.matchmakingRequests,
      );
      final reqData = _extractDataMap(reqRes.data);
      final incomingList = (reqData['incoming'] as List<dynamic>?) ?? const [];
      for (final raw in incomingList.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        final reqId = int.tryParse('${map['id'] ?? 0}') ?? 0;
        final status = (map['status'] ?? 'pending').toString();
        if (reqId <= 0 || status != 'pending') continue;
        final synthId = -(100000 + reqId);
        if (_localDeletedIds.contains(synthId)) continue;
        final member = map['member'] is Map
            ? Map<String, dynamic>.from(map['member'] as Map)
            : const <String, dynamic>{};
        final name = (member['full_name'] ?? '').toString().trim();
        synthesized.add(
          NotificationItemModel(
            id: synthId,
            eventId: 'synth_match_in_$reqId',
            eventType: 'new_matchmaking_request',
            titleAr: 'طلب تعارف جديد',
            bodyAr: name.isNotEmpty
                ? 'أرسل لك "$name" طلب تعارف جديد.'
                : 'لديك طلب تعارف جديد بانتظار ردك.',
            actionRoute: 'matchmaking_requests_incoming',
            referenceType: 'matchmaking_request',
            referenceId: reqId,
            routingMetadata: {'request_id': reqId, 'tab': 'incoming'},
            isRead: _localReadIds.contains(synthId),
            createdAt: map['created_at']?.toString(),
          ),
        );
      }

      final acceptedList = (reqData['accepted'] as List<dynamic>?) ?? const [];
      for (final raw in acceptedList.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        final reqId = int.tryParse('${map['id'] ?? 0}') ?? 0;
        if (reqId <= 0) continue;
        final synthId = -(200000 + reqId);
        if (_localDeletedIds.contains(synthId)) continue;
        final convId = int.tryParse('${map['conversation_id'] ?? ''}');
        final member = map['member'] is Map
            ? Map<String, dynamic>.from(map['member'] as Map)
            : const <String, dynamic>{};
        final name = (member['full_name'] ?? '').toString().trim();
        synthesized.add(
          NotificationItemModel(
            id: synthId,
            eventId: 'synth_match_acc_$reqId',
            eventType: 'accepted_matchmaking_request',
            titleAr: 'تمت الموافقة على طلب التعارف',
            bodyAr: name.isNotEmpty
                ? 'تم فتح محادثة خاصة للتعارف مع "$name".'
                : 'تمت الموافقة على طلب التعارف وفتح المحادثة الخاصة.',
            actionRoute:
                convId != null ? 'conversation' : 'matchmaking_requests_incoming',
            referenceType: convId != null ? 'conversation' : 'matchmaking_request',
            referenceId: convId ?? reqId,
            routingMetadata: {
              'request_id': reqId,
              if (convId != null) 'conversation_id': convId,
              'tab': 'accepted',
            },
            isRead: _localReadIds.contains(synthId),
            createdAt: (map['responded_at'] ?? map['created_at'])?.toString(),
          ),
        );
      }
    } catch (_) {}

    // 2. Conversations with unread messages
    try {
      final convRes = await _apiClient.dio.get<dynamic>(
        ApiEndpoints.conversations,
      );
      final convData = _extractDataMap(convRes.data);
      final convList = (convData['conversations'] as List<dynamic>?) ?? const [];
      for (final raw in convList.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        final convId = int.tryParse('${map['id'] ?? 0}') ?? 0;
        final unread = int.tryParse('${map['unread_count'] ?? 0}') ?? 0;
        if (convId <= 0 || unread <= 0) continue;
        final synthId = -(300000 + convId);
        if (_localDeletedIds.contains(synthId)) continue;
        final other = map['other_member'] is Map
            ? Map<String, dynamic>.from(map['other_member'] as Map)
            : const <String, dynamic>{};
        final name = (other['full_name'] ?? '').toString().trim();
        synthesized.add(
          NotificationItemModel(
            id: synthId,
            eventId: 'synth_conv_msg_$convId',
            eventType: 'new_private_message',
            titleAr: 'رسالة جديدة',
            bodyAr: name.isNotEmpty
                ? 'لديك رسالة جديدة من "$name" في المحادثة الخاصة.'
                : 'لديك رسالة جديدة في المحادثة الخاصة.',
            actionRoute: 'conversation',
            referenceType: 'conversation',
            referenceId: convId,
            routingMetadata: {'conversation_id': convId},
            isRead: _localReadIds.contains(synthId),
            createdAt: map['last_message_at']?.toString(),
          ),
        );
      }
    } catch (_) {}

    // 3. Active Subscription notification
    try {
      final subRes = await _apiClient.dio.get<dynamic>(
        ApiEndpoints.subscription,
      );
      final subData = _extractDataMap(subRes.data);
      final entitlement = subData['entitlement'] is Map
          ? Map<String, dynamic>.from(subData['entitlement'] as Map)
          : const <String, dynamic>{};
      final currentSub = subData['subscription'] is Map
          ? Map<String, dynamic>.from(subData['subscription'] as Map)
          : const <String, dynamic>{};
      final isEntitled = entitlement['has_active_subscription'] == true;
      final subId = int.tryParse('${currentSub['id'] ?? 1}') ?? 1;
      final synthId = -(400000 + subId);
      if (isEntitled && !_localDeletedIds.contains(synthId)) {
        synthesized.add(
          NotificationItemModel(
            id: synthId,
            eventId: 'synth_sub_active_$subId',
            eventType: 'subscription_activated',
            titleAr: 'تم تفعيل اشتراكك',
            bodyAr: 'عضويتك المميزة في نصيبك بلس نشطة الآن ويمكنك التواصل بحرية.',
            actionRoute: 'subscription',
            referenceType: 'subscription',
            referenceId: subId,
            routingMetadata: {'reference_id': subId},
            isRead: _localReadIds.contains(synthId),
            createdAt: currentSub['starts_at']?.toString(),
          ),
        );
      }
    } catch (_) {}

    return synthesized;
  }

  /// GET /api/v1/notifications/unread-count
  Future<int> fetchUnreadCount() async {
    final response = await _apiClient.dio.get<dynamic>(
      ApiEndpoints.notificationsUnreadCount,
    );
    final data = _extractDataMap(response.data);
    final raw = data['unread_count'];
    return raw is num ? raw.toInt() : (int.tryParse('${raw ?? 0}') ?? 0);
  }

  /// POST /api/v1/notifications/{notification}/read
  Future<({NotificationItemModel notification, int unreadCount})> markAsRead(
    int notificationId,
  ) async {
    if (notificationId <= 0) {
      _localReadIds.add(notificationId);
      final fallback = await _buildClientActivityNotifications();
      final matched = fallback.where((n) => n.id == notificationId).firstOrNull ??
          NotificationItemModel(
            id: notificationId,
            titleAr: 'إشعار',
            bodyAr: '',
            isRead: true,
          );
      final unread = fallback.where((n) => !n.isRead).length;
      return (notification: matched.copyWith(isRead: true), unreadCount: unread);
    }

    final response = await _apiClient.dio.post<dynamic>(
      ApiEndpoints.notificationMarkRead(notificationId),
    );
    final data = _extractDataMap(response.data);
    final rawNotif = data['notification'];
    final notifMap = rawNotif is Map
        ? Map<String, dynamic>.from(rawNotif)
        : const <String, dynamic>{};
    final rawUnread = data['unread_count'];

    return (
      notification: NotificationItemModel.fromJson(notifMap),
      unreadCount: rawUnread is num
          ? rawUnread.toInt()
          : (int.tryParse('${rawUnread ?? 0}') ?? 0),
    );
  }

  /// POST /api/v1/notifications/read-all
  Future<int> markAllAsRead() async {
    final response = await _apiClient.dio.post<dynamic>(
      ApiEndpoints.notificationsReadAll,
    );
    final data = _extractDataMap(response.data);
    final rawCount = data['updated_count'];
    return rawCount is num
        ? rawCount.toInt()
        : (int.tryParse('${rawCount ?? 0}') ?? 0);
  }

  /// DELETE /api/v1/notifications/{notification}
  Future<int> deleteNotification(int notificationId) async {
    if (notificationId <= 0) {
      _localDeletedIds.add(notificationId);
      _localReadIds.add(notificationId);
      final fallback = await _buildClientActivityNotifications();
      return fallback.where((n) => !n.isRead).length;
    }

    final response = await _apiClient.dio.delete<dynamic>(
      ApiEndpoints.notificationDelete(notificationId),
    );
    final data = _extractDataMap(response.data);
    final rawUnread = data['unread_count'];
    return rawUnread is num
        ? rawUnread.toInt()
        : (int.tryParse('${rawUnread ?? 0}') ?? 0);
  }

  /// GET /api/v1/notification-preferences
  Future<NotificationPreferencesModel> fetchPreferences() async {
    final response = await _apiClient.dio.get<dynamic>(
      ApiEndpoints.notificationPreferences,
    );
    final data = _extractDataMap(response.data);
    final rawPrefs = data['preferences'];
    final prefsMap = rawPrefs is Map
        ? Map<String, dynamic>.from(rawPrefs)
        : const <String, dynamic>{};
    return NotificationPreferencesModel.fromJson(prefsMap);
  }

  /// PATCH /api/v1/notification-preferences
  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    final response = await _apiClient.dio.patch<dynamic>(
      ApiEndpoints.notificationPreferences,
      data: preferences.toJson(),
    );
    final data = _extractDataMap(response.data);
    final rawPrefs = data['preferences'];
    final prefsMap = rawPrefs is Map
        ? Map<String, dynamic>.from(rawPrefs)
        : const <String, dynamic>{};
    return NotificationPreferencesModel.fromJson(prefsMap);
  }
}
