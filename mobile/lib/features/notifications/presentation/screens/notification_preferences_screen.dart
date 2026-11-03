import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/notification_provider.dart';

/// Screen 11 (Batch 2B) — Notification Preferences Screen (`إعدادات الإشعارات`)
/// شاشة تفضيلات الإشعارات الفورية بتصميم نَصِيبُكَ الفاخر (Astra Design System)
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final prefs = state.preferences;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NaseebakColors.backgroundBeige,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'إعدادات الإشعارات',
              subtitle: 'التحكم في التنبيهات الفورية التي تصل إلى هاتفك',
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'رجوع',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  _buildSystemPermissionCard(context, ref, state),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: NaseebakColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NaseebakColors.borderLight),
                      boxShadow: const [
                        BoxShadow(
                          color: NaseebakColors.shadowColor,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                          child: Text(
                            'تفضيلات التنبيهات الفورية',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: NaseebakColors.textDarkNavy,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'حدد فئات الإشعارات التي ترغب في تلقيها فوراً على شاشة القفل وجهازك:',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: NaseebakColors.textWarmGray,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                          subtitle: 'تأكيد التفعيل وتنبيهات اقتراب موعد التجديد',
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
                          subtitle: 'المستجدات والخدمات الجديدة وإرشادات الاستخدام',
                          value: prefs.announcementsEnabled,
                          isUpdating: state.isUpdatingPreferences,
                          onChanged: (val) {
                            ref.read(notificationProvider.notifier).updatePreferences(
                                  announcementsEnabled: val,
                                );
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NaseebakColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: NaseebakColors.error.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: NaseebakColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                color: NaseebakColors.error,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
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
        color: isGranted
            ? NaseebakColors.cardBackground
            : NaseebakColors.accentGoldMuted.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted
              ? NaseebakColors.borderLight
              : NaseebakColors.accentGold.withOpacity(0.4),
        ),
        boxShadow: const [
          BoxShadow(
            color: NaseebakColors.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted
                      ? NaseebakColors.accentGoldMuted.withOpacity(0.3)
                      : NaseebakColors.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGranted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_paused_rounded,
                  color: isGranted
                      ? NaseebakColors.accentGoldDark
                      : NaseebakColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isGranted
                      ? 'إشعارات النظام مفعّلة على هذا الجهاز'
                      : 'إشعارات النظام غير مفعّلة حاليًا',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: NaseebakColors.textDarkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isGranted
                ? 'سيصلك تنبيه فوري عند ورود طلبات تعارف أو رسائل جديدة وفق تفضيلاتك أدناه.'
                : 'فعّل الإشعارات على هاتفك لتصلك طلبات التعارف والرسائل الخاصة في وقتها.',
            style: const TextStyle(
              fontSize: 12.5,
              color: NaseebakColors.textWarmGray,
              height: 1.55,
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
                label: const Text('تفعيل إشعارات الجهاز الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NaseebakColors.primaryNavy,
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: NaseebakColors.accentGoldMuted.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: NaseebakColors.primaryNavy, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: NaseebakColors.textDarkNavy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11.5,
          color: NaseebakColors.textWarmGray,
          height: 1.4,
        ),
      ),
      activeColor: NaseebakColors.accentGoldDark,
      activeTrackColor: NaseebakColors.accentGoldMuted,
      value: value,
      onChanged: isUpdating ? null : onChanged,
    );
  }
}
