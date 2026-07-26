/// A single auto-logged history entry — created every time the user
/// presses "=". Unlike a [CalculationSheet] (which is a deliberate,
/// named save), history entries are captured automatically so the user
/// never loses a calculation they forgot to save, without cluttering
/// their curated Sheets list.
///
/// [sheetId] scopes the entry: `null` means it was calculated in plain
/// "free calculation" mode (the *general* history), while a non-null
/// value ties it to whichever Sheet was active at the moment "=" was
/// pressed (that sheet's *own* history).
class CalculationHistoryEntry {
  final int? id;
  final String expression;
  final String result;
  final DateTime timestamp;
  final int? sheetId;

  const CalculationHistoryEntry({
    this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
    this.sheetId,
  });

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'expression': expression,
      'result': result,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sheetId': sheetId,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory CalculationHistoryEntry.fromMap(Map<String, Object?> map) {
    return CalculationHistoryEntry(
      id: map['id'] as int?,
      expression: map['expression'] as String,
      result: map['result'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      sheetId: map['sheetId'] as int?,
    );
  }

  static const String tableName = 'calculation_history';

  static const String createTableSql = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expression TEXT NOT NULL,
      result TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      sheetId INTEGER
    )
  ''';

  /// Cap on how many history rows are retained *in total* (across both
  /// general and all sheets combined) — oldest entries beyond this are
  /// pruned automatically so the table doesn't grow forever.
  static const int maxEntries = 200;
}
