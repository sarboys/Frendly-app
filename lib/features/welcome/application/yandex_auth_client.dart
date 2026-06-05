import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile2/app/core/config/backend_config.dart';

const yandexAuthChannel = MethodChannel('app.yandex.auth');
const _yandexWebOnlyAuthorizationStrategy = 'webOnly';

class YandexAuthClient {
  const YandexAuthClient({
    this.platform,
    String clientId = BackendConfig.yandexClientId,
  }) : _clientId = clientId;

  final TargetPlatform? platform;
  final String _clientId;

  Future<String> signIn() async {
    final currentPlatform = platform ?? defaultTargetPlatform;
    if (currentPlatform == TargetPlatform.android) {
      throw PlatformException(
        code: 'yandex_android_not_ready',
        message: 'Yandex auth for Android is not configured yet',
      );
    }
    if (currentPlatform != TargetPlatform.iOS) {
      throw PlatformException(
        code: 'yandex_auth_unsupported_platform',
        message: 'Yandex auth is available only on iOS',
      );
    }

    final clientId = _trimmedOrNull(_clientId);
    final arguments = <String, String>{
      'authorizationStrategy': _yandexWebOnlyAuthorizationStrategy,
      if (clientId != null) 'clientId': clientId,
    };
    final token = await yandexAuthChannel.invokeMethod<String>(
      'signIn',
      arguments,
    );
    final trimmed = token?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw PlatformException(
        code: 'missing_yandex_token',
        message: 'Yandex token is missing',
      );
    }
    return trimmed;
  }

  Future<void> signOut() async {
    final currentPlatform = platform ?? defaultTargetPlatform;
    if (currentPlatform != TargetPlatform.iOS) {
      return;
    }

    final clientId = _trimmedOrNull(_clientId);
    await yandexAuthChannel.invokeMethod<void>(
      'signOut',
      clientId == null ? null : {'clientId': clientId},
    );
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
