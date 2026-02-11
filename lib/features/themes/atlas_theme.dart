// lib/theme/atlas_theme.dart
import 'package:flutter/material.dart';
import '../../app/screens/landing_screen.dart';


class AtlasTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    return base.copyWith(
      scaffoldBackgroundColor: AtlasPalette.background,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 44,
          height: 1.00,
          color: AtlasPalette.primaryText,
          letterSpacing: -0.2,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          height: 1.35,
          color: AtlasPalette.primaryText,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.35,
          color: AtlasPalette.secondaryText,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          height: 1.1,
        ),
      ),
    );
  }
}
