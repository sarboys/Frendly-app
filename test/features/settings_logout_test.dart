import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/auth/social_auth_session_reset.dart';
import 'package:mobile2/app/core/device/app_push_token_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/app/session/session_cleanup_controller.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('settings logout resets cached social provider sessions', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requests = <RequestOptions>[];
    var googleSignOutCalls = 0;
    var yandexSignOutCalls = 0;
    final repository = BackendRepository(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _FakeAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            '{"ok":true}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        backendRepositoryProvider.overrideWithValue(repository),
        appPushTokenServiceProvider.overrideWithValue(
          const _FakePushTokenService(),
        ),
        sessionCleanupControllerProvider.overrideWithValue(
          SessionCleanupController(
            cacheStore: null,
            chatStore: null,
            clearPrivateMediaCache: () async {},
          ),
        ),
        socialAuthSessionResetterProvider.overrideWithValue(
          SocialAuthSessionResetter(
            googleSignOut: () async {
              googleSignOutCalls += 1;
            },
            yandexSignOut: () async {
              yandexSignOutCalls += 1;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(currentUserProvider.notifier).state =
        const BackendUser(id: 'user-1', name: 'Alex');
    await container.read(authTokensProvider.notifier).setTokens(
          const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
        );

    await container.read(settingsActionsProvider).logout();

    expect(requests.map((request) => request.path), ['/auth/logout']);
    expect(googleSignOutCalls, 1);
    expect(yandexSignOutCalls, 1);
    expect(container.read(authTokensProvider), isNull);
    expect(container.read(currentUserProvider), isNull);
  });
}

class _FakePushTokenService implements AppPushTokenService {
  const _FakePushTokenService();

  @override
  Future<void> clearRegisteredToken() async {}

  @override
  Future<String?> currentDeviceId() async => null;

  @override
  Future<RegisteredPushToken?> registerDeviceToken() async => null;
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
