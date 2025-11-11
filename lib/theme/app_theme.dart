// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Pick a lively brand color that also works in dark mode.
  // You can tweak to your taste (e.g., Colors.teal, Colors.green, etc.)
  static const _brand = Color(0xFF1EA37A); // fresh green-teal
  static const _brandAlt = Color(0xFF5B7CFF); // accent blue for tertiary

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
    ).copyWith(
      tertiary: _brandAlt,
      surface: const Color(0xFFF8FAFC),
      surfaceContainerHighest: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      chipTheme: ChipThemeData(
        shape: StadiumBorder(),
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        backgroundColor: scheme.secondaryContainer,
        selectedColor: scheme.primaryContainer,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: .1),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.dark,
    ).copyWith(
      tertiary: _brandAlt,
      surface: const Color(0xFF0F1216),
      surfaceContainerHighest: const Color(0xFF171B21),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      chipTheme: ChipThemeData(
        shape: StadiumBorder(),
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        backgroundColor: scheme.secondaryContainer.withOpacity(.35),
        selectedColor: scheme.primaryContainer.withOpacity(.45),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: .1),
      ),
    );
  }
}
