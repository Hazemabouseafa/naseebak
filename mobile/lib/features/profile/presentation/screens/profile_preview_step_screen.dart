import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/profile_registration_provider.dart';

/// 06. Profile Preview Screen (الخطوة 4 من 4: معاينة ومراجعة الملف الشخصي قبل النشر)
/// تلزم المستخدم بمراجعة جميع بياناته وتتيح له التحكم في ظهور ملفه الشخصي للأعضاء قبل الاعتماد.
class ProfilePreviewStepScreen extends ConsumerWidget {
  const ProfilePreviewStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regState = ref.watch(profileRegistrationProvider);
    final draft = regState.draft;
    final ageYears = draft.calculatedAgeYears ?? 30;
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
                // Astra Preview Header Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius:
                        BorderRadius.circular(NaseebakSpacing.cardRadius),
                    border: Border.all(color: AppColors.subtleBorder),
                    boxShadow: NaseebakSpacing.subtleCardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Navy & Gold Header Cover
                      Container(
                        height: 132,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              AppColors.primaryNavy,
                              AppColors.primaryBlue,
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(21),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.goldAccent,
                                width: 2.2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.creamHighlight,
                              child: Text(
                                initialLetter,
                                style: const TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${draft.fullName} • $ageYears سنة',
                                    style: NaseebakTypography.sectionHeading,
                                  ),
                                ),
                                const NaseebakStatusBadge(
                                  label: 'معاينة قبل النشر',
                                  icon: Icons.visibility_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: AppColors.warmGold,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${draft.region}، ${draft.countryOfResidence} (${draft.nationality})',
                                    style: NaseebakTypography.supportingText,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                              height: 26,
                              color: AppColors.subtleBorder,
                            ),

                            const Text(
                              'المعلومات الأساسية والأسرية',
                              style: NaseebakTypography.cardTitle,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 14,
                              runSpacing: 12,
                              children: [
                                _InfoItem(
                                  label: 'الحالة الاجتماعية',
                                  value: draft.maritalStatusLabelAr,
                                ),
                                _InfoItem(
                                  label: 'سبق الزواج',
                                  value: draft.previouslyMarried ? 'نعم' : 'لا',
                                ),
                                _InfoItem(
                                  label: 'الأطفال',
                                  value: draft.hasChildren ? 'يوجد' : 'لا يوجد',
                                ),
                                _InfoItem(
                                  label: 'المؤهل الدراسي',
                                  value: draft.educationLevelLabelAr,
                                ),
                                _InfoItem(
                                  label: 'المهنة',
                                  value: draft.occupation,
                                ),
                                _InfoItem(
                                  label: 'السكن',
                                  value: draft.homeOwnershipLabelAr,
                                ),
                                _InfoItem(
                                  label: 'الطول والبرج',
                                  value:
                                      '${draft.heightCm} سم • ${draft.calculatedZodiacSignAr}',
                                ),
                                _InfoItem(
                                  label: 'التدخين',
                                  value: draft.smokingStatusLabelAr,
                                ),
                              ],
                            ),

                            if (draft.hobbies.isNotEmpty) ...[
                              const Divider(
                                height: 26,
                                color: AppColors.subtleBorder,
                              ),
                              const Text(
                                'الهوايات',
                                style: NaseebakTypography.formLabel,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                draft.hobbies.join(' • '),
                                style: NaseebakTypography.supportingText,
                              ),
                            ],

                            if (draft.bio.trim().isNotEmpty) ...[
                              const Divider(
                                height: 26,
                                color: AppColors.subtleBorder,
                              ),
                              const Text(
                                'نبذة عني',
                                style: NaseebakTypography.formLabel,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                draft.bio,
                                style: NaseebakTypography.bodyText.copyWith(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Visibility Control Switch
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.subtleBorder),
                  ),
                  tileColor: AppColors.softBackground,
                  activeColor: AppColors.primaryNavy,
                  title: const Text(
                    'إظهار ملفي الشخصي في نتائج البحث للأعضاء',
                    style: TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'يمكنك إخفاء أو إظهار ملفك الشخصي في أي وقت من إعدادات الخصوصية.',
                    style: TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: draft.isVisible,
                  onChanged: (val) {
                    ref.read(profileRegistrationProvider.notifier).updateDraft(
                          draft.copyWith(isVisible: val),
                        );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        NaseebakPrimaryButton(
          buttonKey: const Key('publish_profile_btn'),
          isLoading: regState.isSubmitting,
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            size: 20,
            color: AppColors.goldAccent,
          ),
          label: regState.isSubmitting
              ? 'جارٍ حفظ ونشر الملف الشخصي...'
              : 'إنهاء الإعداد ونشر الملف الشخصي',
          onPressed: () {
            ref.read(profileRegistrationProvider.notifier).publishProfile();
          },
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
