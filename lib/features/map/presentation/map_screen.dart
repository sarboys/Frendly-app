import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/config/backend_config.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/meetings/presentation/meeting_boost.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/city_catalog.dart';
import 'package:mobile2/shared/data/yandex_city_search_service.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

const _mapZoomStep = 1.0;
const _minMapZoom = 2.0;
const _maxMapZoom = 19.0;
const _radarClusterPointThreshold = 10;
const _radarClusterRadius = 64.0;
const _radarClusterMinZoom = 13;
const _radarPinScale = 1.04;
const _radarSelectedPinScale = 1.18;
const _radarClusterPinScale = 1.12;
const _radarWaveMinRadiusMeters = 34.0;
const _radarWaveRadiusStepMeters = 72.0;
const _radarListFocusZoom = 14.5;
const _radarListFocusZoomThreshold = 13.0;
const _radarUserFocusRadiusKm = 5.0;

const radarDefaultMapPoint = ym.Point(
  latitude: 55.7558,
  longitude: 37.6173,
);

enum RadarMapPinKind {
  bars,
  routes,
  affiche,
  cluster,
  promoted,
  boost6h,
  boost24h,
  boost72h,
  coffee,
  footprints,
  music,
  user,
}

const _radarPinAssetByKind = <RadarMapPinKind, String>{
  RadarMapPinKind.bars: 'assets/map/pins/front2_pin_lime.png',
  RadarMapPinKind.routes: 'assets/map/pins/front2_pin_lilac.png',
  RadarMapPinKind.affiche: 'assets/map/pins/front2_pin_pink.png',
  RadarMapPinKind.cluster: 'assets/map/pins/front2_pin_cluster.png',
  RadarMapPinKind.promoted: 'assets/map/pins/front2_pin_boost_24h.png',
  RadarMapPinKind.boost6h: 'assets/map/pins/front2_pin_boost_6h.png',
  RadarMapPinKind.boost24h: 'assets/map/pins/front2_pin_boost_24h.png',
  RadarMapPinKind.boost72h: 'assets/map/pins/front2_pin_boost_72h.png',
  RadarMapPinKind.coffee: 'assets/map/pins/front2_pin_lime.png',
  RadarMapPinKind.footprints: 'assets/map/pins/front2_pin_lilac.png',
  RadarMapPinKind.music: 'assets/map/pins/front2_pin_lime.png',
  RadarMapPinKind.user: 'assets/map/pins/radar_pin_user.png',
};

final radarNativeMapEnabledProvider = Provider<bool>((_) => true);

