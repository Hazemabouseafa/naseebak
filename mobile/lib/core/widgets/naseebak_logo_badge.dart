import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

/// الشعار الرسمي المعتمد لتطبيق نصيبك — Naseebak
/// يستخدم الأصول الرسمية المستخرجة من شعار نصيبك المعتمد (العريس والعروس داخل القلب الذهبي وأوراق الغار الذهبية)
/// بدون أي رموز دينية أو مساجد أو أهلة.
class NaseebakLogoBadge extends StatelessWidget {
  final double size;
  final bool showText;
  final bool lightText;
  final bool useFullEmblem;

  const NaseebakLogoBadge({
    super.key,
    this.size = 56,
    this.showText = true,
    this.lightText = false,
    this.useFullEmblem = false,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = useFullEmblem
        ? AppStrings.officialLogoAsset
        : AppStrings.officialAppIconAsset;

    final badgeGraphic = useFullEmblem
        ? SizedBox(
            width: size * 1.28,
            height: size,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _FallbackOfficialLogoMark(
                size: size,
                lightText: lightText,
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withOpacity(0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.28),
              child: Image.asset(
                assetPath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => _FallbackOfficialLogoMark(
                  size: size,
                  lightText: lightText,
                ),
              ),
            ),
          );

    if (!showText) {
      return badgeGraphic;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badgeGraphic,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.appNameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: size * 0.44,
                  fontWeight: FontWeight.w700,
                  color: lightText ? Colors.white : AppColors.primaryNavy,
                  height: 1.15,
                ),
              ),
              Text(
                'Naseebak',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: (size * 0.22).clamp(9.0, 14.0),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: lightText ? AppColors.goldAccent : AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FallbackOfficialLogoMark extends StatelessWidget {
  final double size;
  final bool lightText;

  const _FallbackOfficialLogoMark({
    required this.size,
    required this.lightText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryNavy, AppColors.primaryBlue],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: AppColors.goldAccent,
          width: 1.8,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          color: AppColors.goldAccent,
          size: size * 0.52,
        ),
      ),
    );
  }
}
