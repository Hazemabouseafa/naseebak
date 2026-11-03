import '../../../matchmaking/data/models/matchmaking_request_model.dart';

class LastMessagePreviewModel {
  final int id;
  final int senderId;
  final String bodyPreview;
  final bool isRead;
  final String? createdAt;

  const LastMessagePreviewModel({
    required this.id,
    required this.senderId,
    required this.bodyPreview,
    required this.isRead,
    this.createdAt,
  });

  factory LastMessagePreviewModel.fromJson(Map<String, dynamic> json) {
    return LastMessagePreviewModel(
      id: (json['id'] as num).toInt(),
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      bodyPreview: (json['body_preview'] as String?) ?? '',
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}

class ConversationSummaryModel {
  final int id;
  final int? matchmakingRequestId;
  final String status; // active, blocked, closed
  final bool isBlocked;
  final bool canSendMessages;
  final String? restrictionCode;
  final int unreadCount;
  final int? viewerLastReadMessageId;
  final int? otherLastReadMessageId;
  final String? lastMessageAt;
  final LastMessagePreviewModel? lastMessage;
  final MatchmakingMemberSummary otherMember;

  const ConversationSummaryModel({
    required this.id,
    this.matchmakingRequestId,
    required this.status,
    required this.isBlocked,
    required this.canSendMessages,
    this.restrictionCode,
    required this.unreadCount,
    this.viewerLastReadMessageId,
    this.otherLastReadMessageId,
    this.lastMessageAt,
    this.lastMessage,
    required this.otherMember,
  });

  factory ConversationSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawLast = json['last_message'];
    final rawMember = json['other_member'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return ConversationSummaryModel(
      id: (json['id'] as num).toInt(),
      matchmakingRequestId: (json['matchmaking_request_id'] as num?)?.toInt(),
      status: (json['status'] as String?) ?? 'active',
      isBlocked: (json['is_blocked'] as bool?) ?? false,
      canSendMessages: (json['can_send_messages'] as bool?) ?? false,
      restrictionCode: json['restriction_code'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      viewerLastReadMessageId:
          (json['viewer_last_read_message_id'] as num?)?.toInt(),
      otherLastReadMessageId:
          (json['other_last_read_message_id'] as num?)?.toInt(),
      lastMessageAt: json['last_message_at'] as String?,
      lastMessage: rawLast is Map<String, dynamic>
          ? LastMessagePreviewModel.fromJson(rawLast)
          : null,
      otherMember: MatchmakingMemberSummary.fromJson(rawMember),
    );
  }

  ConversationSummaryModel copyWith({
    String? status,
    bool? isBlocked,
    bool? canSendMessages,
    String? restrictionCode,
    int? unreadCount,
    int? otherLastReadMessageId,
    String? lastMessageAt,
    LastMessagePreviewModel? lastMessage,
  }) {
    return ConversationSummaryModel(
      id: id,
      matchmakingRequestId: matchmakingRequestId,
      status: status ?? this.status,
      isBlocked: isBlocked ?? this.isBlocked,
      canSendMessages: canSendMessages ?? this.canSendMessages,
      restrictionCode: restrictionCode ?? this.restrictionCode,
      unreadCount: unreadCount ?? this.unreadCount,
      viewerLastReadMessageId: viewerLastReadMessageId,
      otherLastReadMessageId:
          otherLastReadMessageId ?? this.otherLastReadMessageId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      otherMember: otherMember,
    );
  }
}

enum OutgoingSendState {
  sending,
  sent,
  failed,
}

class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String? clientMessageId;
  final String body;
  final bool isRead;
  final String deliveryStatus; // delivered_server, delivered_recipient, read
  final String? createdAt;
  final OutgoingSendState sendState;
  final String? sendError;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.clientMessageId,
    required this.body,
    required this.isRead,
    this.deliveryStatus = 'delivered_server',
    this.createdAt,
    this.sendState = OutgoingSendState.sent,
    this.sendError,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      clientMessageId: json['client_message_id'] as String?,
      body: (json['body'] as String?) ?? '',
      isRead: (json['is_read'] as bool?) ?? false,
      deliveryStatus:
          (json['delivery_status'] as String?) ?? 'delivered_server',
      createdAt: json['created_at'] as String?,
      sendState: OutgoingSendState.sent,
    );
  }

  ChatMessageModel copyWith({
    int? id,
    bool? isRead,
    String? deliveryStatus,
    OutgoingSendState? sendState,
    String? sendError,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      clientMessageId: clientMessageId,
      body: body,
      isRead: isRead ?? this.isRead,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      createdAt: createdAt,
      sendState: sendState ?? this.sendState,
      sendError: sendError,
    );
  }
}

class MessagePaginationCursor {
  final int limit;
  final bool hasOlderMessages;
  final bool hasNewerMessages;
  final int? nextBeforeId;
  final int? latestMessageId;

  const MessagePaginationCursor({
    this.limit = 30,
    this.hasOlderMessages = false,
    this.hasNewerMessages = false,
    this.nextBeforeId,
    this.latestMessageId,
  });

  factory MessagePaginationCursor.fromJson(Map<String, dynamic> json) {
    return MessagePaginationCursor(
      limit: (json['limit'] as num?)?.toInt() ?? 30,
      hasOlderMessages: (json['has_older_messages'] as bool?) ?? false,
      hasNewerMessages: (json['has_newer_messages'] as bool?) ?? false,
      nextBeforeId: (json['next_before_id'] as num?)?.toInt(),
      latestMessageId: (json['latest_message_id'] as num?)?.toInt(),
    );
  }
}

class MessageSendResult {
  final bool isSuccess;
  final bool isSubscriptionRequired;
  final bool isBlocked;
  final String? errorCode;
  final String message;
  final ChatMessageModel? savedMessage;

  const MessageSendResult({
    required this.isSuccess,
    this.isSubscriptionRequired = false,
    this.isBlocked = false,
    this.errorCode,
    required this.message,
    this.savedMessage,
  });
}
