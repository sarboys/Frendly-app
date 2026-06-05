import 'dart:async';

import 'package:dio/dio.dart';
import 'package:mobile2/app/core/local_cache/app_cache_key.dart';
import 'package:mobile2/app/core/local_cache/app_local_cache_store.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

const afficheClientGeoCacheNamespace = 'affiche_geo';
const _cacheTtl = Duration(days: 7);
const _defaultThrottle = Duration(milliseconds: 1500);
const _maxAttemptsPerScreen = 8;

typedef AfficheClientGeoBackendSaver = Future<AfficheClientGeoSaveResult>
    Function(
  AfficheClientGeoSaveRequest request, {
  CancelToken? cancelToken,
});

abstract class AfficheClientGeoPlaceSearcher {
  Future<List<AfficheClientGeoPlaceResult>> search(
    String query, {
    int limit = 8,
    CancelToken? cancelToken,
  });
}

class YandexMapKitAffichePlaceSearcher
    implements AfficheClientGeoPlaceSearcher {
  const YandexMapKitAffichePlaceSearcher();

  @override
  Future<List<AfficheClientGeoPlaceResult>> search(
    String query, {
    int limit = 8,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      return const [];
    }
    final session = await ym.YandexSearch.searchByText(
      searchText: query,
      geometry: ym.Geometry.fromBoundingBox(
        const ym.BoundingBox(
          northEast: ym.Point(latitude: 85, longitude: 180),
          southWest: ym.Point(latitude: -85, longitude: -180),
        ),
      ),
      searchOptions: ym.SearchOptions(
        searchType: ym.SearchType.biz,
        geometry: true,
        resultPageSize: limit,
      ),
    );
    final result = await session.$2;
    if (cancelToken?.isCancelled == true) {
      return const [];
    }
    return (result.items ?? const <ym.SearchItem>[])
        .map(_placeFromYandexItem)
        .whereType<AfficheClientGeoPlaceResult>()
        .toList(growable: false);
  }

  AfficheClientGeoPlaceResult? _placeFromYandexItem(ym.SearchItem item) {
    final point = item.geometry
            .map((geometry) => geometry.point)
            .whereType<ym.Point>()
            .firstOrNull ??
        item.toponymMetadata?.balloonPoint;
    if (point == null) {
      return null;
    }
    final name = item.businessMetadata?.shortName ??
        item.businessMetadata?.name ??
        item.name;
    final displayName = item.businessMetadata?.name ??
        item.businessMetadata?.address.formattedAddress ??
        item.toponymMetadata?.address.formattedAddress ??
        name;
    return AfficheClientGeoPlaceResult(
      latitude: point.latitude,
      longitude: point.longitude,
      name: name.trim(),
      displayName: displayName.trim(),
    );
  }
}

class AfficheClientGeoRequest {
  const AfficheClientGeoRequest({
    required this.id,
    required this.sourceCode,
    required this.sourceItemId,
    required this.city,
    required this.venueName,
    this.backendLatitude,
    this.backendLongitude,
  });

  final String id;
  final String? sourceCode;
  final String? sourceItemId;
  final String? city;
  final String? venueName;
  final double? backendLatitude;
  final double? backendLongitude;

  AfficheClientGeoRequest copyWith({
    String? id,
    String? sourceCode,
    String? sourceItemId,
    String? city,
    String? venueName,
    double? backendLatitude,
    double? backendLongitude,
  }) {
    return AfficheClientGeoRequest(
      id: id ?? this.id,
      sourceCode: sourceCode ?? this.sourceCode,
      sourceItemId: sourceItemId ?? this.sourceItemId,
      city: city ?? this.city,
      venueName: venueName ?? this.venueName,
      backendLatitude: backendLatitude ?? this.backendLatitude,
      backendLongitude: backendLongitude ?? this.backendLongitude,
    );
  }
}

class AfficheClientGeoPlaceResult {
  const AfficheClientGeoPlaceResult({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.displayName,
  });

  final double latitude;
  final double longitude;
  final String name;
  final String? displayName;
}

class AfficheClientGeoResult {
  const AfficheClientGeoResult({
    required this.latitude,
    required this.longitude,
    this.displayName,
    this.backendSaved = false,
  });

  final double latitude;
  final double longitude;
  final String? displayName;
  final bool backendSaved;
}

