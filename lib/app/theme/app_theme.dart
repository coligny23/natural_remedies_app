// lib/app/theme/app_theme.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class AppTheme {
  /// ---- LIGHT THEME ----
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.seed,
      brightness: Brightness.light,
    ).copyWith(
      // gentle, modern surfaces
      surface: const Color(0xFFF7F8FA),
      surfaceContainerHighest: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
    );
    final text = _textTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      // NEW: register theme extensions
      extensions: <ThemeExtension<dynamic>>[
        const AppElevations(small: 3, base: 8, high: 18, modal: 24),
        GlossyCardTheme.light(scheme),
        const BackgroundImages(
          lightAsset: 'assets/images/articles_jpg/imagetwo.jpg', // <- your light image
          darkAsset:  'assets/images/articles_jpg/imageone.jpg',  // safe to keep here too
          fit: BoxFit.cover,
          opacity: 1.0,
    ),
      ],

      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
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
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      // Cards (polished, “small but classy”)
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppTokens.rXl)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Chips look vibrant but readable
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        backgroundColor: scheme.secondaryContainer,
        selectedColor: scheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }

  /// ---- DARK THEME ----
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0F1216),
      surfaceContainerHighest: const Color(0xFF171B21),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
    );
    final text = _textTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      // NEW: register theme extensions
      extensions: <ThemeExtension<dynamic>>[
        const AppElevations(small: 3, base: 8, high: 18, modal: 24),
        GlossyCardTheme.dark(scheme),
        const BackgroundImages(
          lightAsset: 'assets/images/articles_jpg/imagetwo.jpg', // <- your light image
          darkAsset:  'assets/images/articles_jpg/imageone.jpg',  // safe to keep here too
          fit: BoxFit.cover,
          opacity: 0.95,
        )
      ],

      textTheme: text,
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
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppTokens.rXl)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        backgroundColor: scheme.secondaryContainer.withOpacity(.35),
        selectedColor: scheme.primaryContainer.withOpacity(.45),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }

  /// iOS uses SF system font; Android gets Inter for that clean feel.
  static TextTheme _textTheme(TextTheme base) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return base.copyWith(
        headlineMedium: base.headlineMedium?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      );
    }
    final inter = GoogleFonts.interTextTheme(base);
    return inter.copyWith(
      headlineMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.45),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               THEME EXTENSIONS                             */
/* -------------------------------------------------------------------------- */

@immutable
class AppElevations extends ThemeExtension<AppElevations> {
  final double small; // tiny decoration lifts
  final double base;  // default “card”
  final double high;  // hero cards / key accents
  final double modal; // drawers/overlays/fabs

  const AppElevations({
    required this.small,
    required this.base,
    required this.high,
    required this.modal,
  });

  @override
  AppElevations copyWith({double? small, double? base, double? high, double? modal}) {
    return AppElevations(
      small: small ?? this.small,
      base: base ?? this.base,
      high: high ?? this.high,
      modal: modal ?? this.modal,
    );
  }

  @override
  AppElevations lerp(ThemeExtension<AppElevations>? other, double t) {
    if (other is! AppElevations) return this;
    double _l(double a, double b) => a + (b - a) * t;
    return AppElevations(
      small: _l(small, other.small),
      base: _l(base, other.base),
      high: _l(high, other.high),
      modal: _l(modal, other.modal),
    );
    }
}

@immutable
class GlossyCardTheme extends ThemeExtension<GlossyCardTheme> {
  final Gradient headerGradient; // for “hero” headers
  final Color surface;           // card body surface
  final Color border;            // subtle outline
  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;
  final double blurSigma;        // used with BackdropFilter for glassy feel

  const GlossyCardTheme({
    required this.headerGradient,
    required this.surface,
    required this.border,
    required this.shadows,
    required this.borderRadius,
    required this.blurSigma,
  });

  factory GlossyCardTheme.light(ColorScheme s) => GlossyCardTheme(
        headerGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            s.primary.withOpacity(.14),
            s.tertiary.withOpacity(.10),
          ],
        ),
        surface: s.surfaceContainerHighest,
        border: s.outlineVariant,
        shadows: [
          BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
        borderRadius: const BorderRadius.all(Radius.circular(AppTokens.rXl)),
        blurSigma: 10,
      );

  factory GlossyCardTheme.dark(ColorScheme s) => GlossyCardTheme(
        headerGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            s.primary.withOpacity(.24),
            s.tertiary.withOpacity(.20),
          ],
        ),
        surface: s.surfaceContainerHighest,
        border: s.outlineVariant.withOpacity(.7),
        shadows: [
          BoxShadow(color: Colors.black.withOpacity(.24), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        borderRadius: const BorderRadius.all(Radius.circular(AppTokens.rXl)),
        blurSigma: 12,
      );

  @override
  GlossyCardTheme copyWith({
    Gradient? headerGradient,
    Color? surface,
    Color? border,
    List<BoxShadow>? shadows,
    BorderRadius? borderRadius,
    double? blurSigma,
  }) {
    return GlossyCardTheme(
      headerGradient: headerGradient ?? this.headerGradient,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      shadows: shadows ?? this.shadows,
      borderRadius: borderRadius ?? this.borderRadius,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  GlossyCardTheme lerp(ThemeExtension<GlossyCardTheme>? other, double t) {
    if (other is! GlossyCardTheme) return this;
    return this; // gradients/shadows don’t lerp nicely—keep simple.
  }

  /// Convenience: build a decoration for “glossy” bodies.
  BoxDecoration bodyDecoration() => BoxDecoration(
        color: surface,
        borderRadius: borderRadius,
        border: Border.all(color: border),
        boxShadow: shadows,
      );

  /// Convenience: header container with gradient and rounded top corners.
  BoxDecoration headerDecoration() => BoxDecoration(
        gradient: headerGradient,
        borderRadius: BorderRadius.only(
          topLeft: borderRadius.topLeft,
          topRight: borderRadius.topRight,
        ),
      );
}

@immutable
class BackgroundImages extends ThemeExtension<BackgroundImages> {
  final String? lightAsset;
  final String? darkAsset;
  final BoxFit fit;
  final double opacity; // apply a subtle opacity so content stays readable

  const BackgroundImages({
    this.lightAsset,
    this.darkAsset,
    this.fit = BoxFit.cover,
    this.opacity = 1.0,
  });

  @override
  BackgroundImages copyWith({
    String? lightAsset,
    String? darkAsset,
    BoxFit? fit,
    double? opacity,
  }) {
    return BackgroundImages(
      lightAsset: lightAsset ?? this.lightAsset,
      darkAsset: darkAsset ?? this.darkAsset,
      fit: fit ?? this.fit,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  BackgroundImages lerp(ThemeExtension<BackgroundImages>? other, double t) {
    if (other is! BackgroundImages) return this;
    return BackgroundImages(
      lightAsset: t < .5 ? lightAsset : other.lightAsset,
      darkAsset: t < .5 ? darkAsset : other.darkAsset,
      fit: fit,
      opacity: opacity + (other.opacity - opacity) * t,
    );
  }
}
