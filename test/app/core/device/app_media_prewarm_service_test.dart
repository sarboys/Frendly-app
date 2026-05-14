import 'dart:io' as io;

import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
// ignore: depend_on_referenced_packages
import 'package:file/file.dart' as pfile;
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCacheFileSystem implements FileSystem {
  _MemoryCacheFileSystem() : _delegate = MemoryFileSystem();

  final MemoryFileSystem _delegate;

  @override
  Future<pfile.File> createFile(String name) async {
    final file = _delegate.file(name);
    await file.parent.create(recursive: true);
    return file;
  }
}

class _RecordingCacheManager extends CacheManager {
  _RecordingCacheManager(
    String key, {
    this.delay = Duration.zero,
  }) : super(
          Config(
            key,
            repo: JsonCacheInfoRepository.withFile(
              io.File('${io.Directory.systemTemp.path}/$key.json'),
            ),
            fileSystem: _MemoryCacheFileSystem(),
          ),
        );

  final Duration delay;
  final urls = <String>[];
  final keys = <String?>[];
  var active = 0;
  var maxActive = 0;
  final _fileSystem = MemoryFileSystem();

  @override
  Future<pfile.File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    urls.add(url);
    keys.add(key);
    active += 1;
    if (active > maxActive) {
      maxActive = active;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    active -= 1;
    final file = _fileSystem.file('/${url.hashCode}.jpg');
    if (!file.existsSync()) {
      file.writeAsStringSync('image');
    }
    return file;
  }
}

void main() {
  test('external event prewarm uses injected cache manager and first 8 urls',
      () async {
    final externalCache = _RecordingCacheManager(
      'bb-media-prewarm-external-test',
      delay: const Duration(milliseconds: 1),
    );
    final service = AppMediaPrewarmService(
      profileImageCacheManager: _RecordingCacheManager(
        'bb-media-prewarm-profile-unused-test',
      ),
      externalEventImageCacheManager: externalCache,
    );

    await service.warmExternalEventImages(
      List<String>.generate(
          12, (index) => ' https://cdn.example.com/$index.jpg '),
      usage: BbExternalEventImageUsage.card,
      limit: 8,
      concurrency: 10,
    );

    expect(
      externalCache.urls,
      List<String>.generate(8, (index) => 'https://cdn.example.com/$index.jpg'),
    );
    expect(
      externalCache.keys.first,
      'external-event-image-v4-card-https://cdn.example.com/0.jpg',
    );
    expect(externalCache.maxActive, lessThanOrEqualTo(3));
  });

  test('profile prewarm keeps cellular-like concurrency at 2', () async {
    final profileCache = _RecordingCacheManager(
      'bb-media-prewarm-profile-test',
      delay: const Duration(milliseconds: 1),
    );
    final service = AppMediaPrewarmService(
      profileImageCacheManager: profileCache,
      externalEventImageCacheManager: _RecordingCacheManager(
        'bb-media-prewarm-external-unused-test',
      ),
    );

    await service.warmProfileImages(
      List<String>.generate(6, (index) => 'https://cdn.example.com/$index.jpg'),
      usageProfile: BbImageUsageProfile.avatar,
      limit: 6,
      concurrency: 2,
    );

    expect(profileCache.urls, hasLength(6));
    expect(
      profileCache.keys.first,
      'profile-image-v2-avatar-https://cdn.example.com/0.jpg',
    );
    expect(profileCache.maxActive, lessThanOrEqualTo(2));
  });
}
