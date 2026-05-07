import 'package:big_break_mobile/app/app.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/features/tonight/presentation/tonight_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/tokens.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    expect(find.text('Город дышит —'), findsOneWidget);
    expect(find.text('Радар вечера'), findsOneWidget);
    expect(find.text('Сейчас собираются'), findsOneWidget);

    await _dragUntilVisible(tester, find.text('Дейтинг · рядом'), 420);
    await _dragUntilVisible(tester, find.text('Афиша города'), 420);
    await _dragUntilVisible(tester, find.text('Маршруты вечера'), 420);
    await _dragUntilVisible(tester, find.text('Пульс города'), 420);
    await _dragUntilVisible(tester, find.text('AI compass'), 420);

    expect(find.text('Frendly Evening'), findsNothing);
    expect(find.text('Frendly Evenings'), findsNothing);
    expect(find.text('Идут и собираются'), findsNothing);
    expect(find.text('Твои встречи сегодня'), findsNothing);
    expect(find.text('Рядом с тобой'), findsNothing);
    expect(find.text('Что в городе'), findsNothing);
    expect(find.text('Билеты на эту неделю'), findsNothing);
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

  testWidgets('tonight gathering CTA opens search preset', (
    tester,
  ) async {
    await _pumpTonightApp(tester);

    await _dragUntilVisible(
      tester,
      find.byKey(const ValueKey('tonight-gathering-all')),
      260,
    );
    await tester.tap(find.byKey(const ValueKey('tonight-gathering-all')));
    await tester.pumpAndSettle();

    expect(find.text('Рядом с тобой'), findsOneWidget);
    expect(find.text('Недавнее'), findsNothing);
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
