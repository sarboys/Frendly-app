import 'package:big_break_mobile/app/core/config/backend_config.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/backend_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses paid affiliate affiche event with optional address', () {
    final event = AfficheEvent.fromJson({
      'id': 'event-1',
      'title': 'Большой стендап',
      'description': 'Описание',
      'city': 'Москва',
      'venue': 'Клуб',
      'address': null,
      'lat': null,
      'lng': null,
      'startsAt': '2026-05-05T16:00:00.000Z',
      'endsAt': null,
      'dateLabel': '5 мая',
      'timeLabel': '19:00',
      'category': 'comedy',
      'priceFrom': 1500,
      'priceMode': 'paid',
      'currency': 'RUB',
      'imageUrl': 'https://ticketland.ru/image.jpg',
      'provider': 'Ticketland / MTS Live',
      'sourceCode': 'advcake_ticketland',
      'actionUrl': 'https://go.avred.online/click',
      'actionKind': 'affiliate_ticket',
      'isAffiliate': true,
      'tags': ['18+'],
    });

    expect(event.isPaid, isTrue);
    expect(event.isAffiliate, isTrue);
    expect(event.priceLabel, 'от 1 500 ₽');
    expect(event.compactPriceLabel, 'от 1 500 ₽');
    expect(event.ctaLabel, 'Купить билет');
    expect(event.placeLabel, 'Клуб');
    expect(event.hasCoords, isFalse);
  });

  test('cleans escaped html from external description', () {
    final event = AfficheEvent.fromJson({
      'id': 'event-html',
      'title': 'Событие',
      'description': '&lt;p&gt;Проверка &amp;amp; детали&lt;/p&gt;',
      'city': 'Москва',
      'category': 'comedy',
      'priceMode': 'paid',
      'priceFrom': 499,
      'isAffiliate': true,
      'tags': [],
    });

    expect(event.description, 'Проверка & детали');
    expect(event.compactPriceLabel, 'от 499 ₽');
  });

  test('decodes common named entities from affiche descriptions', () {
    final event = AfficheEvent.fromJson({
      'id': 'event-named-entities',
      'title': 'Событие',
      'description':
          '&laquo;Стендап-экскурсия&raquo; &mdash; это новое&nbsp;событие',
      'city': 'Москва',
      'category': 'comedy',
      'priceMode': 'paid',
      'priceFrom': 1200,
      'isAffiliate': true,
      'tags': [],
    });

    expect(event.description, '«Стендап-экскурсия» — это новое событие');
  });

  test('does not call unknown price free', () {
    final event = AfficheEvent.fromJson({
      'id': 'event-2',
      'title': 'Событие',
      'city': 'Москва',
      'category': 'culture',
      'priceMode': 'unknown',
      'isAffiliate': false,
      'tags': [],
    });

    expect(event.isFree, isFalse);
    expect(event.priceLabel, 'Цена не указана');
  });

  test('resolves relative affiche image proxy urls through api base url', () {
    final event = AfficheEvent.fromJson({
      'id': 'event-3',
      'title': 'Событие',
      'city': 'Москва',
      'category': 'culture',
      'priceMode': 'paid',
      'isAffiliate': true,
      'imageUrl': '/affiche/images?key=external-content%2Fitem.jpg',
      'tags': [],
    });

    expect(
      event.imageUrl,
      '${BackendConfig.apiBaseUrl}/affiche/images?key=external-content%2Fitem.jpg',
    );
  });

  test('joins relative backend urls without duplicate slash', () {
    expect(
      joinBackendUrl(
        'https://api.frendly.tech/',
        '/affiche/images?key=external-content%2Fitem.jpg',
      ),
      'https://api.frendly.tech/affiche/images?key=external-content%2Fitem.jpg',
    );
  });
}
