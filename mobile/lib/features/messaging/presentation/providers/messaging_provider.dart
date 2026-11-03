import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/messaging_repository.dart';
import '../../data/services/realtime_messaging_service.dart';

class MessagingState {
  final bool isLoadingConversations;
  final List<ConversationSummaryModel> conversations;
  final int currentConversationsPage;
  final bool hasMoreConversations;
  final String? conversationsError;

  final int? activeConversationId;
  final ConversationSummaryModel? activeConversation;
  final bool isLoadingMessages;
  final bool isLoadingOlderMessages;
  final List<ChatMessageModel> activeMessages;
  final MessagePaginationCursor messageCursor;
  final String? messagesError;

  final bool isSendingMessage;
  final bool showSubscriptionRequiredPrompt;
  final String preservedDraftText;
  final int maxMessageLength;
  final RealtimeConnectionState connectionState;

  const MessagingState({
    this.isLoadingConversations = false,
    this.conversations = const [],
    this.currentConversationsPage = 1,
    this.hasMoreConversations = false,
    this.conversationsError,
    this.activeConversationId,
    this.activeConversation,
    this.isLoadingMessages = false,
    this.isLoadingOlderMessages = false,
    this.activeMessages = const [],
    this.messageCursor = const MessagePaginationCursor(),
    this.messagesError,
    this.isSendingMessage = false,
    this.showSubscriptionRequiredPrompt = false,
    this.preservedDraftText = '',
    this.maxMessageLength = 2000,
    this.connectionState = RealtimeConnectionState.disconnected,
  });

