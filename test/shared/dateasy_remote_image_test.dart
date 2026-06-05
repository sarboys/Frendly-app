import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;

  setUpAll(() {
    tempDirectory = Directory.systemTemp.createTempSync(
      'dateasy_remote_image_test.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return switch (call.method) {
        'getTemporaryDirectory' ||
        'getApplicationSupportDirectory' =>
          tempDirectory.path,
        _ => null,
      };
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    tempDirectory.deleteSync(recursive: true);
  });

  testWidgets('avatar image fallback shows a person icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: null,
          usage: DateasyImageUsage.avatar,
        ),
      ),
    );

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('card image fallback shows a broken image icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: '',
          usage: DateasyImageUsage.card,
        ),
      ),
    );

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('relative backend image urls are resolved before loading',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: '/affiche/images?key=card',
          usage: DateasyImageUsage.card,
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(
      image.imageUrl,
      'https://api.frendly.tech/affiche/images?key=card',
    );
    expect(
      image.cacheKey,
      'dateasy-image-v4-card-https://api.frendly.tech/affiche/images?key=card',
    );
  });

  testWidgets('uses the best image variant for the requested usage',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: 'https://cdn.test/original.jpg',
          imageVariants: {
            'thumb': {'url': 'https://cdn.test/photo__thumb.webp'},
            'card': {'url': 'https://cdn.test/photo__card.webp'},
            'hero': {'url': 'https://cdn.test/photo__hero.webp'},
          },
          usage: DateasyImageUsage.card,
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.imageUrl, 'https://cdn.test/photo__card.webp');
    expect(image.cacheKey, contains('photo__card.webp'));
  });

  testWidgets('falls back to a smaller variant before the original image',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: 'https://cdn.test/original.jpg',
          imageVariants: {
            'thumb': {'url': 'https://cdn.test/photo__thumb.webp'},
          },
          usage: DateasyImageUsage.card,
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.imageUrl, 'https://cdn.test/photo__thumb.webp');
  });

  testWidgets('tries the original image when the selected variant fails',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: 'https://cdn.test/original.jpg',
          imageVariants: {
            'card': {'url': 'https://cdn.test/photo__card.webp'},
          },
          usage: DateasyImageUsage.card,
        ),
      ),
    );

    final first = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(first.imageUrl, 'https://cdn.test/photo__card.webp');

    first.errorListener?.call(StateError('variant decode failed'));
    await tester.pump();

    final fallback = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(fallback.imageUrl, 'https://cdn.test/original.jpg');
    expect(fallback.cacheKey, contains('original.jpg'));
  });

  testWidgets('image urls do not receive auth headers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: 'https://cdn.test/photo.jpg',
          usage: DateasyImageUsage.card,
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.httpHeaders, isNull);
  });

  testWidgets('omits disk resize for cache managers without image resizing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: 'https://cdn.test/photo.jpg',
          usage: DateasyImageUsage.card,
          cacheManager: _PlainCacheManager(),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.maxWidthDiskCache, isNull);
    expect(image.maxHeightDiskCache, isNull);
  });

  test('drops volatile signed media query parameters from cache keys', () {
    final first = DateasyRemoteImage.cacheKeyFor(
      'https://cdn.test/media/a.jpg?X-Amz-Signature=one&X-Amz-Expires=60',
      DateasyImageUsage.card,
    );
    final second = DateasyRemoteImage.cacheKeyFor(
      'https://cdn.test/media/a.jpg?X-Amz-Signature=two&X-Amz-Expires=60',
      DateasyImageUsage.card,
    );

    expect(first, second);
    expect(first, 'dateasy-image-v4-card-https://cdn.test/media/a.jpg');
  });

  test('public image cache keys use the current cache namespace', () {
    final cacheKey = DateasyRemoteImage.cacheKeyFor(
      'https://cdn.test/photo.jpg',
      DateasyImageUsage.card,
    );

    expect(cacheKey, startsWith('dateasy-image-v4-card-'));
    expect(cacheKey, isNot(startsWith('dateasy-image-v3-card-')));
  });

  testWidgets('retries with a fresh cache key after image load error',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DateasyRemoteImage(
          imageUrl: 'https://cdn.test/photo.jpg',
          usage: DateasyImageUsage.card,
        ),
      ),
    );

    final first = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    first.errorListener?.call(StateError('cached file decode failed'));
    await tester.pump();

    final retried = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(retried.cacheKey, isNot(first.cacheKey));
    expect(retried.cacheKey, startsWith('${first.cacheKey}-retry-'));
  });
}

class _PlainCacheManager extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    return const Stream.empty();
  }

  @override
  Future<void> removeFile(String key) async {}
}
