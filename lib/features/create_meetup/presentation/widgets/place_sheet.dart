import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_address_geocoding_service.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/device/app_reverse_geocoding_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/utils/location_label.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' show Point;

class PlaceSelection {
  const PlaceSelection({
    required this.name,
    required this.address,
    this.distance,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.category,
    this.emoji,
    this.externalPlaceId,
    this.bookingUrl,
    this.averageCheck,
    this.currency,
    this.provider,
    this.promos = const [],
  });

  final String name;
  final String address;
  final String? distance;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? emoji;
  final String? externalPlaceId;
  final String? bookingUrl;
  final int? averageCheck;
  final String? currency;
  final String? provider;
  final List<BackendPlacePromo> promos;
}

Future<PlaceSelection?> showPlaceSheet(
  BuildContext context, {
  required PlaceSelection initialValue,
  VoidCallback? onPickAfficheEvent,
}) {
  final container = ProviderScope.containerOf(context, listen: false);

  return showModalBottomSheet<PlaceSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: BbV5Colors.ink.withValues(alpha: 0.5),
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: _PlaceSheet(
        initialValue: initialValue,
        onPickAfficheEvent: onPickAfficheEvent,
      ),
    ),
  );
}

const _recentPlaces = <PlaceSelection>[];

const _nearbyPlaces = <PlaceSelection>[
  PlaceSelection(
    name: 'Brix',
    address: 'Покровка 12',
    distance: '0.4 км',
    distanceKm: 0.4,
    category: 'Винный бар',
    emoji: '🍷',
  ),
  PlaceSelection(
    name: 'Aglio',
    address: 'Маросейка 6',
    distance: '0.7 км',
    distanceKm: 0.7,
    category: 'Trattoria',
    emoji: '🍝',
  ),
  PlaceSelection(
    name: 'Powerhouse',
    address: 'Казакова 8',
    distance: '1.2 км',
    distanceKm: 1.2,
    category: 'Late jazz',
    emoji: '🎶',
  ),
  PlaceSelection(
    name: 'Парк Горького',
    address: 'Главный вход',
    distance: '2.4 км',
    distanceKm: 2.4,
    category: 'Open air',
    emoji: '🌿',
  ),
  PlaceSelection(
    name: 'Хохловский переулок',
    address: 'У арки',
    distance: '0.9 км',
    distanceKm: 0.9,
    category: 'Дворик',
    emoji: '☕',
  ),
];

class _PlaceSheet extends ConsumerStatefulWidget {
  const _PlaceSheet({
    required this.initialValue,
    this.onPickAfficheEvent,
  });

