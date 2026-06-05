import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/welcome/application/google_auth_client.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';

void main() {
  test('google auth client initializes sdk and returns id token', () async {
    final gateway = _FakeGoogleAuthGateway(idToken: 'google-id-token');
    final client = GoogleAuthClient(
      gateway: gateway,
      clientId: ' google-client ',
      serverClientId: ' google-server ',
    );

    final idToken = await client.signIn();

    expect(idToken, 'google-id-token');
    expect(gateway.initializedClientId, 'google-client');
    expect(gateway.initializedServerClientId, 'google-server');
    expect(gateway.scopeHint, ['email', 'profile']);
  });

  test('google auth client fails when id token is missing', () async {
    final client = GoogleAuthClient(
      gateway: _FakeGoogleAuthGateway(),
      clientId: 'google-client',
      serverClientId: 'google-server',
    );

    await expectLater(
      client.signIn(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'missing_google_id_token',
        ),
      ),
    );
  });

  test('google auth client signs out cached provider session', () async {
    final gateway = _FakeGoogleAuthGateway();
    final client = GoogleAuthClient(
      gateway: gateway,
      clientId: 'google-client',
      serverClientId: 'google-server',
    );

    await client.signOut();

    expect(gateway.signOutCalls, 1);
  });

  test(
      'auth action stores tokens and current user after google backend verification',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = _FakeAdapter((options) async {
      if (options.path == '/auth/google/verify') {
        expect(options.data, {
          'idToken': 'google-id-token',
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

    final auth = await container.read(authActionsProvider).verifyGoogleAuth(
          idToken: 'google-id-token',
        );

    expect(auth.tokens.accessToken, 'access');
    expect(auth.tokens.refreshToken, 'refresh');
    expect(auth.isNewUser, false);
    expect(container.read(authTokensProvider)?.accessToken, 'access');
    expect(container.read(currentUserProvider)?.id, 'user-1');
    expect(container.read(currentUserProvider)?.onboardingComplete, isTrue);
  });
}

class _FakeGoogleAuthGateway implements GoogleAuthGateway {
  _FakeGoogleAuthGateway({this.idToken});

  final String? idToken;
  String? initializedClientId;
  String? initializedServerClientId;
  List<String>? scopeHint;
  int signOutCalls = 0;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
  }) async {
    initializedClientId = clientId;
    initializedServerClientId = serverClientId;
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<String?> authenticateIdToken({required List<String> scopeHint}) async {
    this.scopeHint = scopeHint;
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
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
