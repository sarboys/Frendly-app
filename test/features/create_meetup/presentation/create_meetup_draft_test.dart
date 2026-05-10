import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
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

    final draft = _draft(startsAt: startsAt);

    expect(draft.timeLabel, 'Завтра · 19:30');
  });

  test('submit description falls back to place when text is empty', () {
    final draft = _draft(
      description: '   ',
      place: 'Powerhouse · Казакова 8',
    );

    expect(draft.submitDescription, 'Встречаемся: Powerhouse · Казакова 8');
  });

  test('publish uses manual location when draft place has no coordinates', () {
    const manualLocation = ManualLocation(
      label: 'Москва',
      latitude: 55.7558,
      longitude: 37.6173,
      city: 'Москва',
    );

    final coordinates = createMeetupPublishCoordinatesForTest(
      _draft(),
      manualLocation,
    );

    expect(coordinates?.latitude, 55.7558);
    expect(coordinates?.longitude, 37.6173);
  });

  test('publish keeps exact place coordinates before manual location', () {
    const manualLocation = ManualLocation(
      label: 'Москва',
      latitude: 55.7558,
      longitude: 37.6173,
      city: 'Москва',
    );

    final coordinates = createMeetupPublishCoordinatesForTest(
      _draft(latitude: 55.7601, longitude: 37.6302),
      manualLocation,
    );

    expect(coordinates?.latitude, 55.7601);
    expect(coordinates?.longitude, 37.6302);
  });
}

CreateMeetupDraft _draft({
  DateTime? startsAt,
  String description = 'Встречаемся сегодня',
  String place = 'Brix',
  double? latitude,
  double? longitude,
}) {
  return CreateMeetupDraft(
    title: 'Кофе',
    description: description,
    emoji: '☕',
    vibe: 'Спокойно',
    place: place,
    startsAt: startsAt ?? DateTime(2026, 5, 10, 18),
    capacity: 6,
    mode: 'default',
    lifestyle: 'neutral',
    priceMode: 'free',
    accessMode: 'open',
    genderMode: 'all',
    visibilityMode: 'public',
    joinMode: EventJoinMode.open,
    idempotencyKey: 'test-key',
    latitude: latitude,
    longitude: longitude,
  );
}
