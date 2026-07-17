import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Material 3 theming for CalcBook. Uses a deep indigo/violet
/// seed for a premium, modern feel, with a display-oriented font for the
/// calculator readout and a clean grotesk for UI chrome.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF5B5FEF);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.jetBrainsMono(
        fontSize: 56,
        fontWeight: FontWeight.w300,
        letterSpacing: -1,
      ),
      displayMedium: GoogleFonts.jetBrainsMono(
        fontSize: 34,
        fontWeight: FontWeight.w400,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // Semantic button role colors used by CalcButton, resolved per-theme
  // so they adapt correctly to light/dark mode.
  static Color numberButton(ColorScheme s) => s.surfaceContainerHigh;
  static Color operatorButton(ColorScheme s) => s.primaryContainer;
  static Color functionButton(ColorScheme s) => s.secondaryContainer;
  static Color accentButton(ColorScheme s) => s.primary;

  /// Builds a status-bar / navigation-bar overlay style that matches the
  /// given scheme, so system chrome never looks mismatched against the
  /// app's current light/dark theme (e.g. dark status bar icons on a
  /// dark background, or a stray white nav bar in dark mode).
  static SystemUiOverlayStyle systemOverlayStyle(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: scheme.surface,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}
