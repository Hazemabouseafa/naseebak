import 'package:flutter/material.dart';

/// الهوية البصرية المعتمدة لتطبيق نصيبك — Naseebak
/// يمنع استخدام أي تدرجات خضراء سابقة أو أي رموز دينية.
class AppColors {
  AppColors._();

  /// Primary background: #FFFFFF
  static const Color backgroundPrimary = Color(0xFFFFFFFF);

  /// Secondary background: #F5F8FC
  static const Color backgroundSecondary = Color(0xFFF5F8FC);

  /// Primary blue: #145A9E
  static const Color primaryBlue = Color(0xFF145A9E);

  /// Dark blue: #123D6A
  static const Color darkBlue = Color(0xFF123D6A);
  static const Color primaryBlueDark = Color(0xFF123D6A);

  /// Accent yellow: #FFC43D
  static const Color accentYellow = Color(0xFFFFC43D);

  /// Primary Text: #1D2939
  static const Color textPrimary = Color(0xFF1D2939);

  /// Supporting / Muted Text & Borders
  static const Color textSecondary = Color(0xFF475467);
  static const Color textMuted = Color(0xFF667085);
  static const Color borderLight = Color(0xFFD0D5DD);
  static const Color surfaceSubtleBlue = Color(0xFFEAF2FA);
  static const Color surfaceSubtleYellow = Color(0xFFFFF8E6);

  /// Semantic Status Colors
  static const Color error = Color(0xFFD92D20);
  static const Color warning = Color(0xFFF79009);
  static const Color info = Color(0xFF145A9E);
}
