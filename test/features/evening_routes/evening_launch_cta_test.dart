import 'package:big_break_mobile/features/evening_routes/presentation/create_evening_session_screen.dart';
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
  testWidgets('launch entry uses common publish screen without plan sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _UnavailableEveningRepository(ref),
          ),
          subscriptionStateProvider.overrideWith((ref) async {
            return _inactiveSubscription;
          }),
          eveningRouteTemplateProvider.overrideWith((ref, templateId) async {
            return _templateDetail;
          }),
        ],
        child: const MaterialApp(
          home: CreateEveningSessionScreen(templateId: 'template-cozy'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Опубликовать вечер?'), findsNothing);
    expect(find.text('Собрать вечер по маршруту'), findsNothing);
    expect(find.text('Запустить маршрут · в чат'), findsNothing);
    expect(find.text('Собрать своих'), findsNothing);
    expect(find.text('Дальше · превью'), findsNothing);
    expect(find.text('Финальный шаг'), findsOneWidget);
    expect(find.text('превью карточки'), findsOneWidget);
    expect(
      find.text('Маршрут · Спокойный вечер: Kitchen Burger Bar → дом Шурика'),
      findsOneWidget,
    );
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
  'id': 'template-cozy',
  'routeId': 'route-cozy',
  'title': 'Спокойный вечер: Kitchen Burger Bar → дом Шурика',
  'blurb': 'Начните вечер с бургера, затем прогуляйтесь до дома Шурика.',
  'city': 'Москва',
  'area': 'Москва',
  'vibe': 'Спокойно',
  'budget': 'mid',
  'durationLabel': '2.5 часа',
  'totalPriceFrom': 0,
  'totalSavings': 0,
  'stepsPreview': [],
  'partnerOffersPreview': [],
  'nearestSessions': [],
  'goal': 'newfriends',
  'steps': [
    {
      'id': 'step-burger',
      'time': '19:00',
      'endTime': '20:00',
      'kind': 'dinner',
      'title': 'ресторан Kitchen Burger Bar',
      'venue': 'Kitchen Burger Bar',
      'address': 'ул. Пятницкая, д. 82/34, стр. 1',
      'emoji': '☕',
      'distance': 'старт маршрута',
      'lat': 55.735,
      'lng': 37.627,
    },
  ],
});

class _UnavailableEveningRepository extends BackendRepository {
  _UnavailableEveningRepository(Ref ref) : super(ref: ref, dio: Dio());

  @override
  Future<Map<String, dynamic>> fetchEveningRoute(
    String routeId, {
    CancelToken? cancelToken,
  }) async {
    throw StateError('Network disabled in CTA test');
  }

  @override
  Future<EveningPublishResult> publishEveningRoute(
    String routeId, {
    required EveningPrivacy privacy,
  }) async {
    throw StateError('Network disabled in CTA test');
  }
}