bool radarShouldRenderNativeMap({
  required bool nativeMapEnabled,
  required bool hasDartMapKitKey,
}) {
  return nativeMapEnabled || hasDartMapKitKey;
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapEventsQuery? _mapQuery;
  ym.YandexMapController? _controller;
  Timer? _viewportDebounce;
  final DateasyMapObjectCache _mapObjectCache = DateasyMapObjectCache();
  List<BackendCardItem> _lastMapEvents = const [];
  String? _resolvedCityKey;
  String? _resolvingCityKey;
  ym.Point? _cityPoint;
  String _filter = 'meetups';
  String _selectedId = '';
  bool _nearbyOpen = true;
  bool _initialCameraReady = false;
  bool _locatingUser = false;
  bool _cityResolveFailed = false;
  int _cityResolveGeneration = 0;

  MapEventsQuery get _effectiveQuery =>
      _mapQuery ??
      initialRadarMapEventsQuery(
        preferredPoint: _radarPointForCity(ref.read(currentUserProvider)?.city),
        radiusKm: ref.read(nearbyEventsRadiusKmProvider),
      );

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    super.dispose();
  }

  void _ensureCityPoint(String? city) {
    final key = city?.trim() ?? '';
    if (_resolvedCityKey == key || _resolvingCityKey == key) {
      return;
    }
    final generation = ++_cityResolveGeneration;
    _resolvingCityKey = key;
    Future<void>(() async {
      if (!mounted || generation != _cityResolveGeneration) {
        return;
      }
      setState(() {
        _mapQuery = null;
        _lastMapEvents = const [];
        _selectedId = '';
        _initialCameraReady = false;
        _cityResolveFailed = false;
      });
      final point = await _resolveCityPoint(city);
      if (!mounted || generation != _cityResolveGeneration) {
        return;
      }
      setState(() {
        _resolvedCityKey = key;
        _resolvingCityKey = null;
        _cityPoint = point;
        _cityResolveFailed = key.isNotEmpty && point == null;
      });
      if (point != null) {
        await _moveToRadius(point, ref.read(nearbyEventsRadiusKmProvider));
      }
    });
  }

  Future<ym.Point?> _resolveCityPoint(String? city) async {
    final trimmed = city?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return radarDefaultMapPoint;
    }
    final catalogPoint = pointForCityCoordinates(cityPointForQuery(trimmed));
    if (catalogPoint != null) {
      return catalogPoint;
    }
    try {
      final results = await ref
          .read(yandexCitySearchServiceProvider)
          .search(trimmed, limit: 1);
      if (results.isEmpty) {
        return null;
      }
      final first = results.first;
      return _pointFromCoordinates(first.latitude, first.longitude);
    } catch (_) {
      return null;
    }
  }

  ym.Point? _radarPointForCity(String? city) {
    final key = city?.trim() ?? '';
    if (key.isEmpty) {
      return radarDefaultMapPoint;
    }
    if (_resolvedCityKey != key) {
      return null;
    }
    return _cityPoint;
  }

  Widget _buildCityResolvingState(String? city) {
    final resolving = !_cityResolveFailed;
    return DateasyPhoneFrame(
      child: Stack(
        children: [
          const Positioned.fill(child: _MapkitUnavailableState()),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (resolving)
                    const CircularProgressIndicator(color: DateasyColors.lime)
                  else
                    const Icon(
                      LucideIcons.mapPinOff,
                      color: DateasyColors.muted,
                      size: 36,
                    ),
                  const SizedBox(height: 14),
                  Text(
                    resolving
                        ? 'Готовлю карту города'
                        : 'Не удалось найти город на карте',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: DateasyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (!resolving) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        _resolvedCityKey = null;
                        _resolvingCityKey = null;
                        _ensureCityPoint(city);
                      },
                      child: const Text(
                        'Повторить',
                        style: TextStyle(
                          color: DateasyColors.lime,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const DateasyBottomNav(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final radiusKm = ref.watch(nearbyEventsRadiusKmProvider);
    final city = user?.city?.trim();
    _ensureCityPoint(city);
    final radarPoint = _radarPointForCity(city);
    if (radarPoint == null) {
      return _buildCityResolvingState(city);
    }
    final query = _mapQuery ??
        initialRadarMapEventsQuery(
          preferredPoint: radarPoint,
          radiusKm: radiusKm,
        );
    final eventsState = ref.watch(mapEventsProvider(query));
    final events = visibleMapEventsForRadar(
      eventsState: eventsState,
      previousEvents: _lastMapEvents,
    );
    if (eventsState.hasValue) {
      _lastMapEvents = events;
    }
    final categoryCounts = buildRadarCategoryCounts(events);
    final activeFilter = activeRadarFilterForCounts(
      selectedFilter: _filter,
      counts: categoryCounts,
    );
    final filteredEvents = _filteredEvents(events, activeFilter);
    final selectedId = _selectedId.isNotEmpty
        ? _selectedId
        : filteredEvents.isEmpty
            ? ''
            : filteredEvents.first.id;
    final nearby =
        filteredEvents.map(_NearbyItem.fromBackend).toList(growable: false);
    final mapObjects = _mapObjectCache.objectsFor(
      events: filteredEvents,
      selectedId: selectedId,
      onPinTap: _handlePinTap,
    );

    return DateasyPhoneFrame(
      child: Stack(
        children: [
          Positioned.fill(
            child: _NativeMap(
              mapObjects: mapObjects,
              loading: eventsState.isLoading && events.isEmpty,
              renderNativeMap: radarShouldRenderNativeMap(
                nativeMapEnabled: ref.watch(radarNativeMapEnabledProvider),
                hasDartMapKitKey: BackendConfig.hasMapKitKey,
              ),
              onCreated: _handleMapCreated,
              onCameraFinished: _handleCameraFinished,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopControls(onRadiusTap: () => _showRadiusSheet(radiusKm)),
                  _FilterChips(
                    filter: activeFilter,
                    counts: categoryCounts,
                    onSelect: _selectFilter,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapZoomButton(
                    icon: LucideIcons.plus,
                    onTap: () => _changeZoom(_mapZoomStep),
                  ),
                  const SizedBox(height: 8),
                  _MapZoomButton(
                    icon: LucideIcons.navigation,
                    loading: _locatingUser,
                    onTap: _focusCurrentLocation,
                  ),
                  const SizedBox(height: 8),
                  _MapZoomButton(
                    icon: LucideIcons.minus,
                    onTap: () => _changeZoom(-_mapZoomStep),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 104,
            child: _NearbyCard(
              items: nearby,
              loading: eventsState.isLoading && events.isEmpty,
              hasError: eventsState.hasError,
              open: _nearbyOpen,
              onToggle: () => setState(() => _nearbyOpen = !_nearbyOpen),
              onSwipe: (open) => setState(() => _nearbyOpen = open),
              onPageChanged: _handleNearbyPageChanged,
            ),
          ),
          const DateasyBottomNav(),
        ],
      ),
    );
  }

  Future<void> _handleMapCreated(ym.YandexMapController controller) async {
    _controller = controller;
    final initialQuery = _effectiveQuery;
    if (mounted && _mapQuery == null) {
      setState(() => _mapQuery = initialQuery);
    }
    await controller.moveCamera(
      ym.CameraUpdate.newCameraPosition(
        _cameraForQuery(initialQuery, MediaQuery.sizeOf(context)),
      ),
    );
    if (!mounted || !identical(_controller, controller)) {
      return;
    }
    _initialCameraReady = true;
    await _updateViewportFromNative();
  }

  void _handleCameraFinished(ym.CameraPosition cameraPosition) {
    if (!_initialCameraReady) {
      return;
    }
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _updateViewportFromNative(center: cameraPosition.target),
    );
  }

  Future<void> _updateViewportFromNative({ym.Point? center}) async {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    try {
      final region = await controller.getVisibleRegion();
      final cameraCenter =
          center ?? (await controller.getCameraPosition()).target;
      if (!mounted || !identical(_controller, controller)) {
        return;
      }
      final next = buildMapEventsQuery(
        bounds: boundingBoxFromVisibleRegion(region),
        center: cameraCenter,
      );
      if (_effectiveQuery == next) {
        return;
      }
      setState(() => _mapQuery = next);
    } catch (_) {
      return;
    }
  }

  void _selectFilter(String nextFilter) {
    if (_filter == nextFilter) {
      return;
    }
    final nextEvents = _filteredEvents(_lastMapEvents, nextFilter);
    final nextSelectedId = nextEvents.isEmpty ? '' : nextEvents.first.id;
    setState(() {
      _filter = nextFilter;
      _selectedId = nextSelectedId;
    });
    if (nextEvents.isNotEmpty) {
      final point = pointForEvent(nextEvents.first);
      if (point != null) {
        unawaited(_moveToPoint(point, keepCurrentZoom: true));
      }
    }
  }

  void _handlePinTap(String eventId) {
    final event =
        _lastMapEvents.where((item) => item.id == eventId).firstOrNull;
    final nextFilter = event == null ? _filter : radarCategoryForEvent(event);
    setState(() {
      _selectedId = eventId;
      _filter = nextFilter;
    });
    final point = event == null ? null : pointForEvent(event);
    if (point != null) {
      unawaited(_moveToPoint(point, keepCurrentZoom: true));
    }
  }

  void _handleNearbyPageChanged(String eventId) {
    final event =
        _lastMapEvents.where((item) => item.id == eventId).firstOrNull;
    if (event == null) {
      return;
    }
    setState(() {
      _selectedId = eventId;
      _filter = radarCategoryForEvent(event);
    });
    unawaited(_moveToEventFromList(event));
  }

  Future<void> _changeZoom(double delta) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      final camera = await controller.getCameraPosition();
      await controller.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: camera.target,
            zoom: clampMapZoom(camera.zoom + delta),
            azimuth: camera.azimuth,
            tilt: camera.tilt,
          ),
        ),
        animation: const ym.MapAnimation(
          type: ym.MapAnimationType.smooth,
          duration: 0.22,
        ),
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _focusCurrentLocation() async {
    if (_locatingUser) {
      return;
    }
    setState(() => _locatingUser = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMapSnack('Геолокация выключена');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMapSnack('Нет доступа к геолокации');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) {
        return;
      }
      final point = ym.Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final controller = _controller;
      if (controller != null) {
        unawaited(controller.toggleUserLayer(visible: true));
      }
      ref
          .read(nearbyEventsRadiusKmProvider.notifier)
          .setRadiusKm(_radarUserFocusRadiusKm);
      setState(() {
        _selectedId = '';
        _mapQuery = buildInitialMapEventsQuery(
          point,
          radiusKm: _radarUserFocusRadiusKm,
        );
      });
      await _moveToRadius(point, _radarUserFocusRadiusKm);
    } catch (_) {
      _showMapSnack('Не удалось определить геолокацию');
    } finally {
      if (mounted) {
        setState(() => _locatingUser = false);
      }
    }
  }

  void _showMapSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _moveToPoint(
    ym.Point point, {
    bool keepCurrentZoom = false,
    double? targetZoom,
  }) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      final camera = await controller.getCameraPosition();
      await controller.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: point,
            zoom: targetZoom ??
                (keepCurrentZoom ? clampMapZoom(camera.zoom) : 15),
            azimuth: 0,
            tilt: 0,
          ),
        ),
        animation: const ym.MapAnimation(
          type: ym.MapAnimationType.smooth,
          duration: 0.28,
        ),
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _moveToEventFromList(BackendCardItem event) async {
    final controller = _controller;
    final point = pointForEvent(event);
    if (controller == null || point == null) {
      return;
    }
    try {
      final camera = await controller.getCameraPosition();
      await _moveToPoint(
        point,
        targetZoom: mapZoomForNearbySelection(currentZoom: camera.zoom),
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _changeNearbyRadius(double value) async {
    final radiusKm = clampNearbyEventsRadiusKm(value);
    ref.read(nearbyEventsRadiusKmProvider.notifier).setRadiusKm(radiusKm);
    final center = await _currentCameraCenter() ??
        _queryCenter(_effectiveQuery) ??
        _radarPointForCity(ref.read(currentUserProvider)?.city) ??
        radarDefaultMapPoint;
    if (!mounted) {
      return;
    }
    setState(() {
      _mapQuery = buildInitialMapEventsQuery(center, radiusKm: radiusKm);
    });
    await _moveToRadius(center, radiusKm);
  }

  Future<ym.Point?> _currentCameraCenter() async {
    final controller = _controller;
    if (controller == null) {
      return null;
    }
    try {
      return (await controller.getCameraPosition()).target;
    } catch (_) {
      return null;
    }
  }

  Future<void> _moveToRadius(ym.Point center, double radiusKm) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    try {
      await controller.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: center,
            zoom: mapZoomForRadiusKm(
              radiusKm: radiusKm,
              viewportSize: size,
              latitude: center.latitude,
            ),
            azimuth: 0,
            tilt: 0,
          ),
        ),
        animation: const ym.MapAnimation(
          type: ym.MapAnimationType.smooth,
          duration: 0.28,
        ),
      );
    } catch (_) {
      return;
    }
  }

  void _showRadiusSheet(double currentRadiusKm) {
    var radiusKm = currentRadiusKm;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _GlassPanel(
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Радиус радара',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${radiusKm.round()} км',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Slider(
                      min: 1,
                      max: nearbyEventsMaxRadiusKm,
                      divisions: nearbyEventsMaxRadiusKm.round() - 1,
                      value: radiusKm,
                      activeColor: DateasyColors.lime,
                      inactiveColor: DateasyColors.border,
                      onChanged: (value) {
                        setSheetState(() => radiusKm = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        unawaited(_changeNearbyRadius(radiusKm));
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: dateasyLimeGradient,
                        ),
                        child: const Text(
                          'Применить',
                          style: TextStyle(
                            color: DateasyColors.backgroundDeep,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NativeMap extends StatelessWidget {
  const _NativeMap({
    required this.mapObjects,
    required this.loading,
    required this.renderNativeMap,
    required this.onCreated,
    required this.onCameraFinished,
  });

  final List<ym.MapObject> mapObjects;
  final bool loading;
  final bool renderNativeMap;
  final ValueChanged<ym.YandexMapController> onCreated;
  final ValueChanged<ym.CameraPosition> onCameraFinished;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (renderNativeMap)
          ym.YandexMap(
            nightModeEnabled: true,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            mode2DEnabled: true,
            mapObjects: mapObjects,
            onMapCreated: onCreated,
            onCameraPositionChanged: (position, _, finished) {
              if (finished) {
                onCameraFinished(position);
              }
            },
          )
        else
          const _MapkitUnavailableState(),
        if (loading)
          const Center(
            child: CircularProgressIndicator(color: DateasyColors.lime),
          ),
      ],
    );
  }
}

class _MapkitUnavailableState extends StatelessWidget {
  const _MapkitUnavailableState();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: dateasyHeroGradient),
      child: Center(
        child: Icon(
          LucideIcons.map,
          size: 40,
          color: DateasyColors.muted,
        ),
      ),
    );
  }
}

class DateasyMapObjectCache {
  String _key = '';
  List<ym.MapObject> _objects = const [];

  List<ym.MapObject> objectsFor({
    required List<BackendCardItem> events,
    required String selectedId,
    double pulsePhase = 0,
    required ValueChanged<String> onPinTap,
  }) {
    final nextKey = buildMapObjectsCacheKey(
      events: events,
      selectedId: selectedId,
      pulsePhase: pulsePhase,
    );
    if (nextKey == _key) {
      return _objects;
    }
    final placemarks = buildEventPlacemarks(
      events: events,
      selectedId: selectedId,
      pulsePhase: pulsePhase,
      onPinTap: onPinTap,
    );
    if (placemarks.isEmpty) {
      _key = nextKey;
      _objects = const [];
      return const [];
    }
    final objects = <ym.MapObject>[
      if (placemarks.length > _radarClusterPointThreshold)
        ym.ClusterizedPlacemarkCollection(
          mapId: const ym.MapObjectId('event-pins'),
          radius: _radarClusterRadius,
          minZoom: _radarClusterMinZoom,
          placemarks: placemarks,
          onClusterAdded: (_, cluster) async {
            return cluster.copyWith(
              appearance: cluster.appearance.copyWith(
                opacity: 0.92,
                icon: ym.PlacemarkIcon.single(
                  radarPinIconStyle(
                    kind: RadarMapPinKind.cluster,
                    selected: false,
                  ),
                ),
                text: ym.PlacemarkText(
                  text: radarClusterText(cluster.size),
                  style: radarClusterTextStyle(cluster.size),
                ),
              ),
            );
          },
        )
      else ...[
        ...buildEventWaveObjects(
          events: events,
          selectedId: selectedId,
          pulsePhase: pulsePhase,
        ),
        ...placemarks,
      ],
    ];
    _key = nextKey;
    _objects = List<ym.MapObject>.unmodifiable(objects);
    return _objects;
  }
}

String buildMapObjectsCacheKey({
  required List<BackendCardItem> events,
  required String selectedId,
  double pulsePhase = 0,
}) {
  final parts = <String>[
    'selected:$selectedId',
  ];
  for (final event in events) {
    for (final entry in pointsForEvent(event)) {
      parts.add(
        [
          event.id,
          entry.idSuffix,
          entry.point.latitude.toStringAsFixed(5),
          entry.point.longitude.toStringAsFixed(5),
          radarCategoryForEvent(event),
          meetingBoostTierFromRaw(event.raw)?.optionId ?? '',
        ].join(':'),
      );
    }
  }
  return parts.join('|');
}

List<ym.PlacemarkMapObject> buildEventPlacemarks({
  required List<BackendCardItem> events,
  required String selectedId,
  double pulsePhase = 0,
  required ValueChanged<String> onPinTap,
}) {
  return [
    for (final event in events)
      for (final entry in pointsForEvent(event))
        _eventPlacemark(
          event: event,
          pointEntry: entry,
          selected: event.id == selectedId,
          pulsePhase: pulsePhase,
          onPinTap: onPinTap,
        ),
  ];
}

ym.PlacemarkMapObject _eventPlacemark({
  required BackendCardItem event,
  required EventMapPoint pointEntry,
  required bool selected,
  required double pulsePhase,
  required ValueChanged<String> onPinTap,
}) {
  return ym.PlacemarkMapObject(
    mapId: ym.MapObjectId('event-${event.id}${pointEntry.idSuffix}'),
    point: pointEntry.point,
    zIndex: selected ? 2 : 1,
    consumeTapEvents: true,
    opacity: 1,
    onTap: (_, __) => onPinTap(event.id),
    icon: ym.PlacemarkIcon.single(
      radarPinIconStyle(
        kind: radarPinKindForEvent(event),
        selected: selected,
      ),
    ),
  );
}

ym.PlacemarkIconStyle radarPinIconStyle({
  required RadarMapPinKind kind,
  required bool selected,
}) {
  final scale = switch (kind) {
    RadarMapPinKind.user => 1.0,
    RadarMapPinKind.cluster => _radarClusterPinScale,
    RadarMapPinKind.promoted ||
    RadarMapPinKind.boost6h ||
    RadarMapPinKind.boost24h ||
    RadarMapPinKind.boost72h =>
      selected ? 1.34 : 1.22,
    _ => selected ? _radarSelectedPinScale : _radarPinScale,
  };
  return ym.PlacemarkIconStyle(
    image: ym.BitmapDescriptor.fromAssetImage(_radarPinAssetByKind[kind]!),
    anchor: kind == RadarMapPinKind.user || kind == RadarMapPinKind.cluster
        ? const Offset(0.5, 0.5)
        : const Offset(0.5, 0.82),
    scale: scale,
  );
}

List<ym.CircleMapObject> buildEventWaveObjects({
  required List<BackendCardItem> events,
  required String selectedId,
  double pulsePhase = 0,
}) {
  final phase = pulsePhase.clamp(0, 1).toDouble();
  return [
    for (final event in events)
      for (final entry in pointsForEvent(event))
        ym.CircleMapObject(
          mapId: ym.MapObjectId('event-wave-${event.id}${entry.idSuffix}'),
          circle: ym.Circle(
            center: entry.point,
            radius:
                _radarWaveMinRadiusMeters + phase * _radarWaveRadiusStepMeters,
          ),
          zIndex: event.id == selectedId ? 0.7 : 0.5,
          strokeWidth: 0,
          strokeColor: Colors.transparent,
          fillColor: radarPinColorForKind(
            radarPinKindForEvent(event),
          ).withValues(alpha: 0.24 - phase * 0.16),
        ),
  ];
}

Color radarPinColorForKind(RadarMapPinKind kind) {
  return switch (kind) {
    RadarMapPinKind.affiche ||
    RadarMapPinKind.promoted ||
    RadarMapPinKind.boost24h =>
      DateasyColors.pink,
    RadarMapPinKind.routes || RadarMapPinKind.footprints => DateasyColors.lilac,
    RadarMapPinKind.boost72h => const Color(0xFFFFB020),
    _ => DateasyColors.lime,
  };
}

String radarClusterText(int size) {
  if (size > 999) {
    return '999+';
  }
  return size.toString();
}

ym.PlacemarkTextStyle radarClusterTextStyle(int size) {
  final text = radarClusterText(size);
  final fontSize = switch (text.length) {
    1 => 14.0,
    2 => 12.0,
    3 => 10.5,
    _ => 9.0,
  };
  return ym.PlacemarkTextStyle(
    size: fontSize,
    color: DateasyColors.backgroundDeep,
    outlineColor: Colors.transparent,
    placement: ym.TextStylePlacement.center,
    offsetFromIcon: false,
  );
}

class _TopControls extends StatelessWidget {
  const _TopControls({required this.onRadiusTap});

  final VoidCallback onRadiusTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          child: const _GlassPanel(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(LucideIcons.arrowLeft, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => context.go('/search'),
            child: const _GlassPanel(
              borderRadius: 16,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search,
                    size: 16,
                    color: DateasyColors.muted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Места, события, люди',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: DateasyColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRadiusTap,
          child: const _GlassPanel(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(LucideIcons.slidersHorizontal, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.counts,
    required this.onSelect,
  });

  final String filter;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        children: [
          for (var index = 0; index < _radarFilters.length; index++) ...[
            _FilterChip(
              label:
                  '${_radarFilters[index].title} · ${counts[_radarFilters[index].key] ?? 0}',
              active: filter == _radarFilters[index].key,
              onTap: () => onSelect(_radarFilters[index].key),
            ),
            if (index != _radarFilters.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? DateasyColors.foreground : DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: active
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: active
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground,
                fontSize: 12,
                height: 1.15,
                fontWeight: active ? FontWeight.w600 : null,
              ),
        ),
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: _GlassPanel(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 42,
          height: 42,
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DateasyColors.foreground,
                    ),
                  ),
                )
              : Icon(icon, size: 18),
        ),
      ),
    );
  }
}

