import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/chats/presentation/meeting_chat_screen.dart';
import 'package:mobile2/shared/widgets/dateasy_map_choice_sheet.dart';

void main() {
  test('chat location is active until expiration', () {
    final expiresAt = DateTime.utc(2026, 5, 24, 12, 15);

    expect(
      chatLocationIsActive(
        expiresAt: expiresAt,
        now: DateTime.utc(2026, 5, 24, 12, 14, 59),
      ),
      isTrue,
    );
    expect(
      chatLocationIsActive(
        expiresAt: expiresAt,
        now: DateTime.utc(2026, 5, 24, 12, 15),
      ),
      isFalse,
    );
  });

  test('builds external map urls for coordinates', () {
    final urls = dateasyMapChoiceUrls(
      latitude: 55.751244,
      longitude: 37.618423,
      label: 'Красная площадь',
    )!;

    expect(urls.google.toString(), contains('google.com/maps/search/'));
    expect(urls.google.toString(), contains('55.751244,37.618423'));
    expect(urls.yandex.toString(), contains('yandex.ru/maps/'));
    expect(urls.yandex.toString(), contains('pt=37.618423,55.751244'));
  });

  test('builds external map urls for text search', () {
    final urls = dateasyMapChoiceUrls(
      label: 'Brew Lab',
      fallbackQuery: 'Brew Lab, Москва',
    )!;

    expect(urls.google.toString(), contains('google.com/maps/search/'));
    expect(urls.google.queryParameters['query'], 'Brew Lab, Москва');
    expect(urls.yandex.toString(), contains('yandex.ru/maps/'));
    expect(urls.yandex.queryParameters['text'], 'Brew Lab, Москва');
  });
}
