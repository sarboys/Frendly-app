import 'package:big_break_mobile/features/create_meetup/presentation/widgets/route_picker_sheet.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() {
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
                showRoutePickerSheet(context);
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
    expect(find.text('Создать свой маршрут'), findsNothing);
    expect(
      find.text('Из 2–6 шагов · сохраним в твоей коллекции'),
      findsNothing,
    );
    expect(find.text('Найти маршрут или место'), findsOneWidget);
    expect(find.text('Тёплый круг на Покровке'), findsOneWidget);
    expect(find.text('3 шагов'), findsOneWidget);
    expect(find.text('−650 ₽'), findsOneWidget);
  });

  testWidgets('custom route tab shows the v5 route constructor', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свой'));
    await tester.pumpAndSettle();

    expect(find.text('Свой маршрут'), findsAtLeastNWidgets(1));
    expect(find.text('Собери вечер'), findsOneWidget);
    expect(find.text('Настроение'), findsOneWidget);
    expect(find.text('Длительность'), findsOneWidget);
    expect(find.text('Шаги вечера · 2'), findsOneWidget);
    expect(find.text('Добавить шаг (2/6)'), findsOneWidget);
    expect(find.text('Сохранить маршрут'), findsOneWidget);
  });

  testWidgets('custom route tab uses route constructor fields', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свой'));
    await tester.pumpAndSettle();

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();

    expect(fields, hasLength(5));
    expect(fields[0].decoration?.hintText, 'Slow night на Патриках');
    expect(fields[1].decoration?.hintText, 'Бар или кафе');
    expect(fields[2].decoration?.hintText, 'Адрес или ориентир');
    expect(fields[3].decoration?.hintText, 'Прогулка');
    expect(fields[4].decoration?.hintText, 'Адрес или ориентир');
  });

  testWidgets('custom route step icon cycles like route constructor', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свой'));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.coffee), findsOneWidget);

    await tester.ensureVisible(find.byIcon(LucideIcons.coffee));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.coffee));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.wine), findsWidgets);
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
