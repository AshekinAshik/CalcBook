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
    // Build the base theme from the ColorScheme *first* — this is what
    // gives Flutter's own text theme correctly brightness-aware colors
    // (onSurface-derived, not a fixed black/white). The previous version
    // called `GoogleFonts.interTextTheme()` with no base argument, which
    // silently defaults to a fixed light-mode/black-text baseline no
    // matter the app's actual brightness — every Text widget that didn't
    // explicitly override its own color (dialog titles, drawer headers,
    // list content, etc.) was rendering near-black text even in dark
    // mode. Passing `base.textTheme` into GoogleFonts here fixes that at
    // the root: GoogleFonts only swaps the font family/weight and keeps
    // the color it's given.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.jetBrainsMono(
        fontSize: 56,
        fontWeight: FontWeight.w300,
        letterSpacing: -1,
        color: scheme.onSurface,
      ),
      displayMedium: GoogleFonts.jetBrainsMono(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
    );

    return base.copyWith(
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
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: scheme.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
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
