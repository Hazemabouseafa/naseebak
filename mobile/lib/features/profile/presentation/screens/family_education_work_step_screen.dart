import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';

/// 04. Family, Education and Work Screen (الخطوة 2 من 4: العائلة والتعليم والعمل — تصميم Astra Screens 04-05)
/// تشمل: أيقونة الخطوة الذهبية، هل سبق لك الزواج؟، هل لديك أطفال؟، المؤهل الدراسي، المهنة، والسكن.
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
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const NaseebakStepBadge(
                  icon: Icons.home_outlined,
                  title: 'العائلة والتعليم والعمل',
                  subtitle: 'شاركنا المزيد عن وضعك العائلي والمهني',
                ),
                const SizedBox(height: 20),

                // Previous Marriage
                const Text(
                  'هل سبق لك الزواج؟',
                  style: NaseebakTypography.formLabel,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 18),

                // Children
                const Text(
                  'هل لديك أطفال؟',
                  style: NaseebakTypography.formLabel,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 18),

                // Education Level
                const Text(
                  'المؤهل الدراسي',
                  style: NaseebakTypography.formLabel,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 18),

                // Occupation
                NaseebakTextField(
                  fieldKey: const Key('profile_occupation_input'),
                  label: 'المهنة / العمل',
                  hintText: 'أدخل مهنتك (مثال: مهندس، طبيب، محاسب...)',
                  controller: _occupationController,
                  onChanged: (value) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(occupation: value),
                        );
                  },
                ),
                const SizedBox(height: 18),

                // Home Ownership
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'السكن / المنزل',
                      style: NaseebakTypography.formLabel,
                    ),
                    Text(
                      'للتوافق الأسري',
                      style: NaseebakTypography.supportingText,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                NaseebakSegmentedControl<String>(
                  options: const {
                    'owned': 'تمليك',
                    'rented': 'إيجار',
                    'family_home': 'مع العائلة',
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
        NaseebakPrimaryButton(
          buttonKey: const Key('step2_next_btn'),
          label: 'التالي',
          onPressed: () {
            ref
                .read(profileRegistrationProvider.notifier)
                .validateAndAdvanceFromStep2();
          },
        ),
      ],
    );
  }
}
