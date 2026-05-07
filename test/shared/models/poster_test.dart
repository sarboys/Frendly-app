import 'package:big_break_mobile/app/core/config/backend_config.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('poster reads cover url from backend media payload', () {
    final poster = Poster.fromJson({
      'id': 'poster-1',
      'title': 'Концерт с фото',
      'category': 'concert',
      'emoji': '🎸',
      'startsAt': '2026-05-01T20:00:00.000Z',
      'date': '1 мая',
      'time': '20:00',
      'venue': 'Aglomerat',
      'address': 'Костомаровский пер. 3',
      'distance': '1.2 км',
      'priceFrom': 1200,
      'ticketUrl': 'https://example.com/tickets',
      'provider': 'Provider',
      'tone': 'warm',
      'tags': ['рок'],
      'description': 'Описание',
      'isFeatured': true,
      'cover': {
        'id': 'asset-1',
        'url': '/media/asset-1',
      },
    });

    expect(poster.imageUrl, '${BackendConfig.apiBaseUrl}/media/asset-1');
  });
}
