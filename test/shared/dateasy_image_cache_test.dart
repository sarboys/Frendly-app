import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/widgets/dateasy_image_cache.dart';

void main() {
  test('remote image file service times out slow requests', () async {
    final service = DateasyTimeoutFileService(
      delegate: _NeverCompletesFileService(),
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      service.get('https://cdn.test/slow.webp'),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('remote image timeout is eight seconds in production config', () {
    expect(dateasyRemoteImageRequestTimeout, const Duration(seconds: 8));
  });
}

class _NeverCompletesFileService extends FileService {
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) {
    return Completer<FileServiceResponse>().future;
  }
}
