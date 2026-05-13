import 'package:big_break_mobile/app/app.dart';
import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  disableDebugPaintOverlays();
  final systemUiFuture =
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final preferencesFuture = SharedPreferences.getInstance();
  configureYandexMapRendering();
  final preferences = await preferencesFuture;
  await systemUiFuture;
  const tokenStorage = FlutterAuthTokenStorage(
    AuthTokensController.defaultSecureStorage,
  );
  final initialTokens = await restoreInitialAuthTokens(
    tokenStorage,
    preferences,
  );
  runApp(
    BigBreakRoot(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authTokenStorageProvider.overrideWithValue(tokenStorage),
        initialAuthTokensProvider.overrideWithValue(initialTokens),
      ],
    ),
  );
}

@visibleForTesting
void disableDebugPaintOverlays() {
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;
}