  MessagingState copyWith({
    bool? isLoadingConversations,
    List<ConversationSummaryModel>? conversations,
    int? currentConversationsPage,
    bool? hasMoreConversations,
    String? conversationsError,
    bool clearConversationsError = false,
    int? activeConversationId,
    ConversationSummaryModel? activeConversation,
    bool? isLoadingMessages,
    bool? isLoadingOlderMessages,
    List<ChatMessageModel>? activeMessages,
    MessagePaginationCursor? messageCursor,
    String? messagesError,
    bool clearMessagesError = false,
    bool? isSendingMessage,
    bool? showSubscriptionRequiredPrompt,
    String? preservedDraftText,
    int? maxMessageLength,
    RealtimeConnectionState? connectionState,
  }) {
    return MessagingState(
      isLoadingConversations:
          isLoadingConversations ?? this.isLoadingConversations,
      conversations: conversations ?? this.conversations,
      currentConversationsPage:
          currentConversationsPage ?? this.currentConversationsPage,
      hasMoreConversations: hasMoreConversations ?? this.hasMoreConversations,
      conversationsError: clearConversationsError
          ? null
          : (conversationsError ?? this.conversationsError),
      activeConversationId: activeConversationId ?? this.activeConversationId,
      activeConversation: activeConversation ?? this.activeConversation,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isLoadingOlderMessages:
          isLoadingOlderMessages ?? this.isLoadingOlderMessages,
      activeMessages: activeMessages ?? this.activeMessages,
      messageCursor: messageCursor ?? this.messageCursor,
      messagesError:
          clearMessagesError ? null : (messagesError ?? this.messagesError),
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      showSubscriptionRequiredPrompt:
          showSubscriptionRequiredPrompt ?? this.showSubscriptionRequiredPrompt,
      preservedDraftText: preservedDraftText ?? this.preservedDraftText,
      maxMessageLength: maxMessageLength ?? this.maxMessageLength,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}

final messagingProvider =
    StateNotifierProvider<MessagingNotifier, MessagingState>((ref) {
  return MessagingNotifier(
    repository: ref.watch(messagingRepositoryProvider),
    realtimeService: ref.watch(realtimeMessagingServiceProvider),
  );
});

class MessagingNotifier extends StateNotifier<MessagingState> {
  final MessagingRepository _repository;
  final RealtimeMessagingService _realtimeService;

  StreamSubscription<RealtimeConnectionState>? _connSub;
  StreamSubscription<ReverbEventMessage>? _eventSub;
  StreamSubscription<void>? _reconnectedSub;

  MessagingNotifier({
    required MessagingRepository repository,
    required RealtimeMessagingService realtimeService,
  })  : _repository = repository,
        _realtimeService = realtimeService,
        super(MessagingState(
          connectionState: realtimeService.connectionState,
        )) {
    _connSub = _realtimeService.connectionStateStream.listen((nextState) {
      state = state.copyWith(connectionState: nextState);
    });
    _eventSub = _realtimeService.eventsStream.listen(_handleRealtimeEvent);
    _reconnectedSub = _realtimeService.onReconnectedStream.listen((_) {
      resynchronizeAfterReconnection();
    });
  }

  Future<void> loadConversations({bool loadMore = false}) async {
    if (state.isLoadingConversations) return;

    final nextPage = loadMore ? state.currentConversationsPage + 1 : 1;
    state = state.copyWith(
      isLoadingConversations: true,
      clearConversationsError: true,
    );

    try {
      final res = await _repository.fetchConversations(page: nextPage);
      final merged = loadMore
          ? [...state.conversations, ...res.conversations]
          : res.conversations;

      state = state.copyWith(
        isLoadingConversations: false,
        conversations: merged,
        currentConversationsPage: res.currentPage,
        hasMoreConversations: res.hasMorePages,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoadingConversations: false,
        conversationsError: _extractError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingConversations: false,
        conversationsError: 'تعذر تحميل قائمة المحادثات حالياً.',
      );
    }
  }

  Future<void> openConversation(int conversationId) async {
    state = state.copyWith(
      activeConversationId: conversationId,
      isLoadingMessages: true,
      clearMessagesError: true,
      showSubscriptionRequiredPrompt: false,
    );

    try {
      final detail = await _repository.fetchConversationDetail(conversationId);
      final history = await _repository.fetchMessages(conversationId, limit: 30);

      state = state.copyWith(
        isLoadingMessages: false,
        activeConversation: detail.conversation.copyWith(
          isBlocked: history.isBlocked,
          canSendMessages: history.canSendMessages,
          restrictionCode: history.restrictionCode,
        ),
        activeMessages: history.messages,
        messageCursor: history.cursor,
        maxMessageLength: detail.maxMessageLength,
      );

      await _realtimeService.subscribeToConversation(conversationId);

      if (history.messages.isNotEmpty) {
        await markActiveConversationRead(
          upToMessageId: history.messages.last.id,
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoadingMessages: false,
        messagesError: _extractError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMessages: false,
        messagesError: 'تعذر تحميل المحادثة حالياً.',
      );
    }
  }

  Future<void> loadOlderMessages() async {
    final convId = state.activeConversationId;
    final nextBeforeId = state.messageCursor.nextBeforeId;
    if (convId == null ||
        nextBeforeId == null ||
        !state.messageCursor.hasOlderMessages ||
        state.isLoadingOlderMessages) {
      return;
    }

    state = state.copyWith(isLoadingOlderMessages: true);
    try {
      final older = await _repository.fetchMessages(
        convId,
        limit: 30,
        beforeId: nextBeforeId,
      );

      final existingIds = state.activeMessages.map((m) => m.id).toSet();
      final filteredOlder = older.messages
          .where((m) => !existingIds.contains(m.id))
          .toList();

      state = state.copyWith(
        isLoadingOlderMessages: false,
        activeMessages: [...filteredOlder, ...state.activeMessages],
        messageCursor: older.cursor,
      );
    } catch (_) {
      state = state.copyWith(isLoadingOlderMessages: false);
    }
  }

  /// Sends a text message or preserves the draft when subscription is required.
  Future<MessageSendResult> sendMessage({
    required int conversationId,
    required int currentUserId,
    required String rawText,
    String? retryClientMessageId,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return const MessageSendResult(
        isSuccess: false,
        message: 'لا يمكن إرسال رسالة فارغة.',
      );
    }

    if (state.isSendingMessage) {
      return const MessageSendResult(
        isSuccess: false,
        message: 'جاري إرسال الرسالة...',
      );
    }

    final clientMsgId = retryClientMessageId ??
        'nsb-${conversationId}-${currentUserId}-${DateTime.now().microsecondsSinceEpoch}';

    final optimisticMessage = ChatMessageModel(
      id: -DateTime.now().millisecondsSinceEpoch,
      conversationId: conversationId,
      senderId: currentUserId,
      clientMessageId: clientMsgId,
      body: trimmed,
      isRead: false,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      sendState: OutgoingSendState.sending,
    );

    final updatedList = [
      ...state.activeMessages
          .where((m) => m.clientMessageId != clientMsgId),
      optimisticMessage,
    ];

    state = state.copyWith(
      isSendingMessage: true,
      activeMessages: updatedList,
      showSubscriptionRequiredPrompt: false,
    );

    final res = await _repository.sendMessage(
      conversationId: conversationId,
      bodyText: trimmed,
      clientMessageId: clientMsgId,
    );

    if (res.isSuccess && res.savedMessage != null) {
      final saved = res.savedMessage!;
      final reconciled = state.activeMessages
          .map((m) => m.clientMessageId == clientMsgId ? saved : m)
          .toList();

      state = state.copyWith(
        isSendingMessage: false,
        activeMessages: _deduplicateMessages(reconciled),
        preservedDraftText: '',
      );
      return res;
    }

    if (res.isSubscriptionRequired) {
      // Remove optimistic bubble, preserve the unsent draft locally, and trigger subscription dialog
      final withoutOptimistic = state.activeMessages
          .where((m) => m.clientMessageId != clientMsgId)
          .toList();

      state = state.copyWith(
        isSendingMessage: false,
        activeMessages: withoutOptimistic,
        preservedDraftText: trimmed,
        showSubscriptionRequiredPrompt: true,
        activeConversation: state.activeConversation?.copyWith(
          canSendMessages: false,
          restrictionCode: 'SUBSCRIPTION_REQUIRED',
        ),
      );
      return res;
    }

    // Network/other failure: keep bubble in failed state so user can tap retry without losing draft
    final markedFailed = state.activeMessages.map((m) {
      if (m.clientMessageId == clientMsgId) {
        return m.copyWith(
          sendState: OutgoingSendState.failed,
          sendError: res.message,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      isSendingMessage: false,
      activeMessages: markedFailed,
      preservedDraftText: trimmed,
    );
    return res;
  }

  Future<void> markActiveConversationRead({int? upToMessageId}) async {
    final convId = state.activeConversationId;
    if (convId == null) return;

    try {
      await _repository.markConversationRead(
        convId,
        upToMessageId: upToMessageId,
      );
      final updatedConvs = state.conversations.map((c) {
        if (c.id == convId) {
          return c.copyWith(unreadCount: 0);
        }
        return c;
      }).toList();
      state = state.copyWith(conversations: updatedConvs);
    } catch (_) {}
  }

  /// Refreshes conversation state & fetches missed messages after reconnection or returning from SubscriptionScreen.
  Future<void> resynchronizeAfterReconnection() async {
    final convId = state.activeConversationId;
    if (convId == null) {
      await loadConversations();
      return;
    }

    try {
      final detail = await _repository.fetchConversationDetail(convId);
      final highestPersistedId = state.activeMessages
          .where((m) => m.id > 0)
          .fold<int>(0, (maxId, m) => m.id > maxId ? m.id : maxId);

      if (highestPersistedId > 0) {
        final missed = await _repository.fetchMessages(
          convId,
          afterId: highestPersistedId,
        );
        final merged = _deduplicateMessages([
          ...state.activeMessages,
          ...missed.messages,
        ]);
        state = state.copyWith(
          activeConversation: detail.conversation.copyWith(
            isBlocked: missed.isBlocked,
            canSendMessages: missed.canSendMessages,
            restrictionCode: missed.restrictionCode,
          ),
          activeMessages: merged,
          showSubscriptionRequiredPrompt: false,
        );
      } else {
        await openConversation(convId);
      }
    } catch (_) {}
  }

  void dismissSubscriptionRequiredPrompt() {
    state = state.copyWith(showSubscriptionRequiredPrompt: false);
  }

  void leaveActiveConversation() {
    final convId = state.activeConversationId;
    if (convId != null) {
      _realtimeService.unsubscribeFromConversation(convId);
    }
    state = state.copyWith(
      activeConversationId: null,
      activeConversation: null,
      activeMessages: const [],
    );
  }

  void _handleRealtimeEvent(ReverbEventMessage event) {
    if (event.event == 'message.sent') {
      final incoming = ChatMessageModel.fromJson(event.data);
      if (incoming.conversationId == state.activeConversationId) {
        final merged = _deduplicateMessages([
          ...state.activeMessages,
          incoming,
        ]);
        state = state.copyWith(activeMessages: merged);
        markActiveConversationRead(upToMessageId: incoming.id);
      }
      loadConversations();
    } else if (event.event == 'message.read') {
      final convId = (event.data['conversation_id'] as num?)?.toInt();
      final lastReadId =
          (event.data['last_read_message_id'] as num?)?.toInt() ?? 0;

      if (convId == state.activeConversationId && lastReadId > 0) {
        final updated = state.activeMessages.map((msg) {
          if (msg.id > 0 && msg.id <= lastReadId) {
            return msg.copyWith(isRead: true, deliveryStatus: 'read');
          }
          return msg;
        }).toList();
        state = state.copyWith(activeMessages: updated);
      }
    } else if (event.event == 'conversation.updated') {
      loadConversations();
    }
  }

  List<ChatMessageModel> _deduplicateMessages(List<ChatMessageModel> items) {
    final result = <ChatMessageModel>[];
    for (final item in items) {
      final existingIndex = result.indexWhere((existing) {
        if (item.id > 0 && existing.id > 0 && item.id == existing.id) {
          return true;
        }
        if (item.clientMessageId != null &&
            item.clientMessageId!.isNotEmpty &&
            existing.clientMessageId == item.clientMessageId) {
          return true;
        }
        return false;
      });

      if (existingIndex >= 0) {
        result[existingIndex] = item;
      } else {
        result.add(item);
      }
    }
    return result;
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'حدث خطأ في الاتصال بالخادم.';
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _eventSub?.cancel();
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
