import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// شعار نصيبك المرجعي (Placeholder) المستوحى من رسم بسيط للعريس والعروس
/// بدون أي رموز دينية أو معمارية دينية، وبألوان الهوية الجديدة (الأزرق والذهبي/الأصفر).
/// ملاحظة: هذا العنصر محدّد بوضوح كأصل مرجعي مؤقت (Placeholder) لحين تزويد ملف الشعار المتجه النهائي المعتمد.
class NaseebakLogoBadge extends StatelessWidget {
  final double size;
  final bool showText;
  final bool lightText;

  const NaseebakLogoBadge({
    super.key,
    this.size = 56,
    this.showText = true,
    this.lightText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: lightText ? Colors.white.withOpacity(0.14) : AppColors.surfaceSubtleBlue,
            borderRadius: BorderRadius.circular(size * 0.30),
            border: Border.all(
              color: AppColors.accentYellow,
              width: 2.0,
            ),
          ),
          child: CustomPaint(
            painter: _BrideAndGroomPlaceholderPainter(
              primaryColor: lightText ? Colors.white : AppColors.primaryBlue,
              accentColor: AppColors.accentYellow,
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'نصيبك',
                style: TextStyle(
                  fontSize: size * 0.44,
                  fontWeight: FontWeight.w800,
                  color: lightText ? Colors.white : AppColors.darkBlue,
                  height: 1.15,
                ),
              ),
              Text(
                'Naseebak',
                style: TextStyle(
                  fontSize: size * 0.20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: lightText ? AppColors.accentYellow : AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BrideAndGroomPlaceholderPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  _BrideAndGroomPlaceholderPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Groom silhouette (Right side in RTL)
    final groomCenterX = size.width * 0.62;
    final headY = size.height * 0.34;
    final headRadius = size.width * 0.11;

    canvas.drawCircle(Offset(groomCenterX, headY), headRadius, strokePaint);
    final groomShoulders = Path()
      ..moveTo(groomCenterX - size.width * 0.17, size.height * 0.76)
      ..quadraticBezierTo(
        groomCenterX,
        size.height * 0.48,
        groomCenterX + size.width * 0.17,
        size.height * 0.76,
      );
    canvas.drawPath(groomShoulders, strokePaint);

    // Groom bow-tie accent
    canvas.drawCircle(Offset(groomCenterX, size.height * 0.54), size.width * 0.035, accentPaint);

    // Bride silhouette (Left side in RTL)
    final brideCenterX = size.width * 0.38;
    canvas.drawCircle(Offset(brideCenterX, headY + size.height * 0.02), headRadius * 0.94, strokePaint);
    final brideShoulders = Path()
      ..moveTo(brideCenterX - size.width * 0.16, size.height * 0.76)
      ..quadraticBezierTo(
        brideCenterX,
        size.height * 0.50,
        brideCenterX + size.width * 0.16,
        size.height * 0.76,
      );
    canvas.drawPath(brideShoulders, strokePaint);

    // Subtle crown / floral tiara dot in Accent Yellow (#FFC43D)
    canvas.drawCircle(
      Offset(brideCenterX, headY - headRadius * 1.15),
      size.width * 0.045,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BrideAndGroomPlaceholderPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
