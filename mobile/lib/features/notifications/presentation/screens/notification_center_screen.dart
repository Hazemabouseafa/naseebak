import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/notification_navigation_service.dart';
import '../providers/notification_provider.dart';
import 'notification_preferences_screen.dart';

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
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('الإشعارات'),
              if (state.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.unreadCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (state.unreadCount > 0)
              TextButton.icon(
                key: const ValueKey('btn_mark_all_read'),
                onPressed: state.isMarkingAllRead
                    ? null
                    : () {
                        ref
                            .read(notificationProvider.notifier)
                            .markAllNotificationsAsRead();
                      },
                icon: const Icon(
                  Icons.done_all_rounded,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
                label: const Text(
                  'تحديد الكل كمقروء',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            IconButton(
              key: const ValueKey('btn_open_notification_preferences'),
              tooltip: 'إعدادات الإشعارات',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                );
              },
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
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFEC84B)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFFB54708),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'فعّل الإشعارات لتصلك طلبات التعارف والرسائل الجديدة.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF93370D),
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
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'تفعيل الإشعارات',
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    if (state.errorMessage != null && state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const ValueKey('btn_retry_notifications'),
                onPressed: () {
                  ref
                      .read(notificationProvider.notifier)
                      .fetchNotifications(refresh: true);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref
            .read(notificationProvider.notifier)
            .fetchNotifications(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 42,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد إشعارات حاليًا',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        'ستظهر هنا إشعارات طلبات التعارف والرسائل الجديدة وتحديثات الاشتراك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(notificationProvider.notifier)
          .fetchNotifications(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount:
            state.notifications.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= state.notifications.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryBlue,
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
        color: isUnread ? const Color(0xFFF0F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread
              ? AppColors.primaryBlue.withOpacity(0.35)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                              fontSize: 14.5,
                              fontWeight:
                                  isUnread ? FontWeight.bold : FontWeight.w600,
                              color: AppColors.darkBlue,
                            ),
                          ),
                        ),
                        Text(
                          _formatRelativeTimestamp(item.createdAtDateTime),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.bodyAr,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isUnread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('btn_delete_notification_${item.id}'),
                tooltip: 'حذف الإشعار',
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.grey.shade500,
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
        bgColor = const Color(0xFFEFF8FF);
        iconColor = AppColors.primaryBlue;
        break;
      case 'subscription_activated':
      case 'subscription_expiring_soon':
      case 'subscription_expired':
        icon = Icons.workspace_premium_rounded;
        bgColor = const Color(0xFFFFFAEB);
        iconColor = const Color(0xFFD97706);
        break;
      default:
        icon = Icons.campaign_rounded;
        bgColor = const Color(0xFFF4F3FF);
        iconColor = AppColors.darkBlue;
        break;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
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
