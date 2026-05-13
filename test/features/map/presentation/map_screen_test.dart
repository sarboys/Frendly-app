import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/features/map/presentation/map_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

import '../../../test_overrides.dart';

class _ImmediateMapkitBootstrap implements MapkitBootstrap {
  const _ImmediateMapkitBootstrap();

  @override
  Future<void> ensureInitialized() async {}
}

List<Override> _mapTestOverrides([List<Override> overrides = const []]) {
  return [
    ...buildTestOverrides(),
    appLocationServiceProvider.overrideWithValue(const _NoLocationService()),
    ...overrides,
  ];
}

class _NoLocationService implements AppLocationService {
  const _NoLocationService();

  @override
  Future<Position?> getCurrentPosition() async => null;

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return 0;
  }
}

class _FixedLocationService implements AppLocationService {
  const _FixedLocationService(this.position);

  final Position position;

  @override
  Future<Position?> getCurrentPosition() async => position;

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}

double _eventPlacemarkScale(WidgetTester tester, String eventId) {
  final map = tester.widget<ym.YandexMap>(find.byType(ym.YandexMap));
  final placemark = map.mapObjects
      .whereType<ym.PlacemarkMapObject>()
      .where((object) => object.mapId.value == 'event_$eventId')
      .single;
  final style = placemark.icon!.toJson()['style'] as Map<String, dynamic>;
  return style['scale'] as double;
}

