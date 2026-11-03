import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/member_profile_model.dart';
import 'authorized_photo_avatar.dart';

/// MemberCard (بطاقة العضو الموحدة لشاشات الرئيسية، نتائج البحث، والمفضلة)
/// تعرض فقط البيانات المسموح بها: الصورة الشخصية وفق الخصوصية، الاسم، العمر، الحالة الاجتماعية،
/// المؤهل الدراسي، المهنة، البلد أو المنطقة، زر "عرض الملف"، وزر الإضافة/الإزالة من المفضلة.
class MemberCard extends StatelessWidget {
  final MemberCardModel member;
  final VoidCallback onTapViewProfile;
  final VoidCallback onToggleFavorite;

  const MemberCard({
    super.key,
    required this.member,
    required this.onTapViewProfile,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final locationText = [
      if (member.region.isNotEmpty) member.region,
      if (member.countryOfResidence.isNotEmpty) member.countryOfResidence,
    ].join('، ');

    final educationAndJobText = [
      member.educationLevelLabelAr,
      if (member.occupation.isNotEmpty) member.occupation,
      member.smokingStatusLabelAr,
    ].join(' · ');

    return InkWell(
      onTap: onTapViewProfile,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AuthorizedPhotoAvatar(
              photoId: member.primaryPhotoId,
              photoAuthorized: member.photoAuthorized,
              fallbackName: member.fullName,
              radius: 29,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${member.fullName} • ${member.ageYears} سنة',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${member.maritalStatusLabelAr} · $locationText',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    educationAndJobText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: onTapViewProfile,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtleBlue,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            'عرض الملف',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      if (!member.photoAuthorized) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'الصورة بإذن صاحب الملف',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('favorite_toggle_btn_${member.userId}'),
              onPressed: onToggleFavorite,
              tooltip: member.isFavorited
                  ? 'إزالة من المفضلة'
                  : 'إضافة إلى المفضلة',
              icon: Icon(
                member.isFavorited
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: member.isFavorited
                    ? AppColors.accentYellow
                    : AppColors.textMuted,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
