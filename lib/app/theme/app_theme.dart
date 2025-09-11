import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.seed,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
    );
    final text = _textTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      textTheme: text,

      // Accessibility defaults
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        minLeadingWidth: 24,
        dense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
          ),
        ),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.seed,
      brightness: Brightness.dark,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
    );
    final text = _textTheme(base.textTheme);

    return base.copyWith(
      textTheme: text,

      // Accessibility defaults
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        minLeadingWidth: 24,
        dense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
          ),
        ),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: Color(0xFF1C1C1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.rXl)),
        ),
      ),
    );
  }

  /// iOS uses SF system font; Android gets Inter to feel iOS-clean.
  static TextTheme _textTheme(TextTheme base) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return base.copyWith(
        headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: base.titleLarge?.copyWith(
            fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge:
            base.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      );
    }
    final inter = GoogleFonts.interTextTheme(base);
    return inter.copyWith(
      headlineMedium: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge:
          GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.45),
    );
  }
}
