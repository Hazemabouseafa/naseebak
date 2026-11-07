import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/naseebak_design_system.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/notification_navigation_service.dart';
import '../providers/notification_provider.dart';
import 'notification_preferences_screen.dart';

/// Screen 09 (Batch 2B) — Notification Center Screen (`مركز الإشعارات`)
/// شاشة عرض الإشعارات والتنبيهات المعتمدة بتصميم نَصِيبُكَ الفاخر (Astra Design System)
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications(refresh: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      ref.read(notificationProvider.notifier).fetchNotifications(refresh: false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cardWhite,
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          centerTitle: true,
          leading: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: NaseebakCircleButton(
                icon: Icons.arrow_forward_rounded,
                size: 40,
                iconSize: 20,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'رجوع',
              ),
            ),
          ),
          title: const Text(
            'الإشعارات',
            style: TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            if (state.unreadCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: const TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                key: const ValueKey('btn_mark_all_read'),
                onPressed: state.isMarkingAllRead
                    ? null
                    : () {
                        ref
                            .read(notificationProvider.notifier)
                            .markAllNotificationsAsRead();
                      },
                child: const Text(
                  'تحديد الكل كمقروء',
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    color: AppColors.primaryBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: NaseebakCircleButton(
                key: const ValueKey('btn_open_notification_preferences'),
                tooltip: 'إعدادات الإشعارات',
                icon: Icons.tune_rounded,
                size: 40,
                iconSize: 20,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationPreferencesScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (!state.isSystemPermissionGranted)
              _buildPermissionPromptBanner(context, ref),
            Expanded(
              child: _buildBody(context, ref, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionPromptBanner(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NaseebakColors.accentGoldMuted.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NaseebakColors.accentGold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: NaseebakColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: NaseebakColors.accentGoldDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'فعّل الإشعارات لتصلك طلبات التعارف والرسائل الجديدة.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: NaseebakColors.primaryNavyDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: const ValueKey('btn_banner_enable_notifications'),
            onPressed: () {
              ref
                  .read(notificationProvider.notifier)
                  .requestNotificationPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: NaseebakColors.primaryNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'تفعيل',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationCenterState state,
  ) {
    if (state.isLoading && state.notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NaseebakLoadingSkeleton(height: 80),
          SizedBox(height: 12),
          NaseebakLoadingSkeleton(height: 80),
          SizedBox(height: 12),
          NaseebakLoadingSkeleton(height: 80),
        ],
      );
    }

    if (state.errorMessage != null && state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: NaseebakColors.cardBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: NaseebakColors.errorBorder),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: NaseebakColors.error,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: NaseebakColors.textDarkNavy,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const ValueKey('btn_retry_notifications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NaseebakColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ref
                      .read(notificationProvider.notifier)
                      .fetchNotifications(refresh: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return RefreshIndicator(
        color: NaseebakColors.accentGold,
        onRefresh: () => ref
            .read(notificationProvider.notifier)
            .fetchNotifications(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 60),
            NaseebakEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'لا توجد إشعارات حاليًا',
              subtitle:
                  'ستظهر هنا إشعارات طلبات التعارف والرسائل الخاصة وتحديثات اشتراكك أولاً بأول.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: NaseebakColors.accentGold,
      onRefresh: () => ref
          .read(notificationProvider.notifier)
          .fetchNotifications(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount:
            state.notifications.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= state.notifications.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NaseebakColors.accentGold,
                  ),
                ),
              ),
            );
          }

          final item = state.notifications[index];
          return _buildNotificationCard(context, ref, item);
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationItemModel item,
  ) {
    final isUnread = !item.isRead;

    return Container(
      key: ValueKey('notification_item_${item.id}'),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.surfaceSubtleBlue
            : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppColors.primaryBlue.withOpacity(0.3)
              : AppColors.subtleBorder,
          width: isUnread ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (!item.isRead) {
            await ref
                .read(notificationProvider.notifier)
                .markNotificationAsRead(item.id);
          }
          if (!context.mounted) return;
          await NotificationNavigationService.navigateFromNotification(
            context: context,
            ref: ref,
            notification: item,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeIcon(item.notificationType, isUnread),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUnread) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            item.titleAr,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 14.5,
                              fontWeight:
                                  isUnread ? FontWeight.w800 : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _formatRelativeTimestamp(item.createdAtDateTime),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isUnread
                                ? NaseebakColors.accentGoldDark
                                : NaseebakColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.bodyAr,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnread
                            ? NaseebakColors.textDarkNavy
                            : NaseebakColors.textWarmGray,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('btn_delete_notification_${item.id}'),
                tooltip: 'حذف الإشعار',
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: NaseebakColors.textMuted,
                ),
                onPressed: () {
                  ref
                      .read(notificationProvider.notifier)
                      .deleteNotification(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type, bool isUnread) {
    IconData icon;
    Color bgColor;
    Color iconColor;

    switch (type) {
      case 'matchmaking_request_received':
      case 'matchmaking_request_accepted':
      case 'matchmaking_request_rejected':
        icon = Icons.favorite_rounded;
        bgColor = const Color(0xFFFFF1F3);
        iconColor = const Color(0xFFE11D48);
        break;
      case 'new_message_received':
        icon = Icons.chat_bubble_rounded;
        bgColor = AppColors.surfaceSubtleBlue;
        iconColor = AppColors.primaryBlue;
        break;
      case 'subscription_activated':
      case 'subscription_expiring_soon':
      case 'subscription_expired':
        icon = Icons.workspace_premium_rounded;
        bgColor = const Color(0xFFFEF9EE);
        iconColor = AppColors.goldAccent;
        break;
      default:
        icon = Icons.notifications_rounded;
        bgColor = AppColors.surfaceSubtleBlue;
        iconColor = AppColors.primaryBlue;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  String _formatRelativeTimestamp(DateTime? dt) {
    if (dt == null) return 'الآن';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} ي';
  }
}
