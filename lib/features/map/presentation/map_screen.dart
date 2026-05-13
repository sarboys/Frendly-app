import 'dart:async';
import 'dart:math' as math;

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/features/tonight/presentation/v5_search_modal.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/dating_profile.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/widgets/bb_bottom_nav.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

@visibleForTesting
const mapAutoNativeUserLayerEnabled = false;

const _mapZoomStep = 1.0;
const _minMapZoom = 2.0;
const _maxMapZoom = 19.0;
const _radarCarouselInitialPage = 0;
const _nativeMapPoiLimit = 80;
const _manualRadiusViewportFitKey = 'manual-radius-fit';
const _radarClusterPointThreshold = 80;
const _radarClusterRadius = 48.0;
const _radarClusterMinZoom = 13;

@visibleForTesting
enum RadarMapPinKind {
  bars,
  routes,
  dating,
  affiche,
  live,
  user,
  search,
  cluster,
  promoted,
}

const _radarPinAssetByKind = <RadarMapPinKind, String>{
  RadarMapPinKind.bars: 'assets/map/pins/radar_pin_bars.png',
  RadarMapPinKind.routes: 'assets/map/pins/radar_pin_routes.png',
  RadarMapPinKind.dating: 'assets/map/pins/radar_pin_dating.png',
  RadarMapPinKind.affiche: 'assets/map/pins/radar_pin_affiche.png',
  RadarMapPinKind.live: 'assets/map/pins/radar_pin_live.png',
  RadarMapPinKind.user: 'assets/map/pins/radar_pin_user.png',
  RadarMapPinKind.cluster: 'assets/map/pins/radar_pin_cluster.png',
  RadarMapPinKind.promoted: 'assets/map/pins/radar_pin_promoted.png',
};

const _radarSelectedPinAssetByKind = <RadarMapPinKind, String>{
  RadarMapPinKind.bars: 'assets/map/pins/radar_pin_bars_selected.png',
  RadarMapPinKind.routes: 'assets/map/pins/radar_pin_routes_selected.png',
  RadarMapPinKind.dating: 'assets/map/pins/radar_pin_dating_selected.png',
  RadarMapPinKind.affiche: 'assets/map/pins/radar_pin_affiche_selected.png',
  RadarMapPinKind.live: 'assets/map/pins/radar_pin_live_selected.png',
  RadarMapPinKind.promoted: 'assets/map/pins/radar_pin_promoted_selected.png',
};