class AfficheClientGeoSaveRequest {
  const AfficheClientGeoSaveRequest({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.query,
    this.displayName,
    this.venueName,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String query;
  final String? displayName;
  final String? venueName;
}

class AfficheClientGeoSaveResult {
  const AfficheClientGeoSaveResult({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.saved,
    required this.code,
    this.address,
  });

  final String id;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool saved;
  final String code;
}

class AfficheClientGeoEnrichmentService {
  AfficheClientGeoEnrichmentService({
    required AfficheClientGeoPlaceSearcher searcher,
    required AfficheClientGeoBackendSaver backendSaver,
    required AppLocalCacheStore? cacheStore,
    required AppCacheUserScope userScope,
    Duration throttle = _defaultThrottle,
    DateTime Function()? clock,
  })  : _searcher = searcher,
        _backendSaver = backendSaver,
        _cacheStore = cacheStore,
        _userScope = userScope,
        _throttle = throttle,
        _clock = clock ?? DateTime.now;

  final AfficheClientGeoPlaceSearcher _searcher;
  final AfficheClientGeoBackendSaver _backendSaver;
  final AppLocalCacheStore? _cacheStore;
  final AppCacheUserScope _userScope;
  final Duration _throttle;
  final DateTime Function() _clock;
  final _memory = <String, _CacheEntry>{};
  final _inflight = <String, Future<AfficheClientGeoResult?>>{};
  Future<void> _queueTail = Future.value();
  DateTime? _lastSearchStarted;
  int _attempts = 0;

  Future<AfficheClientGeoResult?> enrich(
    AfficheClientGeoRequest request, {
    CancelToken? cancelToken,
    void Function(AfficheClientGeoResult result)? onLocalResult,
  }) {
    final backend = _backendResult(request);
    final key = cacheKeyFor(request);
    if (backend != null) {
      _memory.remove(key);
      unawaited(_cacheStore?.deleteKey(_cacheKey(key)));
      return Future.value(backend);
    }
    final existing = _inflight[key];
    if (existing != null) {
      return existing;
    }
    final future = _enrichOnce(
      request,
      key: key,
      cancelToken: cancelToken,
      onLocalResult: onLocalResult,
    );
    _inflight[key] = future;
    future.whenComplete(() => _inflight.remove(key));
    return future;
  }

  String cacheKeyFor(AfficheClientGeoRequest request) {
    final sourceCode = _cleanPart(request.sourceCode);
    final sourceItemId =
        _cleanPart(request.sourceItemId) ?? _cleanPart(request.id);
    final city = _cleanPart(request.city);
    final venue = _normalizeVenue(request.venueName);
    return 'affiche_geo:${sourceCode ?? 'unknown'}:${sourceItemId ?? request.id}:${city ?? ''}:$venue';
  }

  Future<AfficheClientGeoResult?> _enrichOnce(
    AfficheClientGeoRequest request, {
    required String key,
    CancelToken? cancelToken,
    void Function(AfficheClientGeoResult result)? onLocalResult,
  }) async {
    final cachedMemory = _memory[key];
    if (cachedMemory != null && !cachedMemory.isExpired(_clock())) {
      return cachedMemory.toResult();
    }
    final cached =
        await _cacheStore?.getFreshJson(_cacheKey(key), now: _clock());
    if (cached != null) {
      final entry = _CacheEntry.fromJson(cached);
      if (entry.status != _CacheStatus.success) {
        return null;
      }
      _memory[key] = entry;
      return entry.toResult();
    }
    if (_attempts >= _maxAttemptsPerScreen ||
        cancelToken?.isCancelled == true) {
      return null;
    }
    _attempts += 1;
    final query = _queryFor(request);
    if (query == null) {
      await _writeCache(key, _CacheEntry.negative(_clock()));
      return null;
    }
    final candidate = await _runQueued(
      () => _searchBestCandidate(request, query, cancelToken: cancelToken),
    );
    if (candidate == null || cancelToken?.isCancelled == true) {
      await _writeCache(key, _CacheEntry.negative(_clock()));
      return null;
    }
    final localResult = AfficheClientGeoResult(
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      displayName: candidate.displayName ?? candidate.name,
    );
    _memory[key] = _CacheEntry.success(_clock(), localResult);
    onLocalResult?.call(localResult);
    try {
      await _saveWithRetry(
        AfficheClientGeoSaveRequest(
          id: request.id,
          latitude: candidate.latitude,
          longitude: candidate.longitude,
          query: query,
          displayName: candidate.displayName ?? candidate.name,
          venueName: request.venueName,
        ),
        cancelToken: cancelToken,
      );
      await _writeCache(key, _CacheEntry.success(_clock(), localResult));
      return localResult;
    } on DioException catch (error) {
      if (error.response != null) {
        await _writeCache(key, _CacheEntry.backendRejected(_clock()));
      }
      return localResult;
    } catch (_) {
      return localResult;
    }
  }

  Future<AfficheClientGeoPlaceResult?> _searchBestCandidate(
    AfficheClientGeoRequest request,
    String query, {
    CancelToken? cancelToken,
  }) async {
    final results =
        await _searcher.search(query, limit: 8, cancelToken: cancelToken);
    for (final result in results) {
      if (!_validPoint(result.latitude, result.longitude)) {
        continue;
      }
      if (!_pointInCity(request.city, result.latitude, result.longitude)) {
        continue;
      }
      if (!_venueSimilar(request.venueName, result.name, result.displayName)) {
        continue;
      }
      if (_looksLikeNonVenue(result.displayName ?? result.name)) {
        continue;
      }
      return result;
    }
    return null;
  }

  Future<T> _runQueued<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    final previous = _queueTail;
    _queueTail = completer.future.then((_) {}, onError: (_) {});
    unawaited(() async {
      try {
        await previous;
        final lastStarted = _lastSearchStarted;
        if (lastStarted != null && _throttle > Duration.zero) {
          final elapsed = _clock().difference(lastStarted);
          if (elapsed < _throttle) {
            await Future<void>.delayed(_throttle - elapsed);
          }
        }
        _lastSearchStarted = _clock();
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }());
    return completer.future;
  }

  Future<AfficheClientGeoSaveResult> _saveWithRetry(
    AfficheClientGeoSaveRequest request, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _backendSaver(request, cancelToken: cancelToken);
    } on DioException catch (error) {
      if (error.response == null && cancelToken?.isCancelled != true) {
        return _backendSaver(request, cancelToken: cancelToken);
      }
      rethrow;
    }
  }

  AppCacheKey _cacheKey(String key) {
    return AppCacheKey(
      namespace: afficheClientGeoCacheNamespace,
      value: key,
      userScope: _userScope,
    );
  }

  Future<void> _writeCache(String key, _CacheEntry entry) async {
    await _cacheStore?.putJson(
      _cacheKey(key),
      entry.toJson(),
      expiresAt: entry.expiresAt,
    );
  }

  AfficheClientGeoResult? _backendResult(AfficheClientGeoRequest request) {
    if (!_validPoint(request.backendLatitude, request.backendLongitude)) {
      return null;
    }
    return AfficheClientGeoResult(
      latitude: request.backendLatitude!,
      longitude: request.backendLongitude!,
      backendSaved: true,
    );
  }

  String? _queryFor(AfficheClientGeoRequest request) {
    final city = _cleanPart(request.city);
    final venue = _cleanPart(request.venueName);
    if (city == null || venue == null) {
      return null;
    }
    return '$city, $venue';
  }

  bool _venueSimilar(String? venueName, String name, String? displayName) {
    final eventTokens = _significantTokens(venueName);
    if (eventTokens.isEmpty) {
      return false;
    }
    final candidateTokens = _significantTokens('$name ${displayName ?? ''}');
    return eventTokens.any(candidateTokens.contains);
  }

  bool _looksLikeNonVenue(String value) {
    final tokens = _normalizeVenue(value)
        .split(' ')
        .where((item) => item.isNotEmpty)
        .toSet();
    const blocked = {
      'улица',
      'ул',
      'проспект',
      'район',
      'жк',
      'метро',
      'locality',
      'площадь',
    };
    return tokens.any(blocked.contains) &&
        _significantTokens(value).length <= 1;
  }

  Set<String> _significantTokens(String? value) {
    const stopWords = {
      'театр',
      'клуб',
      'кафе',
      'ресторан',
      'дом',
      'сцена',
      'зал',
      'центр',
      'московский',
    };
    return _normalizeVenue(value)
        .split(' ')
        .where((token) => token.length > 1 && !stopWords.contains(token))
        .toSet();
  }

  String _normalizeVenue(String? value) {
    return (value ?? '')
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'["' '«»“”„`]'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _cleanPart(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool _validPoint(double? lat, double? lng) {
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  bool _pointInCity(String? city, double lat, double lng) {
    final bbox = _cityBbox(city);
    if (bbox == null) {
      return true;
    }
    return lat >= bbox.south &&
        lat <= bbox.north &&
        lng >= bbox.west &&
        lng <= bbox.east;
  }

  _CityBbox? _cityBbox(String? city) {
    return switch (city?.trim()) {
      'Москва' => const _CityBbox(55.55, 37.35, 55.95, 37.95),
      'Санкт-Петербург' => const _CityBbox(59.75, 30.05, 60.10, 30.65),
      'Казань' => const _CityBbox(55.65, 48.85, 55.95, 49.35),
      'Сочи' => const _CityBbox(43.35, 39.55, 43.75, 40.10),
      'Новосибирск' => const _CityBbox(54.80, 82.70, 55.15, 83.20),
      'Омск' => const _CityBbox(54.85, 73.15, 55.10, 73.65),
      'Калининград' => const _CityBbox(54.60, 20.35, 54.85, 20.70),
      'Ростов-на-Дону' => const _CityBbox(47.15, 39.55, 47.35, 39.90),
      'Нижний Новгород' => const _CityBbox(56.15, 43.75, 56.40, 44.20),
      'Екатеринбург' => const _CityBbox(56.70, 60.35, 56.95, 60.85),
      'Краснодар' => const _CityBbox(44.95, 38.85, 45.15, 39.20),
      _ => null,
    };
  }
}

AfficheClientGeoRequest? afficheClientGeoRequestFromCard(
    BackendCardItem event) {
  final raw = event.raw;
  final venueName = _stringOrNull(raw['venue'] ?? raw['venueName']);
  final city = _stringOrNull(raw['city']) ?? event.city;
  if (venueName == null || city == null) {
    return null;
  }
  return AfficheClientGeoRequest(
    id: event.id,
    sourceCode: _stringOrNull(raw['sourceCode']),
    sourceItemId: _stringOrNull(raw['sourceItemId']),
    city: city,
    venueName: venueName,
    backendLatitude: event.latitude,
    backendLongitude: event.longitude,
  );
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

enum _CacheStatus { success, negative, backendRejected }

class _CacheEntry {
  const _CacheEntry({
    required this.status,
    required this.expiresAt,
    this.result,
  });

  factory _CacheEntry.success(DateTime now, AfficheClientGeoResult result) {
    return _CacheEntry(
      status: _CacheStatus.success,
      expiresAt: now.add(_cacheTtl),
      result: result,
    );
  }

  factory _CacheEntry.negative(DateTime now) {
    return _CacheEntry(
      status: _CacheStatus.negative,
      expiresAt: now.add(_cacheTtl),
    );
  }

  factory _CacheEntry.backendRejected(DateTime now) {
    return _CacheEntry(
      status: _CacheStatus.backendRejected,
      expiresAt: now.add(_cacheTtl),
    );
  }

  factory _CacheEntry.fromJson(Map<String, Object?> json) {
    final status = switch (json['status']) {
      'success' => _CacheStatus.success,
      'backend_rejected' => _CacheStatus.backendRejected,
      _ => _CacheStatus.negative,
    };
    final lat = _doubleOrNull(json['lat']);
    final lng = _doubleOrNull(json['lng']);
    return _CacheEntry(
      status: status,
      expiresAt: DateTime.now().add(_cacheTtl),
      result: status == _CacheStatus.success && lat != null && lng != null
          ? AfficheClientGeoResult(
              latitude: lat,
              longitude: lng,
              displayName: json['displayName']?.toString(),
            )
          : null,
    );
  }

  final _CacheStatus status;
  final DateTime expiresAt;
  final AfficheClientGeoResult? result;

  bool isExpired(DateTime now) => expiresAt.isBefore(now);

  AfficheClientGeoResult? toResult() =>
      status == _CacheStatus.success ? result : null;

  Map<String, Object?> toJson() {
    return {
      'status': switch (status) {
        _CacheStatus.success => 'success',
        _CacheStatus.negative => 'negative',
        _CacheStatus.backendRejected => 'backend_rejected',
      },
      if (result != null) 'lat': result!.latitude,
      if (result != null) 'lng': result!.longitude,
      if (result?.displayName != null) 'displayName': result!.displayName,
    };
  }

  static double? _doubleOrNull(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}

class _CityBbox {
  const _CityBbox(this.south, this.west, this.north, this.east);

  final double south;
  final double west;
  final double north;
  final double east;
}
