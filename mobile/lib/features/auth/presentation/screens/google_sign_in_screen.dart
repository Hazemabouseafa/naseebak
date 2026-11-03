import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/naseebak_logo_badge.dart';
import '../providers/auth_provider.dart';

/// 02. Google Sign-In Screen (شاشة الدخول باستخدام Google حصراً)
/// تستبدل شاشة رقم الهاتف/OTP في الـ Mockup القديم بنظام Google OAuth / OpenID Connect الحصري.
class GoogleSignInScreen extends ConsumerWidget {
  const GoogleSignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () {
            ref.read(authControllerProvider.notifier).navigateToWelcome();
          },
          tooltip: 'رجوع',
        ),
        title: const Text('تسجيل الدخول الآمن'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 44).clamp(0.0, double.infinity),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtleBlue,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.accentYellow,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: NaseebakLogoBadge(
                      size: 56,
                      showText: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'المتابعة بحساب Google الخاص بك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'يعتمد تطبيق نصيبك على المصادقة الموثوقة عبر Google فقط لضمان جدية الحسابات وحماية خصوصيتك دون الحاجة لمشاركة رقم هاتفك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 24),

              // Privacy & Security Trust Box (Inspired by Mockup Screen 02 trust-note)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'لا يظهر بريدك الإلكتروني لأي عضو آخر داخل التطبيق.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.darkBlue,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'يتم التحقق من هوية الحساب على خادم نصيبك عبر بروتوكول OpenID Connect المشفّر.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.6,
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
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              ElevatedButton.icon(
                key: const Key('google_signin_submit_btn'),
                onPressed: authState.isLoading
                    ? null
                    : () {
                        ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle();
                      },
                icon: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'G',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                label: Text(
                  authState.isLoading
                      ? 'جارٍ التحقق من حساب Google...'
                      : AppStrings.continueWithGoogle,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                key: const Key('preview_profile_flow_btn'),
                onPressed: authState.isLoading
                    ? null
                    : () {
                        ref
                            .read(authControllerProvider.notifier)
                            .enterProfileRegistrationPreview();
                      },
                child: const Text(
                  'معاينة خطوات استكمال الملف الشخصي (وضع الفحص المحلي)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.termsAcceptanceNotice,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  height: 1.7,
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
