import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

abstract class MapkitBootstrap {
  Future<void> ensureInitialized();
}

final mapkitBootstrapProvider = Provider<MapkitBootstrap>(
  (ref) => const MethodChannelMapkitBootstrap(),
);

const _useAndroidYandexVirtualDisplay = bool.fromEnvironment(
  'BIG_BREAK_ANDROID_YANDEX_USE_VIRTUAL_DISPLAY',
  defaultValue: false,
);

void configureYandexMapRendering({
  bool useVirtualDisplay = _useAndroidYandexVirtualDisplay,
}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    AndroidYandexMap.useAndroidViewSurface = !useVirtualDisplay;
  }
}

class MethodChannelMapkitBootstrap implements MapkitBootstrap {
  const MethodChannelMapkitBootstrap();

  static const MethodChannel _channel = MethodChannel('app.mapkit.bootstrap');
  static const String _apiKey = String.fromEnvironment(
    'BIG_BREAK_MAPKIT_API_KEY',
  );
  static Future<void>? _initialization;

  @override
  Future<void> ensureInitialized() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return SynchronousFuture(null);
    }

    return _initialization ??= _channel.invokeMethod<void>(
        'ensureInitialized', {'apiKey': _apiKey}).then((_) {});
  }
}
