import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../matchmaking/presentation/screens/matchmaking_requests_screen.dart';
import '../../../messaging/data/services/realtime_messaging_service.dart';
import '../../../messaging/presentation/screens/conversations_screen.dart';
import '../../../notifications/data/services/notification_navigation_service.dart';
import '../../../notifications/data/services/push_notification_service.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/screens/my_profile_screen.dart';
import '../providers/discovery_provider.dart';
import 'advanced_search_screen.dart';
import 'discovery_home_screen.dart';

/// Main Authenticated Shell with 5 Bottom Navigation Tabs (UX Pilot RTL):
/// 1. الرئيسية -> Opens DiscoveryHomeScreen (Screen 03)
/// 2. البحث -> Opens AdvancedSearchScreen (Screen 04)
/// 3. الطلبات -> Opens MatchmakingRequestsScreen (Screen 07)
/// 4. المحادثات -> Opens ConversationsScreen (Screen 08)
/// 5. حسابي -> Opens MyProfileScreen (Screen 13)
class HomeDiscoveryPlaceholderScreen extends ConsumerStatefulWidget {
  const HomeDiscoveryPlaceholderScreen({super.key});

  @override
  ConsumerState<HomeDiscoveryPlaceholderScreen> createState() =>
      _HomeDiscoveryPlaceholderScreenState();
}

class _HomeDiscoveryPlaceholderScreenState
    extends ConsumerState<HomeDiscoveryPlaceholderScreen> {
  int _selectedIndex = 0;
  StreamSubscription<IncomingPushPayload>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authControllerProvider).user?.id;
      if (userId != null && userId > 0) {
        ref.read(realtimeMessagingServiceProvider).connectForUser(userId);
      }
      ref
          .read(notificationProvider.notifier)
          .initializeForAuthenticatedUser();

      _notificationTapSubscription?.cancel();
      _notificationTapSubscription = ref
          .read(pushNotificationServiceProvider)
          .notificationTapStream
          .listen((payload) {
        if (!mounted) return;
        final notifId = payload.notificationId;
        if (notifId != null && notifId > 0) {
          ref
              .read(notificationProvider.notifier)
              .markNotificationAsRead(notifId);
        }
        NotificationNavigationService.navigateFromPushPayload(
          context: context,
          ref: ref,
          payload: payload,
        );
      });
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBackground,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DiscoveryHomeScreen(
            onOpenMyProfileTab: () => setState(() => _selectedIndex = 4),
          ),
          AdvancedSearchScreen(
            openedFromResults: false,
            onCloseTab: () => setState(() => _selectedIndex = 0),
          ),
          const MatchmakingRequestsScreen(),
          const ConversationsScreen(),
          const MyProfileScreen(),
        ],
      ),
      bottomNavigationBar: NaseebakBottomNavigation(
        selectedIndex: _selectedIndex,
        isFiveTabs: true,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            ref.read(discoveryProvider.notifier).loadDiscoveryFeed();
          }
        },
      ),
    );
  }
}