List<BackendCardItem> _filteredEvents(
  List<BackendCardItem> events,
  String filter,
) {
  return events
      .where((event) => radarCategoryForEvent(event) == filter)
      .toList(growable: false);
}

class _RadarFilterDefinition {
  const _RadarFilterDefinition({
    required this.key,
    required this.title,
  });

  final String key;
  final String title;
}

const _radarFilters = [
  _RadarFilterDefinition(key: 'meetups', title: 'Встречи'),
  _RadarFilterDefinition(key: 'routes', title: 'Маршруты'),
  _RadarFilterDefinition(key: 'affiche', title: 'Афиша'),
];

Map<String, int> buildRadarCategoryCounts(List<BackendCardItem> events) {
  final counts = <String, int>{
    for (final filter in _radarFilters) filter.key: 0,
  };
  for (final event in events) {
    final category = radarCategoryForEvent(event);
    counts[category] = (counts[category] ?? 0) + 1;
  }
  return counts;
}

String activeRadarFilterForCounts({
  required String selectedFilter,
  required Map<String, int> counts,
}) {
  if ((counts[selectedFilter] ?? 0) > 0) {
    return selectedFilter;
  }
  for (final filter in _radarFilters) {
    if ((counts[filter.key] ?? 0) > 0) {
      return filter.key;
    }
  }
  return selectedFilter;
}

