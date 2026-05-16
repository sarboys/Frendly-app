import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/features/meetups/presentation/meetups_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

final _meetupsRefreshVersionProvider = StateProvider<int>((ref) => 0);

void main() {
  test('promoted meetups stay above regular meetups for every sort', () {
    final regularSoon = _event('regular-soon', DateTime(2026, 5, 9, 18));
    final promotedLater = _event('promoted-later', DateTime(2026, 5, 9, 22));
    final regularPopular =
        _event('regular-popular', DateTime(2026, 5, 9, 17), going: 8);

    expect(
      sortMeetupsForTest(
        [regularSoon, promotedLater, regularPopular],
        promotedIds: {'promoted-later'},
        sort: MeetupsSortForTest.time,
      ).map((event) => event.id),
      ['promoted-later', 'regular-popular', 'regular-soon'],
    );

    expect(
      sortMeetupsForTest(
        [regularSoon, promotedLater, regularPopular],
        promotedIds: {'promoted-later'},
        sort: MeetupsSortForTest.popular,
      ).map((event) => event.id),
      ['promoted-later', 'regular-popular', 'regular-soon'],
    );
  });

  test('week filter stops at the end of the current local week', () {
    final now = DateTime(2026, 5, 9, 12);

    expect(
      meetupMatchesWhenForTest(
        _event('sat', DateTime(2026, 5, 9, 18)),
        'На неделе',
        now: now,
      ),
      isTrue,
    );
    expect(
      meetupMatchesWhenForTest(
        _event('sun', DateTime(2026, 5, 10, 18)),
        'На неделе',
        now: now,
      ),
      isTrue,
    );
    expect(
      meetupMatchesWhenForTest(
        _event('mon', DateTime(2026, 5, 11, 18)),
        'На неделе',
        now: now,
      ),
      isFalse,
    );
  });

  test('weekend filter includes Saturday when today is Saturday', () {
    final now = DateTime(2026, 5, 9, 12);

    expect(
      meetupMatchesWhenForTest(
        _event('sat', DateTime(2026, 5, 9, 18)),
        'Выходные',
        now: now,
      ),
      isTrue,
    );
    expect(
      meetupMatchesWhenForTest(
        _event('sun', DateTime(2026, 5, 10, 18)),
        'Выходные',
        now: now,
      ),
      isTrue,
    );
    expect(
      meetupMatchesWhenForTest(
        _event('mon', DateTime(2026, 5, 11, 18)),
        'Выходные',
        now: now,
      ),
      isFalse,
    );
  });

  test('event feed ISO dates are parsed as local dates for filters', () {
    final event = _event('utc-event', DateTime.utc(2026, 5, 9, 18));

    expect(eventDateForTest(event).isUtc, isFalse);
  });

  testWidgets('meetup list labels tomorrow events as tomorrow', (
    tester,
  ) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 15);
    final event = _event(
      'tomorrow-walk',
      tomorrow,
      time: 'Завтра · 15:00',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authBootstrapProvider.overrideWith((ref) async {}),
          appLocationServiceProvider.overrideWithValue(
            const _FixedLocationService(),
          ),
          backendRepositoryProvider.overrideWith(
            (ref) => _MeetupsRepository(
              ref: ref,
              dio: Dio(),
              events: [event],
            ),
          ),
        ],
        child: const MaterialApp(home: MeetupsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Завтра'));
    await tester.pumpAndSettle();

    expect(find.text('ЗАВТРА'), findsOneWidget);
    expect(find.text('СЕГОДНЯ'), findsNothing);
  });

  testWidgets('today meetups request includes backend date on initial load', (
    tester,
  ) async {
    final requestedDates = <String?>[];
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authBootstrapProvider.overrideWith((ref) async {}),
          appLocationServiceProvider.overrideWithValue(
            const _FixedLocationService(),
          ),
          backendRepositoryProvider.overrideWith(
            (ref) => _MeetupsRepository(
              ref: ref,
              dio: Dio(),
              events: const [],
              requestedDates: requestedDates,
            ),
          ),
        ],
        child: const MaterialApp(home: MeetupsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(requestedDates, [_isoDateForTest(now)]);
  });

  testWidgets('meetup list keeps rows and scroll offset during refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final pendingRefresh = Completer<List<Event>>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 18);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authBootstrapProvider.overrideWith((ref) async {}),
          appLocationServiceProvider.overrideWithValue(
            const _FixedLocationService(),
          ),
          backendRepositoryProvider.overrideWith(
            (ref) => _MeetupsRepository(
              ref: ref,
              dio: Dio(),
              eventsLoader: () {
                final version =
                    ref.read(_meetupsRefreshVersionProvider.notifier).state;
                if (version == 0) {
                  return Future.value(
                    List.generate(
                      18,
                      (index) => _event(
                        'meetup-$index',
                        today.add(Duration(minutes: index)),
                      ),
                    ),
                  );
                }
                return pendingRefresh.future;
              },
            ),
          ),
        ],
        child: const MaterialApp(home: MeetupsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('meetup-v5-event-meetup-0')), findsOneWidget);

    final scrollable = find.byType(Scrollable).last;
    await tester.drag(scrollable, const Offset(0, -520));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));

    final context = tester.element(find.byType(MeetupsScreen));
    ProviderScope.containerOf(context, listen: false)
        .read(_meetupsRefreshVersionProvider.notifier)
        .state = 1;
    final refreshIndicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    final refreshFuture = refreshIndicator.onRefresh();
    await tester.pump();

    final during = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(during, closeTo(before, 0.1));
    expect(
        find.byKey(const ValueKey('meetup-v5-event-meetup-5')), findsWidgets);

    pendingRefresh.complete(
      List.generate(
        18,
        (index) => _event(
          'meetup-$index',
          today.add(Duration(minutes: index)),
        ),
      ),
    );
    await refreshFuture;
    await tester.pumpAndSettle();

    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, closeTo(before, 0.1));
  });
}

Event _event(
  String id,
  DateTime startsAt, {
  int going = 1,
  String? time,
}) {
  return Event(
    id: id,
    title: 'Кофе',
    emoji: '☕',
    time: time ?? 'Сегодня · 18:00',
    startsAtIso: startsAt.toIso8601String(),
    place: 'Brix',
    distance: '1 км',
    attendees: const [],
    going: going,
    capacity: 6,
    vibe: 'Спокойно',
    tone: EventTone.warm,
    joined: false,
  );
}

class _MeetupsRepository extends BackendRepository {
  _MeetupsRepository({
    required super.ref,
    required super.dio,
    this.events = const [],
    this.eventsLoader,
    this.requestedDates,
  });

  final List<Event> events;
  final Future<List<Event>> Function()? eventsLoader;
  final List<String?>? requestedDates;

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
    requestedDates?.add(date);
    final loadedEvents = await eventsLoader?.call();
    return PaginatedResponse<Event>(
      items: loadedEvents ?? events,
      nextCursor: null,
    );
  }
}

String _isoDateForTest(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _FixedLocationService implements AppLocationService {
  const _FixedLocationService();

  @override
  Future<Position?> getCurrentPosition() async {
    return Position(
      longitude: 37.6173,
      latitude: 55.7558,
      timestamp: DateTime(2026, 5, 14),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

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
