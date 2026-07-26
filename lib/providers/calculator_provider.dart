import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../models/calculation_sheet.dart';
import '../models/calculation_history_entry.dart';
import '../services/expression_evaluator.dart';

/// The single source of truth for the active calculator state, the
/// list of saved Calculation Sheets, and the auto-logged Calculation
/// History. This is the MVVM "ViewModel" layer (Flutter's
/// `ChangeNotifier` stands in for Android's `ViewModel` + `StateFlow`).
class CalculatorProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  String _expression = '';
  String _liveResult = '';
  bool _isScientificMode = false;
  int? _activeSheetId; // non-null while a saved sheet is loaded & unsaved-clean
  List<CalculationSheet> _sheets = [];

  // All history rows (both general and every sheet's), kept in one small
  // in-memory cache — capped at [CalculationHistoryEntry.maxEntries], so
  // filtering it in memory per-scope (see [generalHistory]/[sheetHistory])
  // is cheap and avoids extra DB round-trips every time a drawer opens.
  List<CalculationHistoryEntry> _history = [];

  String get expression => _expression;
  String get liveResult => _liveResult;
  bool get isScientificMode => _isScientificMode;
  int? get activeSheetId => _activeSheetId;
  List<CalculationSheet> get sheets => List.unmodifiable(_sheets);

  /// History of calculations made outside any sheet ("free" mode).
  List<CalculationHistoryEntry> get generalHistory =>
      _history.where((h) => h.sheetId == null).toList();

  /// History of calculations made while a specific sheet was active.
  List<CalculationHistoryEntry> sheetHistory(int sheetId) =>
      _history.where((h) => h.sheetId == sheetId).toList();

  CalculatorProvider() {
    _loadSheets();
    _loadHistory();
  }

  Future<void> _loadSheets() async {
    try {
      _sheets = await _db.getAllSheets();
    } catch (e) {
      // Worst-case fallback: start with an empty list rather than crash
      // the whole app on launch over a DB-open failure. Sheets already
      // on disk aren't lost — this only affects the in-memory list for
      // this session; the next successful load picks them back up.
      debugPrint('CalcBook: failed to load sheets: $e');
      _sheets = [];
    }
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    try {
      _history = await _db.getAllHistory();
    } catch (e) {
      debugPrint('CalcBook: failed to load history: $e');
      _history = [];
    }
    notifyListeners();
  }

  void toggleScientificMode() {
    _isScientificMode = !_isScientificMode;
    notifyListeners();
  }

  /// Appends a token (digit, operator, function, parenthesis) to the
  /// live expression trail and re-evaluates the preview result.
  ///
  /// Two input-level guards keep the expression well-formed, matching
  /// standard calculator-app behavior:
  ///  - A second decimal point within the same number is ignored rather
  ///    than appended. Without this, something like "1.2.3" would reach
  ///    the parser as two adjacent number literals ("1.2" and ".3"),
  ///    which implicit multiplication support would silently turn into
  ///    "1.2 × 0.3" — a wrong *answer*, not just a rejected input, which
  ///    is worse than simply blocking the second '.' at entry time.
  ///  - Pressing ×, ÷, or ^ immediately after another operator replaces
  ///    the trailing one instead of stacking a second (e.g. "5+" then
  ///    tapping × corrects to "5×", not the dead-end "5+×"). + and − are
  ///    deliberately never *replaced by* this, nor do they ever trigger
  ///    replacing what came before them — they have valid unary/prefix
  ///    meaning in the grammar ("5×-3", "5^-3", "5^+3" are all
  ///    legitimate and already evaluate correctly), whereas ×, ÷, and ^
  ///    never do, so only *they* get this treatment.
  void appendToken(String token) {
    const nonUnaryOps = {'×', '÷', '^'};
    const replaceableTrailing = {'+', '-', '×', '÷', '^'};

    if (nonUnaryOps.contains(token) &&
        _expression.isNotEmpty &&
        replaceableTrailing.contains(_expression[_expression.length - 1])) {
      _expression = _expression.substring(0, _expression.length - 1) + token;
      _recompute();
      return;
    }

    if (token == '.' && _currentNumberHasDecimal()) {
      return;
    }

    _expression += token;
    _recompute();
  }

  /// Whether the number currently being typed (the run of digits back
  /// to the last operator/parenthesis/function) already contains a '.'.
  bool _currentNumberHasDecimal() {
    for (var i = _expression.length - 1; i >= 0; i--) {
      final c = _expression[i];
      if (c == '.') return true;
      final code = c.codeUnitAt(0);
      final isDigit = code >= 48 && code <= 57;
      if (!isDigit) break;
    }
    return false;
  }

  void backspace() {
    if (_expression.isEmpty) return;
    _expression = _expression.substring(0, _expression.length - 1);
    _recompute();
  }

  void clearAll() {
    _expression = '';
    _liveResult = '';
    // Deliberately does NOT touch _activeSheetId — "AC" clears the
    // display, nothing more. Exiting a sheet is its own explicit action
    // (the × on the sheet chip / exitActiveSheet()); AC silently doing
    // the same thing as a side effect would mean clearing a mistyped
    // number could unexpectedly detach you from the sheet you were
    // working in.
    notifyListeners();
  }

  /// Evaluates and "commits" the current expression, replacing it with
  /// its final result (standard calculator '=' behavior), and silently
  /// logs the calculation to History — scoped to whichever sheet is
  /// currently active, or to General history if none is.
  void evaluateEquals() {
    if (_expression.trim().isEmpty) return;
    final result = ExpressionEvaluator.evaluate(_expression);
    if (!result.isError && result.display.isNotEmpty) {
      final originalExpression = _expression;
      _expression = result.display;
      _liveResult = '';
      _logHistory(originalExpression, result.display);
    } else {
      _liveResult = 'Error';
    }
    notifyListeners();
  }

  Future<void> _logHistory(String expression, String result) async {
    // Skip logging trivial no-op entries like "5" -> "5".
    if (expression == result) return;
    final entry = CalculationHistoryEntry(
      expression: expression,
      result: result,
      timestamp: DateTime.now(),
      sheetId: _activeSheetId,
    );
    await _db.insertHistoryEntry(entry);
    _history = await _db.getAllHistory();
    notifyListeners();
  }

  void _recompute() {
    final result = ExpressionEvaluator.evaluate(_expression);
    _liveResult = result.isError ? '' : result.display;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Calculation Sheets — save / reload / edit / delete / reorder
  // ---------------------------------------------------------------------

  /// Saves the current live expression trail as a brand-new independent
  /// sheet ("Calculation Sheets" — the core innovation of the app).
  Future<void> saveCurrentAsNewSheet({String? title, String? description}) async {
    if (_expression.trim().isEmpty) return;
    final order = await _db.nextDisplayOrder();
    final sheet = CalculationSheet(
      title: title?.trim().isNotEmpty == true
          ? _clampTitle(title!.trim())
          : 'Sheet ${_sheets.length + 1}',
      description: _clampDescription(description),
      expression: _expression,
      displayOrder: order,
    );
    final saved = await _db.insertSheet(sheet);
    _sheets = [..._sheets, saved];
    _activeSheetId = saved.id;
    notifyListeners();
  }

  static String _clampTitle(String title) {
    if (title.length <= CalculationSheet.maxTitleLength) return title;
    return title.substring(0, CalculationSheet.maxTitleLength);
  }

  static String _clampDescription(String? description) {
    final trimmed = (description ?? '').trim();
    if (trimmed.length <= CalculationSheet.maxDescriptionLength) return trimmed;
    return trimmed.substring(0, CalculationSheet.maxDescriptionLength);
  }

  /// Reloads a saved sheet's expression back into the active calculator
  /// so the user can resume working on it.
  void reloadSheet(CalculationSheet sheet) {
    _expression = sheet.expression;
    _activeSheetId = sheet.id;
    _recompute();
  }

  /// Persists the live expression back into the currently-loaded sheet
  /// (update-in-place), if one is active.
  Future<void> saveToActiveSheet() async {
    if (_activeSheetId == null) {
      await saveCurrentAsNewSheet();
      return;
    }
    final idx = _sheets.indexWhere((s) => s.id == _activeSheetId);
    if (idx == -1) return;
    final updated = _sheets[idx].copyWith(expression: _expression);
    await _db.updateSheet(updated);
    _sheets[idx] = updated;
    notifyListeners();
  }

  /// Detaches the calculator from the currently loaded sheet, returning
  /// to plain "free calculation" mode — the current expression is left
  /// untouched, only the sheet association is cleared. From this point,
  /// further "=" evaluations log to General history, and swipe-up opens
  /// General history instead of that sheet's history.
  void exitActiveSheet() {
    if (_activeSheetId == null) return;
    _activeSheetId = null;
    notifyListeners();
  }

  /// Updates a sheet's title and/or description (used by the "Edit
  /// sheet" dialog). Both fields are set together since they're edited
  /// in the same dialog.
  Future<void> updateSheetDetails(
    int id, {
    required String title,
    required String description,
  }) async {
    final idx = _sheets.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;
    final updated = _sheets[idx].copyWith(
      title: _clampTitle(trimmedTitle),
      description: _clampDescription(description),
    );
    await _db.updateSheet(updated);
    _sheets[idx] = updated;
    notifyListeners();
  }

  /// Deletes a sheet and its own history (handled together at the DB
  /// layer so the sheet's history never outlives the sheet).
  Future<void> deleteSheet(int id) async {
    await _db.deleteSheet(id);
    _sheets = _sheets.where((s) => s.id != id).toList();
    _history = _history.where((h) => h.sheetId != id).toList();
    if (_activeSheetId == id) _activeSheetId = null;
    notifyListeners();
  }

  /// Called after a drag-and-drop reorder in the Sheet Manager drawer.
  /// `oldIndex`/`newIndex` follow Flutter's `ReorderableListView` contract.
  Future<void> reorderSheet(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updatedList = List<CalculationSheet>.from(_sheets);
    final moved = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, moved);

    // Re-stamp displayOrder to match the new list positions.
    final reindexed = <CalculationSheet>[];
    for (var i = 0; i < updatedList.length; i++) {
      reindexed.add(updatedList[i].copyWith(displayOrder: i));
    }
    _sheets = reindexed;
    notifyListeners();
    await _db.reorderSheets(reindexed);
  }

  // ---------------------------------------------------------------------
  // Calculation History
  // ---------------------------------------------------------------------

  /// Loads a past calculation's expression back into the active
  /// calculator so the user can tweak or continue from it. Deliberately
  /// leaves [activeSheetId] untouched — you can only be viewing a given
  /// history list (General or a specific sheet's) while already in that
  /// exact context, so there's nothing to change.
  void reuseHistoryEntry(CalculationHistoryEntry entry) {
    _expression = entry.expression;
    _recompute();
  }

  Future<void> deleteHistoryEntry(int id) async {
    await _db.deleteHistoryEntry(id);
    _history = _history.where((h) => h.id != id).toList();
    notifyListeners();
  }

  /// Clears only General history (calculations made outside any sheet).
  Future<void> clearGeneralHistory() async {
    await _db.clearHistory(sheetId: null);
    _history = _history.where((h) => h.sheetId != null).toList();
    notifyListeners();
  }

  /// Clears only the given sheet's own history.
  Future<void> clearSheetHistory(int sheetId) async {
    await _db.clearHistory(sheetId: sheetId);
    _history = _history.where((h) => h.sheetId != sheetId).toList();
    notifyListeners();
  }
}
