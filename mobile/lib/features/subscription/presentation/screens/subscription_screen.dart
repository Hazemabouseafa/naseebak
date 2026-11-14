import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/subscription_provider.dart';

/// Screen 01 — Membership Status Screen (`عضويتي في نَصِيبُكَ`)
///
/// Designed strictly in compliance with Google Play's Consumption-Only guidelines:
/// - NO Google Play Billing purchase flows or buttons
/// - NO Paymob / Sha7nawy checkout links or WebViews
/// - NO clickable external payment links or deep links
/// - Non-clickable informational text referencing the official website domain: naseebak.hazem.my
/// - Authoritative server-side status refresh from Laravel API
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).loadSubscriptionCenter();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(subscriptionProvider.notifier).refreshEntitlementOnly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: NaseebakCircleButton(
                icon: Icons.close_rounded,
                size: 38,
                iconSize: 20,
                onTap: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null,
                tooltip: 'إغلاق',
              ),
            ),
          ),
          title: const Text(
            'عضويتي في نَصِيبُكَ',
            style: TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF123D6A),
            ),
          ),
        ),
        body: SafeArea(
          child: _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SubscriptionState state) {
    // 1. Initial Loading State (clean full-screen spinner)
    if (state.isLoading &&
        state.uiPhase == SubscriptionUiPhase.loading &&
        state.currentSubscription == null &&
        state.errorMessage == null) {
      return const Center(
        child: Column(
          key: Key('membership_loading_indicator'),
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF184A8C),
              strokeWidth: 2.8,
            ),
            SizedBox(height: 18),
            Text(
              'جارٍ التحقق من حالة العضوية...',
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Network Error State (never mask error as inactive)
    if (state.errorMessage != null &&
        state.uiPhase == SubscriptionUiPhase.purchaseFailure) {
      return _buildErrorState(context, state);
    }

    // 3. Active Membership State
    if (state.entitlement.hasActiveSubscription) {
      return _buildActiveState(context, state);
    }

    // 4. Pending Payment State
    if (state.uiPhase == SubscriptionUiPhase.purchasePending ||
        state.entitlement.subscriptionStatus == 'pending') {
      return _buildPendingState(context, state);
    }

    // 5. Expired Membership State
    if (state.uiPhase == SubscriptionUiPhase.expiredSubscription ||
        state.entitlement.subscriptionStatus == 'expired' ||
        (state.currentSubscription != null &&
            state.currentSubscription!.status == 'expired')) {
      return _buildExpiredState(context, state);
    }

    // 6. Inactive Membership State (Free User)
    return _buildInactiveState(context, state);
  }

  // ===========================================================================
  // STATE 1: INACTIVE MEMBERSHIP (Free member)
  // ===========================================================================
  Widget _buildInactiveState(BuildContext context, SubscriptionState state) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF123D6A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE8B44D),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.card_membership_rounded,
                      size: 32,
                      color: Color(0xFF184A8C),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'عضويتك غير نشطة حاليًا',
                  key: Key('inactive_membership_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF123D6A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تقدر تكتشف الأعضاء وتستخدم المميزات المتاحة لحسابك، وللتواصل عبر المحادثات تحتاج عضوية فعّالة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Benefits Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF184A8C),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'مميزات العضوية',
                      style: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF123D6A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildBenefitRow('التواصل بعد قبول طلب التعارف.'),
                _buildBenefitRow('استخدام مميزات التواصل المتاحة.'),
                _buildBenefitRow('متابعة حالة العضوية وتاريخ انتهائها.'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // How Membership Works (Google Play Policy Compliant)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF184A8C),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'كيف تعمل العضوية؟',
                      style: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF123D6A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'الاشتراكات غير متاحة للشراء من داخل التطبيق. يمكنك الاشتراك من خلال موقع نَصِيبُكَ الرسمي باستخدام نفس حساب Google.',
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),

                // Non-clickable informational domain box
                Container(
                  key: const Key('non_interactive_domain_text'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.language_rounded,
                        size: 18,
                        color: Color(0xFF184A8C),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'naseebak.hazem.my',
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123D6A),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'بعد تفعيل العضوية على نفس حسابك، يمكنك تحديث حالة العضوية هنا.',
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Functional Refresh Button
          _buildRefreshButton(state),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATE 2: ACTIVE MEMBERSHIP
  // ===========================================================================
  Widget _buildActiveState(BuildContext context, SubscriptionState state) {
    final sub = state.currentSubscription;
    final entitlement = state.entitlement;
    final planName = sub?.planNameAr.isNotEmpty == true
        ? sub!.planNameAr
        : (state.activePlan?.nameAr ?? 'العضوية المميزة — نصيبك');
    final statusText = sub?.statusLabelAr.isNotEmpty == true
        ? sub!.statusLabelAr
        : 'نشط ومفعل';
    final expiryDate = sub?.currentPeriodEnd ?? entitlement.currentPeriodEnd;
    final startDate = sub?.startsAt;
    final remainingDays = _calculateRemainingDays(expiryDate);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active Premium Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF1E5BB0),
                  Color(0xFF123D6A),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF123D6A).withOpacity(0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE8B44D),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          size: 28,
                          color: Color(0xFFE8B44D),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8B44D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123D6A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'عضويتك فعّالة ✨',
                  key: Key('active_membership_title'),
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  planName,
                  key: const Key('membership_plan_name'),
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.90),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'تقدر دلوقتي تستفيد من مميزات التواصل المتاحة لعضويتك.',
                    style: TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real Membership Details Grid
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تفاصيل العضوية',
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF123D6A),
                  ),
                ),
                const SizedBox(height: 14),
                _buildDetailRow(
                  label: 'الباقة',
                  value: planName,
                  icon: Icons.card_membership_outlined,
                ),
                if (startDate != null) ...[
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildDetailRow(
                    label: 'تاريخ البدء',
                    value: _formatDate(startDate),
                    icon: Icons.calendar_today_outlined,
                  ),
                ],
                if (expiryDate != null) ...[
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildDetailRow(
                    label: 'تاريخ الانتهاء',
                    value: _formatDate(expiryDate),
                    icon: Icons.event_available_outlined,
                    valueKey: const Key('membership_expiry_date'),
                  ),
                ],
                if (remainingDays.isNotEmpty) ...[
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildDetailRow(
                    label: 'الوقت المتبقي',
                    value: remainingDays,
                    icon: Icons.hourglass_top_outlined,
                    highlightValue: true,
                  ),
                ],
                if (entitlement.autoRenewing) ...[
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildDetailRow(
                    label: 'حالة التجديد',
                    value: 'يتجدد تلقائياً',
                    icon: Icons.autorenew_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Entitlements Overview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المميزات المفعلة في حسابك',
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF123D6A),
                  ),
                ),
                const SizedBox(height: 12),
                _buildBenefitRow('إرسال واستقبال طلبات التعارف.'),
                _buildBenefitRow('المحادثة الخاصة الفورية بعد قبول الطرف الآخر.'),
                _buildBenefitRow('البحث المتقدم بكافة المعايير المتاحة.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Functional Refresh Button
          _buildRefreshButton(state),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATE 3: EXPIRED MEMBERSHIP
  // ===========================================================================
  Widget _buildExpiredState(BuildContext context, SubscriptionState state) {
    final expiryDate = state.currentSubscription?.currentPeriodEnd ??
        state.entitlement.currentPeriodEnd;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.history_toggle_off_rounded,
                      size: 30,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'انتهت صلاحية عضويتك',
                  key: Key('expired_membership_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (expiryDate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'انتهت في: ${_formatDate(expiryDate)}',
                    style: const TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'يمكنك متابعة استخدام المميزات المتاحة بدون عضوية. لتفعيل فترة جديدة، تتوفر الاشتراكات عبر الموقع الرسمي لنَصِيبُكَ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),

                // Non-clickable informational domain box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.language_rounded,
                        size: 18,
                        color: Color(0xFF184A8C),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'naseebak.hazem.my',
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123D6A),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Functional Refresh Button
          _buildRefreshButton(state),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATE 4: PENDING PAYMENT STATE
  // ===========================================================================
  Widget _buildPendingState(BuildContext context, SubscriptionState state) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE8B44D)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hourglass_empty_rounded,
                      size: 30,
                      color: Color(0xFF184A8C),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'عملية الدفع قيد التأكيد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF123D6A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'عملية الاشتراك قيد التأكيد والمزامنة عبر الخادم. سيتم تفعيل العضوية تلقائياً فور اكتمال التأكيد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildRefreshButton(state),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATE 5: NETWORK ERROR STATE
  // ===========================================================================
  Widget _buildErrorState(BuildContext context, SubscriptionState state) {
    return Center(
      key: const Key('membership_error_state'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: const Center(
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'تعذر الاتصال بالخادم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage?.isNotEmpty == true
                  ? state.errorMessage!
                  : 'تعذر التحقق من حالة العضوية حالياً. يرجى التأكد من اتصال الإنترنت وإعادة المحاولة.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              key: const Key('retry_membership_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF184A8C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                ref
                    .read(subscriptionProvider.notifier)
                    .loadSubscriptionCenter();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // REUSABLE HELPER WIDGETS
  // ===========================================================================
  Widget _buildRefreshButton(SubscriptionState state) {
    return ElevatedButton.icon(
      key: const Key('refresh_membership_status_btn'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF184A8C),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: state.isLoading
          ? null
          : () {
              ref
                  .read(subscriptionProvider.notifier)
                  .loadSubscriptionCenter();
            },
      icon: state.isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 20),
      label: const Text(
        'تحديث حالة العضوية',
        style: TextStyle(
          fontFamily: NaseebakTypography.fontFamily,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE8B44D),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 14,
              color: Color(0xFF123D6A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    Key? valueKey,
    bool highlightValue = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: NaseebakTypography.fontFamily,
            fontSize: 13.5,
            color: Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontFamily: NaseebakTypography.fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: highlightValue
                ? const Color(0xFF184A8C)
                : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _calculateRemainingDays(DateTime? endDate) {
    if (endDate == null) return '';
    final now = DateTime.now();
    final diff = endDate.difference(now);
    if (diff.isNegative) return 'منتهي';
    final days = diff.inDays;
    if (days == 0) return 'ينتهي اليوم';
    if (days == 1) return 'متبقي يوم واحد';
    if (days == 2) return 'متبقي يومان';
    if (days <= 10) return 'متبقي $days أيام';
    return 'متبقي $days يومًا';
  }
}
