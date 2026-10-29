import 'package:flutter/material.dart';

class AppTheme {
  // Brand Palette:
  // #030407 - Deep Obsidian Background
  // #1558C9 - Electric Cobalt Accent / Primary
  // #D4FF24 - Cyber Lime High-Contrast Highlight
  static const Color background = Color(0xFF030407);
  static const Color surface = Color(0xFF0C0F17);
  static const Color surfaceLight = Color(0xFF141926);
  static const Color primary = Color(0xFF1558C9);
  static const Color accentLime = Color(0xFFD4FF24);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E95A5);
  static const Color divider = Color(0xFF1E2433);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentLime,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accentLime,
        unselectedItemColor: textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
