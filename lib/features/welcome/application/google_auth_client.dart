import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile2/app/core/config/backend_config.dart';

final googleAuthClientProvider = Provider<GoogleAuthClient>(
  (ref) => GoogleAuthClient(),
);

abstract interface class GoogleAuthGateway {
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
  });

  bool supportsAuthenticate();

  Future<String?> authenticateIdToken({required List<String> scopeHint});

  Future<void> signOut();
}

class GoogleSignInAuthGateway implements GoogleAuthGateway {
  GoogleSignInAuthGateway({GoogleSignIn? signIn})
      : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
  }) {
    return _signIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  @override
  bool supportsAuthenticate() => _signIn.supportsAuthenticate();

  @override
  Future<String?> authenticateIdToken({
    required List<String> scopeHint,
  }) async {
    final account = await _signIn.authenticate(scopeHint: scopeHint);
    return account.authentication.idToken;
  }

  @override
  Future<void> signOut() {
    return _signIn.signOut();
  }
}

class GoogleAuthClient {
  GoogleAuthClient({
    GoogleAuthGateway? gateway,
    String clientId = BackendConfig.googleClientId,
    String serverClientId = BackendConfig.googleServerClientId,
  })  : _gateway = gateway ?? GoogleSignInAuthGateway(),
        _clientId = clientId,
        _serverClientId = serverClientId;

  static const _scopeHint = ['email', 'profile'];

  final GoogleAuthGateway _gateway;
  final String _clientId;
  final String _serverClientId;

  Future<void>? _initializeFuture;
  bool _initialized = false;

  Future<String> signIn() async {
    await _ensureInitialized();
    if (!_gateway.supportsAuthenticate()) {
      throw PlatformException(
        code: 'google_auth_unsupported_platform',
        message: 'Google auth is not available on this platform',
      );
    }

    try {
      final idToken = await _gateway.authenticateIdToken(
        scopeHint: _scopeHint,
      );
      final trimmed = idToken?.trim() ?? '';
      if (trimmed.isEmpty) {
        throw PlatformException(
          code: 'missing_google_id_token',
          message: 'Google did not return an id token',
        );
      }
      return trimmed;
    } on GoogleSignInException catch (error) {
      throw _platformExceptionForGoogle(error);
    }
  }

  Future<void> signOut() {
    return _gateway.signOut();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final clientId = _trimmedOrNull(_clientId);
    final serverClientId = _trimmedOrNull(_serverClientId) ?? clientId;
    if (clientId == null && serverClientId == null) {
      throw PlatformException(
        code: 'google_auth_not_configured',
        message: 'Google auth is not configured',
      );
    }

    final existing = _initializeFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _gateway.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
    _initializeFuture = future;
    try {
      await future;
      _initialized = true;
    } catch (_) {
      _initializeFuture = null;
      rethrow;
    }
  }

  PlatformException _platformExceptionForGoogle(GoogleSignInException error) {
    final code = switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'google_auth_cancelled',
      GoogleSignInExceptionCode.interrupted => 'google_auth_cancelled',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'google_auth_not_configured',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'google_auth_not_configured',
      GoogleSignInExceptionCode.uiUnavailable => 'google_auth_ui_unavailable',
      _ => 'google_auth_failed',
    };
    return PlatformException(
      code: code,
      message: error.description ?? 'Google auth failed',
      details: error.details,
    );
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
