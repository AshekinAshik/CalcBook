import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The visual role of a button, which drives its color per Material 3
/// tonal conventions (numbers are neutral, operators are primary-tinted,
/// scientific functions are secondary-tinted, and '=' is a filled accent).
enum CalcButtonRole { number, operatorKey, function, accent, subtle }

/// A single calculator key. Designed to be placed inside an `Expanded`
/// cell (row/column) by its parent grid, so it always fills the space
/// it's given rather than forcing a fixed aspect ratio — this is what
/// lets the whole button grid adapt to any screen height without ever
/// needing to scroll. Enforces a comfortable minimum touch target via
/// generous internal padding, and gives a light haptic tap for a
/// premium, tactile feel.
class CalcButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final CalcButtonRole role;
  final double fontSize;
  final Widget? icon;

  const CalcButton({
    super.key,
    required this.label,
    required this.onTap,
    this.role = CalcButtonRole.number,
    this.fontSize = 24,
    this.icon,
  });

  Color _bg(ColorScheme s) {
    switch (role) {
      case CalcButtonRole.number:
        return s.surfaceContainerHigh;
      case CalcButtonRole.operatorKey:
        return s.primaryContainer;
      case CalcButtonRole.function:
        return s.secondaryContainer;
      case CalcButtonRole.accent:
        return s.primary;
      case CalcButtonRole.subtle:
        return s.surfaceContainerLow;
    }
  }

  Color _fg(ColorScheme s) {
    switch (role) {
      case CalcButtonRole.number:
        return s.onSurface;
      case CalcButtonRole.operatorKey:
        return s.onPrimaryContainer;
      case CalcButtonRole.function:
        return s.onSecondaryContainer;
      case CalcButtonRole.accent:
        return s.onPrimary;
      case CalcButtonRole.subtle:
        return s.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: _bg(scheme),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Center(
            child: icon ??
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: _fg(scheme),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
