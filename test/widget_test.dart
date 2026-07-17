import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcbook/main.dart';

void main() {
  testWidgets('CalcBook launches and shows the calculator screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalcBookApp());
    await tester.pumpAndSettle();

    expect(find.text('CalcBook'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
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
}
