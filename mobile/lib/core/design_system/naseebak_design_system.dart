import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

export '../constants/app_colors.dart' show AppColors, NaseebakColors;
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
  static const double pillRadius = 28.0;

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

/// زر أساسي فاخر بتصميم Astra (كحلي ملكي بحواف دائرية كاملة وظل ناعم)
class NaseebakPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Key? buttonKey;

  const NaseebakPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primaryNavy;
    final fg = foregroundColor ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NaseebakSpacing.pillRadius),
        boxShadow: onPressed != null && !isLoading
            ? NaseebakSpacing.elevatedNavyShadow
            : null,
      ),
      child: ElevatedButton(
        key: buttonKey,
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NaseebakSpacing.pillRadius),
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
                style: NaseebakTypography.buttonText.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر ثانوي أنيق بتصميم Astra (خلفية بيضاء وإطار ناعم)
class NaseebakSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color? borderColor;
  final Color? textColor;
  final Key? buttonKey;

  const NaseebakSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.borderColor,
    this.textColor,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.primaryNavy;
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: AppColors.cardWhite,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(
          color: borderColor ?? AppColors.subtleBorder,
          width: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NaseebakSpacing.pillRadius),
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
                color: fg,
              ),
            ),
          ),
        ],
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

/// شريط التطبيق العلوي الموحد بتصميم Astra
class NaseebakAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? leading;
  final double? leadingWidth;
  final bool darkHeader;

  const NaseebakAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.leading,
    this.leadingWidth,
    this.darkHeader = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final bg = darkHeader ? AppColors.primaryNavy : AppColors.cardWhite;
    final fg = darkHeader ? Colors.white : AppColors.textPrimary;

    return AppBar(
      backgroundColor: bg,
      foregroundColor: fg,
      leadingWidth: leadingWidth,
      leading: leading ??
          (onBack != null
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 19,
                    color: fg,
                  ),
                  onPressed: onBack,
                  tooltip: 'رجوع',
                )
              : null),
      title: Text(
        title,
        style: NaseebakTypography.cardTitle.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
      actions: actions,
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

/// رأس قسم موحد مع إجراء فرعي اختياري
class NaseebakSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const NaseebakSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: NaseebakTypography.sectionHeading,
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
      ],
    );
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
    required this.subtitle,
    this.actionButton,
  });

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

/// شريط التنقل السفلي الموحد بتصميم Astra
class NaseebakBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const NaseebakBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
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
        indicatorColor: AppColors.creamHighlight,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            key: Key('bottom_nav_discover_tab'),
            icon: Icon(Icons.explore_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.explore_rounded, color: AppColors.primaryNavy),
            label: 'اكتشف',
          ),
          NavigationDestination(
            key: Key('bottom_nav_requests_tab'),
            icon: Icon(Icons.favorite_border_rounded, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.favorite_rounded, color: AppColors.primaryNavy),
            label: 'الطلبات',
          ),
          NavigationDestination(
            key: Key('bottom_nav_messages_tab'),
            icon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.primaryNavy),
            label: 'الرسائل',
          ),
          NavigationDestination(
            key: Key('bottom_nav_my_profile_tab'),
            icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryNavy),
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
