import 'package:big_break_mobile/app/core/config/backend_config.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves relative event image urls through api base url', () {
    final event = Event.fromJson({
      'id': 'event-1',
      'title': 'Идем на концерт',
      'emoji': '🎵',
      'time': 'Сегодня · 18:00',
      'startsAtIso': '2026-05-07T15:00:00.000Z',
      'place': 'Клуб',
      'distance': '1.2 км',
      'attendees': [],
      'going': 1,
      'capacity': 8,
      'vibe': 'Спокойно',
      'tone': 'warm',
      'joined': false,
      'imageUrl': '/affiche/images?key=external-content%2Fitem.jpg',
    });
    final dynamic dynamicEvent = event;

    expect(
      dynamicEvent.imageUrl,
      '${BackendConfig.apiBaseUrl}/affiche/images?key=external-content%2Fitem.jpg',
    );
  });

  test('maps paid ticket summary for affiche backed events', () {
    final event = Event.fromJson({
      'id': 'event-ticket',
      'title': 'Идем на концерт',
      'emoji': '🎵',
      'time': 'Сегодня · 18:00',
      'startsAtIso': '2026-05-07T15:00:00.000Z',
      'place': 'Клуб',
      'distance': '1.2 км',
      'attendees': [],
      'going': 1,
      'capacity': 8,
      'vibe': 'Спокойно',
      'tone': 'warm',
      'joined': false,
      'ticketUrl': 'https://tickets.example/show',
      'ticketSourceKind': 'affiche',
      'ticketSourceId': 'affiche-1',
      'ticketPriceFrom': 1500,
      'ticketProvider': 'Ticketland',
      'ticketVenue': 'Live Arena',
    });

    expect(event.ticketUrl, 'https://tickets.example/show');
    expect(event.ticketSourceKind, EventTicketSourceKind.affiche);
    expect(event.ticketSourceId, 'affiche-1');
    expect(event.ticketPriceFrom, 1500);
    expect(event.ticketProvider, 'Ticketland');
    expect(event.ticketVenue, 'Live Arena');
    expect(event.hasPaidTicket, isTrue);
  });

  test('maps radar category fields from event json', () {
    final event = Event.fromJson({
      'id': 'event-route-date',
      'title': 'Маршрут на двоих',
      'emoji': '✨',
      'time': 'Сегодня · 18:00',
      'place': 'Центр',
      'distance': '1.2 км',
      'attendees': [],
      'going': 1,
      'capacity': 2,
      'vibe': 'Свидание',
      'tone': 'warm',
      'joined': false,
      'routeId': 'r-date-route',
      'isDate': true,
    });

    expect(event.routeId, 'r-date-route');
    expect(event.isDate, isTrue);
  });

  test('maps event entry requirement flags from summary json', () {
    final event = Event.fromJson({
      'id': 'event-locked',
      'title': 'Закрытый ужин',
      'emoji': '🍷',
      'time': 'Сегодня · 18:00',
      'place': 'Brix',
      'distance': '1.2 км',
      'attendees': [],
      'going': 1,
      'capacity': 8,
      'vibe': 'Спокойно',
      'tone': 'warm',
      'joined': false,
      'requiresVerification': true,
      'requiresFrendlyPlus': true,
    });

    expect(event.requiresVerification, isTrue);
    expect(event.requiresFrendlyPlus, isTrue);
  });

  test('maps event detail entry requirement viewer state', () {
    final detail = EventDetail.fromJson({
      'id': 'event-locked',
      'title': 'Закрытый ужин',
      'emoji': '🍷',
      'time': 'Сегодня · 18:00',
      'place': 'Brix',
      'distance': '1.2 км',
      'vibe': 'Спокойно',
      'description': 'Только с доступом',
      'hostNote': null,
      'joined': false,
      'partnerName': null,
      'partnerOffer': null,
      'capacity': 8,
      'going': 1,
      'chatId': null,
      'requiresVerification': true,
      'requiresFrendlyPlus': true,
      'entryRequirements': {
        'canJoin': false,
        'missing': ['verification', 'frendly_plus'],
      },
      'host': {
        'id': 'host-1',
        'displayName': 'Никита',
        'verified': true,
        'rating': 4.9,
        'meetupCount': 10,
        'avatarUrl': null,
      },
      'attendees': [],
    });

    expect(detail.requiresVerification, isTrue);
    expect(detail.requiresFrendlyPlus, isTrue);
    expect(detail.entryRequirements.canJoin, isFalse);
    expect(detail.entryRequirements.missingVerification, isTrue);
    expect(detail.entryRequirements.missingFrendlyPlus, isTrue);
  });

  test('maps event detail route stop booking and ticket metadata', () {
    final stop = EventDetailRouteStop.fromJson({
      'title': 'Late jazz в Aglio',
      'address': 'Маросейка 6',
      'time': '22:00',
      'ticketUrl': 'https://tomesto.example/aglio',
      'ticketPrice': 800,
      'ticketProvider': 'Tomesto',
      'ticketSourceCode': 'tomesto',
      'sourceUrl': 'https://tomesto.ru/moskva/places/aglio',
      'bookingUrl': 'https://tomesto.example/aglio/book',
      'bookingAverageCheck': 1800,
      'bookingCurrency': 'RUB',
    });

    expect(stop.ticketUrl, 'https://tomesto.example/aglio');
    expect(stop.ticketPrice, 800);
    expect(stop.ticketSourceCode, 'tomesto');
    expect(stop.sourceUrl, 'https://tomesto.ru/moskva/places/aglio');
    expect(stop.bookingUrl, 'https://tomesto.example/aglio/book');
    expect(stop.bookingAverageCheck, 1800);
    expect(stop.bookingCurrency, 'RUB');
  });
}
