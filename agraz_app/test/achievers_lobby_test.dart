import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agraz/app_theme.dart';
import 'package:agraz/achievers_lobby.dart';

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

  testWidgets('Achievers Lobby shows two tabs, search, and upload',
      (tester) async {
    await pumpPage(tester, const AchieversLobbyPage(skipNetwork: true));

    expect(tester.takeException(), isNull);
    expect(find.text('Achievers Lobby'), findsWidgets);
    expect(find.text('Achievers'), findsOneWidget);
    expect(find.text('Innovations'), findsOneWidget);
    expect(find.text('Search by name'), findsOneWidget);
    expect(find.text('Upload video'), findsWidgets);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('No videos yet'), findsOneWidget);
  });

  testWidgets('Upload form requires name, mobile, category, and video',
      (tester) async {
    await pumpPage(tester, const AchieversLobbyUploadPage(skipNetwork: true));
    await tester.pump();

    expect(find.text('Upload video'), findsWidgets);
    expect(find.text('Name *'), findsWidgets);
    expect(find.text('Mobile *'), findsWidgets);
    expect(find.text('Select video'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
  });
}
