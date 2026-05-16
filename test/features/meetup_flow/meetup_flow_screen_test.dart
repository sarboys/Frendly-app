import 'package:big_break_mobile/features/after_party/presentation/after_party_screen.dart';
import 'package:big_break_mobile/features/check_in/presentation/check_in_screen.dart';
import 'package:big_break_mobile/features/host_dashboard/presentation/host_dashboard_screen.dart';
import 'package:big_break_mobile/features/join_request/presentation/join_request_screen.dart';
import 'package:big_break_mobile/features/live_meetup/presentation/live_meetup_screen.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../test_overrides.dart';

class _FakeLocationService implements AppLocationService {
  const _FakeLocationService();

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return 120;
  }

  @override
  Future<Position?> getCurrentPosition() async {
    return Position(
      longitude: 37.6486,
      latitude: 55.7579,
      timestamp: DateTime(2026, 4, 22, 18),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class _FakeMeetupFlowRepository extends BackendRepository {
  _FakeMeetupFlowRepository({
    required super.ref,
    required super.dio,
  });

  @override
  Future<void> confirmCheckIn(String eventId, {String? code}) async {}
}

class _RecordingJoinRequestRepository extends BackendRepository {
  _RecordingJoinRequestRepository({
    required super.ref,
    required super.dio,
  });

  int joinRequestCalls = 0;

  @override
  Future<void> createJoinRequest(String eventId, {required String note}) async {
    joinRequestCalls += 1;
  }
}

Widget _wrap(Widget child, {List<Override> extraOverrides = const []}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      ...extraOverrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('join request screen renders submit CTA', (tester) async {
    await tester.pumpWidget(_wrap(const JoinRequestScreen(eventId: 'e5')));
    await tester.pumpAndSettle();

    expect(find.text('Отправить заявку'), findsOneWidget);
    expect(find.byType(BbV5Scaffold), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Обычно отвечают'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Обычно отвечают'), findsOneWidget);
  });

  testWidgets('join request screen blocks form when requirements are missing',
      (tester) async {
    _RecordingJoinRequestRepository? repository;
    await tester.pumpWidget(
      _wrap(
        const JoinRequestScreen(eventId: 'e-locked'),
        extraOverrides: [
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-locked',
              title: 'Закрытый ужин',
              emoji: '🍷',
              time: 'Сегодня · 20:00',
              place: 'Brix Wine',
              distance: '1.2 км',
              vibe: 'Спокойно',
              description: 'Только для гостей с доступом.',
              hostNote: null,
              joined: false,
              partnerName: null,
              partnerOffer: null,
              capacity: 8,
              going: 2,
              chatId: null,
              requiresVerification: true,
              requiresFrendlyPlus: true,
              entryRequirements: EventEntryRequirements(
                canJoin: false,
                missing: [
                  EventEntryRequirement.verification,
                  EventEntryRequirement.frendlyPlus,
                ],
              ),
              host: EventHost(
                id: 'host-1',
                displayName: 'Мира',
                verified: true,
                rating: 4.9,
                meetupCount: 10,
                avatarUrl: null,
              ),
              attendees: [],
            );
          }),
          backendRepositoryProvider.overrideWith((ref) {
            repository = _RecordingJoinRequestRepository(ref: ref, dio: Dio());
            return repository!;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пройти верификацию'), findsOneWidget);
    expect(find.text('Оформить Frendly+'), findsOneWidget);
    expect(find.text('Сообщение хосту'), findsNothing);
    expect(find.text('Отправить заявку'), findsNothing);
    expect(repository?.joinRequestCalls ?? 0, 0);
  });

  testWidgets('check-in screen renders arrival CTA', (tester) async {
    await tester.pumpWidget(_wrap(const CheckInScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    expect(find.text('Я на месте'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Покажи хосту'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Покажи хосту'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ввести код вручную'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ввести код вручную'), findsOneWidget);
  });

  testWidgets('check-in screen shows real distance after explicit action',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProviderScope(
            overrides: [
              ...buildTestOverrides(),
              appLocationServiceProvider.overrideWithValue(
                const _FakeLocationService(),
              ),
              backendRepositoryProvider.overrideWith(
                (ref) => _FakeMeetupFlowRepository(ref: ref, dio: Dio()),
              ),
            ],
            child: const CheckInScreen(eventId: 'e1'),
          ),
        ),
        GoRoute(
          path: AppRoute.liveMeetup.path,
          name: AppRoute.liveMeetup.name,
          builder: (context, state) => const Text('live-meetup-opened'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Я на месте'));
    await tester.pumpAndSettle();

    expect(find.text('live-meetup-opened'), findsOneWidget);
  });

  testWidgets('live meetup screen renders chat CTA', (tester) async {
    await tester.pumpWidget(_wrap(const LiveMeetupScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    expect(find.text('Открыть чат встречи'), findsOneWidget);
    expect(find.text('На встрече сейчас'), findsOneWidget);
  });

  testWidgets('after-party screen renders save CTA', (tester) async {
    await tester.pumpWidget(_wrap(const AfterPartyScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    expect(find.text('Сохранить'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Они увидят это'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Они увидят это'), findsOneWidget);
  });

  testWidgets('host dashboard renders title', (tester) async {
    await tester.pumpWidget(_wrap(const HostDashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Хост-панель'), findsOneWidget);
    expect(find.text('Этот месяц'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Предстоящие'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Предстоящие'), findsOneWidget);
  });

  testWidgets('host dashboard renders past tab from startsAtIso',
      (tester) async {
    await tester.pumpWidget(_wrap(const HostDashboardScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Прошедшие'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Прошедшие'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Винный вечер на крыше'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Винный вечер на крыше'), findsOneWidget);
  });
}
