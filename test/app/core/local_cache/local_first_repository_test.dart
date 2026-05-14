import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_cache_store.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_database.dart';
import 'package:big_break_mobile/app/core/local_cache/local_first_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalDatabase db;
  late DateTime now;
  late AppLocalCacheStore store;
  late LocalFirstRepository repository;

  const policy = AppCachePolicy(
    staleAfter: Duration(minutes: 2),
    expiresAfter: Duration(minutes: 10),
  );
  final user = AppCacheUserScope.user('user-a');

  setUp(() {
    db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    now = DateTime.utc(2026, 5, 14, 10);
    store = AppLocalCacheStore(db, now: () => now);
    repository = LocalFirstRepository(store);
  });

  tearDown(() async {
    await db.close();
  });

  test('returns cached data immediately and refreshes in background', () async {
    await store.write(
      userScope: user,
      namespace: AppCacheNamespace.tonight,
      cacheKey: 'home',
      payloadJson: '{"value":"cached"}',
      policy: policy,
    );

    final result = await repository.fetch<Map<String, dynamic>>(
      userScope: user,
      namespace: AppCacheNamespace.tonight,
      cacheKey: 'home',
      policy: policy,
      networkFetch: () async => {'value': 'network'},
      fromJson: (json) => Map<String, dynamic>.from(json as Map),
      toJson: (value) => value,
    );

    expect(result.data, {'value': 'cached'});
    expect(result.fromCache, isTrue);
    expect(await result.refresh, {'value': 'network'});

    final cached = await store.readAny(
      userScope: user,
      namespace: AppCacheNamespace.tonight,
      cacheKey: 'home',
    );
    expect(cached?.payloadJson, '{"value":"network"}');
  });

  test('keeps cached data when background refresh fails', () async {
    await store.write(
      userScope: user,
      namespace: AppCacheNamespace.chatList,
      cacheKey: 'meetup',
      payloadJson: '{"items":["cached"]}',
      policy: policy,
    );

    final result = await repository.fetch<Map<String, dynamic>>(
      userScope: user,
      namespace: AppCacheNamespace.chatList,
      cacheKey: 'meetup',
      policy: policy,
      networkFetch: () => throw StateError('offline'),
      fromJson: (json) => Map<String, dynamic>.from(json as Map),
      toJson: (value) => value,
    );

    expect(result.data, {
      'items': ['cached']
    });
    expect(await result.refresh, {
      'items': ['cached']
    });
  });

  test('preserves network error when cache is empty', () async {
    await expectLater(
      repository.fetch<Map<String, dynamic>>(
        userScope: user,
        namespace: AppCacheNamespace.map,
        cacheKey: 'viewport',
        policy: policy,
        networkFetch: () => throw StateError('offline'),
        fromJson: (json) => Map<String, dynamic>.from(json as Map),
        toJson: (value) => value,
      ),
      throwsStateError,
    );
  });

  test('forceRefresh skips cache and writes network response', () async {
    await store.write(
      userScope: user,
      namespace: AppCacheNamespace.profile,
      cacheKey: 'me',
      payloadJson: '{"name":"cached"}',
      policy: policy,
    );

    final result = await repository.fetch<Map<String, dynamic>>(
      userScope: user,
      namespace: AppCacheNamespace.profile,
      cacheKey: 'me',
      policy: policy,
      forceRefresh: true,
      networkFetch: () async => {'name': 'network'},
      fromJson: (json) => Map<String, dynamic>.from(json as Map),
      toJson: (value) => value,
    );

    expect(result.data, {'name': 'network'});
    expect(result.fromCache, isFalse);
    expect(result.refresh, isNull);
  });
}
