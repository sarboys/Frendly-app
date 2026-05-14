import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_database.dart';
import 'package:big_break_mobile/app/core/local_cache/local_cache_metrics.dart';
import 'package:drift/drift.dart';

typedef AppLocalCacheClock = DateTime Function();

class AppLocalCacheHit {
  const AppLocalCacheHit({
    required this.payloadJson,
    required this.fetchedAt,
    required this.staleAt,
    required this.expiresAt,
    required this.isStale,
    this.etag,
    this.lastModified,
  });

  final String payloadJson;
  final DateTime fetchedAt;
  final DateTime staleAt;
  final DateTime expiresAt;
  final bool isStale;
  final String? etag;
  final String? lastModified;
}

class AppLocalCacheStore {
  AppLocalCacheStore(
    this._database, {
    AppLocalCacheClock? now,
    LocalCacheMetrics? metrics,
  })  : _now = now ?? DateTime.now,
        _metrics = metrics ?? LocalCacheMetrics();

  final AppLocalDatabase _database;
  final AppLocalCacheClock _now;
  final LocalCacheMetrics _metrics;
  final _writeQueues = <String, Future<void>>{};

  LocalCacheMetrics get metrics => _metrics;

  Future<AppLocalCacheHit?> readFresh({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
  }) async {
    return _read(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
      allowStale: false,
    );
  }

  Future<AppLocalCacheHit?> readAny({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
  }) async {
    return _read(
      userScope: userScope,
      namespace: namespace,
      cacheKey: cacheKey,
      allowStale: true,
    );
  }

  Future<void> write({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
    required String payloadJson,
    required AppCachePolicy policy,
    String? etag,
    String? lastModified,
  }) {
    final queueKey = '${userScope.storageId}/${namespace.value}/$cacheKey';
    final previous = _writeQueues[queueKey] ?? Future<void>.value();
    final current = previous.catchError((_) {}).then((_) {
      return _writeNow(
        userScope: userScope,
        namespace: namespace,
        cacheKey: cacheKey,
        payloadJson: payloadJson,
        policy: policy,
        etag: etag,
        lastModified: lastModified,
      );
    });
    late final Future<void> tracked;
    tracked = current.whenComplete(() {
      if (identical(_writeQueues[queueKey], tracked)) {
        _writeQueues.remove(queueKey);
      }
    });
    _writeQueues[queueKey] = tracked;
    return tracked;
  }

  Future<void> deleteKey({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
  }) async {
    await (_database.delete(_database.cacheEntries)
          ..where(
            (table) =>
                table.userId.equals(userScope.storageId) &
                table.namespace.equals(namespace.value) &
                table.cacheKey.equals(cacheKey),
          ))
        .go();
  }

  Future<void> deleteNamespace({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
  }) async {
    await (_database.delete(_database.cacheEntries)
          ..where(
            (table) =>
                table.userId.equals(userScope.storageId) &
                table.namespace.equals(namespace.value),
          ))
        .go();
  }

  Future<void> deleteUser(AppCacheUserScope userScope) async {
    await _database.transaction(() async {
      await (_database.delete(_database.cacheEntries)
            ..where((table) => table.userId.equals(userScope.storageId)))
          .go();
      await (_database.delete(_database.chatSummaries)
            ..where((table) => table.userId.equals(userScope.storageId)))
          .go();
      await (_database.delete(_database.chatMessages)
            ..where((table) => table.userId.equals(userScope.storageId)))
          .go();
      await (_database.delete(_database.syncCursors)
            ..where((table) => table.userId.equals(userScope.storageId)))
          .go();
      await (_database.delete(_database.pendingCommands)
            ..where((table) => table.userId.equals(userScope.storageId)))
          .go();
    });
  }

  Future<int> pruneExpired() {
    final now = _now();
    return (_database.delete(_database.cacheEntries)
          ..where((table) => table.expiresAt.isSmallerOrEqualValue(now)))
        .go();
  }

  Future<int> estimateSizeBytes({AppCacheUserScope? userScope}) async {
    var total = 0;
    total += await _sumCacheEntryBytes(userScope);
    total += await _sumChatSummaryBytes(userScope);
    total += await _sumChatMessageBytes(userScope);
    total += await _sumSyncCursorBytes(userScope);
    total += await _sumPendingCommandBytes(userScope);
    _metrics.setGauge(LocalCacheMetricNames.cacheDbSizeBytes, total);
    return total;
  }

