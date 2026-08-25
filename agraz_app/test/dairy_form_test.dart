import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agraz/app_theme.dart';
import 'package:agraz/dairy.dart';
import 'package:agraz/dairy_owner.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: page,
      ),
    );
    await tester.pump();
  }

  testWidgets('Dairy entry form renders and Save validates empty name',
      (tester) async {
    await pumpPage(tester, const DairyPage(skipBootstrap: true));

    expect(tester.takeException(), isNull);
    expect(find.text('Dairy'), findsWidgets);
    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    final narration = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(narration.minLines, isNotNull);
    expect(narration.maxLines, isNotNull);
    expect(narration.minLines! <= narration.maxLines!, isTrue);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter dairy / party name'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Gowda Dairy');
    await tester.enterText(fields.at(2), '10');
    await tester.enterText(fields.at(3), '5');
    await tester.pump();

    final amountField = tester.widget<TextField>(fields.at(4));
    expect(amountField.controller?.text, '50.00');

    await tester.tap(find.text('Payment received'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Quantity (liters)'), findsNothing);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No dairy entries yet'), findsOneWidget);
  });

  testWidgets('Dairy owner entry form with narration does not assert',
      (tester) async {
    await pumpPage(tester, const DairyOwnerPage(skipBootstrap: true));

    expect(tester.takeException(), isNull);
    expect(find.text('Dairy Owner'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);

    final narration = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(narration.minLines! <= narration.maxLines!, isTrue);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter customer name'), findsOneWidget);

    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add customer'), findsOneWidget);
  });
}
