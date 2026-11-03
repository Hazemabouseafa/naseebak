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

  const NotificationRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// GET /api/v1/notifications
  Future<PaginatedNotificationsResponse> fetchNotifications({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
      queryParameters: {
        'page': page,
        'per_page': perPage,
      },
    );

    final data = (response.data?['data'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return PaginatedNotificationsResponse.fromJson(data);
  }

  /// GET /api/v1/notifications/unread-count
  Future<int> fetchUnreadCount() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      ApiEndpoints.notificationsUnreadCount,
    );
    final data = (response.data?['data'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }

  /// POST /api/v1/notifications/{notification}/read
  Future<({NotificationItemModel notification, int unreadCount})> markAsRead(
    int notificationId,
  ) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      ApiEndpoints.notificationMarkRead(notificationId),
    );
    final data = (response.data?['data'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final rawNotif =
        data['notification'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return (
      notification: NotificationItemModel.fromJson(rawNotif),
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// POST /api/v1/notifications/read-all
  Future<int> markAllAsRead() async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      ApiEndpoints.notificationsReadAll,
    );
    final data = (response.data?['data'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return (data['updated_count'] as num?)?.toInt() ?? 0;
  }

  /// DELETE /api/v1/notifications/{notification}
  Future<int> deleteNotification(int notificationId) async {
    final response = await _apiClient.dio.delete<Map<String, dynamic>>(
      ApiEndpoints.notificationDelete(notificationId),
    );
    final data = (response.data?['data'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }

  /// GET /api/v1/notification-preferences
  Future<NotificationPreferencesModel> fetchPreferences() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      ApiEndpoints.notificationPreferences,
    );
    final data = (response.data?['data'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final rawPrefs =
        data['preferences'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return NotificationPreferencesModel.fromJson(rawPrefs);
  }

  /// PATCH /api/v1/notification-preferences
  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      ApiEndpoints.notificationPreferences,
      data: preferences.toJson(),
    );
    final data = (response.data?['data'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final rawPrefs =
        data['preferences'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return NotificationPreferencesModel.fromJson(rawPrefs);
  }
}
