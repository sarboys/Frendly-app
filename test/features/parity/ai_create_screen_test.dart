import 'package:big_break_mobile/app/app.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/ai_create/presentation/ai_create_screen.dart';
import 'package:big_break_mobile/features/ai_voice/presentation/ai_voice_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

Widget _wrapPhoneViewport(Widget child) {
  return MaterialApp(
    home: AppPhoneViewportMediaQuery(
      statusBarHeight: 44,
      child: child,
    ),
  );
}

void main() {
  testWidgets('ai create uses compact v5 mood tiles', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const AiCreateScreen()));
    await tester.pumpAndSettle();

    final wineTile = find.ancestor(
      of: find.text('Вино'),
      matching: find.byType(InkWell),
    );

    expect(wineTile, findsOneWidget);
    expect(tester.getSize(wineTile).height, lessThanOrEqualTo(76));
  });

  testWidgets('ai create scroll viewport fills the phone window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrapPhoneViewport(const AiCreateScreen()));
    await tester.pumpAndSettle();

    final scrollRect = tester.getRect(find.byType(CustomScrollView));

    expect(scrollRect.top, 44);
    expect(scrollRect.bottom, 820);
  });

  testWidgets('ai create resolves typed prompt through backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late _FakeAiRouteRepository repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith((ref) {
            repository = _FakeAiRouteRepository(ref);
            return repository;
          }),
        ],
        child: const MaterialApp(home: AiCreateScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Винный бар и джаз на двоих',
    );
    await _dragUntilVisible(tester, find.text('Собрать план'), 260);
    await tester.tap(find.text('Собрать план'));
    await tester.pumpAndSettle();

    expect(repository.resolveCalls, 1);
    expect(repository.lastPrompt, contains('Винный бар и джаз на двоих'));
    expect(repository.lastBudget, 'low');
    expect(find.text('Backend Bar'), findsOneWidget);
    expect(find.text('План пока не собран'), findsNothing);
  });

  testWidgets('ai create mic action opens voice flow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: AppRoute.aiCreate.path,
      routes: [
        GoRoute(
          path: AppRoute.aiCreate.path,
          name: AppRoute.aiCreate.name,
          builder: (context, state) => const AiCreateScreen(),
        ),
        GoRoute(
          path: AppRoute.aiVoice.path,
          name: AppRoute.aiVoice.name,
          builder: (context, state) => const AiVoiceScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Сказать вслух'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.mic));
    for (var i = 0;
        i < 12 && find.byType(AiVoiceScreen).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(AiVoiceScreen), findsOneWidget);
  });
}

Future<void> _dragUntilVisible(
  WidgetTester tester,
  Finder finder,
  double moveStep, {
  int maxScrolls = 12,
}) async {
  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final start = Offset(logicalSize.width / 2, logicalSize.height * 0.62);

  for (var i = 0; i < maxScrolls && finder.evaluate().isEmpty; i++) {
    await tester.dragFrom(start, Offset(0, -moveStep));
    await tester.pumpAndSettle();
  }

  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
}

class _FakeAiRouteRepository extends BackendRepository {
  _FakeAiRouteRepository(Ref ref) : super(ref: ref, dio: Dio());

  var resolveCalls = 0;
  String? lastPrompt;
  String? lastBudget;

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
    lastPrompt = prompt;
    lastBudget = budget;
    return _backendRouteJson;
  }
}

const _backendRouteJson = {
  'id': 'backend-route',
  'title': 'Backend Route',
  'vibe': 'С backend',
  'blurb': 'Маршрут пришел из API',
  'totalPriceFrom': 1200,
  'totalSavings': 400,
  'durationLabel': '19:00 - 23:00',
  'area': 'Центр',
  'goal': 'date',
  'mood': 'date',
  'budget': 'low',
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
