import 'package:flutter/material.dart';

/// الهوية البصرية المعتمدة لتطبيق نصيبك — Naseebak (تصميم Astra الفاخر)
/// يمنع استخدام أي تدرجات خضراء سابقة أو أي رموز دينية.
class AppColors {
  AppColors._();

  /// Primary Navy: #123D6A
  static const Color primaryNavy = Color(0xFF123D6A);
  static const Color darkBlue = Color(0xFF123D6A);
  static const Color primaryBlueDark = Color(0xFF123D6A);

  /// Deep Navy for Splash / Header Gradient: #0A294E
  static const Color deepNavy = Color(0xFF0A294E);

  /// Primary Blue: #145A9E
  static const Color primaryBlue = Color(0xFF145A9E);

  /// Gold Accent: #FFC43D
  static const Color goldAccent = Color(0xFFFFC43D);
  static const Color accentYellow = Color(0xFFFFC43D);

  /// Warm Botanical Gold: #D9A436
  static const Color warmGold = Color(0xFFD9A436);

  /// Cream Highlight: #FFF4E1
  static const Color creamHighlight = Color(0xFFFFF4E1);
  static const Color surfaceSubtleYellow = Color(0xFFFFF4E1);

  /// Soft Background: #F5F8FC
  static const Color softBackground = Color(0xFFF5F8FC);
  static const Color backgroundSecondary = Color(0xFFF5F8FC);

  /// Card White / Primary Background: #FFFFFF
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color backgroundPrimary = Color(0xFFFFFFFF);

  /// Primary Text: #1D2939
  static const Color textPrimary = Color(0xFF1D2939);

  /// Secondary / Supporting Text: #667085
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF667085);

  /// Subtle Border: #E4EAF2
  static const Color subtleBorder = Color(0xFFE4EAF2);
  static const Color borderLight = Color(0xFFE4EAF2);

  /// Subtle Blue Surface: #EAF2FA
  static const Color surfaceSubtleBlue = Color(0xFFEAF2FA);

  /// Semantic Status Colors
  static const Color success = Color(0xFF12B76A);
  static const Color error = Color(0xFFD92D20);
  static const Color warning = Color(0xFFF79009);
  static const Color info = Color(0xFF145A9E);
}

/// Alias for centralized design system nomenclature
typedef NaseebakColors = AppColors;
