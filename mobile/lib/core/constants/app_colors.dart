import 'package:flutter/material.dart';

/// الهوية البصرية المعتمدة لتطبيق نصيبك — Naseebak (تصميم UX Pilot الفاخر)
/// Primary Blue: #184A8C, Deep Navy: #123D6A, Premium Gold: #E8B44D
/// Primary Background: #FFFFFF, Secondary Background: #F5F8FC
/// Primary Text: #1D2939, Secondary Text: #667085, Border: #E5EAF0
/// Success: #16A085, Error: #D64550
class AppColors {
  AppColors._();

  /// Primary Blue: #184A8C
  static const Color primaryBlue = Color(0xFF184A8C);
  static const Color primaryBlueDark = Color(0xFF123D6A);

  /// Deep Navy: #123D6A
  static const Color primaryNavy = Color(0xFF123D6A);
  static const Color darkBlue = Color(0xFF123D6A);
  static const Color deepNavy = Color(0xFF123D6A);
  static const Color primaryNavyDark = Color(0xFF0A294E);

  /// Premium Gold: #E8B44D
  static const Color goldAccent = Color(0xFFE8B44D);
  static const Color accentYellow = Color(0xFFE8B44D);
  static const Color accentGold = Color(0xFFE8B44D);
  static const Color accentGoldLight = Color(0xFFFFE082);
  static const Color accentGoldDark = Color(0xFFD9A436);
  static const Color accentGoldMuted = Color(0xFFFFF4E1);
  static const Color warmGold = Color(0xFFE8B44D);
  static const Color creamHighlight = Color(0xFFFFF8EC);
  static const Color surfaceSubtleYellow = Color(0xFFFFF8EC);

  /// Primary Background: #FFFFFF
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color backgroundPrimary = Color(0xFFFFFFFF);

  /// Secondary Background: #F5F8FC
  static const Color softBackground = Color(0xFFF5F8FC);
  static const Color backgroundSecondary = Color(0xFFF5F8FC);
  static const Color backgroundBeige = Color(0xFFF5F8FC);

  /// Primary Text: #1D2939
  static const Color textPrimary = Color(0xFF1D2939);
  static const Color textDarkNavy = Color(0xFF123D6A);

  /// Secondary / Supporting Text: #667085
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF667085);
  static const Color textWarmGray = Color(0xFF667085);

  /// Border: #E5EAF0
  static const Color subtleBorder = Color(0xFFE5EAF0);
  static const Color borderLight = Color(0xFFE5EAF0);
  static const Color errorBorder = Color(0xFFFDA29B);

  /// Subtle Blue Surface / Circular Button Background: #F0F4FA
  static const Color surfaceSubtleBlue = Color(0xFFF0F4FA);
  static const Color circleButtonBg = Color(0xFFF0F4FA);

  /// Shadow color
  static const Color shadowColor = Color(0x0F123D6A);

  /// Semantic Status Colors
  static const Color success = Color(0xFF16A085);
  static const Color error = Color(0xFFD64550);
  static const Color warning = Color(0xFFF79009);
  static const Color info = Color(0xFF184A8C);
}

/// Alias for centralized design system nomenclature
typedef NaseebakColors = AppColors;
