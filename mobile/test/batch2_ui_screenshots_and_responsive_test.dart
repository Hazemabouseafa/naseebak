import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:naseebak_mobile/core/design_system/naseebak_design_system.dart';
import 'package:naseebak_mobile/core/network/api_client.dart';
import 'package:naseebak_mobile/core/storage/secure_session_storage.dart';
import 'package:naseebak_mobile/features/discovery/data/models/member_profile_model.dart';
import 'package:naseebak_mobile/features/discovery/data/repositories/discovery_repository.dart';
import 'package:naseebak_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:naseebak_mobile/features/discovery/presentation/screens/favorites_screen.dart';
import 'package:naseebak_mobile/features/discovery/presentation/widgets/report_member_dialog.dart';
import 'package:naseebak_mobile/features/matchmaking/data/models/matchmaking_request_model.dart';
import 'package:naseebak_mobile/features/matchmaking/data/repositories/matchmaking_repository.dart';
import 'package:naseebak_mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:naseebak_mobile/features/matchmaking/presentation/screens/matchmaking_requests_screen.dart';
import 'package:naseebak_mobile/features/messaging/data/models/conversation_model.dart';
import 'package:naseebak_mobile/features/messaging/data/repositories/messaging_repository.dart';
import 'package:naseebak_mobile/features/messaging/data/services/realtime_messaging_service.dart';
import 'package:naseebak_mobile/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:naseebak_mobile/features/messaging/presentation/screens/chat_screen.dart';
import 'package:naseebak_mobile/features/messaging/presentation/screens/conversations_screen.dart';
import 'package:naseebak_mobile/features/notifications/data/models/notification_model.dart';
import 'package:naseebak_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:naseebak_mobile/features/notifications/data/services/push_notification_service.dart';
import 'package:naseebak_mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:naseebak_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:naseebak_mobile/features/notifications/presentation/screens/notification_preferences_screen.dart';
import 'package:naseebak_mobile/features/profile/domain/profile_registration_draft.dart';
import 'package:naseebak_mobile/features/profile/presentation/providers/profile_management_provider.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/blocked_members_screen.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/delete_account_screen.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/privacy_settings_screen.dart';
import 'package:naseebak_mobile/features/subscription/data/models/subscription_model.dart';
import 'package:naseebak_mobile/features/subscription/data/repositories/subscription_repository.dart';
import 'package:naseebak_mobile/features/subscription/data/services/google_play_billing_service.dart';
import 'package:naseebak_mobile/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:naseebak_mobile/features/subscription/presentation/screens/my_subscription_screen.dart';
import 'package:naseebak_mobile/features/subscription/presentation/screens/subscription_screen.dart';

// ---------------------------------------------------------------------------
// Mock Data
// ---------------------------------------------------------------------------

const _sampleFavorites = [
  MemberCardModel(
    userId: 101,
    fullName: 'نورة العتيبي',
    gender: 'female',
    ageYears: 26,
    maritalStatus: 'single',
    educationLevel: 'bachelor',
    occupation: 'مهندسة معمارية',
    smokingStatus: 'non_smoker',
    nationality: 'سعودية',
    countryOfResidence: 'السعودية',
    region: 'الرياض',
    photoPrivacy: 'public',
    photoAuthorized: true,
    isFavorited: true,
  ),
  MemberCardModel(
    userId: 102,
    fullName: 'سارة المنصور',
    gender: 'female',
    ageYears: 28,
    maritalStatus: 'single',
    educationLevel: 'master',
    occupation: 'طبيبة أسنان',
    smokingStatus: 'non_smoker',
    nationality: 'سعودية',
    countryOfResidence: 'السعودية',
    region: 'جدة',
    photoPrivacy: 'public',
    photoAuthorized: true,
    isFavorited: true,
  ),
];

const _samplePartnerSummary = MatchmakingMemberSummary(
  userId: 101,
  fullName: 'نورة العتيبي',
  gender: 'female',
  ageYears: 26,
  maritalStatus: 'single',
  region: 'الرياض',
  countryOfResidence: 'السعودية',
  photoPrivacy: 'public',
  photoAuthorized: true,
);