@visibleForTesting
const radarMapStyleJson = '''
[
  {
    "tags": {
      "all": ["poi"]
    },
    "stylers": {
      "saturation": -0.30,
      "lightness": 0.10
    }
  },
  {
    "tags": {
      "all": ["road"]
    },
    "stylers": {
      "saturation": -0.25,
      "lightness": 0.08
    }
  },
  {
    "tags": {
      "all": ["landscape"]
    },
    "stylers": {
      "saturation": -0.20,
      "lightness": 0.06
    }
  }
]
''';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    this.initialEventId,
    super.key,
  });

  final String? initialEventId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final Future<void> _mapBootstrapFuture;
  late final PageController _eventPageController;
  final MapObjectCache _mapObjectCache = MapObjectCache();
  ym.YandexMapController? _mapController;
  Timer? _viewportQueryDebounce;
  int _mapControllerGeneration = 0;
  int _viewportQueryGeneration = 0;
  int _viewportFitGeneration = 0;
  MapEventsQuery _mapQuery = const MapEventsQuery();
  ym.Point? _searchPoint;
  ym.Point? _userPoint;
  String selected = '';
  String selectedDatingUserId = '';
  String filter = 'all';
  bool _primingInitialLocation = false;
  bool _didPrimeInitialLocation = false;
  bool _triedInitialLocation = false;
  bool _autoFitPending = false;
  bool _isRadarListExpanded = true;
  bool _syncRadiusAfterProgrammaticZoom = false;
  String _lastViewportFitKey = '';
  List<Event> _lastMapEvents = const [];
  List<Event> _visibleMapEvents = const [];

  bool get _supportsNativeMap =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    _eventPageController = PageController(
      initialPage: _radarCarouselInitialPage,
      viewportFraction: 0.74,
    );
    final initialEventId = widget.initialEventId;
    if (initialEventId != null && initialEventId.isNotEmpty) {
      selected = initialEventId;
    }
    _mapBootstrapFuture = _supportsNativeMap
        ? ref.read(mapkitBootstrapProvider).ensureInitialized()
        : Future<void>.value();
    if ((initialEventId ?? '').isEmpty) {
      unawaited(_primeInitialUserLocation(animated: false));
    }
  }

  @override
  void dispose() {
    _mapControllerGeneration += 1;
    _viewportQueryGeneration += 1;
    _viewportFitGeneration += 1;
    _mapController = null;
    _viewportQueryDebounce?.cancel();
    _eventPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nearbyRadiusKm = ref.watch(nearbyEventsRadiusKmProvider);
    final mapEventsAsync = ref.watch(mapEventsProvider(_mapQuery));
    final datingProfilesAsync = ref.watch(datingDiscoverProvider);
    final wallet = ref.watch(tokenWalletProvider);
    final promotedIds = wallet.promoted.keys
        .where((eventId) => wallet.isPromoted(eventId))
        .toSet();
    final events = visibleMapEventsForRadar(
      eventsAsync: mapEventsAsync,
      previousEvents: _lastMapEvents,
    );
    if (mapEventsAsync.hasValue) {
      _lastMapEvents = events;
    }
    final datingProfiles = datingProfilesWithMapPoints(
      datingProfilesAsync.valueOrNull ?? const <DatingProfileData>[],
    );
    final filteredEvents =
        filter == 'dating' ? const <Event>[] : _filteredEvents(events, filter);
    final liveEvenings =
        (ref.watch(eveningSessionsProvider).valueOrNull ?? const [])
            .where((session) => session.phase == EveningSessionPhase.live)
            .take(4)
            .toList(growable: false);
    final activeDatingProfile = filter == 'dating'
        ? datingProfiles
                .where((item) => item.userId == selectedDatingUserId)
                .cast<DatingProfileData?>()
                .firstOrNull ??
            (datingProfiles.isNotEmpty ? datingProfiles.first : null)
        : null;
    final activeEvent = filteredEvents
            .where((item) => item.id == selected)
            .cast<Event?>()
            .firstOrNull ??
        (filteredEvents.isNotEmpty ? filteredEvents.first : null);
    final selectedId = activeEvent?.id ?? selected;
    _visibleMapEvents = filteredEvents;
    final mapObjects = _mapObjectCache.objectsFor(
      events: filteredEvents,
      selectedId: selectedId,
      promotedIds: promotedIds,
      datingProfiles: filter == 'dating' ? datingProfiles : const [],
      selectedDatingUserId: activeDatingProfile?.userId ?? selectedDatingUserId,
      liveEvenings: liveEvenings,
      userPoint: _userPoint,
      searchPoint: _searchPoint,
      onEventTap: _handleEventTap,
      onEventClusterTap: _handleEventClusterTap,
      onDatingProfileTap: _handleDatingProfileTap,
      onSessionTap: _openEveningPreview,
    );
    if (filter == 'dating') {
      _syncPagerToSelectedDatingProfile(
        datingProfiles,
        activeDatingProfile?.userId ?? selectedDatingUserId,
      );
      _scheduleDatingViewportFit(datingProfiles);
    } else {
      _syncPagerToSelected(filteredEvents, selectedId);
      _scheduleViewportFit(filteredEvents);
    }
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: BbV5Colors.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildMapSurface(
              filteredEvents,
              mapObjects,
              selectedId,
            ),
          ),
          if (!_supportsNativeMap)
            const Positioned.fill(
              child: IgnorePointer(
                child: _RadarMapVisualOverlay(
                  showUserPulse: true,
                ),
              ),
            ),
          if (!_supportsNativeMap)
            for (final entry in liveEvenings.asMap().entries)
              _LiveEveningMapPin(
                session: entry.value,
                index: entry.key,
              ),
          Positioned(
            left: 0,
            right: 0,
            top: topInset + 12,
            child: _RadarTopControls(
              events: events,
              datingProfileCount: datingProfiles.length,
              filter: filter,
              radiusKm: nearbyRadiusKm,
              onBack: _handleBack,
              onSelectFilter: (nextFilter) => _selectFilter(
                nextFilter,
                events,
                datingProfiles,
              ),
              onRadiusChanged: (value) => unawaited(_changeNearbyRadius(value)),
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
                  _MapTopButton(
                    icon: LucideIcons.plus,
                    tooltip: 'Приблизить',
                    onTap: () => _changeZoom(_mapZoomStep),
                  ),
                  const SizedBox(height: 8),
                  _MapTopButton(
                    icon: LucideIcons.minus,
                    tooltip: 'Отдалить',
                    onTap: () => _changeZoom(-_mapZoomStep),
                  ),
                ],
              ),
            ),
          ),
          if (filter == 'dating' && datingProfiles.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: _RadarDatingBottomSheet(
                profiles: datingProfiles,
                isExpanded: _isRadarListExpanded,
                pageController: _eventPageController,
                onPageChanged: (index) {
                  final profileIndex = radarCarouselEventIndex(
                    index,
                    datingProfiles.length,
                  );
                  if (profileIndex < 0 ||
                      profileIndex >= datingProfiles.length) {
                    return;
                  }
                  _selectDatingProfile(
                    datingProfiles[profileIndex],
                    datingProfiles,
                    animatePager: false,
                    keepCurrentZoom: true,
                  );
                },
                onExpandedChanged: (expanded) {
                  setState(() {
                    _isRadarListExpanded = expanded;
                  });
                },
                onProfileTap: (profile) => context.pushRoute(
                  AppRoute.userProfile,
                  pathParameters: {'userId': profile.userId},
                ),
              ),
            )
          else if (filteredEvents.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: _RadarBottomSheet(
                events: filteredEvents,
                isExpanded: _isRadarListExpanded,
                pageController: _eventPageController,
                onPageChanged: (index) {
                  final eventIndex = radarCarouselEventIndex(
                    index,
                    filteredEvents.length,
                  );
                  if (eventIndex < 0 || eventIndex >= filteredEvents.length) {
                    return;
                  }
                  _selectEvent(
                    filteredEvents[eventIndex],
                    filteredEvents,
                    animatePager: false,
                    keepCurrentZoom: true,
                  );
                },
                onExpandedChanged: (expanded) {
                  setState(() {
                    _isRadarListExpanded = expanded;
                  });
                },
                onEventTap: (event) => context.pushRoute(
                  AppRoute.eventDetail,
                  pathParameters: {'eventId': event.id},
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BbV5GlassBottomBar(
              child: BbBottomNav(
                location: AppRoute.tonight.path,
                onTap: (tab) => context.goRoute(tab.route),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goRoute(AppRoute.tonight);
  }

  Widget _buildMapSurface(
    List<Event> filteredEvents,
    List<ym.MapObject> mapObjects,
    String selectedId,
  ) {
    if (!_supportsNativeMap) {
      return _FallbackMapSurface(
        events: filteredEvents,
        selectedId: selectedId,
        onTap: _handleEventTap,
      );
    }

    return FutureBuilder<void>(
      future: _mapBootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FallbackMapSurface(
            key: const Key('map-bootstrap-error-surface'),
            events: filteredEvents,
            selectedId: selectedId,
            onTap: _handleEventTap,
            footer: const _NativeMapErrorBadge(),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const _NativeMapLoadingSurface(
            key: Key('map-native-loading'),
          );
        }

        return Container(
          key: const Key('map-native-surface'),
          color: const Color(0xFFF1ECE2),
          child: ym.YandexMap(
            mapObjects: mapObjects,
            onMapCreated: (controller) =>
                _onMapCreated(controller, filteredEvents),
            onCameraPositionChanged: _onCameraPositionChanged,
            onMapTap: _onMapTap,
            mapType: ym.MapType.vector,
            mode2DEnabled: true,
            poiLimit: _nativeMapPoiLimit,
          ),
        );
      },
    );
  }

  void _openEveningPreview(String sessionId) {
    context.pushRoute(
      AppRoute.eveningPreview,
      pathParameters: {'sessionId': sessionId},
    );
  }

  void _onMapCreated(
    ym.YandexMapController controller,
    List<Event> filteredEvents,
  ) {
    _mapControllerGeneration += 1;
    _mapController = controller;
    unawaited(controller.setMapStyle(radarMapStyleJson));
    if (mapAutoNativeUserLayerEnabled) {
      unawaited(controller.toggleUserLayer(visible: true));
    }
    final initialEventId = widget.initialEventId;
    if (initialEventId != null && initialEventId.isNotEmpty) {
      final activeEvent = filteredEvents
          .where((item) => item.id == initialEventId)
          .cast<Event?>()
          .firstOrNull;
      final point = activeEvent == null ? null : _pointForEvent(activeEvent);
      if (point == null) {
        return;
      }
      unawaited(
        _moveToPoint(
          point,
          zoom: 15,
          animated: false,
        ),
      );
      return;
    }

    final fitKey = buildMapViewportFitKey(filteredEvents, filter);
    if (shouldScheduleMapViewportFit(
      supportsNativeMap: _supportsNativeMap,
      hasMapController: _mapController != null,
      hasInitialEvent: false,
      autoFitPending: _autoFitPending,
      fitKey: fitKey,
      lastFitKey: _lastViewportFitKey,
    )) {
      _autoFitPending = false;
      _lastViewportFitKey = fitKey;
      final fitGeneration = ++_viewportFitGeneration;
      unawaited(
        _fitViewportForEvents(
          filteredEvents,
          animated: false,
          fitGeneration: fitGeneration,
        ),
      );
      return;
    }
    if (_userPoint != null) {
      unawaited(_moveToUserPreview(_userPoint!, animated: false));
    } else {
      unawaited(_primeInitialUserLocation(animated: false));
    }
  }

  void _onCameraPositionChanged(
    ym.CameraPosition cameraPosition,
    ym.CameraUpdateReason reason,
    bool finished,
  ) {
    final shouldSyncProgrammaticZoom = _syncRadiusAfterProgrammaticZoom &&
        reason == ym.CameraUpdateReason.application &&
        finished;
    if (shouldSyncProgrammaticZoom) {
      _syncRadiusAfterProgrammaticZoom = false;
    }

    if (!shouldRefreshMapViewportQuery(
      reason: reason,
      finished: finished,
      allowApplication: shouldSyncProgrammaticZoom,
    )) {
      return;
    }

    _viewportQueryDebounce?.cancel();
    final queryGeneration = ++_viewportQueryGeneration;
    _viewportQueryDebounce = Timer(
      const Duration(milliseconds: 250),
      () {
        if (!mounted ||
            _mapController == null ||
            queryGeneration != _viewportQueryGeneration) {
          return;
        }
        unawaited(
          _refreshViewportQuery(
            center: cameraPosition.target,
            queryGeneration: queryGeneration,
          ),
        );
      },
    );
  }

  Future<void> _refreshViewportQuery({
    ym.Point? center,
    required int queryGeneration,
  }) async {
    final controller = _mapController;
    final generation = _mapControllerGeneration;
    if (controller == null) {
      return;
    }

    try {
      final visibleRegion = await controller.getVisibleRegion();
      if (!_isActiveMapController(controller, generation) ||
          queryGeneration != _viewportQueryGeneration) {
        return;
      }
      final cameraCenter =
          center ?? (await controller.getCameraPosition()).target;
      if (!_isActiveMapController(controller, generation) ||
          queryGeneration != _viewportQueryGeneration) {
        return;
      }

      final nextQuery = buildMapEventsQuery(
        bounds: boundingBoxFromVisibleRegion(visibleRegion),
        center: cameraCenter,
      );
      final currentRadiusKm = ref.read(nearbyEventsRadiusKmProvider);
      final nextRadiusKm = nearbyRadiusKmFromMapQuery(
        currentRadiusKm: currentRadiusKm,
        query: nextQuery,
      );
      if (nextRadiusKm != currentRadiusKm) {
        ref
            .read(nearbyEventsRadiusKmProvider.notifier)
            .setRadiusKm(nextRadiusKm);
      }
      if (nextQuery == _mapQuery) {
        return;
      }
      if (queryGeneration != _viewportQueryGeneration) {
        return;
      }

      setState(() {
        _mapQuery = nextQuery;
      });
    } catch (_) {
      return;
    }
  }

  bool _isActiveMapController(
    ym.YandexMapController controller,
    int generation,
  ) {
    return mounted &&
        identical(_mapController, controller) &&
        _mapControllerGeneration == generation;
  }

  Future<void> _primeInitialUserLocation({required bool animated}) async {
    if (_didPrimeInitialLocation || _primingInitialLocation) {
      return;
    }

    _didPrimeInitialLocation = true;
    _primingInitialLocation = true;
    _triedInitialLocation = true;
    try {
      final point = await _resolvePreferredMapPoint();
      if (point == null || !mounted) {
        return;
      }

      setState(() {
        _autoFitPending = true;
        _userPoint = point;
        _mapQuery = buildInitialMapEventsQuery(point);
      });

      unawaited(_moveToUserPreview(point, animated: animated));
    } finally {
      _primingInitialLocation = false;
    }
  }

  Future<void> _changeNearbyRadius(double value) async {
    final radiusKm = clampNearbyEventsRadiusKm(value);
    ref.read(nearbyEventsRadiusKmProvider.notifier).setRadiusKm(radiusKm);
    final currentCenter = mapRadiusCenterForChange(
      query: _mapQuery,
      userPoint: _userPoint,
      cameraPoint: await _currentCameraCenter(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _autoFitPending = false;
      _lastViewportFitKey = _manualRadiusViewportFitKey;
      if (currentCenter == null) {
        _mapQuery = MapEventsQuery(radiusKm: radiusKm);
      } else {
        _mapQuery = MapEventsQuery(
          centerLatitude: _roundGeo(currentCenter.latitude),
          centerLongitude: _roundGeo(currentCenter.longitude),
          radiusKm: radiusKm,
        );
      }
    });

    if (currentCenter != null) {
      unawaited(_fitViewportForRadius(currentCenter, radiusKm));
    }
  }

  Future<ym.Point?> _currentCameraCenter() async {
    final controller = _mapController;
    final generation = _mapControllerGeneration;
    if (controller == null) {
      return null;
    }

    try {
      final cameraPosition = await controller.getCameraPosition();
      if (!_isActiveMapController(controller, generation)) {
        return null;
      }
      return cameraPosition.target;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fitViewportForRadius(ym.Point center, double radiusKm) {
    return _moveToRadius(center, radiusKm);
  }

  Future<void> _moveToRadius(ym.Point center, double radiusKm) async {
    final controller = _mapController;
    final generation = _mapControllerGeneration;
    if (controller == null) {
      return;
    }

    try {
      final zoom = mapZoomForRadiusKm(
        radiusKm: radiusKm,
        viewportSize: _mapRadiusViewportSize(),
        latitude: center.latitude,
      );
      if (!_isActiveMapController(controller, generation)) {
        return;
      }
      await controller.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: center,
            zoom: zoom,
            azimuth: 0,
            tilt: 0,
          ),
        ),
        animation: const ym.MapAnimation(
          type: ym.MapAnimationType.smooth,
          duration: 0.35,
        ),
      );
    } catch (_) {
      return;
    }
  }

  Size _mapRadiusViewportSize() {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) {
      return const Size(390, 620);
    }
    return Size(
      size.width,
      (size.height - 220).clamp(240, size.height).toDouble(),
    );
  }

  Future<ym.Point?> _resolvePreferredMapPoint() async {
    final manualLocation = ref.read(manualLocationProvider);
    if (manualLocation != null) {
      return resolvePreferredMapPoint(manualLocation: manualLocation);
    }

    final locationService = ref.read(appLocationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (!mounted) {
      return null;
    }
    return resolvePreferredMapPoint(currentPosition: position);
  }

  Future<void> _moveToUserPreview(
    ym.Point point, {
    bool animated = true,
  }) {
    return _moveToPoint(point, zoom: 13.5, animated: animated);
  }

  Future<void> _moveToEventPoint(
    ym.Point point, {
    required bool keepCurrentZoom,
  }) async {
    double? currentZoom;
    if (keepCurrentZoom) {
      final controller = _mapController;
      final generation = _mapControllerGeneration;
      if (controller != null) {
        try {
          final cameraPosition = await controller.getCameraPosition();
          if (_isActiveMapController(controller, generation)) {
            currentZoom = cameraPosition.zoom;
          }
        } catch (_) {
          currentZoom = null;
        }
      }
    }

    return _moveToPoint(
      point,
      zoom: mapZoomForEventSelection(
        currentZoom: currentZoom,
        keepCurrentZoom: keepCurrentZoom,
      ),
    );
  }

  Future<void> _moveToPoint(
    ym.Point point, {
    double zoom = 14,
    bool animated = true,
  }) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: point,
            zoom: zoom,
            azimuth: 0,
            tilt: 0,
          ),
        ),
        animation: animated
            ? const ym.MapAnimation(
                type: ym.MapAnimationType.smooth,
                duration: 0.35,
              )
            : null,
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _changeZoom(double delta) async {
    final controller = _mapController;
    final generation = _mapControllerGeneration;
    if (controller == null) {
      return;
    }

    try {
      final cameraPosition = await controller.getCameraPosition();
      if (!_isActiveMapController(controller, generation)) {
        return;
      }
      _syncRadiusAfterProgrammaticZoom = true;
      await controller.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: cameraPosition.target,
            zoom: clampMapZoom(cameraPosition.zoom + delta),
            azimuth: cameraPosition.azimuth,
            tilt: cameraPosition.tilt,
          ),
        ),
        animation: const ym.MapAnimation(
          type: ym.MapAnimationType.smooth,
          duration: 0.22,
        ),
      );
    } catch (_) {
      _syncRadiusAfterProgrammaticZoom = false;
      return;
    }
  }

  Future<void> _moveToBounds(
    ym.BoundingBox bounds, {
    bool animated = true,
  }) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.moveCamera(
        ym.CameraUpdate.newGeometry(
          ym.Geometry.fromBoundingBox(bounds),
          focusRect: _mapFocusRect(),
        ),
        animation: animated
            ? const ym.MapAnimation(
                type: ym.MapAnimationType.smooth,
                duration: 0.35,
              )
            : null,
      );
    } catch (_) {
      return;
    }
  }

  ym.ScreenRect? _mapFocusRect() {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) {
      return null;
    }

    return ym.ScreenRect(
      topLeft: const ym.ScreenPoint(x: 0, y: 0),
      bottomRight: ym.ScreenPoint(
        x: size.width,
        y: (size.height - 145).clamp(240, size.height).toDouble(),
      ),
    );
  }

  Future<void> _fitViewportForEvents(
    List<Event> events, {
    bool animated = true,
    required int fitGeneration,
  }) async {
    final eventPoints = events
        .map(_pointForEvent)
        .whereType<ym.Point>()
        .toList(growable: false);
    if (eventPoints.isEmpty) {
      return;
    }

    final userPoint = await _resolveViewportUserPoint();
    if (!mounted || fitGeneration != _viewportFitGeneration) {
      return;
    }

    final bounds = buildMapViewportBounds(
      userPoint: userPoint,
      eventPoints: eventPoints,
    );
    if (bounds == null) {
      return;
    }
    if (fitGeneration != _viewportFitGeneration) {
      return;
    }

    await _moveToBounds(bounds, animated: animated);
  }

  Future<ym.Point?> _resolveViewportUserPoint() async {
    if (_userPoint != null) {
      return _userPoint;
    }
    if (_triedInitialLocation) {
      return null;
    }

    _triedInitialLocation = true;
    final point = await _resolvePreferredMapPoint();
    if (point == null) {
      return null;
    }

    if (mounted) {
      setState(() {
        _userPoint = point;
      });
    }
    return point;
  }

  void _onMapTap(ym.Point point) {
    setState(() {
      _searchPoint = point;
    });
    unawaited(_moveToPoint(point, zoom: 15));
  }

  void _handleEventTap(String eventId) {
    final events = _visibleMapEvents;
    final event = events.where((item) => item.id == eventId).firstOrNull;
    if (event == null) {
      return;
    }
    _selectEvent(
      event,
      events,
      animatePager: true,
      keepCurrentZoom: false,
    );
  }

  Future<void> _handleEventClusterTap(
    List<ym.PlacemarkMapObject> placemarks,
  ) async {
    final target = clusterCenterPoint(placemarks);
    final controller = _mapController;
    final generation = _mapControllerGeneration;
    if (target == null || controller == null) {
      return;
    }

    try {
      final cameraPosition = await controller.getCameraPosition();
      if (!_isActiveMapController(controller, generation)) {
        return;
      }
      await controller.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: target,
            zoom: mapZoomForClusterTap(cameraPosition.zoom),
            azimuth: cameraPosition.azimuth,
            tilt: cameraPosition.tilt,
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

  void _handleDatingProfileTap(String userId) {
    final profiles = datingProfilesWithMapPoints(
      ref.read(datingDiscoverProvider).valueOrNull ??
          const <DatingProfileData>[],
    );
    final profile = profiles.where((item) => item.userId == userId).firstOrNull;
    if (profile == null) {
      return;
    }
    _selectDatingProfile(
      profile,
      profiles,
      animatePager: true,
      keepCurrentZoom: false,
    );
  }

  void _selectEvent(
    Event event,
    List<Event> events, {
    required bool animatePager,
    required bool keepCurrentZoom,
  }) {
    setState(() {
      selected = event.id;
    });

    final point = _pointForEvent(event);
    if (point != null) {
      unawaited(
        _moveToEventPoint(
          point,
          keepCurrentZoom: keepCurrentZoom,
        ),
      );
    }

    if (animatePager) {
      final index = events.indexWhere((item) => item.id == event.id);
      if (index >= 0 && _eventPageController.hasClients) {
        final currentPage =
            _eventPageController.page?.round() ?? _radarCarouselInitialPage;
        unawaited(
          _eventPageController.animateToPage(
            nearestRadarCarouselPage(
              currentPage,
              targetIndex: index,
              eventCount: events.length,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    }
  }

  void _selectDatingProfile(
    DatingProfileData profile,
    List<DatingProfileData> profiles, {
    required bool animatePager,
    required bool keepCurrentZoom,
  }) {
    setState(() {
      selectedDatingUserId = profile.userId;
    });

    final point = _pointForDatingProfile(profile);
    if (point != null) {
      unawaited(
        _moveToEventPoint(
          point,
          keepCurrentZoom: keepCurrentZoom,
        ),
      );
    }

    if (animatePager) {
      final index =
          profiles.indexWhere((item) => item.userId == profile.userId);
      if (index >= 0 && _eventPageController.hasClients) {
        final currentPage =
            _eventPageController.page?.round() ?? _radarCarouselInitialPage;
        unawaited(
          _eventPageController.animateToPage(
            nearestRadarCarouselPage(
              currentPage,
              targetIndex: index,
              eventCount: profiles.length,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    }
  }

  void _syncPagerToSelected(List<Event> events, String selectedId) {
    if (selectedId.isEmpty) {
      return;
    }
    final index = events.indexWhere((item) => item.id == selectedId);
    if (index < 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_eventPageController.hasClients) {
        return;
      }
      final currentPage =
          _eventPageController.page?.round() ?? _radarCarouselInitialPage;
      if (radarCarouselEventIndex(currentPage, events.length) == index) {
        return;
      }
      _eventPageController.jumpToPage(
        nearestRadarCarouselPage(
          currentPage,
          targetIndex: index,
          eventCount: events.length,
        ),
      );
    });
  }

  void _syncPagerToSelectedDatingProfile(
    List<DatingProfileData> profiles,
    String selectedUserId,
  ) {
    if (selectedUserId.isEmpty) {
      return;
    }
    final index = profiles.indexWhere((item) => item.userId == selectedUserId);
    if (index < 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_eventPageController.hasClients) {
        return;
      }
      final currentPage =
          _eventPageController.page?.round() ?? _radarCarouselInitialPage;
      if (radarCarouselEventIndex(currentPage, profiles.length) == index) {
        return;
      }
      _eventPageController.jumpToPage(
        nearestRadarCarouselPage(
          currentPage,
          targetIndex: index,
          eventCount: profiles.length,
        ),
      );
    });
  }

  void _scheduleViewportFit(List<Event> events) {
    final fitKey = buildMapViewportFitKey(events, filter);
    if (!shouldScheduleMapViewportFit(
      supportsNativeMap: _supportsNativeMap,
      hasMapController: _mapController != null,
      hasInitialEvent: (widget.initialEventId ?? '').isNotEmpty,
      autoFitPending: _autoFitPending,
      fitKey: fitKey,
      lastFitKey: _lastViewportFitKey,
    )) {
      return;
    }
    _autoFitPending = false;
    _lastViewportFitKey = fitKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null) {
        return;
      }
      final fitGeneration = ++_viewportFitGeneration;
      unawaited(
        _fitViewportForEvents(
          events,
          fitGeneration: fitGeneration,
        ),
      );
    });
  }

  void _scheduleDatingViewportFit(List<DatingProfileData> profiles) {
    final fitKey = buildDatingProfilesViewportFitKey(profiles);
    if (!shouldScheduleMapViewportFit(
      supportsNativeMap: _supportsNativeMap,
      hasMapController: _mapController != null,
      hasInitialEvent: (widget.initialEventId ?? '').isNotEmpty,
      autoFitPending: _autoFitPending,
      fitKey: fitKey,
      lastFitKey: _lastViewportFitKey,
    )) {
      return;
    }
    _autoFitPending = false;
    _lastViewportFitKey = fitKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null) {
        return;
      }
      final fitGeneration = ++_viewportFitGeneration;
      unawaited(
        _fitViewportForPoints(
          datingProfilePoints(profiles),
          fitGeneration: fitGeneration,
        ),
      );
    });
  }

  Future<void> _fitViewportForPoints(
    List<ym.Point> points, {
    bool animated = true,
    required int fitGeneration,
  }) async {
    if (points.isEmpty) {
      return;
    }

    final userPoint = await _resolveViewportUserPoint();
    if (!mounted || fitGeneration != _viewportFitGeneration) {
      return;
    }

    final bounds = buildMapViewportBounds(
      userPoint: userPoint,
      eventPoints: points,
    );
    if (bounds == null) {
      return;
    }
    if (fitGeneration != _viewportFitGeneration) {
      return;
    }

    await _moveToBounds(bounds, animated: animated);
  }

  void _selectFilter(
    String nextFilter,
    List<Event> events,
    List<DatingProfileData> datingProfiles,
  ) {
    if (nextFilter == 'dating') {
      setState(() {
        filter = nextFilter;
        if (datingProfiles.isNotEmpty &&
            !datingProfiles
                .any((item) => item.userId == selectedDatingUserId)) {
          selectedDatingUserId = datingProfiles.first.userId;
        }
      });

      if (datingProfiles.isNotEmpty) {
        final activeProfile = datingProfiles
                .where((item) => item.userId == selectedDatingUserId)
                .cast<DatingProfileData?>()
                .firstOrNull ??
            datingProfiles.first;
        final index = datingProfiles.indexWhere(
          (item) => item.userId == activeProfile.userId,
        );
        if (index >= 0 && _eventPageController.hasClients) {
          final currentPage =
              _eventPageController.page?.round() ?? _radarCarouselInitialPage;
          unawaited(
            _eventPageController.animateToPage(
              nearestRadarCarouselPage(
                currentPage,
                targetIndex: index,
                eventCount: datingProfiles.length,
              ),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
          );
        }
        final fitGeneration = ++_viewportFitGeneration;
        unawaited(
          _fitViewportForPoints(
            datingProfilePoints(datingProfiles),
            fitGeneration: fitGeneration,
          ),
        );
      }
      return;
    }

    final filtered = _filteredEvents(events, nextFilter);
    setState(() {
      filter = nextFilter;
      if (filtered.isEmpty) {
        return;
      }
      if (!filtered.any((item) => item.id == selected)) {
        selected = filtered.first.id;
      }
    });

    if (filtered.isNotEmpty) {
      final activeEvent = filtered
              .where((item) => item.id == selected)
              .cast<Event?>()
              .firstOrNull ??
          filtered.first;
      final index = filtered.indexWhere((item) => item.id == activeEvent.id);
      if (index >= 0 && _eventPageController.hasClients) {
        final currentPage =
            _eventPageController.page?.round() ?? _radarCarouselInitialPage;
        unawaited(
          _eventPageController.animateToPage(
            nearestRadarCarouselPage(
              currentPage,
              targetIndex: index,
              eventCount: filtered.length,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
      final fitGeneration = ++_viewportFitGeneration;
      unawaited(
        _fitViewportForEvents(
          filtered,
          fitGeneration: fitGeneration,
        ),
      );
    }
  }

  ym.Point? _pointForEvent(Event event) {
    return _pointForEventModel(event);
  }

  ym.Point? _pointForDatingProfile(DatingProfileData profile) {
    return _pointForDatingProfileModel(profile);
  }

  List<Event> _filteredEvents(List<Event> events, String currentFilter) {
    if (currentFilter == 'all') {
      return events;
    }

    return events
        .where((event) => radarCategoryForEvent(event) == currentFilter)
        .toList(growable: false);
  }
}

class _RadarMapVisualOverlay extends StatelessWidget {
  const _RadarMapVisualOverlay({
    required this.showUserPulse,
  });

  final bool showUserPulse;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF6E2CC).withValues(alpha: 0.34),
                  BbV5Colors.paper.withValues(alpha: 0.28),
                  const Color(0xFFE8D6BE).withValues(alpha: 0.34),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RadarTopographyPainter(),
          ),
        ),
        Positioned(
          right: -64,
          top: 120,
          width: 260,
          height: 230,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  BbV5Colors.brandSoft.withValues(alpha: 0.26),
                  BbV5Colors.brandSoft.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -72,
          top: 240,
          width: 230,
          height: 190,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  BbV5Colors.terraSoft.withValues(alpha: 0.26),
                  BbV5Colors.terraSoft.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        if (showUserPulse)
          const Align(
            alignment: Alignment(0, -0.10),
            child: _RadarUserPulse(),
          ),
      ],
    );
  }
}

