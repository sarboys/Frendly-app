import 'package:big_break_mobile/features/meetups/presentation/meetups_screen.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

Event _event(String id, DateTime startsAt) {
  return Event(
    id: id,
    title: 'Кофе',
    emoji: '☕',
    time: 'Сегодня · 18:00',
    startsAtIso: startsAt.toIso8601String(),
    place: 'Brix',
    distance: '1 км',
    attendees: const [],
    going: 1,
    capacity: 6,
    vibe: 'Спокойно',
    tone: EventTone.warm,
    joined: false,
  );
}
