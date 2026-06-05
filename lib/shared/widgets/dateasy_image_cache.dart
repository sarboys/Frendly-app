import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mobile2/shared/models/backend_url.dart';

enum DateasyImageUsage { avatar, card, hero, fullscreen }

const dateasyRemoteImageRequestTimeout = Duration(seconds: 8);

final dateasyRemoteImageCacheManager = _DateasyImageCacheManager(
  'dateasyRemoteImageCacheV4',
);

final dateasyPrivateAttachmentCacheManager = _DateasyImageCacheManager(
  'dateasyPrivateAttachmentCacheV1',
);

class _DateasyImageCacheManager extends CacheManager with ImageCacheManager {
  _DateasyImageCacheManager(String key)
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 512,
            fileService: DateasyTimeoutFileService(),
          ),
        );
}

class DateasyTimeoutFileService extends FileService {
  DateasyTimeoutFileService({
    FileService? delegate,
    Duration? timeout,
  })  : _delegate = delegate ?? HttpFileService(),
        timeout = timeout ?? dateasyRemoteImageRequestTimeout {
    concurrentFetches = _delegate.concurrentFetches;
  }

  final FileService _delegate;
  final Duration timeout;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) {
    return _delegate.get(url, headers: headers).timeout(timeout);
  }
}

String dateasyImageCacheKeyFor(String url, DateasyImageUsage usage) {
  final resolvedUrl = resolveBackendUrl(url) ?? url;
  return 'dateasy-image-v4-${usage.name}-${_stableImageUrlIdentity(resolvedUrl)}';
}

String dateasyPrivateMediaCacheKeyFor(
  String path,
  DateasyImageUsage usage,
) {
  return 'dateasy-private-media-v1-${usage.name}-$path';
}

String _stableImageUrlIdentity(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.queryParametersAll.isEmpty) {
    return url;
  }
  final stableQuery = <String, List<String>>{};
  for (final entry in uri.queryParametersAll.entries) {
    if (_isVolatileMediaQueryKey(entry.key)) {
      continue;
    }
    stableQuery[entry.key] = entry.value;
  }
  if (stableQuery.isEmpty) {
    final withoutQuery = uri.replace(query: '').toString();
    return withoutQuery.endsWith('?')
        ? withoutQuery.substring(0, withoutQuery.length - 1)
        : withoutQuery;
  }
  return uri.replace(query: _queryString(stableQuery)).toString();
}

String _queryString(Map<String, List<String>> query) {
  return query.entries
      .expand(
        (entry) => entry.value.map(
          (value) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
        ),
      )
      .join('&');
}

bool _isVolatileMediaQueryKey(String key) {
  final lower = key.toLowerCase();
  return lower == 'token' ||
      lower == 'signature' ||
      lower == 'expires' ||
      lower == 'expiresat' ||
      lower == 'policy' ||
      lower.startsWith('x-amz-') ||
      lower.startsWith('x-goog-') ||
      lower.startsWith('response-');
}
