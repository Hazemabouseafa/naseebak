import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../../core/widgets/naseebak_logo_badge.dart';
import '../providers/auth_provider.dart';

/// 02. Google Sign-In Screen (شاشة تسجيل الدخول عبر Google — تصميم Astra Screen 02)
/// خلفية بيضاء وكريمية دافئة مع أيقونة نصيبك الرسمية الكحلية والذهبية،
/// وعنوان "مرحبًا بك في نصيبك"، وزر "المتابعة باستخدام Google" المرتفع مع زخارف أوراق الغار الذهبية.
class GoogleSignInScreen extends ConsumerWidget {
  const GoogleSignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: NaseebakAppBar(
        title: 'تسجيل الدخول',
        onBack: () {
          ref.read(authControllerProvider.notifier).navigateToWelcome();
        },
      ),
      body: Stack(
        children: [
          // Soft Warm Cream Top Halo
          Positioned(
            top: -50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.creamHighlight.withOpacity(0.85),
                      AppColors.cardWhite.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Decorative Warm Gold Botanical Leaves (Astra Screen 02 Signature)
          const Positioned(
            bottom: 90,
            right: -14,
            child: NaseebakGoldBotanicalDecoration(
              size: 135,
              opacity: 0.28,
            ),
          ),
          const Positioned(
            bottom: 110,
            left: -18,
            child: NaseebakGoldBotanicalDecoration(
              size: 115,
              opacity: 0.20,
              flipHorizontal: true,
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 44)
                        .clamp(0.0, double.infinity),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 1),

                        // Centered Official Naseebak App Icon Badge in Elevated Halo
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.creamHighlight,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: AppColors.goldAccent.withOpacity(0.45),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryNavy.withOpacity(0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const NaseebakLogoBadge(
                              size: 86,
                              showText: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Headline: "مرحبًا بك في نصيبك"
                        const Text(
                          AppStrings.googleWelcomeHeadline,
                          textAlign: TextAlign.center,
                          style: NaseebakTypography.pageTitle,
                        ),
                        const SizedBox(height: 8),

                        // Subtitle: "ابدأ رحلتك للبحث عن شريك حياتك."
                        const Text(
                          AppStrings.googleWelcomeSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Elevated Google Sign-In Pill Button (Astra Screen 02 Centerpiece)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNavy.withOpacity(0.10),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            key: const Key('google_signin_submit_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cardWhite,
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size.fromHeight(58),
                              elevation: 0,
                              side: const BorderSide(
                                color: AppColors.subtleBorder,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: authState.isLoading
                                ? null
                                : () {
                                    ref
                                        .read(authControllerProvider.notifier)
                                        .signInWithGoogle();
                                  },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (authState.isLoading)
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.3,
                                      color: AppColors.primaryNavy,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.softBackground,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.subtleBorder,
                                      ),
                                    ),
                                    child: const Text(
                                      'G',
                                      style: TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    authState.isLoading
                                        ? 'جارٍ التحقق من حساب Google...'
                                        : AppStrings.continueWithGoogle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: NaseebakTypography.fontFamily,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Security & Privacy Trust Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.softBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.subtleBorder),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'المتابعة بحساب Google الخاص بك',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: AppColors.primaryBlue,
                                    size: 19,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'لا يظهر بريدك الإلكتروني لأي عضو آخر داخل التطبيق.',
                                      style: TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppColors.warmGold,
                                    size: 19,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'مصادقة مشفّرة عبر OpenID Connect بدون مشاركة رقم الهاتف.',
                                      style: TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: const TextStyle(
                                      fontFamily: NaseebakTypography.fontFamily,
                                      fontSize: 12.5,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const Spacer(flex: 2),

                        // Privacy Policy & Terms of Service Notice
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.65,
                            ),
                            children: [
                              TextSpan(text: 'بالمتابعة، أنت توافق على '),
                              TextSpan(
                                text: 'شروط الخدمة',
                                style: TextStyle(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' و '),
                              TextSpan(
                                text: 'سياسة الخصوصية',
                                style: TextStyle(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' الخاصة بنا.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
