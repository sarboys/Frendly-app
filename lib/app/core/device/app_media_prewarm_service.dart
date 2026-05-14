import 'dart:async';
import 'dart:math' as math;

import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart'
    as external_images;
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appMediaPrewarmServiceProvider = Provider<AppMediaPrewarmService>(
  (ref) => AppMediaPrewarmService(),
);

class AppMediaPrewarmService {
  AppMediaPrewarmService({
    CacheManager? profileImageCacheManager,
    CacheManager? externalEventImageCacheManager,
  })  : _profileImageCacheManager =
            profileImageCacheManager ?? DefaultCacheManager(),
        _externalEventImageCacheManager = externalEventImageCacheManager ??
            external_images.externalEventImageCacheManager;

  static const _maxRememberedKeys = 512;
  static const _maxConcurrentWarmups = 3;

  final CacheManager _profileImageCacheManager;
  final CacheManager _externalEventImageCacheManager;
  final Set<String> _rememberedKeys = <String>{};

  Future<void> warmExternalEventImages(
    Iterable<String?> urls, {
    required external_images.BbExternalEventImageUsage usage,
    int limit = 6,
    int concurrency = 2,
  }) {
    final targets = urls
        .map((url) => url?.trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .take(limit)
        .map(
          (url) => _MediaPrewarmTarget(
            url: url,
            cacheKey: external_images.BbExternalEventImage.cacheKeyFor(
              url,
              usage,
            ),
            cacheManager: _externalEventImageCacheManager,
          ),
        )
        .toList(growable: false);

    return _warmBounded(targets, concurrency: concurrency);
  }

  Future<void> warmProfileImages(
    Iterable<String?> urls, {
    required BbImageUsageProfile usageProfile,
    int limit = 4,
    int concurrency = 2,
  }) {
    final targets = urls
        .map((url) => url?.trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .take(limit)
        .map(
          (url) => _MediaPrewarmTarget(
            url: url,
            cacheKey: BbProfilePhotoImage.cacheKeyFor(url, usageProfile),
            cacheManager: _profileImageCacheManager,
          ),
        )
        .toList(growable: false);

    return _warmBounded(targets, concurrency: concurrency);
  }

  Future<void> _warmBounded(
    List<_MediaPrewarmTarget> targets, {
    required int concurrency,
  }) async {
    final pending = targets.where(_markStarted).toList(growable: false);
    if (pending.isEmpty) {
      return;
    }

    var next = 0;
    final requestedWorkers = math.min(
      math.max(1, concurrency),
      _maxConcurrentWarmups,
    );
    final workerCount = math.min(requestedWorkers, pending.length);
    await Future.wait(
      List.generate(workerCount, (_) async {
        while (next < pending.length) {
          final target = pending[next];
          next += 1;
          try {
            await target.cacheManager.getSingleFile(
              target.url,
              key: target.cacheKey,
            );
          } catch (_) {}
        }
      }),
    );
  }

  bool _markStarted(_MediaPrewarmTarget target) {
    if (_rememberedKeys.contains(target.cacheKey)) {
      return false;
    }
    if (_rememberedKeys.length >= _maxRememberedKeys) {
      _rememberedKeys.clear();
    }
    _rememberedKeys.add(target.cacheKey);
    return true;
  }
}

class _MediaPrewarmTarget {
  const _MediaPrewarmTarget({
    required this.url,
    required this.cacheKey,
    required this.cacheManager,
  });

  final String url;
  final String cacheKey;
  final CacheManager cacheManager;
}
