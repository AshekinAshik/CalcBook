import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:calcbook/main.dart';

void main() {
  // CalculatorProvider talks to sqflite as soon as it's constructed
  // (loading saved Sheets and History). Plain `flutter test` has no
  // platform channel for the real sqflite plugin — only a device or
  // `flutter test integration_test` does — so without this, every test
  // below would fail with a MissingPluginException before the app even
  // finished its first frame. This swaps in sqflite_common_ffi's
  // pure-Dart SQLite implementation for the test run only.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('CalcBook launches and shows the calculator screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalcBookApp());
    await tester.pumpAndSettle();

    expect(find.text('CalcBook'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Scientific'), findsOneWidget);
  });

  testWidgets('Tapping digits and = shows a result',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalcBookApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('7'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('='));
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('Scientific toggle reveals scientific function keys',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalcBookApp());
    await tester.pumpAndSettle();

    expect(find.text('sin'), findsNothing);
    await tester.tap(find.text('Scientific'));
    await tester.pumpAndSettle();
    expect(find.text('sin'), findsOneWidget);
    expect(find.text('log'), findsOneWidget);
  });

  testWidgets('Sheets badge starts at zero and Sheets drawer opens',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalcBookApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calculation Sheets'));
    await tester.pumpAndSettle();

    expect(find.text('Calculation Sheets'), findsOneWidget);
    expect(find.text('No saved sheets yet'), findsOneWidget);
  });
}
