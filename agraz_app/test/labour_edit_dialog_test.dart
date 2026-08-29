import 'package:agraz/api_service.dart';
import 'package:agraz/app_theme.dart';
import 'package:agraz/labour_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('history edit dialog shows shift, location, type and wage',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showLaborEntryEditDialog(
                  context,
                  {
                    'id': 12,
                    'name': 'narayan nak',
                    'category': 'Plucking',
                    'wage': '100',
                    'hours': 1,
                    'shift': 'fullday',
                    'location': 'Farm',
                    'entry_kind': 'payable',
                    'gender': 'Male',
                    'work_type': 'Daily Wages',
                    'narration': 'narayan paid',
                    'date': '2026-08-13',
                    'extra': {'rent': 0, 'food': 0, 'bonus': 0},
                  },
                  ApiService(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit labour entry'), findsOneWidget);
    expect(find.text('narayan nak'), findsOneWidget);
    expect(find.text('fullday'), findsWidgets);
    expect(find.text('Farm'), findsWidgets);
    expect(find.text('Payable'), findsWidgets);
    expect(find.text('Plucking'), findsWidgets);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('narayan paid'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit labour entry'), findsNothing);
  });
}