String radarCategoryForEvent(BackendCardItem event) {
  final raw = event.raw;
  if (raw['source'] == 'affiche' ||
      raw['afficheEventId'] != null ||
      _stringOrNull(raw['ticketUrl'] ?? raw['actionUrl']) != null ||
      _stringOrNull(raw['ticketSourceKind'] ?? raw['ticketSourceCode']) !=
          null) {
    return 'affiche';
  }
  final routePointCount = _intOrNull(raw['routePointCount']);
  final routeId = _stringOrNull(raw['routeId']);
  if ((routePointCount ?? 0) > 1 ||
      (routePointCount == null && routeId != null)) {
    return 'routes';
  }
  return 'meetups';
}

RadarMapPinKind radarPinKindForEvent(BackendCardItem event) {
  final raw = event.raw;
  final boostTier = meetingBoostTierFromRaw(raw);
  if (boostTier?.id == '72h') {
    return RadarMapPinKind.boost72h;
  }
  if (boostTier?.id == '24h') {
    return RadarMapPinKind.boost24h;
  }
  if (boostTier?.id == '6h') {
    return RadarMapPinKind.boost6h;
  }
  if (raw['isAfterDark'] == true) {
    return RadarMapPinKind.promoted;
  }
  final category = radarCategoryForEvent(event);
  if (category == 'affiche') {
    return RadarMapPinKind.affiche;
  }
  final pinText = [
    event.title,
    event.subtitle,
    raw['vibe'],
    raw['place'],
    raw['emoji'],
  ].whereType<Object>().join(' ').toLowerCase();
  if (category == 'routes') {
    if (pinText.contains('прогул') ||
        pinText.contains('пеш') ||
        pinText.contains('🚶')) {
      return RadarMapPinKind.footprints;
    }
    return RadarMapPinKind.routes;
  }
  if (pinText.contains('coffee') ||
      pinText.contains('кофе') ||
      pinText.contains('☕')) {
    return RadarMapPinKind.coffee;
  }
  if (pinText.contains('jazz') ||
      pinText.contains('джаз') ||
      pinText.contains('music') ||
      pinText.contains('музык') ||
      pinText.contains('концерт') ||
      pinText.contains('🎙') ||
      pinText.contains('🎵') ||
      pinText.contains('🎶')) {
    return RadarMapPinKind.music;
  }
  return RadarMapPinKind.bars;
}

