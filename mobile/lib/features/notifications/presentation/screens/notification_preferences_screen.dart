import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/notification_provider.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final prefs = state.preferences;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          title: const Text('إعدادات الإشعارات'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSystemPermissionCard(context, ref, state),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'تفضيلات الإشعارات الفورية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'تحكم في أنواع الإشعارات الفورية التي ترغب في استلامها على هاتفك. تظل الإشعارات المهمة متاحة داخل مركز الإشعارات بالتطبيق.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  _buildPreferenceTile(
                    key: const ValueKey('pref_matchmaking_requests'),
                    icon: Icons.favorite_outline_rounded,
                    title: 'إشعارات طلبات التعارف',
                    subtitle: 'إشعارات الطلبات الواردة والقبول أو التحديثات',
                    value: prefs.matchmakingRequestsEnabled,
                    isUpdating: state.isUpdatingPreferences,
                    onChanged: (val) {
                      ref.read(notificationProvider.notifier).updatePreferences(
                            matchmakingRequestsEnabled: val,
                          );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildPreferenceTile(
                    key: const ValueKey('pref_messages'),
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'إشعارات الرسائل',
                    subtitle: 'إشعارات وصول رسائل جديدة في المحادثات المعتمدة',
                    value: prefs.messagesEnabled,
                    isUpdating: state.isUpdatingPreferences,
                    onChanged: (val) {
                      ref.read(notificationProvider.notifier).updatePreferences(
                            messagesEnabled: val,
                          );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildPreferenceTile(
                    key: const ValueKey('pref_subscriptions'),
                    icon: Icons.workspace_premium_outlined,
                    title: 'إشعارات الاشتراك',
                    subtitle: 'تأكيد التفعيل وتنبيهات اقتراب انتهاء الاشتراك',
                    value: prefs.subscriptionsEnabled,
                    isUpdating: state.isUpdatingPreferences,
                    onChanged: (val) {
                      ref.read(notificationProvider.notifier).updatePreferences(
                            subscriptionsEnabled: val,
                          );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildPreferenceTile(
                    key: const ValueKey('pref_announcements'),
                    icon: Icons.campaign_outlined,
                    title: 'الإعلانات العامة',
                    subtitle: 'تحديثات منصة نَصِيبُكَ والإشعارات العامة',
                    value: prefs.announcementsEnabled,
                    isUpdating: state.isUpdatingPreferences,
                    onChanged: (val) {
                      ref.read(notificationProvider.notifier).updatePreferences(
                            announcementsEnabled: val,
                          );
                    },
                  ),
                  ],
                ),
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemPermissionCard(
    BuildContext context,
    WidgetRef ref,
    NotificationCenterState state,
  ) {
    final isGranted = state.isSystemPermissionGranted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFEFF8FF) : const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? const Color(0xFFB2DDFF) : const Color(0xFFFEC84B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGranted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_paused_rounded,
                color:
                    isGranted ? AppColors.primaryBlue : const Color(0xFFB54708),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isGranted
                      ? 'إشعارات النظام مفعّلة على هذا الجهاز'
                      : 'إشعارات النظام غير مفعّلة حاليًا',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color:
                        isGranted ? AppColors.darkBlue : const Color(0xFF93370D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isGranted
                ? 'سيصلك تنبيه فوري عند ورود طلبات تعارف أو رسائل جديدة وفق تفضيلاتك أدناه.'
                : 'فعّل الإشعارات لتصلك طلبات التعارف والرسائل الجديدة.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_enable_system_notifications'),
                onPressed: () async {
                  await ref
                      .read(notificationProvider.notifier)
                      .requestNotificationPermission();
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('تفعيل الإشعارات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferenceTile({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isUpdating,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      key: key,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryBlue, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
      ),
      activeColor: AppColors.primaryBlue,
      value: value,
      onChanged: isUpdating ? null : onChanged,
    );
  }
}
