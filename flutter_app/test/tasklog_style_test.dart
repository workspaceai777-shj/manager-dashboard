import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontario_staff_tasks/tasklog_style.dart';

void main() {
  testWidgets('Ontario medical plus brand mark renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TaskLogBrandMark()),
    ));
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
