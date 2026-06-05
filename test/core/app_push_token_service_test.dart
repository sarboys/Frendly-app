import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/device/app_push_token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.push.token');
  final calls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'registerDeviceToken':
          return 'native-token-123';
        case 'clearRegisteredToken':
          return null;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('registers ios token and keeps stable device id', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = NativeAppPushTokenService(
      sharedPreferences: preferences,
      channel: channel,
      platformOverride: TargetPlatform.iOS,
    );

    final first = await service.registerDeviceToken();
    final second = await service.registerDeviceToken();

    expect(first, isNotNull);
    expect(first!.token, 'native-token-123');
    expect(first.provider, 'apns');
    expect(first.platform, 'ios');
    expect(first.deviceId, startsWith('iOS-push-'));
    expect(second!.deviceId, first.deviceId);
    expect(await service.currentDeviceId(), first.deviceId);
  });

  test('registers android token as fcm when firebase token is present',
      () async {
    final preferences = await SharedPreferences.getInstance();
    var getTokenCalls = 0;
    final service = NativeAppPushTokenService(
      sharedPreferences: preferences,
      platformOverride: TargetPlatform.android,
      androidTokenProvider: () async {
        getTokenCalls += 1;
        return 'fcm-token-123';
      },
    );

    final first = await service.registerDeviceToken();
    final second = await service.registerDeviceToken();

    expect(first, isNotNull);
    expect(first!.token, 'fcm-token-123');
    expect(first.provider, 'fcm');
    expect(first.platform, 'android');
    expect(first.deviceId, startsWith('android-push-'));
    expect(second!.deviceId, first.deviceId);
    expect(await service.currentDeviceId(), first.deviceId);
    expect(getTokenCalls, 2);
  });

  test('clears native token cache', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = NativeAppPushTokenService(
      sharedPreferences: preferences,
      channel: channel,
      platformOverride: TargetPlatform.iOS,
    );

    await service.clearRegisteredToken();

    expect(calls.single.method, 'clearRegisteredToken');
  });

  test('clears android fcm token cache', () async {
    final preferences = await SharedPreferences.getInstance();
    var clearCalls = 0;
    final service = NativeAppPushTokenService(
      sharedPreferences: preferences,
      platformOverride: TargetPlatform.android,
      androidTokenClearer: () async {
        clearCalls += 1;
      },
    );

    await service.clearRegisteredToken();

    expect(clearCalls, 1);
  });
}
