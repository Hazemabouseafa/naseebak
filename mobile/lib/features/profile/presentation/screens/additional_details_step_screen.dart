import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';

/// 05. Additional Profile Details and Biography Screen (الخطوة 3 من 4: التفاصيل الإضافية والنبذة)
/// تشمل: الطول بالسنتيمتر، البرج الفلكي (محسوب تلقائياً)، التدخين، الجنسية، بلد الإقامة، المنطقة/المحافظة، الهوايات، والنبذة الشخصية الاختيارية.
class AdditionalDetailsStepScreen extends ConsumerStatefulWidget {
  const AdditionalDetailsStepScreen({super.key});

  @override
  ConsumerState<AdditionalDetailsStepScreen> createState() =>
      _AdditionalDetailsStepScreenState();
}

class _AdditionalDetailsStepScreenState
    extends ConsumerState<AdditionalDetailsStepScreen> {
  static const List<String> _availableHobbies = [
    'القراءة',
    'السفر',
    'الرياضة',
    'الطبخ',
    'الفنون والتصميم',
    'العمل التطوعي',
    'التصوير',
    'المشي والطبيعة',
  ];

  late final TextEditingController _nationalityController;
  late final TextEditingController _countryController;
  late final TextEditingController _regionController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileRegistrationProvider).draft;
    _nationalityController = TextEditingController(text: draft.nationality);
    _countryController = TextEditingController(text: draft.countryOfResidence);
    _regionController = TextEditingController(text: draft.region);
    _bioController = TextEditingController(text: draft.bio);
  }

  @override
  void dispose() {
    _nationalityController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _bioController.dispose();
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
                // Height & Auto-Calculated Zodiac Sign Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الطول: ${draft.heightCm} سم',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Slider(
                            value: draft.heightCm.toDouble(),
                            min: 140,
                            max: 210,
                            divisions: 70,
                            activeColor: AppColors.primaryBlue,
                            label: '${draft.heightCm} سم',
                            onChanged: (val) {
                              ref
                                  .read(profileRegistrationProvider.notifier)
                                  .updateDraft(
                                    draft.copyWith(heightCm: val.round()),
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtleBlue,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'البرج الفلكي',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            draft.calculatedZodiacSignAr,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Smoking Status
                const Text(
                  'حالة التدخين',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                NaseebakSegmentedControl<String>(
                  options: const {
                    'non_smoker': 'غير مدخن',
                    'occasional': 'أحياناً',
                    'smoker': 'مدخن',
                  },
                  selectedValue: draft.smokingStatus,
                  onChanged: (val) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(smokingStatus: val),
                        );
                  },
                ),
                const SizedBox(height: 16),

                // Location: Nationality, Country of Residence, Region
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الجنسية',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nationalityController,
                            onChanged: (val) => ref
                                .read(profileRegistrationProvider.notifier)
                                .updateDraft(draft.copyWith(nationality: val)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بلد الإقامة',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _countryController,
                            onChanged: (val) => ref
                                .read(profileRegistrationProvider.notifier)
                                .updateDraft(
                                  draft.copyWith(countryOfResidence: val),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'المحافظة / المنطقة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _regionController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: القاهرة / الجيزة / الإسكندرية / الرياض',
                  ),
                  onChanged: (val) => ref
                      .read(profileRegistrationProvider.notifier)
                      .updateDraft(draft.copyWith(region: val)),
                ),
                const SizedBox(height: 16),

                // Hobbies Selection
                const Text(
                  'الهوايات والاهتمامات',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableHobbies.map((hobby) {
                    final selected = draft.hobbies.contains(hobby);
                    return FilterChip(
                      label: Text(hobby),
                      selected: selected,
                      selectedColor: AppColors.surfaceSubtleBlue,
                      checkmarkColor: AppColors.primaryBlue,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                      ),
                      onSelected: (isSelected) {
                        final updated = List<String>.from(draft.hobbies);
                        if (isSelected) {
                          updated.add(hobby);
                        } else {
                          updated.remove(hobby);
                        }
                        ref
                            .read(profileRegistrationProvider.notifier)
                            .updateDraft(draft.copyWith(hobbies: updated));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Optional Biography
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نبذة شخصية عنك وعن شريك الحياة',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'اختياري',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'اكتب نبذة مختصرة ومحترمة تعبّر عن شخصيتك وما تبحث عنه في شريك الحياة...',
                  ),
                  onChanged: (val) => ref
                      .read(profileRegistrationProvider.notifier)
                      .updateDraft(draft.copyWith(bio: val)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('step3_next_btn'),
          onPressed: () {
            ref
                .read(profileRegistrationProvider.notifier)
                .validateAndAdvanceFromStep3();
          },
          child: const Text('مراجعة الملف قبل النشر'),
        ),
      ],
    );
  }
}
