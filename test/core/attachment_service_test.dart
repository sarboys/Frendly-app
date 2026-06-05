import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/device/app_attachment_service.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

void main() {
  test('coalesces equal signed URL requests and keeps a short cache', () async {
    var calls = 0;
    final service = AppAttachmentService(
      fetchSignedUrl: (path) async {
        calls++;
        return SignedMediaUrl(
          url: 'https://cdn.test/$path?token=$calls',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
      },
    );

    final results = await Future.wait([
      service.resolveSignedUrl('/media/a/download-url'),
      service.resolveSignedUrl('/media/a/download-url'),
    ]);
    final cached = await service.resolveSignedUrl('/media/a/download-url');

    expect(results[0], results[1]);
    expect(cached, results[0]);
    expect(calls, 1);
  });

  test('refreshes signed URL when it is close to expiry', () async {
    var calls = 0;
    final service = AppAttachmentService(
      fetchSignedUrl: (path) async {
        calls++;
        return SignedMediaUrl(
          url: 'https://cdn.test/$path?token=$calls',
          expiresAt: DateTime.now().add(const Duration(seconds: 30)),
        );
      },
    );

    final first = await service.resolveSignedUrl('/media/a/download-url');
    final second = await service.resolveSignedUrl('/media/a/download-url');

    expect(first, isNot(second));
    expect(calls, 2);
  });

  test('warms a bounded set with concurrency two', () async {
    var active = 0;
    var maxActive = 0;
    final seen = <String>[];
    final service = AppAttachmentService(
      fetchSignedUrl: (path) async {
        active++;
        maxActive = maxActive < active ? active : maxActive;
        seen.add(path);
        await Future<void>.delayed(const Duration(milliseconds: 1));
        active--;
        return SignedMediaUrl(
          url: 'https://cdn.test$path',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
      },
      fetchFile: (_, __) async {},
    );

    await service.warmCache([
      '/media/1/download-url',
      '/media/2/download-url',
      '/media/3/download-url',
      '/media/4/download-url',
      '/media/5/download-url',
      '/media/6/download-url',
      '/media/7/download-url',
    ]);

    expect(seen, hasLength(6));
    expect(maxActive, lessThanOrEqualTo(2));
  });

  test('warms resolved attachment files with stable private image cache keys',
      () async {
    final downloads = <String, String>{};
    final service = AppAttachmentService(
      fetchSignedUrl: (path) async {
        return SignedMediaUrl(
          url: 'https://cdn.test$path?X-Amz-Signature=one',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
      },
      fetchFile: (url, cacheKey) async {
        downloads[url] = cacheKey;
      },
    );

    await service.warmCache(['/media/1/download-url']);

    expect(
      downloads,
      {
        'https://cdn.test/media/1/download-url?X-Amz-Signature=one':
            'dateasy-private-media-v1-card-/media/1/download-url',
      },
    );
  });

  test('resolves signed media into cached local file path', () async {
    final downloads = <String, String>{};
    final service = AppAttachmentService(
      fetchSignedUrl: (path) async {
        return SignedMediaUrl(
          url: 'https://cdn.test$path?X-Amz-Signature=voice',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
      },
      cacheFile: (url, cacheKey) async {
        downloads[url] = cacheKey;
        return '/local/cache/voice.m4a';
      },
    );

    final path =
        await service.resolveCachedFilePath('/media/voice/download-url');

    expect(path, '/local/cache/voice.m4a');
    expect(
      downloads,
      {
        'https://cdn.test/media/voice/download-url?X-Amz-Signature=voice':
            'dateasy-private-media-v1-card-/media/voice/download-url',
      },
    );
  });

  test('clears signed URL and cached attachment files on private cache clear',
      () async {
    var signedUrlCalls = 0;
    var clearFileCacheCalls = 0;
    final service = AppAttachmentService(
      fetchSignedUrl: (path) async {
        signedUrlCalls++;
        return SignedMediaUrl(
          url: 'https://cdn.test$path?token=$signedUrlCalls',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
      },
      clearCachedFiles: () async {
        clearFileCacheCalls++;
      },
    );

    final first = await service.resolveSignedUrl('/media/1/download-url');
    await service.clearPrivateCache();
    final second = await service.resolveSignedUrl('/media/1/download-url');

    expect(first, isNot(second));
    expect(signedUrlCalls, 2);
    expect(clearFileCacheCalls, 1);
  });

  test('private attachment keys are separate from public image keys', () {
    final publicKey = DateasyRemoteImage.cacheKeyFor(
      'https://cdn.test/media/1/download-url?X-Amz-Signature=one',
      DateasyImageUsage.card,
    );
    final privateKey = DateasyRemoteImage.privateCacheKeyFor(
      '/media/1/download-url',
      DateasyImageUsage.card,
    );

    expect(privateKey, 'dateasy-private-media-v1-card-/media/1/download-url');
    expect(privateKey, isNot(publicKey));
  });
}
