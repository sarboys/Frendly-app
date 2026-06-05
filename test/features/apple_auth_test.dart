import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/welcome/application/apple_auth_client.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';

void main() {
  test('apple auth client returns identity token and full name', () async {
    final gateway = _FakeAppleAuthGateway(
      identityToken: 'apple-id-token',
      authorizationCode: 'apple-auth-code',
      givenName: 'Sergey',
      familyName: 'Polyakov',
    );
    final client = AppleAuthClient(gateway: gateway);

    final result = await client.signIn();

    expect(result.identityToken, 'apple-id-token');
    expect(result.authorizationCode, 'apple-auth-code');
    expect(result.fullName, 'Sergey Polyakov');
    expect(gateway.requestedScopes, AppleAuthClient.defaultScopes);
  });

  test('apple auth client fails when identity token is missing', () async {
    final client = AppleAuthClient(
      gateway: _FakeAppleAuthGateway(authorizationCode: 'apple-auth-code'),
    );

    await expectLater(
      client.signIn(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'missing_apple_identity_token',
        ),
      ),
    );
  });

  test(
      'auth action stores tokens and current user after apple backend verification',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = _FakeAdapter((options) async {
      if (options.path == '/auth/apple/verify') {
        expect(options.data, {
          'identityToken': 'apple-id-token',
          'authorizationCode': 'apple-auth-code',
          'fullName': 'Sergey Polyakov',
          'acceptedTerms': true,
        });
        return ResponseBody.fromString(
          '{"accessToken":"access","refreshToken":"refresh","userId":"user-1","isNewUser":false}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      expect(options.path, '/me');
      return ResponseBody.fromString(
        '{"id":"user-1","displayName":"S P","onboardingComplete":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWithValue(BackendRepository(dio)),
      ],
    );
    addTearDown(container.dispose);

    final auth = await container.read(authActionsProvider).verifyAppleAuth(
          identityToken: 'apple-id-token',
          authorizationCode: 'apple-auth-code',
          fullName: 'Sergey Polyakov',
        );

    expect(auth.tokens.accessToken, 'access');
    expect(auth.tokens.refreshToken, 'refresh');
    expect(auth.isNewUser, false);
    expect(container.read(authTokensProvider)?.accessToken, 'access');
    expect(container.read(currentUserProvider)?.id, 'user-1');
    expect(container.read(currentUserProvider)?.onboardingComplete, isTrue);
  });
}

class _FakeAppleAuthGateway implements AppleAuthGateway {
  _FakeAppleAuthGateway({
    this.identityToken,
    this.authorizationCode,
    this.givenName,
    this.familyName,
  });

  final String? identityToken;
  final String? authorizationCode;
  final String? givenName;
  final String? familyName;
  List<AppleAuthScope>? requestedScopes;

  @override
  Future<AppleAuthCredential> signIn({
    required List<AppleAuthScope> scopes,
  }) async {
    requestedScopes = scopes;
    return AppleAuthCredential(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      givenName: givenName,
      familyName: familyName,
    );
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handle);

  final Future<ResponseBody> Function(RequestOptions options) handle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}
