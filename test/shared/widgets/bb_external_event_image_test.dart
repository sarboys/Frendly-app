import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('external event image uses profile based cache key and bucket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbExternalEventImage(
            imageUrl: ' https://cdn.example.com/event.jpg ',
            usage: BbExternalEventImageUsage.card,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://cdn.example.com/event.jpg');
    expect(
      image.cacheKey,
      'external-event-image-v4-card-https://cdn.example.com/event.jpg',
    );
    expect(image.memCacheWidth, 900);
    expect(image.memCacheHeight, 520);
    expect(image.maxWidthDiskCache, 900);
    expect(image.maxHeightDiskCache, 520);
    expect(image.cacheManager, same(externalEventImageCacheManager));
    expect(externalEventImageCacheManager, isA<ImageCacheManager>());
  });

  testWidgets('external event image shows fallback without url', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbExternalEventImage(
            imageUrl: ' ',
            usage: BbExternalEventImageUsage.rail,
            fallbackIconSize: 32,
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.ticket));
    expect(icon.size, 32);
  });
}
