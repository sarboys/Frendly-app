import 'package:big_break_mobile/features/meetups/presentation/meetups_screen.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

Event _event(String id, DateTime startsAt, {int going = 1}) {
  return Event(
    id: id,
    title: 'Кофе',
    emoji: '☕',
    time: 'Сегодня · 18:00',
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
