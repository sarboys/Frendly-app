class LocalCacheMetricNames {
  const LocalCacheMetricNames._();

  static const cacheHit = 'cache_hit';
  static const cacheMiss = 'cache_miss';
  static const cacheStaleHit = 'cache_stale_hit';
  static const cacheWriteMs = 'cache_write_ms';
  static const cacheReadMs = 'cache_read_ms';
}

class LocalCacheMetrics {
  final _counts = <String, int>{};
  final _timings = <String, List<Duration>>{};

  void increment(String name) {
    _counts[name] = (_counts[name] ?? 0) + 1;
  }

  void recordTiming(String name, Duration duration) {
    (_timings[name] ??= <Duration>[]).add(duration);
  }

  int count(String name) => _counts[name] ?? 0;

  List<Duration> timings(String name) =>
      List<Duration>.unmodifiable(_timings[name] ?? const <Duration>[]);
}
