import 'dart:async';
import 'dart:typed_data';

import 'package:big_break_mobile/app/core/network/api_client.dart';
import 'package:big_break_mobile/shared/models/tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps original 401 when token refresh fails', () async {
    var refreshCalls = 0;
    final client = ApiClient(
      readAccessToken: () async => 'expired-access',
      refreshTokens: () async {
        refreshCalls += 1;
        throw DioException.badResponse(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/auth/refresh'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            statusCode: 401,
          ),
        );
      },
    );
    client.dio.httpClientAdapter = _FakeAdapter(
      onFetch: (options, _) {
        if (options.path == '/profile/me') {
          return ResponseBody.fromString('', 401);
        }
        return ResponseBody.fromString('', 404);
      },
    );

    final future = client.dio.get('/profile/me');

    await expectLater(
      future,
      throwsA(
        isA<DioException>().having(
          (error) => error.requestOptions.path,
          'path',
          '/profile/me',
        ),
      ),
    );
    expect(refreshCalls, 1);
  });

  test('retries original request with fresh access token after refresh',
      () async {
    var refreshCalls = 0;
    var requestCalls = 0;
    final client = ApiClient(
      readAccessToken: () async => 'expired-access',
      refreshTokens: () async {
        refreshCalls += 1;
        return const AuthTokens(
          accessToken: 'fresh-access',
          refreshToken: 'fresh-refresh',
        );
      },
    );
    client.dio.httpClientAdapter = _FakeAdapter(
      onFetch: (options, _) {
        requestCalls += 1;
        final authHeader = options.headers['authorization']?.toString();
        if (options.path == '/profile/me' &&
            authHeader == 'Bearer expired-access') {
          return ResponseBody.fromString('', 401);
        }
        return ResponseBody.fromString('{"ok":true}', 200, headers: {
          Headers.contentTypeHeader: ['application/json'],
        });
      },
    );

    final response = await client.dio.get<Map<String, dynamic>>('/profile/me');

    expect(response.data, {'ok': true});
    expect(refreshCalls, 1);
    expect(requestCalls, 2);
  });

  test('deduplicates concurrent identical uncancelled get requests', () async {
    var requestCalls = 0;
    final client = ApiClient(
      readAccessToken: () async => 'access',
      refreshTokens: () async => const AuthTokens(
        accessToken: 'fresh-access',
        refreshToken: 'fresh-refresh',
      ),
    );
    client.dio.httpClientAdapter = _FakeAdapter(
      onFetch: (options, _) async {
        requestCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return ResponseBody.fromString('{"items":[]}', 200, headers: {
          Headers.contentTypeHeader: ['application/json'],
        });
      },
    );

    final responses = await Future.wait([
      client.dio.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {'filter': 'nearby', 'limit': 20},
      ),
      client.dio.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {'limit': 20, 'filter': 'nearby'},
      ),
    ]);

    expect(requestCalls, 1);
    expect(responses.map((response) => response.data), [
      {'items': []},
      {'items': []},
    ]);
  });

  test('does not deduplicate get requests with cancel tokens', () async {
    var requestCalls = 0;
    final client = ApiClient(
      readAccessToken: () async => 'access',
      refreshTokens: () async => const AuthTokens(
        accessToken: 'fresh-access',
        refreshToken: 'fresh-refresh',
      ),
    );
    client.dio.httpClientAdapter = _FakeAdapter(
      onFetch: (options, _) async {
        requestCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return ResponseBody.fromString('{"ok":true}', 200, headers: {
          Headers.contentTypeHeader: ['application/json'],
        });
      },
    );

    await Future.wait([
      client.dio.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {'filter': 'nearby'},
        cancelToken: CancelToken(),
      ),
      client.dio.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {'filter': 'nearby'},
        cancelToken: CancelToken(),
      ),
    ]);

    expect(requestCalls, 2);
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    required this.onFetch,
  });

  final FutureOr<ResponseBody> Function(
    RequestOptions options,
    Future<void>? cancelFuture,
  ) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return onFetch(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
