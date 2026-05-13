import 'dart:async';

import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() {
  test('default yandex search bounds are not limited to Moscow', () {
    expect(
      yandexDefaultSearchBoundingBox.southWest.latitude,
      lessThanOrEqualTo(12.2388),
    );
    expect(
      yandexDefaultSearchBoundingBox.northEast.latitude,
      greaterThanOrEqualTo(59.9386),
    );
    expect(
      yandexDefaultSearchBoundingBox.southWest.longitude,
      lessThanOrEqualTo(30.3141),
    );
    expect(
      yandexDefaultSearchBoundingBox.northEast.longitude,
      greaterThanOrEqualTo(109.1967),
    );
  });

  test('yandex geosearch cache returns fresh entries and expires old ones', () {
    final cache = YandexGeosearchCache(
      ttl: const Duration(minutes: 10),
      now: () => DateTime.utc(2026, 4, 25, 12),
    );
    const key = YandexGeosearchCacheKey(
      kind: 'places',
      query: ' кофе ',
      near: Point(latitude: 55.75001, longitude: 37.61001),
    );
    const result = [
      ResolvedAddress(
        name: 'Кофемания',
        address: 'Тверская 10',
        point: Point(latitude: 55.765, longitude: 37.605),
      ),
    ];

    cache.put(key, result);

    expect(cache.get(key)!.single.name, 'Кофемания');

    cache.now = () => DateTime.utc(2026, 4, 25, 12, 11);

    expect(cache.get(key), isNull);
  });

  test('yandex geosearch cache normalizes query and nearby point', () {
    final cache = YandexGeosearchCache(
      ttl: const Duration(minutes: 10),
      now: () => DateTime.utc(2026, 4, 25, 12),
    );
    const storedKey = YandexGeosearchCacheKey(
      kind: 'places',
      query: 'Кофе',
      near: Point(latitude: 55.750014, longitude: 37.610014),
    );
    const lookupKey = YandexGeosearchCacheKey(
      kind: 'places',
      query: ' кофе ',
      near: Point(latitude: 55.750016, longitude: 37.610016),
    );
    const result = [
      ResolvedAddress(
        name: 'Кофемания',
        address: 'Тверская 10',
        point: Point(latitude: 55.765, longitude: 37.605),
      ),
    ];

    cache.put(storedKey, result);

    expect(cache.get(lookupKey)!.single.name, 'Кофемания');
  });

  test('yandex text search returns empty when mapkit bootstrap hangs', () async {
    final service = YandexMapService(
      bootstrap: _HangingMapkitBootstrap(),
      searchTimeout: const Duration(milliseconds: 10),
    );

    final results = await service.searchPlaces(
      'Москва, Кетчерская улица',
      geocodeFirst: true,
    );

    expect(results, isEmpty);
  });
}

class _HangingMapkitBootstrap implements MapkitBootstrap {
  @override
  Future<void> ensureInitialized() => Completer<void>().future;
}