class _RadarTopographyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = BbV5Colors.ink.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final softLinePaint = Paint()
      ..color = BbV5Colors.ink.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final upper = Path()
      ..moveTo(0, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.22,
        size.width,
        size.height * 0.34,
      );
    final middle = Path()
      ..moveTo(0, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.36,
        size.width,
        size.height * 0.48,
      );
    final lower = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.58,
        size.width,
        size.height * 0.74,
      );
    final leftVertical = Path()
      ..moveTo(size.width * 0.34, 0)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.50,
        size.width * 0.27,
        size.height,
      );
    final rightVertical = Path()
      ..moveTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.82, size.height);

    canvas.drawPath(upper, linePaint);
    canvas.drawPath(middle, linePaint);
    canvas.drawPath(lower, softLinePaint);
    canvas.drawPath(leftVertical, softLinePaint);
    canvas.drawPath(rightVertical, softLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadarUserPulse extends StatelessWidget {
  const _RadarUserPulse();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BbV5Colors.ink.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: BbV5Colors.paperHi,
              boxShadow: BbV5Shadows.pill,
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: BbV5Colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarTopControls extends StatelessWidget {
  const _RadarTopControls({
    required this.events,
    required this.datingProfileCount,
    required this.filter,
    required this.radiusKm,
    required this.onBack,
    required this.onSelectFilter,
    required this.onRadiusChanged,
  });

  final List<Event> events;
  final int datingProfileCount;
  final String filter;
  final double radiusKm;
  final VoidCallback onBack;
  final ValueChanged<String> onSelectFilter;
  final ValueChanged<double> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final categoryCounts = buildRadarCategoryCounts(
      events,
      datingProfileCount: datingProfileCount,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  _MapTopButton(
                    icon: LucideIcons.arrow_left,
                    onTap: onBack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => showV5SearchModal(context),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: BbV5Colors.paperHi.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(BbV5Radii.pill),
                          border: Border.all(color: BbV5Colors.hair),
                          boxShadow: BbV5Shadows.pill,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.search,
                              size: 16,
                              color: BbV5Colors.inkMute,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Бар, маршрут, человек…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta.copyWith(
                                  fontSize: 13,
                                  color: BbV5Colors.inkMute,
                                ),
                              ),
                            ),
                            const Icon(
                              LucideIcons.sun,
                              size: 13,
                              color: BbV5Colors.inkMute,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+14°',
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'Sora',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MapTopButton(
                    icon: LucideIcons.sliders_horizontal,
                    onTap: () => _showRadarRadiusSheet(
                      context,
                      radiusKm,
                      onRadiusChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 39,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _radarFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = _radarFilters[index];
                    final count = categoryCounts[item.key] ?? 0;
                    return _RadarFilterChip(
                      label: '${item.title} · $count',
                      active: filter == item.key,
                      onTap: () => onSelectFilter(item.key),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showRadarRadiusSheet(
  BuildContext context,
  double currentRadiusKm,
  ValueChanged<double> onChanged,
) {
  var radiusKm = currentRadiusKm;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8014100C),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: Material(
                  color: BbV5Colors.paper,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 48,
                              height: 4,
                              decoration: BoxDecoration(
                                color: BbV5Colors.hair,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Радиус радара',
                            style: bbV5DisplayStyle(
                              fontSize: 20,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          BbV5Kicker('РАДИУС · ${radiusKm.round()} КМ'),
                          Slider(
                            min: 1,
                            max: nearbyEventsMaxRadiusKm,
                            divisions: nearbyEventsMaxRadiusKm.round() - 1,
                            value: radiusKm,
                            activeColor: BbV5Colors.accent,
                            inactiveColor: BbV5Colors.hair,
                            onChanged: (value) {
                              setSheetState(() {
                                radiusKm = value;
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          BbV5PillButton(
                            label: 'Применить',
                            dark: true,
                            height: 52,
                            expanded: true,
                            onPressed: () {
                              onChanged(radiusKm);
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _RadarFilterChip extends StatelessWidget {
  const _RadarFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? BbV5Colors.ink : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.ink : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
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
  _RadarFilterDefinition(key: 'all', title: 'Все'),
  _RadarFilterDefinition(key: 'bars', title: 'Бары'),
  _RadarFilterDefinition(key: 'routes', title: 'Маршруты'),
  _RadarFilterDefinition(key: 'dating', title: 'Дейтинг'),
  _RadarFilterDefinition(key: 'affiche', title: 'Афиша'),
];

@visibleForTesting
Map<String, int> buildRadarCategoryCounts(
  List<Event> events, {
  int datingProfileCount = 0,
}) {
  final counts = <String, int>{
    for (final filter in _radarFilters) filter.key: 0,
  };
  counts['all'] = events.length + datingProfileCount;
  for (final event in events) {
    final category = radarCategoryForEvent(event);
    if (category == 'dating') {
      continue;
    }
    counts[category] = (counts[category] ?? 0) + 1;
  }
  counts['dating'] = datingProfileCount;
  return counts;
}

@visibleForTesting
String radarCategoryForEvent(Event event) {
  if (event.isDate) {
    return 'dating';
  }
  if ((event.routeId ?? '').trim().isNotEmpty) {
    return 'routes';
  }
  if (event.ticketSourceKind != null ||
      (event.ticketUrl ?? '').trim().isNotEmpty) {
    return 'affiche';
  }
  return 'bars';
}

@visibleForTesting
RadarMapPinKind radarPinKindForEvent(Event event) {
  switch (radarCategoryForEvent(event)) {
    case 'routes':
      return RadarMapPinKind.routes;
    case 'affiche':
      return RadarMapPinKind.affiche;
    case 'dating':
      return RadarMapPinKind.dating;
    case 'bars':
    default:
      return RadarMapPinKind.bars;
  }
}

@visibleForTesting
ym.PlacemarkIconStyle radarPinIconStyle({
  required RadarMapPinKind kind,
  required bool selected,
}) {
  final selectedAsset = _radarSelectedPinAssetByKind[kind];
  final asset = selected && selectedAsset != null
      ? selectedAsset
      : _radarPinAssetByKind[kind]!;
  return ym.PlacemarkIconStyle(
    image: ym.BitmapDescriptor.fromAssetImage(asset),
    scale: selected ? 2.0 : 1.8,
    anchor: kind == RadarMapPinKind.user
        ? const Offset(0.5, 0.5)
        : const Offset(0.5, 0.82),
  );
}

@visibleForTesting
ym.BoundingBox? buildMapViewportBounds({
  required ym.Point? userPoint,
  required List<ym.Point> eventPoints,
}) {
  final points = [
    if (userPoint != null) userPoint,
    ...eventPoints,
  ];
  if (points.isEmpty) {
    return null;
  }

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

  final latitudeSpan = maxLatitude - minLatitude;
  final longitudeSpan = maxLongitude - minLongitude;
  final latitudePadding = (latitudeSpan * 0.18).clamp(0.006, 0.12).toDouble();
  final longitudePadding = (longitudeSpan * 0.18).clamp(0.006, 0.12).toDouble();

  return ym.BoundingBox(
    southWest: ym.Point(
      latitude: minLatitude - latitudePadding,
      longitude: minLongitude - longitudePadding,
    ),
    northEast: ym.Point(
      latitude: maxLatitude + latitudePadding,
      longitude: maxLongitude + longitudePadding,
    ),
  );
}

@visibleForTesting
ym.BoundingBox buildMapRadiusBounds({
  required ym.Point center,
  required double radiusKm,
}) {
  const kilometersPerLatitudeDegree = 111.32;
  final paddedRadiusKm = radiusKm.clamp(0.5, nearbyEventsMaxRadiusKm) * 1.12;
  final latitudeDelta = paddedRadiusKm / kilometersPerLatitudeDegree;
  final latitudeRadians = center.latitude * 0.017453292519943295;
  final longitudeScale =
      math.cos(latitudeRadians).abs().clamp(0.01, 1).toDouble();
  final longitudeDelta =
      paddedRadiusKm / (kilometersPerLatitudeDegree * longitudeScale);

  return ym.BoundingBox(
    southWest: ym.Point(
      latitude: (center.latitude - latitudeDelta).clamp(-90, 90).toDouble(),
      longitude:
          (center.longitude - longitudeDelta).clamp(-180, 180).toDouble(),
    ),
    northEast: ym.Point(
      latitude: (center.latitude + latitudeDelta).clamp(-90, 90).toDouble(),
      longitude:
          (center.longitude + longitudeDelta).clamp(-180, 180).toDouble(),
    ),
  );
}

@visibleForTesting
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

@visibleForTesting
ym.Point? mapRadiusCenterForChange({
  required MapEventsQuery query,
  required ym.Point? userPoint,
  required ym.Point? cameraPoint,
}) {
  if (cameraPoint != null) {
    return cameraPoint;
  }

  if (query.centerLatitude != null && query.centerLongitude != null) {
    return ym.Point(
      latitude: query.centerLatitude!,
      longitude: query.centerLongitude!,
    );
  }

  return userPoint;
}

@visibleForTesting
bool shouldScheduleMapViewportFit({
  required bool supportsNativeMap,
  required bool hasMapController,
  required bool hasInitialEvent,
  required bool autoFitPending,
  required String fitKey,
  required String lastFitKey,
}) {
  return supportsNativeMap &&
      hasMapController &&
      !hasInitialEvent &&
      fitKey.isNotEmpty &&
      fitKey != lastFitKey &&
      (autoFitPending || lastFitKey.isEmpty);
}

@visibleForTesting
bool shouldRefreshMapViewportQuery({
  required ym.CameraUpdateReason reason,
  required bool finished,
  bool allowApplication = false,
}) {
  return finished &&
      (reason == ym.CameraUpdateReason.gestures ||
          (allowApplication && reason == ym.CameraUpdateReason.application));
}

@visibleForTesting
List<Event> visibleMapEventsForRadar({
  required AsyncValue<List<Event>> eventsAsync,
  required List<Event> previousEvents,
}) {
  if (eventsAsync.hasValue) {
    final events = eventsAsync.value ?? const <Event>[];
    if (events.isEmpty && previousEvents.isNotEmpty) {
      return previousEvents;
    }
    return events;
  }

  return previousEvents;
}

@visibleForTesting
double nearbyRadiusKmFromMapQuery({
  required double currentRadiusKm,
  required MapEventsQuery query,
}) {
  final radiusKm = query.radiusKm;
  if (radiusKm == null) {
    return currentRadiusKm;
  }

  return clampNearbyEventsRadiusKm(radiusKm);
}

@visibleForTesting
double clampMapZoom(double zoom) {
  return zoom.clamp(_minMapZoom, _maxMapZoom).toDouble();
}

@visibleForTesting
double mapZoomForEventSelection({
  required double? currentZoom,
  required bool keepCurrentZoom,
}) {
  if (keepCurrentZoom && currentZoom != null) {
    return clampMapZoom(currentZoom);
  }

  return 15;
}

@visibleForTesting
double mapZoomForClusterTap(double currentZoom) {
  return clampMapZoom(
    math.max(currentZoom + 2, _radarClusterMinZoom + 1),
  );
}

@visibleForTesting
ym.Point? clusterCenterPoint(List<ym.PlacemarkMapObject> placemarks) {
  if (placemarks.isEmpty) {
    return null;
  }

  var latitude = 0.0;
  var longitude = 0.0;
  for (final placemark in placemarks) {
    latitude += placemark.point.latitude;
    longitude += placemark.point.longitude;
  }

  return ym.Point(
    latitude: latitude / placemarks.length,
    longitude: longitude / placemarks.length,
  );
}

@visibleForTesting
int radarCarouselEventIndex(int pageIndex, int eventCount) {
  if (eventCount <= 0) {
    return 0;
  }
  return pageIndex % eventCount;
}

@visibleForTesting
int nearestRadarCarouselPage(
  int currentPage, {
  required int targetIndex,
  required int eventCount,
}) {
  if (eventCount <= 1) {
    return 0;
  }

  final currentEventIndex = radarCarouselEventIndex(currentPage, eventCount);
  final forward = (targetIndex - currentEventIndex) % eventCount;
  final backward = forward - eventCount;
  final delta = forward.abs() <= backward.abs() ? forward : backward;
  return currentPage + delta;
}

@visibleForTesting
String buildMapViewportFitKey(List<Event> events, String filter) {
  final parts = events
      .where((event) => event.latitude != null && event.longitude != null)
      .map(
        (event) =>
            '${event.id}:${event.latitude!.toStringAsFixed(5)},${event.longitude!.toStringAsFixed(5)}',
      )
      .toList(growable: false);
  if (parts.isEmpty) {
    return '';
  }

  return '$filter|${parts.join('|')}';
}

@visibleForTesting
String buildDatingProfilesViewportFitKey(List<DatingProfileData> profiles) {
  final parts = profiles
      .where((profile) => profile.latitude != null && profile.longitude != null)
      .map(
        (profile) =>
            '${profile.userId}:${profile.latitude!.toStringAsFixed(5)},${profile.longitude!.toStringAsFixed(5)}',
      )
      .toList(growable: false);
  if (parts.isEmpty) {
    return '';
  }

  return 'dating|${parts.join('|')}';
}

@visibleForTesting
class MapObjectCache {
  String _key = '';
  List<ym.MapObject> _objects = const [];

  List<ym.MapObject> objectsFor({
    required List<Event> events,
    required String selectedId,
    List<DatingProfileData> datingProfiles = const [],
    String selectedDatingUserId = '',
    Set<String> promotedIds = const {},
    required List<EveningSessionSummary> liveEvenings,
    required ym.Point? userPoint,
    required ym.Point? searchPoint,
    required void Function(String eventId) onEventTap,
    void Function(List<ym.PlacemarkMapObject> placemarks)? onEventClusterTap,
    void Function(String userId)? onDatingProfileTap,
    required void Function(String sessionId) onSessionTap,
  }) {
    final nextKey = buildMapObjectsCacheKey(
      events: events,
      selectedId: selectedId,
      datingProfiles: datingProfiles,
      selectedDatingUserId: selectedDatingUserId,
      promotedIds: promotedIds,
      liveEvenings: liveEvenings,
      userPoint: userPoint,
      searchPoint: searchPoint,
    );
    if (nextKey == _key) {
      return _objects;
    }

    final eventPlacemarks = buildEventPlacemarks(
      events: events,
      selectedId: selectedId,
      promotedIds: promotedIds,
      onEventTap: onEventTap,
    );
    final objects = <ym.MapObject>[
      if (eventPlacemarks.length > _radarClusterPointThreshold)
        buildEventClusterCollection(
          placemarks: eventPlacemarks,
          onClusterTap: onEventClusterTap ?? (_) {},
        )
      else
        ...eventPlacemarks,
      ...buildDatingProfilePlacemarks(
        profiles: datingProfiles,
        selectedUserId: selectedDatingUserId,
        onProfileTap: onDatingProfileTap ?? (_) {},
      ),
      ...buildLiveEveningPlacemarks(
        sessions: liveEvenings,
        onSessionTap: onSessionTap,
      ),
      if (userPoint != null) buildUserLocationPlacemark(userPoint),
      if (searchPoint != null) buildSearchPointPlacemark(searchPoint),
    ];

    _key = nextKey;
    _objects = List<ym.MapObject>.unmodifiable(objects);
    return _objects;
  }
}

@visibleForTesting
String buildMapObjectsCacheKey({
  required List<Event> events,
  required String selectedId,
  List<DatingProfileData> datingProfiles = const [],
  String selectedDatingUserId = '',
  Set<String> promotedIds = const {},
  required List<EveningSessionSummary> liveEvenings,
  required ym.Point? userPoint,
  required ym.Point? searchPoint,
}) {
  final parts = <String>[
    'selected:$selectedId',
    'selectedDating:$selectedDatingUserId',
    'user:${_pointCacheKey(userPoint)}',
    'search:${_pointCacheKey(searchPoint)}',
    'cluster:${events.length > _radarClusterPointThreshold}',
    for (final event in events)
      if (event.latitude != null && event.longitude != null)
        [
          'event',
          event.id,
          _roundGeo(event.latitude!).toStringAsFixed(5),
          _roundGeo(event.longitude!).toStringAsFixed(5),
          event.emoji,
          promotedIds.contains(event.id) ? 'promoted' : 'regular',
        ].join(':'),
    for (final profile in datingProfiles)
      if (profile.latitude != null && profile.longitude != null)
        [
          'dating',
          profile.userId,
          _roundGeo(profile.latitude!).toStringAsFixed(5),
          _roundGeo(profile.longitude!).toStringAsFixed(5),
          profile.photoEmoji,
        ].join(':'),
    for (final session in liveEvenings)
      if (session.lat != null && session.lng != null)
        [
          'session',
          session.id,
          _roundGeo(session.lat!).toStringAsFixed(5),
          _roundGeo(session.lng!).toStringAsFixed(5),
          session.emoji,
        ].join(':'),
  ];

  return parts.join('|');
}

@visibleForTesting
List<ym.PlacemarkMapObject> buildEventPlacemarks({
  required List<Event> events,
  required String selectedId,
  Set<String> promotedIds = const {},
  required void Function(String eventId) onEventTap,
}) {
  return [
    for (final event in events)
      if (event.latitude != null && event.longitude != null)
        _buildEventPlacemark(
          event: event,
          selected: event.id == selectedId,
          promoted: promotedIds.contains(event.id),
          onEventTap: onEventTap,
        ),
  ];
}

ym.PlacemarkMapObject _buildEventPlacemark({
  required Event event,
  required bool selected,
  required bool promoted,
  required void Function(String eventId) onEventTap,
}) {
  final pinKind =
      promoted ? RadarMapPinKind.promoted : radarPinKindForEvent(event);
  return ym.PlacemarkMapObject(
    mapId: ym.MapObjectId('event_${event.id}'),
    point: ym.Point(
      latitude: event.latitude!,
      longitude: event.longitude!,
    ),
    zIndex: selected ? 2 : 1,
    consumeTapEvents: true,
    opacity: 1,
    icon: ym.PlacemarkIcon.single(
      radarPinIconStyle(
        kind: pinKind,
        selected: selected,
      ),
    ),
    text: promoted
        ? ym.PlacemarkText(
            text: '🔥',
            style: ym.PlacemarkTextStyle(
              size: selected ? 16 : 15,
              placement: ym.TextStylePlacement.center,
              offsetFromIcon: false,
            ),
          )
        : null,
    onTap: (_, __) => onEventTap(event.id),
  );
}

@visibleForTesting
ym.ClusterizedPlacemarkCollection buildEventClusterCollection({
  required List<ym.PlacemarkMapObject> placemarks,
  required void Function(List<ym.PlacemarkMapObject> placemarks) onClusterTap,
}) {
  return ym.ClusterizedPlacemarkCollection(
    mapId: const ym.MapObjectId('event_clusters'),
    placemarks: placemarks,
    radius: _radarClusterRadius,
    minZoom: _radarClusterMinZoom,
    zIndex: 1,
    consumeTapEvents: true,
    onClusterAdded: (collection, cluster) async {
      return cluster.copyWith(
        appearance: cluster.appearance.copyWith(
          opacity: 1,
          icon: ym.PlacemarkIcon.single(
            radarPinIconStyle(
              kind: RadarMapPinKind.cluster,
              selected: false,
            ),
          ),
          text: ym.PlacemarkText(
            text: cluster.size.toString(),
            style: const ym.PlacemarkTextStyle(
              size: 13,
              color: Color(0xFF2A2A2A),
              outlineColor: Colors.white,
              placement: ym.TextStylePlacement.center,
              offsetFromIcon: false,
            ),
          ),
        ),
      );
    },
    onClusterTap: (_, cluster) => onClusterTap(cluster.placemarks),
  );
}

@visibleForTesting
List<DatingProfileData> datingProfilesWithMapPoints(
  List<DatingProfileData> profiles,
) {
  return profiles
      .where((profile) => _pointForDatingProfileModel(profile) != null)
      .toList(growable: false);
}

@visibleForTesting
List<ym.Point> datingProfilePoints(List<DatingProfileData> profiles) {
  return profiles
      .map(_pointForDatingProfileModel)
      .whereType<ym.Point>()
      .toList(growable: false);
}

@visibleForTesting
List<ym.PlacemarkMapObject> buildDatingProfilePlacemarks({
  required List<DatingProfileData> profiles,
  required String selectedUserId,
  required void Function(String userId) onProfileTap,
}) {
  return [
    for (final profile in profiles)
      if (profile.latitude != null && profile.longitude != null)
        _buildDatingProfilePlacemark(
          profile: profile,
          selected: profile.userId == selectedUserId,
          onProfileTap: onProfileTap,
        ),
  ];
}

ym.PlacemarkMapObject _buildDatingProfilePlacemark({
  required DatingProfileData profile,
  required bool selected,
  required void Function(String userId) onProfileTap,
}) {
  return ym.PlacemarkMapObject(
    mapId: ym.MapObjectId('dating_${profile.userId}'),
    point: ym.Point(
      latitude: profile.latitude!,
      longitude: profile.longitude!,
    ),
    zIndex: selected ? 6 : 5,
    consumeTapEvents: true,
    opacity: 1,
    icon: ym.PlacemarkIcon.single(
      radarPinIconStyle(
        kind: RadarMapPinKind.dating,
        selected: selected,
      ),
    ),
    onTap: (_, __) => onProfileTap(profile.userId),
  );
}

@visibleForTesting
List<ym.PlacemarkMapObject> buildLiveEveningPlacemarks({
  required List<EveningSessionSummary> sessions,
  required void Function(String sessionId) onSessionTap,
}) {
  return [
    for (final session in sessions)
      if (session.lat != null && session.lng != null)
        ym.PlacemarkMapObject(
          mapId: ym.MapObjectId('evening_session_${session.id}'),
          point: ym.Point(
            latitude: session.lat!,
            longitude: session.lng!,
          ),
          zIndex: 5,
          consumeTapEvents: true,
          opacity: 1,
          icon: ym.PlacemarkIcon.single(
            radarPinIconStyle(
              kind: RadarMapPinKind.live,
              selected: false,
            ),
          ),
          onTap: (_, __) => onSessionTap(session.id),
        ),
  ];
}

@visibleForTesting
ym.PlacemarkMapObject buildUserLocationPlacemark(ym.Point point) {
  return ym.PlacemarkMapObject(
    mapId: const ym.MapObjectId('user_location'),
    point: point,
    zIndex: 4,
    consumeTapEvents: false,
    opacity: 1,
    icon: ym.PlacemarkIcon.single(
      radarPinIconStyle(
        kind: RadarMapPinKind.user,
        selected: false,
      ),
    ),
  );
}

@visibleForTesting
ym.PlacemarkMapObject buildSearchPointPlacemark(ym.Point point) {
  return ym.PlacemarkMapObject(
    mapId: const ym.MapObjectId('search_point'),
    point: point,
    zIndex: 3,
    text: const ym.PlacemarkText(
      text: '📍',
      style: ym.PlacemarkTextStyle(
        size: 18,
        placement: ym.TextStylePlacement.center,
        offsetFromIcon: false,
      ),
    ),
  );
}

ym.Point? _pointForEventModel(Event event) {
  final latitude = event.latitude;
  final longitude = event.longitude;
  if (latitude == null || longitude == null) {
    return null;
  }

  return ym.Point(
    latitude: latitude,
    longitude: longitude,
  );
}

ym.Point? _pointForDatingProfileModel(DatingProfileData profile) {
  final latitude = profile.latitude;
  final longitude = profile.longitude;
  if (latitude == null || longitude == null) {
    return null;
  }
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180 ||
      (latitude == 0 && longitude == 0)) {
    return null;
  }

  return ym.Point(
    latitude: latitude,
    longitude: longitude,
  );
}

@visibleForTesting
MapEventsQuery buildMapEventsQuery({
  required ym.BoundingBox bounds,
  required ym.Point center,
}) {
  final radiusKm = [
    _distanceKm(center, bounds.southWest),
    _distanceKm(center, bounds.northEast),
  ].reduce((value, item) => value > item ? value : item);

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

@visibleForTesting
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
    southWest: ym.Point(
      latitude: minLatitude,
      longitude: minLongitude,
    ),
    northEast: ym.Point(
      latitude: maxLatitude,
      longitude: maxLongitude,
    ),
  );
}

@visibleForTesting
MapEventsQuery buildInitialMapEventsQuery(ym.Point point) {
  return MapEventsQuery(
    centerLatitude: _roundGeo(point.latitude),
    centerLongitude: _roundGeo(point.longitude),
    radiusKm: nearbyEventsDefaultRadiusKm,
  );
}

@visibleForTesting
ym.Point? resolvePreferredMapPoint({
  ManualLocation? manualLocation,
  Position? currentPosition,
}) {
  if (manualLocation != null && isSupportedManualLocation(manualLocation)) {
    return ym.Point(
      latitude: manualLocation.latitude,
      longitude: manualLocation.longitude,
    );
  }

  if (currentPosition == null) {
    return null;
  }

  return ym.Point(
    latitude: currentPosition.latitude,
    longitude: currentPosition.longitude,
  );
}

String _pointCacheKey(ym.Point? point) {
  if (point == null) {
    return '-';
  }

  return '${_roundGeo(point.latitude).toStringAsFixed(5)},'
      '${_roundGeo(point.longitude).toStringAsFixed(5)}';
}

double _roundGeo(double value) => double.parse(value.toStringAsFixed(5));

double _roundViewportGeo(double value) =>
    double.parse(value.toStringAsFixed(3));

double _roundDistanceKm(double value) => double.parse(value.toStringAsFixed(1));

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

class _RadarBottomSheet extends StatelessWidget {
  const _RadarBottomSheet({
    required this.events,
    required this.isExpanded,
    required this.pageController,
    required this.onPageChanged,
    required this.onExpandedChanged,
    required this.onEventTap,
  });

  final List<Event> events;
  final bool isExpanded;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<Event> onEventTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('radar-bottom-sheet-drag-area'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 20) {
          onExpandedChanged(false);
        } else if (velocity < -20) {
          onExpandedChanged(true);
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, isExpanded ? 16 : 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BbV5Colors.paperHi, BbV5Colors.paper],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: BbV5Colors.hair),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E1F241D),
              blurRadius: 40,
              spreadRadius: -12,
              offset: Offset(0, -16),
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 34,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: BbV5Colors.hair,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 136,
                    child: PageView.builder(
                      controller: pageController,
                      padEnds: true,
                      onPageChanged: onPageChanged,
                      itemCount: events.length <= 2 ? events.length : null,
                      itemBuilder: (context, index) {
                        final event = events[radarCarouselEventIndex(
                          index,
                          events.length,
                        )];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _RadarEventCard(
                            event: event,
                            onTap: () => onEventTap(event),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarDatingBottomSheet extends StatelessWidget {
  const _RadarDatingBottomSheet({
    required this.profiles,
    required this.isExpanded,
    required this.pageController,
    required this.onPageChanged,
    required this.onExpandedChanged,
    required this.onProfileTap,
  });

  final List<DatingProfileData> profiles;
  final bool isExpanded;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<DatingProfileData> onProfileTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('radar-dating-bottom-sheet-drag-area'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 20) {
          onExpandedChanged(false);
        } else if (velocity < -20) {
          onExpandedChanged(true);
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, isExpanded ? 16 : 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BbV5Colors.paperHi, BbV5Colors.paper],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: BbV5Colors.hair),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E1F241D),
              blurRadius: 40,
              spreadRadius: -12,
              offset: Offset(0, -16),
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 34,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: BbV5Colors.hair,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 136,
                    child: PageView.builder(
                      controller: pageController,
                      padEnds: true,
                      onPageChanged: onPageChanged,
                      itemCount: profiles.length <= 2 ? profiles.length : null,
                      itemBuilder: (context, index) {
                        final profile = profiles[radarCarouselEventIndex(
                          index,
                          profiles.length,
                        )];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _RadarDatingProfileCard(
                            profile: profile,
                            onTap: () => onProfileTap(profile),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarDatingProfileCard extends StatelessWidget {
  const _RadarDatingProfileCard({
    required this.profile,
    required this.onTap,
  });

  final DatingProfileData profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title =
        profile.age == null ? profile.name : '${profile.name}, ${profile.age}';
    final area = (profile.area?.trim().isNotEmpty ?? false)
        ? profile.area!.trim()
        : (profile.city?.trim().isNotEmpty ?? false)
            ? profile.city!.trim()
            : 'Рядом';
    final distance = profile.distance.trim();
    final details = distance.isEmpty ? area : '$area · $distance';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: Text(
                  profile.photoEmoji,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.itemTitle.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: BbV5Colors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: BbV5Colors.inkMute,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    profile.online ? LucideIcons.radio : LucideIcons.heart,
                    size: 10,
                    color: BbV5Colors.inkSoft,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profile.online ? 'сейчас рядом' : 'профиль дейтинга',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BbV5Colors.inkSoft,
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.arrow_up_right,
                    size: 12,
                    color: BbV5Colors.inkMute,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarEventCard extends StatelessWidget {
  const _RadarEventCard({
    required this.event,
    required this.onTap,
  });

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final toneColor = switch (event.tone) {
      EventTone.evening => BbV5Colors.terra,
      EventTone.sage => BbV5Colors.brand,
      EventTone.warm => BbV5Colors.gold,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: Text(
                  event.emoji,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.itemTitle.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: BbV5Colors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${event.vibe} · ${event.distance}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: BbV5Colors.inkMute,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    LucideIcons.users,
                    size: 10,
                    color: BbV5Colors.inkSoft,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${event.going} идут',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BbV5Colors.inkSoft,
                      ),
                    ),
                  ),
                  Icon(
                    LucideIcons.arrow_up_right,
                    size: 16,
                    color: toneColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapTopButton extends StatelessWidget {
  const _MapTopButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: BbV5Colors.paperHi.withValues(alpha: 0.92),
      shadowColor: const Color(0x4D1F241D),
      elevation: 0,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onTap == null ? BbV5Colors.inkMute : BbV5Colors.ink,
            size: 17,
          ),
        ),
      ),
    );
    final message = tooltip;
    if (message == null) {
      return button;
    }
    return Tooltip(
      message: message,
      child: Semantics(
        button: true,
        label: message,
        child: button,
      ),
    );
  }
}

class _LiveEveningMapPin extends StatelessWidget {
  const _LiveEveningMapPin({
    required this.session,
    required this.index,
  });

  final EveningSessionSummary session;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final positions = const [
      Offset(0.32, 0.24),
      Offset(0.58, 0.31),
      Offset(0.42, 0.48),
      Offset(0.70, 0.42),
    ];
    final position = positions[index % positions.length];
    final size = MediaQuery.sizeOf(context);

    return Positioned(
      key: ValueKey('map-live-evening-pin-${session.id}'),
      left: size.width * position.dx - 26,
      top: size.height * position.dy - 26,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushRoute(
            AppRoute.eveningPreview,
            pathParameters: {'sessionId': session.id},
          ),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 64,
            height: 72,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  child: _MapLivePulse(
                    key: ValueKey('map-live-evening-pulse-${session.id}'),
                  ),
                ),
                Positioned(
                  top: 4,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                      border: Border.all(color: colors.background, width: 4),
                      boxShadow: AppShadows.card,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      session.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: AppRadii.pillBorder,
                    ),
                    child: Text(
                      'Live',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.primaryForeground,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLivePulse extends StatefulWidget {
  const _MapLivePulse({super.key});

  @override
  State<_MapLivePulse> createState() => _MapLivePulseState();
}

class _MapLivePulseState extends State<_MapLivePulse> {
  Timer? _pulseTimer;
  bool _wide = true;

  @override
  void initState() {
    super.initState();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _wide = !_wide;
      });
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      width: _wide ? 56 : 48,
      height: _wide ? 56 : 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary.withValues(alpha: _wide ? 0.22 : 0.34),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x668B7D6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final thinPaint = Paint()
      ..color = const Color(0x408B7D6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final mainPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.48,
        size.height * 0.2,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.28,
        size.width * 0.88,
        size.height * 0.18,
      );

    final middlePath = Path()
      ..moveTo(size.width * 0.12, size.height * 0.4)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.34,
        size.width * 0.46,
        size.height * 0.44,
        size.width * 0.66,
        size.height * 0.36,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.33,
        size.width * 0.9,
        size.height * 0.42,
      );

    final lowerPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.72)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.6,
        size.width * 0.42,
        size.height * 0.8,
        size.width * 0.58,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.64,
        size.width * 0.92,
        size.height * 0.76,
      );

    final verticalPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.08)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.26,
        size.width * 0.34,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.56,
        size.width * 0.26,
        size.height * 0.84,
      );

    canvas.drawPath(mainPath, paint);
    canvas.drawPath(middlePath, paint);
    canvas.drawPath(lowerPath, paint);
    canvas.drawPath(verticalPath, thinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NativeMapLoadingSurface extends StatelessWidget {
  const _NativeMapLoadingSurface({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      color: const Color(0xFFF1ECE2),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Поднимаем карту',
            style: AppTextStyles.meta.copyWith(color: colors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _NativeMapErrorBadge extends StatelessWidget {
  const _NativeMapErrorBadge();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Positioned(
      top: 132,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.background.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Text(
          'Карта не успела подняться. Пока показываем облегчённый режим.',
          style: AppTextStyles.meta.copyWith(color: colors.inkSoft),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _FallbackMapSurface extends StatelessWidget {
  const _FallbackMapSurface({
    super.key,
    required this.events,
    required this.selectedId,
    required this.onTap,
    this.footer,
  });

  final List<Event> events;
  final String selectedId;
  final ValueChanged<String> onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('map-fallback-surface'),
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1ECE2), Color(0xFFE3D7C6)],
              ),
            ),
            child: CustomPaint(
              painter: _MapPainter(),
            ),
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final eventsWithCoordinates = events
                  .where((event) =>
                      event.latitude != null && event.longitude != null)
                  .toList(growable: false);
              return Stack(
                children: [
                  for (final entry in eventsWithCoordinates.asMap().entries)
                    Positioned(
                      left: constraints.maxWidth *
                              _fallbackPositionForEvent(
                                entry.value,
                                entry.key,
                                events.length,
                              ).left -
                          28,
                      top: constraints.maxHeight *
                              _fallbackPositionForEvent(
                                entry.value,
                                entry.key,
                                events.length,
                              ).top -
                          28,
                      child: GestureDetector(
                        onTap: () => onTap(entry.value.id),
                        child: _FallbackPin(
                          emoji: entry.value.emoji,
                          selected: entry.value.id == selectedId,
                          tone: entry.value.tone,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }
}

({double left, double top}) _fallbackPositionForEvent(
  Event event,
  int index,
  int total,
) {
  final left = ((event.longitude! - 37.5) / 0.2).clamp(0.14, 0.86);
  final top = (1 - ((event.latitude! - 55.70) / 0.1)).clamp(0.18, 0.82);
  return (left: left, top: top);
}

class _FallbackPin extends StatelessWidget {
  const _FallbackPin({
    required this.emoji,
    required this.selected,
    required this.tone,
  });

  final String emoji;
  final bool selected;
  final EventTone tone;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 50.0 : 44.0;
    final color = _radarPinColor(emoji, tone);
    return Transform.scale(
      scale: selected ? 1.06 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BbV5Colors.paperHi,
              border: Border.all(color: BbV5Colors.hair),
              boxShadow: BbV5Shadows.pill,
            ),
            alignment: Alignment.center,
            child: Icon(
              _radarPinIcon(emoji, tone),
              size: selected ? 19 : 17,
              color: color,
            ),
          ),
          Positioned(
            left: size / 2 - 3,
            bottom: -8,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: BbV5Colors.ink.withValues(alpha: 0.20),
                    blurRadius: 8,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _radarPinIcon(String emoji, EventTone tone) {
  if (emoji.contains('✨') || tone == EventTone.sage) {
    return LucideIcons.sparkles;
  }
  if (emoji.contains('♡') || emoji.contains('❤️') || emoji.contains('💘')) {
    return LucideIcons.heart;
  }
  if (emoji.contains('🎟') || emoji.contains('🎫')) {
    return LucideIcons.ticket;
  }
  if (emoji.contains('☕')) {
    return LucideIcons.coffee;
  }
  if (emoji.contains('🚶')) {
    return LucideIcons.footprints;
  }
  return LucideIcons.wine;
}

Color _radarPinColor(String emoji, EventTone tone) {
  if (emoji.contains('✨') || tone == EventTone.sage) {
    return BbV5Colors.brand;
  }
  if (emoji.contains('♡') || emoji.contains('❤️') || emoji.contains('💘')) {
    return BbV5Colors.rose;
  }
  if (emoji.contains('🎟') || emoji.contains('🎫') || tone == EventTone.warm) {
    return BbV5Colors.gold;
  }
  if (emoji.contains('☕')) {
    return BbV5Colors.brandDeep;
  }
  return BbV5Colors.terra;
}
