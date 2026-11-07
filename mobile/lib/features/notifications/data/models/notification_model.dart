class NotificationItemModel {
  final int id;
  final String eventId;
  final String eventType;
  final String titleAr;
  final String bodyAr;
  final String? referenceType;
  final int? referenceId;
  final String actionRoute;
  final Map<String, dynamic> routingMetadata;
  final bool isRead;
  final String? readAt;
  final String? createdAt;

  NotificationItemModel({
    required this.id,
    String? eventId,
    String? eventType,
    String? notificationType,
    required this.titleAr,
    required this.bodyAr,
    this.referenceType,
    this.referenceId,
    this.actionRoute = 'notification_center',
    this.routingMetadata = const {},
    Map<String, dynamic>? dataPayload,
    this.isRead = false,
    String? deliveryStatus,
    dynamic readAt,
    dynamic createdAt,
  })  : eventId = eventId ??
            (dataPayload != null ? (dataPayload['event_id'] as String? ?? '') : ''),
        eventType = eventType ?? notificationType ?? 'admin_announcement',
        readAt = readAt is DateTime ? readAt.toIso8601String() : (readAt as String?),
        createdAt = createdAt is DateTime
            ? createdAt.toIso8601String()
            : (createdAt as String?);

  String get notificationType => eventType;

  DateTime? get createdAtDateTime =>
      createdAt != null ? DateTime.tryParse(createdAt!) : null;

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    final rawNotif = json['notification'];
    final payload = rawNotif is Map
        ? Map<String, dynamic>.from(rawNotif)
        : json;
    final rawMeta = payload['routing_metadata'] ?? json['routing_metadata'];
    final meta = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : const <String, dynamic>{};

    final rawDataPayload = payload['data_payload'];
    final dataMap = rawDataPayload is Map
        ? Map<String, dynamic>.from(rawDataPayload)
        : null;

    final resolvedEventId = (json['event_id'] ??
            payload['event_id'] ??
            (dataMap != null ? dataMap['event_id'] : null) ??
            '')
        .toString();

    final rawId = payload['id'] ?? json['id'] ?? 0;
    final parsedId =
        rawId is num ? rawId.toInt() : (int.tryParse('$rawId') ?? 0);

    final rawRefId = payload['reference_id'] ?? json['reference_id'];
    final parsedRefId = rawRefId is num
        ? rawRefId.toInt()
        : (rawRefId != null ? int.tryParse('$rawRefId') : null);

    final rawIsRead = payload['is_read'] ?? json['is_read'];
    final parsedIsRead =
        rawIsRead == true || rawIsRead == 1 || rawIsRead == '1' || rawIsRead == 'true';

    return NotificationItemModel(
      id: parsedId,
      eventId: resolvedEventId,
      eventType: (payload['event_type'] ??
              payload['notification_type'] ??
              json['event_type'] ??
              json['notification_type'] ??
              'admin_announcement')
          .toString(),
      titleAr: (payload['title_ar'] ?? json['title_ar'] ?? 'إشعار جديد')
          .toString(),
      bodyAr: (payload['body_ar'] ?? json['body_ar'] ?? '').toString(),
      referenceType:
          (payload['reference_type'] ?? json['reference_type'])?.toString(),
      referenceId: parsedRefId,
      actionRoute: (payload['action_route'] ??
              json['action_route'] ??
              'notification_center')
          .toString(),
      routingMetadata: meta,
      isRead: parsedIsRead,
      readAt: (payload['read_at'] ?? json['read_at'])?.toString(),
      createdAt: (payload['created_at'] ?? json['created_at'])?.toString(),
    );
  }

  NotificationItemModel copyWith({
    bool? isRead,
    dynamic readAt,
  }) {
    return NotificationItemModel(
      id: id,
      eventId: eventId,
      eventType: eventType,
      titleAr: titleAr,
      bodyAr: bodyAr,
      referenceType: referenceType,
      referenceId: referenceId,
      actionRoute: actionRoute,
      routingMetadata: routingMetadata,
      isRead: isRead ?? this.isRead,
      readAt: readAt is DateTime
          ? readAt.toIso8601String()
          : (readAt as String? ?? this.readAt),
      createdAt: createdAt,
    );
  }
}

typedef PaginatedNotificationsResult = PaginatedNotificationsResponse;

class PaginatedNotificationsResponse {
  final List<NotificationItemModel> notifications;
  final int unreadCount;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  const PaginatedNotificationsResponse({
    List<NotificationItemModel>? notifications,
    List<NotificationItemModel>? items,
    required this.unreadCount,
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
    this.total = 0,
    this.hasMorePages = false,
  }) : notifications = notifications ?? items ?? const [];

  List<NotificationItemModel> get items => notifications;

  factory PaginatedNotificationsResponse.fromJson(Map<String, dynamic> data) {
    final rawList = (data['notifications'] ?? data['items']) as List<dynamic>? ??
        const [];
    final rawPagination = data['pagination'];
    final pagination = rawPagination is Map
        ? Map<String, dynamic>.from(rawPagination)
        : const <String, dynamic>{};

    final items = rawList
        .whereType<Map>()
        .map((e) => NotificationItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawUnread = data['unread_count'];
    final parsedUnread = rawUnread is num
        ? rawUnread.toInt()
        : (int.tryParse('${rawUnread ?? ''}') ??
            items.where((n) => !n.isRead).length);

    int parseIntField(dynamic val, int fallback) =>
        val is num ? val.toInt() : (int.tryParse('${val ?? ''}') ?? fallback);

    return PaginatedNotificationsResponse(
      notifications: items,
      unreadCount: parsedUnread,
      currentPage: parseIntField(pagination['current_page'], 1),
      lastPage: parseIntField(pagination['last_page'], 1),
      perPage: parseIntField(pagination['per_page'], 20),
      total: parseIntField(pagination['total'], items.length),
      hasMorePages: pagination['has_more_pages'] == true,
    );
  }
}

class NotificationPreferencesModel {
  final bool matchmakingRequestsEnabled;
  final bool messagesEnabled;
  final bool subscriptionsEnabled;
  final bool announcementsEnabled;

  const NotificationPreferencesModel({
    this.matchmakingRequestsEnabled = true,
    this.messagesEnabled = true,
    this.subscriptionsEnabled = true,
    this.announcementsEnabled = true,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      matchmakingRequestsEnabled:
          (json['matchmaking_requests_enabled'] as bool?) ?? true,
      messagesEnabled: (json['messages_enabled'] as bool?) ?? true,
      subscriptionsEnabled: (json['subscriptions_enabled'] as bool?) ?? true,
      announcementsEnabled: (json['announcements_enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchmaking_requests_enabled': matchmakingRequestsEnabled,
      'messages_enabled': messagesEnabled,
      'subscriptions_enabled': subscriptionsEnabled,
      'announcements_enabled': announcementsEnabled,
    };
  }

  NotificationPreferencesModel copyWith({
    bool? matchmakingRequestsEnabled,
    bool? messagesEnabled,
    bool? subscriptionsEnabled,
    bool? announcementsEnabled,
  }) {
    return NotificationPreferencesModel(
      matchmakingRequestsEnabled:
          matchmakingRequestsEnabled ?? this.matchmakingRequestsEnabled,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      subscriptionsEnabled: subscriptionsEnabled ?? this.subscriptionsEnabled,
      announcementsEnabled: announcementsEnabled ?? this.announcementsEnabled,
    );
  }
}

typedef NotificationPreferenceModel = NotificationPreferencesModel;
