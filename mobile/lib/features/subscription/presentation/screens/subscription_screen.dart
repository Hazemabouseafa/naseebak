import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import 'my_subscription_screen.dart';

/// Screen 11 — Monthly Subscription Screen (`الاشتراك الشهري`)
///
/// Displays:
/// - Title: "فعّل اشتراكك وابدأ التواصل"
/// - Description: "اشترك شهريًا لإرسال طلبات التعارف والتواصل مع الأعضاء بعد قبول الطلب."
/// - Benefits:
///   1. إرسال طلبات التعارف
///   2. التواصل بعد الموافقة
///   3. إرسال الرسائل الخاصة
/// - Localized monthly price & currency loaded exclusively from Google Play Billing
///   (shows a clear unavailable state if Google Play product is unavailable; NEVER invents a fake price).
/// - Primary Button: "اشترك الآن" -> Opens authorized Google Play Billing flow only.
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

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('الاشتراك الشهري'),
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
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: state.isLoading &&
                state.uiPhase == SubscriptionUiPhase.loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      key: Key('subscription_loading_indicator'),
                      color: AppColors.primaryBlue,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'جارٍ تحميل تفاصيل باقة الاشتراك من متجر Google Play...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status / Verification Pending Banner
                    if (state.statusBannerMessage != null) ...[
                      Container(
                        key: const Key('subscription_status_banner'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtleBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (state.uiPhase ==
                                    SubscriptionUiPhase.verificationPending ||
                                state.uiPhase ==
                                    SubscriptionUiPhase.purchaseInProgress)
                              const Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                state.statusBannerMessage!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                  height: 1.6,
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
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
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.surfaceSubtleBlue,
                            AppColors.surfaceSubtleYellow,
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.accentYellow,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 32,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'فعّل اشتراكك وابدأ التواصل',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'اشترك شهريًا لإرسال طلبات التعارف والتواصل مع الأعضاء بعد قبول الطلب.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Benefits Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مزايا العضوية الشهرية',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...benefits.map(
                            (benefit) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSubtleBlue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      benefit,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 18),

                    // Pricing & Billing Period Card (Localized Google Play Price Only - Never Fake Price)
                    Container(
                      key: const Key('subscription_pricing_card'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: storePricing != null
                              ? AppColors.primaryBlue
                              : AppColors.borderLight,
                          width: storePricing != null ? 1.5 : 1.0,
                        ),
                      ),
                      child: storePricing != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      plan?.nameAr ??
                                          'العضوية الشهرية — نصيبك',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentYellow,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'شهري (30 يومًا)',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.darkBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      storePricing.formattedPrice,
                                      key: const Key('localized_store_price'),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${storePricing.currencyCode} / شهريًا)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              key: const Key('product_unavailable_state'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'يعرض تطبيق نصيبك السعر الفعلي المحلي المعتمد من متجر Google Play فقط دون عرض أي أسعار افتراضية. يرجى التأكد من تسجيل الدخول في متجر Google Play وإعادة المحاولة.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.65,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(subscriptionProvider.notifier)
                                        .loadSubscriptionCenter();
                                  },
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('إعادة التحقق من المتجر'),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),

                    // Active Subscription Indicator if already subscribed
                    if (state.entitlement.hasActiveSubscription) ...[
                      Container(
                        key: const Key('already_active_subscription_banner'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtleBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryBlue),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: AppColors.primaryBlue,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'لديك اشتراك شهري نشط وموثق بالفعل. يمكنك إرسال طلبات التعارف والرسائل الخاصة.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
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
                      child: const Text('اشترك الآن'),
                    ),
                    const SizedBox(height: 10),

                    // Restore Purchases Button
                    OutlinedButton.icon(
                      key: const Key('restore_purchases_btn'),
                      onPressed: state.isLoading
                          ? null
                          : () {
                              ref
                                  .read(subscriptionProvider.notifier)
                                  .restoreGooglePlayPurchases(
                                    currentUserId: authUser?.id,
                                  );
                            },
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('استعادة المشتريات السابقة'),
                    ),
                    const SizedBox(height: 18),

                    // Renewal & Cancellation Terms
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'شروط التجديد والإلغاء:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            plan?.renewalTermsAr ??
                                'يتجدد الاشتراك شهرياً تلقائياً عبر حسابك في متجر Google Play ما لم يتم إلغاؤه قبل 24 ساعة على الأقل من انتهاء الفترة الحالية.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.65,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            plan?.cancellationTermsAr ??
                                'يمكنك إدارة أو إلغاء الاشتراك في أي وقت من قسم الاشتراكات في حساب متجر Google Play، وتستمر مزايا الاشتراك حتى نهاية الفترة المدفوعة.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
