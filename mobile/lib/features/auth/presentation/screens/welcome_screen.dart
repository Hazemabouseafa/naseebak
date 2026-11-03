import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../../core/widgets/naseebak_logo_badge.dart';
import '../providers/auth_provider.dart';

/// 01. Splash / Welcome Screen (شاشة الترحيب الفاخرة — تصميم Astra Screen 01)
/// خلفية كحلية ملكية متدرجة (#123D6A -> #0A294E) مع الشعار الرسمي المعتمد لتطبيق نصيبك
/// (العريس والعروس داخل القلب الذهبي)، وموجة الشريط الذهبي المنساب وأوراق الغار الذهبية.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryNavy,
              AppColors.deepNavy,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Soft Golden Radial Halo behind the Couple Emblem
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.goldAccent.withOpacity(0.22),
                        AppColors.primaryBlue.withOpacity(0.10),
                        AppColors.primaryNavy.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Golden Sweeping Ribbon Wave (Astra Screen 01 Signature)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: NaseebakGoldenRibbonWavePainter(),
                ),
              ),
            ),

            // Decorative Botanical Leaves at Bottom Right & Left
            const Positioned(
              bottom: 36,
              right: -12,
              child: NaseebakGoldBotanicalDecoration(
                size: 130,
                opacity: 0.32,
              ),
            ),
            const Positioned(
              bottom: 50,
              left: -16,
              child: NaseebakGoldBotanicalDecoration(
                size: 115,
                opacity: 0.24,
                flipHorizontal: true,
              ),
            ),

            // Foreground Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 40)
                          .clamp(0.0, double.infinity),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 2),

                          // Animated Official Naseebak Couple & Golden Heart Emblem
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.92, end: 1.0),
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.easeOutCubic,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: NaseebakLogoBadge(
                                  size: 164,
                                  showText: false,
                                  lightText: true,
                                  useFullEmblem: true,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Brand Title: "نصيبك"
                          const Text(
                            AppStrings.appNameAr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Golden Tagline: "رحلتك للبحث عن شريك حياتك"
                          const Text(
                            AppStrings.taglineBadge,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.goldAccent,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            AppStrings.welcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.84),
                              height: 1.65,
                            ),
                          ),

                          const Spacer(flex: 3),

                          // Single Primary Transition Button -> Navigates to Login Screen
                          ElevatedButton(
                            key: const Key('welcome_continue_google_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cardWhite,
                              foregroundColor: AppColors.primaryNavy,
                              minimumSize: const Size.fromHeight(54),
                              elevation: 4,
                              shadowColor: Colors.black.withOpacity(0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: authState.isLoading
                                ? null
                                : () {
                                    ref
                                        .read(authControllerProvider.notifier)
                                        .navigateToGoogleSignIn();
                                  },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppStrings.startNow,
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primaryNavy,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Adults Only +18 Notice
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.goldAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '+18',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppStrings.adultsOnlyNotice,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.86),
                                    fontWeight: FontWeight.w500,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
