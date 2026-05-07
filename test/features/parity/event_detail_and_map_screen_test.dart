import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/event_detail/presentation/event_detail_screen.dart';
import 'package:big_break_mobile/features/map/presentation/map_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../test_overrides.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      appLocationServiceProvider.overrideWithValue(const _NoLocationService()),
    ],
    child: MaterialApp(home: child),
  );
}

class _NoLocationService implements AppLocationService {
  const _NoLocationService();

  @override
  Future<Position?> getCurrentPosition() async => null;

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return 0;
  }
}

void main() {
  testWidgets('event detail uses total going count in attendee summary',
      (tester) async {
    await tester.pumpWidget(_wrap(const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Кто идёт · 6'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );

    expect(find.text('Кто идёт · 6'), findsOneWidget);
    expect(find.text('Программа вечера'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Бонус от Brix Wine'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
    expect(find.text('Бонус от Brix Wine'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Включить Safe Walk'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
    expect(find.text('Включить Safe Walk'), findsOneWidget);
  });

  testWidgets('event detail shows criteria as muted chips', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-criteria',
              title: 'Фестиваль кофе и винила',
              emoji: '☕',
              time: 'Вс, 27 апр · 13:00',
              place: 'Хлебозавод',
              distance: '1.0 км',
              vibe: 'Активно',
              description: 'Обжарщики, виниловые сеты и дегустации.',
              hostNote: null,
              joined: false,
              partnerName: null,
              partnerOffer: null,
              capacity: 8,
              going: 1,
              chatId: 'mc-criteria',
              lifestyle: 'anti',
              priceMode: 'range',
              priceAmountFrom: 700,
              priceAmountTo: 1200,
              accessMode: 'request',
              genderMode: 'female',
              visibilityMode: 'friends',
              host: EventHost(
                id: 'user-me',
                displayName: 'Сергей',
                verified: true,
                rating: 4.8,
                meetupCount: 6,
                avatarUrl: null,
              ),
              attendees: [
                EventAttendee(
                  id: 'user-me',
                  displayName: 'Сергей',
                  avatarUrl: null,
                ),
              ],
            );
          }),
        ],
        child: const MaterialApp(
          home: EventDetailScreen(eventId: 'e-criteria'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Критерии встречи'), findsNothing);
    expect(find.text('Образ жизни'), findsNothing);
    expect(find.text('Стоимость'), findsNothing);
    expect(find.text('Кого приглашают'), findsNothing);
    expect(find.text('Вступление'), findsNothing);
    expect(find.text('Видимость'), findsNothing);
    expect(find.text('До 8 участников'), findsOneWidget);
    expect(find.text('Не ЗОЖ'), findsOneWidget);
    expect(find.text('700-1200 ₽'), findsOneWidget);
    expect(find.text('Девушки'), findsOneWidget);
    expect(find.text('По заявке'), findsOneWidget);
    expect(find.text('По ссылке'), findsNothing);

    final lifestyleValue = tester.widget<Text>(find.text('Не ЗОЖ'));
    expect(lifestyleValue.style?.fontFamily, 'Manrope');
    expect(lifestyleValue.style?.fontSize, 14);
    expect(lifestyleValue.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('map filter updates count and selected card', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    await tester.pumpWidget(_wrap(const MapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('5 точек · 25 км'), findsOneWidget);
    expect(find.text('Винный вечер на крыше'), findsOneWidget);

    await tester.tap(find.text('Популярные'));
    await tester.pumpAndSettle();

    expect(find.text('2 точек · 25 км'), findsOneWidget);
    expect(find.text('Настолки и кофе'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('event detail place row opens map focused on event',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProviderScope(
            overrides: buildTestOverrides(),
            child: const EventDetailScreen(eventId: 'e1'),
          ),
        ),
        GoRoute(
          path: '/map',
          name: 'map',
          builder: (context, state) => Text(
            'map-opened-${state.uri.queryParameters['eventId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Brix Wine, Покровка 12'));
    await tester.pumpAndSettle();

    expect(find.text('map-opened-e1'), findsOneWidget);
  });

  testWidgets('event host can open create meetup in edit mode', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProviderScope(
            overrides: [
              ...buildTestOverrides(),
              eventDetailProvider.overrideWith((ref, eventId) async {
                return const EventDetail(
                  id: 'e-host',
                  title: 'Вечерняя пробежка',
                  emoji: '🏃',
                  time: 'Сегодня · 20:00',
                  place: 'Парк Горького',
                  distance: '1.4 км',
                  vibe: 'Активно',
                  description: 'Легкий темп и кофе после.',
                  hostNote: null,
                  joined: true,
                  partnerName: null,
                  partnerOffer: null,
                  capacity: 8,
                  going: 4,
                  chatId: 'mc-host',
                  startsAtIso: '2026-05-04T17:00:00.000Z',
                  lifestyle: 'zozh',
                  priceMode: 'free',
                  accessMode: 'open',
                  genderMode: 'all',
                  visibilityMode: 'public',
                  joinMode: EventJoinMode.open,
                  isHost: true,
                  host: EventHost(
                    id: 'user-me',
                    displayName: 'Сергей',
                    verified: true,
                    rating: 4.9,
                    meetupCount: 12,
                    avatarUrl: null,
                  ),
                  attendees: [
                    EventAttendee(
                      id: 'user-me',
                      displayName: 'Сергей',
                      avatarUrl: null,
                    ),
                  ],
                );
              }),
            ],
            child: const EventDetailScreen(eventId: 'e-host'),
          ),
        ),
        GoRoute(
          path: '/create',
          name: 'createMeetup',
          builder: (context, state) => Text(
            'edit-event-${state.uri.queryParameters['editEventId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();

    expect(find.text('edit-event-e-host'), findsOneWidget);
  });

  testWidgets('event host profile button opens own v5 profile', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProviderScope(
            overrides: [
              ...buildTestOverrides(),
              eventDetailProvider.overrideWith((ref, eventId) async {
                return const EventDetail(
                  id: 'e-host',
                  title: 'Идем на Гадкий утенок',
                  emoji: '🎟️',
                  time: 'Сегодня · 11:00',
                  place: 'Театр кукол имени...',
                  distance: '1.0 км',
                  vibe: 'Спокойно',
                  description: 'Спектакль и кофе после.',
                  hostNote: null,
                  joined: true,
                  partnerName: null,
                  partnerOffer: null,
                  capacity: 8,
                  going: 1,
                  chatId: 'mc-host',
                  startsAtIso: '2026-05-04T08:00:00.000Z',
                  lifestyle: 'calm',
                  priceMode: 'free',
                  accessMode: 'open',
                  genderMode: 'all',
                  visibilityMode: 'public',
                  joinMode: EventJoinMode.open,
                  isHost: true,
                  host: EventHost(
                    id: 'user-me',
                    displayName: 'Сергей',
                    verified: true,
                    rating: 0,
                    meetupCount: 0,
                    avatarUrl: null,
                  ),
                  attendees: [
                    EventAttendee(
                      id: 'user-me',
                      displayName: 'Сергей',
                      avatarUrl: null,
                    ),
                  ],
                );
              }),
            ],
            child: const EventDetailScreen(eventId: 'e-host'),
          ),
        ),
        GoRoute(
          path: AppRoute.profile.path,
          name: AppRoute.profile.name,
          builder: (context, state) => const Text('own-v5-profile'),
        ),
        GoRoute(
          path: AppRoute.userProfile.path,
          name: AppRoute.userProfile.name,
          builder: (context, state) => Text(
            'old-public-profile-${state.pathParameters['userId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Профиль'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    expect(find.text('own-v5-profile'), findsOneWidget);
    expect(find.text('old-public-profile-user-me'), findsNothing);
  });
}