List<BackendCardItem> visibleMapEventsForRadar({
  required AsyncValue<BackendPage<BackendCardItem>> eventsState,
  required List<BackendCardItem> previousEvents,
}) {
  if (eventsState.hasValue) {
    final events = eventsState.valueOrNull?.items ?? const <BackendCardItem>[];
    return events;
  }
  return previousEvents;
}

class EventMapPoint {
  const EventMapPoint({
    required this.idSuffix,
    required this.point,
  });

  final String idSuffix;
  final ym.Point point;
}

List<EventMapPoint> pointsForEvent(BackendCardItem event) {
  final raw = event.raw;
  final routeId = _stringOrNull(raw['routeId']);
  final routePoints = raw['routePoints'];
  final stepPoints = raw['steps'];
  final points =
      routePoints is List && routePoints.isNotEmpty ? routePoints : stepPoints;
  if (routeId != null && points is List && points.isNotEmpty) {
    return [
      for (final entry in points.indexed)
        if (entry.$2 is Map)
          if (_pointFromRaw(Map<Object?, Object?>.from(entry.$2 as Map))
              case final point?)
            EventMapPoint(
              idSuffix: '-${_routePointMapIdSuffix(entry.$2 as Map, entry.$1)}',
              point: point,
            ),
    ];
  }
  final point = _pointFromCoordinates(event.latitude, event.longitude);
  if (point == null) {
    return const [];
  }
  return [EventMapPoint(idSuffix: '', point: point)];
}

