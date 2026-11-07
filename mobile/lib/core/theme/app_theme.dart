import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// نظام الثيم الموحد لتطبيق نصيبك — Naseebak (UX Pilot Design System)
/// يعتمد خط Cairo العربي المتميز للأجهزة المحمولة مع التدرج الاحتياطي IBM Plex Sans Arabic
/// والألوان الفاخرة: الأزرق الملكي (#184A8C)، الكحلي (#123D6A)، والذهبي (#E8B44D).
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Cairo';
  static const List<String> fontFamilyFallback = [
    'IBMPlexSansArabic',
    'Cairo',
    'Arial',
    'sans-serif',
  ];

  static ThemeData get lightTheme {
    const baseTextStyle = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      color: AppColors.textPrimary,
      height: 1.45,
    );

    final textTheme = TextTheme(
      displayLarge: baseTextStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      displayMedium: baseTextStyle.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineLarge: baseTextStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: baseTextStyle.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextStyle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.6,
      ),
      bodyMedium: baseTextStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
      ),
      bodySmall: baseTextStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      labelLarge: baseTextStyle.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.softBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        secondary: AppColors.goldAccent,
        onSecondary: AppColors.primaryNavy,
        tertiary: AppColors.primaryNavy,
        surface: AppColors.cardWhite,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.subtleBorder,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(54),
          elevation: 2,
          shadowColor: AppColors.primaryBlue.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          backgroundColor: AppColors.cardWhite,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: BorderSide(
            color: AppColors.primaryBlue.withOpacity(0.28),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.subtleBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.subtleBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.3),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardWhite,
        selectedColor: AppColors.primaryBlue,
        secondarySelectedColor: AppColors.primaryBlue,
        side: const BorderSide(color: AppColors.subtleBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.subtleBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardWhite,
        indicatorColor: AppColors.surfaceSubtleBlue,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
          );
        }),
      ),
    );
  }
}

/// Alias for centralized design system nomenclature
typedef NaseebakTheme = AppTheme;
