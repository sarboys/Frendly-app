import 'package:big_break_mobile/features/report/presentation/report_screen.dart';
import 'package:big_break_mobile/features/safety/presentation/safety_hub_screen.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: buildTestOverrides(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('safety hub matches emergency call flow from front',
      (tester) async {
    await tester.pumpWidget(_wrap(const SafetyHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Безопасность'), findsOneWidget);
    expect(find.text('УДЕРЖИВАЙ КНОПКУ'), findsOneWidget);
    expect(find.text('Позвонить 112'), findsOneWidget);
    expect(find.text('Поделиться гео'), findsOneWidget);
    expect(find.text('Safe Walk'), findsOneWidget);
    expect(find.text('Чат с поддержкой'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ГОРЯЧИЕ ЛИНИИ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ГОРЯЧИЕ ЛИНИИ'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Добавить контакт'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Добавить контакт'));
    await tester.pumpAndSettle();

    expect(find.text('Доверенный контакт'), findsOneWidget);
    expect(find.text('Телефон'), findsWidgets);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Когда уведомлять'), findsOneWidget);
    expect(find.text('Встречи + SOS'), findsWidgets);
    expect(find.text('Только SOS'), findsWidgets);
  });

  testWidgets('report screen uses front details prompt copy', (tester) async {
    await tester.pumpWidget(_wrap(const ReportScreen(userId: 'user-anya')));
    await tester.pumpAndSettle();

    expect(find.byType(BbV5Scaffold), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Подробности (по желанию)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Подробности (по желанию)'), findsOneWidget);
    expect(
      find.text('Что произошло? Когда, где, как себя вёл?'),
      findsOneWidget,
    );
  });
}
