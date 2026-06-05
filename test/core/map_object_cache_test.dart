import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/map/presentation/map_screen.dart';
import 'package:mobile2/shared/data/city_catalog.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

void main() {
  test('radar native map does not require dart mapkit define', () {
    expect(
      radarShouldRenderNativeMap(
        nativeMapEnabled: true,
        hasDartMapKitKey: false,
      ),
      isTrue,
    );
  });

  test('reuses map objects when visible pins do not change', () {
    final cache = DateasyMapObjectCache();
    final events = [
      _pin('a', 55.7, 37.6),
      _pin('b', 55.8, 37.7),
    ];

    final first = cache.objectsFor(
      events: events,
      selectedId: 'a',
      onPinTap: (_) {},
    );
    final second = cache.objectsFor(
      events: List<BackendCardItem>.of(events),
      selectedId: 'a',
      onPinTap: (_) {},
    );
    final changed = cache.objectsFor(
      events: [_pin('a', 55.71, 37.6), _pin('b', 55.8, 37.7)],
      selectedId: 'a',
      onPinTap: (_) {},
    );

    expect(identical(first, second), isTrue);
    expect(identical(second, changed), isFalse);
  });

  test('city point lookup includes Нижневартовск and unknown city is null', () {
    final nizhnevartovsk = cityPointForQuery('Нижневартовск');
    final moscow = cityPointForQuery('Москва');
    final unknown = cityPointForQuery('неизвестный город');

    expect(nizhnevartovsk, isNotNull);
    expect(nizhnevartovsk!.latitude, closeTo(60.9397, 0.001));
    expect(nizhnevartovsk.longitude, closeTo(76.5696, 0.001));
    expect(moscow, isNotNull);
    expect(moscow!.latitude, closeTo(radarDefaultMapPoint.latitude, 0.001));
    expect(moscow.longitude, closeTo(radarDefaultMapPoint.longitude, 0.001));
    expect(unknown, isNull);
  });

  test('initial radar query can start from selected city coordinates', () {
    final cityPoint = cityPointForQuery('Нижневартовск');

    final query = initialRadarMapEventsQuery(
      preferredPoint: pointForCityCoordinates(cityPoint),
      radiusKm: 25,
    );

    expect(query.centerLatitude, closeTo(60.9397, 0.001));
    expect(query.centerLongitude, closeTo(76.5696, 0.001));
    expect(query.centerLatitude, isNot(radarDefaultMapPoint.latitude));
    expect(query.radiusKm, 25);
  });

  test('map object cache key ignores pulse-only changes', () {
    final events = [_pin('a', 55.7, 37.6)];

    final first = buildMapObjectsCacheKey(
      events: events,
      selectedId: 'a',
      pulsePhase: 0,
    );
    final second = buildMapObjectsCacheKey(
      events: events,
      selectedId: 'a',
      pulsePhase: 1,
    );

    expect(second, first);
  });

  test('map keeps previous event pins while a fresh request loads', () {
    final previous = [_pin('a', 55.7, 37.6)];

    expect(
      visibleMapEventsForRadar(
        eventsState: const AsyncLoading<BackendPage<BackendCardItem>>(),
        previousEvents: previous,
      ),
      previous,
    );
  });

  test('map clears previous event pins when fresh request returns empty', () {
    final previous = [_pin('a', 55.7, 37.6)];

    expect(
      visibleMapEventsForRadar(
        eventsState: const AsyncData<BackendPage<BackendCardItem>>(
          BackendPage(items: [], raw: {'items': []}),
        ),
        previousEvents: previous,
      ),
      isEmpty,
    );
  });

  test('radar category counts split meetups, routes and affiche', () {
    final events = [
      _pin('meetup', 55.7, 37.6),
      _pin(
        'route',
        55.71,
        37.61,
        raw: const {'routeId': 'route-1', 'routePointCount': 3},
      ),
      _pin(
        'affiche',
        55.72,
        37.62,
        raw: const {'ticketUrl': 'https://example.com/tickets'},
      ),
    ];

    final counts = buildRadarCategoryCounts(events);

    expect(counts['meetups'], 1);
    expect(counts['routes'], 1);
    expect(counts['affiche'], 1);
  });

  test('active radar filter falls back to first non-empty category', () {
    expect(
      activeRadarFilterForCounts(
        selectedFilter: 'meetups',
        counts: const {'meetups': 0, 'routes': 10, 'affiche': 0},
      ),
      'routes',
    );
    expect(
      activeRadarFilterForCounts(
        selectedFilter: 'affiche',
        counts: const {'meetups': 1, 'routes': 10, 'affiche': 2},
      ),
      'affiche',
    );
  });

  test('map event objects use front2 v5 placemark icons and selected scale',
      () {
    final events = [
      _pin(
        'coffee',
        55.7,
        37.6,
        title: 'Кофе утром',
        raw: const {'vibe': 'Кофе'},
      ),
      _pin(
        'music',
        55.8,
        37.7,
        title: 'Джаз вечером',
        raw: const {'vibe': 'Музыка'},
      ),
    ];

    final placemarks = buildEventPlacemarks(
      events: events,
      selectedId: 'coffee',
      onPinTap: (_) {},
    );

    expect(placemarks, hasLength(2));
    final selectedStyle =
        placemarks.first.icon!.toJson()['style'] as Map<String, dynamic>;
    final selectedImage = selectedStyle['image'] as Map<String, dynamic>;
    final regularStyle =
        placemarks.last.icon!.toJson()['style'] as Map<String, dynamic>;
    final regularImage = regularStyle['image'] as Map<String, dynamic>;

    expect(selectedImage['assetName'], 'assets/map/pins/front2_pin_lime.png');
    expect(regularImage['assetName'], 'assets/map/pins/front2_pin_lime.png');
    expect(selectedStyle['scale'], greaterThan(regularStyle['scale'] as num));
    expect(placemarks.first.text, isNull);
  });

  test('map event objects use front2 route and affiche marker tones', () {
    final events = [
      _pin(
        'route',
        55.7,
        37.6,
        raw: const {'routeId': 'route-1', 'routePointCount': 2},
      ),
      _pin(
        'affiche',
        55.8,
        37.7,
        raw: const {'source': 'affiche'},
      ),
    ];

    final placemarks = buildEventPlacemarks(
      events: events,
      selectedId: 'route',
      onPinTap: (_) {},
    );

    final routeStyle =
        placemarks.first.icon!.toJson()['style'] as Map<String, dynamic>;
    final routeImage = routeStyle['image'] as Map<String, dynamic>;
    final afficheStyle =
        placemarks.last.icon!.toJson()['style'] as Map<String, dynamic>;
    final afficheImage = afficheStyle['image'] as Map<String, dynamic>;

    expect(routeImage['assetName'], 'assets/map/pins/front2_pin_lilac.png');
    expect(afficheImage['assetName'], 'assets/map/pins/front2_pin_pink.png');
  });

  test('map event objects use front2 boosted marker badges', () {
    final events = [
      _pin(
        'boost24',
        55.7,
        37.6,
        raw: const {'boostTier': '24h'},
      ),
      _pin(
        'boost72',
        55.8,
        37.7,
        raw: const {'boostTier': '72h'},
      ),
    ];

    final placemarks = buildEventPlacemarks(
      events: events,
      selectedId: 'boost24',
      onPinTap: (_) {},
    );

    final boost24Style =
        placemarks.first.icon!.toJson()['style'] as Map<String, dynamic>;
    final boost24Image = boost24Style['image'] as Map<String, dynamic>;
    final boost72Style =
        placemarks.last.icon!.toJson()['style'] as Map<String, dynamic>;
    final boost72Image = boost72Style['image'] as Map<String, dynamic>;

    expect(
        boost24Image['assetName'], 'assets/map/pins/front2_pin_boost_24h.png');
    expect(
        boost72Image['assetName'], 'assets/map/pins/front2_pin_boost_72h.png');
  });

  test('front2 map markers keep static wave and icon scale', () {
    final events = [_pin('a', 55.7, 37.6)];
    final cache = DateasyMapObjectCache();

    final resting = cache.objectsFor(
      events: events,
      selectedId: 'a',
      pulsePhase: 0,
      onPinTap: (_) {},
    );
    final pulsed = cache.objectsFor(
      events: events,
      selectedId: 'a',
      pulsePhase: 1,
      onPinTap: (_) {},
    );

    final restingWave = resting.whereType<ym.CircleMapObject>().single;
    final pulsedWave = pulsed.whereType<ym.CircleMapObject>().single;
    final restingPlacemark = resting.whereType<ym.PlacemarkMapObject>().single;
    final pulsedPlacemark = pulsed.whereType<ym.PlacemarkMapObject>().single;
    final restingStyle =
        restingPlacemark.icon!.toJson()['style'] as Map<String, dynamic>;
    final pulsedStyle =
        pulsedPlacemark.icon!.toJson()['style'] as Map<String, dynamic>;

    expect(identical(resting, pulsed), isTrue);
    expect(pulsedWave.circle.radius, restingWave.circle.radius);
    expect(pulsedWave.fillColor.a, restingWave.fillColor.a);
    expect(pulsedStyle['scale'], restingStyle['scale']);
  });

  test('cluster text stays centered inside green front2 cluster marker', () {
    expect(radarClusterText(24), '24');
    expect(radarClusterText(1200), '999+');

    final twoDigitStyle = radarClusterTextStyle(24);
    final cappedStyle = radarClusterTextStyle(1200);
    final iconStyle = radarPinIconStyle(
      kind: RadarMapPinKind.cluster,
      selected: false,
    );

    expect(twoDigitStyle.placement, ym.TextStylePlacement.center);
    expect(twoDigitStyle.offsetFromIcon, isFalse);
    expect(twoDigitStyle.size, lessThanOrEqualTo(12));
    expect(cappedStyle.size, lessThanOrEqualTo(9));
    expect(iconStyle.anchor.dx, 0.5);
    expect(iconStyle.anchor.dy, 0.5);
  });

  test('nearby list selection zooms in when current map zoom is distant', () {
    expect(mapZoomForNearbySelection(currentZoom: 9), 14.5);
    expect(mapZoomForNearbySelection(currentZoom: 15), 15);
  });

  test('route backed events render every route point as map placemark', () {
    final event = _pin(
      'route',
      55.7,
      37.6,
      raw: {
        'routeId': 'route-1',
        'routePointCount': 2,
        'routePoints': [
          {
            'id': 'start',
            'latitude': 55.751,
            'longitude': 37.611,
          },
          {
            'id': 'finish',
            'latitude': 55.762,
            'longitude': 37.642,
          },
        ],
      },
    );

    final placemarks = buildEventPlacemarks(
      events: [event],
      selectedId: event.id,
      onPinTap: (_) {},
    );

    expect(placemarks, hasLength(2));
    expect(placemarks.first.mapId.value, 'event-route-start');
    expect(placemarks.first.point.latitude, 55.751);
    expect(placemarks.last.mapId.value, 'event-route-finish');
    expect(placemarks.last.point.longitude, 37.642);
  });

  test('route detail steps render as map placemarks', () {
    const event = BackendCardItem(
      id: 'route',
      title: 'Route',
      raw: {
        'routeId': 'route-1',
        'steps': [
          {'id': 'start', 'lat': 55.751, 'lng': 37.611},
          {'id': 'finish', 'lat': 55.762, 'lng': 37.642},
        ],
      },
    );

    final placemarks = buildEventPlacemarks(
      events: [event],
      selectedId: event.id,
      onPinTap: (_) {},
    );

    expect(placemarks, hasLength(2));
    expect(placemarks.first.mapId.value, 'event-route-start');
    expect(placemarks.last.point.longitude, 37.642);
  });

  test('map object cache clusters large point sets only', () {
    final cache = DateasyMapObjectCache();
    final events = List<BackendCardItem>.generate(
      20,
      (index) => _pin(
        'event-$index',
        55.7 + index * 0.001,
        37.6 + index * 0.001,
      ),
    );

    final objects = cache.objectsFor(
      events: events,
      selectedId: 'event-0',
      onPinTap: (_) {},
    );

    expect(
        objects.whereType<ym.ClusterizedPlacemarkCollection>(), hasLength(1));
  });

  test('map zoom and viewport query helpers stay bounded', () {
    final query = buildMapEventsQuery(
      bounds: const ym.BoundingBox(
        southWest: ym.Point(latitude: 55.7, longitude: 37.5),
        northEast: ym.Point(latitude: 55.8, longitude: 37.7),
      ),
      center: const ym.Point(latitude: 55.75, longitude: 37.6),
    );

    expect(query.centerLatitude, 55.75);
    expect(query.southWestLatitude, 55.7);
    expect(query.northEastLongitude, 37.7);
    expect(clampMapZoom(1), 2);
    expect(clampMapZoom(22), 19);
  });

  test('initial radar query keeps stored radius', () {
    final query = initialRadarMapEventsQuery(radiusKm: 25);

    expect(query.centerLatitude, radarDefaultMapPoint.latitude);
    expect(query.centerLongitude, radarDefaultMapPoint.longitude);
    expect(query.radiusKm, 25);
  });
}

BackendCardItem _pin(
  String id,
  double latitude,
  double longitude, {
  String? title,
  Map<String, Object?> raw = const {},
}) {
  return BackendCardItem(
    id: id,
    title: title ?? id,
    latitude: latitude,
    longitude: longitude,
    raw: {'id': id, ...raw},
  );
}
