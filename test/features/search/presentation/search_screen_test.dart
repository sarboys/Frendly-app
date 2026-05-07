import 'dart:async';

import 'package:big_break_mobile/features/search/presentation/search_screen.dart';
import 'package:big_break_mobile/features/search/presentation/search_providers.dart';
import 'package:big_break_mobile/features/after_dark/presentation/after_dark_models.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/mock_data.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_filters.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:big_break_mobile/shared/widgets/bb_chip.dart';
import 'package:big_break_mobile/shared/widgets/bb_event_card.dart';
import 'package:big_break_mobile/shared/widgets/bb_search_bar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_overrides.dart';

class _FakeSearchRepository extends BackendRepository {
  _FakeSearchRepository({
    required super.ref,
    required super.dio,
  });

  @override
  Future<PaginatedResponse<Event>> fetchEvents({
    String filter = 'nearby',
    String? q,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? date,
    String? cursor,
    int limit = 20,
    double? latitude,
    double? longitude,
    double? radiusKm,
    double? southWestLatitude,
    double? southWestLongitude,
    double? northEastLatitude,
    double? northEastLongitude,
    CancelToken? cancelToken,
  }) async {
    return PaginatedResponse(
      items: mockEvents,
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<PersonSummary>> fetchPeople({
    String? q,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final normalized = q?.trim().toLowerCase() ?? '';
    final items = mockPeople
        .map(
      (item) => PersonSummary(
        id: item.name,
        name: item.name,
        age: item.age,
        area: item.area,
        common: item.common,
        online: item.online,
        verified: item.verified,
        vibe: item.vibe,
        avatarUrl: null,
      ),
    )
        .where((person) {
      if (normalized.isEmpty) {
        return true;
      }
      final haystack = [
        person.name,
        person.area ?? '',
        person.vibe ?? '',
        ...person.common,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList(growable: false);

    return PaginatedResponse(
      items: items,
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<EveningSessionSummary>> fetchEveningSessions({
    int limit = 20,
  }) async {
    return const PaginatedResponse(
      items: [
        EveningSessionSummary(
          id: 'session-cozy',
          routeId: 'r-cozy-circle',
          chatId: 'chat-cozy',
          phase: EveningSessionPhase.scheduled,
          chatPhase: MeetupPhase.soon,
          privacy: EveningPrivacy.open,
          title: 'Теплый круг на Покровке',
          vibe: 'Спокойный маршрут с вином',
          emoji: '🍇',
          area: 'Покровка',
          hostName: 'Аня К',
          joinedCount: 4,
          maxGuests: 10,
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<AfterDarkEvent>> fetchAfterDarkEvents({
    String? q,
    String? date,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return const PaginatedResponse(
      items: [
        AfterDarkEvent(
          id: 'ad-pokrovka',
          title: 'Velvet Room · Speakeasy',
          emoji: '🥃',
          category: 'nightlife',
          time: 'Сегодня · 23:00',
          district: 'Покровка',
          distanceKm: 1.4,
          going: 18,
          capacity: 30,
          ratio: 'Mixed',
          ageRange: '25–40',
          dressCode: 'Smart elegant',
          vibe: 'Тихий джаз',
          hostVerified: true,
          consentRequired: false,
          glow: 'magenta',
          priceFrom: 2500,
          joined: false,
          joinRequestStatus: null,
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<EveningRouteTemplateSummary>>
      fetchEveningRouteTemplates({
    String city = 'Москва',
    String? q,
    int limit = 20,
  }) async {
    return const PaginatedResponse(
      items: [
        EveningRouteTemplateSummary(
          id: 'tpl-pokrovka',
          routeId: 'route-pokrovka',
          title: 'Маршрут по Покровке',
          blurb: 'Вино, паста и мягкий финал вечера',
          city: 'Москва',
          area: 'Покровка',
          vibe: 'Спокойный маршрут',
          budget: 'mid',
          durationLabel: '2.5 часа',
          totalPriceFrom: 2800,
          stepsPreview: [],
          partnerOffersPreview: [],
          nearestSessions: [],
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<Poster>> fetchPosters({
    String? q,
    String? category,
    bool? featured,
    String? cursor,
    int limit = 24,
    String? date,
    CancelToken? cancelToken,
  }) async {
    return PaginatedResponse(
      items: [
        Poster(
          id: 'poster-pokrovka',
          title: 'Джаз на Покровке',
          category: PosterCategory.concert,
          emoji: '🎷',
          startsAt: DateTime(2026, 5, 3, 20),
          dateLabel: 'Вс, 3 мая',
          timeLabel: '20:00',
          venue: 'Покровка Hall',
          address: 'Покровка 12',
          distance: '1.2 км',
          priceFrom: 1800,
          ticketUrl: 'https://example.test',
          provider: 'Тест',
          tone: EventTone.evening,
          tags: ['джаз', 'вечер'],
          description: 'Камерный концерт',
          isFeatured: true,
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<GroupedSearchResults> searchGrouped({
    String? q,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? date,
    int meetupsLimit = 4,
    int eveningsLimit = 3,
    int routesLimit = 3,
    int postersLimit = 6,
    int afficheLimit = 6,
    String? city,
    CancelToken? cancelToken,
  }) async {
    final meetups = await fetchEvents(
      q: q,
      lifestyle: lifestyle,
      price: price,
      gender: gender,
      access: access,
      date: date,
      limit: meetupsLimit,
    );
    final evenings = await fetchAfterDarkEvents(
      q: q,
      date: date,
      limit: eveningsLimit,
    );
    final routes = await fetchEveningRouteTemplates(
      q: q,
      limit: routesLimit,
    );
    final posters = await fetchPosters(
      q: q,
      date: date,
      limit: postersLimit,
    );
    return GroupedSearchResults(
      meetups: meetups.items,
      evenings: evenings.items,
      routes: routes.items,
      posters: posters.items,
      affiche: const [],
    );
  }
}

class _CancellableSearchRepository extends BackendRepository {
  _CancellableSearchRepository({
    required super.ref,
    required super.dio,
  });

  final started = Completer<void>();
  CancelToken? capturedCancelToken;

  @override
  Future<GroupedSearchResults> searchGrouped({
    String? q,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? date,
    int meetupsLimit = 4,
    int eveningsLimit = 3,
    int routesLimit = 3,
    int postersLimit = 6,
    int afficheLimit = 6,
    String? city,
    CancelToken? cancelToken,
  }) async {
    capturedCancelToken = cancelToken;
    if (!started.isCompleted) {
      started.complete();
    }
    await Completer<void>().future;
    return const GroupedSearchResults(
      meetups: [],
      evenings: [],
      routes: [],
      posters: [],
      affiche: [],
    );
  }
}

Widget _wrap({
  List<Override> extraOverrides = const [],
  SearchPreset? preset,
}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      backendRepositoryProvider.overrideWith(
        (ref) => _FakeSearchRepository(ref: ref, dio: Dio()),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp(
      home: SearchScreen(preset: preset),
    ),
  );
}

void main() {
  test('search results cancels in-flight request when provider disposes',
      () async {
    late _CancellableSearchRepository repository;
    final container = ProviderContainer(
      overrides: [
        ...buildTestOverrides(),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _CancellableSearchRepository(ref: ref, dio: Dio());
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      searchResultsProvider(
        const SearchResultsQuery(
          query: 'джаз',
          activeFilters: [],
          sheetFilters: EventFilters.defaults,
        ),
      ),
      (_, __) {},
      fireImmediately: true,
    );
    await repository.started.future;

    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(repository.capturedCancelToken?.isCancelled, isTrue);
  });

  testWidgets('search uses v5 shell without old shared search widgets', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(BbV5Scaffold), findsOneWidget);
    expect(find.byType(BbSearchBar), findsNothing);
    expect(find.byType(BbChip), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'покров');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(BbEventCard), findsNothing);
  });

  testWidgets('search input keeps hint vertically centered', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField).first);

    expect(textField.decoration?.prefixIcon, isNull);
    expect(textField.decoration?.isCollapsed, isTrue);
    expect(textField.textInputAction, TextInputAction.search);
  });

  testWidgets('recent searches are hidden until the user searches', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Недавнее'), findsNothing);
    expect(find.text('Очистить'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'кофе');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Недавнее'), findsOneWidget);
    expect(find.text('кофе'), findsOneWidget);
  });

  testWidgets('recent searches keep only last three unique queries', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    for (final query in ['кофе', 'йога', 'кино', 'кофе', 'бранч']) {
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    expect(find.text('бранч'), findsOneWidget);
    expect(find.text('кофе'), findsOneWidget);
    expect(find.text('кино'), findsOneWidget);
    expect(find.text('йога'), findsNothing);
  });

  testWidgets('removing one recent item does not apply that search', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'настолки');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('настолки'), findsOneWidget);
    expect(find.text('Встречи · 5'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('recent-remove-настолки')));
    await tester.pumpAndSettle();

    expect(find.text('настолки'), findsNothing);
    expect(find.text('Встречи · 5'), findsNothing);
  });

  testWidgets('clear removes all recent items', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    for (final query in ['пробежка', 'винный вечер']) {
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    expect(find.text('пробежка'), findsOneWidget);
    expect(find.text('винный вечер'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-recents-clear')));
    await tester.pumpAndSettle();

    expect(find.text('настолки'), findsNothing);
    expect(find.text('пробежка'), findsNothing);
    expect(find.text('винный вечер'), findsNothing);
  });

  testWidgets('free quick filter shows filtered results without text query', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Бесплатно'));
    await tester.pumpAndSettle();

    expect(find.text('Встречи · 1'), findsOneWidget);
    expect(find.text('Вечерняя пробежка по бульварам'), findsOneWidget);
    expect(find.text('Винный вечер на крыше'), findsNothing);
  });

  testWidgets(
      'search results are grouped by meetups, evenings, routes and posters', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'покров');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Встречи · 1'), findsOneWidget);
    expect(find.text('Вечера · 1'), findsOneWidget);
    expect(find.text('Маршруты · 1'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
    expect(find.textContaining('Люди ·'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text('Маршрут по Покровке'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('Афиша · 1'), findsOneWidget);
  });

  testWidgets('search shows after dark evenings instead of old session section',
      (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'velvet');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Вечера · 1'), findsOneWidget);
    expect(find.text('Velvet Room · Speakeasy'), findsOneWidget);
    expect(find.textContaining('Frendly Evenings ·'), findsNothing);
  });

  testWidgets('evenings preset opens results with active preset chips', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(preset: SearchPreset.evenings));
    await tester.pumpAndSettle();

    expect(find.text('Вечера рядом'), findsWidgets);
    expect(find.text('Frendly Evenings'), findsNothing);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Live'), findsWidgets);
    expect(find.text('Собираются'), findsWidgets);
    expect(find.text('Недавнее'), findsNothing);
  });

  testWidgets('nearby preset opens results and keeps map entry', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(preset: SearchPreset.nearby));
    await tester.pumpAndSettle();

    expect(find.text('Рядом с тобой'), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Рядом'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.textContaining('Встречи ·'), findsOneWidget);
    expect(find.text('Недавнее'), findsNothing);
  });

  testWidgets('search results use a lazy scroll view', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'вечер');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.textContaining('Встречи ·'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
