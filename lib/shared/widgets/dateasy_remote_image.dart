import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mobile2/shared/widgets/dateasy_image_cache.dart';
import 'package:mobile2/shared/models/backend_url.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';

export 'package:mobile2/shared/widgets/dateasy_image_cache.dart'
    show
        DateasyImageUsage,
        dateasyPrivateAttachmentCacheManager,
        dateasyRemoteImageCacheManager;

class DateasyRemoteImage extends StatefulWidget {
  const DateasyRemoteImage({
    required this.imageUrl,
    required this.usage,
    this.fit = BoxFit.cover,
    this.imageVariants,
    this.cacheKey,
    this.cacheManager,
    super.key,
  });

  final String? imageUrl;
  final DateasyImageUsage usage;
  final BoxFit fit;
  final Object? imageVariants;
  final String? cacheKey;
  final BaseCacheManager? cacheManager;

  static String cacheKeyFor(String url, DateasyImageUsage usage) {
    return dateasyImageCacheKeyFor(url, usage);
  }

  static String privateCacheKeyFor(String path, DateasyImageUsage usage) {
    return dateasyPrivateMediaCacheKeyFor(path, usage);
  }

  static String? resolveImageUrl(String? raw) {
    return resolveBackendUrl(raw);
  }

  static String? resolveVariantImageUrl({
    required String? imageUrl,
    required Object? imageVariants,
    required DateasyImageUsage usage,
  }) {
    final candidates = resolveImageUrlCandidates(
      imageUrl: imageUrl,
      imageVariants: imageVariants,
      usage: usage,
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  static List<String> resolveImageUrlCandidates({
    required String? imageUrl,
    required Object? imageVariants,
    required DateasyImageUsage usage,
  }) {
    final variants = _variantMap(imageVariants);
    final urls = <String>[];
    final seen = <String>{};
    void addCandidate(Object? raw) {
      final url = resolveBackendUrl(_stringOrNull(raw));
      if (url != null && url.isNotEmpty && seen.add(url)) {
        urls.add(url);
      }
    }

    for (final key in _variantPreference(usage)) {
      final variant = _variantMap(variants[key]);
      addCandidate(variant['url']);
      addCandidate(variant['downloadUrl']);
    }
    addCandidate(imageUrl);
    return urls;
  }

  @override
  State<DateasyRemoteImage> createState() => _DateasyRemoteImageState();
}

class _DateasyRemoteImageState extends State<DateasyRemoteImage> {
  static const int _maxRetryCount = 2;

  int _candidateIndex = 0;
  int _retryCount = 0;

  @override
  void didUpdateWidget(DateasyRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageVariants != widget.imageVariants ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.usage != widget.usage) {
      _candidateIndex = 0;
      _retryCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = DateasyRemoteImage.resolveImageUrlCandidates(
      imageUrl: widget.imageUrl,
      imageVariants: widget.imageVariants,
      usage: widget.usage,
    );
    if (candidates.isEmpty) {
      return _DateasyImageFallback(usage: widget.usage);
    }
    final candidateIndex =
        _candidateIndex < candidates.length ? _candidateIndex : 0;
    final url = candidates[candidateIndex];
    final size = switch (widget.usage) {
      DateasyImageUsage.avatar => 96,
      DateasyImageUsage.card => 720,
      DateasyImageUsage.hero => 1080,
      DateasyImageUsage.fullscreen => 1440,
    };
    final baseCacheKey = _baseCacheKeyFor(url, candidateIndex);
    final effectiveCacheKey =
        _retryCount == 0 ? baseCacheKey : '$baseCacheKey-retry-$_retryCount';
    final cacheManager = widget.cacheManager ?? dateasyRemoteImageCacheManager;
    final supportsDiskResize = cacheManager is ImageCacheManager;
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: effectiveCacheKey,
      cacheManager: cacheManager,
      fit: widget.fit,
      memCacheWidth: size,
      memCacheHeight: size,
      maxWidthDiskCache: supportsDiskResize ? size : null,
      maxHeightDiskCache: supportsDiskResize ? size : null,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => const ColoredBox(color: DateasyColors.glass),
      errorListener: (error) =>
          _handleImageError(cacheManager, effectiveCacheKey, candidates.length),
      errorWidget: (_, __, ___) => _DateasyImageFallback(usage: widget.usage),
    );
  }

  String _baseCacheKeyFor(String url, int candidateIndex) {
    final configuredCacheKey = widget.cacheKey;
    if (configuredCacheKey == null) {
      return DateasyRemoteImage.cacheKeyFor(url, widget.usage);
    }
    if (candidateIndex == 0) {
      return configuredCacheKey;
    }
    return '$configuredCacheKey-candidate-$candidateIndex';
  }

  void _handleImageError(
    BaseCacheManager cacheManager,
    String cacheKey,
    int candidateCount,
  ) {
    unawaited(
      cacheManager.removeFile(cacheKey).catchError((_) {}),
    );
    if (!mounted) {
      return;
    }
    if (_candidateIndex < candidateCount - 1) {
      setState(() {
        _candidateIndex += 1;
        _retryCount = 0;
      });
      return;
    }
    if (_retryCount >= _maxRetryCount) {
      return;
    }
    setState(() {
      _retryCount += 1;
    });
  }
}

class _DateasyImageFallback extends StatelessWidget {
  const _DateasyImageFallback({required this.usage});

  final DateasyImageUsage usage;

  @override
  Widget build(BuildContext context) {
    final icon = usage == DateasyImageUsage.avatar
        ? Icons.person
        : Icons.broken_image_outlined;
    final size = usage == DateasyImageUsage.avatar ? 24.0 : 28.0;
    return ColoredBox(
      color: DateasyColors.glass,
      child: Center(
        child: Icon(
          icon,
          size: size,
          color: DateasyColors.muted,
        ),
      ),
    );
  }
}

List<String> _variantPreference(DateasyImageUsage usage) {
  return switch (usage) {
    DateasyImageUsage.avatar => const ['avatar', 'thumb', 'card'],
    DateasyImageUsage.card => const ['card', 'thumb', 'hero'],
    DateasyImageUsage.hero => const ['hero', 'card', 'fullscreen'],
    DateasyImageUsage.fullscreen => const ['fullscreen', 'hero', 'card'],
  };
}

Map<String, Object?> _variantMap(Object? raw) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
  return const {};
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
