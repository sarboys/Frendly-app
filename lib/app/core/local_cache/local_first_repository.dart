import 'dart:async';
import 'dart:convert';

import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_cache_store.dart';
import 'package:big_break_mobile/app/core/local_cache/local_cache_metrics.dart';

typedef LocalFirstNetworkFetch<T> = FutureOr<T> Function();
typedef LocalFirstJsonDecoder<T> = T Function(Object? json);
typedef LocalFirstJsonEncoder<T> = Object? Function(T value);

class LocalFirstResult<T> {
  const LocalFirstResult({
    required this.data,
    required this.fromCache,
    required this.isStale,
    this.refresh,
  });

  final T data;
  final bool fromCache;
  final bool isStale;
  final Future<T>? refresh;
}

class LocalFirstRepository {
  LocalFirstRepository(this._store);

  final AppLocalCacheStore _store;
  final _invalidationVersions = <String, int>{};

  Future<void> deleteKey({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
  }) async {
    _bumpInvalidationVersion(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
    );
    await _store.deleteKey(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
    );
  }

  Future<void> deleteNamespace({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
  }) async {
    _bumpInvalidationVersion(
      userScope: userScope,
      namespace: namespace,
    );
    await _store.deleteNamespace(
      userScope: userScope,
      namespace: namespace,
    );
  }

  Future<LocalFirstResult<T>> fetch<T>({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
    required AppCachePolicy policy,
    required LocalFirstNetworkFetch<T> networkFetch,
    required LocalFirstJsonDecoder<T> fromJson,
    required LocalFirstJsonEncoder<T> toJson,
    bool forceRefresh = false,
  }) async {
    final invalidationVersion = _invalidationVersion(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
    );
    if (!forceRefresh) {
      final cached = await _store.readFresh(
        userScope: userScope,
        namespace: namespace,
        cacheKey: cacheKey,
      );
      if (cached != null) {
        try {
          final data = fromJson(jsonDecode(cached.payloadJson));
          return LocalFirstResult<T>(
            data: data,
            fromCache: true,
            isStale: cached.isStale,
            refresh: _refresh(
              userScope: userScope,
              namespace: namespace,
              cacheKey: cacheKey,
              policy: policy,
              networkFetch: networkFetch,
              toJson: toJson,
              fallback: data,
              invalidationVersion: invalidationVersion,
            ),
          );
        } catch (_) {
          await _store.deleteKey(
            userScope: userScope,
            namespace: namespace,
            cacheKey: cacheKey,
          );
        }
      }
    }

    final data = await _fetchAndWrite(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
      policy: policy,
      networkFetch: networkFetch,
      toJson: toJson,
      invalidationVersion: invalidationVersion,
    );
    return LocalFirstResult<T>(
      data: data,
      fromCache: false,
      isStale: false,
    );
  }

  Future<T> _refresh<T>({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
    required AppCachePolicy policy,
    required LocalFirstNetworkFetch<T> networkFetch,
    required LocalFirstJsonEncoder<T> toJson,
    required T fallback,
    required int invalidationVersion,
  }) async {
    try {
      return await _fetchAndWrite(
        userScope: userScope,
        namespace: namespace,
        cacheKey: cacheKey,
        policy: policy,
        networkFetch: networkFetch,
        toJson: toJson,
        invalidationVersion: invalidationVersion,
      );
    } catch (_) {
      _store.metrics.increment(LocalCacheMetricNames.cacheRefreshFailure);
      return fallback;
    }
  }

  Future<T> _fetchAndWrite<T>({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
    required AppCachePolicy policy,
    required LocalFirstNetworkFetch<T> networkFetch,
    required LocalFirstJsonEncoder<T> toJson,
    required int invalidationVersion,
  }) async {
    final data = await Future<T>.sync(networkFetch);
    if (_invalidationVersion(
          userScope: userScope,
          namespace: namespace,
          cacheKey: cacheKey,
        ) !=
        invalidationVersion) {
      return data;
    }
    await _store.write(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
      payloadJson: jsonEncode(toJson(data)),
      policy: policy,
    );
    return data;
  }

  void _bumpInvalidationVersion({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    String? cacheKey,
  }) {
    final key = _invalidationKey(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
    );
    _invalidationVersions[key] = (_invalidationVersions[key] ?? 0) + 1;
  }

  int _invalidationVersion({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
  }) {
    return (_invalidationVersions[
                _invalidationKey(userScope: userScope, namespace: namespace)] ??
            0) +
        (_invalidationVersions[_invalidationKey(
              userScope: userScope,
              namespace: namespace,
              cacheKey: cacheKey,
            )] ??
            0);
  }

  String _invalidationKey({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    String? cacheKey,
  }) {
    final base = '${userScope.storageId}/${namespace.value}';
    if (cacheKey == null) {
      return base;
    }
    return '$base/$cacheKey';
  }
}