void main() {
  test('map viewport bounds include user location and event points', () {
    final bounds = buildMapViewportBounds(
      userPoint: const ym.Point(latitude: 55.75, longitude: 37.61),
      eventPoints: const [
        ym.Point(latitude: 55.76, longitude: 37.64),
        ym.Point(latitude: 55.70, longitude: 37.50),
      ],
    );

    expect(bounds, isNotNull);
    expect(bounds!.southWest.latitude, lessThan(55.70));
    expect(bounds.southWest.longitude, lessThan(37.50));
    expect(bounds.northEast.latitude, greaterThan(55.76));
    expect(bounds.northEast.longitude, greaterThan(37.64));
  });

  test('map viewport bounds fit actual points, not the full nearby radius', () {
    final bounds = buildMapViewportBounds(
      userPoint: const ym.Point(latitude: 55.75, longitude: 37.61),
      eventPoints: const [
        ym.Point(latitude: 55.751, longitude: 37.611),
      ],
    );

    expect(bounds, isNotNull);
    expect(
      bounds!.northEast.latitude - bounds.southWest.latitude,
      lessThan(0.05),
    );
    expect(
      bounds.northEast.longitude - bounds.southWest.longitude,
      lessThan(0.05),
    );
  });

  test('map radius bounds cover the selected radius around center', () {
    const center = ym.Point(latitude: 55.7558, longitude: 37.6173);

    final bounds = buildMapRadiusBounds(center: center, radiusKm: 42);

    expect(bounds.southWest.latitude, lessThan(center.latitude));
    expect(bounds.southWest.longitude, lessThan(center.longitude));
    expect(bounds.northEast.latitude, greaterThan(center.latitude));
    expect(bounds.northEast.longitude, greaterThan(center.longitude));
    expect(
      Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        bounds.northEast.latitude,
        center.longitude,
      ),
      greaterThan(42000),
    );
  });

  test('map radius change uses the current camera center first', () {
    final center = mapRadiusCenterForChange(
      query: const MapEventsQuery(
        centerLatitude: 55.7558,
        centerLongitude: 37.6173,
      ),
      userPoint: const ym.Point(latitude: 55.76, longitude: 37.62),
      cameraPoint: const ym.Point(latitude: 59.93, longitude: 30.31),
    );

    expect(center?.latitude, 59.93);
    expect(center?.longitude, 30.31);
  });

  test('map radius zooms out when radius grows', () {
    final zoom50 = mapZoomForRadiusKm(
      radiusKm: 50,
      viewportSize: const Size(390, 620),
      latitude: 55.7558,
    );
    final zoom150 = mapZoomForRadiusKm(
      radiusKm: 150,
      viewportSize: const Size(390, 620),
      latitude: 55.7558,
    );

    expect(zoom150, lessThan(zoom50 - 1));
  });

  test('map keeps previous event markers while radius request is loading', () {
    const previousEvents = [
      Event(
        id: 'map-1',
        title: 'Первая точка',
        emoji: '☕',
        time: 'Сегодня · 12:00',
        place: 'Москва',
        distance: '0.5 км',
        attendees: ['Аня'],
        going: 1,
        capacity: 4,
        vibe: 'Спокойно',
        tone: EventTone.warm,
        latitude: 55.75,
        longitude: 37.61,
        joined: false,
      ),
    ];

    expect(
      visibleMapEventsForRadar(
        eventsAsync: const AsyncLoading<List<Event>>(),
        previousEvents: previousEvents,
      ),
      previousEvents,
    );
  });

  test('map keeps previous event markers when viewport request is empty', () {
    const previousEvents = [
      Event(
        id: 'map-1',
        title: 'Первая точка',
        emoji: '☕',
        time: 'Сегодня · 12:00',
        place: 'Москва',
        distance: '0.5 км',
        attendees: ['Аня'],
        going: 1,
        capacity: 4,
        vibe: 'Спокойно',
        tone: EventTone.warm,
        latitude: 55.75,
        longitude: 37.61,
        joined: false,
      ),
    ];

    expect(
      visibleMapEventsForRadar(
        eventsAsync: const AsyncData<List<Event>>([]),
        previousEvents: previousEvents,
      ),
      previousEvents,
    );
  });

  test('map viewport fit does not repeat without an explicit pending fit', () {
    expect(
      shouldScheduleMapViewportFit(
        supportsNativeMap: true,
        hasMapController: true,
        hasInitialEvent: false,
        autoFitPending: false,
        fitKey: 'all|map-1:55.75000,37.61000',
        lastFitKey: 'all|map-2:55.76000,37.62000',
      ),
      isFalse,
    );
    expect(
      shouldScheduleMapViewportFit(
        supportsNativeMap: true,
        hasMapController: true,
        hasInitialEvent: false,
        autoFitPending: true,
        fitKey: 'all|map-1:55.75000,37.61000',
        lastFitKey: 'all|map-2:55.76000,37.62000',
      ),
      isTrue,
    );
  });

  test('initial map viewport fit can use event points without user location',
      () {
    expect(
      shouldScheduleMapViewportFit(
        supportsNativeMap: true,
        hasMapController: true,
        hasInitialEvent: false,
        autoFitPending: false,
        fitKey: 'all|map-1:55.75000,37.61000',
        lastFitKey: '',
      ),
      isTrue,
    );
  });

  test('map viewport query refresh only reacts to user gestures', () {
    expect(
      shouldRefreshMapViewportQuery(
        reason: ym.CameraUpdateReason.application,
        finished: true,
      ),
      isFalse,
    );
    expect(
      shouldRefreshMapViewportQuery(
        reason: ym.CameraUpdateReason.gestures,
        finished: false,
      ),
      isFalse,
    );
    expect(
      shouldRefreshMapViewportQuery(
        reason: ym.CameraUpdateReason.gestures,
        finished: true,
      ),
      isTrue,
    );
    expect(
      shouldRefreshMapViewportQuery(
        reason: ym.CameraUpdateReason.application,
        finished: true,
        allowApplication: true,
      ),
      isTrue,
    );
  });

  test('map zoom is clamped to supported range', () {
    expect(clampMapZoom(1), 2);
    expect(clampMapZoom(14.5), 14.5);
    expect(clampMapZoom(22), 19);
  });

  test('map card swipe keeps the current camera zoom for event selection', () {
    expect(
      mapZoomForEventSelection(
        currentZoom: 8.25,
        keepCurrentZoom: true,
      ),
      8.25,
    );
    expect(
      mapZoomForEventSelection(
        currentZoom: null,
        keepCurrentZoom: true,
      ),
      15,
    );
    expect(
      mapZoomForEventSelection(
        currentZoom: 8.25,
        keepCurrentZoom: false,
      ),
      15,
    );
  });

  test('radar category counts are calculated from loaded map events', () {
    const events = [
      Event(
        id: 'bar-1',
        title: 'Brix',
        emoji: '🍷',
        time: 'Сегодня · 20:00',
        place: 'Патрики',
        distance: '0.4 км',
        attendees: [],
        going: 8,
        capacity: 12,
        vibe: 'Вино',
        tone: EventTone.warm,
        joined: false,
      ),
      Event(
        id: 'route-1',
        title: 'Тверская в огнях',
        emoji: '✨',
        time: 'Сегодня · 20:30',
        place: 'Тверская',
        distance: '0.7 км',
        attendees: [],
        going: 6,
        capacity: 8,
        vibe: 'Маршрут',
        tone: EventTone.evening,
        routeId: 'r-lights',
        joined: false,
      ),
      Event(
        id: 'date-1',
        title: 'Дейтинг рядом',
        emoji: '💫',
        time: 'Сегодня · 21:00',
        place: 'Центр',
        distance: '0.9 км',
        attendees: [],
        going: 2,
        capacity: 2,
        vibe: 'Свидание',
        tone: EventTone.warm,
        isDate: true,
        joined: false,
      ),
      Event(
        id: 'poster-1',
        title: 'Стендап',
        emoji: '🎟️',
        time: 'Сегодня · 22:00',
        place: 'Клуб',
        distance: '1.1 км',
        attendees: [],
        going: 14,
        capacity: 30,
        vibe: 'Афиша',
        tone: EventTone.sage,
        ticketSourceKind: EventTicketSourceKind.affiche,
        joined: false,
      ),
    ];

    final counts = buildRadarCategoryCounts(events);

    expect(counts['all'], 4);
    expect(counts['bars'], 1);
    expect(counts['routes'], 1);
    expect(counts['dating'], 1);
    expect(counts['affiche'], 1);
  });

  test('map prefers manual location over device GPS', () {
    final point = resolvePreferredMapPoint(
      manualLocation: const ManualLocation(
        label: 'Москва',
        latitude: 55.7558,
        longitude: 37.6173,
      ),
      currentPosition: Position(
        latitude: 12.2388,
        longitude: 109.1967,
        timestamp: DateTime(2026, 5, 5, 12),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 0,
      ),
    );

    expect(point?.latitude, 55.7558);
    expect(point?.longitude, 37.6173);
  });

  test('map ignores invalid manual location and falls back to device GPS', () {
    final point = resolvePreferredMapPoint(
      manualLocation: const ManualLocation(
        label: 'Москва',
        latitude: 0,
        longitude: 0,
      ),
      currentPosition: Position(
        latitude: 12.2388,
        longitude: 109.1967,
        timestamp: DateTime(2026, 5, 5, 12),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 0,
      ),
    );

    expect(point?.latitude, 12.2388);
    expect(point?.longitude, 109.1967);
  });

  test('map viewport fit key changes when event points arrive', () {
    expect(buildMapViewportFitKey(const [], 'all'), isEmpty);

    const events = [
      Event(
        id: 'map-1',
        title: 'Первая точка',
        emoji: '☕',
        time: 'Сегодня · 12:00',
        place: 'Москва',
        distance: '0.5 км',
        attendees: ['Аня'],
        going: 1,
        capacity: 4,
        vibe: 'Спокойно',
        tone: EventTone.warm,
        latitude: 55.75,
        longitude: 37.61,
        joined: false,
      ),
    ];

    expect(buildMapViewportFitKey(events, 'all'), isNotEmpty);
  });

  test('map event objects use visible placemark icons', () {
    const events = [
      Event(
        id: 'map-1',
        title: 'Первая точка',
        emoji: '☕',
        time: 'Сегодня · 12:00',
        place: 'Москва',
        distance: '0.5 км',
        attendees: ['Аня'],
        going: 1,
        capacity: 4,
        vibe: 'Спокойно',
        tone: EventTone.warm,
        latitude: 55.75,
        longitude: 37.61,
        joined: false,
      ),
      Event(
        id: 'map-2',
        title: 'Вторая точка',
        emoji: '🎙️',
        time: 'Сегодня · 20:00',
        place: 'Москва',
        distance: '1.0 км',
        attendees: ['Ира'],
        going: 2,
        capacity: 8,
        vibe: 'Активно',
        tone: EventTone.evening,
        latitude: 55.7601,
        longitude: 37.6401,
        joined: false,
      ),
    ];

    final placemarks = buildEventPlacemarks(
      events: events,
      selectedId: 'map-1',
      onEventTap: (_) {},
    );

    expect(placemarks, hasLength(2));
    expect(placemarks.first.icon, isNotNull);
    expect(placemarks.first.opacity, 1);
    expect(placemarks.first.text?.text, '☕');
    expect(placemarks.last.text?.text, '🎙️');
  });

  test('map object cache reuses unchanged object lists', () {
    final cache = MapObjectCache();
    const events = [
      Event(
        id: 'map-1',
        title: 'Первая точка',
        emoji: '☕',
        time: 'Сегодня · 12:00',
        place: 'Москва',
        distance: '0.5 км',
        attendees: ['Аня'],
        going: 1,
        capacity: 4,
        vibe: 'Спокойно',
        tone: EventTone.warm,
        latitude: 55.75,
        longitude: 37.61,
        joined: false,
      ),
    ];

    final first = cache.objectsFor(
      events: events,
      selectedId: 'map-1',
      liveEvenings: const [],
      userPoint: null,
      searchPoint: null,
      onEventTap: (_) {},
      onSessionTap: (_) {},
    );
    final second = cache.objectsFor(
      events: events,
      selectedId: 'map-1',
      liveEvenings: const [],
      userPoint: null,
      searchPoint: null,
      onEventTap: (_) {},
      onSessionTap: (_) {},
    );
    final changedSelection = cache.objectsFor(
      events: events,
      selectedId: '',
      liveEvenings: const [],
      userPoint: null,
      searchPoint: null,
      onEventTap: (_) {},
      onSessionTap: (_) {},
    );

    expect(identical(second, first), isTrue);
    expect(identical(changedSelection, first), isFalse);
  });

  test('map live evening objects use session coordinates', () {
    const sessions = [
      EveningSessionSummary(
        id: 'session-live',
        routeId: 'r-cozy-circle',
        chatId: 'chat-live',
        phase: EveningSessionPhase.live,
        chatPhase: MeetupPhase.live,
        privacy: EveningPrivacy.open,
        title: 'Теплый круг',
        vibe: 'Камерный вечер',
        emoji: '🍷',
        lat: 55.7601,
        lng: 37.6401,
      ),
      EveningSessionSummary(
        id: 'session-without-point',
        routeId: 'r-no-point',
        chatId: 'chat-no-point',
        phase: EveningSessionPhase.live,
        chatPhase: MeetupPhase.live,
        privacy: EveningPrivacy.open,
        title: 'Без точки',
        vibe: 'Камерный вечер',
        emoji: '✨',
      ),
    ];

    final placemarks = buildLiveEveningPlacemarks(
      sessions: sessions,
      onSessionTap: (_) {},
    );

    expect(placemarks, hasLength(1));
    expect(placemarks.single.mapId.value, 'evening_session_session-live');
    expect(placemarks.single.point.latitude, 55.7601);
    expect(placemarks.single.point.longitude, 37.6401);
    expect(placemarks.single.text?.text, '🍷');
  });

  test('map does not auto-enable native user layer on create', () {
    expect(mapAutoNativeUserLayerEnabled, isFalse);
  });

  test('map viewport query is built from bounds and camera target', () {
    final query = buildMapEventsQuery(
      bounds: const ym.BoundingBox(
        southWest: ym.Point(latitude: 55.70, longitude: 37.50),
        northEast: ym.Point(latitude: 55.80, longitude: 37.70),
      ),
      center: const ym.Point(latitude: 55.75, longitude: 37.61),
    );

    expect(query.centerLatitude, 55.75);
    expect(query.centerLongitude, 37.61);
    expect(query.southWestLatitude, 55.70);
    expect(query.southWestLongitude, 37.50);
    expect(query.northEastLatitude, 55.80);
    expect(query.northEastLongitude, 37.70);
    expect(query.radiusKm, greaterThan(0));
  });

  test('map viewport query ignores tiny camera jitter', () {
    final first = buildMapEventsQuery(
      bounds: const ym.BoundingBox(
        southWest: ym.Point(latitude: 55.700004, longitude: 37.500004),
        northEast: ym.Point(latitude: 55.800004, longitude: 37.700004),
      ),
      center: const ym.Point(latitude: 55.750004, longitude: 37.610004),
    );
    final second = buildMapEventsQuery(
      bounds: const ym.BoundingBox(
        southWest: ym.Point(latitude: 55.700006, longitude: 37.500006),
        northEast: ym.Point(latitude: 55.800006, longitude: 37.700006),
      ),
      center: const ym.Point(latitude: 55.750006, longitude: 37.610006),
    );

    expect(second, first);
  });

  test('map viewport query can request the shared maximum radius', () {
    final query = buildMapEventsQuery(
      bounds: const ym.BoundingBox(
        southWest: ym.Point(latitude: 54.40, longitude: 35.70),
        northEast: ym.Point(latitude: 57.10, longitude: 39.90),
      ),
      center: const ym.Point(latitude: 55.75, longitude: 37.61),
    );

    expect(query.radiusKm, 150);
  });

  test('map radius filter follows the viewport query radius', () {
    expect(
      nearbyRadiusKmFromMapQuery(
        currentRadiusKm: 50,
        query: const MapEventsQuery(radiusKm: 24.5),
      ),
      24.5,
    );
  });

  test('initial map query centers on user location with nearby radius', () {
    final query = buildInitialMapEventsQuery(
      const ym.Point(latitude: 55.75399, longitude: 37.62001),
    );

    expect(query.centerLatitude, 55.75399);
    expect(query.centerLongitude, 37.62001);
    expect(query.radiusKm, 50);
  });

  test('radar carousel maps infinite pages to event indexes', () {
    expect(radarCarouselEventIndex(1000, 2), 0);
    expect(radarCarouselEventIndex(1001, 2), 1);
    expect(radarCarouselEventIndex(1002, 2), 0);
    expect(radarCarouselEventIndex(0, 0), 0);
  });

  test('radar carousel selects nearest physical page for event', () {
    expect(nearestRadarCarouselPage(1000, targetIndex: 1, eventCount: 2), 1001);
    expect(nearestRadarCarouselPage(1001, targetIndex: 0, eventCount: 2), 1002);
    expect(nearestRadarCarouselPage(1000, targetIndex: 0, eventCount: 1), 0);
  });

  testWidgets('map bottom sheet renders v5 event cards', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides(),
            mapEventsProvider.overrideWith(
              (ref, query) async => const [
                Event(
                  id: 'map-1',
                  title: 'Спокойный вечер: Kitchen Burger Bar → дом Шурика',
                  emoji: '☕',
                  time: 'Сегодня · 12:00',
                  place: 'Москва',
                  distance: '0.5 км',
                  attendees: ['Аня'],
                  going: 1,
                  capacity: 4,
                  vibe: 'Спокойно',
                  tone: EventTone.warm,
                  latitude: 55.75,
                  longitude: 37.61,
                  joined: false,
                ),
                Event(
                  id: 'map-2',
                  title: 'Вторая точка',
                  emoji: '🎙️',
                  time: 'Сегодня · 20:00',
                  place: 'Москва',
                  distance: '1.0 км',
                  attendees: ['Ира'],
                  going: 2,
                  capacity: 8,
                  vibe: 'Активно',
                  tone: EventTone.evening,
                  latitude: 55.76,
                  longitude: 37.64,
                  joined: false,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Рядом сегодня'), findsNothing);
      expect(find.text('2 точек · 50 км'), findsNothing);
      expect(find.text('AI подбор'), findsNothing);
      expect(
        find.text('Спокойный вечер: Kitchen Burger Bar → дом Шурика'),
        findsOneWidget,
      );
      expect(find.text('Вторая точка'), findsOneWidget);
      expect(find.text('Открыть →'), findsNothing);
      expect(find.text('1 из 4'), findsNothing);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.padEnds, isTrue);
      expect(pageView.controller?.viewportFraction, greaterThan(0.70));

      await tester.fling(
        find.byKey(const Key('radar-bottom-sheet-drag-area')),
        const Offset(0, 160),
        600,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Спокойный вечер: Kitchen Burger Bar → дом Шурика'),
        findsNothing,
      );
      expect(find.byIcon(LucideIcons.chevron_up), findsNothing);
      expect(find.byIcon(LucideIcons.chevron_down), findsNothing);

      await tester.fling(
        find.byKey(const Key('radar-bottom-sheet-drag-area')),
        const Offset(0, -160),
        600,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Спокойный вечер: Kitchen Burger Bar → дом Шурика'),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.chevron_up), findsNothing);
      expect(find.byIcon(LucideIcons.chevron_down), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('map surface extends under the phone notch', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapEventsProvider.overrideWith((ref, query) async => const []),
            ]),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                padding: EdgeInsets.only(top: 47),
                size: Size(390, 844),
              ),
              child: MapScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('map-fallback-surface'))).dy,
        0,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('map displays every event returned by the map provider',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              appLocationServiceProvider.overrideWithValue(
                _FixedLocationService(
                  Position(
                    latitude: 12.25,
                    longitude: 109.19,
                    timestamp: DateTime(2026, 5, 7, 12),
                    accuracy: 1,
                    altitude: 0,
                    altitudeAccuracy: 1,
                    heading: 0,
                    headingAccuracy: 1,
                    speed: 0,
                    speedAccuracy: 0,
                  ),
                ),
              ),
              mapEventsProvider.overrideWith(
                (ref, query) async => const [
                  Event(
                    id: 'near',
                    title: 'Рядом',
                    emoji: '☕',
                    time: 'Сегодня · 12:00',
                    place: 'Нячанг',
                    distance: '0.5 км',
                    attendees: ['Аня'],
                    going: 1,
                    capacity: 4,
                    vibe: 'Спокойно',
                    tone: EventTone.warm,
                    latitude: 12.25,
                    longitude: 109.19,
                    joined: false,
                  ),
                  Event(
                    id: 'far',
                    title: 'Далеко',
                    emoji: '🍷',
                    time: 'Сегодня · 13:00',
                    place: 'Далат',
                    distance: '158.5 км',
                    attendees: ['Ира'],
                    going: 2,
                    capacity: 8,
                    vibe: 'Спокойно',
                    tone: EventTone.evening,
                    latitude: 11.94,
                    longitude: 108.44,
                    joined: false,
                  ),
                ],
              ),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 точек · 50 км'), findsNothing);
      expect(find.text('Рядом'), findsOneWidget);
      expect(find.text('Далеко'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('paging map event cards selects the focused placemark',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapkitBootstrapProvider.overrideWithValue(
                const _ImmediateMapkitBootstrap(),
              ),
              mapEventsProvider.overrideWith(
                (ref, query) async => const [
                  Event(
                    id: 'map-1',
                    title: 'Первая точка',
                    emoji: '☕',
                    time: 'Сегодня · 12:00',
                    place: 'Москва',
                    distance: '0.5 км',
                    attendees: ['Аня'],
                    going: 1,
                    capacity: 4,
                    vibe: 'Спокойно',
                    tone: EventTone.warm,
                    latitude: 55.75,
                    longitude: 37.61,
                    joined: false,
                  ),
                  Event(
                    id: 'map-2',
                    title: 'Вторая точка',
                    emoji: '🎙️',
                    time: 'Сегодня · 20:00',
                    place: 'Москва',
                    distance: '1.0 км',
                    attendees: ['Ира'],
                    going: 2,
                    capacity: 8,
                    vibe: 'Активно',
                    tone: EventTone.evening,
                    latitude: 55.76,
                    longitude: 37.64,
                    joined: false,
                  ),
                ],
              ),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_eventPlacemarkScale(tester, 'map-1'), 0.72);
      expect(_eventPlacemarkScale(tester, 'map-2'), 0.62);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.onPageChanged!(1);
      await tester.pumpAndSettle();

      expect(_eventPlacemarkScale(tester, 'map-1'), 0.62);
      expect(_eventPlacemarkScale(tester, 'map-2'), 0.72);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('map reuses native map objects across unrelated rebuilds',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapkitBootstrapProvider.overrideWithValue(
                const _ImmediateMapkitBootstrap(),
              ),
              mapEventsProvider.overrideWith(
                (ref, query) async => const [
                  Event(
                    id: 'map-1',
                    title: 'Первая точка',
                    emoji: '☕',
                    time: 'Сегодня · 12:00',
                    place: 'Москва',
                    distance: '0.5 км',
                    attendees: ['Аня'],
                    going: 1,
                    capacity: 4,
                    vibe: 'Спокойно',
                    tone: EventTone.warm,
                    latitude: 55.75,
                    longitude: 37.61,
                    joined: false,
                  ),
                ],
              ),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstMap = tester.widget<ym.YandexMap>(find.byType(ym.YandexMap));
      final firstObjects = firstMap.mapObjects;

      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();

      final secondMap = tester.widget<ym.YandexMap>(find.byType(ym.YandexMap));
      expect(identical(secondMap.mapObjects, firstObjects), isTrue);
    } finally {
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('map renders zoom controls', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapEventsProvider.overrideWith((ref, query) async => const []),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final plus = find.byIcon(LucideIcons.plus);
      final minus = find.byIcon(LucideIcons.minus);
      expect(plus, findsOneWidget);
      expect(minus, findsOneWidget);
      expect(find.byIcon(LucideIcons.layers), findsNothing);
      expect(find.byIcon(LucideIcons.locate_fixed), findsNothing);

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final plusCenter = tester.getCenter(plus);
      final minusCenter = tester.getCenter(minus);
      expect(plusCenter.dx, greaterThan(size.width - 72));
      expect(minusCenter.dx, greaterThan(size.width - 72));
      expect(
        (plusCenter.dy + minusCenter.dy) / 2,
        moreOrLessEquals(size.height / 2, epsilon: 24),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('radar map back falls back to tonight and hides create meetup',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final router = GoRouter(
        initialLocation: AppRoute.map.path,
        routes: [
          GoRoute(
            path: AppRoute.map.path,
            name: AppRoute.map.name,
            builder: (context, state) => ProviderScope(
              overrides: _mapTestOverrides([
                mapEventsProvider.overrideWith((ref, query) async => const []),
              ]),
              child: const MapScreen(),
            ),
          ),
          GoRoute(
            path: AppRoute.tonight.path,
            name: AppRoute.tonight.name,
            builder: (context, state) => const Text('tonight-opened'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Встреча'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.arrow_left));
      await tester.pumpAndSettle();

      expect(find.text('tonight-opened'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('map does not render fallback pins when backend returns empty',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapEventsProvider.overrideWith((ref, query) async => const []),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Brix'), findsNothing);
      expect(find.text('Все · 46'), findsNothing);
      expect(find.text('Рядом сегодня'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('map shows live evening pins on fallback surface',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides(),
            eveningSessionsProvider.overrideWith(
              (ref) async => const [
                EveningSessionSummary(
                  id: 'session-live',
                  routeId: 'r-cozy-circle',
                  chatId: 'chat-live',
                  phase: EveningSessionPhase.live,
                  chatPhase: MeetupPhase.live,
                  privacy: EveningPrivacy.open,
                  title: 'Теплый круг',
                  vibe: 'Камерный вечер',
                  emoji: '🍷',
                  area: 'Покровка',
                  joinedCount: 5,
                  maxGuests: 10,
                  currentStep: 2,
                  totalSteps: 3,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('map-live-evening-pin-session-live')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('map-live-evening-pulse-session-live')),
        findsOneWidget,
      );
      expect(find.text('Live'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('map screen uses fallback surface on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapkitBootstrapProvider.overrideWithValue(
                const _ImmediateMapkitBootstrap(),
              ),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-native-surface')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native map does not pin user pulse to screen center',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapkitBootstrapProvider.overrideWithValue(
                const _ImmediateMapkitBootstrap(),
              ),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_RadarUserPulse',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native map keeps base map details visible', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              mapkitBootstrapProvider.overrideWithValue(
                const _ImmediateMapkitBootstrap(),
              ),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final map = tester.widget<ym.YandexMap>(find.byType(ym.YandexMap));
      expect(map.mapType, ym.MapType.vector);
      expect(map.poiLimit, greaterThan(0));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_RadarTopographyPainter',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native map renders user location as coordinate placemark',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._mapTestOverrides([
              appLocationServiceProvider.overrideWithValue(
                _FixedLocationService(
                  Position(
                    latitude: 12.2388,
                    longitude: 109.1967,
                    timestamp: DateTime(2026, 5, 7, 12),
                    accuracy: 1,
                    altitude: 0,
                    altitudeAccuracy: 1,
                    heading: 0,
                    headingAccuracy: 1,
                    speed: 0,
                    speedAccuracy: 0,
                  ),
                ),
              ),
              mapEventsProvider.overrideWith((ref, query) async => const []),
              mapkitBootstrapProvider.overrideWithValue(
                const _ImmediateMapkitBootstrap(),
              ),
            ]),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final map = tester.widget<ym.YandexMap>(find.byType(ym.YandexMap));
      final userMarker = map.mapObjects
          .whereType<ym.PlacemarkMapObject>()
          .where((object) => object.mapId.value == 'user_location')
          .singleOrNull;

      expect(userMarker, isNotNull);
      expect(userMarker!.point.latitude, 12.2388);
      expect(userMarker.point.longitude, 109.1967);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
