import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/calculation_sheet.dart';
import '../models/calculation_history_entry.dart';

/// Singleton database access layer — the sqflite equivalent of a
/// Room `@Dao` + `@Database` pair. All Calculation Sheet persistence
/// (create, read, update, delete, reorder) goes through here, along
/// with the separate, auto-logged Calculation History table.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;
  static const int _dbVersion = 3;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'calcbook.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(CalculationSheet.createTableSql);
        await db.execute(CalculationHistoryEntry.createTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // History table didn't exist yet — create it fresh with the
          // *current* schema (already includes sheetId), so no separate
          // ALTER is needed for databases coming straight from v1.
          await db.execute(CalculationHistoryEntry.createTableSql);
        } else if (oldVersion < 3) {
          // History table already existed (from v2) without sheetId.
          await db.execute(
            'ALTER TABLE ${CalculationHistoryEntry.tableName} ADD COLUMN sheetId INTEGER',
          );
        }
        if (oldVersion < 3) {
          // Sheets table has existed since v1, but without description.
          await db.execute(
            "ALTER TABLE ${CalculationSheet.tableName} ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  /// Returns all saved sheets, ordered by their manual displayOrder.
  Future<List<CalculationSheet>> getAllSheets() async {
    final db = await database;
    final rows = await db.query(
      CalculationSheet.tableName,
      orderBy: 'displayOrder ASC',
    );
    return rows.map(CalculationSheet.fromMap).toList();
  }

  /// Inserts a new sheet. If [displayOrder] isn't provided, the sheet
  /// is appended to the end of the list.
  Future<CalculationSheet> insertSheet(CalculationSheet sheet) async {
    final db = await database;
    final id = await db.insert(
      CalculationSheet.tableName,
      sheet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return sheet.copyWith(id: id);
  }

  /// Updates an existing sheet (used for rename and reload-then-edit flows).
  Future<int> updateSheet(CalculationSheet sheet) async {
    final db = await database;
    return db.update(
      CalculationSheet.tableName,
      sheet.toMap(),
      where: 'id = ?',
      whereArgs: [sheet.id],
    );
  }

  /// Deletes a sheet by id, along with any history entries scoped to it
  /// (that sheet's own History would otherwise be orphaned — pointing at
  /// a sheetId that no longer exists — once the sheet itself is gone).
  Future<int> deleteSheet(int id) async {
    final db = await database;
    final batch = db.batch();
    batch.delete(
      CalculationHistoryEntry.tableName,
      where: 'sheetId = ?',
      whereArgs: [id],
    );
    batch.delete(
      CalculationSheet.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    final results = await batch.commit();
    return results.last as int;
  }

  /// Persists a new manual ordering for a batch of sheets. Called after
  /// a drag-to-reorder gesture in the Sheet Manager drawer.
  Future<void> reorderSheets(List<CalculationSheet> orderedSheets) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < orderedSheets.length; i++) {
      batch.update(
        CalculationSheet.tableName,
        {'displayOrder': i},
        where: 'id = ?',
        whereArgs: [orderedSheets[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// The next displayOrder value to append a new sheet at the end.
  Future<int> nextDisplayOrder() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(displayOrder) as maxOrder FROM ${CalculationSheet.tableName}',
    );
    final maxOrder = result.first['maxOrder'] as int?;
    return (maxOrder ?? -1) + 1;
  }

  // ---------------------------------------------------------------------
  // Calculation History — auto-logged, separate from saved Sheets
  // ---------------------------------------------------------------------

  /// Returns history entries newest-first.
  Future<List<CalculationHistoryEntry>> getAllHistory() async {
    final db = await database;
    final rows = await db.query(
      CalculationHistoryEntry.tableName,
      orderBy: 'timestamp DESC',
    );
    return rows.map(CalculationHistoryEntry.fromMap).toList();
  }

  /// Inserts a new history entry and prunes the oldest rows beyond
  /// [CalculationHistoryEntry.maxEntries] so the table stays bounded.
  Future<void> insertHistoryEntry(CalculationHistoryEntry entry) async {
    final db = await database;
    await db.insert(CalculationHistoryEntry.tableName, entry.toMap());

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${CalculationHistoryEntry.tableName}',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;
    if (count > CalculationHistoryEntry.maxEntries) {
      final excess = count - CalculationHistoryEntry.maxEntries;
      await db.rawDelete(
        '''
        DELETE FROM ${CalculationHistoryEntry.tableName}
        WHERE id IN (
          SELECT id FROM ${CalculationHistoryEntry.tableName}
          ORDER BY timestamp ASC LIMIT ?
        )
        ''',
        [excess],
      );
    }
  }

  Future<void> deleteHistoryEntry(int id) async {
    final db = await database;
    await db.delete(
      CalculationHistoryEntry.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clears history. Pass `sheetId: null` to clear only the *general*
  /// history (calculations made outside any sheet), or a specific id to
  /// clear only that sheet's own history — never both at once, so
  /// clearing one never touches the other.
  Future<void> clearHistory({required int? sheetId}) async {
    final db = await database;
    if (sheetId == null) {
      await db.delete(CalculationHistoryEntry.tableName, where: 'sheetId IS NULL');
    } else {
      await db.delete(
        CalculationHistoryEntry.tableName,
        where: 'sheetId = ?',
        whereArgs: [sheetId],
      );
    }
  }
}
