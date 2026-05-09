import 'package:big_break_mobile/app/app.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/features/meetups/presentation/meetups_screen.dart';
import 'package:big_break_mobile/features/tonight/presentation/tonight_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/tokens.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_overrides.dart';

void main() {
  testWidgets('tonight shows create meetup button above shell content', (
    tester,
  ) async {
    await _pumpTonightApp(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('tonight renders the linked HomeV5 screen only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpTonightApp(tester);

    expect(find.text('FRENDLY'), findsOneWidget);
    expect(find.textContaining('Город дышит'), findsOneWidget);
    expect(find.text('Радар вечера'), findsOneWidget);
    expect(find.text('Сейчас собираются'), findsOneWidget);

    await _dragUntilVisible(tester, find.text('Дейтинг · рядом'), 420);
    await _dragUntilVisible(tester, find.text('Афиша города'), 420);
    await _dragUntilVisible(tester, find.text('Маршруты вечера'), 420);
    await _dragUntilVisible(tester, find.text('Сводка'), 420);
    await _dragUntilVisible(tester, find.text('AI compass'), 420);

    expect(find.text('Frendly Evening'), findsNothing);
    expect(find.text('Frendly Evenings'), findsNothing);
    expect(find.text('Идут и собираются'), findsNothing);
    expect(find.text('Твои встречи сегодня'), findsNothing);
    expect(find.text('Рядом с тобой'), findsNothing);
    expect(find.text('Что в городе'), findsNothing);
    expect(find.text('Билеты на эту неделю'), findsNothing);
  });

  testWidgets('tonight routes section uses backend route templates', (
    tester,
  ) async {
    await _pumpTonightDirect(
      tester,
      extraOverrides: [
        eveningRouteTemplatesProvider.overrideWith(
          (ref, city) async => const [_tonightRouteTemplate],
        ),
      ],
    );

    await _dragUntilVisible(tester, find.text('Backend маршрут'), 420);

    expect(find.text('Backend маршрут'), findsOneWidget);
    expect(find.text('Тверская в огнях'), findsNothing);
    expect(find.text('Замоскворечье ночью'), findsNothing);
  });

  testWidgets('tonight radar legend keeps full row width', (tester) async {
    await _pumpTonightDirect(tester);

    for (final label in ['Встречи', 'Маршруты', 'Дейтинг', 'Афиша']) {
      expect(find.text(label), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('tonight radar sweep rotates over time', (tester) async {
    await _pumpTonightDirect(tester);

    final sweep = find.byKey(const ValueKey('tonight-radar-sweep-rotation'));

    expect(sweep, findsOneWidget);
    final initialScaleX = tester.widget<Transform>(sweep).transform.storage[0];

    await tester.pump(const Duration(milliseconds: 240));

    final movedScaleX = tester.widget<Transform>(sweep).transform.storage[0];
    expect(movedScaleX, isNot(initialScaleX));
  });

  testWidgets('tonight gathering CTA opens the v5 meetups surface', (
    tester,
  ) async {
    await _pumpTonightApp(
      tester,
      extraOverrides: [
        appLocationServiceProvider.overrideWithValue(
          const _NoLocationService(),
        ),
        mapkitBootstrapProvider.overrideWithValue(
          const _ImmediateMapkitBootstrap(),
        ),
      ],
    );

    await _dragUntilVisible(
      tester,
      find.byKey(const ValueKey('tonight-gathering-all')),
      260,
    );
    await tester.tap(find.byKey(const ValueKey('tonight-gathering-all')));
    await tester.pumpAndSettle();

    expect(find.byType(MeetupsScreen), findsOneWidget);
    expect(find.text('Радар вечера'), findsNothing);
  });

  testWidgets('tonight header AI opens city limited flow', (
    tester,
  ) async {
    await _pumpTonightApp(
      tester,
      extraOverrides: [
        tonightCityAvailabilityProvider.overrideWith((ref) async => false),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('tonight-header-ai')));
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.text('Frendly Вечер — пока только в Москве и СПб'),
      findsOneWidget,
    );
  });

  testWidgets('tonight header AI opens builder from manual Moscow location', (
    tester,
  ) async {
    await _pumpTonightApp(
      tester,
      extraOverrides: [
        manualLocationProvider.overrideWith((ref) {
          return ManualLocationController(null)
            ..setLocation(
              const ManualLocation(
                label: 'Москва - Покровка',
                latitude: 55.757,
                longitude: 37.648,
              ),
            );
        }),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('tonight-header-ai')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    expect(
      find.text('Frendly · AI compass'),
      findsOneWidget,
    );
    expect(
      find.text('Frendly Вечер — пока только в Москве и СПб'),
      findsNothing,
    );
  });

  testWidgets('tonight uses v5 dating cards without old avatar tiles', (
    tester,
  ) async {
    await _pumpTonightApp(
      tester,
      extraOverrides: [
        peopleProvider.overrideWith(
          (ref) async => const [
            PersonSummary(
              id: 'user-sergey',
              name: 'Сергей',
              age: 31,
              area: 'Центр',
              common: ['Музыка', 'Бары'],
              online: true,
              verified: true,
              vibe: 'джаз',
              avatarUrl: 'https://cdn.example.com/sergey.jpg',
            ),
          ],
        ),
      ],
    );

    await _dragUntilVisible(tester, find.text('Сергей, 31'), 420);

    expect(find.text('Сергей, 31'), findsOneWidget);
    expect(find.text('2 общих интереса'), findsNothing);
  });

  testWidgets('tonight dating cards render profile photos', (
    tester,
  ) async {
    await _pumpTonightApp(
      tester,
      extraOverrides: [
        peopleProvider.overrideWith(
          (ref) async => const [
            PersonSummary(
              id: 'user-sergey',
              name: 'Сергей',
              age: 31,
              area: 'Центр',
              common: ['Музыка', 'Бары'],
              online: true,
              verified: true,
              vibe: 'джаз',
              avatarUrl: 'https://cdn.example.com/sergey.jpg',
            ),
          ],
        ),
      ],
    );

    await _dragUntilVisible(tester, find.text('Сергей, 31'), 420);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is BbProfilePhotoImage &&
            widget.imageUrl == 'https://cdn.example.com/sergey.jpg' &&
            widget.usageProfile == BbImageUsageProfile.card,
      ),
      findsOneWidget,
    );
  });

  testWidgets('tonight dating preview opens v5 dating, not old user profile', (
    tester,
  ) async {
    await _pumpTonightApp(
      tester,
      extraOverrides: [
        peopleProvider.overrideWith(
          (ref) async => const [
            PersonSummary(
              id: 'user-dasha',
              name: 'Даша',
              age: 34,
              area: 'Патриаршие пруды',
              common: ['Кино', 'Вино'],
              online: true,
              verified: true,
              vibe: 'вечер',
              avatarUrl: 'https://cdn.example.com/dasha.jpg',
            ),
          ],
        ),
      ],
    );

    await _dragUntilVisible(tester, find.text('Даша, 34'), 420);
    await tester.tap(find.text('Даша, 34'));
    await tester.pumpAndSettle();

    expect(find.text('Дейтинг · свидания'), findsOneWidget);
    expect(find.text('Встреч'), findsNothing);
    expect(find.text('Рейтинг'), findsNothing);
  });

  testWidgets('tonight does not fall back to old poster teaser', (
    tester,
  ) async {
    await _pumpTonightApp(
      tester,
      extraOverrides: [
        afficheEventsProvider.overrideWith(
          (ref, query) async => const <AfficheEvent>[],
        ),
      ],
    );

    await _dragUntilVisible(
      tester,
      find.text('Пока нет событий в афише'),
      420,
    );

    expect(find.text('Пока нет событий в афише'), findsOneWidget);
    expect(find.text('Что в городе'), findsNothing);
    expect(find.text('Афиша рядом'), findsNothing);
  });

  testWidgets('tonight gathering cards render event source images', (
    tester,
  ) async {
    await _pumpTonightDirect(
      tester,
      extraOverrides: [
        eventsProvider.overrideWith(
          (ref, filter) async => [_eventFromAfficheFixture],
        ),
      ],
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is BbExternalEventImage &&
            widget.imageUrl == 'https://cdn.example.com/affiche-meetup.jpg',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tonight metrics does not start chat or session providers', (
    tester,
  ) async {
    var meetupChatReads = 0;
    var sessionReads = 0;

    await _pumpTonightDirect(
      tester,
      extraOverrides: [
        meetupChatsProvider.overrideWith((ref) async {
          meetupChatReads += 1;
          return const [];
        }),
        eveningSessionsProvider.overrideWith((ref) async {
          sessionReads += 1;
          return const [];
        }),
      ],
    );

    await _dragUntilVisible(tester, find.text('Сводка'), 420);

    expect(meetupChatReads, 0);
    expect(sessionReads, 0);
  });
}

Future<void> _pumpTonightDirect(
  WidgetTester tester, {
  List<Override> extraOverrides = const [],
}) async {
  _useTallPhoneViewport(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...buildTestOverrides(),
        afficheEventsProvider.overrideWith(
          (ref, query) async => _afficheFixtures,
        ),
        ...extraOverrides,
      ],
      child: const MaterialApp(
        home: TonightScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTonightApp(
  WidgetTester tester, {
  List<Override> extraOverrides = const [],
}) async {
  if (tester.view.physicalSize.height <= 700) {
    _useTallPhoneViewport(tester);
  }

  SharedPreferences.setMockInitialValues({
    'auth.tokens':
        '{"accessToken":"access-token","refreshToken":"refresh-token"}',
  });
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    BigBreakRoot(
      overrides: [
        ...buildTestOverrides(),
        initialAuthTokensProvider.overrideWithValue(
          const AuthTokens(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        afficheEventsProvider.overrideWith(
          (ref, query) async => _afficheFixtures,
        ),
        ...extraOverrides,
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void _useTallPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _dragUntilVisible(
  WidgetTester tester,
  Finder finder,
  double moveStep, {
  int maxScrolls = 40,
}) async {
  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final start = Offset(logicalSize.width / 2, logicalSize.height * 0.28);

  for (var i = 0; i < maxScrolls && finder.evaluate().isEmpty; i++) {
    await tester.dragFrom(start, Offset(0, -moveStep));
    await tester.pumpAndSettle();
  }

  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
}

class _ImmediateMapkitBootstrap implements MapkitBootstrap {
  const _ImmediateMapkitBootstrap();

  @override
  Future<void> ensureInitialized() async {}
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

const _afficheFixtures = [
  AfficheEvent(
    id: 'affiche-standup',
    title: 'Стендап-четверг',
    description: 'Вечер локальных комиков',
    city: 'Москва',
    venue: 'Stand-Up Store',
    address: 'Петровка 21',
    latitude: 55.765,
    longitude: 37.62,
    startsAt: null,
    endsAt: null,
    dateLabel: 'Сегодня',
    timeLabel: '21:00',
    category: 'комедия',
    priceFrom: 1200,
    priceMode: AffichePriceMode.paid,
    currency: 'RUB',
    imageUrl: null,
    provider: 'mock',
    sourceCode: 'mock',
    actionUrl: null,
    actionKind: 'details',
    isAffiliate: false,
    tags: ['комедия'],
  ),
  AfficheEvent(
    id: 'affiche-run',
    title: 'Утренний забег',
    description: 'Легкий старт в парке',
    city: 'Москва',
    venue: 'Парк Горького',
    address: 'Крымский Вал',
    latitude: 55.729,
    longitude: 37.603,
    startsAt: null,
    endsAt: null,
    dateLabel: 'Суббота',
    timeLabel: '08:00',
    category: 'спорт',
    priceFrom: null,
    priceMode: AffichePriceMode.free,
    currency: 'RUB',
    imageUrl: null,
    provider: 'mock',
    sourceCode: 'mock',
    actionUrl: null,
    actionKind: 'details',
    isAffiliate: false,
    tags: ['спорт'],
  ),
];

const _tonightRouteTemplate = EveningRouteTemplateSummary(
  id: 'template-backend-route',
  routeId: 'route-backend',
  title: 'Backend маршрут',
  blurb: 'Реальный шаблон из API',
  city: 'Москва',
  area: 'Патрики',
  vibe: 'спокойно',
  budget: 'mid',
  durationLabel: '2 часа',
  totalPriceFrom: 1800,
  totalSavings: 300,
  hostsCount: 4,
  stepsPreview: [
    EveningRouteTemplateStepPreview(
      title: 'Кофе',
      venue: 'Кофейня',
      emoji: '☕',
      time: '19:00',
      kind: 'cafe',
    ),
    EveningRouteTemplateStepPreview(
      title: 'Кино',
      venue: 'Кинотеатр',
      emoji: '🎬',
      time: '20:30',
      kind: 'show',
    ),
  ],
  partnerOffersPreview: [],
  nearestSessions: [],
);

final _eventFromAfficheFixture = Event.fromJson({
  'id': 'event-affiche',
  'title': 'Идем на концерт',
  'emoji': '🎵',
  'time': 'Сегодня · 18:00',
  'startsAtIso': '2026-05-07T15:00:00.000Z',
  'place': 'Клуб',
  'distance': '1.2 км',
  'attendees': ['Аня'],
  'going': 2,
  'capacity': 8,
  'vibe': 'Спокойно',
  'tone': 'warm',
  'joined': false,
  'imageUrl': 'https://cdn.example.com/affiche-meetup.jpg',
});
