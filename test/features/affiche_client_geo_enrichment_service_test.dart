import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/local_cache/app_cache_key.dart';
import 'package:mobile2/app/core/local_cache/app_local_cache_store.dart';
import 'package:mobile2/app/core/local_cache/app_local_database.dart';
import 'package:mobile2/shared/data/affiche_client_geo_enrichment_service.dart';

void main() {
  late AppLocalDatabase database;
  late AppLocalCacheStore cacheStore;
  late _FakeSearcher searcher;
  late _FakeBackend backend;
  late AfficheClientGeoEnrichmentService service;

  const request = AfficheClientGeoRequest(
    id: 'affiche-1',
    sourceCode: 'advcake_ticketland',
    sourceItemId: 'ticketland-1',
    city: 'Москва',
    venueName: 'Клуб 16 тонн',
  );

  setUp(() {
    database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    cacheStore = AppLocalCacheStore(database);
    searcher = _FakeSearcher([
      const AfficheClientGeoPlaceResult(
        latitude: 55.763,
        longitude: 37.564,
        name: 'Клуб 16 тонн',
        displayName: 'Клуб 16 тонн',
      ),
    ]);
    backend = _FakeBackend();
    service = AfficheClientGeoEnrichmentService(
      searcher: searcher,
      backendSaver: backend.save,
      cacheStore: cacheStore,
      userScope: AppCacheUserScope.user('u1'),
      throttle: Duration.zero,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('uses memory cache before search', () async {
    final first = await service.enrich(request);
    final second = await service.enrich(request);

    expect(first?.latitude, 55.763);
    expect(second?.longitude, 37.564);
    expect(searcher.calls, 1);
  });

  test('uses persistent success cache', () async {
    await cacheStore.putJson(
      AppCacheKey(
        namespace: afficheClientGeoCacheNamespace,
        value: service.cacheKeyFor(request),
        userScope: AppCacheUserScope.user('u1'),
      ),
      {
        'status': 'success',
        'lat': 55.763,
        'lng': 37.564,
        'displayName': 'Клуб 16 тонн',
      },
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );

    final result = await service.enrich(request);

    expect(result?.latitude, 55.763);
    expect(searcher.calls, 0);
  });

  test('respects negative cache', () async {
    await cacheStore.putJson(
      AppCacheKey(
        namespace: afficheClientGeoCacheNamespace,
        value: service.cacheKeyFor(request),
        userScope: AppCacheUserScope.user('u1'),
      ),
      {'status': 'negative'},
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );

    final result = await service.enrich(request);

    expect(result, isNull);
    expect(searcher.calls, 0);
  });

  test('deduplicates inflight requests', () async {
    final completer = Completer<List<AfficheClientGeoPlaceResult>>();
    searcher.pending = completer;

    final first = service.enrich(request);
    final second = service.enrich(request);
    completer.complete([
      const AfficheClientGeoPlaceResult(
        latitude: 55.763,
        longitude: 37.564,
        name: 'Клуб 16 тонн',
        displayName: 'Клуб 16 тонн',
      ),
    ]);

    expect(await first, same(await second));
    expect(searcher.calls, 1);
  });

  test('runs queue with concurrency 1 and throttle', () async {
    service = AfficheClientGeoEnrichmentService(
      searcher: searcher,
      backendSaver: backend.save,
      cacheStore: cacheStore,
      userScope: AppCacheUserScope.user('u1'),
      throttle: const Duration(milliseconds: 20),
    );

    await Future.wait([
      service.enrich(request),
      service.enrich(
        request.copyWith(
          id: 'affiche-2',
          sourceItemId: 'ticketland-2',
          venueName: 'Клуб 16 тонн',
        ),
      ),
    ]);

    expect(searcher.maxConcurrent, 1);
    expect(
      searcher.startedAt[1].difference(searcher.startedAt[0]),
      greaterThanOrEqualTo(const Duration(milliseconds: 18)),
    );
  });

  test('backend coordinates override local cache', () async {
    await cacheStore.putJson(
      AppCacheKey(
        namespace: afficheClientGeoCacheNamespace,
        value: service.cacheKeyFor(request),
        userScope: AppCacheUserScope.user('u1'),
      ),
      {
        'status': 'success',
        'lat': 55.763,
        'lng': 37.564,
      },
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );

    final result = await service.enrich(
      request.copyWith(
        backendLatitude: 55.7,
        backendLongitude: 37.5,
      ),
    );

    expect(result?.latitude, 55.7);
    expect(searcher.calls, 0);
    final cached = await cacheStore.getJson(
      AppCacheKey(
        namespace: afficheClientGeoCacheNamespace,
        value: service.cacheKeyFor(request),
        userScope: AppCacheUserScope.user('u1'),
      ),
    );
    expect(cached, isNull);
  });

  test('does not persist success cache when backend rejects', () async {
    backend.reject = true;

    final result = await service.enrich(request);

    expect(result?.latitude, 55.763);
    final cached = await cacheStore.getFreshJson(
      AppCacheKey(
        namespace: afficheClientGeoCacheNamespace,
        value: service.cacheKeyFor(request),
        userScope: AppCacheUserScope.user('u1'),
      ),
      now: DateTime.now(),
    );
    expect(cached?['status'], 'backend_rejected');
  });

  test('rejects candidates outside city bbox', () async {
    searcher.results = [
      const AfficheClientGeoPlaceResult(
        latitude: 59.93,
        longitude: 30.33,
        name: 'Клуб 16 тонн',
        displayName: 'Клуб 16 тонн',
      ),
    ];

    final result = await service.enrich(request);

    expect(result, isNull);
    expect(backend.calls, 0);
  });
}

class _FakeSearcher implements AfficheClientGeoPlaceSearcher {
  _FakeSearcher(this.results);

  List<AfficheClientGeoPlaceResult> results;
  Completer<List<AfficheClientGeoPlaceResult>>? pending;
  int calls = 0;
  int _active = 0;
  int maxConcurrent = 0;
  final startedAt = <DateTime>[];

  @override
  Future<List<AfficheClientGeoPlaceResult>> search(
    String query, {
    int limit = 8,
    CancelToken? cancelToken,
  }) async {
    calls += 1;
    _active += 1;
    maxConcurrent = maxConcurrent < _active ? _active : maxConcurrent;
    startedAt.add(DateTime.now());
    try {
      if (pending != null) {
        return await pending!.future;
      }
      return results;
    } finally {
      _active -= 1;
    }
  }
}

class _FakeBackend {
  bool reject = false;
  int calls = 0;

  Future<AfficheClientGeoSaveResult> save(
    AfficheClientGeoSaveRequest request, {
    CancelToken? cancelToken,
  }) async {
    calls += 1;
    if (reject) {
      throw DioException(
        requestOptions: RequestOptions(path: '/affiche/events/client-geo'),
        response: Response(
          requestOptions: RequestOptions(path: '/affiche/events/client-geo'),
          statusCode: 400,
          data: {'code': 'client_geo_venue_mismatch'},
        ),
      );
    }
    return AfficheClientGeoSaveResult(
      id: request.id,
      latitude: request.latitude,
      longitude: request.longitude,
      address: request.displayName,
      saved: true,
      code: 'saved',
    );
  }
}