ym.Point? pointForEvent(BackendCardItem event) {
  final points = pointsForEvent(event);
  return points.isEmpty ? null : points.first.point;
}

ym.Point? _pointFromRaw(Map<Object?, Object?> raw) {
  return _pointFromCoordinates(
    _doubleOrNull(raw['latitude'] ?? raw['lat']),
    _doubleOrNull(raw['longitude'] ?? raw['lng']),
  );
}

ym.Point? _pointFromCoordinates(double? latitude, double? longitude) {
  if (latitude == null ||
      longitude == null ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180 ||
      (latitude == 0 && longitude == 0)) {
    return null;
  }
  return ym.Point(latitude: latitude, longitude: longitude);
}

String _routePointMapIdSuffix(Map<Object?, Object?> raw, int index) {
  final id = _stringOrNull(raw['id']);
  if (id != null) {
    return id;
  }
  return 'route-point-$index';
}

MapEventsQuery buildMapEventsQuery({
  required ym.BoundingBox bounds,
  required ym.Point center,
}) {
  final radiusKm = [
    _distanceKm(center, bounds.southWest),
    _distanceKm(center, bounds.northEast),
  ].reduce(math.max);
  return MapEventsQuery(
    centerLatitude: _roundViewportGeo(center.latitude),
    centerLongitude: _roundViewportGeo(center.longitude),
    radiusKm: _roundDistanceKm(
      radiusKm.clamp(0.5, nearbyEventsMaxRadiusKm).toDouble(),
    ),
    southWestLatitude: _roundViewportGeo(bounds.southWest.latitude),
    southWestLongitude: _roundViewportGeo(bounds.southWest.longitude),
    northEastLatitude: _roundViewportGeo(bounds.northEast.latitude),
    northEastLongitude: _roundViewportGeo(bounds.northEast.longitude),
  );
}

