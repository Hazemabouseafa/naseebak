import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

export '../constants/app_colors.dart' show AppColors, NaseebakColors;
export '../constants/arabic_locations_data.dart' show ArabicLocationsData, NaseebakLocationDropdownField, CountryLocationEntry;
export '../theme/app_theme.dart' show AppTheme, NaseebakTheme;
export '../../features/discovery/presentation/widgets/authorized_photo_avatar.dart'
    show AuthorizedPhotoAvatar, NaseebakAvatar;
export '../../features/discovery/presentation/widgets/member_card.dart'
    show MemberCard, NaseebakProfileCard;

/// تدرج الخطوط العربية الموحد لتطبيق نصيبك — Naseebak (IBM Plex Sans Arabic)
/// متوافق مع مقاييس التصميم المعتمدة:
/// - Page Titles: 24sp Bold
/// - Section Headings: 19sp SemiBold
/// - Card Titles: 16sp SemiBold
/// - Buttons: 16sp SemiBold
/// - Body Text: 15sp Regular
/// - Form Labels: 14–15sp Medium
/// - Supporting Text: 13–14sp Regular
class NaseebakTypography {
  NaseebakTypography._();

  static const String fontFamily = AppTheme.fontFamily;

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.65,
  );

  static const TextStyle formLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle supportingText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );
}

/// المسافات والأبعاد القياسية في نظام تصميم نصيبك
class NaseebakSpacing {
  NaseebakSpacing._();

  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 16.0;
  static const double lg = 22.0;
  static const double xl = 28.0;

  static const double screenHorizontal = 20.0;
  static const double cardRadius = 22.0;
  static const double inputRadius = 16.0;
  static const double buttonRadius = 16.0;
  static const double pillRadius = 24.0;

