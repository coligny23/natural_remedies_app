// lib/app/widgets/app_background.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final String asset; // e.g. 'assets/bg/leaves.jpg'
  const AppBackground({super.key, required this.child, required this.asset});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        // soften + tint to preserve contrast
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: isDark
                  ? Colors.black.withOpacity(0.35)
                  : Colors.white.withOpacity(0.30),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
