import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/event_detail/presentation/event_detail_screen.dart';
import 'package:big_break_mobile/features/map/presentation/map_screen.dart';
import 'package:big_break_mobile/features/user_profile/presentation/user_profile_screen.dart';
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
  testWidgets('event detail uses new compact meetup detail layout',
      (tester) async {
    await tester.pumpWidget(_wrap(const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Место'),
      find.byType(CustomScrollView),
      const Offset(0, -180),
    );

    expect(find.text('Место'), findsOneWidget);
    expect(find.text('Когда'), findsNothing);
    expect(find.text('Где'), findsNothing);
    expect(find.text('Длительность'), findsNothing);

    await tester.dragUntilVisible(
      find.text('Идут · 6'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );

    expect(find.text('Идут · 6'), findsOneWidget);

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

  testWidgets('event detail renders interactive evening route stops',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-route',
              title: 'Винный вечер на крыше',
              emoji: '🍷',
              time: 'Сегодня · 20:00',
              place: 'Маршрут: Тверская в огнях',
              distance: '0.0 км',
              vibe: 'Спокойно',
              description: 'Идем по маршруту вечера.',
              hostNote: null,
              joined: true,
              partnerName: null,
              partnerOffer: null,
              capacity: 10,
              going: 6,
              chatId: 'mc-route',
              routeId: 'route-mc1',
              host: EventHost(
                id: 'user-anya',
                displayName: 'Аня К',
                verified: true,
                rating: 4.9,
                meetupCount: 23,
                avatarUrl: null,
              ),
              attendees: [],
            );
          }),
          eventDetailRouteStopsProvider.overrideWith((ref, routeId) async {
            return const [
              EventDetailRouteStop(
                title: 'Brix Wine',
                subtitle: 'Покровка 12',
                time: '20:00',
                note: 'Стартуем у барной стойки',
                emoji: '🍷',
              ),
              EventDetailRouteStop(
                title: 'Прогулка по Покровке',
                subtitle: '15 минут пешком',
                time: '21:30',
                note: 'Идем до второй точки',
                emoji: '🚶',
              ),
              EventDetailRouteStop(
                title: 'Late jazz в Aglio',
                subtitle: 'Маросейка 6',
                time: '22:00',
                note: 'Опционально после бара',
                emoji: '🎷',
              ),
            ];
          }),
        ],
        child: const MaterialApp(
          home: EventDetailScreen(eventId: 'e-route'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Маршрут вечера'),
      find.byType(CustomScrollView),
      const Offset(0, -180),
    );

    expect(find.text('Маршрут вечера'), findsOneWidget);
    expect(find.text('3 ОСТАНОВКИ'), findsOneWidget);
    expect(find.text('Brix Wine'), findsOneWidget);
    expect(find.text('Прогулка по Покровке'), findsOneWidget);
    expect(find.text('Late jazz в Aglio'), findsOneWidget);

    await tester.ensureVisible(find.text('Прогулка по Покровке'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Прогулка по Покровке'));
    await tester.pumpAndSettle();

    expect(find.text('Идем до второй точки'), findsOneWidget);
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

    await tester.dragUntilVisible(
      find.text('До 8 участников'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
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
    expect(lifestyleValue.style?.fontFamily, 'Sora');
    expect(lifestyleValue.style?.fontSize, 11.5);
    expect(lifestyleValue.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('event detail labels tomorrow event date as tomorrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-tomorrow',
              title: 'Прогулка по району',
              emoji: '🚶',
              time: 'Завтра · 15:00',
              place: 'Маросейка',
              distance: '3.2 км',
              vibe: 'Спокойно',
              description: 'Идем гулять по району.',
              hostNote: null,
              joined: false,
              partnerName: null,
              partnerOffer: null,
              capacity: 8,
              going: 1,
              chatId: null,
              host: EventHost(
                id: 'user-host',
                displayName: 'Лена',
                verified: true,
                rating: 4.8,
                meetupCount: 9,
                avatarUrl: null,
              ),
              attendees: [
                EventAttendee(
                  id: 'user-host',
                  displayName: 'Лена',
                  avatarUrl: null,
                ),
              ],
            );
          }),
        ],
        child: const MaterialApp(
          home: EventDetailScreen(eventId: 'e-tomorrow'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('Сегодня'), findsNothing);
  });

  testWidgets('event detail shows pending join request state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-pending',
              title: 'Камерный ужин по заявкам',
              emoji: '🍝',
              time: 'Сегодня · 18:30',
              place: 'Солянка 5',
              distance: '0.7 км',
              vibe: 'Уютно',
              description: 'Ужин в маленькой компании.',
              hostNote: null,
              joined: false,
              partnerName: null,
              partnerOffer: null,
              capacity: 6,
              going: 1,
              chatId: null,
              accessMode: 'request',
              visibilityMode: 'friends',
              joinMode: EventJoinMode.request,
              joinRequestStatus: EventJoinRequestStatus.pending,
              host: EventHost(
                id: 'user-anya',
                displayName: 'Аня К',
                verified: true,
                rating: 4.8,
                meetupCount: 12,
                avatarUrl: null,
              ),
              attendees: [
                EventAttendee(
                  id: 'user-anya',
                  displayName: 'Аня К',
                  avatarUrl: null,
                ),
              ],
            );
          }),
        ],
        child: const MaterialApp(
          home: EventDetailScreen(eventId: 'e-pending'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заявка отправлена'), findsOneWidget);
    expect(find.text('Отменить заявку'), findsOneWidget);
    final pendingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Заявка отправлена'),
    );
    expect(pendingButton.onPressed, isNull);
  });

  testWidgets('event detail shows buy ticket button for paid affiche meetup',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-ticket',
              title: 'Концерт и встреча',
              emoji: '🎟',
              time: 'Сегодня · 20:00',
              place: 'Live Arena',
              distance: '1.1 км',
              vibe: 'Музыка',
              description: 'Идем вместе на концерт.',
              hostNote: null,
              joined: false,
              partnerName: null,
              partnerOffer: null,
              capacity: 8,
              going: 2,
              chatId: 'mc-ticket',
              ticketUrl: 'https://tickets.example/show',
              ticketSourceKind: EventTicketSourceKind.affiche,
              ticketSourceId: 'affiche-1',
              ticketPriceFrom: 1500,
              ticketProvider: 'Ticketland',
              ticketVenue: 'Live Arena',
              host: EventHost(
                id: 'user-host',
                displayName: 'Мира',
                verified: true,
                rating: 4.9,
                meetupCount: 10,
                avatarUrl: null,
              ),
              attendees: [],
            );
          }),
        ],
        child: const MaterialApp(
          home: EventDetailScreen(eventId: 'e-ticket'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Купить билет'), findsOneWidget);
    expect(find.textContaining('от 1500 ₽'), findsOneWidget);
  });

  testWidgets('map category filters render counts and keep selected card',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    await tester.pumpWidget(_wrap(const MapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Все · 5'), findsOneWidget);
    expect(find.text('Бары · 5'), findsOneWidget);
    expect(find.text('Винный вечер на крыше'), findsOneWidget);

    await tester.tap(find.text('Бары · 5'));
    await tester.pumpAndSettle();

    expect(find.text('Винный вечер на крыше'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('event detail route button opens external map options',
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

    await tester.dragUntilVisible(
      find.text('Brix Wine'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
    await tester.ensureVisible(find.text('Brix Wine'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Маршрут'));
    await tester.pumpAndSettle();

    expect(find.text('Открыть адрес'), findsOneWidget);
    expect(find.text('Google Карты'), findsOneWidget);
  });

  testWidgets('event detail route action opens external map options',
      (tester) async {
    await tester.pumpWidget(_wrap(const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Brix Wine'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
    await tester.ensureVisible(find.text('Brix Wine'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Маршрут'));
    await tester.pumpAndSettle();

    expect(find.text('Открыть адрес'), findsOneWidget);
    expect(find.text('Google Карты'), findsOneWidget);
    expect(find.text('Яндекс Карты'), findsOneWidget);
  });

  testWidgets('event detail attendee rail does not duplicate host or users',
      (tester) async {
    await tester.pumpWidget(_wrap(const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Идут · 6'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(find.text('Аня К, 26'), findsNothing);
    expect(find.text('Никита М, 27'), findsNothing);
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
    await tester.ensureVisible(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    expect(find.text('own-v5-profile'), findsOneWidget);
    expect(find.text('old-public-profile-user-me'), findsNothing);
  });

  testWidgets('event guest opens host public profile on v5 surface', (
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
                  id: 'e-guest',
                  title: 'Вечер в баре',
                  emoji: '🍷',
                  time: 'Сегодня · 19:00',
                  place: 'Brix',
                  distance: '1.0 км',
                  vibe: 'Спокойно',
                  description: 'Вино и разговоры.',
                  hostNote: null,
                  joined: false,
                  partnerName: null,
                  partnerOffer: null,
                  capacity: 8,
                  going: 2,
                  chatId: 'mc-guest',
                  startsAtIso: '2026-05-04T16:00:00.000Z',
                  lifestyle: 'calm',
                  priceMode: 'free',
                  accessMode: 'open',
                  genderMode: 'all',
                  visibilityMode: 'public',
                  joinMode: EventJoinMode.open,
                  isHost: false,
                  host: EventHost(
                    id: 'user-anya',
                    displayName: 'Аня К',
                    verified: true,
                    rating: 4.8,
                    meetupCount: 12,
                    avatarUrl: null,
                  ),
                  attendees: [
                    EventAttendee(
                      id: 'user-anya',
                      displayName: 'Аня К',
                      avatarUrl: null,
                    ),
                  ],
                );
              }),
            ],
            child: const EventDetailScreen(eventId: 'e-guest'),
          ),
        ),
        GoRoute(
          path: AppRoute.userProfile.path,
          name: AppRoute.userProfile.name,
          builder: (context, state) => ProviderScope(
            overrides: buildTestOverrides(),
            child: UserProfileScreen(
              userId: state.pathParameters['userId']!,
            ),
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
    await tester.ensureVisible(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    expect(find.text('Написать'), findsOneWidget);
    expect(find.text('Аня К'), findsWidgets);
  });
}
