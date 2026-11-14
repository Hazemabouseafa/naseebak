import '../config/app_environment.dart';

class ApiEndpoints {
  ApiEndpoints._();

  /// Active build-time environment configuration (development | staging | production)
  static final AppEnvironmentConfig environmentConfig =
      AppEnvironmentConfig.fromBuildDefines();

  /// Base URL configured via --dart-define=API_BASE_URL=https://...
  static String get baseUrl => environmentConfig.apiBaseUrl;

  /// Laravel Reverb WebSocket URL configured via --dart-define=REVERB_WS_URL=wss://...
  static String get reverbWsUrl => environmentConfig.reverbWsUrl;

  /// Server Web Client ID used by GoogleSignIn to issue verifiable ID tokens
  static String get googleServerClientId =>
      environmentConfig.googleServerClientId;

  /// Android OAuth Client ID
  static String get googleAndroidClientId =>
      environmentConfig.googleAndroidClientId;

  /// Health check endpoint
  static const String health = '/health';

  // Authentication
  static const String authGoogle = '/auth/google';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';
  static const String authDeleteAccount = '/auth/account';

  // Phase 1 & Phase 2: Profile Management & Privacy
  static const String profile = '/profile';
  static const String profileComplete = '/profile/complete';
  static const String profilePhoto = '/profile/photo';
  static const String profilePrivacy = '/profile/privacy';

  static String photoStream(int photoId) => '/profile/photos/$photoId/stream';

  // Phase 3: Discovery, Search, Preferences, Member Profiles, Favorites & Safety
  static const String discovery = '/discovery';
  static const String membersSearch = '/members/search';
  static const String searchPreferences = '/search/preferences';
  static const String favorites = '/favorites';
  static const String blockedMembers = '/blocked-members';

  static String memberProfile(int userId) => '/members/$userId/profile';
  static String favoriteMember(int userId) => '/favorites/$userId';
  static String blockMember(int userId) => '/members/$userId/block';
  static String unblockMember(int userId) => '/members/$userId/block';
  static String reportMember(int userId) => '/members/$userId/report';

  // Phase 5: Monthly Subscriptions & Google Play Purchase Verification
  static const String subscription = '/subscription';
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionEntitlement = '/subscription/entitlement';
  static const String subscriptionVerifyGooglePlay =
      '/subscription/google-play/verify';
  static const String subscriptionHistory = '/subscription/history';

  // Phase 6: Matchmaking Requests, Private Conversations, Messaging & Reverb Auth
  static const String matchmakingRequests = '/matchmaking/requests';
  static String matchmakingRequestDetail(int requestId) =>
      '/matchmaking/requests/$requestId';
  static String acceptMatchmakingRequest(int requestId) =>
      '/matchmaking/requests/$requestId/accept';
  static String rejectMatchmakingRequest(int requestId) =>
      '/matchmaking/requests/$requestId/reject';
  static String cancelMatchmakingRequest(int requestId) =>
      '/matchmaking/requests/$requestId/cancel';

  static const String conversations = '/conversations';
  static String conversationDetail(int conversationId) =>
      '/conversations/$conversationId';
  static String conversationMessages(int conversationId) =>
      '/conversations/$conversationId/messages';
  static String conversationMarkRead(int conversationId) =>
      '/conversations/$conversationId/read';

  static const String broadcastingAuth = '/broadcasting/auth';

  // Phase 7: FCM Device Token Registration, In-App Notification Center & Preferences
  static const String devicesRegister = '/devices/register';
  static const String devicesUnregister = '/devices/unregister';
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationMarkRead(int notificationId) =>
      '/notifications/$notificationId/read';
  static String notificationDelete(int notificationId) =>
      '/notifications/$notificationId';
  static const String notificationPreferences = '/notification-preferences';

  // Phase 20: Member Support Inquiries & Complaints
  static const String supportTickets = '/support/tickets';
  static String supportTicketDetail(int ticketId) =>
      '/support/tickets/$ticketId';
  static String supportTicketReplies(int ticketId) =>
      '/support/tickets/$ticketId/replies';
}
