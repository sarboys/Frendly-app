import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draft time label keeps tomorrow date in publish preview', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startsAt = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      19,
      30,
    );

    final draft = CreateMeetupDraft(
      title: 'Вечер',
      description: 'Описание',
      emoji: '✨',
      vibe: 'chill',
      place: 'Парк',
      startsAt: startsAt,
      capacity: 4,
      mode: 'default',
      lifestyle: 'any',
      priceMode: 'free',
      accessMode: 'open',
      genderMode: 'all',
      visibilityMode: 'public',
      joinMode: EventJoinMode.open,
      idempotencyKey: 'test',
    );

    expect(draft.timeLabel, 'Завтра · 19:30');
  });
}
