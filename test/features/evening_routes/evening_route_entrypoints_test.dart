import 'package:big_break_mobile/features/evening_routes/presentation/create_evening_session_screen.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/evening_route_detail_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/subscription.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route detail entry uses the front-like EveningPlan screen', (
    tester,
  ) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      _wrap(
        const EveningRouteDetailScreen(templateId: 'template-generated'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Маршрут вечера'), findsWidgets);
    expect(find.text('Frendly Plan'), findsNothing);
    expect(find.text('Generated route from template'), findsNWidgets(2));
    expect(find.text('Тёплый круг на Покровке'), findsNothing);
    expect(find.text('Generated concert'), findsOneWidget);
    expect(find.text('Шоу'), findsOneWidget);
    expect(find.text('Поехали по маршруту'), findsOneWidget);
    expect(find.text('У маршрута нет чата.'), findsNothing);
  });

  testWidgets('create session entry opens the same launch sheet as route plan',
      (
    tester,
  ) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      _wrap(
        const CreateEveningSessionScreen(templateId: 'template-cozy'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Опубликовать вечер?'), findsOneWidget);
    expect(find.text('Кто может вписаться'), findsOneWidget);
    expect(find.text('Опубликовать и собрать людей'), findsOneWidget);
    expect(find.text('Заметка хоста'), findsNothing);
  });
}

Widget _wrap(Widget screen) {
  return ProviderScope(
    overrides: [
      backendRepositoryProvider.overrideWith(
        (ref) => _UnavailableEveningPlanRepository(ref),
      ),
      subscriptionStateProvider.overrideWith((ref) async {
        return _inactiveSubscription;
      }),
      eveningRouteTemplateProvider.overrideWith((ref, templateId) async {
        return _templateDetail;
      }),
    ],
    child: MaterialApp(home: screen),
  );
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const _inactiveSubscription = SubscriptionStateData(
  plan: null,
  status: 'inactive',
  startedAt: null,
  renewsAt: null,
  trialEndsAt: null,
);

final _templateDetail = EveningRouteTemplateDetail.fromJson(const {
  'id': 'template-generated',
  'routeId': 'route-generated',
  'title': 'Generated route from template',
  'blurb': 'Template blurb without local mock flicker',
  'city': 'Москва',
  'area': 'Центр',
  'vibe': 'Камерный вечер',
  'budget': 'mid',
  'durationLabel': '19:00 — 00:30',
  'totalPriceFrom': 1400,
  'totalSavings': 650,
  'stepsPreview': [],
  'partnerOffersPreview': [],
  'nearestSessions': [],
  'goal': 'newfriends',
  'steps': [
    {
      'id': 'step-generated-concert',
      'time': '19:00',
      'endTime': '20:30',
      'kind': 'concert',
      'title': 'Generated concert',
      'venue': 'Generated Hall',
      'address': 'Центр 1',
      'emoji': '🎭',
      'distance': 'старт маршрута',
      'lat': 55.75,
      'lng': 37.61,
    },
    {
      'id': 'step-generated-bar',
      'time': '20:45',
      'endTime': '21:45',
      'kind': 'bar',
      'title': 'Generated bar',
      'venue': 'Generated Bar',
      'address': 'Центр 2',
      'emoji': '🍷',
      'distance': '10 минут пешком',
      'lat': 55.751,
      'lng': 37.611,
    },
  ],
});

class _UnavailableEveningPlanRepository extends BackendRepository {
  _UnavailableEveningPlanRepository(Ref ref) : super(ref: ref, dio: Dio());

  @override
  Future<Map<String, dynamic>> fetchEveningRoute(
    String routeId, {
    CancelToken? cancelToken,
  }) async {
    throw StateError('Network disabled in route entry tests');
  }

  @override
  Future<EveningPublishResult> publishEveningRoute(
    String routeId, {
    required EveningPrivacy privacy,
  }) async {
    throw StateError('Network disabled in route entry tests');
  }
}
