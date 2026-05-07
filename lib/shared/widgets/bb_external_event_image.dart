import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

enum BbExternalEventImageUsage {
  rail,
  card,
  hero,
}

final externalEventImageCacheManager = CacheManager(
  Config(
    'externalEventImageCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 512,
  ),
);

class BbExternalEventImage extends StatelessWidget {
  const BbExternalEventImage({
    required this.imageUrl,
    required this.usage,
    super.key,
    this.fit = BoxFit.cover,
    this.fallbackIconSize,
  });

  final String? imageUrl;
  final BbExternalEventImageUsage usage;
  final BoxFit fit;
  final double? fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _ExternalEventImageFallback(size: fallbackIconSize);
    }

    final bucket = _bucketForUsage(usage);
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKeyFor(url, usage),
      cacheManager: externalEventImageCacheManager,
      fit: fit,
      memCacheWidth: bucket.width,
      memCacheHeight: bucket.height,
      maxWidthDiskCache: bucket.width,
      maxHeightDiskCache: bucket.height,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => _ExternalEventImageFallback(
        size: fallbackIconSize,
      ),
      errorWidget: (_, __, ___) => _ExternalEventImageFallback(
        size: fallbackIconSize,
      ),
    );
  }

  static String cacheKeyFor(String url, BbExternalEventImageUsage usage) {
    return 'external-event-image-${usage.name}-$url';
  }
}

_ImageBucket _bucketForUsage(BbExternalEventImageUsage usage) {
  switch (usage) {
    case BbExternalEventImageUsage.rail:
      return const _ImageBucket(width: 560, height: 320);
    case BbExternalEventImageUsage.card:
      return const _ImageBucket(width: 900, height: 520);
    case BbExternalEventImageUsage.hero:
      return const _ImageBucket(width: 1400, height: 900);
  }
}

class _ImageBucket {
  const _ImageBucket({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

class _ExternalEventImageFallback extends StatelessWidget {
  const _ExternalEventImageFallback({this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.secondarySoft,
      child: Center(
        child: Icon(
          LucideIcons.ticket,
          color: colors.inkMute,
          size: size ?? 40,
        ),
      ),
    );
  }
}
