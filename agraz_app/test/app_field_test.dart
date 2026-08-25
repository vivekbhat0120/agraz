import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agraz/app_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('AppField with maxLines 2 does not assert (dairy narration)',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(wrap(
      AppField(
        controller: ctrl,
        label: 'Narration',
        icon: Icons.notes_rounded,
        maxLines: 2,
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 2);
    expect(field.maxLines, 2);
    expect(field.minLines! <= field.maxLines!, isTrue);
  });

  testWidgets('AppField single-line stays minLines 1', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(wrap(
      AppField(
        controller: ctrl,
        label: 'Amount',
        icon: Icons.payments_rounded,
      ),
    ));

    expect(tester.takeException(), isNull);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 1);
    expect(field.maxLines, 1);
  });

  testWidgets('AppField clamps minLines that exceed maxLines', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(wrap(
      AppField(
        controller: ctrl,
        label: 'Notes',
        icon: Icons.notes_rounded,
        minLines: 5,
        maxLines: 2,
      ),
    ));

    expect(tester.takeException(), isNull);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 2);
    expect(field.maxLines, 2);
  });
}
