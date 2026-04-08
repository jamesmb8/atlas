// lib/features/themes/atlas_theme.dart
import 'package:flutter/material.dart';

@immutable
class AtlasPalette extends ThemeExtension<AtlasPalette> {
  final Color brandPrimary;
  final Color brandSecondary;
  final Color brandTertiary;
  final Color brandHighlight;

  final Color background;
  final Color surface;
  final Color surfaceFeatured;

  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color danger;

  const AtlasPalette({
    required this.brandPrimary,
    required this.brandSecondary,
    required this.brandTertiary,
    required this.brandHighlight,
    required this.background,
    required this.surface,
    required this.surfaceFeatured,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.danger,
  });

  static const light = AtlasPalette(
    brandPrimary: Color(0xFF346739),
    brandSecondary: Color(0xFF79AE6F),
    brandTertiary: Color(0xFF9FCB98),
    brandHighlight: Color(0xFFF2EDC2),
    background: Color(0xFFF7F6F2),
    surface: Color(0xFFFFFFFF),
    surfaceFeatured: Color(0xFFEAF4E7),
    textPrimary: Color(0xFF1F1F1F),
    textSecondary: Color(0xFF6B6E6A),
    border: Color(0xFFE3E4DE),
    danger: Color(0xFFB3261E),
  );

  @override
  AtlasPalette copyWith({
    Color? brandPrimary,
    Color? brandSecondary,
    Color? brandTertiary,
    Color? brandHighlight,
    Color? background,
    Color? surface,
    Color? surfaceFeatured,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? danger,
  }) {
    return AtlasPalette(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      brandTertiary: brandTertiary ?? this.brandTertiary,
      brandHighlight: brandHighlight ?? this.brandHighlight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceFeatured: surfaceFeatured ?? this.surfaceFeatured,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      danger: danger ?? this.danger,
    );
  }

  @override
  AtlasPalette lerp(ThemeExtension<AtlasPalette>? other, double t) {
    if (other is! AtlasPalette) {
      return this;
    }

    return AtlasPalette(
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t) ?? brandPrimary,
      brandSecondary: Color.lerp(brandSecondary, other.brandSecondary, t) ?? brandSecondary,
      brandTertiary: Color.lerp(brandTertiary, other.brandTertiary, t) ?? brandTertiary,
      brandHighlight: Color.lerp(brandHighlight, other.brandHighlight, t) ?? brandHighlight,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceFeatured: Color.lerp(surfaceFeatured, other.surfaceFeatured, t) ?? surfaceFeatured,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      border: Color.lerp(border, other.border, t) ?? border,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
    );
  }
}

class AtlasFonts {
  const AtlasFonts._();

  static const String display = 'LineSeedJP';
  static const String body = 'LineSeedJP';
}

class AtlasTheme {
  const AtlasTheme._();

  static ThemeData light() {
    const atlas = AtlasPalette.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: atlas.brandPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: atlas.brandPrimary,
      onPrimary: Colors.white,
      secondary: atlas.brandSecondary,
      onSecondary: atlas.textPrimary,
      surface: atlas.surface,
      onSurface: atlas.textPrimary,
      outline: atlas.border,
      error: atlas.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AtlasFonts.body,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontFamily: AtlasFonts.display,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      displayMedium: base.textTheme.displayMedium?.copyWith(
        fontFamily: AtlasFonts.display,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w800,
        height: 1.12,
      ),
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFamily: AtlasFonts.display,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.14,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: AtlasFonts.display,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.16,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontFamily: AtlasFonts.display,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: AtlasFonts.display,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: AtlasFonts.display,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.24,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.24,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textSecondary,
        fontWeight: FontWeight.w400,
        height: 1.35,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textSecondary,
        fontWeight: FontWeight.w400,
        height: 1.2,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontFamily: AtlasFonts.body,
        color: atlas.textSecondary,
        fontWeight: FontWeight.w400,
        height: 1.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: AtlasFonts.body,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: atlas.background,
      canvasColor: atlas.background,
      cardColor: atlas.surface,
      dividerColor: atlas.border,
      splashColor: atlas.brandSecondary.withOpacity(0.08),
      highlightColor: atlas.brandTertiary.withOpacity(0.08),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: atlas.brandPrimary,
        circularTrackColor: atlas.brandTertiary.withOpacity(0.24),
        linearTrackColor: atlas.brandTertiary.withOpacity(0.24),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: atlas.background,
        foregroundColor: atlas.textPrimary,
        elevation: 0,
        surfaceTintColor: atlas.background,
        centerTitle: false,
        iconTheme: IconThemeData(color: atlas.textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontFamily: AtlasFonts.display,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: atlas.textPrimary,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: atlas.brandPrimary,
        selectionColor: atlas.brandTertiary.withOpacity(0.35),
        selectionHandleColor: atlas.brandPrimary,
      ),
      iconTheme: IconThemeData(
        color: atlas.textPrimary,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: atlas.textPrimary,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: atlas.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: atlas.brandPrimary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: atlas.brandPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: atlas.brandTertiary.withOpacity(0.18),
        selectedColor: atlas.brandSecondary.withOpacity(0.2),
        disabledColor: atlas.border,
        secondarySelectedColor: atlas.brandSecondary.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelMedium?.copyWith(color: atlas.textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: atlas.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: atlas.border),
        ),
        side: BorderSide(color: atlas.border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: atlas.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: atlas.textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: atlas.textSecondary),
        prefixIconColor: atlas.textSecondary,
        suffixIconColor: atlas.textSecondary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: atlas.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: atlas.brandPrimary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: atlas.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: atlas.danger, width: 1.4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: atlas.border,
        thickness: 1,
        space: 1,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AtlasPalette.light,
      ],
    );
  }
}

extension AtlasThemeContext on BuildContext {
  AtlasPalette get atlas => Theme.of(this).extension<AtlasPalette>()!;
}