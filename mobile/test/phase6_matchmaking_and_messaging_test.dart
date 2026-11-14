import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/features/discovery/data/models/member_profile_model.dart';
import 'package:naseebak_mobile/features/discovery/data/repositories/discovery_repository.dart';
import 'package:naseebak_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/member_profile_screen.dart';
import 'package:naseebak_mobile/features/matchmaking/data/models/matchmaking_request_model.dart';
import 'package:naseebak_mobile/features/matchmaking/data/repositories/matchmaking_repository.dart';
import 'package:naseebak_mobile/features/matchmaking/presentation/screens/matchmaking_requests_screen.dart';
import 'package:naseebak_mobile/features/messaging/data/models/conversation_model.dart';
import 'package:naseebak_mobile/features/messaging/data/repositories/messaging_repository.dart';
import 'package:naseebak_mobile/features/messaging/data/services/realtime_messaging_service.dart';
import 'package:naseebak_mobile/features/messaging/presentation/screens/chat_screen.dart';
import 'package:naseebak_mobile/features/messaging/presentation/screens/conversations_screen.dart';

class _FakeDiscoveryRepository extends Fake implements DiscoveryRepository {
  MemberProfileDetailModel profileToReturn;

  _FakeDiscoveryRepository(this.profileToReturn);

  @override
  Future<MemberProfileDetailModel> fetchMemberProfile(int targetUserId) async {
    return profileToReturn;
  }
}

class _FakeMatchmakingRepository extends Fake implements MatchmakingRepository {
  MatchmakingRequestsBundle bundleToReturn;
  int? acceptedConversationId;

  _FakeMatchmakingRepository({
    this.bundleToReturn = const MatchmakingRequestsBundle(),
    this.acceptedConversationId = 77,
  });

  @override
  Future<MatchmakingRequestsBundle> fetchAllRequests() async => bundleToReturn;

  @override
  Future<MatchmakingCreateResult> sendMatchmakingRequest(
      int recipientUserId) async {
    return const MatchmakingCreateResult(
      isSuccess: true,
      message: 'تم إرسال طلب التعارف بنجاح',
    );
  }

  @override
  Future<({
    MatchmakingRequestItemModel? request,
    int? conversationId,
    String message,
  })> acceptRequest(int requestId) async {
    final item = bundleToReturn.incoming.firstWhere((r) => r.id == requestId);
    return (
      request: MatchmakingRequestItemModel(
        id: item.id,
        direction: 'accepted',
        senderId: item.senderId,
        recipientId: item.recipientId,
        status: 'accepted',
        statusLabelAr: 'مقبول',
        canAccept: false,
        canReject: false,
        canCancel: false,
        conversationId: acceptedConversationId,
        member: item.member,
      ),
      conversationId: acceptedConversationId,
      message: 'تم قبول طلب التعارف وفتح المحادثة الخاصة بنجاح.',
    );
  }

  @override
  Future<String> cancelRequest(int requestId) async {
    bundleToReturn = MatchmakingRequestsBundle(
      incoming: bundleToReturn.incoming,
      sent: bundleToReturn.sent
          .map((s) => s.id == requestId
              ? MatchmakingRequestItemModel(
                  id: s.id,
                  direction: 'sent',
                  senderId: s.senderId,
                  recipientId: s.recipientId,
                  status: 'cancelled',
                  statusLabelAr: 'ملغى',
                  canAccept: false,
                  canReject: false,
                  canCancel: false,
                  member: s.member,
                )
              : s)
          .toList(),
      accepted: bundleToReturn.accepted,
    );
    return 'تم إلغاء طلب التعارف المرسل.';
  }
}

class _FakeMessagingRepository extends Fake implements MessagingRepository {
  List<ConversationSummaryModel> conversations;
  ConversationSummaryModel detailConversation;
  List<ChatMessageModel> messages;
  MessageSendResult sendResult;
  int fetchMessagesCalls = 0;

  _FakeMessagingRepository({
    this.conversations = const [],
    required this.detailConversation,
    this.messages = const [],
    required this.sendResult,
  });

  @override
  Future<({
    List<ConversationSummaryModel> conversations,
    int currentPage,
    bool hasMorePages,
    bool viewerHasActiveSubscription,
  })> fetchConversations({int page = 1, int perPage = 20}) async {
    return (
      conversations: conversations,
      currentPage: 1,
      hasMorePages: false,
      viewerHasActiveSubscription: true,
    );
  }

