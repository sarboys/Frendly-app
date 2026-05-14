import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_cache_store.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_database.dart';
import 'package:big_break_mobile/app/core/local_cache/local_cache_metrics.dart';
import 'package:big_break_mobile/app/core/local_cache/local_first_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalDatabase db;
  late DateTime now;
  late LocalCacheMetrics metrics;
  late AppLocalCacheStore store;

  const policy = AppCachePolicy(
    staleAfter: Duration(minutes: 2),
    expiresAfter: Duration(minutes: 10),
  );
  final userA = AppCacheUserScope.user('user-a');
  final userB = AppCacheUserScope.user('user-b');

  setUp(() {
    db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    now = DateTime.utc(2026, 5, 14, 10);
    metrics = LocalCacheMetrics();
    store = AppLocalCacheStore(
      db,
      now: () => now,
      metrics: metrics,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('readFresh returns a non stale cache hit', () async {
    await store.write(
      userScope: userA,
      namespace: AppCacheNamespace.tonight,
      cacheKey: 'home',
      payloadJson: '{"items":[1]}',
      policy: policy,
    );

    final hit = await store.readFresh(
      userScope: userA,
      namespace: AppCacheNamespace.tonight,
      cacheKey: 'home',
    );

    expect(hit?.payloadJson, '{"items":[1]}');
    expect(hit?.isStale, isFalse);
    expect(metrics.count(LocalCacheMetricNames.cacheHit), 1);
    expect(metrics.timings(LocalCacheMetricNames.cacheReadMs), isNotEmpty);
    expect(metrics.timings(LocalCacheMetricNames.cacheWriteMs), isNotEmpty);
  });

  test('readAny returns stale data before expiry', () async {
    await store.write(
      userScope: userA,
      namespace: AppCacheNamespace.chatList,
      cacheKey: 'meetup',
      payloadJson: '{"items":[1]}',
      policy: policy,
    );
    now = now.add(const Duration(minutes: 3));

    final hit = await store.readAny(
      userScope: userA,
      namespace: AppCacheNamespace.chatList,
      cacheKey: 'meetup',
    );

    expect(hit?.payloadJson, '{"items":[1]}');
    expect(hit?.isStale, isTrue);
    expect(metrics.count(LocalCacheMetricNames.cacheStaleHit), 1);
  });

  test('readFresh and readAny return miss after expiry', () async {
    await store.write(
      userScope: userA,
      namespace: AppCacheNamespace.map,
      cacheKey: 'viewport',
      payloadJson: '{"items":[1]}',
      policy: policy,
    );
    now = now.add(const Duration(minutes: 11));

    expect(
      await store.readFresh(
        userScope: userA,
        namespace: AppCacheNamespace.map,
        cacheKey: 'viewport',
      ),
      isNull,
    );
    expect(
      await store.readAny(
        userScope: userA,
        namespace: AppCacheNamespace.map,
        cacheKey: 'viewport',
      ),
      isNull,
    );
    expect(metrics.count(LocalCacheMetricNames.cacheMiss), 2);
  });

  test('same namespace and key are isolated by user scope', () async {
    await store.write(
      userScope: userA,
      namespace: AppCacheNamespace.profile,
      cacheKey: 'me',
      payloadJson: '{"name":"A"}',
      policy: policy,
    );
    await store.write(
      userScope: userB,
      namespace: AppCacheNamespace.profile,
      cacheKey: 'me',
      payloadJson: '{"name":"B"}',
      policy: policy,
    );

    final a = await store.readAny(
      userScope: userA,
      namespace: AppCacheNamespace.profile,
      cacheKey: 'me',
    );
    final b = await store.readAny(
      userScope: userB,
      namespace: AppCacheNamespace.profile,
      cacheKey: 'me',
    );

    expect(a?.payloadJson, '{"name":"A"}');
    expect(b?.payloadJson, '{"name":"B"}');
  });

  test('delete and prune operations remove only requested entries', () async {
    const freshPolicy = AppCachePolicy(
      staleAfter: Duration(minutes: 2),
      expiresAfter: Duration(minutes: 30),
    );
    await store.write(
      userScope: userA,
      namespace: AppCacheNamespace.affiche,
      cacheKey: 'fresh',
      payloadJson: '{"id":"fresh"}',
      policy: freshPolicy,
    );
    await store.write(
      userScope: userA,
      namespace: AppCacheNamespace.affiche,
      cacheKey: 'expired',
      payloadJson: '{"id":"expired"}',
      policy: policy,
    );

    now = now.add(const Duration(minutes: 11));
    await store.pruneExpired();

    expect(
      await store.readAny(
        userScope: userA,
        namespace: AppCacheNamespace.affiche,
        cacheKey: 'expired',
      ),
      isNull,
    );

    now = DateTime.utc(2026, 5, 14, 10, 1);
    expect(
      await store.readAny(
        userScope: userA,
        namespace: AppCacheNamespace.affiche,
        cacheKey: 'fresh',
      ),
      isNotNull,
    );

    await store.deleteNamespace(
      userScope: userA,
      namespace: AppCacheNamespace.affiche,
    );

    expect(
      await store.readAny(
        userScope: userA,
        namespace: AppCacheNamespace.affiche,
        cacheKey: 'fresh',
      ),
      isNull,
    );
  });

  test('tracks refresh failures, DB read p95 and estimated DB size', () async {
    final repository = LocalFirstRepository(store);
    await store.write(
      userScope: userA,
      namespace: AppCacheNamespace.tonight,
      cacheKey: 'home',
      payloadJson: '{"items":["cached"]}',
      policy: policy,
    );

    final result = await repository.fetch<Map<String, dynamic>>(
      userScope: userA,
      namespace: AppCacheNamespace.tonight,
      cacheKey: 'home',
      policy: policy,
      networkFetch: () => throw StateError('offline'),
      fromJson: (json) => Map<String, dynamic>.from(json as Map),
      toJson: (value) => value,
    );
    await result.refresh;

    expect(metrics.count(LocalCacheMetricNames.cacheRefreshFailure), 1);
    expect(metrics.p95Ms(LocalCacheMetricNames.cacheReadMs), isNonNegative);
    final sizeBytes = await store.estimateSizeBytes(userScope: userA);
    expect(sizeBytes, greaterThan(0));
    expect(metrics.gauge(LocalCacheMetricNames.cacheDbSizeBytes), sizeBytes);
  });
}
