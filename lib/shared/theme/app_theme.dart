import 'package:flutter/material.dart';

class SwimColors {
  SwimColors._();

  // Brand
  static const ocean = Color(0xFF0D1F3C);
  static const oceanLight = Color(0xFF1D3A6E);
  static const wave = Color(0xFF1D9E75);
  static const waveMuted = Color(0xFF0F6E56);
  static const foam = Color(0xFFE1F5EE);

  // Semantic
  static const danger = Color(0xFFE24B4A);
  static const dangerBg = Color(0xFF1A0A0A);
  static const warning = Color(0xFFEF9F27);
  static const heartRate = Color(0xFFE24B4A);
  static const calories = Color(0xFFEF9F27);
  static const waterBlue = Color(0xFF378ADD);

  // Neutrals (dark UI)
  static const surface = Color(0xFF0F2440);
  static const surfaceLight = Color(0xFF1A3050);
  static const border = Color(0xFF1A3050);
  static const textPrimary = Color(0xFFD0E4FF);
  static const textSecondary = Color(0xFF5A7FA8);
  static const textMuted = Color(0xFF3D5A7A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: SwimColors.ocean,
        colorScheme: const ColorScheme.dark(
          primary: SwimColors.wave,
          secondary: SwimColors.waterBlue,
          surface: SwimColors.surface,
          error: SwimColors.danger,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: SwimColors.ocean,
          foregroundColor: SwimColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: SwimColors.textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: SwimColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: SwimColors.border, width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SwimColors.wave,
            foregroundColor: SwimColors.foam,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: SwimColors.waterBlue,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w500,
            color: SwimColors.wave,
            letterSpacing: -2,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: SwimColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: SwimColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: SwimColors.textSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            color: SwimColors.textMuted,
            letterSpacing: 0.05,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: SwimColors.surface,
          indicatorColor: SwimColors.surfaceLight,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: SwimColors.textSecondary,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: SwimColors.border,
          thickness: 0.5,
        ),
      );

  // Light theme — minimal, car l'app est pensée dark
  static ThemeData get light => dark;
}
