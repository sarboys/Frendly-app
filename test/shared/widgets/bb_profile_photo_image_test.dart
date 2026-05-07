import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile photo uses profile based cache key and bucket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbProfilePhotoImage(
            imageUrl: ' https://cdn.example.com/profile.jpg ',
            fallbackText: 'АК',
            usageProfile: BbImageUsageProfile.hero,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://cdn.example.com/profile.jpg');
    expect(
      image.cacheKey,
      'profile-image-v2-hero-https://cdn.example.com/profile.jpg',
    );
    expect(image.memCacheWidth, 1200);
    expect(image.memCacheHeight, 1600);
    expect(image.maxWidthDiskCache, 1200);
    expect(image.maxHeightDiskCache, 1600);
  });

  testWidgets('profile photo shows fallback without url', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbProfilePhotoImage(
            imageUrl: ' ',
            fallbackText: 'АК',
            usageProfile: BbImageUsageProfile.avatar,
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('АК'), findsOneWidget);
  });
}
