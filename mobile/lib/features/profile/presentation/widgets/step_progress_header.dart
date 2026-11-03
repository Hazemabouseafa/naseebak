import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

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
    final progress = (currentStep / totalSteps).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الخطوة $currentStep من $totalSteps',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
            Text(
              stepTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceSubtleBlue,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }
}

class NaseebakSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  const NaseebakSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.entries.map((entry) {
        final isSelected = entry.key == selectedValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.surfaceSubtleBlue
                      : AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.borderLight,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