  Future<AppLocalCacheHit?> _read({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
    required bool allowStale,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final row = await (_database.select(_database.cacheEntries)
            ..where(
              (table) =>
                  table.userId.equals(userScope.storageId) &
                  table.namespace.equals(namespace.value) &
                  table.cacheKey.equals(cacheKey),
            ))
          .getSingleOrNull();
      final now = _now();
      if (row == null || !row.expiresAt.isAfter(now)) {
        _metrics.increment(LocalCacheMetricNames.cacheMiss);
        return null;
      }

      final isStale = !row.staleAt.isAfter(now);
      if (isStale && !allowStale) {
        _metrics.increment(LocalCacheMetricNames.cacheMiss);
        return null;
      }

      _metrics.increment(
        isStale
            ? LocalCacheMetricNames.cacheStaleHit
            : LocalCacheMetricNames.cacheHit,
      );
      return AppLocalCacheHit(
        payloadJson: row.payloadJson,
        fetchedAt: row.fetchedAt,
        staleAt: row.staleAt,
        expiresAt: row.expiresAt,
        isStale: isStale,
        etag: row.etag,
        lastModified: row.lastModified,
      );
    } finally {
      stopwatch.stop();
      _metrics.recordTiming(
          LocalCacheMetricNames.cacheReadMs, stopwatch.elapsed);
    }
  }

  Future<void> _writeNow({
    required AppCacheUserScope userScope,
    required AppCacheNamespace namespace,
    required String cacheKey,
    required String payloadJson,
    required AppCachePolicy policy,
    required String? etag,
    required String? lastModified,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final fetchedAt = _now();
      await _database.into(_database.cacheEntries).insertOnConflictUpdate(
            CacheEntriesCompanion.insert(
              userId: userScope.storageId,
              namespace: namespace.value,
              cacheKey: cacheKey,
              payloadJson: payloadJson,
              fetchedAt: fetchedAt,
              staleAt: policy.staleAt(fetchedAt),
              expiresAt: policy.expiresAt(fetchedAt),
              etag: Value(etag),
              lastModified: Value(lastModified),
            ),
          );
    } finally {
      stopwatch.stop();
      _metrics.recordTiming(
          LocalCacheMetricNames.cacheWriteMs, stopwatch.elapsed);
    }
  }

  Future<int> _sumCacheEntryBytes(AppCacheUserScope? userScope) async {
    final query = _database.select(_database.cacheEntries);
    if (userScope != null) {
      query.where((table) => table.userId.equals(userScope.storageId));
    }
    final rows = await query.get();
    return rows.fold<int>(
      0,
      (total, row) =>
          total +
          _stringBytes(row.userId) +
          _stringBytes(row.namespace) +
          _stringBytes(row.cacheKey) +
          _stringBytes(row.payloadJson) +
          _stringBytes(row.etag) +
          _stringBytes(row.lastModified),
    );
  }

  Future<int> _sumChatSummaryBytes(AppCacheUserScope? userScope) async {
    final query = _database.select(_database.chatSummaries);
    if (userScope != null) {
      query.where((table) => table.userId.equals(userScope.storageId));
    }
    final rows = await query.get();
    return rows.fold<int>(
      0,
      (total, row) =>
          total +
          _stringBytes(row.userId) +
          _stringBytes(row.chatId) +
          _stringBytes(row.chatKind) +
          _stringBytes(row.summaryJson),
    );
  }

  Future<int> _sumChatMessageBytes(AppCacheUserScope? userScope) async {
    final query = _database.select(_database.chatMessages);
    if (userScope != null) {
      query.where((table) => table.userId.equals(userScope.storageId));
    }
    final rows = await query.get();
    return rows.fold<int>(
      0,
      (total, row) =>
          total +
          _stringBytes(row.userId) +
          _stringBytes(row.chatId) +
          _stringBytes(row.messageId) +
          _stringBytes(row.clientMessageId) +
          _stringBytes(row.messageJson),
    );
  }

  Future<int> _sumSyncCursorBytes(AppCacheUserScope? userScope) async {
    final query = _database.select(_database.syncCursors);
    if (userScope != null) {
      query.where((table) => table.userId.equals(userScope.storageId));
    }
    final rows = await query.get();
    return rows.fold<int>(
      0,
      (total, row) =>
          total +
          _stringBytes(row.userId) +
          _stringBytes(row.chatId) +
          _stringBytes(row.cursor),
    );
  }

  Future<int> _sumPendingCommandBytes(AppCacheUserScope? userScope) async {
    final query = _database.select(_database.pendingCommands);
    if (userScope != null) {
      query.where((table) => table.userId.equals(userScope.storageId));
    }
    final rows = await query.get();
    return rows.fold<int>(
      0,
      (total, row) =>
          total +
          _stringBytes(row.userId) +
          _stringBytes(row.commandId) +
          _stringBytes(row.chatId) +
          _stringBytes(row.commandType) +
          _stringBytes(row.payloadJson) +
          _stringBytes(row.lastError),
    );
  }

  int _stringBytes(String? value) => value == null ? 0 : value.length;
}
