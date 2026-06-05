import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/welcome/application/yandex_auth_client.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(yandexAuthChannel, null);
  });

  test('uses native yandex auth channel on ios', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(yandexAuthChannel, (call) async {
      calls.add(call);
      return 'oauth-token';
    });

    final token = await const YandexAuthClient(
      platform: TargetPlatform.iOS,
    ).signIn();

    expect(token, 'oauth-token');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'signIn');
    expect(calls.single.arguments, {'authorizationStrategy': 'webOnly'});
  });

  test('passes configured yandex client id to native auth channel', () async {
    late MethodCall seenCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(yandexAuthChannel, (call) async {
      seenCall = call;
      return 'oauth-token';
    });

    final token = await const YandexAuthClient(
      platform: TargetPlatform.iOS,
      clientId: ' yandex-client ',
    ).signIn();

    expect(token, 'oauth-token');
    expect(seenCall.method, 'signIn');
    expect(seenCall.arguments, {
      'clientId': 'yandex-client',
      'authorizationStrategy': 'webOnly',
    });
  });

  test('signs out cached yandex provider session through native channel',
      () async {
    late MethodCall seenCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(yandexAuthChannel, (call) async {
      seenCall = call;
      return null;
    });

    await const YandexAuthClient(
      platform: TargetPlatform.iOS,
      clientId: ' yandex-client ',
    ).signOut();

    expect(seenCall.method, 'signOut');
    expect(seenCall.arguments, {'clientId': 'yandex-client'});
  });

  test(
      'does not start yandex sdk on android until android client is configured',
      () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(yandexAuthChannel, (_) async {
      called = true;
      return 'oauth-token';
    });

    await expectLater(
      const YandexAuthClient(platform: TargetPlatform.android).signIn(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'yandex_android_not_ready',
        ),
      ),
    );
    expect(called, isFalse);
  });

  test(
      'auth action stores tokens and current user after yandex backend verification',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = _FakeAdapter((options) async {
      if (options.path == '/auth/yandex/verify') {
        expect(options.data, {
          'oauthToken': 'oauth-token',
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
        '{"id":"user-1","displayName":"Сергей","onboardingComplete":true}',
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

    final auth = await container.read(authActionsProvider).verifyYandexAuth(
          oauthToken: 'oauth-token',
        );

    expect(auth.tokens.accessToken, 'access');
    expect(auth.tokens.refreshToken, 'refresh');
    expect(auth.isNewUser, false);
    expect(container.read(authTokensProvider)?.accessToken, 'access');
    expect(container.read(currentUserProvider)?.id, 'user-1');
    expect(container.read(currentUserProvider)?.onboardingComplete, isTrue);
  });
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
