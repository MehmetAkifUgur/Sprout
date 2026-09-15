import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const seed = Color(0xFF3F8F4F);
  static const leaf = Color(0xFF4CAF50);
  static const leafDark = Color(0xFF2E7D32);
  static const stem = Color(0xFF558B2F);
  static const wilted = Color(0xFF9C8A55);
  static const soil = Color(0xFF5D4037);
  static const pot = Color(0xFFC8693F);
  static const potRim = Color(0xFFB05A33);
  static const bark = Color(0xFF795548);
  static const missed = Color(0xFFE57373);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F8F2)
          : scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