  @override
  Future<({
    ConversationSummaryModel conversation,
    bool viewerHasActiveSubscription,
    int maxMessageLength,
  })> fetchConversationDetail(int conversationId) async {
    return (
      conversation: detailConversation,
      viewerHasActiveSubscription: detailConversation.canSendMessages,
      maxMessageLength: 2000,
    );
  }

  @override
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
    fetchMessagesCalls++;
    return (
      messages: messages,
      cursor: const MessagePaginationCursor(),
      isBlocked: detailConversation.isBlocked,
      canSendMessages: detailConversation.canSendMessages,
      restrictionCode: detailConversation.restrictionCode,
      otherLastReadMessageId: null,
    );
  }

  @override
  Future<MessageSendResult> sendMessage({
    required int conversationId,
    required String bodyText,
    required String clientMessageId,
  }) async {
    if (sendResult.isSuccess && sendResult.savedMessage != null) {
      return MessageSendResult(
        isSuccess: true,
        message: sendResult.message,
        savedMessage: ChatMessageModel(
          id: sendResult.savedMessage!.id,
          conversationId: conversationId,
          senderId: sendResult.savedMessage!.senderId,
          clientMessageId: clientMessageId,
          body: bodyText,
          isRead: false,
        ),
      );
    }
    return sendResult;
  }

  @override
  Future<int?> markConversationRead(
    int conversationId, {
    int? upToMessageId,
  }) async {
    return upToMessageId ?? 1;
  }
}

class _FakeRealtimeMessagingService extends Fake
    implements RealtimeMessagingService {
  final _connController =
      StreamController<RealtimeConnectionState>.broadcast();
  final _eventsController = StreamController<ReverbEventMessage>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();

  @override
  RealtimeConnectionState get connectionState =>
      RealtimeConnectionState.connected;

  @override
  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connController.stream;

  @override
  Stream<ReverbEventMessage> get eventsStream => _eventsController.stream;

  @override
  Stream<void> get onReconnectedStream => _reconnectedController.stream;

  @override
  Future<void> subscribeToConversation(int conversationId) async {}

  @override
  void unsubscribeFromConversation(int conversationId) {}

  void emitEvent(ReverbEventMessage event) => _eventsController.add(event);

  void emitReconnected() => _reconnectedController.add(null);
}

MemberProfileDetailModel _buildSampleMember({
  required String buttonState,
  bool viewerHasSub = true,
  int? conversationId,
}) {
  return MemberProfileDetailModel(
    userId: 202,
    fullName: 'مريم أحمد',
    gender: 'female',
    ageYears: 27,
    maritalStatus: 'single',
    educationLevel: 'bachelor',
    occupation: 'صيدلانية',
    smokingStatus: 'non_smoker',
    nationality: 'مصر',
    countryOfResidence: 'مصر',
    region: 'الإسكندرية',
    photoPrivacy: 'public',
    photoAuthorized: false,
    isFavorited: false,
    zodiacSign: 'العذراء',
    previouslyMarried: false,
    hasChildren: false,
    childrenCount: 0,
    heightCm: 165,
    homeOwnership: 'family_home',
    hobbies: const ['القراءة'],
    viewerHasActiveSubscription: viewerHasSub,
    viewerCanSendMatchRequests: viewerHasSub,
    viewerCanSendMessages: viewerHasSub,
    matchmakingButtonState: buttonState,
    matchmakingConversationId: conversationId,
  );
}

const _sampleMemberSummary = MatchmakingMemberSummary(
  userId: 202,
  fullName: 'مريم أحمد',
  gender: 'female',
  ageYears: 27,
  maritalStatus: 'single',
  region: 'الإسكندرية',
  countryOfResidence: 'مصر',
  photoPrivacy: 'public',
  photoAuthorized: false,
);

