import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';

/// 03. Basic Profile Information Screen (الخطوة 1 من 4: البيانات الأساسية)
/// تشمل: الصورة الشخصية، الاسم الكامل، النوع، تاريخ الميلاد (مع حساب العمر والبرج تلقائياً ومنع < 18)، والحالة الاجتماعية.
class BasicProfileStepScreen extends ConsumerStatefulWidget {
  const BasicProfileStepScreen({super.key});

  @override
  ConsumerState<BasicProfileStepScreen> createState() =>
      _BasicProfileStepScreenState();
}

class _BasicProfileStepScreenState
    extends ConsumerState<BasicProfileStepScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileRegistrationProvider).draft;
    _nameController = TextEditingController(text: draft.fullName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final draft = ref.read(profileRegistrationProvider).draft;
    final now = DateTime.now();
    final maxAdultDate = DateTime(now.year - 18, now.month, now.day);
    final initialDate = draft.dateOfBirth ?? DateTime(1992, 6, 15);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(maxAdultDate) ? maxAdultDate : initialDate,
      firstDate: DateTime(1940, 1, 1),
      lastDate: now,
      helpText: 'اختر تاريخ الميلاد (18 عاماً فأكثر)',
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
    );

    if (picked != null) {
      ref.read(profileRegistrationProvider.notifier).updateDraft(
            draft.copyWith(dateOfBirth: picked),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(profileRegistrationProvider);
    final draft = regState.draft;
    final dob = draft.dateOfBirth;
    final ageYears = draft.calculatedAgeYears;

    final initialLetter = draft.fullName.trim().isNotEmpty
        ? draft.fullName.trim().substring(0, 1)
        : 'ن';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Photo Upload Row (Matching Mockup Screen 03)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 31,
                            backgroundColor: AppColors.surfaceSubtleBlue,
                            child: Text(
                              initialLetter,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الصورة الشخصية',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'تُحفظ بأمان ويمكنك التحكم في خصوصية ظهورها (حد أقصى 2 ميجابايت)',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name
                const Text(
                  'الاسم الكامل',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  key: const Key('profile_full_name_input'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: سارة محمد / أحمد محمود',
                  ),
                  onChanged: (value) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(fullName: value),
                        );
                  },
                ),
                const SizedBox(height: 16),

                // Gender
                const Text(
                  'النوع',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                NaseebakSegmentedControl<String>(
                  options: const {
                    'female': 'أنثى',
                    'male': 'ذكر',
                  },
                  selectedValue: draft.gender,
                  onChanged: (gender) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(gender: gender),
                        );
                  },
                ),
                const SizedBox(height: 16),

                // Date of Birth + Auto Age & Zodiac Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تاريخ الميلاد',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (ageYears != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ageYears >= 18
                              ? AppColors.surfaceSubtleBlue
                              : AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'العمر: $ageYears سنة • البرج: ${draft.calculatedZodiacSignAr}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ageYears >= 18
                                ? AppColors.primaryBlue
                                : AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                InkWell(
                  key: const Key('profile_dob_picker'),
                  onTap: () => _selectDateOfBirth(context),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dob != null
                              ? '${dob.day.toString().padLeft(2, '0')} / ${dob.month.toString().padLeft(2, '0')} / ${dob.year}'
                              : 'اختر تاريخ الميلاد',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Marital Status
                const Text(
                  'الحالة الاجتماعية',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                NaseebakSegmentedControl<String>(
                  options: draft.gender == 'male'
                      ? const {
                          'single': 'أعزب',
                          'divorced': 'مطلق',
                          'widowed': 'أرمل',
                        }
                      : const {
                          'single': 'عزباء',
                          'divorced': 'مطلقة',
                          'widowed': 'أرملة',
                        },
                  selectedValue: draft.maritalStatus,
                  onChanged: (status) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(maritalStatus: status),
                        );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('step1_next_btn'),
          onPressed: () {
            ref
                .read(profileRegistrationProvider.notifier)
                .validateAndAdvanceFromStep1();
          },
          child: const Text('التالي'),
        ),
      ],
    );
  }
}
