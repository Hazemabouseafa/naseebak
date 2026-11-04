import 'package:flutter/material.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../data/models/member_profile_model.dart';

/// MemberCard / NaseebakProfileCard (بطاقة العضو الموحدة بتصميم Astra الفاخر)
/// لشاشات الرئيسية، نتائج البحث، والمفضلة.
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
      borderRadius: BorderRadius.circular(NaseebakSpacing.cardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(NaseebakSpacing.cardRadius),
          border: Border.all(color: AppColors.subtleBorder),
          boxShadow: NaseebakSpacing.subtleCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Subtle Navy/Cream Accent Strip + Avatar & Primary Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthorizedPhotoAvatar(
                    photoId: member.primaryPhotoId,
                    photoAuthorized: member.photoAuthorized,
                    fallbackName: member.fullName,
                    radius: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${member.fullName} • ${member.ageYears} سنة',
                                style: NaseebakTypography.cardTitle.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
                              color: AppColors.warmGold,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${member.maritalStatusLabelAr} · $locationText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          educationAndJobText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Astra Circular Favorite Heart Button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: member.isFavorited
                          ? AppColors.creamHighlight
                          : AppColors.softBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: member.isFavorited
                            ? AppColors.goldAccent
                            : AppColors.subtleBorder,
                      ),
                    ),
                    child: IconButton(
                      key: Key('favorite_toggle_btn_${member.userId}'),
                      padding: EdgeInsets.zero,
                      onPressed: onToggleFavorite,
                      tooltip: member.isFavorited
                          ? 'إزالة من المفضلة'
                          : 'إضافة إلى المفضلة',
                      icon: Icon(
                        member.isFavorited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: member.isFavorited
                            ? AppColors.warmGold
                            : AppColors.primaryNavy,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Floating Pill Action Row (Astra Card Footer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.softBackground,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(21),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.subtleBorder, width: 0.8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!member.photoAuthorized)
                    const Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'الصورة بإذن صاحب الملف',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'ملف معتمد',
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  InkWell(
                    onTap: onTapViewProfile,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'عرض الملف',
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: AppColors.goldAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef NaseebakProfileCard = MemberCard;
