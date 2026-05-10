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
            const _NoLocationService(),
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
    required this.events,
  });

  final List<Event> events;

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
    return PaginatedResponse<Event>(
      items: events,
      nextCursor: null,
    );
  }
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
