import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';
import 'basic_profile_step_screen.dart';
import 'family_education_work_step_screen.dart';
import 'additional_details_step_screen.dart';
import 'profile_preview_step_screen.dart';

/// Multi-Step Profile Registration Flow Coordinator (Screens 03, 04, 05, 06)
class ProfileRegistrationCoordinatorScreen extends ConsumerWidget {
  const ProfileRegistrationCoordinatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regState = ref.watch(profileRegistrationProvider);

    final stepTitle = switch (regState.currentStep) {
      1 => 'البيانات الأساسية',
      2 => 'الأسرة والتعليم والعمل',
      3 => 'التفاصيل الإضافية والنبذة',
      _ => 'مراجعة الملف قبل النشر',
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () {
            ref.read(profileRegistrationProvider.notifier).goBackStep();
          },
          tooltip: 'رجوع',
        ),
        title: const Text('إكمال ملفك الشخصي'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
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
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          regState.validationError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
    );
  }
}
