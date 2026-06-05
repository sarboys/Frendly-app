import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/meetings/application/new_meeting_payload.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('builds legacy create source payload from query params', () {
    expect(
      buildNewMeetingSourcePayload(
        inviteeUserId: ' u1 ',
        sourceChatId: ' chat-1 ',
        communityId: ' club-1 ',
        routeId: ' route-1 ',
      ),
      {
        'inviteeUserId': 'u1',
        'sourceChatId': 'chat-1',
        'communityId': 'club-1',
        'routeId': 'route-1',
      },
    );
  });

  test('builds create event base payload for backend contract', () {
    final payload = buildNewMeetingBasePayload(
      title: 'Кофе',
      description: 'Встречаемся после работы',
      vibe: 'Кофе',
      place: 'Duo',
      address: 'Рубинштейна 20',
      startsAt: DateTime.utc(2026, 5, 20, 16),
      capacity: 6,
      gender: 'any',
      visibility: 'private',
      city: 'Санкт-Петербург',
    );

    expect(payload, {
      'title': 'Кофе',
      'description': 'Встречаемся после работы',
      'emoji': '☕',
      'vibe': 'Кофе',
      'place': 'Duo, Рубинштейна 20',
      'address': 'Рубинштейна 20',
      'city': 'Санкт-Петербург',
      'startsAt': '2026-05-20T16:00:00.000Z',
      'capacity': 6,
      'genderMode': 'all',
      'visibilityMode': 'friends',
      'visibility': 'private',
      'accessMode': 'request',
      'joinMode': 'request',
      'priceMode': 'free',
    });
  });

  test('serializes local meeting start time as UTC for backend validation', () {
    final startsAt = DateTime(2026, 5, 20, 20, 15);
    final payload = buildNewMeetingBasePayload(
      title: 'Кофе',
      description: 'Встречаемся после работы',
      vibe: 'Кофе',
      place: 'Duo',
      address: '',
      startsAt: startsAt,
      capacity: 6,
      gender: 'any',
      visibility: 'public',
    );

    expect(payload['startsAt'], startsAt.toUtc().toIso8601String());
    final serializedStartsAt = payload['startsAt'];
    expect(
      serializedStartsAt,
      isA<String>().having(
        (value) => value,
        'UTC marker',
        endsWith('Z'),
      ),
    );
  });

  test('parses Moscow meeting wall time as Moscow UTC offset', () {
    final startsAt = parseNewMeetingStartsAt(
      date: '2026-05-27',
      time: '19:00',
      city: 'Москва',
    );

    expect(startsAt, DateTime.utc(2026, 5, 27, 16));
  });

  test('builds create event entry requirement payload', () {
    final payload = buildNewMeetingBasePayload(
      title: 'Кофе',
      description: 'Встречаемся после работы',
      vibe: 'Кофе',
      place: 'Duo',
      address: '',
      startsAt: DateTime.utc(2026, 5, 20, 16),
      capacity: 6,
      gender: 'any',
      visibility: 'public',
      requiresVerification: true,
      requiresFrendlyPlus: true,
    );

    expect(payload['requiresVerification'], true);
    expect(payload['requiresFrendlyPlus'], true);
  });

  test('shows clear create meeting coordinate errors', () {
    expect(
      newMeetingCreateFailureMessage(code: 'event_coordinates_required'),
      'Не нашли точку на карте. Укажи адрес точнее',
    );
    expect(
      newMeetingCreateFailureMessage(code: 'event_source_coordinates_missing'),
      'У выбранного места нет точки на карте. Выбери другое',
    );
    expect(
      newMeetingCreateFailureMessage(
        code: 'invalid_event_payload',
        message: 'startsAt is invalid',
      ),
      'Время уже прошло. Выбери будущее',
    );
    expect(
      newMeetingCreateFailureMessage(
        code: 'event_weekly_limit_reached',
        details: {'limit': 10},
      ),
      'Лимит встреч на неделю: 10. Нужен Frendly+ или новая неделя',
    );
    expect(
      newMeetingCreateFailureMessage(code: 'content_moderation_rejected'),
      'Текст не прошел проверку. Измени формулировку',
    );
    expect(
      newMeetingCreateFailureMessage(code: 'unknown'),
      'Backend не создал встречу',
    );
  });

  test('builds request-only join payload independent from visibility', () {
    final payload = buildNewMeetingBasePayload(
      title: 'Кофе',
      description: 'Встречаемся после работы',
      vibe: 'Кофе',
      place: 'Duo',
      address: '',
      startsAt: DateTime.utc(2026, 5, 20, 16),
      capacity: 6,
      gender: 'any',
      visibility: 'public',
      joinPolicy: 'request',
    );

    expect(payload['visibilityMode'], 'public');
    expect(payload['accessMode'], 'request');
    expect(payload['joinMode'], 'request');
  });

  test('builds open join payload for public meeting', () {
    final payload = buildNewMeetingBasePayload(
      title: 'Кофе',
      description: 'Встречаемся после работы',
      vibe: 'Кофе',
      place: 'Duo',
      address: '',
      startsAt: DateTime.utc(2026, 5, 20, 16),
      capacity: 6,
      gender: 'any',
      visibility: 'public',
      joinPolicy: 'open',
    );

    expect(payload['visibilityMode'], 'public');
    expect(payload['accessMode'], 'open');
    expect(payload['joinMode'], 'open');
  });

  test('builds full community meetup payload for admin inline publish', () {
    final payload = {
      ...buildNewMeetingBasePayload(
        title: 'Винил-вечер',
        description: 'Слушаем пластинки и знакомимся',
        vibe: 'Музыка',
        place: 'Patriki',
        address: '',
        startsAt: DateTime.utc(2026, 5, 22, 18, 30),
        capacity: 12,
        gender: 'any',
        visibility: 'public',
        city: 'Москва',
      ),
      ...buildNewMeetingSourcePayload(communityId: ' wine '),
    };

    expect(payload['communityId'], 'wine');
    expect(payload['title'], 'Винил-вечер');
    expect(payload['description'], 'Слушаем пластинки и знакомимся');
    expect(payload['startsAt'], '2026-05-22T18:30:00.000Z');
    expect(payload['capacity'], 12);
    expect(payload['city'], 'Москва');
    expect(payload['accessMode'], 'open');
  });

  test('validates create meeting draft before publish', () {
    expect(
      validateNewMeetingDraft(
        title: '',
        description: 'Описание',
        place: 'Duo',
        startsAt: DateTime.utc(2026, 5, 20, 16),
      ),
      NewMeetingDraftValidation.missingRequired,
    );
    expect(
      validateNewMeetingDraft(
        title: 'Кофе',
        description: 'Описание',
        place: 'Duo',
        startsAt: null,
      ),
      NewMeetingDraftValidation.invalidDateTime,
    );
    expect(
      validateNewMeetingDraft(
        title: 'Кофе',
        description: 'Описание',
        place: 'Duo',
        startsAt: DateTime.utc(2026, 5, 20, 16),
      ),
      NewMeetingDraftValidation.valid,
    );
  });

  test('blocks boosted meeting publish when balance is lower than boost price',
      () {
    expect(
      canPublishMeetingWithBoost(boostPrice: 100, walletBalance: 0),
      isFalse,
    );
    expect(
      canPublishMeetingWithBoost(boostPrice: 100, walletBalance: 100),
      isTrue,
    );
    expect(
      canPublishMeetingWithBoost(boostPrice: null, walletBalance: 0),
      isTrue,
    );
  });

  test('attached route overrides query route source', () {
    expect(
      buildNewMeetingSourcePayload(
        routeId: 'route-from-query',
        attachedRouteId: 'route-from-picker',
      ),
      {
        'routeId': 'route-from-picker',
      },
    );
  });

  test('builds route source prefill draft from route detail', () {
    final draft = buildNewMeetingRoutePrefill(
      const BackendCardItem(
        id: 'route-1',
        title: 'Барный маршрут',
        subtitle: 'Центр',
        raw: {
          'area': 'Центр',
          'durationLabel': '2 часа',
          'blurb': 'Три места рядом, без долгих переходов',
        },
      ),
    );

    expect(draft.id, 'route-1');
    expect(draft.attachedTitle, 'Барный маршрут');
    expect(draft.attachedSubtitle, 'Центр · 2 часа');
    expect(draft.title, 'Барный маршрут');
    expect(draft.description, 'Три места рядом, без долгих переходов');
    expect(draft.place, 'Барный маршрут');
    expect(draft.address, 'Центр');
  });

  test('uses current route id from route template for publish', () {
    final draft = buildNewMeetingRoutePrefill(
      const BackendCardItem(
        id: 'template-1',
        title: 'Спокойный вечер',
        raw: {
          'routeId': 'route-current-1',
          'area': 'Москва',
          'durationLabel': '2.5 часа',
        },
      ),
    );

    expect(draft.id, 'route-current-1');
    expect(
      buildNewMeetingSourcePayload(attachedRouteId: draft.id),
      {'routeId': 'route-current-1'},
    );
  });

  test('builds route source prefill draft from confirmed evening route steps',
      () {
    final draft = buildNewMeetingRoutePrefill(
      const BackendCardItem(
        id: 'route-ai-1',
        title: 'AI маршрут на вечер',
        raw: {
          'area': 'Патрики',
          'durationLabel': '3 часа',
          'blurb': 'Бар и стендап рядом',
          'steps': [
            {
              'title': 'Brix',
              'venue': 'Brix Bar',
              'address': 'Покровка 12',
              'lat': 55.751,
              'lng': 37.611,
            },
            {
              'title': 'Стендап',
              'venue': 'Stage',
              'address': 'Тверская 1',
              'lat': 55.765,
              'lng': 37.615,
            },
          ],
        },
      ),
    );

    expect(draft.id, 'route-ai-1');
    expect(draft.title, 'AI маршрут на вечер');
    expect(draft.description, 'Бар и стендап рядом');
    expect(draft.place, 'Brix Bar');
    expect(draft.address, 'Покровка 12');
    expect(draft.latitude, 55.751);
    expect(draft.longitude, 37.611);
  });

  test('builds route source prefill draft from event route points', () {
    final draft = buildNewMeetingRoutePrefill(
      const BackendCardItem(
        id: 'route-ai-2',
        title: 'AI маршрут с точками',
        raw: {
          'area': 'Центр',
          'durationLabel': '2 часа',
          'description': 'Кофе, концерт и прогулка',
          'routePoints': [
            {
              'title': 'Кофе у бара',
              'venue': 'Brew Lab',
              'address': 'Цветной 12',
              'latitude': 55.755,
              'longitude': 37.62,
            },
          ],
        },
      ),
    );

    expect(draft.id, 'route-ai-2');
    expect(draft.place, 'Brew Lab');
    expect(draft.address, 'Цветной 12');
    expect(draft.latitude, 55.755);
    expect(draft.longitude, 37.62);
  });

  test('builds affiche source prefill draft from poster detail', () {
    final draft = buildNewMeetingAffichePrefill(
      BackendCardItem(
        id: 'poster-1',
        title: 'Джаз вечер',
        startsAt: DateTime(2026, 5, 20, 19, 30),
        latitude: 59.932,
        longitude: 30.347,
        raw: const {
          'description': 'Живая музыка и кофе',
          'venueName': 'Клуб 44',
          'place': {'address': 'Невский 10'},
        },
      ),
    );

    expect(draft.id, 'poster-1');
    expect(draft.attachedTitle, 'Джаз вечер');
    expect(draft.attachedSubtitle, '20.5 · 19:30 · Клуб 44');
    expect(draft.title, 'Идем на Джаз вечер');
    expect(draft.description, 'Живая музыка и кофе');
    expect(draft.dateInput, '2026-05-20');
    expect(draft.timeInput, '19:30');
    expect(draft.place, 'Клуб 44');
    expect(draft.address, 'Невский 10');
    expect(draft.latitude, 59.932);
    expect(draft.longitude, 30.347);
  });

  test('debounces place search query before provider reads it', () {
    final timers = <_FakeTimer>[];
    final debouncer = NewMeetingPlaceSearchDebouncer(
      delay: const Duration(milliseconds: 300),
      timerFactory: (_, callback) {
        final timer = _FakeTimer(callback);
        timers.add(timer);
        return timer;
      },
    );
    addTearDown(debouncer.dispose);

    debouncer.update('b');
    expect(debouncer.query, '');

    debouncer.update('bar  ');
    expect(timers.first.isActive, false);
    expect(debouncer.query, '');

    timers.last.fire();
    expect(debouncer.query, 'bar');
  });

  test('keeps one create idempotency key for draft retries', () {
    var tick = 1000;
    final draftKey = NewMeetingCreateIdempotency(
      timestampFactory: () => tick++,
    );

    final first = draftKey.currentKey();
    final retry = draftKey.currentKey();

    expect(first, 'mobile2-1000');
    expect(retry, first);
    expect(tick, 1001);
  });
}

class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function() _callback;
  var _active = true;

  void fire() {
    if (!_active) {
      return;
    }
    _active = false;
    _callback();
  }

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
