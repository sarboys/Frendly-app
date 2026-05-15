import 'package:big_break_mobile/app/app.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/ai_create/presentation/ai_create_screen.dart';
import 'package:big_break_mobile/features/ai_voice/presentation/ai_voice_screen.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/publish_meetup_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
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
  testWidgets('ai create shows prompt guide instead of filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const AiCreateScreen()));
    await tester.pumpAndSettle();

    expect(find.text('что написать'), findsOneWidget);
    expect(find.text('примеры хороших запросов'), findsOneWidget);
    expect(find.textContaining('недорогая паста до 1500'), findsOneWidget);
    expect(find.text('настроение'), findsNothing);
    expect(find.text('бюджет'), findsNothing);
    expect(find.text('шагов'), findsNothing);
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

  testWidgets('ai create creates route draft through backend', (
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
          manualLocationProvider.overrideWith((ref) {
            return ManualLocationController(null)
              ..setLocation(
                const ManualLocation(
                  label: 'Парк Горького',
                  latitude: 55.7298,
                  longitude: 37.6011,
                  city: 'Москва',
                ),
              );
          }),
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
    await tester.pump();
    expect(find.text('настроение'), findsNothing);
    expect(find.text('бюджет'), findsNothing);
    expect(find.text('шагов'), findsNothing);
    await _dragUntilVisible(tester, find.text('Собрать план'), 260);
    await tester.tap(find.text('Собрать план'));
    await tester.pumpAndSettle();

    expect(repository.createDraftCalls, 1);
    expect(repository.resolveCalls, 0);
    expect(repository.lastPrompt, 'Винный бар и джаз на двоих');
    expect(repository.lastBudget, isNull);
    expect(repository.lastStepCount, isNull);
    expect(repository.lastCity, 'Москва');
    expect(repository.lastLatitude, 55.7298);
    expect(repository.lastLongitude, 37.6011);
    expect(find.text('Backend Bar'), findsOneWidget);
    expect(find.text('План пока не собран'), findsNothing);
  });

  testWidgets('ai create requires a prompt before backend call', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    _FakeAiRouteRepository? repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manualLocationProvider.overrideWith((ref) {
            return ManualLocationController(null)
              ..setLocation(
                const ManualLocation(
                  label: 'Парк Горького',
                  latitude: 55.7298,
                  longitude: 37.6011,
                  city: 'Москва',
                ),
              );
          }),
          backendRepositoryProvider.overrideWith((ref) {
            final fakeRepository = _FakeAiRouteRepository(ref);
            repository = fakeRepository;
            return fakeRepository;
          }),
        ],
        child: const MaterialApp(home: AiCreateScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await _dragUntilVisible(tester, find.text('Собрать план'), 260);
    await tester.tap(find.text('Собрать план'));
    await tester.pumpAndSettle();

    expect(repository?.createDraftCalls ?? 0, 0);
    expect(find.text('Опиши вечер, чтобы AI собрал маршрут'), findsOneWidget);
  });

  testWidgets('ai create card refresh regenerates current draft', (
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

    await tester.enterText(find.byType(TextField), 'Бар и театр');
    await _dragUntilVisible(tester, find.text('Собрать план'), 260);
    await tester.tap(find.text('Собрать план'));
    await tester.pumpAndSettle();

    expect(repository.createDraftCalls, 1);
    await _dragUntilVisible(tester, find.text('AI · план вечера'), 260);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is BbV5IconButton &&
                widget.icon == LucideIcons.refresh_cw,
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(repository.createDraftCalls, 1);
    expect(repository.regenerateDraftCalls, 1);
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

  testWidgets('ai create opens publish screen for generated route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
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
          path: AppRoute.publishMeetup.path,
          name: AppRoute.publishMeetup.name,
          builder: (context, state) => PublishMeetupScreen(
            initialDraft: state.extra is CreateMeetupDraft
                ? state.extra! as CreateMeetupDraft
                : null,
          ),
        ),
        GoRoute(
          path: AppRoute.eveningPlan.path,
          name: AppRoute.eveningPlan.name,
          builder: (context, state) => const Scaffold(
            body: Text('OLD EVENING PLAN'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _FakeAiRouteRepository(ref),
          ),
          tokenWalletProvider
              .overrideWith((ref) => _TestTokenWalletController()),
        ],
        child: MaterialApp.router(routerConfig: router),
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

    await _dragUntilVisible(tester, find.text('Принять шаг'), 260);
    await tester.tap(find.text('Принять шаг'));
    await tester.pumpAndSettle();

    await _dragUntilVisible(tester, find.text('Создать встречу'), 260);
    await tester.tap(find.text('Создать встречу'));
    await tester.pumpAndSettle();

    expect(find.text('OLD EVENING PLAN'), findsNothing);
    expect(find.text('Финальный шаг'), findsOneWidget);
    expect(find.text('Маршрут · Backend Route'), findsOneWidget);
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
  var createDraftCalls = 0;
  var acceptCalls = 0;
  var regenerateDraftCalls = 0;
  var confirmCalls = 0;
  String? lastPrompt;
  String? lastBudget;
  int? lastStepCount;
  String? lastCity;
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<Map<String, dynamic>> resolveEveningRoute({
    CancelToken? cancelToken,
    String? goal,
    String? mood,
    String? budget,
    String? format,
    String? area,
    String? prompt,
    int? stepCount,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    resolveCalls += 1;
    lastPrompt = prompt;
    lastBudget = budget;
    lastStepCount = stepCount;
    lastCity = city;
    lastLatitude = latitude;
    lastLongitude = longitude;
    return _backendRouteJson;
  }

  @override
  Future<Map<String, dynamic>> createAiRouteDraft({
    CancelToken? cancelToken,
    String? goal,
    String? mood,
    String? budget,
    String? format,
    String? area,
    String? prompt,
    int? stepCount,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    createDraftCalls += 1;
    lastPrompt = prompt;
    lastBudget = budget;
    lastStepCount = stepCount;
    lastCity = city;
    lastLatitude = latitude;
    lastLongitude = longitude;
    return _draftJson(canConfirm: false);
  }

  @override
  Future<Map<String, dynamic>> acceptAiRouteDraftStep(
    String draftId,
    int stepIndex, {
    CancelToken? cancelToken,
  }) async {
    acceptCalls += 1;
    return _draftJson(canConfirm: true);
  }

  @override
  Future<Map<String, dynamic>> regenerateAiRouteDraft(
    String draftId, {
    CancelToken? cancelToken,
  }) async {
    regenerateDraftCalls += 1;
    return _draftJson(canConfirm: false, title: 'Другой Backend Route');
  }

  @override
  Future<Map<String, dynamic>> confirmAiRouteDraft(
    String draftId, {
    CancelToken? cancelToken,
  }) async {
    confirmCalls += 1;
    return _draftJson(canConfirm: true);
  }
}

Map<String, dynamic> _draftJson({
  required bool canConfirm,
  String title = 'Backend Route',
}) =>
    {
      'draftId': 'draft-1',
      'route': {
        ..._backendRouteJson,
        'title': title,
      },
      'acceptedStepIndexes': canConfirm ? [0] : [],
      'currentStepIndex': canConfirm ? null : 0,
      'canConfirm': canConfirm,
      'expiresAt': '2026-05-16T08:00:00.000Z',
      'warnings': [],
    };

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

class _TestTokenWalletController extends TokenWalletController {
  _TestTokenWalletController() : super(null) {
    state = const TokenWalletState(
      balance: 20,
      promoted: {},
      history: [],
      loading: false,
    );
  }
}
