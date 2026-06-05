import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

const pushNotificationsEnabledStorageKey = 'settings.push.enabled.v1';
const _pushDeviceIdStorageKey = 'push.device_id.v1';
const _pushTokenChannel = MethodChannel('app.push.token');

class RegisteredPushToken {
  const RegisteredPushToken({
    required this.token,
    required this.provider,
    required this.deviceId,
    required this.platform,
  });

  final String token;
  final String provider;
  final String deviceId;
  final String platform;
}

abstract class AppPushTokenService {
  Future<RegisteredPushToken?> registerDeviceToken();
  Future<String?> currentDeviceId();
  Future<void> clearRegisteredToken();
}

class NativeAppPushTokenService implements AppPushTokenService {
  NativeAppPushTokenService({
    required SharedPreferences? sharedPreferences,
    MethodChannel? channel,
    TargetPlatform? platformOverride,
    Future<String?> Function()? androidTokenProvider,
    Future<void> Function()? androidTokenClearer,
  })  : _sharedPreferences = sharedPreferences,
        _channel = channel ?? _pushTokenChannel,
        _platform = platformOverride,
        _androidTokenProvider = androidTokenProvider,
        _androidTokenClearer = androidTokenClearer;

  final SharedPreferences? _sharedPreferences;
  final MethodChannel _channel;
  final TargetPlatform? _platform;
  final Future<String?> Function()? _androidTokenProvider;
  final Future<void> Function()? _androidTokenClearer;

  TargetPlatform get _targetPlatform => _platform ?? defaultTargetPlatform;

  bool get _supportsPushTokenRegistration {
    return !kIsWeb &&
        (_targetPlatform == TargetPlatform.iOS ||
            _targetPlatform == TargetPlatform.android);
  }

  @override
  Future<RegisteredPushToken?> registerDeviceToken() async {
    if (!_supportsPushTokenRegistration) {
      return null;
    }
    try {
      final token = _targetPlatform == TargetPlatform.android
          ? await (_androidTokenProvider ?? FirebaseMessaging.instance.getToken)
              .call()
          : await _channel.invokeMethod<String>('registerDeviceToken');
      if (token == null || token.isEmpty) {
        return null;
      }
      return RegisteredPushToken(
        token: token,
        provider: _targetPlatform == TargetPlatform.iOS ? 'apns' : 'fcm',
        deviceId: await _resolveDeviceId(),
        platform: _targetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<String?> currentDeviceId() async {
    final existing = _sharedPreferences?.getString(_pushDeviceIdStorageKey);
    return existing == null || existing.isEmpty ? null : existing;
  }

  @override
  Future<void> clearRegisteredToken() async {
    if (!_supportsPushTokenRegistration) {
      return;
    }
    try {
      if (_targetPlatform == TargetPlatform.android) {
        await (_androidTokenClearer ?? FirebaseMessaging.instance.deleteToken)
            .call();
      } else {
        await _channel.invokeMethod<void>('clearRegisteredToken');
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<String> _resolveDeviceId() async {
    final existing = _sharedPreferences?.getString(_pushDeviceIdStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated =
        '${_targetPlatform.name}-push-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    await _sharedPreferences?.setString(_pushDeviceIdStorageKey, generated);
    return generated;
  }
}
