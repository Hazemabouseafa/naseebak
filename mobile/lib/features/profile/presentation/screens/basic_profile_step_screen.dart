import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';

/// 03. Basic Profile Information Screen (الخطوة 1 من 4: معلوماتك الشخصية — تصميم Astra Screen 03)
/// تشمل: أيقونة الخطوة الذهبية، الصورة الشخصية، الاسم الكامل، الجنس (ذكر / أنثى)،
/// تاريخ الميلاد (مع حساب العمر والبرج تلقائياً ومنع < 18)، والحالة الاجتماعية.
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
      initialDate:
          initialDate.isAfter(maxAdultDate) ? maxAdultDate : initialDate,
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
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Astra Step 1 Header Badge
                const NaseebakStepBadge(
                  icon: Icons.person_outline_rounded,
                  title: 'معلوماتك الشخصية',
                  subtitle: 'أدخل بياناتك الأساسية لإنشاء ملفك',
                ),
                const SizedBox(height: 20),

                // Profile Photo Upload Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.softBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.subtleBorder),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.creamHighlight,
                            child: Text(
                              initialLetter,
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryNavy,
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
                                color: AppColors.primaryNavy,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 13,
                                color: AppColors.goldAccent,
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
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'تُحفظ بأمان ويمكنك التحكم الكامل في خصوصية ظهورها للأعضاء',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Full Name Input
                NaseebakTextField(
                  fieldKey: const Key('profile_full_name_input'),
                  label: 'الاسم الكامل',
                  hintText: 'أدخل اسمك الكامل',
                  controller: _nameController,
                  onChanged: (value) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(fullName: value),
                        );
                  },
                ),
                const SizedBox(height: 18),

                // Gender Selection Pills (ذكر / أنثى)
                NaseebakSelectionField<String>(
                  label: 'الجنس',
                  options: const {
                    'male': 'ذكر',
                    'female': 'أنثى',
                  },
                  optionIcons: const {
                    'male': Icons.male_rounded,
                    'female': Icons.female_rounded,
                  },
                  selectedValue: draft.gender,
                  onChanged: (gender) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(gender: gender),
                        );
                  },
                ),
                const SizedBox(height: 18),

                // Date of Birth + Auto Age & Zodiac Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تاريخ الميلاد',
                      style: NaseebakTypography.formLabel,
                    ),
                    if (ageYears != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ageYears >= 18
                                ? AppColors.creamHighlight
                                : AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'العمر: $ageYears سنة • البرج: ${draft.calculatedZodiacSignAr}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: ageYears >= 18
                                  ? AppColors.primaryNavy
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  key: const Key('profile_dob_picker'),
                  onTap: () => _selectDateOfBirth(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.softBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.subtleBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dob != null
                              ? '${dob.day.toString().padLeft(2, '0')} / ${dob.month.toString().padLeft(2, '0')} / ${dob.year}'
                              : 'يوم / شهر / سنة',
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: dob != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 19,
                          color: AppColors.primaryNavy,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Marital Status Pills
                const Text(
                  'الحالة الاجتماعية',
                  style: NaseebakTypography.formLabel,
                ),
                const SizedBox(height: 8),
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
        NaseebakPrimaryButton(
          buttonKey: const Key('step1_next_btn'),
          label: 'التالي',
          onPressed: () {
            ref
                .read(profileRegistrationProvider.notifier)
                .validateAndAdvanceFromStep1();
          },
        ),
      ],
    );
  }
}
