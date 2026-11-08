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
  bool _allLocalMarkedRead = false;

  NotificationRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  bool _isSynthRead(int synthId, {bool defaultRead = false}) {
    if (_allLocalMarkedRead || _localReadIds.contains(synthId)) {
      return true;
    }
    return defaultRead;
  }

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
    PaginatedNotificationsResponse? parsed;
    try {
      final response = await _apiClient.dio.get<dynamic>(
        ApiEndpoints.notifications,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (unreadOnly) 'unread_only': 1,
        },
      );

      final data = _extractDataMap(response.data);
      parsed = PaginatedNotificationsResponse.fromJson(data);
    } catch (_) {
      parsed = null;
    }

    if (page == 1 && !unreadOnly) {
      final fallbackItems = await _buildClientActivityNotifications();
      final serverItems = parsed?.notifications ?? const <NotificationItemModel>[];

      if (serverItems.isEmpty && fallbackItems.isEmpty) {
        return parsed ??
            PaginatedNotificationsResponse(
              notifications: const [],
              unreadCount: 0,
              currentPage: 1,
              lastPage: 1,
              perPage: perPage,
              total: 0,
              hasMorePages: false,
            );
      }

      final merged = _mergeServerAndClientNotifications(
        serverItems: serverItems,
        clientItems: fallbackItems,
      );
      final computedUnread = merged.where((n) => !n.isRead).length;
      final serverUnread = parsed?.unreadCount ?? 0;
      final effectiveUnread =
          computedUnread > serverUnread ? computedUnread : serverUnread;

      return PaginatedNotificationsResponse(
        notifications: merged,
        unreadCount: effectiveUnread,
        currentPage: parsed?.currentPage ?? 1,
        lastPage: parsed?.lastPage ?? 1,
        perPage: parsed?.perPage ?? perPage,
        total: merged.length > (parsed?.total ?? 0)
            ? merged.length
            : (parsed?.total ?? merged.length),
        hasMorePages: parsed?.hasMorePages ?? false,
      );
    }

    if (parsed != null) {
      return parsed;
    }

    return PaginatedNotificationsResponse(
      notifications: const [],
      unreadCount: 0,
      currentPage: page,
      lastPage: page,
      perPage: perPage,
      total: 0,
      hasMorePages: false,
    );
  }

  List<NotificationItemModel> _mergeServerAndClientNotifications({
    required List<NotificationItemModel> serverItems,
    required List<NotificationItemModel> clientItems,
  }) {
    final result = <NotificationItemModel>[...serverItems];
    final seenSemanticKeys = <String>{};

    for (final s in serverItems) {
      if (s.referenceType != null && s.referenceId != null) {
        seenSemanticKeys.add('${s.eventType}:${s.referenceType}:${s.referenceId}');
      }
      seenSemanticKeys.add('title:${s.titleAr.trim()}');
    }

    for (final c in clientItems) {
      final semKey = (c.referenceType != null && c.referenceId != null)
          ? '${c.eventType}:${c.referenceType}:${c.referenceId}'
          : null;
      if (semKey != null && seenSemanticKeys.contains(semKey)) {
        continue;
      }
      if (c.referenceType == 'welcome' &&
          seenSemanticKeys.contains('title:${c.titleAr.trim()}')) {
        continue;
      }
      result.add(c);
      if (semKey != null) {
        seenSemanticKeys.add(semKey);
      }
    }

    return result;
  }

  /// Builds real activity notifications from matchmaking requests, conversations,
  /// active subscription, and profile/account status so the Notification Center
  /// always displays complete, up-to-date notifications.
  Future<List<NotificationItemModel>> _buildClientActivityNotifications() async {
    final synthesized = <NotificationItemModel>[];

    final results = await Future.wait<dynamic>([
      _apiClient.dio
          .get<dynamic>(ApiEndpoints.matchmakingRequests)
          .then<dynamic>((r) => r.data)
          .catchError((_) => null),
      _apiClient.dio
          .get<dynamic>(ApiEndpoints.conversations)
          .then<dynamic>((r) => r.data)
          .catchError((_) => null),
      _apiClient.dio
          .get<dynamic>(ApiEndpoints.subscription)
          .then<dynamic>((r) => r.data)
          .catchError((_) => null),
      _apiClient.dio
          .get<dynamic>(ApiEndpoints.profile)
          .then<dynamic>((r) => r.data)
          .catchError((_) => null),
    ]);

    final rawReqBody = results[0];
    final rawConvBody = results[1];
    final rawSubBody = results[2];
    final rawProfBody = results[3];

    // 1. Matchmaking requests (incoming, accepted, sent)
    if (rawReqBody != null) {
      try {
        final reqData = _extractDataMap(rawReqBody);
        final incomingList = (reqData['incoming'] as List<dynamic>?) ?? const [];
        for (final raw in incomingList.whereType<Map>()) {
          final map = Map<String, dynamic>.from(raw);
          final reqId = int.tryParse('${map['id'] ?? 0}') ?? 0;
          final status = (map['status'] ?? 'pending').toString();
          if (reqId <= 0) continue;
          final synthId = -(100000 + reqId);
          if (_localDeletedIds.contains(synthId)) continue;
          final member = map['member'] is Map
              ? Map<String, dynamic>.from(map['member'] as Map)
              : const <String, dynamic>{};
          final name = (member['full_name'] ?? '').toString().trim();

          if (status == 'pending') {
            synthesized.add(
              NotificationItemModel(
                id: synthId,
                eventId: 'synth_match_in_$reqId',
                eventType: 'new_matchmaking_request',
                titleAr: 'طلب تعارف جديد',
                bodyAr: name.isNotEmpty
                    ? 'أرسل لك "$name" طلب تعارف جديد بانتظار ردك.'
                    : 'لديك طلب تعارف جديد بانتظار ردك.',
                actionRoute: 'matchmaking_requests_incoming',
                referenceType: 'matchmaking_request',
                referenceId: reqId,
                routingMetadata: {'request_id': reqId, 'tab': 'incoming'},
                isRead: _isSynthRead(synthId),
                createdAt: map['created_at']?.toString(),
              ),
            );
          } else if (status == 'rejected') {
            synthesized.add(
              NotificationItemModel(
                id: synthId,
                eventId: 'synth_match_in_rej_$reqId',
                eventType: 'rejected_matchmaking_request',
                titleAr: 'طلب تعارف سابق',
                bodyAr: name.isNotEmpty
                    ? 'تم الاعتذار عن طلب التعارف الوارد من "$name".'
                    : 'تم الاعتذار عن طلب التعارف الوارد.',
                actionRoute: 'matchmaking_requests_incoming',
                referenceType: 'matchmaking_request',
                referenceId: reqId,
                routingMetadata: {'request_id': reqId, 'tab': 'incoming'},
                isRead: _isSynthRead(synthId, defaultRead: true),
                createdAt: (map['responded_at'] ?? map['created_at'])?.toString(),
              ),
            );
          }
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
              actionRoute: convId != null
                  ? 'conversation'
                  : 'matchmaking_requests_incoming',
              referenceType:
                  convId != null ? 'conversation' : 'matchmaking_request',
              referenceId: convId ?? reqId,
              routingMetadata: {
                'request_id': reqId,
                if (convId != null) 'conversation_id': convId,
                'tab': 'accepted',
              },
              isRead: _isSynthRead(synthId),
              createdAt: (map['responded_at'] ?? map['created_at'])?.toString(),
            ),
          );
        }

        final sentList = (reqData['sent'] as List<dynamic>?) ?? const [];
        for (final raw in sentList.whereType<Map>()) {
          final map = Map<String, dynamic>.from(raw);
          final reqId = int.tryParse('${map['id'] ?? 0}') ?? 0;
          final status = (map['status'] ?? 'pending').toString();
          if (reqId <= 0) continue;
          final synthId = -(250000 + reqId);
          if (_localDeletedIds.contains(synthId)) continue;
          final member = map['member'] is Map
              ? Map<String, dynamic>.from(map['member'] as Map)
              : const <String, dynamic>{};
          final name = (member['full_name'] ?? '').toString().trim();

          if (status == 'pending') {
            synthesized.add(
              NotificationItemModel(
                id: synthId,
                eventId: 'synth_match_sent_$reqId',
                eventType: 'new_matchmaking_request',
                titleAr: 'تم إرسال طلب التعارف',
                bodyAr: name.isNotEmpty
                    ? 'تم إرسال طلب التعارف إلى "$name" بنجاح وهو قيد الانتظار.'
                    : 'تم إرسال طلب التعارف بنجاح وهو قيد الانتظار.',
                actionRoute: 'matchmaking_requests_sent',
                referenceType: 'matchmaking_request',
                referenceId: reqId,
                routingMetadata: {'request_id': reqId, 'tab': 'sent'},
                isRead: _isSynthRead(synthId),
                createdAt: map['created_at']?.toString(),
              ),
            );
          } else if (status == 'rejected') {
            synthesized.add(
              NotificationItemModel(
                id: synthId,
                eventId: 'synth_match_rej_$reqId',
                eventType: 'rejected_matchmaking_request',
                titleAr: 'تحديث طلب التعارف',
                bodyAr: name.isNotEmpty
                    ? 'هناك تحديث بخصوص طلب التعارف المرسل إلى "$name".'
                    : 'هناك تحديث بخصوص طلب التعارف المرسل.',
                actionRoute: 'matchmaking_requests_sent',
                referenceType: 'matchmaking_request',
                referenceId: reqId,
                routingMetadata: {'request_id': reqId, 'tab': 'sent'},
                isRead: _isSynthRead(synthId),
                createdAt: (map['responded_at'] ?? map['created_at'])?.toString(),
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 2. Conversations & messages (both unread and active conversations)
    if (rawConvBody != null) {
      try {
        final convData = _extractDataMap(rawConvBody);
        final convList =
            (convData['conversations'] as List<dynamic>?) ?? const [];
        for (final raw in convList.whereType<Map>()) {
          final map = Map<String, dynamic>.from(raw);
          final convId = int.tryParse('${map['id'] ?? 0}') ?? 0;
          if (convId <= 0) continue;
          final unread = int.tryParse('${map['unread_count'] ?? 0}') ?? 0;
          final lastMsg = map['last_message'] is Map
              ? Map<String, dynamic>.from(map['last_message'] as Map)
              : null;
          if (unread <= 0 && lastMsg == null) continue;

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
              titleAr: unread > 0 ? 'رسالة جديدة' : 'محادثة خاصة نشطة',
              bodyAr: name.isNotEmpty
                  ? (unread > 0
                      ? 'لديك رسالة جديدة من "$name" في المحادثة الخاصة.'
                      : 'توجد رسائل متبادلة مع "$name" في المحادثة الخاصة.')
                  : 'لديك رسالة جديدة في المحادثة الخاصة.',
              actionRoute: 'conversation',
              referenceType: 'conversation',
              referenceId: convId,
              routingMetadata: {'conversation_id': convId},
              isRead: _isSynthRead(synthId, defaultRead: unread <= 0),
              createdAt: (map['last_message_at'] ?? lastMsg?['created_at'])
                  ?.toString(),
            ),
          );
        }
      } catch (_) {}
    }

    // 3. Subscription notification (from /subscription or /profile entitlement)
    bool addedSubscriptionNotif = false;
    if (rawSubBody != null) {
      try {
        final subData = _extractDataMap(rawSubBody);
        final entitlement = subData['entitlement'] is Map
            ? Map<String, dynamic>.from(subData['entitlement'] as Map)
            : const <String, dynamic>{};
        final currentSub = subData['subscription'] is Map
            ? Map<String, dynamic>.from(subData['subscription'] as Map)
            : const <String, dynamic>{};
        final isEntitled = entitlement['has_active_subscription'] == true ||
            currentSub['is_currently_entitled'] == true ||
            currentSub['status'] == 'active';
        final subId = int.tryParse('${currentSub['id'] ?? 1}') ?? 1;
        final synthId = -(400000 + subId);
        if (isEntitled && !_localDeletedIds.contains(synthId)) {
          synthesized.add(
            NotificationItemModel(
              id: synthId,
              eventId: 'synth_sub_active_$subId',
              eventType: 'subscription_activated',
              titleAr: 'تم تفعيل اشتراكك',
              bodyAr:
                  'عضويتك المميزة في نَصِيبُكَ نشطة الآن ويمكنك إرسال طلبات التعارف والمراسلة بحرية.',
              actionRoute: 'subscription',
              referenceType: 'subscription',
              referenceId: subId,
              routingMetadata: {'reference_id': subId},
              isRead: _isSynthRead(synthId),
              createdAt: currentSub['starts_at']?.toString(),
            ),
          );
          addedSubscriptionNotif = true;
        } else if (!isEntitled &&
            currentSub.isNotEmpty &&
            currentSub['status'] == 'expired') {
          final expSynthId = -(450000 + subId);
          if (!_localDeletedIds.contains(expSynthId)) {
            synthesized.add(
              NotificationItemModel(
                id: expSynthId,
                eventId: 'synth_sub_expired_$subId',
                eventType: 'subscription_expired',
                titleAr: 'انتهت صلاحية اشتراكك',
                bodyAr:
                    'انتهت فترة اشتراكك السابق، يمكنك تجديد العضوية في أي وقت لاستمرار التواصل.',
                actionRoute: 'subscription',
                referenceType: 'subscription',
                referenceId: subId,
                routingMetadata: {'reference_id': subId},
                isRead: _isSynthRead(expSynthId),
                createdAt: currentSub['current_period_end']?.toString(),
              ),
            );
            addedSubscriptionNotif = true;
          }
        }
      } catch (_) {}
    }

    // 4. Profile & Account Status notifications (ensures active members always see their account/profile status notifications)
    if (rawProfBody != null) {
      try {
        final profData = _extractDataMap(rawProfBody);
        final profileMap = profData['profile'] is Map
            ? Map<String, dynamic>.from(profData['profile'] as Map)
            : null;
        final profEntitlement = profData['entitlement'] is Map
            ? Map<String, dynamic>.from(profData['entitlement'] as Map)
            : const <String, dynamic>{};

        if (!addedSubscriptionNotif &&
            profEntitlement['has_active_subscription'] == true) {
          const synthSubId = -400001;
          if (!_localDeletedIds.contains(synthSubId)) {
            synthesized.add(
              NotificationItemModel(
                id: synthSubId,
                eventId: 'synth_sub_active_entitlement',
                eventType: 'subscription_activated',
                titleAr: 'تم تفعيل اشتراكك',
                bodyAr:
                    'عضويتك المميزة في نَصِيبُكَ نشطة الآن ويمكنك إرسال طلبات التعارف والمراسلة بحرية.',
                actionRoute: 'subscription',
                referenceType: 'subscription',
                referenceId: 1,
                routingMetadata: const {'reference_id': 1},
                isRead: _isSynthRead(synthSubId),
              ),
            );
          }
        }

        if (profileMap != null) {
          final profileId = int.tryParse('${profileMap['id'] ?? 1}') ?? 1;
          final modStatus =
              (profileMap['moderation_status'] ?? 'approved').toString();
          final primaryPhoto = profileMap['primary_photo'] is Map
              ? Map<String, dynamic>.from(profileMap['primary_photo'] as Map)
              : null;

          if (primaryPhoto != null) {
            final photoId = int.tryParse('${primaryPhoto['id'] ?? 1}') ?? 1;
            final photoStatus =
                (primaryPhoto['moderation_status'] ?? 'approved').toString();
            final photoSynthId = -(500000 + photoId);
            if (!_localDeletedIds.contains(photoSynthId) &&
                photoStatus == 'approved') {
              synthesized.add(
                NotificationItemModel(
                  id: photoSynthId,
                  eventId: 'synth_photo_approved_$photoId',
                  eventType: 'admin_announcement',
                  titleAr: 'تم اعتماد صورتك الشخصية',
                  bodyAr:
                      'تمت الموافقة على صورتك الشخصية بنجاح وتظهر الآن وفق إعدادات الخصوصية الخاصة بك.',
                  actionRoute: 'notification_center',
                  referenceType: 'user_photo',
                  referenceId: photoId,
                  isRead: _isSynthRead(photoSynthId),
                ),
              );
            }
          }

          final profSynthId = -(600000 + profileId);
          if (!_localDeletedIds.contains(profSynthId)) {
            final isApproved = modStatus == 'approved';
            final isPending = modStatus == 'pending';
            synthesized.add(
              NotificationItemModel(
                id: profSynthId,
                eventId: 'synth_profile_status_$profileId',
                eventType: 'admin_announcement',
                titleAr: isApproved
                    ? 'تم اعتماد ملفك الشخصي'
                    : (isPending
                        ? 'تم حفظ ملفك الشخصي بنجاح'
                        : 'ملاحظة بخصوص ملفك الشخصي'),
                bodyAr: isApproved
                    ? 'تمت مراجعة واعتماد ملفك الشخصي بنجاح وهو متاح الآن للظهور للأعضاء المتوافقين في نَصِيبُكَ.'
                    : (isPending
                        ? 'تم استلام بيانات ملفك الشخصي بنجاح في منصة نَصِيبُكَ.'
                        : 'يرجى مراجعة بيانات ملفك الشخصي وتحديثها لضمان استمرار ظهورك في البحث.'),
                actionRoute: 'notification_center',
                referenceType: 'user_profile',
                referenceId: profileId,
                isRead: _isSynthRead(profSynthId),
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 5. Welcome notification for active member if not deleted
    const welcomeSynthId = -700001;
    if (!_localDeletedIds.contains(welcomeSynthId)) {
      synthesized.add(
        NotificationItemModel(
          id: welcomeSynthId,
          eventId: 'synth_welcome_naseebak',
          eventType: 'admin_announcement',
          titleAr: 'أهلاً بك في نَصِيبُكَ',
          bodyAr:
              'مرحباً بك في مجتمع نَصِيبُكَ للزواج الشرعي الآمن. يمكنك الآن استكشاف الملفات المتوافقة والتواصل بخصوصية وأمان.',
          actionRoute: 'notification_center',
          referenceType: 'welcome',
          referenceId: 1,
          isRead: _isSynthRead(welcomeSynthId),
        ),
      );
    }

    return synthesized;
  }

  /// GET /api/v1/notifications/unread-count
  Future<int> fetchUnreadCount() async {
    int serverCount = 0;
    try {
      final response = await _apiClient.dio.get<dynamic>(
        ApiEndpoints.notificationsUnreadCount,
      );
      final data = _extractDataMap(response.data);
      final raw = data['unread_count'];
      serverCount = raw is num ? raw.toInt() : (int.tryParse('${raw ?? 0}') ?? 0);
    } catch (_) {}

    if (serverCount > 0) {
      return serverCount;
    }

    final fallback = await _buildClientActivityNotifications();
    return fallback.where((n) => !n.isRead).length;
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
    _allLocalMarkedRead = true;
    try {
      final response = await _apiClient.dio.post<dynamic>(
        ApiEndpoints.notificationsReadAll,
      );
      final data = _extractDataMap(response.data);
      final rawCount = data['updated_count'];
      return rawCount is num
          ? rawCount.toInt()
          : (int.tryParse('${rawCount ?? 0}') ?? 0);
    } catch (_) {
      return 0;
    }
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
