import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Member Profile Card Preview (Matching Mockup Screen 08 layout hierarchy)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Cover in Naseebak Subtle Blue & Yellow Accent
                      Container(
                        height: 125,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.surfaceSubtleBlue,
                              AppColors.surfaceSubtleYellow,
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primaryBlue,
                            child: Text(
                              initialLetter,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${draft.fullName} • $ageYears سنة',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtleBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'معاينة قبل النشر',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${draft.region}، ${draft.countryOfResidence} (${draft.nationality})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            const Text(
                              'المعلومات الأساسية والأسرية',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 14,
                              runSpacing: 10,
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
                              const Divider(height: 24),
                              const Text(
                                'الهوايات',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                draft.hobbies.join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],

                            if (draft.bio.trim().isNotEmpty) ...[
                              const Divider(height: 24),
                              const Text(
                                'نبذة عني',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                draft.bio,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.7,
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
                    horizontal: 14,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                  tileColor: AppColors.backgroundSecondary,
                  activeColor: AppColors.primaryBlue,
                  title: const Text(
                    'إظهار ملفي الشخصي في نتائج البحث للأعضاء',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'يمكنك إخفاء أو إظهار ملفك الشخصي في أي وقت من إعدادات الخصوصية.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
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
        ElevatedButton.icon(
          key: const Key('publish_profile_btn'),
          onPressed: regState.isSubmitting
              ? null
              : () {
                  ref
                      .read(profileRegistrationProvider.notifier)
                      .publishProfile();
                },
          icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
          label: Text(
            regState.isSubmitting
                ? 'جارٍ حفظ ونشر الملف الشخصي...'
                : 'اعتماد ونشر الملف الشخصي',
          ),
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
      width: 135,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