ym.BoundingBox boundingBoxFromVisibleRegion(ym.VisibleRegion region) {
  final points = [
    region.topLeft,
    region.topRight,
    region.bottomLeft,
    region.bottomRight,
  ];
  var minLatitude = points.first.latitude;
  var maxLatitude = points.first.latitude;
  var minLongitude = points.first.longitude;
  var maxLongitude = points.first.longitude;

  for (final point in points.skip(1)) {
    minLatitude = point.latitude < minLatitude ? point.latitude : minLatitude;
    maxLatitude = point.latitude > maxLatitude ? point.latitude : maxLatitude;
    minLongitude =
        point.longitude < minLongitude ? point.longitude : minLongitude;
    maxLongitude =
        point.longitude > maxLongitude ? point.longitude : maxLongitude;
  }

  return ym.BoundingBox(
    southWest: ym.Point(latitude: minLatitude, longitude: minLongitude),
    northEast: ym.Point(latitude: maxLatitude, longitude: maxLongitude),
  );
}

MapEventsQuery buildInitialMapEventsQuery(
  ym.Point point, {
  double radiusKm = nearbyEventsDefaultRadiusKm,
}) {
  return MapEventsQuery(
    centerLatitude: _roundGeo(point.latitude),
    centerLongitude: _roundGeo(point.longitude),
    radiusKm: radiusKm,
  );
}

MapEventsQuery initialRadarMapEventsQuery({
  ym.Point? preferredPoint,
  double radiusKm = nearbyEventsDefaultRadiusKm,
}) {
  return buildInitialMapEventsQuery(
    preferredPoint ?? radarDefaultMapPoint,
    radiusKm: radiusKm,
  );
}

double clampMapZoom(double zoom) {
  return zoom.clamp(_minMapZoom, _maxMapZoom).toDouble();
}

double mapZoomForNearbySelection({required double currentZoom}) {
  final zoom = clampMapZoom(currentZoom);
  if (zoom < _radarListFocusZoomThreshold) {
    return _radarListFocusZoom;
  }
  return zoom;
}

double mapZoomForRadiusKm({
  required double radiusKm,
  required Size viewportSize,
  required double latitude,
}) {
  const earthCircumferenceMeters = 40075016.686;
  const tileSize = 256.0;
  const radiansPerDegree = 0.017453292519943295;
  const log2 = 0.6931471805599453;
  final clampedRadiusKm =
      radiusKm.clamp(0.5, nearbyEventsMaxRadiusKm).toDouble();
  final latitudeScale =
      math.cos(latitude * radiansPerDegree).abs().clamp(0.01, 1).toDouble();
  final metersPerPixelAtZoomZero =
      earthCircumferenceMeters * latitudeScale / tileSize;
  final fitPixels =
      math.max(120.0, math.min(viewportSize.width, viewportSize.height) * 0.72);
  final targetMetersPerPixel = (clampedRadiusKm * 2000) / fitPixels;
  final zoom = math.log(metersPerPixelAtZoomZero / targetMetersPerPixel) / log2;
  return clampMapZoom(zoom);
}

