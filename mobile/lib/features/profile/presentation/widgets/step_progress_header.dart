import 'package:flutter/material.dart';
import '../../../../core/design_system/naseebak_design_system.dart';

/// مؤشر تقدم خطوات إعداد الملف الشخصي المقسم إلى 4 شرائح (Astra Screens 03-06)
class StepProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String stepTitle;

  const StepProgressHeader({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
    required this.stepTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الخطوة $currentStep من $totalSteps',
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
            Flexible(
              child: Text(
                stepTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Modern Segmented Horizontal Progress Bar (UX Pilot Style)
        Row(
          children: List.generate(totalSteps, (index) {
            final stepNumber = index + 1;
            final isCompletedOrActive = stepNumber <= currentStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: stepNumber < totalSteps ? 6 : 0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 5,
                  decoration: BoxDecoration(
                    color: isCompletedOrActive
                        ? AppColors.primaryBlue
                        : AppColors.subtleBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// عنصر اختيار Pill متوافق مع تصميم Astra (خلفية كحلية #123D6A وعلامة صح ذهبية عند التحديد)
class NaseebakSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final Map<T, IconData>? optionIcons;

  const NaseebakSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.optionIcons,
  });

  @override
  Widget build(BuildContext context) {
    return NaseebakSelectionField<T>(
      options: options,
      selectedValue: selectedValue,
      onChanged: onChanged,
      optionIcons: optionIcons,
    );
  }
}
