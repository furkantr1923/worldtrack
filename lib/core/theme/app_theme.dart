import 'package:flutter/material.dart';

/// WORLDTRACK renk sistemi: okyanus mavisi, atlas yeşili ve gün batımı turuncusu.
class WtColors {
  WtColors._();

  static const Color brand = Color(0xFF0E7C86); // atlas yeşili-mavisi
  static const Color brandDeep = Color(0xFF0A3D62); // derin okyanus
  static const Color sunset = Color(0xFFF2994A); // planlanan
  static const Color coral = Color(0xFFE85D4A); // seçili / vurgu
  static const Color visited = Color(0xFF14A38B); // ziyaret edildi

  // Harita (açık tema)
  static const Color oceanLight = Color(0xFFDCEBF3);
  static const Color landLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFB4C6D3);
  // Harita (koyu tema)
  static const Color oceanDark = Color(0xFF0B1A2B);
  static const Color landDark = Color(0xFF1B2B42);
  static const Color borderDark = Color(0xFF34496A);

  static Color ocean(Brightness b) => b == Brightness.dark ? oceanDark : oceanLight;
  static Color land(Brightness b) => b == Brightness.dark ? landDark : landLight;
  static Color border(Brightness b) => b == Brightness.dark ? borderDark : borderLight;
}

class AppTheme {
  AppTheme._();

  static const String font = 'Poppins';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: WtColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF4FC3C9) : WtColors.brand,
      secondary: WtColors.sunset,
      tertiary: WtColors.coral,
      surface: isDark ? const Color(0xFF0F1A2B) : const Color(0xFFF6F8FB),
      surfaceContainerLowest: isDark ? const Color(0xFF0B1423) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF142238) : Colors.white,
      surfaceContainer: isDark ? const Color(0xFF182840) : const Color(0xFFEFF3F7),
      surfaceContainerHigh: isDark ? const Color(0xFF1D3049) : const Color(0xFFE7EDF3),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
    );

    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    final radius = BorderRadius.circular(14);
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Not: ThemeData.textTheme boyutları sonradan eklendiği için burada açıkça verilir.
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder:
            OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: font,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
          fontSize: 14,
        ),
        unselectedLabelTextStyle: TextStyle(fontFamily: font, color: scheme.onSurfaceVariant, fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w500, fontSize: 14, color: scheme.onSurface),
        secondaryLabelStyle:
            TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 14, color: scheme.onSecondaryContainer),
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        checkmarkColor: scheme.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      }),
    );
  }
}
