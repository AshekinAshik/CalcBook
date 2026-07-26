/// Data model for a saved Calculation Sheet.
///
/// This is the Flutter/sqflite equivalent of the Room `CalculationSheet`
/// entity described in the spec:
///   id            -> INTEGER PRIMARY KEY AUTOINCREMENT
///   title         -> TEXT
///   description   -> TEXT (optional note, capped at 250 chars in the UI)
///   expression    -> TEXT (the live calculation trail, e.g. "12 + 8 * 2")
///   displayOrder  -> INTEGER (used for manual re-ordering in the drawer)
class CalculationSheet {
  final int? id;
  final String title;
  final String description;
  final String expression;
  final int displayOrder;

  const CalculationSheet({
    this.id,
    required this.title,
    this.description = '',
    required this.expression,
    required this.displayOrder,
  });

  /// Returns a copy of this sheet with the given fields replaced.
  CalculationSheet copyWith({
    int? id,
    String? title,
    String? description,
    String? expression,
    int? displayOrder,
  }) {
    return CalculationSheet(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      expression: expression ?? this.expression,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  /// Converts this object into a Map for sqflite. `id` is omitted when
  /// null so SQLite can auto-assign the primary key on insert.
  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'title': title,
      'description': description,
      'expression': expression,
      'displayOrder': displayOrder,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory CalculationSheet.fromMap(Map<String, Object?> map) {
    return CalculationSheet(
      id: map['id'] as int?,
      title: map['title'] as String,
      // Defensive default for rows written before the description
      // column existed (pre-migration), even though the migration
      // backfills it with '' — belt and suspenders.
      description: (map['description'] as String?) ?? '',
      expression: map['expression'] as String,
      displayOrder: map['displayOrder'] as int,
    );
  }

  static const String tableName = 'calculation_sheets';
  static const int maxDescriptionLength = 250;
  static const int maxTitleLength = 60;

  static const String createTableSql = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      expression TEXT NOT NULL,
      displayOrder INTEGER NOT NULL
    )
  ''';
}
