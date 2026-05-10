import 'package:big_break_mobile/features/create_meetup/presentation/widgets/route_picker_sheet.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({bool dark = false}) {
  return ProviderScope(
    overrides: [
      eveningRouteTemplatesProvider.overrideWith(
        (ref, city) async => _routeSummaries,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showRoutePickerSheet(context, dark: dark);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('ready route picker mirrors front compact rows', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Маршрут вечера'), findsOneWidget);
    expect(
      find.text('Готовый или свой — несколько мест за вечер'),
      findsOneWidget,
    );
    expect(find.text('Создать свой маршрут'), findsOneWidget);
    expect(find.text('Из 2–6 шагов · сохраним в твоей коллекции'), findsOneWidget);
    expect(find.text('Найти маршрут или место'), findsOneWidget);
    expect(find.text('Тёплый круг на Покровке'), findsOneWidget);
    expect(find.text('3 шагов'), findsOneWidget);
    expect(find.text('−650 ₽'), findsOneWidget);
  });

  testWidgets('custom route tab mirrors front defaults and labels',
      (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свой'));
    await tester.pumpAndSettle();

    expect(find.text('НАЗВАНИЕ'), findsOneWidget);
    expect(find.text('ШАГИ ВЕЧЕРА'), findsOneWidget);
    expect(find.text('Свой маршрут'), findsAtLeastNWidgets(1));
    expect(find.text('19:00'), findsAtLeastNWidgets(1));
    expect(find.text('Аперитив'), findsAtLeastNWidgets(1));
    expect(find.text('21:00'), findsAtLeastNWidgets(1));
    expect(find.text('Ужин'), findsAtLeastNWidgets(1));
    expect(find.text('Место (необязательно)'), findsAtLeastNWidgets(2));
    expect(find.text('Добавить шаг'), findsOneWidget);
    expect(find.text('Сохранить маршрут'), findsOneWidget);
  });

  testWidgets('custom route tab uses compact front metrics', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свой'));
    await tester.pumpAndSettle();

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();

    expect(tester.getSize(find.byType(TextField).at(0)).height, 44);
    expect(
      fields[0].decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 14),
    );
    expect(tester.getSize(find.byType(TextField).at(1)).width, 56);
    expect(fields[1].decoration?.contentPadding, EdgeInsets.zero);
    expect(tester.getSize(find.byType(TextField).at(2)).height, 20);
    expect(tester.getSize(find.byType(TextField).at(3)).height, 20);
  });

  testWidgets('custom route step emoji opens picker like front', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свой'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🍷').first);
    await tester.pumpAndSettle();

    expect(find.text('⚽'), findsOneWidget);

    await tester.tap(find.text('⚽'));
    await tester.pumpAndSettle();

    expect(find.text('⚽'), findsOneWidget);
  });

  testWidgets('route picker supports After Dark styling', (tester) async {
    await tester.pumpWidget(_wrap(dark: true));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final routeIcon = tester.widget<Icon>(find.byIcon(LucideIcons.route));
    expect(routeIcon.color, AppColors.adMagenta);
  });
}

final _routeSummaries = [
  EveningRouteTemplateSummary.fromJson(const {
    'id': 'template-cozy',
    'routeId': 'r-cozy-circle',
    'title': 'Тёплый круг на Покровке',
    'blurb': 'Аперитив, лёгкий стендап и долгий разговор в кофейне',
    'city': 'Москва',
    'area': 'Чистые пруды → Покровка',
    'vibe': 'Камерный вечер',
    'budget': 'mid',
    'durationLabel': '19:00 — 00:30',
    'totalPriceFrom': 1400,
    'totalSavings': 650,
    'stepsPreview': [
      {'title': 'Бар', 'venue': 'Brix Wine', 'emoji': '🍇', 'time': '19:00'},
      {
        'title': 'Шоу',
        'venue': 'Standup Store',
        'emoji': '🎤',
        'time': '20:30'
      },
      {'title': 'Афтер', 'venue': 'Кафе Заря', 'emoji': '☕', 'time': '22:30'},
    ],
    'partnerOffersPreview': [],
    'nearestSessions': [],
  }),
];
