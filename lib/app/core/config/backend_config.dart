import 'package:flutter/foundation.dart';

class BackendConfig {
  const BackendConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'BIG_BREAK_API_URL',
    defaultValue: 'https://api.frendly.tech',
  );

  static const chatWebSocketUrl = String.fromEnvironment(
    'BIG_BREAK_CHAT_WS_URL',
    defaultValue: 'wss://api.frendly.tech/ws',
  );

  static const telegramBotUsername = String.fromEnvironment(
    'BIG_BREAK_TELEGRAM_BOT_USERNAME',
    defaultValue: 'frendly_code_bot',
  );

  static const _defaultGoogleClientId =
      '202569120900-49bl2vjan89hiof10o7uvffij50jj70a.apps.googleusercontent.com';

  static const googleClientId = String.fromEnvironment(
    'BIG_BREAK_GOOGLE_CLIENT_ID',
    defaultValue: _defaultGoogleClientId,
  );

  static const googleServerClientId = String.fromEnvironment(
    'BIG_BREAK_GOOGLE_SERVER_CLIENT_ID',
    defaultValue: googleClientId,
  );

  static const yandexClientId = String.fromEnvironment(
    'BIG_BREAK_YANDEX_CLIENT_ID',
  );

  static const enableTestPhoneShortcuts = bool.fromEnvironment(
    'BIG_BREAK_ENABLE_TEST_PHONE_SHORTCUTS',
    defaultValue: true,
  );

  static const _seededTestPhoneShortcutNumbers = <String>{
    '+70000000000',
    '+71111111111',
    '+72222222222',
    '+73333333333',
    '+74444444444',
    '+75555555555',
    '+76666666666',
    '+77777777777',
    '+78888888888',
    '+79999999999',
  };

  static bool isSeededTestPhoneShortcutNumber(String phoneNumber) {
    if (kReleaseMode && !enableTestPhoneShortcuts) {
      return false;
    }
    final normalized = phoneNumber.replaceAll(RegExp(r'[\s()-]'), '');
    return _seededTestPhoneShortcutNumbers.contains(normalized);
  }

  static const mapKitKey = String.fromEnvironment(
    'BIG_BREAK_MAPKIT_API_KEY',
    defaultValue: String.fromEnvironment('BIG_BREAK_YANDEX_MAPKIT_KEY'),
  );

  static bool get hasMapKitKey => isUsableMapKitKey(mapKitKey);

  static bool isUsableMapKitKey(String value) {
    final key = value.trim();
    return key.isNotEmpty && key != 'your-mapkit-key' && !key.startsWith(r'$(');
  }

  static const localFirstCacheEnabled = bool.fromEnvironment(
    'BIG_BREAK_LOCAL_FIRST_CACHE',
    defaultValue: true,
  );
}
