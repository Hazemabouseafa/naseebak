import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/subscription_provider.dart';
import 'subscription_screen.dart';

/// Subscription Management Screen (`اشتراكي`)
///
/// Displays:
/// - Current subscription status
/// - Subscription plan
/// - Billing channel (`google_play`, `paymob`, `sha7nawy`)
/// - Current period end
/// - Renewal status
/// - Subscription history
/// - Official Google Play subscription management guidance for Google Play subscribers
///   (never shows a fake local cancellation button).
/// - Accurate web renewal guidance for web subscribers.
class MySubscriptionScreen extends ConsumerStatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  ConsumerState<MySubscriptionScreen> createState() =>
      _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends ConsumerState<MySubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).loadSubscriptionCenter();
    });
  }

  Future<void> _showGooglePlaySubscriptionManagementDialog(
    String manageUrl,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundPrimary,
          title: const Text(
            'إدارة اشتراك Google Play',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تتم إدارة أو إلغاء التجديد التلقائي لاشتراكات أندرويد مباشرة عبر واجهة اشتراكات حسابك في متجر Google Play الرسمي.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: SelectableText(
                  manageUrl,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: manageUrl));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.primaryBlue,
                      content: Text(
                        'تم نسخ رابط إدارة اشتراكات متجر Google Play.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('نسخ رابط الإدارة'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);
    final currentSub = state.currentSubscription;
    final entitlement = state.entitlement;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('اشتراكي'),
        actions: [
          IconButton(
            key: const Key('refresh_my_subscription_btn'),
            tooltip: 'تحديث حالة الاشتراك',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: state.isLoading
                ? null
                : () {
                    ref
                        .read(subscriptionProvider.notifier)
                        .refreshEntitlementOnly();
                  },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: state.isLoading && currentSub == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Current Subscription Card
                    Container(
                      key: const Key('my_subscription_summary_card'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: entitlement.hasActiveSubscription
                              ? AppColors.primaryBlue
                              : AppColors.borderLight,
                          width: entitlement.hasActiveSubscription ? 1.5 : 1.0,
                        ),
                      ),
                      child: currentSub == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Icon(
                                  Icons.card_membership_outlined,
                                  size: 42,
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'لا يوجد اشتراك مسجل حالياً',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'يمكنك تفعيل العضوية الشهرية للبدء في إرسال طلبات التعارف والتواصل مع الأعضاء بعد قبول الطلب.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    height: 1.7,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  key: const Key('go_to_subscription_screen_btn'),
                                  onPressed: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const SubscriptionScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('عرض باقة الاشتراك الشهري'),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        currentSub.planNameAr,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: currentSub.isCurrentlyEntitled
                                            ? AppColors.surfaceSubtleBlue
                                            : AppColors.surfaceSubtleYellow,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        currentSub.statusLabelAr,
                                        key: const Key(
                                          'current_subscription_status_badge',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                _DetailRow(
                                  label: 'قناة الاشتراك',
                                  value: currentSub.channelLabelAr,
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  label: 'تاريخ بداية الاشتراك',
                                  value: currentSub.startsAt != null
                                      ? _formatDate(currentSub.startsAt!)
                                      : '-',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  label: 'نهاية الفترة الحالية',
                                  value: currentSub.currentPeriodEnd != null
                                      ? _formatDate(
                                          currentSub.currentPeriodEnd!,
                                        )
                                      : '-',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  label: 'حالة التجديد',
                                  value: currentSub.channel == 'google_play'
                                      ? (currentSub.autoRenewing
                                          ? 'يتجدد تلقائياً عبر Google Play'
                                          : 'ملغى التجديد التلقائي (ينتهي بنهاية الفترة)')
                                      : 'تجديد شهري يدوي دون سحب تلقائي متكرر',
                                ),
                                const SizedBox(height: 16),

                                // Channel-specific management guidance
                                if (currentSub.channel == 'google_play')
                                  OutlinedButton.icon(
                                    key: const Key(
                                      'manage_google_play_subscription_btn',
                                    ),
                                    onPressed: () =>
                                        _showGooglePlaySubscriptionManagementDialog(
                                      state.googlePlayManageUrl,
                                    ),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'إدارة الاشتراك في متجر Google Play',
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'تم تفعيل هذا الاشتراك عبر بوابة الدفع الإلكترونية لمدة 30 يوماً محددة، ولا يتم خصم أي مبالغ متكررة تلقائياً.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.65,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Subscription History Section
                    if (state.history.isNotEmpty) ...[
                      const Text(
                        'سجل الاشتراكات السابقة والحالية',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...state.history.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.planNameAr,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.channelLabelAr} • حتى ${item.currentPeriodEnd != null ? _formatDate(item.currentPeriodEnd!) : '-'}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                item.statusLabelAr,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: item.isCurrentlyEntitled
                                      ? AppColors.primaryBlue
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
