import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dyaudio_widget/main.dart';

void main() {
  const channel = MethodChannel('com.example.dyaudio_widget/recorder');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isRecording':
          return false;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Shows the recording toggle', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('녹음'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
