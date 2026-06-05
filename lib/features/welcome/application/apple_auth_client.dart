import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

enum AppleAuthScope { email, fullName }

class AppleAuthCredential {
  const AppleAuthCredential({
    this.identityToken,
    this.authorizationCode,
    this.givenName,
    this.familyName,
  });

  final String? identityToken;
  final String? authorizationCode;
  final String? givenName;
  final String? familyName;

  String? get fullName {
    final parts = [
      givenName?.trim(),
      familyName?.trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>();
    final value = parts.join(' ').trim();
    return value.isEmpty ? null : value;
  }
}

class AppleAuthResult {
  const AppleAuthResult({
    required this.identityToken,
    this.authorizationCode,
    this.fullName,
  });

  final String identityToken;
  final String? authorizationCode;
  final String? fullName;
}

abstract interface class AppleAuthGateway {
  Future<AppleAuthCredential> signIn({
    required List<AppleAuthScope> scopes,
  });
}

class SignInWithAppleAuthGateway implements AppleAuthGateway {
  const SignInWithAppleAuthGateway();

  @override
  Future<AppleAuthCredential> signIn({
    required List<AppleAuthScope> scopes,
  }) async {
    final credential = await apple.SignInWithApple.getAppleIDCredential(
      scopes: scopes.map(_scope).toList(growable: false),
    );
    return AppleAuthCredential(
      identityToken: credential.identityToken,
      authorizationCode: credential.authorizationCode,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  apple.AppleIDAuthorizationScopes _scope(AppleAuthScope scope) {
    return switch (scope) {
      AppleAuthScope.email => apple.AppleIDAuthorizationScopes.email,
      AppleAuthScope.fullName => apple.AppleIDAuthorizationScopes.fullName,
    };
  }
}

class AppleAuthClient {
  AppleAuthClient({
    AppleAuthGateway gateway = const SignInWithAppleAuthGateway(),
  }) : _gateway = gateway;

  static const defaultScopes = [
    AppleAuthScope.email,
    AppleAuthScope.fullName,
  ];

  final AppleAuthGateway _gateway;

  Future<AppleAuthResult> signIn() async {
    try {
      final credential = await _gateway.signIn(scopes: defaultScopes);
      final identityToken = credential.identityToken?.trim() ?? '';
      if (identityToken.isEmpty) {
        throw PlatformException(
          code: 'missing_apple_identity_token',
          message: 'Apple did not return an identity token',
        );
      }
      final authorizationCode = credential.authorizationCode?.trim();
      return AppleAuthResult(
        identityToken: identityToken,
        authorizationCode:
            authorizationCode == null || authorizationCode.isEmpty
                ? null
                : authorizationCode,
        fullName: credential.fullName,
      );
    } on apple.SignInWithAppleAuthorizationException catch (error) {
      throw _platformExceptionForApple(error);
    }
  }

  PlatformException _platformExceptionForApple(
    apple.SignInWithAppleAuthorizationException error,
  ) {
    final code = switch (error.code) {
      apple.AuthorizationErrorCode.canceled => 'apple_auth_cancelled',
      apple.AuthorizationErrorCode.failed => 'apple_auth_failed',
      apple.AuthorizationErrorCode.invalidResponse =>
        'missing_apple_identity_token',
      apple.AuthorizationErrorCode.notHandled => 'apple_auth_failed',
      apple.AuthorizationErrorCode.notInteractive => 'apple_auth_ui_unavailable',
      apple.AuthorizationErrorCode.unknown => 'apple_auth_failed',
    };
    return PlatformException(
      code: code,
      message: error.message,
      details: error.toString(),
    );
  }
}
