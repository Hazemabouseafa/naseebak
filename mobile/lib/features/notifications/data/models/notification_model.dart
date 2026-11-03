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
    final payload = json['notification'] is Map<String, dynamic>
        ? json['notification'] as Map<String, dynamic>
        : json;
    final rawMeta = payload['routing_metadata'] ?? json['routing_metadata'];
    final rawDataPayload = payload['data_payload'];
    final resolvedEventId = (json['event_id'] as String?) ??
        (payload['event_id'] as String?) ??
        (rawDataPayload is Map<String, dynamic>
            ? rawDataPayload['event_id'] as String?
            : null) ??
        '';

    return NotificationItemModel(
      id: (payload['id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      eventId: resolvedEventId,
      eventType: (payload['event_type'] as String?) ??
          (payload['notification_type'] as String?) ??
          (json['event_type'] as String?) ??
          'admin_announcement',
      titleAr: (payload['title_ar'] as String?) ??
          (json['title_ar'] as String?) ??
          'إشعار جديد',
      bodyAr: (payload['body_ar'] as String?) ??
          (json['body_ar'] as String?) ??
          '',
      referenceType: (payload['reference_type'] as String?) ??
          (json['reference_type'] as String?),
      referenceId: (payload['reference_id'] as num?)?.toInt() ??
          (json['reference_id'] as num?)?.toInt(),
      actionRoute: (payload['action_route'] as String?) ??
          (json['action_route'] as String?) ??
          'notification_center',
      routingMetadata: rawMeta is Map<String, dynamic>
          ? rawMeta
          : const <String, dynamic>{},
      isRead: (payload['is_read'] as bool?) ??
          (json['is_read'] as bool?) ??
          false,
      readAt: (payload['read_at'] as String?) ?? (json['read_at'] as String?),
      createdAt: (payload['created_at'] as String?) ??
          (json['created_at'] as String?),
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
    final rawList = data['notifications'] as List<dynamic>? ?? const [];
    final pagination =
        data['pagination'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return PaginatedNotificationsResponse(
      notifications: rawList
          .whereType<Map<String, dynamic>>()
          .map(NotificationItemModel.fromJson)
          .toList(),
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagination['last_page'] as num?)?.toInt() ?? 1,
      perPage: (pagination['per_page'] as num?)?.toInt() ?? 20,
      total: (pagination['total'] as num?)?.toInt() ?? 0,
      hasMorePages: (pagination['has_more_pages'] as bool?) ?? false,
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
