import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/auth_provider.dart';

/// Screen 01 — Welcome & Google Sign-In (تصميم Screen 01 من UX Pilot)
/// خلفية بيضاء نقية مع الهوية الرسمية "نَصِيبُكَ"، كولاج البورتريه الراقي،
/// عنوان "كل حكاية جميلة ليها بداية"، والوصف الترحيبي، وزر Google الموحد، وروابط الشروط والخصوصية.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 32).clamp(0.0, double.infinity),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // Official Arabic Branding: نَصِيبُكَ
                    const Center(
                      child: Text(
                        AppStrings.appNameAr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Elegant Portrait Composition Collage
                    const Center(
                      child: NaseebakWelcomeCollage(),
                    ),

                    const SizedBox(height: 20),

                    // Welcome Heading: كل حكاية جميلة ليها بداية
                    const Text(
                      'كل حكاية جميلة ليها بداية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Supporting Description
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'اكتشف أشخاص يشاركونك أهدافك، وابدأ رحلة التعارف الجاد بثقة وخصوصية.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Modern Trust Feature Pills
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTrustPill(
                          icon: Icons.verified_user_rounded,
                          label: 'خصوصية وأمان',
                        ),
                        _buildTrustPill(
                          icon: Icons.favorite_rounded,
                          label: 'زواج شرعي جاد',
                        ),
                        _buildTrustPill(
                          icon: Icons.check_circle_rounded,
                          label: 'حسابات موثقة',
                        ),
                      ],
                    ),

                    const Spacer(),
                    const SizedBox(height: 24),

                    // Google Sign-In Action Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        key: const Key('welcome_continue_google_btn'),
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                ref
                                    .read(authControllerProvider.notifier)
                                    .navigateToGoogleSignIn();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.startNow,
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Terms of Service and Privacy Policy Links
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'بالمتابعة، أنت توافق على',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => _showTermsDialog(context),
                                child: const Text(
                                  AppStrings.termsOfService,
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'و',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _showPrivacyDialog(context),
                                child: const Text(
                                  AppStrings.privacyPolicy,
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            AppStrings.adultsOnlyNotice,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtleBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.termsOfService),
        content: const SingleChildScrollView(
          child: Text(
            'شروط استخدام تطبيق نَصِيبُكَ:\n\n'
            '1. المنصة مخصصة حصرياً للراغبين في الزواج الشرعي الجاد (18 عاماً فأكثر).\n'
            '2. يُمنع منعاً باتاً نشر محتوى مسيء أو مخالف للأخلاق والآداب العامة.\n'
            '3. تخضع كافة الصور والملفات الشخصية للتدقيق والرقابة الصارمة.\n'
            '4. يتم إنهاء وحظر أي حساب ينتهك سياسات الاحترام المتبادل.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.privacyPolicy),
        content: const SingleChildScrollView(
          child: Text(
            'سياسة الخصوصية وحماية البيانات في نَصِيبُكَ:\n\n'
            '• نحن نحرص تماماً على خصوصية بياناتك الشخصية.\n'
            '• لا تتم مشاركة أرقام الهواتف أو معلومات الاتصال الخاصة إلا بموافقة صريحة متبادلة.\n'
            '• تخضع الصور لنظام خصوصية صارم يمنع وصول غير المصرح لهم.\n'
            '• كافة الاتصالات مشفرة وفق أعلى معايير الأمان (HTTPS / TLS 1.3).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
