import 'package:big_break_mobile/features/evening_plan/presentation/evening_builder_screen.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'evening_test_routes.dart';

void main() {
  testWidgets('builder follows front question flow and returns matched route',
      (tester) async {
    _setMobileViewport(tester);
    EveningRouteData? readyRoute;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _DefaultEveningBuilderRepository(ref),
          ),
        ],
        child: MaterialApp(
          home: EveningBuilderScreen(
            onReady: (route) {
              readyRoute = route;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    expect(
      find.text(
        'Привет 👋 Я Frendly. Соберу вечер за минуту. С чего начнём — какой повод?',
      ),
      findsOneWidget,
    );

    await _pickOption(tester, 'Новые друзья');
    expect(find.text('Лови. А настроение какое сегодня?'), findsOneWidget);

    await _pickOption(tester, 'Спокойно');
    expect(
      find.text('Бюджет на человека — чтобы не закидывать лишнее'),
      findsOneWidget,
    );

    await _pickOption(tester, 'Средне');
    expect(
      find.text('Что хочется добавить в вечер?'),
      findsOneWidget,
    );

    await _pickOption(tester, 'Бар');
    expect(find.text('Где удобнее стартовать?'), findsOneWidget);

    await _pickOption(tester, 'Центр');
    await tester.pump(const Duration(milliseconds: 1200));

    expect(readyRoute?.id, 'r-cozy-circle');
    expect(find.textContaining('Собрал маршрут «Тёплый круг на Покровке»'),
        findsOneWidget);
  });

  testWidgets('builder reset restarts the front copy flow', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EveningBuilderScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    await tester.tap(find.byTooltip('Начать заново'));
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    expect(find.text('Окей, начнём заново. Какой повод?'), findsOneWidget);
    expect(find.text('Новые друзья'), findsOneWidget);
  });

  testWidgets('builder resolves route through backend with local fallback UI',
      (tester) async {
    _setMobileViewport(tester);
    EveningRouteData? readyRoute;
    late _FakeEveningBuilderRepository repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith((ref) {
            repository = _FakeEveningBuilderRepository(ref);
            return repository;
          }),
        ],
        child: MaterialApp(
          home: EveningBuilderScreen(
            onReady: (route) {
              readyRoute = route;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    await _pickOption(tester, 'Новые друзья');
    expect(find.text('Backend Social'), findsOneWidget);

    await _pickOption(tester, 'Backend Social');
    await _pickOption(tester, 'Средне');
    await _pickOption(tester, 'Бар');
    await _pickOption(tester, 'Центр');
    await tester.pump(const Duration(milliseconds: 1200));

    expect(repository.resolveCalls, 1);
    expect(repository.lastResolvePayload, {
      'goal': 'newfriends',
      'mood': 'social',
      'budget': 'mid',
      'format': 'bar',
      'area': 'center',
      'prompt': null,
    });
    expect(readyRoute?.id, 'backend-route');
    expect(
        find.textContaining('Собрал маршрут «Backend Route»'), findsOneWidget);
  });

  testWidgets('builder matches front step pills and can return to done step',
      (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EveningBuilderScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    expect(find.text('Повод'), findsOneWidget);
    expect(find.text('Настроение'), findsOneWidget);
    expect(find.text('Бюджет'), findsOneWidget);
    expect(find.text('Формат'), findsOneWidget);

    await _pickOption(tester, 'Новые друзья');
    await _pickOption(tester, 'Спокойно');

    expect(find.byIcon(LucideIcons.check), findsWidgets);
    expect(find.byIcon(LucideIcons.pencil), findsWidgets);
    expect(find.text('Новые друзья'), findsWidgets);
    expect(find.text('Спокойно'), findsWidgets);

    await tester.tap(find.text('Новые друзья').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    expect(
      find.text(
        'Привет 👋 Я Frendly. Соберу вечер за минуту. С чего начнём — какой повод?',
      ),
      findsWidgets,
    );
    expect(find.text('Свидание'), findsOneWidget);
  });

  testWidgets('builder sends free prompt to backend resolver', (tester) async {
    _setMobileViewport(tester);
    EveningRouteData? readyRoute;
    late _FakeEveningBuilderRepository repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith((ref) {
            repository = _FakeEveningBuilderRepository(ref);
            return repository;
          }),
        ],
        child: MaterialApp(
          home: EveningBuilderScreen(
            onReady: (route) {
              readyRoute = route;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    expect(find.textContaining('Спонтанный вечер на двоих'), findsOneWidget);
    expect(find.text('Опиши вечер своими словами…'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Свидание у Патриков без алкоголя',
    );
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.send).last);
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    expect(find.text('Свидание у Патриков без алкоголя'), findsOneWidget);
    expect(
      find.text(
          'Понял! Подберу под этот вайб. Уточни ещё пару деталей — и собираю.'),
      findsOneWidget,
    );

    await _pickOption(tester, 'Новые друзья');
    await _pickOption(tester, 'Backend Social');
    await _pickOption(tester, 'Средне');
    await _pickOption(tester, 'Бар');
    await _pickOption(tester, 'Центр');
    await tester.pump(const Duration(milliseconds: 1200));

    expect(repository.lastResolvePayload, {
      'goal': 'newfriends',
      'mood': 'social',
      'budget': 'mid',
      'format': 'bar',
      'area': 'center',
      'prompt': 'Свидание у Патриков без алкоголя',
    });
    expect(readyRoute?.id, 'backend-route');
  });
}

Future<void> _pickOption(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle(const Duration(milliseconds: 700));
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _FakeEveningBuilderRepository extends BackendRepository {
  _FakeEveningBuilderRepository(Ref ref) : super(ref: ref, dio: Dio());

  var resolveCalls = 0;
  Map<String, String?>? lastResolvePayload;

  @override
  Future<Map<String, dynamic>> fetchEveningOptions({
    CancelToken? cancelToken,
  }) async {
    return {
      'moods': [
        {
          'key': 'social',
          'emoji': '✨',
          'label': 'Backend Social',
          'blurb': 'С backend',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> resolveEveningRoute({
    CancelToken? cancelToken,
    String? goal,
    String? mood,
    String? budget,
    String? format,
    String? area,
    String? prompt,
  }) async {
    resolveCalls += 1;
    lastResolvePayload = {
      'goal': goal,
      'mood': mood,
      'budget': budget,
      'format': format,
      'area': area,
      'prompt': prompt,
    };
    return {
      'id': 'backend-route',
      'title': 'Backend Route',
      'vibe': 'С backend',
      'blurb': 'Маршрут пришёл из API',
      'totalPriceFrom': 1200,
      'totalSavings': 400,
      'durationLabel': '19:00 - 23:00',
      'area': 'Центр',
      'goal': 'newfriends',
      'mood': 'social',
      'budget': 'mid',
      'premium': false,
      'recommendedFor': 'Тест',
      'hostsCount': 2,
      'steps': [
        {
          'id': 'step-1',
          'time': '19:00',
          'kind': 'bar',
          'title': 'Backend Bar',
          'venue': 'Backend Bar',
          'address': 'Центр 1',
          'emoji': '🍷',
          'distance': '0.5 км',
          'lat': 0.4,
          'lng': 0.5,
        },
      ],
    };
  }
}

class _DefaultEveningBuilderRepository extends BackendRepository {
  _DefaultEveningBuilderRepository(Ref ref) : super(ref: ref, dio: Dio());

  @override
  Future<Map<String, dynamic>> fetchEveningOptions({
    CancelToken? cancelToken,
  }) async {
    return const {};
  }

  @override
  Future<Map<String, dynamic>> resolveEveningRoute({
    CancelToken? cancelToken,
    String? goal,
    String? mood,
    String? budget,
    String? format,
    String? area,
    String? prompt,
  }) async {
    return _routeJson(testCozyEveningRoute);
  }
}

Map<String, dynamic> _routeJson(EveningRouteData route) {
  return {
    'id': route.id,
    'title': route.title,
    'vibe': route.vibe,
    'blurb': route.blurb,
    'totalPriceFrom': route.totalPriceFrom,
    'totalSavings': route.totalSavings,
    'durationLabel': route.durationLabel,
    'area': route.area,
    'goal': 'newfriends',
    'mood': 'chill',
    'budget': 'mid',
    'premium': route.premium,
    'hostsCount': route.hostsCount,
    'steps': route.steps
        .map((step) => {
              'id': step.id,
              'time': step.time,
              'endTime': step.endTime,
              'kind': 'bar',
              'title': step.title,
              'venue': step.venue,
              'address': step.address,
              'emoji': step.emoji,
              'distance': step.distance,
              'lat': step.lat,
              'lng': step.lng,
            })
        .toList(growable: false),
  };
}
