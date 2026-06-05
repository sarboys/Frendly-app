import 'dart:async';
import 'dart:convert';

import 'package:mobile2/app/core/local_cache/app_cache_key.dart';
import 'package:mobile2/app/core/local_cache/app_local_cache_store.dart';

enum LocalCacheReadPolicy {
  freshOnly,
  staleWhileRefresh,
  sensitiveFreshOnly,
}

class LocalFirstRepository {
  LocalFirstRepository(
    this._store, {
    void Function(Object error, StackTrace stackTrace)? onCacheFailure,
    bool Function(Object error)? isExpectedCancellation,
  })  : _onCacheFailure = onCacheFailure,
        _isExpectedCancellation = isExpectedCancellation;

  final AppLocalCacheStore _store;
  final void Function(Object error, StackTrace stackTrace)? _onCacheFailure;
  final bool Function(Object error)? _isExpectedCancellation;
  final Map<String, Future<void>> _refreshes = <String, Future<void>>{};

  Future<T> fetch<T>({
    required AppCacheKey key,
    required Duration ttl,
    required Future<Map<String, Object?>> Function() network,
    required T Function(Map<String, Object?> json) decode,
    LocalCacheReadPolicy policy = LocalCacheReadPolicy.staleWhileRefresh,
    bool forceRefresh = false,
    bool Function(Map<String, Object?> json)? useCached,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh) {
      final cached = await _readFreshJson(key, now: now);
      if (cached != null && _shouldUseCached(cached, useCached)) {
        unawaited(_refreshInBackground(
          key: key,
          ttl: ttl,
          network: network,
        ));
        return decode(cached);
      }
      if (policy == LocalCacheReadPolicy.staleWhileRefresh) {
        final stale = await _readJson(key);
        if (stale != null && _shouldUseCached(stale, useCached)) {
          unawaited(_refreshInBackground(
            key: key,
            ttl: ttl,
            network: network,
          ));
          return decode(stale);
        }
      }
    }
    final fresh = await network();
    await _writeJson(key, fresh, expiresAt: DateTime.now().add(ttl));
    return decode(fresh);
  }

  Stream<T> watch<T>({
    required AppCacheKey key,
    required Duration ttl,
    required Future<Map<String, Object?>> Function() network,
    required T Function(Map<String, Object?> json) decode,
    LocalCacheReadPolicy policy = LocalCacheReadPolicy.staleWhileRefresh,
    bool forceRefresh = false,
    bool Function(Map<String, Object?> json)? useCached,
  }) async* {
    String? lastJson;

    if (!forceRefresh) {
      final fresh = await _readFreshJson(key, now: DateTime.now());
      final cached = fresh ??
          (policy == LocalCacheReadPolicy.staleWhileRefresh
              ? await _readJson(key)
              : null);
      if (cached != null && _shouldUseCached(cached, useCached)) {
        lastJson = jsonEncode(cached);
        yield decode(cached);
        unawaited(_refreshInBackground(
          key: key,
          ttl: ttl,
          network: network,
        ));
      }
    }

    if (lastJson == null) {
      final Map<String, Object?> fresh;
      try {
        fresh = await network();
      } catch (error, stackTrace) {
        if (_isExpectedCancellation?.call(error) ?? false) {
          return;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      lastJson = jsonEncode(fresh);
      await _writeJson(
        key,
        fresh,
        expiresAt: DateTime.now().add(ttl),
      );
      yield decode(fresh);
    }

    try {
      await for (final json in _store.watchJson(key)) {
        if (json == null) {
          continue;
        }
        final encoded = jsonEncode(json);
        if (encoded == lastJson) {
          continue;
        }
        lastJson = encoded;
        yield decode(json);
      }
    } catch (error, stackTrace) {
      _onCacheFailure?.call(error, stackTrace);
    }
  }

  bool _shouldUseCached(
    Map<String, Object?> json,
    bool Function(Map<String, Object?> json)? useCached,
  ) {
    return useCached == null || useCached(json);
  }

  Future<void> _refreshInBackground({
    required AppCacheKey key,
    required Duration ttl,
    required Future<Map<String, Object?>> Function() network,
  }) {
    final refreshKey = _refreshKey(key);
    final existing = _refreshes[refreshKey];
    if (existing != null) {
      return existing;
    }
    final refresh = _runRefresh(key: key, ttl: ttl, network: network);
    _refreshes[refreshKey] = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshes[refreshKey], refresh)) {
        _refreshes.remove(refreshKey);
      }
    });
  }

  Future<void> _runRefresh({
    required AppCacheKey key,
    required Duration ttl,
    required Future<Map<String, Object?>> Function() network,
  }) async {
    try {
      final fresh = await network();
      await _writeJson(
        key,
        fresh,
        expiresAt: DateTime.now().add(ttl),
      );
    } catch (_) {}
  }

  String _refreshKey(AppCacheKey key) {
    return '${key.userScope.value}/${key.namespace}/${key.value}';
  }

  Future<Map<String, Object?>?> _readFreshJson(
    AppCacheKey key, {
    required DateTime now,
  }) async {
    try {
      return await _store.getFreshJson(key, now: now);
    } catch (error, stackTrace) {
      _onCacheFailure?.call(error, stackTrace);
      return null;
    }
  }

  Future<Map<String, Object?>?> _readJson(AppCacheKey key) async {
    try {
      return await _store.getJson(key);
    } catch (error, stackTrace) {
      _onCacheFailure?.call(error, stackTrace);
      return null;
    }
  }

  Future<void> _writeJson(
    AppCacheKey key,
    Map<String, Object?> json, {
    required DateTime expiresAt,
  }) async {
    try {
      await _store.putJson(key, json, expiresAt: expiresAt);
    } catch (error, stackTrace) {
      _onCacheFailure?.call(error, stackTrace);
    }
  }
}
