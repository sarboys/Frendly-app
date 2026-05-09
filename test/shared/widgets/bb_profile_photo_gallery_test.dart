import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_gallery.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery shows page counter and reacts to swipe', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const photos = [
      ProfilePhoto(
        id: 'ph1',
        url: 'https://cdn.example.com/ph1.jpg',
        order: 0,
      ),
      ProfilePhoto(
        id: 'ph2',
        url: 'https://cdn.example.com/ph2.jpg',
        order: 1,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbProfilePhotoGallery(
            displayName: 'Аня К',
            photos: photos,
          ),
        ),
      ),
    );

    expect(find.text('1/2'), findsOneWidget);
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(
      image.cacheKey,
      BbProfilePhotoImage.cacheKeyFor(
        'https://cdn.example.com/ph1.jpg',
        BbImageUsageProfile.hero,
      ),
    );
    expect(image.memCacheWidth, 800);
    expect(image.memCacheHeight, 480);
    expect(image.maxWidthDiskCache, 800);
    expect(image.maxHeightDiskCache, 480);

    await tester.fling(
      find.byKey(const ValueKey('profile-photo-gallery-pageview')),
      const Offset(-600, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('gallery preview bytes use bounded decode hints', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const photos = [
      ProfilePhoto(
        id: 'ph-local',
        url: 'https://cdn.example.com/ph-local.jpg',
        order: 0,
      ),
    ];
    final bytes = await rootBundle.load('assets/images/logo-fr-orange.jpg');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BbProfilePhotoGallery(
            displayName: 'Аня К',
            photos: photos,
            photoPreviews: {
              'ph-local': bytes.buffer.asUint8List(),
            },
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, 800);
    expect(provider.height, 480);
  });
}
