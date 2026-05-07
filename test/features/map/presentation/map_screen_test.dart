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

  test('map viewport fit requires an explicit pending fit', () {
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
  });

  test('map zoom is clamped to supported range', () {
    expect(clampMapZoom(1), 2);
    expect(clampMapZoom(14.5), 14.5);
    expect(clampMapZoom(22), 19);
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

  test('initial map query centers on user location with nearby radius', () {
    final query = buildInitialMapEventsQuery(
      const ym.Point(latitude: 55.75399, longitude: 37.62001),
    );

    expect(query.centerLatitude, 55.75399);
    expect(query.centerLongitude, 37.62001);
    expect(query.radiusKm, 25);
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
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Рядом сегодня'), findsOneWidget);
      expect(find.text('2 точек · 25 км'), findsOneWidget);
      expect(find.text('Первая точка'), findsOneWidget);
      expect(find.text('Вторая точка'), findsOneWidget);
      expect(find.text('Открыть →'), findsNothing);
      expect(find.text('1 из 4'), findsNothing);
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

      expect(find.text('2 точек · 25 км'), findsOneWidget);
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

      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
      expect(find.byIcon(LucideIcons.minus), findsOneWidget);
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
