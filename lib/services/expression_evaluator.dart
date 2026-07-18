import 'dart:math' as math;

/// Result of evaluating an expression: either a formatted numeric string
/// or an error flag, so the UI can show "Error" without crashing.
class EvalResult {
  final String display;
  final bool isError;
  const EvalResult(this.display, {this.isError = false});
}

/// A small, dependency-free recursive-descent parser/evaluator for
/// calculator expressions.
///
/// This replaces a previous implementation built on the `math_expressions`
/// package, which had two real correctness bugs: `%` has no defined
/// meaning in that library at all (every percent calculation simply
/// errored), and there was no guarantee its `log`/`ln` matched calculator
/// convention (base-10 vs. natural log) — so results could be silently
/// wrong even when they didn't throw. Writing this by hand fixes both,
/// gives full control over degree-based trig, and drops an external
/// dependency (smaller, faster build).
class ExpressionEvaluator {
  static EvalResult evaluate(String rawExpression) {
    if (rawExpression.trim().isEmpty) {
      return const EvalResult('');
    }
    try {
      final withPercent = _resolvePercent(rawExpression);
      final balanced = _autoBalanceParens(withPercent);
      final tokens = _Lexer(balanced).tokenize();
      final parser = _Parser(tokens);
      final value = parser.parseExpression();
      parser.expectEnd();

      if (value.isNaN || value.isInfinite) {
        return const EvalResult('Error', isError: true);
      }
      return EvalResult(_format(value));
    } catch (_) {
      return const EvalResult('Error', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Percent resolution — done as a string-level rewrite before tokenizing,
  // since '%' has no single universal mathematical meaning; calculator
  // apps define it contextually:
  //
  //   "A + B%" / "A - B%"  ->  B% is taken *of A*   (100+10% = 110)
  //   "A × B%" / "A ÷ B%"  ->  B% is just B/100     (50×10% = 5)
  //   a bare "B%" with nothing before it            -> B/100
  //
  // This matches standard Android/iOS calculator behavior for the common
  // single-percent case. A chained percent (e.g. "10%+5%") falls back to
  // bare B/100 semantics for the second term, since "percent of a
  // percent" isn't consistently defined even across real calculator apps.
  // Likewise, percent is only resolved against an immediately preceding
  // *numeric literal* (not an arbitrary sub-expression like "sin(30)%"),
  // matching the scope real calculator apps support.
  // ---------------------------------------------------------------------
  static String _resolvePercent(String expr) {
    var result = expr;
    var guard = 0;
    while (result.contains('%') && guard < 50) {
      guard++;
      final percentIndex = result.indexOf('%');

      int bStart = percentIndex;
      while (bStart > 0 && _isNumChar(result[bStart - 1])) {
        bStart--;
      }
      if (bStart == percentIndex) {
        // Stray '%' with no number before it (e.g. pressed on an empty
        // expression) — drop it rather than let it crash the parse.
        result = result.replaceRange(percentIndex, percentIndex + 1, '');
        continue;
      }
      final bStr = result.substring(bStart, percentIndex);

      int aStart = -1, aEnd = -1;
      final opIndex = bStart - 1;
      if (opIndex >= 0 &&
          (result[opIndex] == '+' || result[opIndex] == '-')) {
        aEnd = opIndex;
        aStart = aEnd;
        while (aStart > 0 && _isNumChar(result[aStart - 1])) {
          aStart--;
        }
      }

      final String replacement;
      if (aStart >= 0 && aStart < aEnd) {
        final aStr = result.substring(aStart, aEnd);
        replacement = '($aStr*($bStr/100))';
      } else {
        replacement = '($bStr/100)';
      }
      result = result.replaceRange(bStart, percentIndex + 1, replacement);
    }
    return result;
  }

  static bool _isNumChar(String c) =>
      (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) || c == '.';

  /// Auto-closes any unmatched '(' so a live/partial expression (while
  /// the user is still typing) can still show a preview result.
  static String _autoBalanceParens(String expr) {
    final opens = '('.allMatches(expr).length;
    final closes = ')'.allMatches(expr).length;
    if (opens > closes) {
      return expr + (')' * (opens - closes));
    }
    return expr;
  }

  /// Formats a double for calculator display: trims trailing zeros,
  /// absorbs floating-point noise near whole numbers (e.g. the
  /// 1.9999999999999998 that `log(100)` can produce), and falls back to
  /// exponential notation only for magnitudes too large/small to show
  /// plainly.
  static String _format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    String s = value.toStringAsPrecision(10);
    if (s.contains('e')) {
      return value.toStringAsExponential(4);
    }
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}

// ===========================================================================
// Lexer
// ===========================================================================

enum _TokType {
  number,
  plus,
  minus,
  star,
  slash,
  caret,
  lparen,
  rparen,
  ident,
  end,
}

class _Token {
  final _TokType type;
  final String text;
  final double? value;
  _Token(this.type, this.text, [this.value]);
}

class _Lexer {
  final String src;
  int _pos = 0;
  _Lexer(this.src);

  List<_Token> tokenize() {
    final tokens = <_Token>[];
    while (_pos < src.length) {
      final c = src[_pos];
      if (c == ' ') {
        _pos++;
        continue;
      }
      if (_isDigit(c) || c == '.') {
        tokens.add(_readNumber());
        continue;
      }
      if (_isAlpha(c)) {
        tokens.add(_readIdent());
        continue;
      }
      switch (c) {
        case '+':
          tokens.add(_Token(_TokType.plus, '+'));
          _pos++;
          break;
        case '-':
          tokens.add(_Token(_TokType.minus, '-'));
          _pos++;
          break;
        case '×':
        case '*':
          tokens.add(_Token(_TokType.star, '*'));
          _pos++;
          break;
        case '÷':
        case '/':
          tokens.add(_Token(_TokType.slash, '/'));
          _pos++;
          break;
        case '^':
          tokens.add(_Token(_TokType.caret, '^'));
          _pos++;
          break;
        case '(':
          tokens.add(_Token(_TokType.lparen, '('));
          _pos++;
          break;
        case ')':
          tokens.add(_Token(_TokType.rparen, ')'));
          _pos++;
          break;
        case 'π':
          tokens.add(_Token(_TokType.number, 'π', math.pi));
          _pos++;
          break;
        default:
          throw FormatException('Unexpected character: $c');
      }
    }

    // Insert implicit multiplication for adjacent tokens like "2π",
    // "2(3+4)", "2sin(30)", "(2+3)(4+5)" — real calculators generally
    // accept these without requiring an explicit '×'.
    final withImplicitMul = <_Token>[];
    for (var i = 0; i < tokens.length; i++) {
      if (i > 0) {
        final prev = tokens[i - 1];
        final cur = tokens[i];
        final prevEndsValue =
            prev.type == _TokType.number || prev.type == _TokType.rparen;
        final curStartsValue = cur.type == _TokType.number ||
            cur.type == _TokType.lparen ||
            cur.type == _TokType.ident;
        if (prevEndsValue && curStartsValue) {
          withImplicitMul.add(_Token(_TokType.star, '*'));
        }
      }
      withImplicitMul.add(tokens[i]);
    }
    withImplicitMul.add(_Token(_TokType.end, ''));
    return withImplicitMul;
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool _isAlpha(String c) => RegExp(r'[a-zA-Z]').hasMatch(c);

  _Token _readNumber() {
    final start = _pos;
    var sawDot = false;
    while (_pos < src.length &&
        (_isDigit(src[_pos]) || (src[_pos] == '.' && !sawDot))) {
      if (src[_pos] == '.') sawDot = true;
      _pos++;
    }
    final text = src.substring(start, _pos);
    return _Token(_TokType.number, text, double.parse(text));
  }

  _Token _readIdent() {
    final start = _pos;
    while (_pos < src.length && _isAlpha(src[_pos])) {
      _pos++;
    }
    return _Token(_TokType.ident, src.substring(start, _pos));
  }
}

// ===========================================================================
// Recursive-descent parser + direct evaluator.
//
// Grammar (highest to lowest binding), chosen deliberately so unary
// minus binds *looser* than power — matching real scientific-calculator
// convention where "-2^2" evaluates to -4, not 4 (typing "(-2)^2"
// explicitly is what gives 4):
//
//   primary    := NUMBER | 'π' | IDENT '(' expression ')' | '(' expression ')'
//   power      := primary ('^' unary)?      // right-associative
//   unary      := '-' unary | '+' unary | power
//   term       := unary (('*' | '/') unary)*
//   expression := term (('+' | '-') term)*
// ===========================================================================

class _Parser {
  final List<_Token> tokens;
  int _pos = 0;
  _Parser(this.tokens);

  _Token get _current => tokens[_pos];

  void expectEnd() {
    if (_current.type != _TokType.end) {
      throw const FormatException('Unexpected trailing input');
    }
  }

  double parseExpression() {
    var value = _parseTerm();
    while (_current.type == _TokType.plus || _current.type == _TokType.minus) {
      final isPlus = _current.type == _TokType.plus;
      _pos++;
      final rhs = _parseTerm();
      value = isPlus ? value + rhs : value - rhs;
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseUnary();
    while (_current.type == _TokType.star || _current.type == _TokType.slash) {
      final isMul = _current.type == _TokType.star;
      _pos++;
      final rhs = _parseUnary();
      if (!isMul && rhs == 0) {
        throw const FormatException('Division by zero');
      }
      value = isMul ? value * rhs : value / rhs;
    }
    return value;
  }

  double _parseUnary() {
    if (_current.type == _TokType.minus) {
      _pos++;
      return -_parseUnary();
    }
    if (_current.type == _TokType.plus) {
      _pos++;
      return _parseUnary();
    }
    return _parsePower();
  }

  double _parsePower() {
    final base = _parsePrimary();
    if (_current.type == _TokType.caret) {
      _pos++;
      final exponent = _parseUnary(); // right-assoc; allows e.g. "2^-3"
      final result = math.pow(base, exponent);
      return result is double ? result : result.toDouble();
    }
    return base;
  }

  double _parsePrimary() {
    final tok = _current;
    if (tok.type == _TokType.number) {
      _pos++;
      return tok.value!;
    }
    if (tok.type == _TokType.lparen) {
      _pos++;
      final value = parseExpression();
      _expect(_TokType.rparen);
      return value;
    }
    if (tok.type == _TokType.ident) {
      _pos++;
      _expect(_TokType.lparen);
      final arg = parseExpression();
      _expect(_TokType.rparen);
      return _applyFunction(tok.text, arg);
    }
    throw FormatException('Unexpected token: "${tok.text}"');
  }

  void _expect(_TokType type) {
    if (_current.type != type) {
      throw FormatException('Expected $type, got ${_current.type}');
    }
    _pos++;
  }

  double _applyFunction(String name, double arg) {
    switch (name) {
      case 'sin':
        return math.sin(arg * math.pi / 180);
      case 'cos':
        return math.cos(arg * math.pi / 180);
      case 'tan':
        final rad = arg * math.pi / 180;
        // Guard the asymptotes (90°, 270°, ...) rather than returning a
        // huge, meaningless float that looks like a "successful" result.
        if (math.cos(rad).abs() < 1e-10) {
          throw const FormatException('tan undefined at this angle');
        }
        return math.tan(rad);
      case 'log':
        if (arg <= 0) throw const FormatException('log domain error');
        return math.log(arg) / math.ln10; // base-10, as on a real calculator
      case 'ln':
        if (arg <= 0) throw const FormatException('ln domain error');
        return math.log(arg); // natural log
      case 'sqrt':
        if (arg < 0) throw const FormatException('sqrt domain error');
        return math.sqrt(arg);
      default:
        throw FormatException('Unknown function: $name');
    }
  }
}