const _sampleRequestsBundle = MatchmakingRequestsBundle(
  incoming: [
    MatchmakingRequestItemModel(
      id: 11,
      direction: 'incoming',
      senderId: 101,
      recipientId: 1,
      status: 'pending',
      statusLabelAr: 'قيد الانتظار',
      canAccept: true,
      canReject: true,
      canCancel: false,
      createdAt: 'منذ 3 ساعات',
      member: _samplePartnerSummary,
    ),
  ],
  sent: [
    MatchmakingRequestItemModel(
      id: 12,
      direction: 'sent',
      senderId: 1,
      recipientId: 102,
      status: 'pending',
      statusLabelAr: 'قيد الانتظار',
      canAccept: false,
      canReject: false,
      canCancel: true,
      createdAt: 'منذ يوم',
      member: MatchmakingMemberSummary(
        userId: 102,
        fullName: 'سارة المنصور',
        gender: 'female',
        ageYears: 28,
        maritalStatus: 'single',
        region: 'جدة',
        countryOfResidence: 'السعودية',
        photoPrivacy: 'public',
        photoAuthorized: true,
      ),
    ),
  ],
  accepted: [
    MatchmakingRequestItemModel(
      id: 10,
      direction: 'accepted',
      senderId: 103,
      recipientId: 1,
      status: 'accepted',
      statusLabelAr: 'مقبول',
      canAccept: false,
      canReject: false,
      canCancel: false,
      conversationId: 88,
      createdAt: 'منذ يومين',
      member: MatchmakingMemberSummary(
        userId: 103,
        fullName: 'مريم الهاشمي',
        gender: 'female',
        ageYears: 25,
        maritalStatus: 'single',
        region: 'دبي',
        countryOfResidence: 'الإمارات',
        photoPrivacy: 'public',
        photoAuthorized: true,
      ),
    ),
  ],
);

final _sampleConversations = [
  ConversationSummaryModel(
    id: 88,
    matchmakingRequestId: 11,
    status: 'active',
    isBlocked: false,
    canSendMessages: true,
    unreadCount: 2,
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
    lastMessage: const LastMessagePreviewModel(
      id: 991,
      senderId: 101,
      bodyPreview: 'وعليكم السلام ورحمة الله، تشرفت بمعرفتك',
      isRead: false,
    ),
    otherMember: _samplePartnerSummary,
  ),
];

final _sampleMessages = [
  ChatMessageModel(
    id: 990,
    conversationId: 88,
    senderId: 1,
    body: 'السلام عليكم ورحمة الله، أسعد الله أوقاتك بكل خير.',
    deliveryStatus: 'read',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
    sendState: OutgoingSendState.sent,
  ),
  ChatMessageModel(
    id: 991,
    conversationId: 88,
    senderId: 101,
    body: 'وعليكم السلام ورحمة الله، تشرفت بمعرفتك وباهتمامك الجاد.',
    deliveryStatus: 'read',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
    sendState: OutgoingSendState.sent,
  ),
];

