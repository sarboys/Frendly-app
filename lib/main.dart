import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile2/app/dateasy_app.dart';
import 'package:mobile2/app/core/auth/auth_token_storage.dart';
import 'package:mobile2/app/core/device/app_runtime_environment.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebaseForAndroid();
  final preferences = await SharedPreferences.getInstance();
  final tokenStorage = SecureAuthTokenStorage(preferences: preferences);
  final initialTokens = await tokenStorage.read();
  final isIosAppOnMac = await const AppRuntimeEnvironment().isIosAppOnMac();
  runApp(
    DateasyApp(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authTokenStorageProvider.overrideWithValue(tokenStorage),
        initialAuthTokensProvider.overrideWithValue(initialTokens),
        iosAppOnMacProvider.overrideWithValue(isIosAppOnMac),
      ],
    ),
  );
}

Future<void> _initializeFirebaseForAndroid() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  await Firebase.initializeApp();
}