  static List<BoxShadow> get subtleCardShadow => [
        BoxShadow(
          color: AppColors.primaryNavy.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get elevatedNavyShadow => [
        BoxShadow(
          color: AppColors.primaryNavy.withOpacity(0.22),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

/// زر أساسي فاخر بتصميم UX Pilot (أزرق ملكي #184A8C بحواف منحنية 16px وظل ناعم)
class NaseebakPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Key? buttonKey;
  final double height;
  final double borderRadius;

  const NaseebakPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.buttonKey,
    this.height = 54,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomBg = backgroundColor != null;
    final fg = foregroundColor ?? Colors.white;
    final isEnabled = onPressed != null && !isLoading;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: !isEnabled
            ? null
            : (hasCustomBg
                ? null
                : const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF1E5BB0),
                      Color(0xFF133E72),
                    ],
                  )),
        color: !isEnabled
            ? AppColors.subtleBorder
            : (hasCustomBg ? backgroundColor : null),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: (backgroundColor ?? AppColors.primaryBlue)
                      .withOpacity(0.26),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        key: buttonKey,
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: fg,
          elevation: 0,
          minimumSize: Size.fromHeight(height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: fg,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              icon!,
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NaseebakTypography.buttonText.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر ثانوي أنيق بتصميم UX Pilot (خلفية بيضاء وإطار ناعم #E5EAF0 وظل خفيف)
class NaseebakSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color? borderColor;
  final Color? textColor;
  final Key? buttonKey;
  final double height;
  final double borderRadius;

  const NaseebakSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.borderColor,
    this.textColor,
    this.buttonKey,
    this.height = 52,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.primaryBlue;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: AppColors.cardWhite,
          minimumSize: Size.fromHeight(height),
          side: BorderSide(
            color: borderColor ?? AppColors.primaryBlue.withOpacity(0.24),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NaseebakTypography.buttonText.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حقل إدخال نصي موحد بتصميم Astra مع عنوان علوي واضح
class NaseebakTextField extends StatelessWidget {
  final String? label;
  final String? badgeText;
  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final Widget? suffixIcon;
  final Key? fieldKey;

  const NaseebakTextField({
    super.key,
    this.label,
    this.badgeText,
    this.hintText,
    this.controller,
    this.onChanged,
    this.maxLines = 1,
    this.suffixIcon,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label!,
                  style: NaseebakTypography.formLabel,
                ),
              ),
              if (badgeText != null)
                Text(
                  badgeText!,
                  style: NaseebakTypography.supportingText.copyWith(
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: NaseebakTypography.bodyText.copyWith(
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.softBackground,
          ),
        ),
      ],
    );
  }
}

/// حقل اختيار Pill موحد بتصميم Astra (يستخدم في النوع، الحالة الاجتماعية، السكن، التدخين)
class NaseebakSelectionField<T> extends StatelessWidget {
  final String? label;
  final Map<T, String> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final Map<T, IconData>? optionIcons;

  const NaseebakSelectionField({
    super.key,
    this.label,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.optionIcons,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(label!, style: NaseebakTypography.formLabel),
          const SizedBox(height: 8),
        ],
        Row(
          children: options.entries.map((entry) {
            final isSelected = entry.key == selectedValue;
            final iconData = optionIcons?[entry.key];
            return Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryNavy
                          : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryNavy
                            : AppColors.subtleBorder,
                        width: isSelected ? 1.5 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryNavy.withOpacity(0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (iconData != null) ...[
                          Icon(
                            iconData,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                        ] else if (isSelected) ...[
                          const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: AppColors.goldAccent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            entry.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NaseebakTypography.fontFamily,
                              fontSize: 13.5,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// زر دائري موحد للأيقونات التفاعلية بتصميم UX Pilot (خلفية #F0F4FA وأيقونة زرقاء #184A8C)
class NaseebakCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final double iconSize;
  final String? tooltip;
  final Widget? badge;
  final Key? buttonKey;

  const NaseebakCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.backgroundColor,
    this.iconColor,
    this.iconSize = 20,
    this.tooltip,
    this.badge,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.surfaceSubtleBlue;
    final fg = iconColor ?? AppColors.primaryBlue;

    Widget btn = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        key: buttonKey,
        color: bg,
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.subtleBorder.withOpacity(0.7),
            width: 0.9,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: fg, size: iconSize),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }

    if (badge != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          btn,
          Positioned(
            top: -2,
            right: -2,
            child: badge!,
          ),
        ],
      );
    }

    return btn;
  }
}

/// شريحة تصفية دائرية موحدة بتصميم UX Pilot (الحالة المحددة كحلي/أزرق #184A8C)
class NaseebakFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? icon;
  final Key? chipKey;

  const NaseebakFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.chipKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.subtleBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة معلومات سريعة للملف الشخصي شبكة 2x2 (تصميم Screen 05 UX Pilot)
class NaseebakProfileQuickInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const NaseebakProfileQuickInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.subtleBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtleBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط التطبيق العلوي الموحد بتصميم UX Pilot
class NaseebakAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? leading;
  final double? leadingWidth;
  final bool darkHeader;
  final bool centerTitle;

  const NaseebakAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.leading,
    this.leadingWidth,
    this.darkHeader = false,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final bg = darkHeader ? AppColors.primaryNavy : AppColors.cardWhite;
    final fg = darkHeader ? Colors.white : AppColors.textPrimary;

    return AppBar(
      backgroundColor: bg,
      foregroundColor: fg,
      centerTitle: centerTitle,
      leadingWidth: leadingWidth ?? (onBack != null ? 58 : null),
      leading: leading ??
          (onBack != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 14),
                    child: NaseebakCircleButton(
                      icon: Icons.arrow_forward_rounded,
                      size: 40,
                      iconSize: 20,
                      onTap: onBack,
                      tooltip: 'رجوع',
                    ),
                  ),
                )
              : null),
      title: Text(
        title,
        style: NaseebakTypography.cardTitle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: 8),
            ]
          : null,
      bottom: darkHeader
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.subtleBorder),
            ),
    );
  }
}

/// أيقونة دائرية ذهبية دافئة لعناوين خطوات التسجيل (مطابقة لتصميم Astra Screens 03-06)
class NaseebakStepBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const NaseebakStepBadge({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.creamHighlight,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.goldAccent.withOpacity(0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.goldAccent.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 30,
            color: AppColors.warmGold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: NaseebakTypography.pageTitle.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: NaseebakTypography.supportingText,
        ),
      ],
    );
  }
}

/// بطاقة معلومات منظمة بتصميم Astra (تستخدم في الملف الشخصي ومعاينة الملف)
class NaseebakInfoCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const NaseebakInfoCard({
    super.key,
    required this.title,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(NaseebakSpacing.cardRadius),
        border: Border.all(color: AppColors.subtleBorder),
        boxShadow: NaseebakSpacing.subtleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.creamHighlight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: AppColors.warmGold,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: NaseebakTypography.cardTitle,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.subtleBorder),
          ),
          child,
        ],
      ),
    );
  }
}

/// رأس قسم موحد مع إجراء فرعي اختياري بتصميم UX Pilot
class NaseebakSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final String? actionTitle;
  final VoidCallback? onActionTap;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const NaseebakSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionTitle,
    this.onActionTap,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = actionTitle ?? actionLabel;
    final effectiveAction = onAction ?? onActionTap;
    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (effectiveLabel != null && effectiveAction != null)
          InkWell(
            onTap: effectiveAction,
            child: Text(
              effectiveLabel,
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
      ],
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return content;
  }
}

