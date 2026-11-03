import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';

/// 04. Family, Education and Work Screen (الخطوة 2 من 4: الأسرة والعمل)
/// مطابقة لتخطيط الـ Mockup Screen 04:
/// هل سبق لك الزواج؟، هل لديك أطفال؟، المؤهل الدراسي، العمل، وهل لديك منزل؟
class FamilyEducationWorkStepScreen extends ConsumerStatefulWidget {
  const FamilyEducationWorkStepScreen({super.key});

  @override
  ConsumerState<FamilyEducationWorkStepScreen> createState() =>
      _FamilyEducationWorkStepScreenState();
}

class _FamilyEducationWorkStepScreenState
    extends ConsumerState<FamilyEducationWorkStepScreen> {
  late final TextEditingController _occupationController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileRegistrationProvider).draft;
    _occupationController = TextEditingController(text: draft.occupation);
  }

  @override
  void dispose() {
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(profileRegistrationProvider).draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Previous Marriage
                const Text(
                  'هل سبق لك الزواج؟',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                NaseebakSegmentedControl<bool>(
                  options: const {
                    true: 'نعم',
                    false: 'لا',
                  },
                  selectedValue: draft.previouslyMarried,
                  onChanged: (val) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(previouslyMarried: val),
                        );
                  },
                ),
                const SizedBox(height: 16),

                // Children
                const Text(
                  'هل لديك أطفال؟',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                NaseebakSegmentedControl<bool>(
                  options: const {
                    true: 'نعم',
                    false: 'لا',
                  },
                  selectedValue: draft.hasChildren,
                  onChanged: (val) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(
                            hasChildren: val,
                            childrenCount: val ? 1 : 0,
                          ),
                        );
                  },
                ),
                const SizedBox(height: 16),

                // Education Level
                const Text(
                  'المؤهل الدراسي',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  value: draft.educationLevel,
                  items: const [
                    DropdownMenuItem(
                      value: 'bachelor',
                      child: Text('بكالوريوس / ليسانس'),
                    ),
                    DropdownMenuItem(
                      value: 'master',
                      child: Text('ماجستير'),
                    ),
                    DropdownMenuItem(
                      value: 'doctorate',
                      child: Text('دكتوراه'),
                    ),
                    DropdownMenuItem(
                      value: 'diploma',
                      child: Text('دبلوم متوسط / فوق متوسط'),
                    ),
                    DropdownMenuItem(
                      value: 'high_school',
                      child: Text('ثانوية عامة أو ما يعادلها'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('مؤهل آخر'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(profileRegistrationProvider.notifier)
                          .updateDraft(draft.copyWith(educationLevel: value));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Occupation
                const Text(
                  'العمل / المهنة',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  key: const Key('profile_occupation_input'),
                  controller: _occupationController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: مهندسة معمارية / محاسب / طبيب',
                  ),
                  onChanged: (value) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(occupation: value),
                        );
                  },
                ),
                const SizedBox(height: 16),

                // Home Ownership
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'حالة السكن / المنزل',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'مطلوب للتوافق الأسري',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                NaseebakSegmentedControl<String>(
                  options: const {
                    'owned': 'تمليك',
                    'rented': 'إيجار',
                    'family_home': 'مع الأسرة',
                  },
                  selectedValue: draft.homeOwnership,
                  onChanged: (val) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(homeOwnership: val),
                        );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('step2_next_btn'),
          onPressed: () {
            ref
                .read(profileRegistrationProvider.notifier)
                .validateAndAdvanceFromStep2();
          },
          child: const Text('التالي'),
        ),
      ],
    );
  }
}
