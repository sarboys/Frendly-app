import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/tonight/presentation/v5_search_modal.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
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

const _initialNearbyRadiusKm = 25.0;
const _mapZoomStep = 1.0;
const _minMapZoom = 2.0;
const _maxMapZoom = 19.0;

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
  ym.YandexMapController? _mapController;
  Timer? _viewportQueryDebounce;
  int _mapControllerGeneration = 0;
  int _viewportQueryGeneration = 0;
  int _viewportFitGeneration = 0;
  MapEventsQuery _mapQuery = const MapEventsQuery();
  ym.Point? _searchPoint;
  ym.Point? _userPoint;
  String selected = '';
  String filter = 'all';
  bool _locating = false;
  bool _primingInitialLocation = false;
  bool _didPrimeInitialLocation = false;
  bool _triedInitialLocation = false;
  bool _autoFitPending = false;
  String _lastViewportFitKey = '';

  bool get _supportsNativeMap =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    _eventPageController = PageController(viewportFraction: 0.52);
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
    final rawEvents =
        ref.watch(mapEventsProvider(_mapQuery)).valueOrNull ?? const <Event>[];
    final events = rawEvents;
    final filteredEvents = _filteredEvents(events, filter);
    final liveEvenings =
        (ref.watch(eveningSessionsProvider).valueOrNull ?? const [])
            .where((session) => session.phase == EveningSessionPhase.live)
            .take(4)
            .toList(growable: false);
    final activeEvent = filteredEvents
            .where((item) => item.id == selected)
            .cast<Event?>()
            .firstOrNull ??
        (filteredEvents.isNotEmpty ? filteredEvents.first : null);
    final selectedId = activeEvent?.id ?? selected;
    final mapObjects = _buildMapObjects(
      filteredEvents,
      selectedId,
      liveEvenings,
    );
    _syncPagerToSelected(filteredEvents, selectedId);
    _scheduleViewportFit(filteredEvents);

    return Scaffold(
      backgroundColor: BbV5Colors.paper,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildMapSurface(
                filteredEvents,
                mapObjects,
                selectedId,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: _RadarMapVisualOverlay(
                  showUserPulse: !_supportsNativeMap,
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
              top: 12,
              child: _RadarTopControls(
                events: events,
                filter: filter,
                onBack: _handleBack,
                onSelectFilter: (nextFilter) => _selectFilter(
                  nextFilter,
                  events,
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: MediaQuery.sizeOf(context).height * 0.40,
              child: Column(
                children: [
                  _MapTopButton(
                    icon: LucideIcons.layers,
                    tooltip: 'Слои карты',
                    onTap: () => _selectFilter(
                      filter == 'all' ? 'calm' : 'all',
                      events,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  _MapTopButton(
                    icon: _locating
                        ? LucideIcons.ellipsis
                        : LucideIcons.locate_fixed,
                    tooltip: 'Моё место',
                    onTap: _locating ? null : _moveToCurrentLocation,
                  ),
                ],
              ),
            ),
            if (filteredEvents.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: _RadarBottomSheet(
                  count: filteredEvents.length,
                  events: filteredEvents,
                  pageController: _eventPageController,
                  onPageChanged: (index) {
                    if (index < 0 || index >= filteredEvents.length) {
                      return;
                    }
                    _selectEvent(
                      filteredEvents[index],
                      filteredEvents,
                      animatePager: false,
                    );
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
        onTap: (eventId) => _handleEventTap(eventId, filteredEvents),
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
            onTap: (eventId) => _handleEventTap(eventId, filteredEvents),
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
            mapType: ym.MapType.map,
            mode2DEnabled: true,
            poiLimit: 0,
          ),
        );
      },
    );
  }

  List<ym.MapObject> _buildMapObjects(
    List<Event> filteredEvents,
    String selectedId,
    List<EveningSessionSummary> liveEvenings,
  ) {
    final eventPlacemarks = buildEventPlacemarks(
      events: filteredEvents,
      selectedId: selectedId,
      onEventTap: (eventId) => _handleEventTap(eventId, filteredEvents),
    );
    final eveningPlacemarks = buildLiveEveningPlacemarks(
      sessions: liveEvenings,
      onSessionTap: _openEveningPreview,
    );
    final objects = <ym.MapObject>[
      ...eventPlacemarks,
      ...eveningPlacemarks,
    ];

    if (_userPoint != null) {
      objects.add(buildUserLocationPlacemark(_userPoint!));
    }

    if (_searchPoint != null) {
      objects.add(
        ym.PlacemarkMapObject(
          mapId: const ym.MapObjectId('search_point'),
          point: _searchPoint!,
          zIndex: 3,
          text: const ym.PlacemarkText(
            text: '📍',
            style: ym.PlacemarkTextStyle(
              size: 18,
              placement: ym.TextStylePlacement.center,
              offsetFromIcon: false,
            ),
          ),
        ),
      );
    }

    return objects;
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
    unawaited(controller.setMapStyle(_yandexV5MapStyle));
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
    if (!shouldRefreshMapViewportQuery(reason: reason, finished: finished)) {
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

  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _locating = true;
    });

    try {
      final point = await _resolvePreferredMapPoint();
      if (point == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _autoFitPending = true;
        _lastViewportFitKey = '';
        _searchPoint = point;
        _userPoint = point;
        _mapQuery = buildInitialMapEventsQuery(point);
      });
      unawaited(_moveToUserPreview(point));
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
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

  void _handleEventTap(String eventId, List<Event> events) {
    final event = events.where((item) => item.id == eventId).firstOrNull;
    if (event == null) {
      return;
    }
    _selectEvent(event, events, animatePager: true);
  }

  void _selectEvent(
    Event event,
    List<Event> events, {
    required bool animatePager,
  }) {
    setState(() {
      selected = event.id;
    });

    final point = _pointForEvent(event);
    if (point != null) {
      unawaited(_moveToPoint(point, zoom: 15));
    }

    if (animatePager) {
      final index = events.indexWhere((item) => item.id == event.id);
      if (index >= 0 && _eventPageController.hasClients) {
        unawaited(
          _eventPageController.animateToPage(
            index,
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
      final currentPage = _eventPageController.page?.round() ?? 0;
      if (currentPage == index) {
        return;
      }
      _eventPageController.jumpToPage(index);
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

  void _selectFilter(String nextFilter, List<Event> events) {
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
        unawaited(
          _eventPageController.animateToPage(
            index,
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

  List<Event> _filteredEvents(List<Event> events, String currentFilter) {
    switch (currentFilter) {
      case 'now':
        return events
            .where((item) => item.time.toLowerCase().contains('сегодня'))
            .toList(growable: false);
      case 'popular':
        return events.where((item) => item.going >= 8).toList(growable: false);
      case 'calm':
        return events
            .where((item) => item.vibe.toLowerCase() == 'спокойно')
            .toList(growable: false);
      case 'all':
      default:
        return events;
    }
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
    required this.filter,
    required this.onBack,
    required this.onSelectFilter,
  });

  final List<Event> events;
  final String filter;
  final VoidCallback onBack;
  final ValueChanged<String> onSelectFilter;

  @override
  Widget build(BuildContext context) {
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
                    onTap: () => onSelectFilter(
                      filter == 'all' ? 'calm' : 'all',
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
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = _radarFilters[index];
                    return _RadarFilterChip(
                      label: item.title,
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
  _RadarFilterDefinition(key: 'now', title: 'Сейчас'),
  _RadarFilterDefinition(key: 'popular', title: 'Популярные'),
  _RadarFilterDefinition(key: 'calm', title: 'Спокойно'),
];

const _yandexV5MapStyle = '''
[
  {
    "tags": {
      "all": ["landscape"]
    },
    "stylers": {
      "color": "F1E6D6",
      "saturation": -0.6,
      "lightness": 0.24
    }
  },
  {
    "tags": {
      "all": ["water"]
    },
    "stylers": {
      "color": "E8D6BE",
      "saturation": -0.7,
      "lightness": 0.18
    }
  },
  {
    "tags": {
      "all": ["road"]
    },
    "stylers": {
      "color": "D8C7B4",
      "saturation": -0.8,
      "lightness": 0.26
    }
  },
  {
    "tags": {
      "all": ["poi"]
    },
    "stylers": {
      "visibility": "off"
    }
  }
]
''';

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
      autoFitPending &&
      fitKey.isNotEmpty &&
      fitKey != lastFitKey;
}

@visibleForTesting
bool shouldRefreshMapViewportQuery({
  required ym.CameraUpdateReason reason,
  required bool finished,
}) {
  return finished && reason == ym.CameraUpdateReason.gestures;
}

@visibleForTesting
double clampMapZoom(double zoom) {
  return zoom.clamp(_minMapZoom, _maxMapZoom).toDouble();
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
List<ym.PlacemarkMapObject> buildEventPlacemarks({
  required List<Event> events,
  required String selectedId,
  required void Function(String eventId) onEventTap,
}) {
  return [
    for (final event in events)
      if (event.latitude != null && event.longitude != null)
        ym.PlacemarkMapObject(
          mapId: ym.MapObjectId('event_${event.id}'),
          point: ym.Point(
            latitude: event.latitude!,
            longitude: event.longitude!,
          ),
          zIndex: event.id == selectedId ? 2 : 1,
          consumeTapEvents: true,
          opacity: 1,
          icon: ym.PlacemarkIcon.single(
            ym.PlacemarkIconStyle(
              image: ym.BitmapDescriptor.fromBytes(
                _eventPinBytes(),
              ),
              scale: event.id == selectedId ? 0.72 : 0.62,
              anchor: const Offset(0.5, 0.5),
            ),
          ),
          onTap: (_, __) => onEventTap(event.id),
          text: ym.PlacemarkText(
            text: event.emoji,
            style: ym.PlacemarkTextStyle(
              size: event.id == selectedId ? 15 : 13,
              color: const Color(0xFF2A2A2A),
              outlineColor: Colors.white,
              placement: ym.TextStylePlacement.center,
              offsetFromIcon: false,
            ),
          ),
        ),
  ];
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
            ym.PlacemarkIconStyle(
              image: ym.BitmapDescriptor.fromBytes(
                _eventPinBytes(),
              ),
              scale: 0.62,
              anchor: const Offset(0.5, 0.5),
            ),
          ),
          onTap: (_, __) => onSessionTap(session.id),
          text: ym.PlacemarkText(
            text: session.emoji,
            style: const ym.PlacemarkTextStyle(
              size: 14,
              color: Color(0xFF2A2A2A),
              outlineColor: Colors.white,
              placement: ym.TextStylePlacement.center,
              offsetFromIcon: false,
            ),
          ),
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
      ym.PlacemarkIconStyle(
        image: ym.BitmapDescriptor.fromBytes(
          _eventPinBytes(),
        ),
        scale: 0.54,
        anchor: const Offset(0.5, 0.5),
      ),
    ),
    text: const ym.PlacemarkText(
      text: '●',
      style: ym.PlacemarkTextStyle(
        size: 15,
        color: BbV5Colors.accent,
        outlineColor: Colors.white,
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
    centerLatitude: _roundGeo(center.latitude),
    centerLongitude: _roundGeo(center.longitude),
    radiusKm: _roundDistanceKm(radiusKm.clamp(0.5, 100).toDouble()),
    southWestLatitude: _roundGeo(bounds.southWest.latitude),
    southWestLongitude: _roundGeo(bounds.southWest.longitude),
    northEastLatitude: _roundGeo(bounds.northEast.latitude),
    northEastLongitude: _roundGeo(bounds.northEast.longitude),
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
    radiusKm: _initialNearbyRadiusKm,
  );
}

@visibleForTesting
ym.Point? resolvePreferredMapPoint({
  ManualLocation? manualLocation,
  Position? currentPosition,
}) {
  if (manualLocation != null) {
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

final _eventPinCache = <String, Uint8List>{};

Uint8List _eventPinBytes() {
  const key = 'event-pin-circle-v1';
  final cached = _eventPinCache[key];
  if (cached != null) {
    return cached;
  }

  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAEgAAABICAYAAABV7bNHAAACx0lEQVR42u2cr3LCQBDGKxAIRGV9BRJRiaioqMMVyQMgKxDIiDwAAolERCIqIniAvgAPgOhMDdNhppbuznwyuT/NBZLLdzOfYUhy+c3e7t3eXu7u2NjYYmyXy6UnehANRU+isegZGuO3If7T6wKQgWgkmojmokS0Fm1FO1Eu2kM5ftviPwmumeAeg5isRC1hJkpFmehT9DV6e7n4SK/BtRnuNcO9e20Ecy96FS3xQgdfIA7ADrj3Es+6bwOYPjqbYJicQoMpAHXCsxI8u99UOGruC9GH6Fw3mAJQZzxb+/DUNOc7FW1ER5+X+v35dpInqCP6Mr25M5cOPIreNfKEBBICGKKh9u3xlkMqdXHAocD4goIjT68+5DCRW9nCdV1gfEBheqB9HV8TztoUoa4FxhUUIt26dkgYVqsmwnGEtKptuMEhp2XD6tZgXEBhuKXBHTdC+XuZQ24aHAukA95lEBLQtCyUNxWOBZJOAaYh/c6mjXAskDaV/RHWVouyGXLLAR3xbv0qgHTx99FmOBZIunZ7rZKySIoWnm2DUwYJC9zkX6kSWE8eg/VYrCj3tiJkApdFE8K2wjFY0Qnv2vONXFlM1mOxoswroiHfe4gNjsGKdPI485k1pzFaj8WKUqfZNbZVsljhGKxIh9nIBZDuPX12EJBuKU1cAM2LVuwdAKQr/blLeE9i9j8WP5QYwz32wdexwzFYkWYdH0yAtFhg22FAWgswtE0Qdx0GtDNOGJGQzzsMKDcm9lGbs+8wIM00PhNQBUAcYpYhRidtcdIM85Ywz4miZaLIpYYts8jFKtMdldMdTJgx5Voh5cqkPbd9gmz7cOOQW88Vtp5ZvMDyl+rlLyygYgneJlhJMIs4WQbMQvJaC8l5FIGHWXgc6mpweKCORzJ5qJfHwpt0LJwfFuCnKWoFxY+beDpzfh7H07r4gSU2tm63PwhRxsGm70hUAAAAAElFTkSuQmCC',
  );
  _eventPinCache[key] = bytes;
  return bytes;
}

double _roundGeo(double value) => double.parse(value.toStringAsFixed(5));

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
    required this.count,
    required this.events,
    required this.pageController,
    required this.onPageChanged,
    required this.onEventTap,
  });

  final int count;
  final List<Event> events;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Event> onEventTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BbV5Colors.hair,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BbV5Kicker('Рядом сегодня'),
                        const SizedBox(height: 6),
                        Text(
                          '$count точек · ${_initialNearbyRadiusKm.toStringAsFixed(0)} км',
                          style: bbV5DisplayStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  BbV5PillButton(
                    label: 'AI подбор',
                    icon: LucideIcons.sparkles,
                    height: 36,
                    fontSize: 11.5,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 148,
                child: PageView.builder(
                  controller: pageController,
                  padEnds: false,
                  onPageChanged: onPageChanged,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == events.length - 1 ? 0 : 12,
                      ),
                      child: _RadarEventCard(
                        event: event,
                        onTap: () => onEventTap(event),
                      ),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: Text(
                  event.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.itemTitle.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: BbV5Colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${event.vibe} · ${event.distance}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
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
