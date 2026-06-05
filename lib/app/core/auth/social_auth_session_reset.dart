import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile2/features/welcome/application/google_auth_client.dart';
import 'package:mobile2/features/welcome/application/yandex_auth_client.dart';

typedef SocialAuthSignOut = Future<void> Function();

final socialAuthSessionResetterProvider = Provider<SocialAuthSessionResetter>(
  (ref) => SocialAuthSessionResetter(
    googleSignOut: ref.watch(googleAuthClientProvider).signOut,
    yandexSignOut: const YandexAuthClient().signOut,
  ),
);

class SocialAuthSessionResetter {
  const SocialAuthSessionResetter({
    required SocialAuthSignOut googleSignOut,
    required SocialAuthSignOut yandexSignOut,
  })  : _googleSignOut = googleSignOut,
        _yandexSignOut = yandexSignOut;

  final SocialAuthSignOut _googleSignOut;
  final SocialAuthSignOut _yandexSignOut;

  Future<void> reset() async {
    await Future.wait([
      _bestEffortSignOut('google', _googleSignOut),
      _bestEffortSignOut('yandex', _yandexSignOut),
    ]);
  }

  Future<void> _bestEffortSignOut(
    String provider,
    SocialAuthSignOut signOut,
  ) async {
    try {
      await signOut();
    } catch (error, stackTrace) {
      if (!kDebugMode) {
        return;
      }
      debugPrint('[social-auth] $provider sign out failed: $error');
      debugPrintStack(
        label: '[social-auth] $provider sign out stack',
        stackTrace: stackTrace,
      );
    }
  }
}