/// شارة حالة (Status Badge) أنيقة
class NaseebakStatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;

  const NaseebakStatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor = AppColors.creamHighlight,
    this.textColor = AppColors.primaryNavy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة عدم وجود بيانات (Empty State) بتصميم Astra
class NaseebakEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? actionButton;

  const NaseebakEmptyState({
    super.key,
    required this.icon,
    required this.title,
    String? subtitle,
    String? message,
    String? description,
    Widget? actionButton,
    Widget? action,
  })  : subtitle = subtitle ?? message ?? description ?? '',
        actionButton = actionButton ?? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(NaseebakSpacing.cardRadius),
        border: Border.all(color: AppColors.subtleBorder),
        boxShadow: NaseebakSpacing.subtleCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.creamHighlight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 34,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: NaseebakTypography.cardTitle.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: NaseebakTypography.supportingText,
          ),
          if (actionButton != null) ...[
            const SizedBox(height: 20),
            actionButton!,
          ],
        ],
      ),
    );
  }
}

/// بنر العضوية المميزة بتصميم UX Pilot (خلفية كحلية #123D6A مع لمسات ذهبية #E8B44D)
class NaseebakPremiumBanner extends StatelessWidget {
  final VoidCallback onTap;

  const NaseebakPremiumBanner({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 4,
            bottom: -6,
            child: Opacity(
              opacity: 0.12,
              child: Icon(
                Icons.diamond_outlined,
                size: 76,
                color: Colors.white,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'خلّي فرص التواصل أكبر ✨',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تعرّف على مزايا العضوية',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.goldAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'عضويتي',
                    style: TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// شعار نَصِيبُكَ الرسمي لشاشة الترحيب وتسجيل الدخول
class NaseebakWelcomeCollage extends StatelessWidget {
  final double height;
  const NaseebakWelcomeCollage({super.key, this.height = 240});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: Image.asset(
          'assets/images/naseebak_logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.favorite_rounded,
            size: height * 0.45,
            color: AppColors.goldAccent,
          ),
        ),
      ),
    );
  }
}

/// شريط التنقل السفلي الموحد بتصميم UX Pilot (5 وجهات: الرئيسية، البحث، الطلبات، المحادثات، حسابي)
class NaseebakBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isFiveTabs;

  const NaseebakBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isFiveTabs = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: const Border(
          top: BorderSide(color: AppColors.subtleBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        backgroundColor: AppColors.cardWhite,
        indicatorColor: AppColors.surfaceSubtleBlue,
        selectedIndex: selectedIndex.clamp(0, isFiveTabs ? 4 : 3),
        onDestinationSelected: onDestinationSelected,
        destinations: isFiveTabs
            ? const [
                NavigationDestination(
                  key: Key('bottom_nav_discover_tab'),
                  icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryBlue),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  key: Key('bottom_nav_search_tab'),
                  icon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                  label: 'البحث',
                ),
                NavigationDestination(
                  key: Key('bottom_nav_requests_tab'),
                  icon: Icon(Icons.volunteer_activism_outlined, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.volunteer_activism_rounded, color: AppColors.primaryBlue),
                  label: 'الطلبات',
                ),
                NavigationDestination(
                  key: Key('bottom_nav_messages_tab'),
                  icon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.primaryBlue),
                  label: 'المحادثات',
                ),
                NavigationDestination(
                  key: Key('bottom_nav_my_profile_tab'),
                  icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryBlue),
                  label: 'حسابي',
                ),
              ]
            : const [
                NavigationDestination(
                  key: Key('bottom_nav_discover_tab'),
                  icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryBlue),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  key: Key('bottom_nav_requests_tab'),
                  icon: Icon(Icons.volunteer_activism_outlined, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.volunteer_activism_rounded, color: AppColors.primaryBlue),
                  label: 'الطلبات',
                ),
                NavigationDestination(
                  key: Key('bottom_nav_messages_tab'),
                  icon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.primaryBlue),
                  label: 'الرسائل',
                ),
                NavigationDestination(
                  key: Key('bottom_nav_my_profile_tab'),
                  icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                  selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryBlue),
                  label: 'حسابي',
                ),
              ],
      ),
    );
  }
}

/// زخرفة أوراق الغار الذهبية الناعمة المستوحاة من تصميم Astra
class NaseebakGoldBotanicalDecoration extends StatelessWidget {
  final double size;
  final double opacity;
  final bool flipHorizontal;

  const NaseebakGoldBotanicalDecoration({
    super.key,
    this.size = 110,
    this.opacity = 0.25,
    this.flipHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.scale(
        scaleX: flipHorizontal ? -1 : 1,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GoldBotanicalPainter(opacity: opacity),
          ),
        ),
      ),
    );
  }
}

class _GoldBotanicalPainter extends CustomPainter {
  final double opacity;

