import 'package:big_break_mobile/features/evening_routes/presentation/route_form_screen.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

void main() {
  testWidgets('route form mirrors v5 constructor basics', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildTestOverrides(),
        child: const MaterialApp(home: RouteFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BbV5Scaffold), findsOneWidget);
    expect(find.text('Свой маршрут'), findsOneWidget);
    expect(find.text('Собери вечер'), findsOneWidget);
    expect(find.text('Настроение'), findsOneWidget);
    expect(find.text('Длительность'), findsOneWidget);
    expect(find.text('Шаги вечера · 2'), findsOneWidget);
    expect(find.text('Добавить шаг (2/6)'), findsOneWidget);
    expect(find.text('Сохранить маршрут'), findsOneWidget);
  });
}
