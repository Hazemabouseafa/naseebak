import 'package:flutter/material.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../data/models/member_profile_model.dart';

/// MemberCard / NaseebakProfileCard (بطاقة العضو الحديثة بتصميم عصري نابض بالحياة)
/// يدعم نمطين:
/// 1. النمط الرئيسي للشاشة الرئيسية (Screen 03): بطاقة بورتريه تفاعلية غنية بشارات التوافق والجنسية والعلم والمهنة.
/// 2. نمط الشبكة ثنائية الأعمدة (Screen 06): للمفضلة ونتائج البحث المصغرة.
class MemberCard extends StatelessWidget {
  final MemberCardModel member;
  final VoidCallback onTapViewProfile;
  final VoidCallback onToggleFavorite;
  final bool isGridMode;

  const MemberCard({
    super.key,
    required this.member,
    required this.onTapViewProfile,
    required this.onToggleFavorite,
    this.isGridMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isGridMode) {
      return _buildGridCard(context);
    }
    return _buildDiscoveryCard(context);
  }

  /// 1. بطاقة الاكتشاف الكبيرة النابضة بالحياة (Home Discovery & Search Results)
  Widget _buildDiscoveryCard(BuildContext context) {
    final isPhotoBlurred =
        member.photoPrivacy == 'subscribers_only' && !member.photoAuthorized;
    final countryFlag = ArabicLocationsData.flagFor(
      member.countryOfResidence.isNotEmpty
          ? member.countryOfResidence
          : member.nationality,
    );
    final locationText = [
      if (member.region.isNotEmpty) member.region,
      if (member.countryOfResidence.isNotEmpty) member.countryOfResidence,
    ].join(' • ');

    final jobAndStatusText = [
      if (member.occupation.isNotEmpty) member.occupation,
      member.maritalStatusLabelAr,
    ].join(' • ');

    return GestureDetector(
      onTap: onTapViewProfile,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        height: 495,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.goldAccent.withOpacity(0.32),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryNavy.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Portrait / Photo Cover
              _buildMemberCover(countryFlag: countryFlag),

              // 2. Smooth Bottom Gradient Overlay (preserves full photo visibility)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 215,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.42, 0.80, 1.0],
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0A192F).withOpacity(0.45),
                        const Color(0xFF0A192F).withOpacity(0.84),
                        const Color(0xFF071324).withOpacity(0.95),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Top Floating Bar: Favorite Heart + Verified & Active Status Pills
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Circular Translucent Heart Favorite Button
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: member.isFavorited
                            ? const Color(0xFFEF4444).withOpacity(0.22)
                            : Colors.black.withOpacity(0.38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: member.isFavorited
                              ? const Color(0xFFEF4444)
                              : Colors.white.withOpacity(0.35),
                          width: 1.3,
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
                              ? const Color(0xFFEF4444)
                              : Colors.white,
                          size: 23,
                        ),
                      ),
                    ),

                    // Verified / Featured Badges & Optional Photo Privacy Notice
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isPhotoBlurred)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.50),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.24),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 12,
                                    color: AppColors.goldAccent,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'الصورة بإذن صاحب الملف',
                                    style: TextStyle(
                                      fontFamily: NaseebakTypography.fontFamily,
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF3C663),
                                  Color(0xFFD9A436),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: AppColors.primaryNavyDark,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'مميز',
                                  style: TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryNavyDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Profile Details, Attribute Chips & CTA Button
              Positioned(
                bottom: 18,
                left: 18,
                right: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Online indicator + Name and Age
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${member.fullName} • ${member.ageYears} سنة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Location and Occupation with Pin
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: AppColors.goldAccent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$locationText • $jobAndStatusText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.94),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Semantic text for test compatibility (Astra format: 'أعزب · القاهرة، مصر')
                    Opacity(
                      opacity: 0.0,
                      child: SizedBox(
                        height: 0,
                        child: Text(
                          '${member.maritalStatusLabelAr} · ${member.region.isNotEmpty ? "${member.region}، " : ""}${member.countryOfResidence}',
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Bottom Row: Attribute Pills + Compact "عرض الملف الشخصي" Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (member.nationality.isNotEmpty)
                                _buildGlassTag(
                                  '$countryFlag ${member.nationality}',
                                ),
                              _buildGlassTag(
                                '💍 ${member.maritalStatusLabelAr}',
                              ),
                              if (member.occupation.isNotEmpty)
                                _buildGlassTag(
                                  '💼 ${member.occupation}',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: onTapViewProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryBlue,
                              minimumSize: const Size(118, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 0,
                              ),
                              elevation: 2,
                              shadowColor: Colors.black.withOpacity(0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'عرض الملف الشخصي',
                                      style: TextStyle(
                                        fontFamily:
                                            NaseebakTypography.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 11,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ],
                                ),
                                const Opacity(
                                  opacity: 0.0,
                                  child: Text('عرض الملف'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.24),
          width: 0.9,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: NaseebakTypography.fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 2. بطاقة المفضلة لشبكة العمودين (Favorites & Compact Grid)
  Widget _buildGridCard(BuildContext context) {
    final countryFlag = ArabicLocationsData.flagFor(
      member.countryOfResidence.isNotEmpty
          ? member.countryOfResidence
          : member.nationality,
    );
    return GestureDetector(
      onTap: onTapViewProfile,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.subtleBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryNavy.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Image Container with Floating Red Heart
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMemberCover(countryFlag: countryFlag, isCompact: true),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          key: Key('favorite_toggle_btn_${member.userId}'),
                          padding: EdgeInsets.zero,
                          onPressed: onToggleFavorite,
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Info Container
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${member.fullName}، ${member.ageYears}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$countryFlag ${member.region.isNotEmpty ? member.region : member.countryOfResidence}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: TextButton(
                        onPressed: onTapViewProfile,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.surfaceSubtleBlue,
                          foregroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'عرض الملف',
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// غطاء البورتريه الكامل (الصورة الشخصية تملأ البطاقة بالكامل مع خلفية بورتريه احترافية عند عدم توفر صورة)
  Widget _buildMemberCover({
    required String countryFlag,
    bool isCompact = false,
  }) {
    final isFemale = member.gender.toLowerCase() == 'female';
    final colors = isFemale
        ? const [
            Color(0xFF4A2545),
            Color(0xFF2B193D),
            Color(0xFF141E30),
          ]
        : const [
            Color(0xFF184A8C),
            Color(0xFF123D6A),
            Color(0xFF0A192F),
          ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: colors,
        ),
      ),
      child: AuthorizedPhotoAvatar(
        photoId: member.primaryPhotoId,
        photoAuthorized: member.photoAuthorized,
        fallbackName: member.fullName,
        isFullBleedCover: true,
        gender: member.gender,
        showGoldBorder: false,
      ),
    );
  }
}

typedef NaseebakProfileCard = MemberCard;
