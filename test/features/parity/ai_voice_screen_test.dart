import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/ai_voice/presentation/ai_voice_screen.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/publish_meetup_screen.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ai voice resolves dictated prompt through backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late _FakeAiVoiceRepository repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith((ref) {
            repository = _FakeAiVoiceRepository(ref);
            return repository;
          }),
        ],
        child: const MaterialApp(home: AiVoiceScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.textContaining('Тихий ужин и долгая прогулка'));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(repository.resolveCalls, 1);
    expect(repository.lastPrompt, 'Тихий ужин и долгая прогулка, не громко');
    expect(find.text('Backend Bar'), findsOneWidget);
    expect(find.text('Маршрут появится после ответа сервера.'), findsNothing);
  });

  testWidgets('ai voice opens publish screen for generated route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: AppRoute.aiVoice.path,
      routes: [
        GoRoute(
          path: AppRoute.aiVoice.path,
          name: AppRoute.aiVoice.name,
          builder: (context, state) => const AiVoiceScreen(),
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
            (ref) => _FakeAiVoiceRepository(ref),
          ),
          tokenWalletProvider
              .overrideWith((ref) => _TestTokenWalletController()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.textContaining('Тихий ужин и долгая прогулка'));
    await tester.pump(const Duration(milliseconds: 1600));

    await tester.ensureVisible(find.text('Превратить в встречу'));
    await tester.tap(find.text('Превратить в встречу'));
    await tester.pumpAndSettle();

    expect(find.text('OLD EVENING PLAN'), findsNothing);
    expect(find.text('Финальный шаг'), findsOneWidget);
    expect(find.text('Маршрут · Voice Backend Route'), findsOneWidget);
  });
}

class _FakeAiVoiceRepository extends BackendRepository {
  _FakeAiVoiceRepository(Ref ref) : super(ref: ref, dio: Dio());

  var resolveCalls = 0;
  String? lastPrompt;

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
    return _backendRouteJson;
  }
}

const _backendRouteJson = {
  'id': 'voice-route',
  'title': 'Voice Backend Route',
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
