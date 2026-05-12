import 'package:big_break_mobile/features/after_dark/presentation/after_dark_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('after dark screen renders locked teaser and notify action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AfterDarkScreen(),
      ),
    );

    expect(find.text('FRENDLY+ 18 · AFTER DARK'), findsOneWidget);
    expect(find.text('8 событий сегодня ночью'), findsOneWidget);
    expect(find.textContaining('замком'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Уведомить о запуске'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Уведомить о запуске'), findsOneWidget);
    expect(find.text('Скоро · следите за обновлениями'), findsOneWidget);
  });
}
