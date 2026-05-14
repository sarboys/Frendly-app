import 'dart:async';
import 'dart:convert';

import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_cache_store.dart';

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
  const LocalFirstRepository(this._store);

  final AppLocalCacheStore _store;

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
    if (!forceRefresh) {
      final cached = await _store.readAny(
        userScope: userScope,
        namespace: namespace,
        cacheKey: cacheKey,
      );
      if (cached != null) {
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
          ),
        );
      }
    }

    final data = await _fetchAndWrite(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
      policy: policy,
      networkFetch: networkFetch,
      toJson: toJson,
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
  }) async {
    try {
      return await _fetchAndWrite(
        userScope: userScope,
        namespace: namespace,
        cacheKey: cacheKey,
        policy: policy,
        networkFetch: networkFetch,
        toJson: toJson,
      );
    } catch (_) {
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
  }) async {
    final data = await Future<T>.sync(networkFetch);
    await _store.write(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
      payloadJson: jsonEncode(toJson(data)),
      policy: policy,
    );
    return data;
  }
}