final _sampleNotifications = [
  NotificationItemModel(
    id: 1,
    notificationType: 'matchmaking_request_received',
    titleAr: 'طلب تعارف جديد',
    bodyAr: 'أرسلت نورة العتيبي طلب تعارف جديد إلى ملفك الشخصي.',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  NotificationItemModel(
    id: 2,
    notificationType: 'new_message_received',
    titleAr: 'رسالة خاصة جديدة',
    bodyAr: 'وصلتك رسالة جديدة في محادثتك مع نورة العتيبي.',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
  NotificationItemModel(
    id: 3,
    notificationType: 'subscription_activated',
    titleAr: 'تم تفعيل الاشتراك الشهري',
    bodyAr: 'اشتراكك الشهري في نَصِيبُكَ نشط الآن مع إمكانية المراسلة غير المحدودة.',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

// ---------------------------------------------------------------------------
// Fake Implementation Classes
// ---------------------------------------------------------------------------

class _FakeSubscriptionRepository extends SubscriptionRepository {
  _FakeSubscriptionRepository()
      : super(
          apiClient: ApiClient(sessionStorage: const SecureSessionStorage()),
        );

  @override
  Future<SubscriptionOverviewResponse> fetchSubscriptionOverview() async {
    return SubscriptionOverviewResponse(
      entitlement: SubscriptionEntitlementModel(
        hasActiveSubscription: true,
        subscriptionStatus: 'active',
        canSendMatchRequests: true,
        canSendMessages: true,
        autoRenewing: true,
        paymentChannel: 'google_play',
        currentPeriodEnd: DateTime.now().add(const Duration(days: 27)),
      ),
      currentSubscription: SubscriptionRecordModel(
        id: 501,
        planCode: 'naseebak_monthly_premium',
        planNameAr: 'الباقة الشهرية المتميزة',
        channel: 'google_play',
        channelLabelAr: 'متجر Google Play',
        status: 'active',
        statusLabelAr: 'نشط',
        isCurrentlyEntitled: true,
        autoRenewing: true,
        startsAt: DateTime.now().subtract(const Duration(days: 3)),
        currentPeriodEnd: DateTime.now().add(const Duration(days: 27)),
      ),
      googlePlayManageUrl: 'https://play.google.com/store/account/subscriptions',
    );
  }

  @override
  Future<List<SubscriptionPlanModel>> fetchPlans() async {
    return const [
      SubscriptionPlanModel(
        id: 1,
        code: 'naseebak_monthly_premium',
        nameAr: 'الباقة الشهرية المتميزة',
        descriptionAr: 'وصول كامل ومراسلة غير محدودة',
        durationDays: 30,
        googlePlayProductId: 'naseebak_monthly_premium',
        featuresAr: ['مراسلة خاصة غير محدودة', 'تصفح كافة الملفات والصور', 'شارة عضو موثق'],
        renewalTermsAr: 'يتجدد الاشتراك شهرياً عبر Google Play ما لم يتم إلغاؤه قبل نهاية الفترة الحالية.',
        cancellationTermsAr: 'يمكنك إلغاء التجديد في أي وقت من متجر Google Play.',
      ),
    ];
  }

  @override
  Future<List<SubscriptionRecordModel>> fetchSubscriptionHistory() async {
    return [
      SubscriptionRecordModel(
        id: 501,
        planCode: 'naseebak_monthly_premium',
        planNameAr: 'الباقة الشهرية المتميزة',
        channel: 'google_play',
        channelLabelAr: 'متجر Google Play',
        status: 'active',
        statusLabelAr: 'نشط',
        isCurrentlyEntitled: true,
        autoRenewing: true,
        startsAt: DateTime.now().subtract(const Duration(days: 3)),
        currentPeriodEnd: DateTime.now().add(const Duration(days: 27)),
      ),
    ];
  }
}

class _FakeBillingClientService extends GooglePlayBillingClientService {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<StoreProductPricingModel?> querySubscriptionProduct(String productId) async {
    return const StoreProductPricingModel(
      productId: 'naseebak_monthly_premium',
      title: 'الباقة الشهرية المتميزة',
      description: 'وصول غير محدود لجميع مزايا نَصِيبُكَ',
      rawPrice: 49.99,
      currencyCode: 'SAR',
      formattedPrice: '49.99 ر.س',
    );
  }
}

class _FakeDiscoveryRepository extends Fake implements DiscoveryRepository {
  @override
  Future<List<MemberCardModel>> fetchFavorites() async => _sampleFavorites;

  @override
  Future<Uint8List> fetchAuthorizedPhotoBytes(int photoId) async => Uint8List(0);

  @override
  Future<String?> reportMember({
    required int memberUserId,
    required String reasonCategory,
    required String details,
    int? conversationId,
    int? messageId,
  }) async => null;

  @override
  Future<void> blockMember({
    required int memberUserId,
    String? reason,
  }) async {}
}

class _FakeMatchmakingRepository extends Fake implements MatchmakingRepository {
  @override
  Future<MatchmakingRequestsBundle> fetchAllRequests() async =>
      _sampleRequestsBundle;

  @override
  Future<MatchmakingCreateResult> sendMatchmakingRequest(int recipientId) async =>
      const MatchmakingCreateResult(
        isSuccess: true,
        message: 'تم إرسال طلب التعارف بنجاح',
      );

  @override
  Future<({MatchmakingRequestItemModel? request, int? conversationId, String message})>
      acceptRequest(int requestId) async => (
        request: _sampleRequestsBundle.incoming.firstOrNull,
        conversationId: 88,
        message: 'تم قبول طلب التعارف بنجاح',
      );

  @override
  Future<String> rejectRequest(int requestId) async => 'تم رفض طلب التعارف';

  @override
  Future<String> cancelRequest(int requestId) async => 'تم إلغاء طلب التعارف';
}

class _FakeMessagingRepository extends Fake implements MessagingRepository {
  @override
  Future<({
    List<ConversationSummaryModel> conversations,
    int currentPage,
    bool hasMorePages,
    bool viewerHasActiveSubscription,
  })> fetchConversations({int page = 1, int perPage = 20}) async {
    return (
      conversations: _sampleConversations,
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
      conversation: _sampleConversations.first,
      viewerHasActiveSubscription: true,
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
    return (
      messages: _sampleMessages,
      cursor: const MessagePaginationCursor(),
      isBlocked: false,
      canSendMessages: true,
      restrictionCode: null,
      otherLastReadMessageId: 991,
    );
  }

  @override
  Future<int?> markConversationRead(
    int conversationId, {
    int? upToMessageId,
  }) async => upToMessageId ?? 991;

  @override
  Future<MessageSendResult> sendMessage({
    required int conversationId,
    required String bodyText,
    required String clientMessageId,
  }) async =>
      MessageSendResult(
        isSuccess: true,
        message: 'تم إرسال الرسالة بنجاح',
        savedMessage: ChatMessageModel(
          id: 992,
          conversationId: conversationId,
          senderId: 1,
          body: bodyText,
          clientMessageId: clientMessageId,
          isRead: false,
          deliveryStatus: 'delivered_server',
          sendState: OutgoingSendState.sent,
        ),
      );
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
}

class _FakeNotificationRepository extends Fake implements NotificationRepository {
  @override
  Future<PaginatedNotificationsResponse> fetchNotifications({
    int page = 1,
    int perPage = 25,
    bool unreadOnly = false,
  }) async {
    return PaginatedNotificationsResponse(
      notifications: _sampleNotifications,
      unreadCount: 2,
      currentPage: 1,
      lastPage: 1,
      total: _sampleNotifications.length,
    );
  }

  @override
  Future<int> fetchUnreadCount() async => 2;

  @override
  Future<({NotificationItemModel notification, int unreadCount})> markAsRead(
    int notificationId,
  ) async {
    final item = _sampleNotifications.firstWhere((n) => n.id == notificationId);
    return (notification: item.copyWith(isRead: true), unreadCount: 1);
  }

  @override
  Future<int> markAllAsRead() async => 2;

  @override
  Future<int> deleteNotification(int notificationId) async => 1;

  @override
  Future<NotificationPreferencesModel> fetchPreferences() async =>
      const NotificationPreferencesModel(
        matchmakingRequestsEnabled: true,
        messagesEnabled: true,
        subscriptionsEnabled: true,
        announcementsEnabled: true,
      );

  @override
  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) async =>
      preferences;
}

class _FakePushNotificationService extends Fake
    implements PushNotificationService {
  final _permissionController =
      StreamController<NotificationPermissionStatus>.broadcast();
  final _foregroundController =
      StreamController<IncomingPushPayload>.broadcast();
  final _tapController = StreamController<IncomingPushPayload>.broadcast();

  @override
  NotificationPermissionStatus get permissionStatus =>
      NotificationPermissionStatus.granted;

  @override
  Stream<NotificationPermissionStatus> get permissionStatusStream =>
      _permissionController.stream;

  @override
  Stream<IncomingPushPayload> get foregroundPushStream =>
      _foregroundController.stream;

  @override
  Stream<IncomingPushPayload> get notificationTapStream =>
      _tapController.stream;

  @override
  bool get isFirebaseAvailable => false;

  @override
  Future<NotificationPermissionStatus> requestNotificationPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<void> initialize() async {}
}

// ---------------------------------------------------------------------------
// Screen Framing Helper
// ---------------------------------------------------------------------------

Widget _buildFramedScreen({
  required GlobalKey boundaryKey,
  required Widget child,
  bool darkStatusBar = false,
}) {
  return RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: darkStatusBar ? AppColors.primaryNavy : AppColors.cardWhite,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '9:41',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.signal_cellular_alt_rounded,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.wifi_rounded,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.battery_full_rounded,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _captureGoldenPng({
  required WidgetTester tester,
  required GlobalKey boundaryKey,
  required String outputPath,
}) async {
  for (final element in find.byType(Image).evaluate()) {
    final widget = element.widget as Image;
    precacheImage(widget.image, element);
  }
  await tester.pumpAndSettle();

  final previousAutoUpdate = autoUpdateGoldenFiles;
  autoUpdateGoldenFiles = true;
  try {
    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile(outputPath),
    );
  } finally {
    autoUpdateGoldenFiles = previousAutoUpdate;
  }
}

Future<void> _loadBundledFontsForTest() async {
  final fontFiles = [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ];

  final ibmLoader = FontLoader('IBMPlexSansArabic');
  for (final path in fontFiles) {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      ibmLoader.addFont(
        Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
      );
    }
  }
  await ibmLoader.load();

  final sdkMaterialFont = File(
    r'C:\Users\w.i\.gemini\antigravity\scratch\tools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );
  if (await sdkMaterialFont.exists()) {
    final iconBytes = await sdkMaterialFont.readAsBytes();
    final iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(iconBytes).buffer)),
    );
    await iconLoader.load();
  }
}

// ---------------------------------------------------------------------------
// Main Test Suite
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await _loadBundledFontsForTest();
  });

  List<Override> buildOverrides() {
    return [
      subscriptionRepositoryProvider
          .overrideWithValue(_FakeSubscriptionRepository()),
      googlePlayBillingServiceProvider
          .overrideWithValue(_FakeBillingClientService()),
      discoveryRepositoryProvider
          .overrideWithValue(_FakeDiscoveryRepository()),
      matchmakingRepositoryProvider
          .overrideWithValue(_FakeMatchmakingRepository()),
      messagingRepositoryProvider
          .overrideWithValue(_FakeMessagingRepository()),
      realtimeMessagingServiceProvider
          .overrideWithValue(_FakeRealtimeMessagingService()),
      notificationRepositoryProvider
          .overrideWithValue(_FakeNotificationRepository()),
      pushNotificationServiceProvider
          .overrideWithValue(_FakePushNotificationService()),
    ];
  }

  void seedProfileState(ProviderContainer container) {
    container.read(profileManagementProvider.notifier).syncFromRegistrationDraft(
          ProfileRegistrationDraft(
            fullName: 'عبدالله السعيد',
            gender: 'male',
            dateOfBirth: DateTime(1994, 1, 15),
            maritalStatus: 'single',
            previouslyMarried: false,
            hasChildren: false,
            childrenCount: 0,
            educationLevel: 'master',
            occupation: 'مهندس برمجيات وذكاء اصطناعي',
            heightCm: 178,
            smokingStatus: 'non_smoker',
            homeOwnership: 'owned',
            nationality: 'سعودي',
            countryOfResidence: 'المملكة العربية السعودية',
            region: 'الرياض',
            hobbies: const ['القراءة', 'الرياضة', 'السفر', 'العمل التطوعي'],
            bio:
                'أبحث عن شريكة حياة صالحة تشاركني بناء أسرة متماسكة قائمة على المودة والرحمة والاحترام المتبادل.',
          ),
        );
  }

  group(
    'Batch 2 — Multi-Viewport Responsive Verification (360dp, 393dp, 430dp)',
    () {
      const widths = [360.0, 393.0, 430.0];

      for (final width in widths) {
        testWidgets(
          'All Batch 2 screens render with zero overflow at ${width.toInt()}dp width',
          (tester) async {
            tester.view.physicalSize = Size(width * 3.0, 840 * 3.0);
            tester.view.devicePixelRatio = 3.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final container = ProviderContainer(overrides: buildOverrides());
            addTearDown(container.dispose);
            seedProfileState(container);

            // Screen 1: Subscription
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const SubscriptionScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 2: My Subscription
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const MySubscriptionScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 3: Favorites
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const FavoritesScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 4: Matchmaking Requests
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const MatchmakingRequestsScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 5: Conversations
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const ConversationsScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 6: Private Chat
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const ChatScreen(
                    conversationId: 88,
                    initialMemberName: 'نورة العتيبي',
                  ),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 7: My Profile
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const MyProfileScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 8: Edit Profile
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const EditProfileScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 9: Notification Center
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const NotificationCenterScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 10: Privacy Settings
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const PrivacySettingsScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 11: Notification Preferences
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const NotificationPreferencesScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 12: Blocked Members
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const BlockedMembersScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Screen 14: Delete Account
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: const DeleteAccountScreen(),
                  theme: AppTheme.lightTheme,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    },
  );

  testWidgets(
    'Batch 2 — Capture Real Flutter Screenshots of All 14 Screens into documentation/ui-redesign/batch2/',
    (tester) async {
      tester.view.physicalSize = const Size(393.0 * 3.0, 852.0 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const outDir = '../../documentation/ui-redesign/batch2';
      final container = ProviderContainer(overrides: buildOverrides());
      addTearDown(container.dispose);
      seedProfileState(container);

      // Pre-populate data
      container.read(subscriptionProvider.notifier).loadSubscriptionCenter();
      container.read(matchmakingProvider.notifier).loadRequests();
      container.read(messagingProvider.notifier).loadConversations();
      container.read(notificationProvider.notifier).fetchNotifications();

      // Screen 1: Monthly Subscription
      final key1 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key1,
            child: const SubscriptionScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key1,
        outputPath: '$outDir/11_subscription_monthly.png',
      );

      // Screen 2: My Subscription
      final key2 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key2,
            child: const MySubscriptionScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key2,
        outputPath: '$outDir/12_my_subscription.png',
      );

      // Screen 3: Favorites
      final key3 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key3,
            child: const FavoritesScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key3,
        outputPath: '$outDir/13_favorites.png',
      );

      // Screen 4: Matchmaking Requests
      final key4 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key4,
            child: const MatchmakingRequestsScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key4,
        outputPath: '$outDir/14_matchmaking_requests.png',
      );

      // Screen 5: Conversations List
      final key5 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key5,
            child: const ConversationsScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key5,
        outputPath: '$outDir/15_conversations_list.png',
      );

      // Screen 6: Private Chat
      final key6 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key6,
            child: const ChatScreen(
              conversationId: 88,
              initialMemberName: 'نورة العتيبي',
            ),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key6,
        outputPath: '$outDir/16_chat_private.png',
      );

      // Screen 7: My Profile
      final key7 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key7,
            child: const MyProfileScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key7,
        outputPath: '$outDir/17_my_profile.png',
      );

      // Screen 8: Edit Profile
      final key8 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key8,
            child: const EditProfileScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key8,
        outputPath: '$outDir/18_edit_profile.png',
      );

      // Screen 9: Notification Center
      final key9 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key9,
            child: const NotificationCenterScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key9,
        outputPath: '$outDir/19_notification_center.png',
      );

      // Screen 10: Privacy Settings
      final key10 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key10,
            child: const PrivacySettingsScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key10,
        outputPath: '$outDir/20_privacy_settings.png',
      );

      // Screen 11: Notification Preferences
      final key11 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key11,
            child: const NotificationPreferencesScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key11,
        outputPath: '$outDir/21_notification_preferences.png',
      );

      // Screen 12: Blocked Members
      final key12 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key12,
            child: const BlockedMembersScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key12,
        outputPath: '$outDir/22_blocked_members.png',
      );

      // Screen 13: Report Member Dialog
      final key13 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key13,
            child: const Center(
              child: ReportMemberDialog(
                memberUserId: 101,
                memberFullName: 'نورة العتيبي',
                conversationId: 88,
              ),
            ),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key13,
        outputPath: '$outDir/23_report_member_dialog.png',
      );

      // Screen 14: Delete Account
      final key14 = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildFramedScreen(
            boundaryKey: key14,
            child: const DeleteAccountScreen(),
          ),
        ),
      );
      await _captureGoldenPng(
        tester: tester,
        boundaryKey: key14,
        outputPath: '$outDir/24_delete_account.png',
      );
    },
  );
}
