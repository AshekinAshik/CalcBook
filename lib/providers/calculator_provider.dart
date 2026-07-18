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
  List<CalculationHistoryEntry> _history = [];

  String get expression => _expression;
  String get liveResult => _liveResult;
  bool get isScientificMode => _isScientificMode;
  int? get activeSheetId => _activeSheetId;
  List<CalculationSheet> get sheets => List.unmodifiable(_sheets);
  List<CalculationHistoryEntry> get history => List.unmodifiable(_history);

  CalculatorProvider() {
    _loadSheets();
    _loadHistory();
  }

  Future<void> _loadSheets() async {
    _sheets = await _db.getAllSheets();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    _history = await _db.getAllHistory();
    notifyListeners();
  }

  void toggleScientificMode() {
    _isScientificMode = !_isScientificMode;
    notifyListeners();
  }

  /// Appends a token (digit, operator, function, parenthesis) to the
  /// live expression trail and re-evaluates the preview result.
  void appendToken(String token) {
    _expression += token;
    _recompute();
  }

  void backspace() {
    if (_expression.isEmpty) return;
    _expression = _expression.substring(0, _expression.length - 1);
    _recompute();
  }

  void clearAll() {
    _expression = '';
    _liveResult = '';
    _activeSheetId = null;
    notifyListeners();
  }

  /// Evaluates and "commits" the current expression, replacing it with
  /// its final result (standard calculator '=' behavior), and silently
  /// logs the calculation to History.
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
  // Calculation Sheets — save / reload / rename / delete / reorder
  // ---------------------------------------------------------------------

  /// Saves the current live expression trail as a brand-new independent
  /// sheet ("Calculation Sheets" — the core innovation of the app).
  Future<void> saveCurrentAsNewSheet({String? title}) async {
    if (_expression.trim().isEmpty) return;
    final order = await _db.nextDisplayOrder();
    final sheet = CalculationSheet(
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : 'Sheet ${_sheets.length + 1}',
      expression: _expression,
      displayOrder: order,
    );
    final saved = await _db.insertSheet(sheet);
    _sheets = [..._sheets, saved];
    _activeSheetId = saved.id;
    notifyListeners();
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
  /// further "=" evaluations log to History as normal, with no implied
  /// tie to the sheet you just left.
  void exitActiveSheet() {
    if (_activeSheetId == null) return;
    _activeSheetId = null;
    notifyListeners();
  }

  Future<void> renameSheet(int id, String newTitle) async {
    if (newTitle.trim().isEmpty) return;
    await _db.renameSheet(id, newTitle.trim());
    final idx = _sheets.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _sheets[idx] = _sheets[idx].copyWith(title: newTitle.trim());
      notifyListeners();
    }
  }

  Future<void> deleteSheet(int id) async {
    await _db.deleteSheet(id);
    _sheets = _sheets.where((s) => s.id != id).toList();
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
  /// calculator so the user can tweak or continue from it.
  void reuseHistoryEntry(CalculationHistoryEntry entry) {
    _expression = entry.expression;
    _activeSheetId = null;
    _recompute();
  }

  Future<void> deleteHistoryEntry(int id) async {
    await _db.deleteHistoryEntry(id);
    _history = _history.where((h) => h.id != id).toList();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _db.clearHistory();
    _history = [];
    notifyListeners();
  }
}
