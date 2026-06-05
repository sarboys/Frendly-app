import 'package:mobile2/shared/widgets/dateasy_image_cache.dart';

typedef AppAttachmentFetchFile = Future<void> Function(
  String url,
  String cacheKey,
);

typedef AppAttachmentCacheFile = Future<String> Function(
  String url,
  String cacheKey,
);

typedef AppAttachmentClearCachedFiles = Future<void> Function();

class SignedMediaUrl {
  const SignedMediaUrl({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final DateTime expiresAt;
}

class AppAttachmentService {
  AppAttachmentService({
    required Future<SignedMediaUrl> Function(String path) fetchSignedUrl,
    AppAttachmentFetchFile? fetchFile,
    AppAttachmentCacheFile? cacheFile,
    AppAttachmentClearCachedFiles? clearCachedFiles,
  })  : _fetchSignedUrl = fetchSignedUrl,
        _fetchFile = fetchFile ??
            ((url, cacheKey) async {
              await dateasyPrivateAttachmentCacheManager.getSingleFile(
                url,
                key: cacheKey,
              );
            }),
        _cacheFile = cacheFile ??
            ((url, cacheKey) async {
              final file =
                  await dateasyPrivateAttachmentCacheManager.getSingleFile(
                url,
                key: cacheKey,
              );
              return file.path;
            }),
        _clearCachedFiles = clearCachedFiles ??
            (() {
              return dateasyPrivateAttachmentCacheManager.emptyCache();
            });

  final Future<SignedMediaUrl> Function(String path) _fetchSignedUrl;
  final AppAttachmentFetchFile _fetchFile;
  final AppAttachmentCacheFile _cacheFile;
  final AppAttachmentClearCachedFiles _clearCachedFiles;
  final Map<String, SignedMediaUrl> _cache = {};
  final Map<String, Future<String>> _inFlight = {};

  static const _expirySafetyWindow = Duration(seconds: 60);

  Future<String> resolveSignedUrl(String path) {
    final now = DateTime.now();
    final cached = _cache[path];
    if (cached != null &&
        cached.expiresAt.isAfter(now.add(_expirySafetyWindow))) {
      return Future.value(cached.url);
    }
    final pending = _inFlight[path];
    if (pending != null) {
      return pending;
    }
    final future = _fetchSignedUrl(path).then((signed) {
      _cache[path] = signed;
      return signed.url;
    });
    _inFlight[path] = future;
    return future.whenComplete(() {
      _inFlight.remove(path);
    });
  }

  Future<void> warmCache(
    Iterable<String> paths, {
    DateasyImageUsage usage = DateasyImageUsage.card,
  }) async {
    final queue = _boundedUniquePaths(paths);
    await _runBounded(queue, (path) async {
      final url = await resolveSignedUrl(path);
      try {
        await _fetchFile(
          url,
          dateasyPrivateMediaCacheKeyFor(path, usage),
        );
      } catch (_) {
        _cache.remove(path);
      }
    });
  }

  Future<void> warmSignedUrls(Iterable<String> paths) async {
    final queue = _boundedUniquePaths(paths);
    await _runBounded(queue, (path) async {
      await resolveSignedUrl(path);
    });
  }

  Future<String> resolveCachedFilePath(String path) async {
    final url = await resolveSignedUrl(path);
    return _cacheFile(
      url,
      dateasyPrivateMediaCacheKeyFor(path, DateasyImageUsage.card),
    );
  }

  List<String> _boundedUniquePaths(Iterable<String> paths) {
    return paths.where((path) => path.isNotEmpty).toSet().take(6).toList(
          growable: false,
        );
  }

  Future<void> _runBounded(
    List<String> queue,
    Future<void> Function(String path) task,
  ) async {
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < queue.length) {
        final index = nextIndex;
        nextIndex += 1;
        await task(queue[index]);
      }
    }

    await Future.wait([
      for (var index = 0; index < 2 && index < queue.length; index += 1)
        worker(),
    ]);
  }

  Future<void> clearPrivateCache() async {
    _cache.clear();
    _inFlight.clear();
    await _clearCachedFiles();
  }
}