  final PlaceSelection initialValue;
  final VoidCallback? onPickAfficheEvent;

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  final _queryController = TextEditingController();
  Timer? _searchDebounce;
  bool _searching = false;
  bool _resolvingCurrentLocation = false;
  List<PlaceSelection> _remoteResults = const [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final localMatches = query.isEmpty
        ? _nearbyPlaces
        : _nearbyPlaces
            .where(
              (place) =>
                  place.name.toLowerCase().contains(query) ||
                  place.address.toLowerCase().contains(query),
            )
            .toList(growable: false);
    final filtered = query.isNotEmpty && _remoteResults.isNotEmpty
        ? _remoteResults
        : localMatches;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.85,
            decoration: const BoxDecoration(
              color: BbV5Colors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: Offset(0, -20),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: BbV5Colors.hair,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BbV5Kicker('выбрать'),
                            const SizedBox(height: 8),
                            Text(
                              'Где встречаемся',
                              style: bbV5DisplayStyle(
                                fontSize: 20,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PlaceSheetCloseButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _PlaceSearchField(
                    controller: _queryController,
                    onChanged: _handleQueryChanged,
                    onClear: () => setState(() {
                      _queryController.clear();
                      _remoteResults = const [];
                      _searching = false;
                    }),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    children: [
                      if (_searching && query.isNotEmpty && filtered.isEmpty)
                        const _PlaceLoadingState()
                      else if (filtered.isEmpty)
                        const _PlaceEmptyState()
                      else
                        ...filtered.map(
                          (place) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PlaceRow(
                              place: place,
                              selected: _samePlace(
                                place,
                                widget.initialValue,
                              ),
                              onTap: () => Navigator.of(context).pop(place),
                            ),
                          ),
                        ),
                      if (query.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PlaceRow(
                            place: PlaceSelection(
                              name: 'Моё местоположение',
                              address: _resolvingCurrentLocation
                                  ? 'Определяем текущую точку'
                                  : 'Использовать текущую точку',
                              distance:
                                  _resolvingCurrentLocation ? null : '0 м',
                              category: 'Геолокация',
                            ),
                            current: true,
                            onTap: _resolvingCurrentLocation
                                ? () {}
                                : _pickCurrentLocation,
                          ),
                        ),
                        if (widget.onPickAfficheEvent != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PlaceRow(
                              place: const PlaceSelection(
                                name: 'Афиша города',
                                address: 'Выбрать событие',
                                category: 'События',
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onPickAfficheEvent?.call();
                              },
                            ),
                          ),
                        if (_recentPlaces.isNotEmpty)
                          ..._recentPlaces.map(
                            (place) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PlaceRow(
                                place: place,
                                selected:
                                    _samePlace(place, widget.initialValue),
                                onTap: () => Navigator.of(context).pop(place),
                              ),
                            ),
                          ),
                      ],
                      if (query.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _UseTypedPlaceButton(
                          label: _queryController.text.trim(),
                          onTap: () => Navigator.of(context).pop(
                            PlaceSelection(
                              name: _queryController.text.trim(),
                              address: 'Своё место',
                              emoji: '📍',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _samePlace(PlaceSelection left, PlaceSelection right) {
    return left.name == right.name && left.address == right.address;
  }

  void _handleQueryChanged(String value) {
    final trimmed = value.trim();
    _searchDebounce?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      if (trimmed.isEmpty || trimmed.length < 2) {
        _remoteResults = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });

    if (trimmed.isEmpty || trimmed.length < 2) {
      return;
    }

    final mapService = ref.read(yandexMapServiceProvider);
    final addressGeocodingService =
        ref.read(appAddressGeocodingServiceProvider);
    final repository = ref.read(backendRepositoryProvider);
    final near = _manualLocationSearchPoint();
    final city = _manualLocationSearchCity();
    late final Timer searchTimer;
    searchTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || !identical(_searchDebounce, searchTimer)) {
        return;
      }

      final places = await _searchPlaceResults(
        trimmed,
        mapService,
        addressGeocodingService,
        repository: repository,
        near: near,
        city: city,
      );

      if (!mounted ||
          !identical(_searchDebounce, searchTimer) ||
          _queryController.text.trim() != trimmed) {
        return;
      }

      setState(() {
        _searching = false;
        _remoteResults = places;
      });
    });
    _searchDebounce = searchTimer;
  }

  Future<void> _pickCurrentLocation() async {
    final locationService = ref.read(appLocationServiceProvider);
    final mapService = ref.read(yandexMapServiceProvider);
    final reverseGeocodingService =
        ref.read(appReverseGeocodingServiceProvider);
    setState(() {
      _resolvingCurrentLocation = true;
    });

    try {
      final position = await locationService.getCurrentPosition();
      if (!mounted) {
        return;
      }
      if (position == null) {
        return;
      }
      final address = await _currentLocationAddress(
        latitude: position.latitude,
        longitude: position.longitude,
        mapService: mapService,
        reverseGeocodingService: reverseGeocodingService,
      );
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        PlaceSelection(
          name: 'Моё местоположение',
          address: address,
          distance: '0 м',
          distanceKm: 0,
          latitude: position.latitude,
          longitude: position.longitude,
          emoji: '📍',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resolvingCurrentLocation = false;
        });
      }
    }
  }

  Future<List<PlaceSelection>> _searchPlaceResults(
    String query,
    YandexMapService mapService,
    AppAddressGeocodingService addressGeocodingService, {
    required BackendRepository repository,
    Point? near,
    required String city,
  }) async {
    final backendPlaces = await _searchBackendPlaces(
      query,
      repository,
      near: near,
      city: city,
    );
    if (backendPlaces.isNotEmpty) {
      return backendPlaces;
    }

    final yandexPlaces = await _searchYandexPlaces(
      query,
      mapService,
      near: near,
    );
    if (yandexPlaces.isNotEmpty) {
      return yandexPlaces;
    }

    final fallbackPlace = await _geocodeTypedAddress(
      query,
      addressGeocodingService,
    );
    return fallbackPlace == null ? const [] : [fallbackPlace];
  }

  Future<List<PlaceSelection>> _searchBackendPlaces(
    String query,
    BackendRepository repository, {
    Point? near,
    required String city,
  }) async {
    try {
      final places = await repository
          .searchPlaces(
            query: query,
            city: city,
            latitude: near?.latitude,
            longitude: near?.longitude,
            limit: 10,
          )
          .timeout(const Duration(seconds: 2));
      return places
          .map(
            (place) => PlaceSelection(
              name: place.name.trim().isEmpty ? place.address : place.name,
              address: place.address,
              distance: place.distanceKm == null
                  ? null
                  : '${place.distanceKm!.toStringAsFixed(1)} км',
              distanceKm: place.distanceKm,
              latitude: place.lat,
              longitude: place.lng,
              category: place.placeKind ?? place.category ?? 'ТоМесто',
              emoji: _emojiForPlace(place.name, place.category ?? ''),
              externalPlaceId: place.id,
              bookingUrl: place.bookingUrl,
              averageCheck: place.averageCheck,
              currency: place.currency,
              provider: place.provider,
              promos: place.promos,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PlaceSelection>> _searchYandexPlaces(
    String query,
    YandexMapService mapService, {
    Point? near,
  }) async {
    try {
      final resolved = await mapService
          .searchPlaces(
            query,
            near: near,
            geocodeFirst: true,
          )
          .timeout(const Duration(seconds: 6));
      return resolved
          .map(
            (item) => PlaceSelection(
              name: item.name.trim().isEmpty
                  ? _nameFromAddress(item.address)
                  : item.name,
              address: item.address,
              latitude: item.point.latitude,
              longitude: item.point.longitude,
              category: item.category ?? 'Яндекс',
              emoji: _emojiForPlace(item.name, item.address),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Point? _manualLocationSearchPoint() {
    final location = ref.read(manualLocationProvider);
    if (location == null || !isSupportedManualLocation(location)) {
      return null;
    }
    return Point(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  String _manualLocationSearchCity() {
    final location = ref.read(manualLocationProvider);
    if (location == null || !isSupportedManualLocation(location)) {
      return 'Москва';
    }
    final city = normalizeCityLabel(location.city);
    if (city.isNotEmpty) {
      return city;
    }
    final label = normalizeCityLabel(location.label);
    return label.isEmpty ? 'Москва' : label;
  }

  Future<PlaceSelection?> _geocodeTypedAddress(
    String query,
    AppAddressGeocodingService addressGeocodingService,
  ) async {
    try {
      final resolved = await addressGeocodingService.geocodeAddress(query);
      if (resolved == null) {
        return null;
      }

      return PlaceSelection(
        name: query,
        address: 'Найдено по системному геокодеру',
        latitude: resolved.latitude,
        longitude: resolved.longitude,
        category: 'Адрес',
        emoji: '📍',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _currentLocationAddress({
    required double latitude,
    required double longitude,
    required YandexMapService mapService,
    required AppReverseGeocodingService reverseGeocodingService,
  }) async {
    final yandexAddress = await _reverseGeocodeWithYandex(
      latitude: latitude,
      longitude: longitude,
      mapService: mapService,
    );
    if (yandexAddress != null) {
      return yandexAddress;
    }

    final platformAddress = await _reverseGeocodeWithPlatform(
      latitude: latitude,
      longitude: longitude,
      reverseGeocodingService: reverseGeocodingService,
    );
    return platformAddress ?? _coordinateAddress(latitude, longitude);
  }

  Future<String?> _reverseGeocodeWithYandex({
    required double latitude,
    required double longitude,
    required YandexMapService mapService,
  }) async {
    try {
      final resolved = await mapService
          .reverseGeocode(
            Point(latitude: latitude, longitude: longitude),
          )
          .timeout(const Duration(seconds: 6));
      final address = resolved?.address.trim();
      return address == null || address.isEmpty ? null : address;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocodeWithPlatform({
    required double latitude,
    required double longitude,
    required AppReverseGeocodingService reverseGeocodingService,
  }) async {
    try {
      final resolved = await reverseGeocodingService.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      return _platformAddress(resolved);
    } catch (_) {
      return null;
    }
  }

  String? _platformAddress(ReverseGeocodedLocation? location) {
    if (location == null) {
      return null;
    }

    final parts = <String>[];
    void addPart(String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty && !parts.contains(trimmed)) {
        parts.add(trimmed);
      }
    }

    addPart(location.street);
    addPart(location.city);

    return parts.isEmpty ? null : parts.join(', ');
  }

  String _coordinateAddress(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  String _nameFromAddress(String address) {
    final parts = address.split(',');
    return parts.first.trim().isEmpty ? address : parts.first.trim();
  }

  String _emojiForPlace(String name, String address) {
    final normalized = '$name $address'.toLowerCase();
    if (normalized.contains('бар') || normalized.contains('wine')) {
      return '🍷';
    }
    if (normalized.contains('кафе') || normalized.contains('кофе')) {
      return '☕';
    }
    if (normalized.contains('парк')) {
      return '🌳';
    }
    if (normalized.contains('музей') || normalized.contains('галерея')) {
      return '🎨';
    }
    return '📍';
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.onTap,
    this.selected = false,
    this.current = false,
  });

  final PlaceSelection place;
  final VoidCallback onTap;
  final bool selected;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? BbV5Colors.paperDeep : BbV5Colors.paperHi,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0FFFFFFF),
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                alignment: Alignment.center,
                child: Icon(
                  current ? LucideIcons.locate_fixed : LucideIcons.map_pin,
                  size: 16,
                  color: BbV5Colors.terra,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: AppTextStyles.body.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: BbV5Colors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _placeSubtitle(place),
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkMute,
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (place.externalPlaceId != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          const _PlaceBadge(label: 'Можно забронировать'),
                          if (place.averageCheck != null)
                            _PlaceBadge(
                              label:
                                  'Средний чек ${place.averageCheck} ${_currencySymbol(place.currency)}',
                            ),
                        ],
                      ),
                      if (place.promos.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          place.promos.first.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.terra,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                LucideIcons.chevron_right,
                size: 24,
                color: BbV5Colors.inkMute,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _placeSubtitle(PlaceSelection place) {
    final category = place.category?.trim();
    final distance = place.distance?.trim();
    final address = place.address.trim();

    if (distance != null && distance.isNotEmpty) {
      final primary = category != null && category.isNotEmpty
          ? category
          : address.isNotEmpty
              ? address
              : null;
      return primary == null ? distance : '$primary · $distance';
    }

    if (category != null && category.isNotEmpty && address.isNotEmpty) {
      return '$address · $category';
    }

    if (category != null && category.isNotEmpty) {
      return category;
    }

    return address;
  }
}

class _PlaceBadge extends StatelessWidget {
  const _PlaceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BbV5Colors.brandSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: BbV5Colors.inkSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _currencySymbol(String? currency) {
  return currency == 'RUB' || currency == null ? '₽' : currency;
}

class _PlaceSheetCloseButton extends StatelessWidget {
  const _PlaceSheetCloseButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbV5Colors.paperHi,
      shape: const CircleBorder(
        side: BorderSide(color: BbV5Colors.hair),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            LucideIcons.x,
            size: 26,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchField extends StatelessWidget {
  const _PlaceSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BbV5Colors.hair),
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
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: 'Найти...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: BbV5Colors.inkMute.withValues(alpha: 0.72),
                  fontSize: 13.5,
                  height: 1.2,
                ),
              ),
              style: AppTextStyles.body.copyWith(
                color: BbV5Colors.ink,
                fontSize: 13.5,
                height: 1.2,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Очистить',
              onPressed: onClear,
              icon: const Icon(
                LucideIcons.x,
                size: 18,
                color: BbV5Colors.inkMute,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceLoadingState extends StatelessWidget {
  const _PlaceLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BbV5Colors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ищем адрес',
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceEmptyState extends StatelessWidget {
  const _PlaceEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        'Ничего не нашли',
        textAlign: TextAlign.center,
        style: AppTextStyles.meta.copyWith(
          color: BbV5Colors.inkMute,
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
    );
  }
}

class _UseTypedPlaceButton extends StatelessWidget {
  const _UseTypedPlaceButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbV5Colors.accent,
      borderRadius: BorderRadius.circular(BbV5Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.check,
                size: 18,
                color: BbV5Colors.paperHi,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Использовать «$label»',
                  style: AppTextStyles.button.copyWith(
                    color: BbV5Colors.paperHi,
                    fontSize: 13,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
