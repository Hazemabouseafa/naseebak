import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/subscription_provider.dart';
import 'subscription_screen.dart';

/// Screen 02 (Batch 2A) — Subscription Management Screen (`اشتراكي`)
/// واجهة إدارة وتفاصيل العضوية الشهرية المعتمدة بتصميم Astra الفاخر.
/// تعرض تفاصيل الباقة، تاريخ الانتهاء أو التجديد، القناة المعتمدة، وسجل الاشتراكات السابقة.
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
        child: Dialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.creamHighlight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.goldAccent),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: AppColors.primaryNavy,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'إدارة اشتراك Google Play',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تتم إدارة أو إلغاء التجديد التلقائي لاشتراكات أندرويد مباشرة عبر واجهة اشتراكات حسابك في متجر Google Play الرسمي.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.subtleBorder),
                  ),
                  child: SelectableText(
                    manageUrl,
                    style: const TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 12,
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          side: const BorderSide(color: AppColors.subtleBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: manageUrl));
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.primaryNavy,
                                content: Text(
                                  'تم نسخ رابط إدارة اشتراكات متجر Google Play.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'نسخ الرابط',
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'حسناً',
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);
    final currentSub = state.currentSubscription;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBackground,
        body: Column(
          children: [
            // Premium Royal Navy Curved Header
            NaseebakCurvedHeader(
              title: 'اشتراكي',
              subtitle: 'إدارة وتفاصيل العضوية المعتمدة',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).pop()
                  : null,
              actions: [
                IconButton(
                  key: const Key('refresh_my_subscription_btn'),
                  tooltip: 'تحديث حالة الاشتراك',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  onPressed: state.isLoading
                      ? null
                      : () {
                          ref
                              .read(subscriptionProvider.notifier)
                              .refreshEntitlementOnly();
                        },
                ),
              ],
            ),

            Expanded(
              child: state.isLoading && currentSub == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryNavy,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Current Subscription Card
                          NaseebakCard(
                            key: const Key('my_subscription_summary_card'),
                            padding: const EdgeInsets.all(20),
                            child: currentSub == null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: AppColors.creamHighlight,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.goldAccent,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.card_membership_rounded,
                                            size: 32,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'لا يوجد اشتراك مسجل حالياً',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily:
                                              NaseebakTypography.fontFamily,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'يمكنك تفعيل العضوية الشهرية للبدء في إرسال طلبات التعارف والتواصل مع الأعضاء بعد قبول الطلب.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily:
                                              NaseebakTypography.fontFamily,
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          height: 1.65,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        key: const Key(
                                            'go_to_subscription_screen_btn'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryNavy,
                                          foregroundColor: Colors.white,
                                          minimumSize:
                                              const Size.fromHeight(50),
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const SubscriptionScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'عرض باقة الاشتراك الشهري',
                                          style: TextStyle(
                                            fontFamily:
                                                NaseebakTypography.fontFamily,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              currentSub.planNameAr,
                                              style: const TextStyle(
                                                fontFamily: NaseebakTypography
                                                    .fontFamily,
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryNavy,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: currentSub
                                                      .isCurrentlyEntitled
                                                  ? AppColors.creamHighlight
                                                  : AppColors.subtleBorder,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: currentSub
                                                        .isCurrentlyEntitled
                                                    ? AppColors.goldAccent
                                                    : AppColors.textSecondary
                                                        .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              currentSub.statusLabelAr,
                                              key: const Key(
                                                'current_subscription_status_badge',
                                              ),
                                              style: TextStyle(
                                                fontFamily: NaseebakTypography
                                                    .fontFamily,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: currentSub
                                                        .isCurrentlyEntitled
                                                    ? AppColors.primaryNavy
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 16),
                                        child: Divider(
                                          height: 1,
                                          color: AppColors.subtleBorder,
                                        ),
                                      ),
                                      _DetailRow(
                                        label: 'قناة الاشتراك',
                                        value: currentSub.channelLabelAr,
                                      ),
                                      const SizedBox(height: 12),
                                      _DetailRow(
                                        label: 'تاريخ بداية الاشتراك',
                                        value: currentSub.startsAt != null
                                            ? _formatDate(currentSub.startsAt!)
                                            : '-',
                                      ),
                                      const SizedBox(height: 12),
                                      _DetailRow(
                                        label: 'نهاية الفترة الحالية',
                                        value:
                                            currentSub.currentPeriodEnd != null
                                                ? _formatDate(
                                                    currentSub
                                                        .currentPeriodEnd!,
                                                  )
                                                : '-',
                                      ),
                                      const SizedBox(height: 12),
                                      _DetailRow(
                                        label: 'حالة التجديد',
                                        value: currentSub.channel ==
                                                'google_play'
                                            ? (currentSub.autoRenewing
                                                ? 'يتجدد تلقائياً عبر Google Play'
                                                : 'ملغى التجديد التلقائي (ينتهي بنهاية الفترة)')
                                            : 'تجديد شهري يدوي دون سحب تلقائي متكرر',
                                      ),
                                      const SizedBox(height: 20),

                                      // Channel-specific management guidance
                                      if (currentSub.channel == 'google_play')
                                        OutlinedButton.icon(
                                          key: const Key(
                                            'manage_google_play_subscription_btn',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppColors.primaryNavy,
                                            minimumSize:
                                                const Size.fromHeight(48),
                                            side: const BorderSide(
                                              color: AppColors.subtleBorder,
                                              width: 1.2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _showGooglePlaySubscriptionManagementDialog(
                                            state.googlePlayManageUrl,
                                          ),
                                          icon: const Icon(
                                            Icons.open_in_new_rounded,
                                            size: 18,
                                            color: AppColors.primaryNavy,
                                          ),
                                          label: const Text(
                                            'إدارة الاشتراك في متجر Google Play',
                                            style: TextStyle(
                                              fontFamily: NaseebakTypography
                                                  .fontFamily,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: AppColors.softBackground,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: AppColors.subtleBorder),
                                          ),
                                          child: const Text(
                                            'تم تفعيل هذا الاشتراك عبر بوابة الدفع الإلكترونية لمدة 30 يوماً محددة، ولا يتم خصم أي مبالغ متكررة تلقائياً.',
                                            style: TextStyle(
                                              fontFamily:
                                                  NaseebakTypography.fontFamily,
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              height: 1.6,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 22),

                          // 2. Subscription History Section
                          if (state.history.isNotEmpty) ...[
                            const Row(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 20,
                                  color: AppColors.primaryNavy,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'سجل الاشتراكات السابقة والحالية',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...state.history.map((item) {
                              return NaseebakCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.planNameAr,
                                            style: const TextStyle(
                                              fontFamily: NaseebakTypography
                                                  .fontFamily,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryNavy,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item.channelLabelAr} • حتى ${item.currentPeriodEnd != null ? _formatDate(item.currentPeriodEnd!) : '-'}',
                                            style: const TextStyle(
                                              fontFamily: NaseebakTypography
                                                  .fontFamily,
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: item.isCurrentlyEntitled
                                            ? AppColors.creamHighlight
                                            : AppColors.subtleBorder
                                                .withOpacity(0.5),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.statusLabelAr,
                                        style: TextStyle(
                                          fontFamily:
                                              NaseebakTypography.fontFamily,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: item.isCurrentlyEntitled
                                              ? AppColors.primaryNavy
                                              : AppColors.textSecondary,
                                        ),
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
          ],
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
            fontFamily: NaseebakTypography.fontFamily,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
