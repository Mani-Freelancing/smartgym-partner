import 'package:flutter/material.dart';

class AppTheme {
  // Sleek Charcoal Slate Palette (Balanced Dark, not pitch black)
  static const Color scaffoldBg = Color(0xFF12151C);
  static const Color cardSurface = Color(0xFF1B1F29);
  static const Color cardElevated = Color(0xFF242936);
  static const Color accent = Color(0xFF00E676);
  static const Color ownerGold = Color(0xFFE5C158);
  static const Color trainerCyan = Color(0xFF3FA697);
  static const Color trainerOrange = Color(0xFF3FA697);
  static const Color champagne = Color(0xFFE5C158);
  static const Color emerald = Color(0xFF00E676);
  static const Color amber = Color(0xFFFFB300);
  static const Color purple = Color(0xFFA78BFA);
  static const Color danger = Color(0xFFFF453A);
  static const Color softRed = Color(0xFFFF6B6B);

  static ThemeData get lightTheme => darkTheme;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: champagne,
        surface: cardSurface,
      ),
      dividerColor: const Color(0x14FFFFFF),
      useMaterial3: true,
    );
  }
}

class AppPalette {
  final bool isDark;
  const AppPalette([this.isDark = true]);

  Color get bg => AppTheme.scaffoldBg;
  Color get card => AppTheme.cardSurface;
  Color get cardSubtle => AppTheme.cardElevated;
  Color get navBar => const Color(0xFF0D0F14);
  Color get border => const Color(0x18FFFFFF);
  Color get textPrimary => Colors.white;
  Color get textSecondary => const Color(0xFF94A3B8);
  Color get textMuted => const Color(0xFF64748B);
  Color get accent => AppTheme.accent;
  List<BoxShadow> get cardShadow => const [];
}
