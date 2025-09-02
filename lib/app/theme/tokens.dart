// lib/app/theme/tokens.dart
import 'package:flutter/material.dart';

/// One place to change spacing, radius, color seeds, motion, etc.
class AppTokens {
  // Spacing (8-pt grid)
  static const s1 = 8.0;
  static const s2 = 16.0;
  static const s3 = 24.0;
  static const s4 = 32.0;

  // Radius
  static const rSm = 8.0;
  static const rMd = 12.0;
  static const rLg = 16.0;
  static const rXl = 20.0; // cards
  static const r2Xl = 24.0; // modals

  // Motion
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 220);

  // Color seed (pick one accent and keep it)
  static const seed = Color(0xFF0EA5A4); // teal-ish
}
