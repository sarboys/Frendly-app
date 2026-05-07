import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/evening_routes_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_overrides.dart';

void main() {
  testWidgets('routes screen mirrors the front catalog structure', (
    tester,
  ) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(_routesApp());
    await tester.pumpAndSettle();

    expect(find.text('Frendly Routes'), findsOneWidget);
    expect(find.text('Маршруты вечера'), findsOneWidget);
    expect(find.text('Город · '), findsOneWidget);
    expect(find.text('2 маршрутов'), findsOneWidget);
    expect(find.text('Спокойно'), findsWidgets);
    expect(find.text('Знакомства'), findsOneWidget);
    expect(find.text('Рекомендованный сегодня'), findsOneWidget);
    expect(find.text('Другие маршруты'), findsOneWidget);
    expect(find.text('-650₽'), findsOneWidget);
    expect(find.text('≈ 1 400 ₽'), findsNothing);
    expect(find.text('экономия 650 ₽ по перкам'), findsNothing);
    expect(find.text('Не нашёл свой? Собери AI-маршрут'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no-route');
    await tester.pumpAndSettle();

    expect(find.text('Маршрутов пока нет'), findsOneWidget);
    expect(find.text('Сбросить фильтры'), findsOneWidget);

    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();

    expect(find.text('Тёплый круг на Покровке'), findsOneWidget);
    expect(find.text('Свидание Noir'), findsOneWidget);
  });

  testWidgets('route card actions open EveningPlan and launch sheet entry', (
    tester,
  ) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(_routesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Подробнее').first);
    await tester.pumpAndSettle();

    expect(find.text('plan:r-cozy-circle launch:0'), findsOneWidget);

    await tester.pumpWidget(_routesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Запустить').first);
    await tester.pumpAndSettle();

    expect(find.text('plan:r-cozy-circle launch:1'), findsOneWidget);
  });

  testWidgets('routes screen does not build every route card at once', (
    tester,
  ) async {
    _setMobileViewport(tester);

    final routes = List.generate(100, _generatedRouteSummary);
    await tester.pumpWidget(_routesApp(routes: routes));
    await tester.pumpAndSettle();

    expect(find.text('Маршрут 0'), findsOneWidget);
    expect(find.text('Маршрут 99'), findsNothing);
  });
}

Widget _routesApp({List<EveningRouteTemplateSummary>? routes}) {
  final routeItems = routes ?? _routeSummaries;
  final router = GoRouter(
    initialLocation: AppRoute.eveningRoutes.path,
    routes: [
      GoRoute(
        path: AppRoute.eveningRoutes.path,
        name: AppRoute.eveningRoutes.name,
        builder: (context, state) => const EveningRoutesScreen(),
      ),
      GoRoute(
        path: AppRoute.eveningBuilder.path,
        name: AppRoute.eveningBuilder.name,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('builder')),
        ),
      ),
      GoRoute(
        path: AppRoute.eveningPlan.path,
        name: AppRoute.eveningPlan.name,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'plan:${state.pathParameters['routeId']} '
              'launch:${state.uri.queryParameters['launch'] ?? '0'}',
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      eveningRouteTemplatesProvider.overrideWith(
        (ref, city) async => routeItems,
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

EveningRouteTemplateSummary _generatedRouteSummary(int index) {
  return EveningRouteTemplateSummary.fromJson({
    'id': 'template-$index',
    'routeId': 'route-$index',
    'title': 'Маршрут $index',
    'blurb': 'Короткий маршрут',
    'city': 'Москва',
    'area': 'центр',
    'badgeLabel': null,
    'coverUrl': null,
    'vibe': 'Спокойно',
    'budget': 'mid',
    'durationLabel': '2 часа',
    'totalPriceFrom': 1000,
    'totalSavings': 0,
    'mood': 'calm',
    'premium': false,
    'hostsCount': 0,
    'stepsPreview': const [
      {
        'title': 'Кофе',
        'venue': 'Кофейня',
        'emoji': '☕',
        'time': '19:00',
        'kind': 'cafe',
      },
    ],
    'partnerOffersPreview': const [],
    'nearestSessions': const [],
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
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
    'badgeLabel': null,
    'coverUrl': null,
    'vibe': 'Камерный вечер',
    'budget': 'mid',
    'durationLabel': '19:00 — 00:30',
    'totalPriceFrom': 1400,
    'totalSavings': 650,
    'mood': 'outdoor',
    'premium': false,
    'hostsCount': 8,
    'stepsPreview': [
      {
        'title': 'Аперитив в Brix Wine',
        'venue': 'Brix Wine',
        'emoji': '🍇',
        'time': '19:00',
        'kind': 'bar',
      },
      {
        'title': 'Открытый микрофон Standup Store',
        'venue': 'Standup Store',
        'emoji': '🎤',
        'time': '20:30',
        'kind': 'show',
      },
      {
        'title': 'After-chat в Кафе Заря',
        'venue': 'Кафе Заря',
        'emoji': '☕',
        'time': '22:30',
        'kind': 'afterparty',
      },
    ],
    'partnerOffersPreview': [],
    'nearestSessions': [
      {
        'sessionId': 'session-cozy',
        'startsAt': '2026-04-29T16:00:00.000Z',
        'joinedCount': 5,
        'capacity': 10,
      },
    ],
  }),
  EveningRouteTemplateSummary.fromJson(const {
    'id': 'template-date',
    'routeId': 'r-date-noir',
    'title': 'Свидание Noir',
    'blurb': 'Камерный показ, прогулка и финал на крыше',
    'city': 'Москва',
    'area': 'Парк Горького → Берсеневская',
    'badgeLabel': null,
    'coverUrl': null,
    'vibe': 'Вечер для двоих',
    'budget': 'high',
    'durationLabel': '20:00 — 01:00',
    'totalPriceFrom': 2400,
    'totalSavings': 900,
    'mood': 'date',
    'premium': true,
    'hostsCount': 3,
    'stepsPreview': [
      {
        'title': 'Авторское кино в Garage Screen',
        'venue': 'Garage Screen',
        'emoji': '🎬',
        'time': '20:00',
        'kind': 'show',
      },
      {
        'title': 'Ужин в Tilda Bistro',
        'venue': 'Tilda Bistro',
        'emoji': '🍝',
        'time': '22:00',
        'kind': 'dinner',
      },
      {
        'title': 'Финал на крыше Стрелка',
        'venue': 'Стрелка',
        'emoji': '🍸',
        'time': '23:30',
        'kind': 'bar',
      },
    ],
    'partnerOffersPreview': [],
    'nearestSessions': [],
  }),
];
