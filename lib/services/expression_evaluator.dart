import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';

/// Result of evaluating an expression: either a formatted numeric string
/// or an error flag, so the UI can show "Error" without crashing.
class EvalResult {
  final String display;
  final bool isError;
  const EvalResult(this.display, {this.isError = false});
}

/// Wraps `math_expressions` to evaluate calculator expressions, mirroring
/// the role exp4j plays in the native Android spec. Supports the standard
/// operators plus scientific functions: sin, cos, tan, log, ln, sqrt,
/// power (^), and parentheses.
///
/// Trig functions operate in degrees to match calculator-app conventions;
/// they are converted to radians internally before evaluation.
class ExpressionEvaluator {
  static final Parser _parser = Parser();

  /// Evaluates a raw calculator expression string (as typed by the user,
  /// e.g. "sin(30) + 2^3") and returns a formatted result or an error.
  static EvalResult evaluate(String rawExpression) {
    if (rawExpression.trim().isEmpty) {
      return const EvalResult('');
    }
    try {
      final normalized = _normalize(rawExpression);
      final exp = _parser.parse(normalized);
      final value = exp.evaluate(EvaluationType.REAL, ContextModel());

      if (value.isNaN || value.isInfinite) {
        return const EvalResult('Error', isError: true);
      }
      return EvalResult(_format(value));
    } catch (_) {
      return const EvalResult('Error', isError: true);
    }
  }

  /// Converts calculator-friendly syntax into syntax `math_expressions`
  /// understands, and rewrites degree-based trig calls into their
  /// radian equivalents (since math_expressions' trig functions use
  /// radians natively).
  static String _normalize(String input) {
    var expr = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('π', '(${math.pi})')
        .replaceAll('√', 'sqrt');

    // Rewrite sin(x), cos(x), tan(x) in degrees -> sin(x * pi / 180), etc.
    expr = _rewriteDegreeTrig(expr, 'sin');
    expr = _rewriteDegreeTrig(expr, 'cos');
    expr = _rewriteDegreeTrig(expr, 'tan');

    // Auto-balance any missing closing parentheses so a live/partial
    // expression (e.g. while the user is still typing) can still preview.
    final opens = '('.allMatches(expr).length;
    final closes = ')'.allMatches(expr).length;
    if (opens > closes) {
      expr = expr + (')' * (opens - closes));
    }
    return expr;
  }

  /// Finds `fn(...)` calls for the given function name and wraps the
  /// inner argument with `* pi / 180` so degrees are used at the call
  /// site, e.g. `sin(30)` -> `sin(30 * pi/180)`.
  static String _rewriteDegreeTrig(String expr, String fn) {
    final pattern = RegExp('$fn\\(');
    final buffer = StringBuffer();
    int cursor = 0;
    for (final match in pattern.allMatches(expr)) {
      buffer.write(expr.substring(cursor, match.start));
      final argStart = match.end;
      final argEnd = _matchingParen(expr, argStart - 1);
      if (argEnd == -1) {
        // Unbalanced; leave the rest as-is.
        buffer.write(expr.substring(match.start));
        cursor = expr.length;
        break;
      }
      final inner = expr.substring(argStart, argEnd);
      buffer.write('$fn(($inner) * pi / 180)');
      cursor = argEnd + 1;
    }
    buffer.write(expr.substring(cursor));
    return buffer.toString();
  }

  static int _matchingParen(String s, int openIndex) {
    int depth = 0;
    for (int i = openIndex; i < s.length; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Formats a double for calculator display: trims trailing zeros,
  /// avoids scientific notation for common magnitudes, and caps
  /// decimal precision so results don't overflow the display.
  static String _format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    String s = value.toStringAsPrecision(10);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