ym.Point? pointForCityCoordinates(CityCoordinates? coordinates) {
  if (coordinates == null) {
    return null;
  }
  return ym.Point(
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
  );
}

ym.CameraPosition _cameraForQuery(MapEventsQuery query, Size viewportSize) {
  final point = _queryCenter(query) ?? radarDefaultMapPoint;
  return ym.CameraPosition(
    target: point,
    zoom: mapZoomForRadiusKm(
      radiusKm: query.radiusKm ?? nearbyEventsDefaultRadiusKm,
      viewportSize: viewportSize,
      latitude: point.latitude,
    ),
    azimuth: 0,
    tilt: 0,
  );
}

ym.Point? _queryCenter(MapEventsQuery query) {
  if (query.centerLatitude == null || query.centerLongitude == null) {
    return null;
  }
  return ym.Point(
    latitude: query.centerLatitude!,
    longitude: query.centerLongitude!,
  );
}

double _distanceKm(ym.Point from, ym.Point to) {
  const earthRadiusKm = 6371.0;
  final latitudeDelta = (to.latitude - from.latitude) * 0.017453292519943295;
  final longitudeDelta = (to.longitude - from.longitude) * 0.017453292519943295;
  final fromRad = from.latitude * 0.017453292519943295;
  final toRad = to.latitude * 0.017453292519943295;
  final a = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(fromRad) *
          math.cos(toRad) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return 2 * earthRadiusKm * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _roundGeo(double value) => double.parse(value.toStringAsFixed(5));

double _roundViewportGeo(double value) =>
    double.parse(value.toStringAsFixed(3));

double _roundDistanceKm(double value) => double.parse(value.toStringAsFixed(1));

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.items,
    required this.loading,
    required this.hasError,
    required this.open,
    required this.onToggle,
    required this.onSwipe,
    required this.onPageChanged,
  });

  final List<_NearbyItem> items;
  final bool loading;
  final bool hasError;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<bool> onSwipe;
  final ValueChanged<String> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(items.length, 8);
    final body = loading
        ? const _NearbyStatus(text: 'Загружаем события')
        : items.isEmpty
            ? _NearbyStatus(
                text: hasError
                    ? 'Не удалось загрузить события'
                    : 'В этом viewport ничего не найдено',
              )
            : PageView.builder(
                controller: PageController(viewportFraction: 0.82),
                padEnds: false,
                itemCount: visibleCount,
                onPageChanged: (index) => onPageChanged(items[index].id),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == visibleCount - 1 ? 0 : 8,
                    ),
                    child: _NearbyRow(item: items[index]),
                  );
                },
              );

    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 120) {
          onSwipe(false);
        } else if (velocity < -120) {
          onSwipe(true);
        }
      },
      child: _GlassPanel(
        borderRadius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Рядом сейчас · ${items.length}'.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.muted,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0 : 0.5,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: DateasyColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        height: loading || items.isEmpty ? 72 : 76,
                        child: body,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyStatus extends StatelessWidget {
  const _NearbyStatus({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.muted,
            ),
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.item});

  final _NearbyItem item;

  @override
  Widget build(BuildContext context) {
    final boostTier = item.boostTier;
    final boostVisual =
        boostTier == null ? null : meetingBoostVisual(boostTier);
    return GestureDetector(
      onTap: () => context.push('/meetings/${item.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: boostVisual == null
              ? null
              : LinearGradient(
                  colors: [
                    boostVisual.primary.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color:
              boostVisual == null ? Colors.white.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: boostVisual?.primary.withValues(alpha: 0.62) ??
                DateasyColors.border,
          ),
          boxShadow: [
            if (boostVisual != null)
              BoxShadow(
                color: boostVisual.glow.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: dateasyLimeGradient,
              ),
              child: Icon(
                item.icon,
                color: DateasyColors.backgroundDeep,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      if (boostTier != null) ...[
                        const SizedBox(width: 6),
                        MeetingBoostBadge(tier: boostTier, compact: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: dateasyLimeGradient,
              ),
              child: Text(
                '+Я',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.backgroundDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: child,
      ),
    );
  }
}

class _NearbyItem {
  const _NearbyItem({
    required this.id,
    required this.title,
    required this.meta,
    required this.icon,
    required this.boostTier,
  });

  final String id;
  final String title;
  final String meta;
  final IconData icon;
  final MeetingBoostTier? boostTier;

  factory _NearbyItem.fromBackend(BackendCardItem item) {
    return _NearbyItem(
      id: item.id,
      title: item.title.isEmpty ? 'Встреча' : item.title,
      meta: [
        if (item.city != null) item.city,
        if (item.subtitle != null) item.subtitle,
      ].whereType<String>().join(' · '),
      boostTier: meetingBoostTierFromRaw(item.raw),
      icon: meetingBoostTierFromRaw(item.raw)?.icon ??
          (item.raw['isAfterDark'] == true
              ? LucideIcons.flame
              : LucideIcons.mapPin),
    );
  }
}
