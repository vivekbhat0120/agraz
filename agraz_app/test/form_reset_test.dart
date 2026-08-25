import 'package:agraz/voice_dictation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stopVoiceAndClearFields clears narration after save',
      (tester) async {
    final narration = TextEditingController(text: 'bought fertilizer');
    final amount = TextEditingController(text: '500');
    addTearDown(narration.dispose);
    addTearDown(amount.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: narration),
              TextField(controller: amount),
            ],
          ),
        ),
      ),
    );

    expect(narration.text, 'bought fertilizer');
    expect(amount.text, '500');

    stopVoiceAndClearFields([narration, amount]);
    await tester.pump();

    expect(narration.text, isEmpty);
    expect(amount.text, isEmpty);
  });

  testWidgets('Form.reset after save does not keep narration when we skip it',
      (tester) async {
    final narration = TextEditingController();
    addTearDown(narration.dispose);
    final key = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: TextFormField(controller: narration),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'old note');
    key.currentState!.save();
    expect(narration.text, 'old note');

    stopVoiceAndClearFields([narration]);
    await tester.pump();
    expect(narration.text, isEmpty);
  });
}