  _GoldBotanicalPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = AppColors.warmGold.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final leafFillPaint = Paint()
      ..color = AppColors.goldAccent.withOpacity(opacity * 0.85)
      ..style = PaintingStyle.fill;

    // Curved botanical stem
    final stemPath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.90)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.50,
        size.width * 0.82,
        size.height * 0.14,
      );
    canvas.drawPath(stemPath, stemPaint);

    // Draw 4 stylized botanical leaves along the stem
    _drawLeaf(
      canvas,
      center: Offset(size.width * 0.34, size.height * 0.68),
      length: size.width * 0.26,
      width: size.width * 0.12,
      angle: -math.pi * 0.62,
      paint: leafFillPaint,
    );
    _drawLeaf(
      canvas,
      center: Offset(size.width * 0.52, size.height * 0.56),
      length: size.width * 0.26,
      width: size.width * 0.12,
      angle: -math.pi * 0.12,
      paint: leafFillPaint,
    );
    _drawLeaf(
      canvas,
      center: Offset(size.width * 0.58, size.height * 0.36),
      length: size.width * 0.24,
      width: size.width * 0.11,
      angle: -math.pi * 0.58,
      paint: leafFillPaint,
    );
    _drawLeaf(
      canvas,
      center: Offset(size.width * 0.78, size.height * 0.18),
      length: size.width * 0.22,
      width: size.width * 0.10,
      angle: -math.pi * 0.28,
      paint: leafFillPaint,
    );
  }

  void _drawLeaf(
    Canvas canvas, {
    required Offset center,
    required double length,
    required double width,
    required double angle,
    required Paint paint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.5, -width, length, 0)
      ..quadraticBezierTo(length * 0.5, width, 0, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoldBotanicalPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// موجة الشريط الذهبي المنساب في شاشة الترحيب (Astra Screen 01)
class NaseebakGoldenRibbonWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ribbonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.goldAccent.withOpacity(0.15),
          AppColors.goldAccent.withOpacity(0.85),
          AppColors.warmGold.withOpacity(0.45),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = AppColors.goldAccent.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    final wave1 = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.58,
        size.width * 0.65,
        size.height * 0.88,
        size.width,
        size.height * 0.64,
      );

    final wave2 = Path()
      ..moveTo(0, size.height * 0.80)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.94,
        size.width * 0.70,
        size.height * 0.62,
        size.width,
        size.height * 0.76,
      );

    canvas.drawPath(wave1, glowPaint);
    canvas.drawPath(wave1, ribbonPaint);
    canvas.drawPath(wave2, ribbonPaint..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// هيدر كحلي ملكي منحنٍ موحد لتطبيق نَصِيبُكَ مع زخارف أوراق الغار الذهبية
class NaseebakCurvedHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottom;
  final double? height;
  final bool showBotanical;

  const NaseebakCurvedHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.leading,
    List<Widget>? actions,
    List<Widget>? trailing,
    this.bottom,
    this.height,
    this.showBotanical = true,
  }) : actions = actions ?? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryNavy,
            AppColors.deepNavy,
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22123D6A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showBotanical)
            const Positioned(
              top: -10,
              left: -15,
              child: NaseebakGoldBotanicalDecoration(
                size: 95,
                opacity: 0.18,
                flipHorizontal: true,
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (leading != null)
                        leading!
                      else if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                          tooltip: 'رجوع',
                        )
                      else
                        const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.goldAccent.withOpacity(0.92),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (actions != null) ...actions!,
                    ],
                  ),
                  if (bottom != null) ...[
                    const SizedBox(height: 14),
                    bottom!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة بيضاء فاخرة موحدة لجميع شاشات نَصِيبُكَ
class NaseebakCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final double radius;

  const NaseebakCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.radius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardWhite,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: AppColors.subtleBorder, width: 1.2),
        boxShadow: NaseebakSpacing.subtleCardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// هيكل تحميل نابض ناعم وفاخر لتجنب الشاشات البيضاء
class NaseebakLoadingSkeleton extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const NaseebakLoadingSkeleton({
    super.key,
    required this.height,
    this.width,
    this.radius = 16.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.subtleBorder.withOpacity(0.55),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// نافذة تأكيد فاخرة موحدة للإجراءات الهامة (الحظر، البلاغات، إلغاء الطلبات)
class NaseebakConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final IconData? icon;

  const NaseebakConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText = 'إلغاء',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.cardWhite,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? AppColors.error.withOpacity(0.12)
                        : AppColors.creamHighlight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive
                        ? AppColors.error
                        : AppColors.primaryNavy,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: const BorderSide(color: AppColors.subtleBorder),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCancel?.call();
                    },
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive
                          ? AppColors.error
                          : AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontFamily: NaseebakTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
