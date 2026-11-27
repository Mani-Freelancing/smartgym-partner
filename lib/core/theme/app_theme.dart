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

  // Warm Cream-Porcelain & Rich Golden-Amber Executive Palette for Owner Portal
  static const Color lightScaffoldBg = Color(0xFFFAF7F2);
  static const Color lightCardSurface = Color(0xFFFFFFFF);
  static const Color lightCardSubtle = Color(0xFFFFF6E5);
  static const Color lightOwnerGold = Color(0xFFD98A16);
  static const Color lightOwnerGoldButton = Color(0xFFD98A16);
  static const Color lightAccent = Color(0xFF16A34A);
  static const Color lightCyan = Color(0xFFB87314);
  static const Color lightAmber = Color(0xFFD97706);
  static const Color lightDanger = Color(0xFFDC2626);
  static const Color lightPurple = Color(0xFF8B5CF6);

  /// Compact Dark-Gold Collections Banner tokens (used ONLY on compact top summary card).
  static const Color heroChampagneGold = Color(0xFFF3B43F);
  static const Color heroObsidianStart = Color(0xFF2B2317);
  static const Color heroObsidianMid = Color(0xFF1F1A13);
  static const Color heroObsidianEnd = Color(0xFF17140F);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScaffoldBg,
      colorScheme: const ColorScheme.light(
        primary: lightOwnerGold,
        secondary: lightCyan,
        surface: lightCardSurface,
        surfaceTint: Colors.transparent,
        onSurface: Color(0xFF1C1917),
        error: lightDanger,
      ),
      cardTheme: const CardThemeData(
        color: lightCardSurface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightScaffoldBg,
        foregroundColor: Color(0xFF1C1917),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: lightCardSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCardSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: const Color(0xFFF0E8DA),
      useMaterial3: true,
      extensions: const [AppPalette.light],
    );
  }

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
      extensions: const [AppPalette.dark],
    );
  }

  static Widget ensureOwnerLight(
    BuildContext context, {
    required Widget child,
  }) {
    if (Theme.of(context).extension<AppPalette>()?.isDark == false) {
      return child;
    }
    return Theme(data: lightTheme, child: child);
  }
}

class AppPalette extends ThemeExtension<AppPalette> {
  final bool isDark;
  final Color bg;
  final Color card;
  final Color cardSubtle;
  final Color navBar;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color gold;
  final Color goldButton;
  final Color cyan;
  final Color amber;
  final Color danger;
  final Color purple;
  final Color onAccent;
  final Color snackBg;

  const AppPalette({
    this.isDark = true,
    this.bg = AppTheme.scaffoldBg,
    this.card = AppTheme.cardSurface,
    this.cardSubtle = AppTheme.cardElevated,
    this.navBar = const Color(0xFF0D0F14),
    this.border = const Color(0x18FFFFFF),
    this.divider = const Color(0x14FFFFFF),
    this.textPrimary = Colors.white,
    this.textSecondary = const Color(0xB3FFFFFF),
    this.textMuted = const Color(0x61FFFFFF),
    this.accent = AppTheme.accent,
    this.gold = AppTheme.ownerGold,
    this.goldButton = AppTheme.ownerGold,
    this.cyan = AppTheme.trainerCyan,
    this.amber = AppTheme.amber,
    this.danger = AppTheme.softRed,
    this.purple = AppTheme.purple,
    this.onAccent = Colors.black,
    this.snackBg = const Color(0xFF1A1E29),
  });

  static const AppPalette dark = AppPalette();

  static const AppPalette light = AppPalette(
    isDark: false,
    bg: AppTheme.lightScaffoldBg,
    card: AppTheme.lightCardSurface,
    cardSubtle: AppTheme.lightCardSubtle,
    navBar: Colors.white,
    border: Color(0xFFEDE4D3),
    divider: Color(0xFFF2ECE1),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF57534E),
    textMuted: Color(0xFF8A8275),
    accent: AppTheme.lightAccent,
    gold: AppTheme.lightOwnerGold,
    goldButton: AppTheme.lightOwnerGoldButton,
    cyan: AppTheme.lightCyan,
    amber: AppTheme.lightAmber,
    danger: AppTheme.lightDanger,
    purple: AppTheme.lightPurple,
    onAccent: Colors.white,
    snackBg: Color(0xFF292524),
  );

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ?? dark;
  }

  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF9A6B16).withValues(alpha: 0.055),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ];

  @override
  AppPalette copyWith({bool? isDark}) =>
      (isDark ?? this.isDark) ? dark : light;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}
