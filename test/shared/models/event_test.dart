import 'package:big_break_mobile/app/core/config/backend_config.dart';
import 'package:big_break_mobile/shared/models/event.dart';
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
}
