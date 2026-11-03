import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import 'my_subscription_screen.dart';

/// Screen 01 (Batch 2A) — Monthly Subscription Screen (`الاشتراك الشهري`)
/// تصميم Astra الفاخر للاشتراك الشهري المعتمد عبر Google Play Billing حصرياً على أندرويد.
/// هيدر كحلي ملكي، بطاقات بيضاء ناعمة، أسعار المتجر الرسمية الموثقة، ومزايا العضوية المعتمدة.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).loadSubscriptionCenter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);
    final authUser = ref.watch(authControllerProvider).user;
    final plan = state.activePlan;
    final storePricing = state.storePricing;

    final benefits = plan?.featuresAr.isNotEmpty == true
        ? plan!.featuresAr
        : const [
            'إرسال طلبات التعارف',
            'التواصل بعد الموافقة',
            'إرسال الرسائل الخاصة',
          ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBackground,
        body: Column(
          children: [
            // Premium Royal Navy Curved Header
            NaseebakCurvedHeader(
              title: 'الاشتراك الشهري',
              subtitle: 'ابدأ خطوة جديدة نحو شريك حياتك',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).pop()
                  : null,
              actions: [
                TextButton(
                  key: const Key('open_my_subscription_screen_btn'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MySubscriptionScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'اشتراكي',
                    style: TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      color: AppColors.goldAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),

            Expanded(
              child: state.isLoading &&
                      state.uiPhase == SubscriptionUiPhase.loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            key: Key('subscription_loading_indicator'),
                            color: AppColors.primaryNavy,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'جارٍ تحميل تفاصيل باقة الاشتراك من متجر Google Play...',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Status / Verification Pending Banner
                          if (state.statusBannerMessage != null) ...[
                            Container(
                              key: const Key('subscription_status_banner'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.creamHighlight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.goldAccent.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (state.uiPhase ==
                                          SubscriptionUiPhase
                                              .verificationPending ||
                                      state.uiPhase ==
                                          SubscriptionUiPhase
                                              .purchaseInProgress)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 10),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: AppColors.primaryNavy,
                                        ),
                                      ),
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.only(left: 10),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        color: AppColors.primaryNavy,
                                        size: 20,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      state.statusBannerMessage!,
                                      style: const TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryNavy,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Error Banner
                          if (state.errorMessage != null) ...[
                            Container(
                              key: const Key('subscription_error_banner'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.error.withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      state.errorMessage!,
                                      style: const TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.error,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Branded Value Proposition Card (Astra Golden Crown Halo)
                          NaseebakCard(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: AppColors.creamHighlight,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.goldAccent,
                                      width: 1.6,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.goldAccent
                                            .withOpacity(0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 36,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'فعّل اشتراكك وابدأ التواصل',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'اشترك شهريًا لإرسال طلبات التعارف والتواصل مع الأعضاء بعد قبول الطلب.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 13.5,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Benefits List Card
                          NaseebakCard(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      color: AppColors.primaryBlue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'مزايا العضوية الشهرية',
                                      style: TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                ...benefits.map(
                                  (benefit) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppColors.creamHighlight,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.goldAccent,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            size: 15,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            benefit,
                                            style: const TextStyle(
                                              fontFamily:
                                                  NaseebakTypography.fontFamily,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Pricing Card (Google Play Live Pricing Only)
                          Container(
                            key: const Key('subscription_pricing_card'),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: storePricing != null
                                    ? AppColors.primaryNavy
                                    : AppColors.subtleBorder,
                                width: storePricing != null ? 1.8 : 1.2,
                              ),
                              boxShadow: NaseebakSpacing.subtleCardShadow,
                            ),
                            child: storePricing != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            plan?.nameAr ??
                                                'العضوية الشهرية — نصيبك',
                                            style: const TextStyle(
                                              fontFamily: NaseebakTypography
                                                  .fontFamily,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryNavy,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.creamHighlight,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.goldAccent,
                                              ),
                                            ),
                                            child: const Text(
                                              'شهري (30 يومًا)',
                                              style: TextStyle(
                                                fontFamily: NaseebakTypography
                                                    .fontFamily,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryNavy,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            storePricing.formattedPrice,
                                            key: const Key(
                                                'localized_store_price'),
                                            style: const TextStyle(
                                              fontFamily: NaseebakTypography
                                                  .fontFamily,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryNavy,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '(${storePricing.currencyCode} / شهريًا)',
                                            style: const TextStyle(
                                              fontFamily: NaseebakTypography
                                                  .fontFamily,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Column(
                                    key: const Key('product_unavailable_state'),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.storefront_outlined,
                                            color: AppColors.warning,
                                            size: 22,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'باقة الاشتراك غير متاحة حالياً من متجر Google Play',
                                              style: TextStyle(
                                                fontFamily: NaseebakTypography
                                                    .fontFamily,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'يعرض تطبيق نَصِيبُكَ السعر الفعلي المحلي المعتمد من متجر Google Play فقط دون عرض أي أسعار افتراضية. يرجى التأكد من تسجيل الدخول في متجر Google Play وإعادة المحاولة.',
                                        style: TextStyle(
                                          fontFamily:
                                              NaseebakTypography.fontFamily,
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.65,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: AppColors.primaryNavy),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(
                                                  subscriptionProvider.notifier)
                                              .loadSubscriptionCenter();
                                        },
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                          color: AppColors.primaryNavy,
                                        ),
                                        label: const Text(
                                          'إعادة التحقق من المتجر',
                                          style: TextStyle(
                                            fontFamily:
                                                NaseebakTypography.fontFamily,
                                            color: AppColors.primaryNavy,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // Active Subscription Notice
                          if (state.entitlement.hasActiveSubscription) ...[
                            Container(
                              key: const Key(
                                  'already_active_subscription_banner'),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.creamHighlight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.goldAccent,
                                  width: 1.2,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: AppColors.primaryNavy,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'لديك اشتراك شهري نشط وموثق بالفعل. يمكنك إرسال طلبات التعارف والرسائل الخاصة.',
                                      style: TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Primary Action Button: "اشترك الآن"
                          ElevatedButton(
                            key: const Key('subscribe_now_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: (state.isLoading ||
                                    storePricing == null ||
                                    state.entitlement.hasActiveSubscription)
                                ? null
                                : () {
                                    ref
                                        .read(subscriptionProvider.notifier)
                                        .initiateGooglePlaySubscription(
                                          currentUserId: authUser?.id,
                                        );
                                  },
                            child: const Text(
                              'اشترك الآن',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Restore Purchases Button
                          OutlinedButton.icon(
                            key: const Key('restore_purchases_btn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryNavy,
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(
                                color: AppColors.subtleBorder,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: state.isLoading
                                ? null
                                : () {
                                    ref
                                        .read(subscriptionProvider.notifier)
                                        .restoreGooglePlayPurchases(
                                          currentUserId: authUser?.id,
                                        );
                                  },
                            icon: const Icon(
                              Icons.restore_rounded,
                              size: 18,
                              color: AppColors.primaryNavy,
                            ),
                            label: const Text(
                              'استعادة المشتريات السابقة',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Renewal & Cancellation Terms Card
                          NaseebakCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.gavel_rounded,
                                      size: 18,
                                      color: AppColors.warmGold,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'شروط التجديد والإلغاء:',
                                      style: TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  plan?.renewalTermsAr ??
                                      'يتجدد الاشتراك شهرياً تلقائياً عبر حسابك في متجر Google Play ما لم يتم إلغاؤه قبل 24 ساعة على الأقل من انتهاء الفترة الحالية.',
                                  style: const TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  plan?.cancellationTermsAr ??
                                      'يمكنك إدارة أو إلغاء الاشتراك في أي وقت من قسم الاشتراكات في حساب متجر Google Play، وتستمر مزايا الاشتراك حتى نهاية الفترة المدفوعة.',
                                  style: const TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
