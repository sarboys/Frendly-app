import 'package:big_break_mobile/features/after_dark/presentation/after_dark_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('after dark screen renders locked teaser and notify action',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AfterDarkScreen(),
      ),
    );

    expect(find.text('After Dark'), findsWidgets);
    expect(find.text('Уведомить'), findsOneWidget);
    expect(find.text('Скоро'), findsOneWidget);
    expect(find.textContaining('замком'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });
}
