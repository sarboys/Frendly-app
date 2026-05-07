import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.mapkit.bootstrap');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('ensureInitialized calls iOS bridge only once', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var callCount = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'ensureInitialized');
      callCount += 1;
      return null;
    });

    const bootstrap = MethodChannelMapkitBootstrap();

    await bootstrap.ensureInitialized();
    await bootstrap.ensureInitialized();

    expect(callCount, 1);
  });

  test('android map uses virtual display composition for stable rendering', () {
    AndroidYandexMap.useAndroidViewSurface = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    configureYandexMapRendering();

    expect(AndroidYandexMap.useAndroidViewSurface, isFalse);
  });
}
