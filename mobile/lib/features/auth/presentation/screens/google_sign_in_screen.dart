import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/auth_provider.dart';

/// Screen 01 / Sign-In — Google Sign-In Screen (تصميم UX Pilot الفاخر)
/// خلفية بيضاء نقية مع الهوية الرسمية "نَصِيبُكَ"، كولاج البورتريه، وزر Google الموحد.
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
                    const SizedBox(height: 8),

                    // Branding
                    const Center(
                      child: Text(
                        AppStrings.appNameAr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Collage
                    const Center(
                      child: NaseebakWelcomeCollage(),
                    ),

                    const SizedBox(height: 16),

                    // Headline
                    const Text(
                      AppStrings.googleWelcomeHeadline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      'المتابعة بحساب Google الخاص بك',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 20),

                    // Google Sign-In Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        key: const Key('google_signin_submit_btn'),
                        onPressed: authState.isLoading
                            ? null
                            : () async {
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogle();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardWhite,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size.fromHeight(56),
                          elevation: 0,
                          side: const BorderSide(
                            color: AppColors.subtleBorder,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.primaryBlue,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'sans-serif',
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    AppStrings.continueWithGoogle,
                                    style: TextStyle(
                                      fontFamily: NaseebakTypography.fontFamily,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Terms Note
                    const Center(
                      child: Text(
                        AppStrings.adultsOnlyNotice,
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
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
}
