import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';
import 'basic_profile_step_screen.dart';
import 'family_education_work_step_screen.dart';
import 'additional_details_step_screen.dart';
import 'profile_preview_step_screen.dart';

/// Multi-Step Profile Registration Flow Coordinator (Astra Screens 03, 04, 05, 06)
class ProfileRegistrationCoordinatorScreen extends ConsumerWidget {
  const ProfileRegistrationCoordinatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regState = ref.watch(profileRegistrationProvider);

    final stepTitle = switch (regState.currentStep) {
      1 => 'معلوماتك الشخصية',
      2 => 'العائلة والتعليم والعمل',
      3 => 'التفاصيل الإضافية والنبذة',
      _ => 'مراجعة الملف قبل النشر',
    };

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: NaseebakAppBar(
        title: 'إعداد الملف الشخصي',
        onBack: () {
          ref.read(profileRegistrationProvider.notifier).goBackStep();
        },
      ),
      body: Stack(
        children: [
          // Subtle Warm Gold Botanical Leaf Decoration at Bottom Right (Astra Signature)
          const Positioned(
            bottom: 64,
            right: -16,
            child: NaseebakGoldBotanicalDecoration(
              size: 120,
              opacity: 0.22,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StepProgressHeader(
                    currentStep: regState.currentStep,
                    totalSteps: 4,
                    stepTitle: stepTitle,
                  ),
                  if (regState.validationError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
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
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              regState.validationError!,
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Expanded(
                    child: switch (regState.currentStep) {
                      1 => const BasicProfileStepScreen(),
                      2 => const FamilyEducationWorkStepScreen(),
                      3 => const AdditionalDetailsStepScreen(),
                      _ => const ProfilePreviewStepScreen(),
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
