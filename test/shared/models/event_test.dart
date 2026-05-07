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
}
