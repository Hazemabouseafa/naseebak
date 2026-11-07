import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/profile_registration_provider.dart';
import '../widgets/step_progress_header.dart';

/// 05. Additional Profile Details and Biography Screen (الخطوة 3 من 4: التفاصيل الإضافية والنبذة — تصميم Astra Screen 06)
/// تشمل: أيقونة الخطوة الذهبية، الطول بالسنتيمتر، البرج الفلكي المحسوب تلقائياً، التدخين،
/// الجنسية (قائمة منسدلة)، بلد الإقامة (قائمة منسدلة)، المحافظة/المدينة (قائمة منسدلة)، الهوايات، والنبذة الشخصية الاختيارية.
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

  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileRegistrationProvider).draft;
    _bioController = TextEditingController(text: draft.bio);
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(profileRegistrationProvider).draft;
    final availableNationalities =
        ArabicLocationsData.nationalitiesForGender(draft.gender);
    final availableCountries = ArabicLocationsData.allCountries;
    final availableCities =
        ArabicLocationsData.citiesForCountry(draft.countryOfResidence);

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
                  icon: Icons.description_outlined,
                  title: 'نبذة عنك وتفاصيل إضافية',
                  subtitle: 'اختر جنسيتك ودولة ومحافظة إقامتك من القائمة وهواياتك لإكمال ملفك',
                ),
                const SizedBox(height: 20),

                // Height & Auto-Calculated Zodiac Sign Card
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.softBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.subtleBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الطول: ${draft.heightCm} سم',
                              style: NaseebakTypography.formLabel.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Slider(
                              value: draft.heightCm.toDouble(),
                              min: 140,
                              max: 210,
                              divisions: 70,
                              activeColor: AppColors.primaryNavy,
                              inactiveColor: AppColors.subtleBorder,
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
                          color: AppColors.creamHighlight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.goldAccent.withOpacity(0.55),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'البرج الفلكي',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              draft.calculatedZodiacSignAr,
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Smoking Status
                const Text(
                  'التدخين',
                  style: NaseebakTypography.formLabel,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 18),

                // Location: Nationality & Country of Residence (Dropdown Pickers)
                Row(
                  children: [
                    Expanded(
                      child: NaseebakLocationDropdownField(
                        label: 'الجنسية',
                        value: draft.nationality,
                        options: availableNationalities,
                        placeholder: 'اختر الجنسية',
                        leadingIcon: Icons.flag_outlined,
                        onChanged: (val) => ref
                            .read(profileRegistrationProvider.notifier)
                            .updateDraft(draft.copyWith(nationality: val)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NaseebakLocationDropdownField(
                        label: 'بلد الإقامة',
                        value: draft.countryOfResidence,
                        options: availableCountries,
                        placeholder: 'اختر الدولة',
                        leadingIcon: Icons.public_rounded,
                        onChanged: (newCountry) {
                          final cities =
                              ArabicLocationsData.citiesForCountry(newCountry);
                          final updatedRegion = cities.contains(draft.region)
                              ? draft.region
                              : (cities.isNotEmpty ? cities.first : '');
                          ref
                              .read(profileRegistrationProvider.notifier)
                              .updateDraft(
                                draft.copyWith(
                                  countryOfResidence: newCountry,
                                  region: updatedRegion,
                                ),
                              );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                NaseebakLocationDropdownField(
                  label: 'المحافظة / المدينة',
                  value: draft.region,
                  options: availableCities,
                  placeholder: 'اختر المحافظة أو المدينة',
                  leadingIcon: Icons.location_city_rounded,
                  onChanged: (val) => ref
                      .read(profileRegistrationProvider.notifier)
                      .updateDraft(draft.copyWith(region: val)),
                ),
                const SizedBox(height: 18),

                // Hobbies Selection
                const Text(
                  'الهوايات والاهتمامات',
                  style: NaseebakTypography.formLabel,
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
                      selectedColor: AppColors.primaryNavy,
                      backgroundColor: AppColors.cardWhite,
                      checkmarkColor: AppColors.goldAccent,
                      labelStyle: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? Colors.white : AppColors.textPrimary,
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
                const SizedBox(height: 18),

                // Optional Biography
                NaseebakTextField(
                  label: 'نبذة شخصية',
                  badgeText: 'اختياري',
                  hintText:
                      'اكتب نبذة مختصرة عن نفسك وما تبحث عنه في شريك حياتك...',
                  controller: _bioController,
                  maxLines: 3,
                  onChanged: (val) => ref
                      .read(profileRegistrationProvider.notifier)
                      .updateDraft(draft.copyWith(bio: val)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        NaseebakPrimaryButton(
          buttonKey: const Key('step3_next_btn'),
          label: 'مراجعة الملف قبل النشر',
          onPressed: () {
            ref
                .read(profileRegistrationProvider.notifier)
                .validateAndAdvanceFromStep3();
          },
        ),
      ],
    );
  }
}
