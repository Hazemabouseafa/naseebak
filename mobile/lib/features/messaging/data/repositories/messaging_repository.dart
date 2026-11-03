import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/conversation_model.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(dio: ref.watch(dioProvider));
});

class MessagingRepository {
  final Dio _dio;

  MessagingRepository({required Dio dio}) : _dio = dio;

  Future<({
    List<ConversationSummaryModel> conversations,
    int currentPage,
    bool hasMorePages,
    bool viewerHasActiveSubscription,
  })> fetchConversations({int page = 1, int perPage = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.conversations,
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final body = response.data as Map<String, dynamic>;
    final data =
        body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawList = data['conversations'] as List<dynamic>? ?? const [];
    final pagination =
        data['pagination'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final entitlement = data['viewer_entitlement'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return (
      conversations: rawList
          .whereType<Map<String, dynamic>>()
          .map(ConversationSummaryModel.fromJson)
          .toList(),
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? 1,
      hasMorePages: (pagination['has_more_pages'] as bool?) ?? false,
      viewerHasActiveSubscription:
          (entitlement['has_active_subscription'] as bool?) ?? false,
    );
  }

  Future<({
    ConversationSummaryModel conversation,
    bool viewerHasActiveSubscription,
    int maxMessageLength,
  })> fetchConversationDetail(int conversationId) async {
    final response = await _dio.get(
      ApiEndpoints.conversationDetail(conversationId),
    );
    final body = response.data as Map<String, dynamic>;
    final data =
        body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawConv = data['conversation'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final entitlement = data['viewer_entitlement'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return (
      conversation: ConversationSummaryModel.fromJson(rawConv),
      viewerHasActiveSubscription:
          (entitlement['has_active_subscription'] as bool?) ?? false,
      maxMessageLength: (data['max_message_length'] as num?)?.toInt() ?? 2000,
    );
  }

  Future<({
    List<ChatMessageModel> messages,
    MessagePaginationCursor cursor,
    bool isBlocked,
    bool canSendMessages,
    String? restrictionCode,
    int? otherLastReadMessageId,
  })> fetchMessages(
    int conversationId, {
    int limit = 30,
    int? beforeId,
    int? afterId,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (beforeId != null) query['before_id'] = beforeId;
    if (afterId != null) query['after_id'] = afterId;

    final response = await _dio.get(
      ApiEndpoints.conversationMessages(conversationId),
      queryParameters: query,
    );
    final body = response.data as Map<String, dynamic>;
    final data =
        body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawMessages = data['messages'] as List<dynamic>? ?? const [];
    final rawCursor =
        data['cursor'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawState = data['conversation_state'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return (
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList(),
      cursor: MessagePaginationCursor.fromJson(rawCursor),
      isBlocked: (rawState['is_blocked'] as bool?) ?? false,
      canSendMessages: (rawState['can_send_messages'] as bool?) ?? false,
      restrictionCode: rawState['restriction_code'] as String?,
      otherLastReadMessageId:
          (rawState['other_participant_last_read_message_id'] as num?)?.toInt(),
    );
  }

  Future<MessageSendResult> sendMessage({
    required int conversationId,
    required String bodyText,
    required String clientMessageId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.conversationMessages(conversationId),
        data: {
          'body': bodyText,
          'client_message_id': clientMessageId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      final data =
          body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final rawMessage = data['message'] as Map<String, dynamic>?;

      return MessageSendResult(
        isSuccess: true,
        message: (body['message'] as String?) ?? 'تم إرسال الرسالة بنجاح.',
        savedMessage: rawMessage != null
            ? ChatMessageModel.fromJson(rawMessage)
            : null,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map<String, dynamic> ? data['code'] as String? : null;
      final msg = data is Map<String, dynamic>
          ? (data['message'] as String? ?? 'تعذر إرسال الرسالة.')
          : 'تعذر إرسال الرسالة بسبب انقطاع الاتصال.';

      return MessageSendResult(
        isSuccess: false,
        isSubscriptionRequired: code == 'SUBSCRIPTION_REQUIRED',
        isBlocked: code == 'CONVERSATION_BLOCKED',
        errorCode: code,
        message: msg,
      );
    }
  }

  Future<int?> markConversationRead(
    int conversationId, {
    int? upToMessageId,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.conversationMarkRead(conversationId),
      data: {
        if (upToMessageId != null) 'up_to_message_id': upToMessageId,
      },
    );
    final body = response.data as Map<String, dynamic>;
    final data =
        body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return (data['last_read_message_id'] as num?)?.toInt();
  }

  Future<String> authorizePrivateChannel({
    required String socketId,
    required String channelName,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.broadcastingAuth,
      data: {
        'socket_id': socketId,
        'channel_name': channelName,
      },
    );
    final body = response.data as Map<String, dynamic>;
    return (body['auth'] as String?) ?? '';
  }
}
