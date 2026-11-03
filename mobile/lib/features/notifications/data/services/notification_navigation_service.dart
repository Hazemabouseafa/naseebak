import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../matchmaking/presentation/screens/matchmaking_requests_screen.dart';
import '../../../messaging/data/repositories/messaging_repository.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../presentation/screens/notification_center_screen.dart';
import '../models/notification_model.dart';
import 'push_notification_service.dart';

class NotificationNavigationResult {
  final bool navigated;
  final bool redirectedToSignIn;
  final String? errorMessage;

  const NotificationNavigationResult({
    required this.navigated,
    this.redirectedToSignIn = false,
    this.errorMessage,
  });
}

final notificationNavigationServiceProvider =
    Provider<NotificationNavigationService>((ref) {
  return NotificationNavigationService(ref: ref);
});

class NotificationNavigationService {
  final Ref _ref;

  static const Set<String> allowlistedRoutes = {
    'matchmaking_incoming',
    'matchmaking_accepted',
    'matchmaking_sent',
    'conversation',
    'subscription',
    'notification_center',
  };

  const NotificationNavigationService({required Ref ref}) : _ref = ref;

  /// Validates whether an actionRoute is a safe, allowlisted internal destination.
  /// Rejects any external URL or unallowlisted route string.
  static bool isAllowlistedRoute(String? actionRoute) {
    if (actionRoute == null || actionRoute.trim().isEmpty) return false;
    final trimmed = actionRoute.trim();
    if (trimmed.contains('://') || trimmed.startsWith('http')) {
      return false;
    }
    return allowlistedRoutes.contains(trimmed);
  }

  /// Securely navigates to the target screen for a notification ONLY after verifying:
  /// 1. Allowlisted internal route
  /// 2. Active authenticated session
  /// 3. Server-side resource authorization (e.g. conversation membership & block status)
  Future<NotificationNavigationResult> handleNotificationNavigation({
    required BuildContext context,
    required String actionRoute,
    Map<String, dynamic> routingMetadata = const {},
    int? fallbackReferenceId,
  }) async {
    if (!isAllowlistedRoute(actionRoute)) {
      return const NotificationNavigationResult(
        navigated: false,
        errorMessage: 'وجهة الإشعار غير مدعومة.',
      );
    }

    // 1. Verify authenticated session
    final authState = _ref.read(authControllerProvider);
    final isAuthenticated = authState.user != null &&
        authState.destination != AuthDestination.welcome &&
        authState.destination != AuthDestination.googleSignIn &&
        authState.destination != AuthDestination.suspended;

    if (!isAuthenticated) {
      _ref.read(authControllerProvider.notifier).navigateToGoogleSignIn();
      return const NotificationNavigationResult(
        navigated: false,
        redirectedToSignIn: true,
        errorMessage: 'يرجى تسجيل الدخول أولاً لعرض محتوى الإشعار.',
      );
    }

    // 2. Handle conversation destination with strict pre-navigation authorization check
    if (actionRoute == 'conversation') {
      final rawConvId =
          routingMetadata['conversation_id'] ?? fallbackReferenceId;
      final conversationId = rawConvId is int
          ? rawConvId
          : int.tryParse('${rawConvId ?? ''}');

      if (conversationId == null || conversationId <= 0) {
        return const NotificationNavigationResult(
          navigated: false,
          errorMessage: 'معرف المحادثة غير صالح.',
        );
      }

      try {
        final messagingRepo = _ref.read(messagingRepositoryProvider);
        final detail =
            await messagingRepo.fetchConversationDetail(conversationId);

        if (detail.conversation.isBlocked ||
            detail.conversation.status == 'blocked') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.error,
                content: Text('لم تعد هذه المحادثة متاحة بسبب الحظر.'),
              ),
            );
          }
          return const NotificationNavigationResult(
            navigated: false,
            errorMessage: 'لم تعد هذه المحادثة متاحة بسبب الحظر.',
          );
        }

        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatScreen(
                conversationId: conversationId,
                initialMemberName: detail.conversation.otherMember.fullName,
              ),
            ),
          );
        }
        return const NotificationNavigationResult(navigated: true);
      } catch (_) {
        const msg =
            'غير مصرح لك بالوصول إلى هذه المحادثة أو لم تعد متاحة حالياً.';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text(msg),
            ),
          );
        }
        return const NotificationNavigationResult(
          navigated: false,
          errorMessage: msg,
        );
      }
    }

    // 3. Handle matchmaking request tabs
    if (actionRoute == 'matchmaking_incoming' ||
        actionRoute == 'matchmaking_accepted' ||
        actionRoute == 'matchmaking_sent') {
      final initialTab = switch (actionRoute) {
        'matchmaking_accepted' => 2,
        'matchmaking_sent' => 1,
        _ => 0,
      };
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MatchmakingRequestsScreen(
              initialTabIndex: initialTab,
            ),
          ),
        );
      }
      return const NotificationNavigationResult(navigated: true);
    }

    // 4. Handle subscription screen
    if (actionRoute == 'subscription') {
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SubscriptionScreen(),
          ),
        );
      }
      return const NotificationNavigationResult(navigated: true);
    }

    // 5. Default: Notification Center
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationCenterScreen(),
        ),
      );
    }
    return const NotificationNavigationResult(navigated: true);
  }

  static Future<NotificationNavigationResult> navigateFromNotification({
    required BuildContext context,
    required WidgetRef ref,
    required NotificationItemModel notification,
  }) {
    return ref
        .read(notificationNavigationServiceProvider)
        .handleNotificationNavigation(
          context: context,
          actionRoute: notification.actionRoute,
          routingMetadata: notification.routingMetadata,
          fallbackReferenceId: notification.referenceId,
        );
  }

  static Future<NotificationNavigationResult> navigateFromPushPayload({
    required BuildContext context,
    required WidgetRef ref,
    required IncomingPushPayload payload,
  }) {
    return ref
        .read(notificationNavigationServiceProvider)
        .handleNotificationNavigation(
          context: context,
          actionRoute: payload.actionRoute,
          routingMetadata: payload.routingMetadata,
          fallbackReferenceId: payload.notificationId,
        );
  }
}
