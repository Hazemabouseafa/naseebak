import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/naseebak_logo_badge.dart';
import '../providers/auth_provider.dart';

/// 01. Welcome Screen (شاشة الترحيب)
/// مطابقة لتخطيط الـ Mockup المعتمد مع تطبيق الهوية الجديدة لتطبيق "نصيبك":
/// الأزرق الملكي (#145A9E) والأزرق الداكن (#123D6A) والأصفر المميز (#FFC43D) والخلفية البيضاء (#FFFFFF).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Banner (replaces the old green gradient with Naseebak Dark Blue -> Primary Blue)
            Expanded(
              flex: 7,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.darkBlue,
                      AppColors.primaryBlue,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle geometric circles matching the approved mockup layout
                    Positioned(
                      top: 110,
                      left: -120,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 135,
                      left: -95,
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentYellow.withOpacity(0.28),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),

                    // Main Hero Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 64, 26, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const NaseebakLogoBadge(
                            size: 52,
                            showText: true,
                            lightText: true,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentYellow.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.accentYellow.withOpacity(0.6),
                              ),
                            ),
                            child: const Text(
                              AppStrings.taglineBadge,
                              style: TextStyle(
                                color: AppColors.accentYellow,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            AppStrings.welcomeHeadline,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppStrings.welcomeSubtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.90),
                              fontSize: 13,
                              height: 1.85,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Area (Google Sign-In ONLY as required by Section 5)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      key: const Key('welcome_continue_google_btn'),
                      onPressed: authState.isLoading
                          ? null
                          : () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .navigateToGoogleSignIn();
                            },
                      icon: Container(
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
                      label: const Text(AppStrings.continueWithGoogle),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('welcome_existing_account_btn'),
                      onPressed: authState.isLoading
                          ? null
                          : () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .navigateToGoogleSignIn();
                            },
                      child: const Text('لدي حساب بالفعل — الدخول عبر Google'),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtleYellow,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accentYellow),
                          ),
                          child: const Text(
                            '+18',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          AppStrings.adultsOnlyNotice,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
