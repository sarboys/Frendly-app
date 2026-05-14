class LocalCacheMetricNames {
  const LocalCacheMetricNames._();

  static const cacheHit = 'cache_hit';
  static const cacheMiss = 'cache_miss';
  static const cacheStaleHit = 'cache_stale_hit';
  static const cacheWriteMs = 'cache_write_ms';
  static const cacheReadMs = 'cache_read_ms';
  static const cacheRefreshFailure = 'cache_refresh_failure';
  static const cacheDbSizeBytes = 'cache_db_size_bytes';
}

class LocalCacheMetrics {
  final _counts = <String, int>{};
  final _timings = <String, List<Duration>>{};
  final _gauges = <String, num>{};

  void increment(String name) {
    _counts[name] = (_counts[name] ?? 0) + 1;
  }

  void recordTiming(String name, Duration duration) {
    (_timings[name] ??= <Duration>[]).add(duration);
  }

  void setGauge(String name, num value) {
    _gauges[name] = value;
  }

  int count(String name) => _counts[name] ?? 0;

  num? gauge(String name) => _gauges[name];

  List<Duration> timings(String name) =>
      List<Duration>.unmodifiable(_timings[name] ?? const <Duration>[]);

  double? p95Ms(String name) {
    final values = _timings[name];
    if (values == null || values.isEmpty) {
      return null;
    }
    final sorted = values.map((value) => value.inMicroseconds / 1000).toList()
      ..sort();
    final index = ((sorted.length - 1) * 0.95).ceil();
    return sorted[index];
  }
}
