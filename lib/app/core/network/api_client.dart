import 'dart:async';
import 'dart:convert';

import 'package:big_break_mobile/app/core/config/backend_config.dart';
import 'package:big_break_mobile/shared/models/tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const _requestDedupeKeyExtra = '_bbRequestDedupeKey';

class ApiClient {
  ApiClient({
    required Future<String?> Function() readAccessToken,
    required Future<AuthTokens> Function() refreshTokens,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: BackendConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {
              'content-type': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuthHeader = options.extra['skipAuthHeader'] == true;
          final token = skipAuthHeader ? null : await readAccessToken();
          final hasExplicitAuthHeader =
              options.headers['authorization'] != null;
          if (!hasExplicitAuthHeader && token != null && token.isNotEmpty) {
            options.headers['authorization'] = 'Bearer $token';
          }
          final dedupeKey = _prepareRequestDedupe(options);
          if (dedupeKey == null) {
            handler.next(options);
            return;
          }

          final pending = _inFlightGetRequests[dedupeKey];
          if (pending != null) {
            try {
              handler.resolve(await pending.future);
            } on DioException catch (pendingError) {
              handler.reject(pendingError);
            } catch (pendingError, stackTrace) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: pendingError,
                  stackTrace: stackTrace,
                ),
              );
            }
            return;
          }

          options.extra[_requestDedupeKeyExtra] = dedupeKey;
          final completer = Completer<Response<dynamic>>();
          completer.future.catchError(
            (_) => Response<dynamic>(requestOptions: options),
          );
          _inFlightGetRequests[dedupeKey] = completer;
          handler.next(options);
        },
        onResponse: (response, handler) {
          _completeRequestDedupe(response.requestOptions, response);
          handler.next(response);
        },
        onError: (error, handler) async {
          final skipAuthRefresh =
              error.requestOptions.extra['skipAuthRefresh'] == true;
          if (error.response?.statusCode == 401 &&
              !skipAuthRefresh &&
              error.requestOptions.extra['retried'] != true) {
            try {
              _debugAuthLog('Auth refresh started after 401');
              final tokens = await refreshTokens();
              final cloned = await _retry(
                error.requestOptions,
                tokens.accessToken,
              );
              _debugAuthLog('Auth refresh succeeded, retrying request');
              _completeRequestDedupe(error.requestOptions, cloned);
              handler.resolve(cloned);
              return;
            } catch (refreshError) {
              _debugAuthLog(
                'Auth refresh failed: ${refreshError.runtimeType}',
              );
              _completeRequestDedupeError(error.requestOptions, error);
              handler.next(error);
              return;
            }
          }

          _completeRequestDedupeError(error.requestOptions, error);
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final _inFlightGetRequests = <String, Completer<Response<dynamic>>>{};

  Dio get dio => _dio;

  Future<Response<dynamic>> _retry(
    RequestOptions requestOptions,
    String accessToken,
  ) {
    final retryExtra = {
      ...requestOptions.extra,
      'retried': true,
    }..remove(_requestDedupeKeyExtra);
    final options = Options(
      method: requestOptions.method,
      connectTimeout: requestOptions.connectTimeout,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      followRedirects: requestOptions.followRedirects,
      maxRedirects: requestOptions.maxRedirects,
      persistentConnection: requestOptions.persistentConnection,
      requestEncoder: requestOptions.requestEncoder,
      responseDecoder: requestOptions.responseDecoder,
      listFormat: requestOptions.listFormat,
      headers: {
        ...requestOptions.headers,
        'authorization': 'Bearer $accessToken',
      },
      extra: retryExtra,
    );

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
      cancelToken: requestOptions.cancelToken,
    );
  }

  String? _prepareRequestDedupe(RequestOptions options) {
    if (!_canDedupeRequest(options)) {
      return null;
    }

    return _requestDedupeKey(options);
  }

  bool _canDedupeRequest(RequestOptions options) {
    return options.method.toUpperCase() == 'GET' &&
        options.cancelToken == null &&
        options.extra['skipRequestDeduplication'] != true &&
        options.extra['retried'] != true &&
        options.responseType != ResponseType.stream;
  }

  String _requestDedupeKey(RequestOptions options) {
    final uriWithoutQuery = options.uri.replace(query: '').toString();
    final query = _stableEncode(options.queryParameters);
    final authHeader = options.headers['authorization']?.toString() ?? '';
    final authScope = '${authHeader.length}:${authHeader.hashCode}';
    return '${options.method.toUpperCase()} $uriWithoutQuery?$query auth=$authScope';
  }

  String _stableEncode(Object? value) {
    if (value is Map) {
      final normalized = <String, Object?>{};
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      for (final key in keys) {
        normalized[key] = _normalizeForStableEncode(value[key]);
      }
      return jsonEncode(normalized);
    }

    return jsonEncode(_normalizeForStableEncode(value));
  }

  Object? _normalizeForStableEncode(Object? value) {
    if (value is Map) {
      final normalized = <String, Object?>{};
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      for (final key in keys) {
        normalized[key] = _normalizeForStableEncode(value[key]);
      }
      return normalized;
    }
    if (value is Iterable) {
      return value.map(_normalizeForStableEncode).toList(growable: false);
    }
    return value;
  }

  void _completeRequestDedupe(
    RequestOptions requestOptions,
    Response<dynamic> response,
  ) {
    final key = requestOptions.extra[_requestDedupeKeyExtra] as String?;
    if (key == null) {
      return;
    }

    final completer = _inFlightGetRequests.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  void _completeRequestDedupeError(
    RequestOptions requestOptions,
    DioException error,
  ) {
    final key = requestOptions.extra[_requestDedupeKeyExtra] as String?;
    if (key == null) {
      return;
    }

    final completer = _inFlightGetRequests.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error, error.stackTrace);
    }
  }
}

void _debugAuthLog(String message) {
  if (kDebugMode || kProfileMode) {
    debugPrint(message);
  }
}
