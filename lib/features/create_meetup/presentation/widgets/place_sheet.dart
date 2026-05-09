import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_address_geocoding_service.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/device/app_reverse_geocoding_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
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
  });

  final String name;
  final String address;
  final String? distance;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? emoji;
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
    final colors = AppColors.of(context);
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
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      'Где встречаемся',
                      textAlign: TextAlign.center,
                      style: bbV5DisplayStyle(
                        fontSize: 18,
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: colors.inkMute,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        onChanged: _handleQueryChanged,
                        decoration: InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: 'Кафе, бар, парк или адрес',
                          hintStyle: AppTextStyles.bodySoft.copyWith(
                            color: colors.inkMute,
                            fontSize: 13.5,
                            height: 1.2,
                          ),
                        ),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (_queryController.text.isNotEmpty)
                      IconButton(
                        onPressed: () => setState(() {
                          _queryController.clear();
                          _remoteResults = const [];
                          _searching = false;
                        }),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colors.inkMute,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.onPickAfficheEvent != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPickAfficheEvent?.call();
                    },
                    icon: const Icon(Icons.confirmation_number_outlined,
                        size: 18),
                    label: const Text('Идём на событие из афиши'),
                    style: FilledButton.styleFrom(
                      textStyle: AppTextStyles.button.copyWith(
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (query.isEmpty)
                    _PlaceRow(
                      place: PlaceSelection(
                        name: 'Моё местоположение',
                        address: _resolvingCurrentLocation
                            ? 'Определяем текущую точку'
                            : 'Использовать текущую точку',
                        distance: _resolvingCurrentLocation ? null : '0 м',
                        emoji: '📍',
                      ),
                      current: true,
                      onTap: _resolvingCurrentLocation
                          ? () {}
                          : _pickCurrentLocation,
                    ),
                  if (query.isEmpty && _recentPlaces.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _ListTitle(
                      icon: Icons.schedule_rounded,
                      title: 'Недавние',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ..._recentPlaces.map(
                      (place) => _PlaceRow(
                        place: place,
                        selected: _samePlace(place, widget.initialValue),
                        onTap: () => Navigator.of(context).pop(place),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _ListTitle(
                    title: query.isEmpty
                        ? 'Рядом с тобой'
                        : 'Найдено · ${filtered.length}',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (_searching && query.isNotEmpty && filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Ищем адрес',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.meta.copyWith(
                              color: colors.inkMute,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Ничего не нашли. Попробуй другой запрос.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.meta.copyWith(
                          color: colors.inkMute,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (place) => _PlaceRow(
                        place: place,
                        selected: _samePlace(place, widget.initialValue),
                        onTap: () => Navigator.of(context).pop(place),
                      ),
                    ),
                  if (query.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        PlaceSelection(
                          name: _queryController.text.trim(),
                          address: 'Своё место',
                          emoji: '📍',
                        ),
                      ),
                      icon: const Icon(Icons.place_outlined, size: 18),
                      label: Text(
                          'Использовать «${_queryController.text.trim()}»'),
                      style: OutlinedButton.styleFrom(
                        textStyle: AppTextStyles.button.copyWith(
                          fontSize: 13,
                          height: 1.1,
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
      if (trimmed.isEmpty || trimmed.length < 3) {
        _remoteResults = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });

    if (trimmed.isEmpty || trimmed.length < 3) {
      return;
    }

    final mapService = ref.read(yandexMapServiceProvider);
    final addressGeocodingService =
        ref.read(appAddressGeocodingServiceProvider);
    late final Timer searchTimer;
    searchTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || !identical(_searchDebounce, searchTimer)) {
        return;
      }

      final places = await _searchPlaceResults(
        trimmed,
        mapService,
        addressGeocodingService,
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
    AppAddressGeocodingService addressGeocodingService,
  ) async {
    final yandexPlaces = await _searchYandexPlaces(query, mapService);
    if (yandexPlaces.isNotEmpty) {
      return yandexPlaces;
    }

    final fallbackPlace = await _geocodeTypedAddress(
      query,
      addressGeocodingService,
    );
    return fallbackPlace == null ? const [] : [fallbackPlace];
  }

  Future<List<PlaceSelection>> _searchYandexPlaces(
    String query,
    YandexMapService mapService,
  ) async {
    try {
      final resolved = await mapService
          .searchPlaces(query)
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

class _ListTitle extends StatelessWidget {
  const _ListTitle({
    required this.title,
    this.icon,
  });

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: colors.inkMute),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: bbV5KickerStyle(
            color: colors.inkMute,
          ),
        ),
      ],
    );
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
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.muted : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: current ? colors.primarySoft : colors.warmStart,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  place.emoji ?? '📍',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.category == null
                          ? place.address
                          : '${place.address} · ${place.category}',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (place.distance != null)
                Text(
                  place.distance!,
                  style: AppTextStyles.meta.copyWith(
                    color: colors.inkMute,
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
