// lib/app/widgets/app_background.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';


class AppBackground extends StatelessWidget {
  final Widget child;
  final Widget? overlay; // optional extra overlay if you ever need it
  const AppBackground({super.key, required this.child, this.overlay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imgs = theme.extension<BackgroundImages>();
    final isDark = theme.brightness == Brightness.dark;
    final asset = isDark ? imgs?.darkAsset : imgs?.lightAsset;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fallback: plain color/gradient when no asset is configured
        if (asset == null) Container(color: theme.colorScheme.surface),

        if (asset != null)
          // The image itself
          Image.asset(
            asset,
            fit: imgs?.fit ?? BoxFit.cover,
          ),

        // Soft scrim to guarantee contrast for text/content (tuned per theme)
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.black.withOpacity(0.20),
                        Colors.black.withOpacity(0.40),
                      ]
                    : [
                        Colors.white.withOpacity(0.06),
                        Colors.white.withOpacity(0.10),
                      ],
              ),
            ),
          ),
        ),

        // Optional extra overlay (blur, vignette, etc.)
        if (overlay != null) overlay!,

        // Your page content
        child,
      ],
    );
  }
}