void main() {
  group('Phase 6 — Matchmaking & Real-Time Messaging Tests', () {
    testWidgets(
      '1 & 3. MemberProfileScreen displays "طلب التعارف" for subscribed viewer and updates to "طلب التعارف قيد الانتظار" after sending',
      (tester) async {
        final fakeDiscoveryRepo = _FakeDiscoveryRepository(
          _buildSampleMember(buttonState: 'available', viewerHasSub: true),
        );
        final fakeMatchmakingRepo = _FakeMatchmakingRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              discoveryRepositoryProvider.overrideWithValue(fakeDiscoveryRepo),
              matchmakingRepositoryProvider
                  .overrideWithValue(fakeMatchmakingRepo),
            ],
            child: const MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: MemberProfileScreen(memberUserId: 202),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('طلب التعارف'), findsOneWidget);

        await tester.tap(find.byKey(const Key('member_send_request_btn')));
        await tester.pumpAndSettle();

        expect(
          find.text('هل ترغب في إرسال طلب تعارف إلى هذا العضو؟'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('confirm_send_match_request_btn')));
        await tester.pumpAndSettle();

        expect(find.text('طلب التعارف قيد الانتظار'), findsOneWidget);
      },
    );

    testWidgets(
      '2. MemberProfileScreen prompts subscription when unsubscribed user taps primary action',
      (tester) async {
        final fakeDiscoveryRepo = _FakeDiscoveryRepository(
          _buildSampleMember(
            buttonState: 'subscription_required',
            viewerHasSub: false,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              discoveryRepositoryProvider.overrideWithValue(fakeDiscoveryRepo),
            ],
            child: const MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: MemberProfileScreen(memberUserId: 202),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('يتطلب التواصل عضوية فعّالة'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('member_send_request_btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('sheet_open_subscription_screen_btn')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '4. Accepted match updates MemberProfileScreen button state to "فتح المحادثة"',
      (tester) async {
        final fakeDiscoveryRepo = _FakeDiscoveryRepository(
          _buildSampleMember(
            buttonState: 'request_accepted',
            viewerHasSub: true,
            conversationId: 77,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              discoveryRepositoryProvider.overrideWithValue(fakeDiscoveryRepo),
            ],
            child: const MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: MemberProfileScreen(memberUserId: 202),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('فتح المحادثة'), findsOneWidget);
      },
    );

    testWidgets(
      '5, 6, 7, 8. MatchmakingRequestsScreen renders incoming/sent/accepted tabs, accept/reject actions, and sent cancellation',
      (tester) async {
        final incomingItem = const MatchmakingRequestItemModel(
          id: 11,
          direction: 'incoming',
          senderId: 202,
          recipientId: 101,
          status: 'pending',
          statusLabelAr: 'قيد الانتظار',
          canAccept: true,
          canReject: true,
          canCancel: false,
          member: _sampleMemberSummary,
        );
        final sentItem = const MatchmakingRequestItemModel(
          id: 12,
          direction: 'sent',
          senderId: 101,
          recipientId: 203,
          status: 'pending',
          statusLabelAr: 'قيد الانتظار',
          canAccept: false,
          canReject: false,
          canCancel: true,
          member: _sampleMemberSummary,
        );

        final fakeRepo = _FakeMatchmakingRepository(
          bundleToReturn: MatchmakingRequestsBundle(
            incoming: [incomingItem],
            sent: [sentItem],
            accepted: const [],
          ),
          acceptedConversationId: null,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matchmakingRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: MatchmakingRequestsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('الواردة'), findsOneWidget);
        expect(find.text('المرسلة'), findsOneWidget);
        expect(find.text('المقبولة'), findsOneWidget);

        expect(find.byKey(const Key('request_accept_btn_11')), findsOneWidget);
        expect(find.byKey(const Key('request_reject_btn_11')), findsOneWidget);

        // Switch to Sent tab and verify cancel button
        await tester.tap(find.byKey(const Key('tab_sent_requests')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('request_cancel_btn_12')), findsOneWidget);
        await tester.tap(find.byKey(const Key('request_cancel_btn_12')));
        await tester.pumpAndSettle();

        expect(find.text('ملغى'), findsOneWidget);
      },
    );

    testWidgets(
      '9 & 10. ConversationsScreen renders empty state and conversation items with unread badge and preview',
      (tester) async {
        const conv = ConversationSummaryModel(
          id: 55,
          status: 'active',
          isBlocked: false,
          canSendMessages: true,
          unreadCount: 3,
          lastMessage: LastMessagePreviewModel(
            id: 900,
            senderId: 202,
            bodyPreview: 'أهلاً وسهلاً بك',
            isRead: false,
          ),
          otherMember: _sampleMemberSummary,
        );

        final fakeMessagingRepo = _FakeMessagingRepository(
          conversations: const [],
          detailConversation: conv,
          sendResult: const MessageSendResult(isSuccess: true, message: 'ok'),
        );
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              messagingRepositoryProvider.overrideWithValue(fakeMessagingRepo),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: ConversationsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('لا توجد محادثات حتى الآن'), findsOneWidget);
        expect(
          find.text('ستظهر محادثاتك هنا بعد قبول طلبات التعارف.'),
          findsOneWidget,
        );

        // Populate conversation and refresh
        fakeMessagingRepo.conversations = const [conv];
        await tester.tap(find.byIcon(Icons.refresh_rounded));
        await tester.pumpAndSettle();

        expect(find.text('مريم أحمد'), findsOneWidget);
        expect(find.text('أهلاً وسهلاً بك'), findsOneWidget);
        expect(find.byKey(const Key('unread_badge_55')), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets(
      '11, 12, 15. ChatScreen renders message history in RTL, deduplicates incoming WebSocket echo, and refreshes on reconnect',
      (tester) async {
        const conv = ConversationSummaryModel(
          id: 55,
          status: 'active',
          isBlocked: false,
          canSendMessages: true,
          unreadCount: 0,
          otherMember: _sampleMemberSummary,
        );

        const initialMsg = ChatMessageModel(
          id: 1,
          conversationId: 55,
          senderId: 202,
          body: 'السلام عليكم',
          isRead: true,
        );

        final fakeRepo = _FakeMessagingRepository(
          detailConversation: conv,
          messages: const [initialMsg],
          sendResult: const MessageSendResult(
            isSuccess: true,
            message: 'ok',
            savedMessage: ChatMessageModel(
              id: 2,
              conversationId: 55,
              senderId: 0,
              body: 'وعليكم السلام ورحمة الله',
              isRead: false,
            ),
          ),
        );
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              messagingRepositoryProvider.overrideWithValue(fakeRepo),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: ChatScreen(conversationId: 55),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('السلام عليكم'), findsOneWidget);

        // Send a message
        await tester.enterText(
          find.byKey(const Key('chat_message_input')),
          'وعليكم السلام ورحمة الله',
        );
        await tester.tap(find.byKey(const Key('chat_send_message_btn')));
        await tester.pumpAndSettle();

        expect(find.text('وعليكم السلام ورحمة الله'), findsOneWidget);

        // Simulate WebSocket echo with identical message ID / content -> must not duplicate
        fakeRealtime.emitEvent(
          const ReverbEventMessage(
            event: 'message.sent',
            channel: 'private-conversation.55',
            data: {
              'id': 2,
              'conversation_id': 55,
              'sender_id': 0,
              'body': 'وعليكم السلام ورحمة الله',
              'is_read': false,
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('وعليكم السلام ورحمة الله'), findsOneWidget);

        // Simulate WebSocket reconnect -> triggers resynchronizeAfterReconnection
        final beforeReconnectCalls = fakeRepo.fetchMessagesCalls;
        fakeRealtime.emitReconnected();
        await tester.pumpAndSettle();
        expect(fakeRepo.fetchMessagesCalls, greaterThan(beforeReconnectCalls));
      },
    );

    testWidgets(
      '13 & 14. ChatScreen preserves unsent draft on SUBSCRIPTION_REQUIRED and disables sending when blocked',
      (tester) async {
        const unsubscribedConv = ConversationSummaryModel(
          id: 55,
          status: 'active',
          isBlocked: false,
          canSendMessages: false,
          restrictionCode: 'SUBSCRIPTION_REQUIRED',
          unreadCount: 0,
          otherMember: _sampleMemberSummary,
        );

        final fakeRepo = _FakeMessagingRepository(
          detailConversation: unsubscribedConv,
          messages: const [],
          sendResult: const MessageSendResult(
            isSuccess: false,
            isSubscriptionRequired: true,
            errorCode: 'SUBSCRIPTION_REQUIRED',
            message: 'يتطلب إرسال الرسائل اشتراكًا شهريًا نشطًا.',
          ),
        );
        final fakeRealtime = _FakeRealtimeMessagingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              messagingRepositoryProvider.overrideWithValue(fakeRepo),
              realtimeMessagingServiceProvider.overrideWithValue(fakeRealtime),
            ],
            child: const MaterialApp(
              home: ChatScreen(conversationId: 55),
            ),
          ),
        );
        await tester.pumpAndSettle();

        const draft = 'مسودة رسالة مهمة محفوظة';
        await tester.enterText(
          find.byKey(const Key('chat_message_input')),
          draft,
        );
        await tester.tap(find.byKey(const Key('chat_send_message_btn')));
        await tester.pumpAndSettle();

        // Dialog is shown and draft text remains preserved in the TextField
        expect(
          find.byKey(const Key('chat_subscription_required_dialog')),
          findsOneWidget,
        );
        final textField = tester.widget<TextField>(
          find.byKey(const Key('chat_message_input')),
        );
        expect(textField.controller?.text, draft);

        // Close dialog and test blocked state
        await tester.tap(find.text('لاحقاً'));
        await tester.pumpAndSettle();

        fakeRepo.detailConversation = unsubscribedConv.copyWith(
          isBlocked: true,
          status: 'blocked',
        );
        fakeRealtime.emitReconnected();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('chat_blocked_composer_banner')),
          findsOneWidget,
        );
      },
    );
  });
}
