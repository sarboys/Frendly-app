import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile2/app/core/auth/social_auth_session_reset.dart';
import 'package:mobile2/app/core/config/backend_config.dart';
import 'package:mobile2/app/core/device/app_push_token_service.dart';
import 'package:mobile2/app/core/local_cache/app_cache_key.dart';
import 'package:mobile2/app/core/local_cache/app_local_cache_store.dart';
import 'package:mobile2/app/core/local_cache/local_first_repository.dart';
import 'package:mobile2/app/core/network/chat_socket_client.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/payments/application/apple_iap_purchase_controller.dart';
import 'package:mobile2/features/payments/application/in_app_purchase_apple_iap_gateway.dart';
import 'package:mobile2/shared/data/affiche_client_geo_enrichment_service.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef CardPage = BackendPage<BackendCardItem>;
typedef SafetyReportPage = BackendPage<SafetyReportData>;
typedef BlockedUserPage = BackendPage<BlockedUserData>;

final reportedEventIdsProvider =
    StateProvider<Set<String>>((ref) => const <String>{});

final afficheClientGeoEnrichmentServiceProvider =
    Provider<AfficheClientGeoEnrichmentService>((ref) {
  return AfficheClientGeoEnrichmentService(
    searcher: const YandexMapKitAffichePlaceSearcher(),
    backendSaver: (request, {cancelToken}) {
      return ref.read(backendRepositoryProvider).saveAfficheClientGeo(
            request,
            cancelToken: cancelToken,
          );
    },
    cacheStore: ref.watch(appLocalCacheStoreProvider),
    userScope: ref.watch(currentCacheScopeProvider),
  );
});

enum ChatListKind { all, meetups, personal, communities, archive, unread }

const nearbyEventsDefaultRadiusKm = 50.0;
const nearbyEventsMaxRadiusKm = 150.0;
const _nearbyEventsRadiusStorageKey = 'events.nearby.radius.v1';

final nearbyEventsRadiusKmProvider =
    StateNotifierProvider<NearbyEventsRadiusController, double>(
  (ref) => NearbyEventsRadiusController(
    ref.read(sharedPreferencesProvider),
  ),
);

class NearbyEventsRadiusController extends StateNotifier<double> {
  NearbyEventsRadiusController(this._preferences)
      : super(
          clampNearbyEventsRadiusKm(
            _preferences?.getDouble(_nearbyEventsRadiusStorageKey) ??
                nearbyEventsDefaultRadiusKm,
          ),
        );

  final SharedPreferences? _preferences;

  void setRadiusKm(double value) {
    final next = clampNearbyEventsRadiusKm(value);
    if (state == next) {
      return;
    }
    state = next;
    unawaited(_preferences?.setDouble(_nearbyEventsRadiusStorageKey, next));
  }
}

double clampNearbyEventsRadiusKm(double value) {
  return value.clamp(1, nearbyEventsMaxRadiusKm).toDouble();
}

class EventListQuery {
  const EventListQuery({
    this.city,
    this.filter,
    this.query,
    this.lifestyle,
    this.price,
    this.gender,
    this.access,
    this.requiresVerification = false,
    this.requiresFrendlyPlus = false,
    this.sort,
    this.date,
    this.limit = 20,
  });

  final String? city;
  final String? filter;
  final String? query;
  final String? lifestyle;
  final String? price;
  final String? gender;
  final String? access;
  final bool requiresVerification;
  final bool requiresFrendlyPlus;
  final String? sort;
  final String? date;
  final int limit;

  String cacheValue({String? resolvedCity}) {
    return [
      'limit=$limit',
      if ((resolvedCity ?? city) != null && (resolvedCity ?? city)!.isNotEmpty)
        'city=${resolvedCity ?? city}',
      if (filter != null && filter!.isNotEmpty) 'filter=$filter',
      if (query != null && query!.isNotEmpty) 'q=$query',
      if (lifestyle != null && lifestyle!.isNotEmpty) 'lifestyle=$lifestyle',
      if (price != null && price!.isNotEmpty) 'price=$price',
      if (gender != null && gender!.isNotEmpty) 'gender=$gender',
      if (access != null && access!.isNotEmpty) 'access=$access',
      if (requiresVerification) 'requiresVerification=true',
      if (requiresFrendlyPlus) 'requiresFrendlyPlus=true',
      if (sort != null && sort!.isNotEmpty) 'sort=$sort',
      if (date != null && date!.isNotEmpty) 'date=$date',
    ].join('&');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EventListQuery &&
            other.city == city &&
            other.filter == filter &&
            other.query == query &&
            other.lifestyle == lifestyle &&
            other.price == price &&
            other.gender == gender &&
            other.access == access &&
            other.requiresVerification == requiresVerification &&
            other.requiresFrendlyPlus == requiresFrendlyPlus &&
            other.sort == sort &&
            other.date == date &&
            other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
        filter,
        city,
        query,
        lifestyle,
        price,
        gender,
        access,
        requiresVerification,
        requiresFrendlyPlus,
        sort,
        date,
        limit,
      );
}

class BackendActionException implements Exception {
  const BackendActionException({
    required this.message,
    this.code,
    this.details,
  });

  final String message;
  final String? code;
  final Map<String, Object?>? details;

  factory BackendActionException.fromDio(DioException error) {
    final data = error.response?.data;
    final code = data is Map ? data['code']?.toString() : null;
    final rawDetails = data is Map ? data['details'] : null;
    final backendMessage = data is Map
        ? data['message']?.toString() ?? 'Backend request failed'
        : 'Backend request failed';
    final message = _friendlyBackendActionMessage(
      code: code,
      details: rawDetails is Map
          ? rawDetails.map((key, value) => MapEntry(key.toString(), value))
          : null,
      fallback: backendMessage,
      errorType: error.type,
      hasResponse: error.response != null,
    );
    return BackendActionException(
      message: message,
      code: code,
      details: rawDetails is Map
          ? rawDetails.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }

  @override
  String toString() {
    return code == null ? message : '$message ($code)';
  }
}

String _friendlyBackendActionMessage({
  required String? code,
  required Map<String, Object?>? details,
  required String fallback,
  required DioExceptionType errorType,
  required bool hasResponse,
}) {
  switch (code) {
    case 'event_weekly_limit_reached':
      final limit = details?['limit'];
      if (limit is int && limit > 0) {
        return 'Лимит встреч на неделю: $limit. Нужен Frendly+ или новая неделя';
      }
      return 'Лимит встреч на неделю исчерпан';
    case 'evening_ai_candidates_not_found':
      return 'Не нашёл подходящие места под запрос';
    case 'evening_ai_exact_place_not_available':
      if (fallback.isNotEmpty && fallback != 'Backend request failed') {
        return fallback;
      }
      final requestedName = details?['requestedName']?.toString();
      if (requestedName != null && requestedName.isNotEmpty) {
        return 'Место «$requestedName» пока не подключено к партнерской программе';
      }
      return 'Это место пока не подключено к партнерской программе';
    case 'evening_ai_regenerate_candidates_exhausted':
      return 'Нет другой подходящей замены';
    case 'apple_auth_unavailable':
      return 'Вход через Apple не настроен на сервере';
    case 'invalid_apple_token':
      return 'Apple не подтвердил вход. Попробуй ещё раз';
  }

  if (!hasResponse ||
      fallback == 'Backend request failed' ||
      errorType == DioExceptionType.connectionTimeout ||
      errorType == DioExceptionType.sendTimeout ||
      errorType == DioExceptionType.receiveTimeout ||
      errorType == DioExceptionType.connectionError) {
    return 'Backend не ответил. Попробуй ещё раз';
  }

  return fallback;
}

final homeEventsProvider =
    homeEventsQueryProvider(const EventListQuery(limit: 6));

CardPage _withoutReportedEvents(CardPage page, Set<String> reportedEventIds) {
  if (reportedEventIds.isEmpty) {
    return page;
  }
  final items = page.items
      .where((item) => !reportedEventIds.contains(item.id))
      .toList(growable: false);
  if (items.length == page.items.length) {
    return page;
  }
  return BackendPage(
    items: items,
    nextCursor: page.nextCursor,
    raw: page.raw,
  );
}

final homeEventsQueryProvider =
    StreamProvider.autoDispose.family<CardPage, EventListQuery>((ref, query) {
  final city = query.city ?? _currentCity(ref);
  final reportedEventIds = ref.watch(reportedEventIdsProvider);
  return _localFirstPageStream(
    ref,
    namespace: 'events',
    cacheValue: 'home?${query.cacheValue(resolvedCity: city)}',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchEvents(
      city: city,
      filter: query.filter,
      query: query.query,
      lifestyle: query.lifestyle,
      price: query.price,
      gender: query.gender,
      access: query.access,
      requiresVerification: query.requiresVerification,
      requiresFrendlyPlus: query.requiresFrendlyPlus,
      sort: query.sort,
      date: query.date,
      limit: query.limit,
      cancelToken: cancelToken,
    ),
  ).map((page) => _withoutReportedEvents(page, reportedEventIds));
});

final meetingsProvider = meetingsQueryProvider(const EventListQuery(limit: 20));

final meetingsQueryProvider =
    StreamProvider.autoDispose.family<CardPage, EventListQuery>((ref, query) {
  final city = query.city ?? _currentCity(ref);
  final reportedEventIds = ref.watch(reportedEventIdsProvider);
  return _localFirstPageStream(
    ref,
    namespace: 'events',
    cacheValue: 'meetings?${query.cacheValue(resolvedCity: city)}',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchEvents(
      city: city,
      filter: query.filter,
      query: query.query,
      lifestyle: query.lifestyle,
      price: query.price,
      gender: query.gender,
      access: query.access,
      requiresVerification: query.requiresVerification,
      requiresFrendlyPlus: query.requiresFrendlyPlus,
      sort: query.sort,
      date: query.date,
      limit: query.limit,
      cancelToken: cancelToken,
    ),
  ).map((page) => _withoutReportedEvents(page, reportedEventIds));
});

final meetingsPaginationProvider = StateNotifierProvider.autoDispose.family<
    MeetingsPaginationController,
    MeetingsPaginationState,
    EventListQuery>((ref, query) {
  return MeetingsPaginationController(ref, query);
});

class MeetingsPaginationState {
  const MeetingsPaginationState({
    this.items = const [],
    this.nextCursor,
    this.loading = false,
    this.error = false,
    this.initialized = false,
  });

  final List<BackendCardItem> items;
  final String? nextCursor;
  final bool loading;
  final bool error;
  final bool initialized;

  bool get hasNextPage => nextCursor != null && nextCursor!.isNotEmpty;

  MeetingsPaginationState copyWith({
    List<BackendCardItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loading,
    bool? error,
    bool? initialized,
  }) {
    return MeetingsPaginationState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      initialized: initialized ?? this.initialized,
    );
  }
}

class MeetingsPaginationController
    extends StateNotifier<MeetingsPaginationState> {
  MeetingsPaginationController(this._ref, this._query)
      : super(const MeetingsPaginationState()) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final EventListQuery _query;
  final Set<CancelToken> _tokens = {};

  void primeNextCursor(String? cursor) {
    if (state.items.isNotEmpty || state.loading) {
      return;
    }
    if (state.initialized && state.nextCursor == cursor) {
      return;
    }
    state = state.copyWith(
      nextCursor: cursor,
      clearNextCursor: cursor == null || cursor.isEmpty,
      error: false,
      initialized: true,
    );
  }

  Future<void> loadNextPage() async {
    final cursor = state.nextCursor;
    if (state.loading || cursor == null || cursor.isEmpty) {
      return;
    }
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    state = state.copyWith(loading: true, error: false);
    try {
      final city = _query.city ?? _currentCity(_ref);
      final page = await _ref.read(backendRepositoryProvider).fetchEvents(
            city: city,
            filter: _query.filter,
            query: _query.query,
            lifestyle: _query.lifestyle,
            price: _query.price,
            gender: _query.gender,
            access: _query.access,
            requiresVerification: _query.requiresVerification,
            requiresFrendlyPlus: _query.requiresFrendlyPlus,
            sort: _query.sort,
            date: _query.date,
            limit: _query.limit,
            cursor: cursor,
            cancelToken: cancelToken,
          );
      final reportedEventIds = _ref.read(reportedEventIdsProvider);
      final visibleItems = reportedEventIds.isEmpty
          ? page.items
          : page.items
              .where((item) => !reportedEventIds.contains(item.id))
              .toList(growable: false);
      state = state.copyWith(
        items: [...state.items, ...visibleItems],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null || page.nextCursor!.isEmpty,
        loading: false,
        error: false,
      );
    } catch (_) {
      if (!cancelToken.isCancelled) {
        state = state.copyWith(loading: false, error: true);
      }
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

final meetingDetailProvider =
    StreamProvider.autoDispose.family<BackendCardItem, String>((ref, id) {
  return _localFirstValueStream<BackendCardItem>(
    ref,
    namespace: 'events',
    cacheValue: 'detail:media-v2:$id',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchEventDetail(
      id,
      cancelToken: cancelToken,
    ),
    encode: (event) => event.raw,
    decode: BackendCardItem.fromJson,
    useCached: _canUseCachedMeetingDetail,
  );
});

final ownProfileProvider = FutureProvider.autoDispose<BackendCardItem>((ref) {
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final repository = ref.read(backendRepositoryProvider);
  if (localFirst == null) {
    return repository.fetchOwnProfile(cancelToken: cancelToken);
  }
  return localFirst.fetch<BackendCardItem>(
    key: AppCacheKey(
      namespace: 'profile',
      value: 'me',
      userScope: ref.watch(currentCacheScopeProvider),
    ),
    ttl: const Duration(minutes: 5),
    network: () async {
      final profile = await repository.fetchOwnProfile(
        cancelToken: cancelToken,
      );
      return profile.raw;
    },
    decode: BackendCardItem.fromJson,
  );
});

final onboardingProvider = FutureProvider.autoDispose<OnboardingData>((ref) {
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final repository = ref.read(backendRepositoryProvider);
  if (localFirst == null) {
    return repository.fetchOnboarding(cancelToken: cancelToken);
  }
  return localFirst.fetch<OnboardingData>(
    key: AppCacheKey(
      namespace: 'onboarding',
      value: 'me',
      userScope: ref.watch(currentCacheScopeProvider),
    ),
    ttl: const Duration(minutes: 5),
    network: () async {
      final onboarding = await repository.fetchOnboarding(
        cancelToken: cancelToken,
      );
      return onboarding.raw;
    },
    decode: OnboardingData.fromJson,
  );
});

final onboardingFlowControllerProvider = Provider<OnboardingFlowController>(
  OnboardingFlowController.new,
);

final appSettingsProvider = FutureProvider.autoDispose<AppSettingsData>((ref) {
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final repository = ref.read(backendRepositoryProvider);
  if (localFirst == null) {
    return repository.fetchSettings(cancelToken: cancelToken);
  }
  return localFirst.fetch<AppSettingsData>(
    key: AppCacheKey(
      namespace: 'settings',
      value: 'me',
      userScope: ref.watch(currentCacheScopeProvider),
    ),
    ttl: const Duration(minutes: 5),
    network: () async {
      final settings = await repository.fetchSettings(cancelToken: cancelToken);
      return settings.raw;
    },
    decode: AppSettingsData.fromJson,
  );
});

final safetyProvider = FutureProvider.autoDispose<SafetyData>((ref) {
  return _privateValueFuture<SafetyData>(
    ref,
    fallback: const SafetyData(
      trustScore: 0,
      settings: AppSettingsData(),
    ),
    namespace: 'safety',
    cacheValue: 'me',
    ttl: const Duration(minutes: 5),
    fetch: (repository, cancelToken) => repository.fetchSafety(
      cancelToken: cancelToken,
    ),
    encode: (safety) => safety.raw,
    decode: SafetyData.fromJson,
  );
});

final settingsActionsProvider = Provider<SettingsActionsController>(
  SettingsActionsController.new,
);

final authActionsProvider = Provider<AuthActionsController>(
  AuthActionsController.new,
);

class SettingsActionsController {
  SettingsActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<AppSettingsData> update(Map<String, Object?> data) async {
    final cancelToken = _trackToken();
    try {
      final settings =
          await _ref.read(backendRepositoryProvider).updateSettings(
                data,
                cancelToken: cancelToken,
              );
      _ref.invalidate(appSettingsProvider);
      return settings;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> setPushEnabled(bool enabled) async {
    final pushTokenService = _ref.read(appPushTokenServiceProvider);
    final cancelToken = _trackToken();
    try {
      final repository = _ref.read(backendRepositoryProvider);
      if (enabled) {
        final token = await pushTokenService.registerDeviceToken();
        if (token == null) {
          throw const BackendActionException(message: 'push_unavailable');
        }
        await repository.registerPushToken(
          token: token.token,
          provider: token.provider,
          deviceId: token.deviceId,
          platform: token.platform,
          cancelToken: cancelToken,
        );
        await update({'allowPush': true});
      } else {
        final deviceId = await pushTokenService.currentDeviceId();
        if (deviceId != null && deviceId.isNotEmpty) {
          await repository.deletePushTokenByDeviceId(
            deviceId,
            cancelToken: cancelToken,
          );
        }
        await pushTokenService.clearRegisteredToken();
        await update({'allowPush': false});
      }
      await _ref
          .read(sharedPreferencesProvider)
          ?.setBool(pushNotificationsEnabledStorageKey, enabled);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> logout() async {
    final userId = _ref.read(currentUserIdProvider);
    final repository = _ref.read(backendRepositoryProvider);
    final pushTokenService = _ref.read(appPushTokenServiceProvider);
    final deviceId = await pushTokenService.currentDeviceId();
    final cancelToken = _trackToken();
    try {
      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          await repository.deletePushTokenByDeviceId(
            deviceId,
            cancelToken: cancelToken,
          );
        } catch (_) {}
      }
      try {
        await repository.logout(cancelToken: cancelToken);
      } catch (_) {}
      await pushTokenService.clearRegisteredToken();
      await _ref.read(socialAuthSessionResetterProvider).reset();
      if (userId != null && userId.isNotEmpty) {
        await _ref
            .read(sessionCleanupControllerProvider)
            .clearPrivateUserData(userId);
      }
      await _ref.read(authTokensProvider.notifier).clear();
      _ref.read(currentUserProvider.notifier).state = null;
      await _ref
          .read(sharedPreferencesProvider)
          ?.setBool(pushNotificationsEnabledStorageKey, false);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class AuthActionsController {
  AuthActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};
  int _sessionReplacementGeneration = 0;

  Future<PhoneAuthChallenge> requestPhoneCode(String phone) async {
    final cancelToken = _trackToken();
    try {
      return await _ref.read(backendRepositoryProvider).requestPhoneCode(
            phone,
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<AuthSession> verifyPhone({
    required String challengeId,
    required String code,
  }) async {
    final cancelToken = _trackToken();
    try {
      final session = await _ref.read(backendRepositoryProvider).verifyPhone(
            challengeId: challengeId,
            code: code,
            cancelToken: cancelToken,
          );
      await _replaceAuthenticatedSession(session, cancelToken: cancelToken);
      return session;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<AuthSession> loginWithTestPhoneShortcut(String phone) async {
    final cancelToken = _trackToken();
    try {
      final session =
          await _ref.read(backendRepositoryProvider).loginWithTestPhoneShortcut(
                phone,
                cancelToken: cancelToken,
              );
      await _replaceAuthenticatedSession(session, cancelToken: cancelToken);
      return session;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<TelegramAuthStart> startTelegramAuth() async {
    final cancelToken = _trackToken();
    try {
      return await _ref.read(backendRepositoryProvider).startTelegramAuth(
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<AuthSession> verifyTelegramAuth({
    required String loginSessionId,
    required String code,
  }) async {
    final cancelToken = _trackToken();
    try {
      final session =
          await _ref.read(backendRepositoryProvider).verifyTelegramAuth(
                loginSessionId: loginSessionId,
                code: code,
                cancelToken: cancelToken,
              );
      await _replaceAuthenticatedSession(session, cancelToken: cancelToken);
      return session;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<AuthSession> verifyGoogleAuth({
    required String idToken,
  }) async {
    final cancelToken = _trackToken();
    try {
      final session =
          await _ref.read(backendRepositoryProvider).verifyGoogleAuth(
                idToken: idToken,
                cancelToken: cancelToken,
              );
      await _replaceAuthenticatedSession(session, cancelToken: cancelToken);
      return session;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<AuthSession> verifyYandexAuth({
    required String oauthToken,
  }) async {
    final cancelToken = _trackToken();
    try {
      final session =
          await _ref.read(backendRepositoryProvider).verifyYandexAuth(
                oauthToken: oauthToken,
                cancelToken: cancelToken,
              );
      await _replaceAuthenticatedSession(session, cancelToken: cancelToken);
      return session;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<AuthSession> verifyAppleAuth({
    required String identityToken,
    String? authorizationCode,
    String? fullName,
  }) async {
    final cancelToken = _trackToken();
    try {
      final session =
          await _ref.read(backendRepositoryProvider).verifyAppleAuth(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName,
                cancelToken: cancelToken,
              );
      await _replaceAuthenticatedSession(session, cancelToken: cancelToken);
      return session;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  Future<void> _replaceAuthenticatedSession(
    AuthSession session, {
    required CancelToken cancelToken,
  }) async {
    final generation = ++_sessionReplacementGeneration;
    await _ref.read(authTokensProvider.notifier).setTokens(session.tokens);

    try {
      final user = await _ref.read(backendRepositoryProvider).fetchMe(
            cancelToken: cancelToken,
          );
      final preparedUser = await prepareAuthenticatedUserForSession(_ref, user);
      if (!_isCurrentSessionReplacement(generation, session.tokens)) {
        return;
      }
      _ref.read(currentUserProvider.notifier).state = preparedUser;
    } on DioException {
      await _clearSessionIfCurrent(generation, session.tokens);
      rethrow;
    }
  }

  bool _isCurrentSessionReplacement(int generation, AuthTokens tokens) {
    final current = _ref.read(authTokensProvider);
    return generation == _sessionReplacementGeneration &&
        current?.accessToken == tokens.accessToken &&
        current?.refreshToken == tokens.refreshToken;
  }

  Future<void> _clearSessionIfCurrent(
    int generation,
    AuthTokens tokens,
  ) async {
    if (!_isCurrentSessionReplacement(generation, tokens)) {
      return;
    }
    await _ref.read(authTokensProvider.notifier).clear();
    _ref.read(currentUserProvider.notifier).state = null;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class OnboardingFlowController {
  OnboardingFlowController(this._ref);

  final Ref _ref;

  Future<OnboardingData> save(OnboardingData data) async {
    final OnboardingData saved;
    try {
      saved = await _ref.read(backendRepositoryProvider).saveOnboarding(
            data,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    }
    await _writeSavedOnboardingCache(saved);
    _ref.invalidate(onboardingProvider);
    _ref.invalidate(ownProfileProvider);
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId != null && currentUserId.isNotEmpty) {
      await _ref.read(sharedPreferencesProvider)?.setBool(
            completedOnboardingUserStorageKey(currentUserId),
            true,
          );
    }
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser != null) {
      _ref.read(currentUserProvider.notifier).state =
          _withCompletedOnboarding(currentUser, saved);
    }
    try {
      final user = await _ref.read(backendRepositoryProvider).fetchMe();
      await _ref.read(sharedPreferencesProvider)?.setBool(
            completedOnboardingUserStorageKey(user.id),
            true,
          );
      _ref.read(currentUserProvider.notifier).state =
          _withCompletedOnboarding(user, saved);
    } catch (_) {}
    return saved;
  }

  Future<void> _writeSavedOnboardingCache(OnboardingData saved) async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    try {
      await store.putJson(
        AppCacheKey(
          namespace: 'onboarding',
          value: 'me',
          userScope: _ref.read(currentCacheScopeProvider),
        ),
        saved.raw.isEmpty ? saved.toJson() : saved.raw,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
    } catch (_) {}
  }

  Future<void> checkContact({
    String? email,
    String? phoneNumber,
  }) async {
    try {
      await _ref.read(backendRepositoryProvider).checkOnboardingContact(
            email: email,
            phoneNumber: phoneNumber,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    }
  }
}

BackendUser _withCompletedOnboarding(BackendUser user, OnboardingData data) {
  return BackendUser(
    id: user.id,
    name: data.name ?? user.name,
    avatarUrl: user.avatarUrl,
    gender: data.gender ?? user.gender,
    onboardingComplete: true,
    city: data.city ?? user.city,
    raw: user.raw,
  );
}

final profileActionsProvider = Provider<ProfileActionsController>(
  ProfileActionsController.new,
);

final publicProfileActionsProvider = Provider<PublicProfileActionsController>(
  PublicProfileActionsController.new,
);

class PublicProfileActionsController {
  PublicProfileActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<Map<String, Object?>> createDirectChat(String userId) async {
    final cancelToken = _trackToken();
    try {
      return await _ref.read(backendRepositoryProvider).createDirectChat(
            userId,
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<ProfileSocialData> setLike(String userId, bool active) async {
    final cancelToken = _trackToken();
    try {
      final json =
          await _ref.read(backendRepositoryProvider).setProfileReaction(
                userId: userId,
                kind: 'like',
                active: active,
                cancelToken: cancelToken,
              );
      _ref.invalidate(publicUserProvider(userId));
      _ref.invalidate(profileSocialProvider(userId));
      return ProfileSocialData.fromJson(json);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<ProfileSocialData> setFollow(String userId, bool active) async {
    final cancelToken = _trackToken();
    try {
      final social =
          await _ref.read(backendRepositoryProvider).setProfileFollow(
                userId: userId,
                active: active,
                cancelToken: cancelToken,
              );
      _ref.invalidate(publicUserProvider(userId));
      _ref.invalidate(profileSocialProvider(userId));
      return social;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<ProfileSocialData> setFollowNotifications(
    String userId,
    bool enabled,
  ) async {
    final cancelToken = _trackToken();
    try {
      final social = await _ref
          .read(backendRepositoryProvider)
          .setProfileFollowNotifications(
            userId: userId,
            enabled: enabled,
            cancelToken: cancelToken,
          );
      _ref.invalidate(publicUserProvider(userId));
      _ref.invalidate(profileSocialProvider(userId));
      return social;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class ProfileActionsController {
  ProfileActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<void> updateCity(String city, {String? area}) async {
    final cancelToken = _trackToken();
    final data = <String, Object?>{'city': city};
    final cleanArea = area?.trim();
    if (cleanArea != null && cleanArea.isNotEmpty) {
      data['area'] = cleanArea;
    }
    try {
      await _ref.read(backendRepositoryProvider).updateOwnProfile(
            data: data,
            cancelToken: cancelToken,
          );
      await _clearProfileCache();
      _ref.invalidate(ownProfileProvider);
      final user = _ref.read(currentUserProvider);
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = BackendUser(
          id: user.id,
          name: user.name,
          avatarUrl: user.avatarUrl,
          gender: user.gender,
          onboardingComplete: user.onboardingComplete,
          city: city,
          raw: user.raw,
        );
      }
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> updateProfileAndInterests({
    required Map<String, Object?> profileData,
    required List<String> interests,
  }) async {
    final cancelToken = _trackToken();
    try {
      final repository = _ref.read(backendRepositoryProvider);
      final onboarding = _ref.read(onboardingProvider).valueOrNull ??
          await repository.fetchOnboarding(cancelToken: cancelToken);
      await repository.updateOwnProfile(
        data: profileData,
        cancelToken: cancelToken,
      );
      await _clearProfileCache();
      await repository.saveOnboarding(
        OnboardingData(
          intent: onboarding.intent,
          gender: onboarding.gender,
          birthDate: onboarding.birthDate,
          city: onboarding.city,
          area: onboarding.area,
          interests: interests,
          vibe: onboarding.vibe,
          bio: onboarding.bio,
          email: onboarding.email,
          phoneNumber: onboarding.phoneNumber,
        ),
        cancelToken: cancelToken,
      );
      await _clearOnboardingCache();
      _ref.invalidate(ownProfileProvider);
      _ref.invalidate(onboardingProvider);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<Map<String, Object?>> uploadProfilePhoto({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    final cancelToken = _trackToken();
    try {
      final result =
          await _ref.read(backendRepositoryProvider).uploadProfilePhotoFile(
                filePath: filePath,
                fileName: fileName,
                mimeType: mimeType,
                cancelToken: cancelToken,
              );
      await _clearProfileCache();
      _ref.invalidate(ownProfileProvider);
      final user = _ref.read(currentUserProvider);
      final url = _primaryUploadedProfilePhotoUrl(
        result,
        currentAvatarUrl: user?.avatarUrl,
      );
      if (user != null && url != null && url.isNotEmpty) {
        _ref.read(currentUserProvider.notifier).state = BackendUser(
          id: user.id,
          name: user.name,
          avatarUrl: url,
          gender: user.gender,
          onboardingComplete: user.onboardingComplete,
          city: user.city,
          raw: user.raw,
        );
      }
      return result;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> deleteProfilePhoto(String photoId) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).deleteProfilePhoto(
            photoId,
            cancelToken: cancelToken,
          );
      await _clearProfileCache();
      _ref.invalidate(ownProfileProvider);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> makePrimaryProfilePhoto(String photoId) async {
    final cancelToken = _trackToken();
    try {
      final result =
          await _ref.read(backendRepositoryProvider).makePrimaryProfilePhoto(
                photoId,
                cancelToken: cancelToken,
              );
      await _clearProfileCache();
      _ref.invalidate(ownProfileProvider);
      final user = _ref.read(currentUserProvider);
      final url = _profileAvatarUrlFromActionResult(result);
      if (user != null && url != null && url.isNotEmpty) {
        _ref.read(currentUserProvider.notifier).state = BackendUser(
          id: user.id,
          name: user.name,
          avatarUrl: url,
          gender: user.gender,
          onboardingComplete: user.onboardingComplete,
          city: user.city,
          raw: user.raw,
        );
      }
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> reorderProfilePhotos(List<String> photoIds) async {
    final cancelToken = _trackToken();
    try {
      final result =
          await _ref.read(backendRepositoryProvider).reorderProfilePhotos(
                photoIds,
                cancelToken: cancelToken,
              );
      await _clearProfileCache();
      _ref.invalidate(ownProfileProvider);
      final user = _ref.read(currentUserProvider);
      final url = _profileAvatarUrlFromActionResult(result);
      if (user != null && url != null && url.isNotEmpty) {
        _ref.read(currentUserProvider.notifier).state = BackendUser(
          id: user.id,
          name: user.name,
          avatarUrl: url,
          gender: user.gender,
          onboardingComplete: user.onboardingComplete,
          city: user.city,
          raw: user.raw,
        );
      }
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  Future<void> _clearProfileCache() {
    return _deleteLocalCacheKey(
      AppCacheKey(
        namespace: 'profile',
        value: 'me',
        userScope: _ref.read(currentCacheScopeProvider),
      ),
    );
  }

  Future<void> _clearOnboardingCache() {
    return _deleteLocalCacheKey(
      AppCacheKey(
        namespace: 'onboarding',
        value: 'me',
        userScope: _ref.read(currentCacheScopeProvider),
      ),
    );
  }

  Future<void> _deleteLocalCacheKey(AppCacheKey key) async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    await store.deleteKey(key);
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

String? _primaryUploadedProfilePhotoUrl(
  Map<String, Object?> result, {
  String? currentAvatarUrl,
}) {
  final photo = _objectMap(result['photo']);
  final order = _intValue(photo['order'] ?? photo['sortOrder']);
  final url = _stringUrl(
    photo['url'] ?? _objectMap(photo['media'])['url'] ?? result['url'],
  );

  if (order != null) {
    return order == 0 ? url : null;
  }
  final hasCurrentAvatar =
      currentAvatarUrl != null && currentAvatarUrl.isNotEmpty;
  return hasCurrentAvatar ? null : url;
}

String? _profileAvatarUrlFromActionResult(Map<String, Object?> result) {
  final direct = _stringUrl(
    result['avatarUrl'] ?? result['imageUrl'] ?? result['url'],
  );
  if (direct != null) {
    return direct;
  }
  final photos = result['photos'];
  if (photos is List && photos.isNotEmpty) {
    final firstPhoto = _objectMap(photos.first);
    return _stringUrl(
      firstPhoto['url'] ?? _objectMap(firstPhoto['media'])['url'],
    );
  }
  return null;
}

String? _stringUrl(Object? value) {
  final url = value?.toString();
  return url != null && url.isNotEmpty ? url : null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

final meetingActionsProvider = Provider<MeetingActionsController>(
  MeetingActionsController.new,
);

class MeetingActionsController {
  MeetingActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<BackendCardItem> setJoined({
    required String eventId,
    required bool joined,
    String? chatId,
  }) async {
    final cancelToken = _trackToken();
    try {
      final event = joined
          ? await _ref.read(backendRepositoryProvider).joinEvent(
                eventId,
                cancelToken: cancelToken,
              )
          : await _ref.read(backendRepositoryProvider).leaveEvent(
                eventId,
                cancelToken: cancelToken,
              );
      if (!joined) {
        await _deleteLocalChat(chatId ?? _stringOrNull(event.raw['chatId']));
      }
      _invalidateEvent(eventId);
      _ref.invalidate(hostDashboardProvider);
      return event;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> _deleteLocalChat(String? chatId) async {
    final resolvedChatId = chatId?.trim();
    if (resolvedChatId == null || resolvedChatId.isEmpty) {
      return;
    }
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null || store == null) {
      return;
    }
    try {
      await store.deleteChat(userId: userId, chatId: resolvedChatId);
      _ref.invalidate(chatSummaryProvider(resolvedChatId));
    } catch (_) {}
  }

  Future<BackendCardItem> setJoinRequested({
    required String eventId,
    required bool requested,
    String? note,
  }) async {
    final cancelToken = _trackToken();
    try {
      final event = requested
          ? await _ref.read(backendRepositoryProvider).createJoinRequest(
                eventId,
                note: note,
                cancelToken: cancelToken,
              )
          : await _ref.read(backendRepositoryProvider).cancelJoinRequest(
                eventId,
                cancelToken: cancelToken,
              );
      _invalidateEvent(eventId);
      return event;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> createEvent({
    required Map<String, Object?> data,
    required String idempotencyKey,
  }) async {
    final cancelToken = _trackToken();
    try {
      final communityId = data['communityId']?.toString().trim();
      final event = await _ref.read(backendRepositoryProvider).createEvent(
            data: data,
            idempotencyKey: idempotencyKey,
            cancelToken: cancelToken,
          );
      unawaited(_refreshAfterEventCreate(communityId));
      return event;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> _refreshAfterEventCreate(String? communityId) async {
    try {
      await _dropEventsCache();
      await _dropMapEventsCache(_ref);
      if (communityId != null && communityId.isNotEmpty) {
        await _dropCommunitiesCache();
      }
      _ref.invalidate(homeEventsProvider);
      _ref.invalidate(homeEventsQueryProvider);
      _ref.invalidate(meetingsProvider);
      _ref.invalidate(meetingsQueryProvider);
      _invalidateMapEvents(_ref);
      if (communityId != null && communityId.isNotEmpty) {
        _ref.invalidate(communityDetailProvider(communityId));
        _ref.invalidate(communitiesProvider);
        _ref.invalidate(communitiesQueryProvider);
      }
    } catch (_) {}
  }

  Future<TokenWalletData> boostEvent(
    String eventId, {
    String optionId = 'boost-24',
  }) async {
    final cancelToken = _trackToken();
    try {
      final wallet = await _ref.read(backendRepositoryProvider).createPromotion(
            targetKind: 'event',
            targetId: eventId,
            optionId: optionId,
            cancelToken: cancelToken,
          );
      _ref.invalidate(tokenWalletProvider);
      await _dropMapEventsCache(_ref);
      _invalidateMapEvents(_ref);
      _invalidateEvent(eventId);
      _ref.invalidate(hostDashboardProvider);
      return wallet;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> fetchHostedEvent(String eventId) async {
    final cancelToken = _trackToken();
    try {
      return await _ref.read(backendRepositoryProvider).fetchHostedEvent(
            eventId,
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> updateHostedEvent({
    required String eventId,
    required Map<String, Object?> data,
  }) async {
    final cancelToken = _trackToken();
    try {
      final event =
          await _ref.read(backendRepositoryProvider).updateHostedEvent(
                eventId,
                data: data,
                cancelToken: cancelToken,
              );
      await _dropEventsCache();
      _invalidateEvent(eventId);
      _ref.invalidate(hostDashboardProvider);
      return event;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> finishHostedEvent({
    required String eventId,
    required List<String> attendedUserIds,
  }) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).finishHostedEvent(
            eventId,
            attendedUserIds: attendedUserIds,
            cancelToken: cancelToken,
          );
      await _dropEventsCache();
      await _dropDropsCache();
      _invalidateEvent(eventId);
      _ref.invalidate(hostDashboardProvider);
      _ref.invalidate(dropsHomeProvider);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  void _invalidateEvent(String eventId) {
    _ref.invalidate(homeEventsProvider);
    _ref.invalidate(homeEventsQueryProvider);
    _ref.invalidate(meetingsProvider);
    _ref.invalidate(meetingsQueryProvider);
    _ref.invalidate(meetingDetailProvider(eventId));
    _ref.invalidate(chatListProvider);
    _ref.invalidate(chatsProvider);
  }

  Future<void> _dropEventsCache() async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    await store.deleteNamespace(
      namespace: 'events',
      userScope: currentCacheScope(_ref),
    );
  }

  Future<void> _dropDropsCache() async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    await store.deleteKey(
      AppCacheKey(
        namespace: 'drops',
        value: 'home',
        userScope: currentCacheScope(_ref),
      ),
    );
  }

  Future<void> _dropCommunitiesCache() async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    await store.deleteNamespace(
      namespace: _communitiesCacheNamespace,
      userScope: currentCacheScope(_ref),
    );
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

final routeTemplatesProvider = routeTemplatesByQueryProvider(null);

final routeTemplatesByQueryProvider =
    StreamProvider.autoDispose.family<CardPage, String?>((ref, query) {
  final city = _currentCity(ref);
  return _localFirstPageStream(
    ref,
    namespace: 'routes',
    cacheValue: 'templates?city=${city ?? ''}&q=${query ?? ''}&limit=20',
    ttl: const Duration(minutes: 10),
    fetch: (repository, cancelToken) => repository.fetchRoutes(
      city: city,
      query: query,
      limit: 20,
      cancelToken: cancelToken,
    ),
  );
});

final routeDetailProvider =
    FutureProvider.autoDispose.family<BackendCardItem, String>((ref, id) {
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final repository = ref.read(backendRepositoryProvider);
  if (localFirst == null) {
    return repository.fetchRouteDetail(id, cancelToken: cancelToken);
  }
  return localFirst.fetch<BackendCardItem>(
    key: AppCacheKey(
      namespace: 'routes',
      value: 'detail:$id',
      userScope: ref.watch(currentCacheScopeProvider),
    ),
    ttl: const Duration(minutes: 10),
    network: () async {
      final route = await repository.fetchRouteDetail(
        id,
        cancelToken: cancelToken,
      );
      return route.raw;
    },
    decode: BackendCardItem.fromJson,
  );
});

final matchesProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _privatePageStream(
    ref,
    namespace: 'matches',
    cacheValue: 'list?limit=10',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchMatches(
      cancelToken: cancelToken,
    ),
  );
});

class PostersQuery {
  const PostersQuery({
    this.city,
    this.query,
    this.date,
    this.dateFrom,
    this.dateTo,
    this.priceMode,
    this.category,
    this.limit = 20,
  });

  final String? city;
  final String? query;
  final String? date;
  final String? dateFrom;
  final String? dateTo;
  final String? priceMode;
  final String? category;
  final int limit;

  String cacheValueFor(String? resolvedCity) {
    return [
      'events',
      'city=${resolvedCity ?? city ?? ''}',
      'q=${query ?? ''}',
      'date=${date ?? ''}',
      'dateFrom=${dateFrom ?? ''}',
      'dateTo=${dateTo ?? ''}',
      'priceMode=${priceMode ?? ''}',
      'category=${category ?? ''}',
      'limit=$limit',
    ].join('&');
  }

  @override
  bool operator ==(Object other) {
    return other is PostersQuery &&
        other.city == city &&
        other.query == query &&
        other.date == date &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        other.priceMode == priceMode &&
        other.category == category &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
      city, query, date, dateFrom, dateTo, priceMode, category, limit);
}

final postersProvider = FutureProvider.autoDispose<CardPage>((ref) {
  return ref.watch(postersQueryProvider(const PostersQuery(limit: 8)).future);
});

final postersQueryProvider =
    StreamProvider.autoDispose.family<CardPage, PostersQuery>((ref, query) {
  final city = query.city ?? _currentCity(ref);
  return _localFirstPageStream(
    ref,
    namespace: 'affiche',
    cacheValue: query.cacheValueFor(city),
    ttl: const Duration(minutes: 10),
    fetch: (repository, cancelToken) => repository.fetchAffiche(
      city: city,
      query: query.query,
      limit: query.limit,
      date: query.date,
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
      priceMode: query.priceMode,
      category: query.category,
      cancelToken: cancelToken,
    ),
  );
});

final postersPaginationProvider = StateNotifierProvider.autoDispose
    .family<PostersPaginationController, PostersPaginationState, PostersQuery>(
        (ref, query) {
  return PostersPaginationController(ref, query);
});

class PostersPaginationState {
  const PostersPaginationState({
    this.items = const [],
    this.nextCursor,
    this.loading = false,
    this.error = false,
    this.initialized = false,
  });

  final List<BackendCardItem> items;
  final String? nextCursor;
  final bool loading;
  final bool error;
  final bool initialized;

  bool get hasNextPage => nextCursor != null && nextCursor!.isNotEmpty;

  PostersPaginationState copyWith({
    List<BackendCardItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loading,
    bool? error,
    bool? initialized,
  }) {
    return PostersPaginationState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      initialized: initialized ?? this.initialized,
    );
  }
}

class PostersPaginationController
    extends StateNotifier<PostersPaginationState> {
  PostersPaginationController(this._ref, this._query)
      : super(const PostersPaginationState()) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final PostersQuery _query;
  final Set<CancelToken> _tokens = {};

  void primeNextCursor(String? cursor) {
    if (state.items.isNotEmpty || state.loading) {
      return;
    }
    if (state.initialized && state.nextCursor == cursor) {
      return;
    }
    state = state.copyWith(
      nextCursor: cursor,
      clearNextCursor: cursor == null || cursor.isEmpty,
      error: false,
      initialized: true,
    );
  }

  Future<void> loadNextPage() async {
    final cursor = state.nextCursor;
    if (state.loading || cursor == null || cursor.isEmpty) {
      return;
    }
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    state = state.copyWith(loading: true, error: false);
    try {
      final city = _query.city ?? _currentCity(_ref);
      final page = await _ref.read(backendRepositoryProvider).fetchAffiche(
            city: city,
            query: _query.query,
            date: _query.date,
            dateFrom: _query.dateFrom,
            dateTo: _query.dateTo,
            priceMode: _query.priceMode,
            category: _query.category,
            limit: _query.limit,
            cursor: cursor,
            cancelToken: cancelToken,
          );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null || page.nextCursor!.isEmpty,
        loading: false,
        error: false,
      );
    } catch (_) {
      if (!cancelToken.isCancelled) {
        state = state.copyWith(loading: false, error: true);
      }
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

final posterDetailProvider =
    FutureProvider.autoDispose.family<BackendCardItem, String>((ref, id) {
  return _localFirstValueFuture<BackendCardItem>(
    ref,
    namespace: 'affiche',
    cacheValue: 'detail:$id',
    ttl: const Duration(minutes: 10),
    fetch: (repository, cancelToken) => repository.fetchAfficheDetail(
      id,
      cancelToken: cancelToken,
    ),
    encode: (event) => event.raw.isEmpty
        ? {
            'id': event.id,
            'title': event.title,
            'subtitle': event.subtitle,
            'imageUrl': event.imageUrl,
            'startsAt': event.startsAt?.toIso8601String(),
            'city': event.city,
            'latitude': event.latitude,
            'longitude': event.longitude,
          }
        : event.raw,
    decode: BackendCardItem.fromJson,
  );
});

class DatingDiscoverFilters {
  const DatingDiscoverFilters({
    this.gender,
    this.ageMin = 18,
    this.ageMax = 99,
    this.radiusKm = 500,
    this.interests = const [],
    this.verifiedOnly = false,
    this.frendlyPlusOnly = false,
    this.onlineOnly = false,
    this.newThisWeekOnly = false,
  });

  final String? gender;
  final int ageMin;
  final int ageMax;
  final int radiusKm;
  final List<String> interests;
  final bool verifiedOnly;
  final bool frendlyPlusOnly;
  final bool onlineOnly;
  final bool newThisWeekOnly;

  String get cacheValue {
    final sortedInterests = [...interests]..sort();
    return [
      'discover',
      if (gender != null && gender!.isNotEmpty) 'gender=$gender',
      'ageMin=$ageMin',
      'ageMax=$ageMax',
      'radiusKm=$radiusKm',
      'interests=${sortedInterests.join(',')}',
      'verifiedOnly=$verifiedOnly',
      'frendlyPlusOnly=$frendlyPlusOnly',
      'onlineOnly=$onlineOnly',
      'newThisWeekOnly=$newThisWeekOnly',
      'limit=10',
    ].join('&');
  }
}

final datingDiscoverFiltersProvider = StateProvider<DatingDiscoverFilters>(
  (_) => const DatingDiscoverFilters(),
);

final datingHandledProfileIdsProvider =
    StateNotifierProvider<DatingHandledProfileIdsController, Set<String>>(
  (ref) {
    ref.watch(currentUserIdProvider);
    return DatingHandledProfileIdsController();
  },
);

class DatingHandledProfileIdsController extends StateNotifier<Set<String>> {
  DatingHandledProfileIdsController() : super(const <String>{});

  void add(String profileId) {
    final cleanId = profileId.trim();
    if (cleanId.isEmpty || state.contains(cleanId)) {
      return;
    }
    state = {...state, cleanId};
  }

  void remove(String profileId) {
    final cleanId = profileId.trim();
    if (cleanId.isEmpty || !state.contains(cleanId)) {
      return;
    }
    state = state.where((id) => id != cleanId).toSet();
  }
}

final datingLimitsProvider =
    FutureProvider.autoDispose<DatingLimitsData>((ref) {
  return _privateValueFuture<DatingLimitsData>(
    ref,
    fallback: const DatingLimitsData(
      premium: false,
      hourlySwipes: DatingHourlySwipesData(
        unlimited: false,
        limit: 50,
        remaining: 50,
      ),
      superLikes: DatingLimitBucketData(
        freeLimit: 1,
        freeRemaining: 1,
        paidCost: 50,
      ),
      rewinds: DatingLimitBucketData(
        freeLimit: 0,
        freeRemaining: 0,
        paidCost: 25,
      ),
    ),
    namespace: 'dating',
    cacheValue: 'limits',
    ttl: const Duration(minutes: 1),
    fetch: (repository, cancelToken) => repository.fetchDatingLimits(
      cancelToken: cancelToken,
    ),
    encode: (limits) => limits.raw,
    decode: DatingLimitsData.fromJson,
  );
});

final chatsProvider = chatListProvider(ChatListKind.meetups);

final chatSummaryProvider = StreamProvider.autoDispose
    .family<BackendChatSummary?, String>((ref, chatId) async* {
  final userId = ref.read(currentUserIdProvider);
  final chatStore = ref.read(chatLocalStoreProvider);
  if (userId != null && chatStore != null) {
    unawaited(
      Future.wait([
        _chatListForKind(ref, ChatListKind.meetups),
        _chatListForKind(ref, ChatListKind.personal),
        _chatListForKind(ref, ChatListKind.communities),
      ]).catchError((_) => <BackendPage<BackendChatSummary>>[]),
    );
    yield* chatStore.watchSummary(userId: userId, chatId: chatId).map(
          (json) => json == null ? null : BackendChatSummary.fromJson(json),
        );
    return;
  }

  final pages = await Future.wait([
    _chatListForKind(ref, ChatListKind.meetups).catchError(
      (_) => const BackendPage<BackendChatSummary>(items: []),
    ),
    _chatListForKind(ref, ChatListKind.personal).catchError(
      (_) => const BackendPage<BackendChatSummary>(items: []),
    ),
    _chatListForKind(ref, ChatListKind.communities).catchError(
      (_) => const BackendPage<BackendChatSummary>(items: []),
    ),
  ]);
  for (final page in pages) {
    for (final summary in page.items) {
      if (summary.id == chatId) {
        yield summary;
        return;
      }
    }
  }
  yield null;
});

final chatListProvider = StreamProvider.autoDispose
    .family<BackendPage<BackendChatSummary>, ChatListKind>((ref, kind) {
  if (kind == ChatListKind.all || kind == ChatListKind.unread) {
    return _watchCombinedChatLists(ref, kind);
  }
  return _watchVisibleChatListForKind(ref, kind);
});

Future<BackendPage<BackendChatSummary>> _chatListForKind(
  Ref ref,
  ChatListKind kind,
) async {
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = CancelToken();
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    cancelToken.cancel();
  });
  final userId = ref.read(currentUserIdProvider);
  final chatStore = ref.read(chatLocalStoreProvider);
  final storeKind = switch (kind) {
    ChatListKind.personal => 'personal',
    ChatListKind.communities => 'communities',
    _ => 'meetups',
  };
  Future<BackendPage<BackendChatSummary>> fetchFresh() {
    return switch (kind) {
      ChatListKind.personal =>
        repository.fetchPersonalChats(cancelToken: cancelToken),
      ChatListKind.communities =>
        repository.fetchCommunityChats(cancelToken: cancelToken),
      _ => repository.fetchMeetupChats(cancelToken: cancelToken),
    };
  }

  Future<void> replaceCachedSummaries(
    BackendPage<BackendChatSummary> page,
  ) async {
    if (disposed || userId == null || chatStore == null) {
      return;
    }
    await chatStore.replaceSummaries(
      userId: userId,
      kind: storeKind,
      summaries: page.items.map((item) => item.raw).toList(),
    );
  }

  if (userId != null && chatStore != null) {
    final cached =
        await chatStore.watchSummaries(userId: userId, kind: storeKind).first;
    if (disposed) {
      return const BackendPage(items: []);
    }
    if (cached.isNotEmpty) {
      unawaited(fetchFresh().then((freshPage) async {
        if (disposed) {
          return;
        }
        final fresh = _withChatKind(freshPage, storeKind);
        await replaceCachedSummaries(fresh);
      }).catchError((_) {}));
      return BackendPage(
        items: _orderedChatSummaries(
          cached.map(BackendChatSummary.fromJson),
        ),
      );
    }
  }
  final fresh = _orderedChatPage(_withChatKind(await fetchFresh(), storeKind));
  if (!disposed) {
    try {
      await replaceCachedSummaries(fresh);
    } catch (_) {}
  }
  return fresh;
}

BackendPage<BackendChatSummary> _withChatKind(
  BackendPage<BackendChatSummary> page,
  String kind,
) {
  return BackendPage(
    items: page.items.map((item) {
      final raw = {
        ...item.raw,
        'kind': switch (kind) {
          'personal' => 'personal',
          'communities' => 'community',
          _ => 'meetup',
        },
      };
      return BackendChatSummary.fromJson(raw);
    }).toList(growable: false),
    nextCursor: page.nextCursor,
    raw: page.raw,
  );
}

Stream<BackendPage<BackendChatSummary>> _watchVisibleChatListForKind(
  Ref ref,
  ChatListKind kind,
) {
  return _watchChatListForKind(ref, kind).map(
    (page) => BackendPage(
      items: _visibleChatSummariesForKind(kind, page.items),
      nextCursor: page.nextCursor,
      raw: page.raw,
    ),
  );
}

Stream<BackendPage<BackendChatSummary>> _watchChatListForKind(
  Ref ref,
  ChatListKind kind,
) async* {
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = CancelToken();
  var disposed = false;
  try {
    final userId = ref.read(currentUserIdProvider);
    final chatStore = ref.read(chatLocalStoreProvider);
    final storeKind = _chatStoreKind(kind);

    Future<BackendPage<BackendChatSummary>> fetchFresh() {
      return switch (kind) {
        ChatListKind.personal =>
          repository.fetchPersonalChats(cancelToken: cancelToken),
        ChatListKind.communities =>
          repository.fetchCommunityChats(cancelToken: cancelToken),
        _ => repository.fetchMeetupChats(cancelToken: cancelToken),
      };
    }

    if (userId == null || chatStore == null) {
      yield _orderedChatPage(_withChatKind(await fetchFresh(), storeKind));
      return;
    }

    Future<bool> replaceCachedSummaries(
      BackendPage<BackendChatSummary> page,
    ) async {
      if (disposed) {
        return false;
      }
      try {
        await chatStore.replaceSummaries(
          userId: userId,
          kind: storeKind,
          summaries: page.items.map((item) => item.raw).toList(),
        );
        return !disposed;
      } catch (_) {
        return false;
      }
    }

    final cached =
        await chatStore.watchSummaries(userId: userId, kind: storeKind).first;
    if (cached.isEmpty) {
      final fresh = _withChatKind(await fetchFresh(), storeKind);
      final cachedFresh = await replaceCachedSummaries(fresh);
      if (!cachedFresh) {
        yield _orderedChatPage(fresh);
        return;
      }
    } else {
      unawaited(
        fetchFresh().then((freshPage) async {
          if (disposed) {
            return;
          }
          final fresh = _withChatKind(freshPage, storeKind);
          await replaceCachedSummaries(fresh);
        }).catchError((_) {}),
      );
    }

    yield* chatStore.watchSummaries(userId: userId, kind: storeKind).map(
          (rows) => BackendPage(
            items: _orderedChatSummaries(
              rows.map(BackendChatSummary.fromJson),
            ),
          ),
        );
  } finally {
    disposed = true;
    if (!cancelToken.isCancelled) {
      cancelToken.cancel();
    }
  }
}

Stream<BackendPage<BackendChatSummary>> _watchCombinedChatLists(
  Ref ref,
  ChatListKind kind,
) {
  late final StreamSubscription<BackendPage<BackendChatSummary>> meetupsSub;
  late final StreamSubscription<BackendPage<BackendChatSummary>> personalSub;
  late final StreamSubscription<BackendPage<BackendChatSummary>> communitiesSub;
  final controller = StreamController<BackendPage<BackendChatSummary>>();
  List<BackendChatSummary>? meetups;
  List<BackendChatSummary>? personal;
  List<BackendChatSummary>? communities;
  var canceled = false;

  void emitIfReady() {
    if (meetups == null && personal == null && communities == null) {
      return;
    }
    final items = [
      ...?meetups,
      ...?personal,
      ...?communities,
    ];
    final visibleItems = _visibleChatSummariesForKind(kind, items);
    controller.add(
      BackendPage(
        items: _orderedChatSummaries(visibleItems),
      ),
    );
  }

  controller.onListen = () {
    meetupsSub = _watchChatListForKind(ref, ChatListKind.meetups).listen(
      (page) {
        meetups = page.items;
        emitIfReady();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!canceled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
    );
    personalSub = _watchChatListForKind(ref, ChatListKind.personal).listen(
      (page) {
        personal = page.items;
        emitIfReady();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!canceled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
    );
    communitiesSub =
        _watchChatListForKind(ref, ChatListKind.communities).listen(
      (page) {
        communities = page.items;
        emitIfReady();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!canceled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
    );
  };
  controller.onCancel = () async {
    canceled = true;
    await Future.wait([
      meetupsSub.cancel().catchError((_) {}),
      personalSub.cancel().catchError((_) {}),
      communitiesSub.cancel().catchError((_) {}),
    ]);
  };
  return controller.stream;
}

String _chatStoreKind(ChatListKind kind) {
  return switch (kind) {
    ChatListKind.personal => 'personal',
    ChatListKind.communities => 'communities',
    _ => 'meetups',
  };
}

BackendPage<BackendChatSummary> _orderedChatPage(
  BackendPage<BackendChatSummary> page,
) {
  return BackendPage(
    items: _orderedChatSummaries(page.items),
    nextCursor: page.nextCursor,
    raw: page.raw,
  );
}

List<BackendChatSummary> _orderedChatSummaries(
  Iterable<BackendChatSummary> items,
) {
  final indexed = items
      .toList(growable: false)
      .asMap()
      .entries
      .map((entry) => (index: entry.key, item: entry.value))
      .toList(growable: false);
  indexed.sort((left, right) {
    final delta = _compareChatSummaries(left.item, right.item);
    if (delta != 0) {
      return delta;
    }
    return left.index - right.index;
  });
  return indexed.map((entry) => entry.item).toList(growable: false);
}

List<BackendChatSummary> _visibleChatSummariesForKind(
  ChatListKind kind,
  Iterable<BackendChatSummary> items,
) {
  final visible = switch (kind) {
    ChatListKind.archive => items.where(_isArchivedMeetupChat),
    ChatListKind.unread => items.where(
        (item) => item.unreadCount > 0 && !_isArchivedMeetupChat(item),
      ),
    ChatListKind.all => items.where((item) => !_isArchivedMeetupChat(item)),
    ChatListKind.meetups => items.where((item) => !_isArchivedMeetupChat(item)),
    ChatListKind.personal => items,
    ChatListKind.communities => items,
  };
  return _orderedChatSummaries(visible);
}

int _compareChatSummaries(
  BackendChatSummary left,
  BackendChatSummary right,
) {
  final pinnedDelta = _boolSortDelta(
    left: _chatIsPinned(left),
    right: _chatIsPinned(right),
  );
  if (pinnedDelta != 0) {
    return pinnedDelta;
  }

  final timeDelta = _chatSortTime(right).compareTo(_chatSortTime(left));
  if (timeDelta != 0) {
    return timeDelta;
  }

  final messageDelta = _boolSortDelta(
    left: _chatHasMessages(left),
    right: _chatHasMessages(right),
  );
  if (messageDelta != 0) {
    return messageDelta;
  }

  final unreadDelta = _boolSortDelta(
    left: _chatHasUnread(left),
    right: _chatHasUnread(right),
  );
  if (unreadDelta != 0) {
    return unreadDelta;
  }

  return 0;
}

bool _chatHasUnread(BackendChatSummary summary) => summary.unreadCount > 0;

bool _chatHasMessages(BackendChatSummary summary) {
  final raw = summary.raw;
  return _stringOrNull(raw['lastMessageId']) != null ||
      _stringOrNull(raw['lastMessageAt']) != null ||
      _stringOrNull(raw['lastMessage']) != null ||
      _stringOrNull(raw['preview']) != null;
}

int _boolSortDelta({required bool left, required bool right}) {
  return (right ? 1 : 0) - (left ? 1 : 0);
}

bool _chatIsPinned(BackendChatSummary summary) {
  return summary.raw['isPinned'] == true || summary.raw['pinned'] == true;
}

DateTime _chatSortTime(BackendChatSummary summary) {
  final raw = summary.raw;
  final values = [
    raw['lastMessageAt'],
    raw['updatedAt'],
    raw['createdAt'],
  ]
      .map((value) => DateTime.tryParse(value?.toString() ?? ''))
      .whereType<DateTime>();
  var latest = DateTime.fromMillisecondsSinceEpoch(0);
  for (final value in values) {
    if (value.isAfter(latest)) {
      latest = value;
    }
  }
  return latest;
}

bool _isArchivedMeetupChat(BackendChatSummary summary) {
  final kind = summary.kind == 'meetup' || summary.raw['kind'] == 'meetup';
  if (!kind) {
    return false;
  }
  final raw = summary.raw;
  return raw['phase'] == 'done' ||
      raw['meetupPhase'] == 'done' ||
      raw['status'] == 'done';
}

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<BackendChatMessage>, String>((ref, chatId) async* {
  final userId = ref.read(currentUserIdProvider);
  final chatStore = ref.read(chatLocalStoreProvider);
  if (userId != null && chatStore != null) {
    final repository = ref.read(backendRepositoryProvider);
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);
    Future<List<BackendChatMessage>> refreshMessages() async {
      final page = await repository.fetchChatMessages(
        chatId,
        cancelToken: cancelToken,
      );
      await chatStore.upsertMessages(
        userId: userId,
        chatId: chatId,
        messages: page.items.map((item) => item.raw).toList(),
      );
      ref
          .read(chatHistoryPaginationProvider(chatId).notifier)
          .setNextCursor(page.nextCursor);
      _prewarmChatAttachments(ref, page.items);
      final lastMessageId = _lastServerMessageId(page.items);
      if (lastMessageId != null) {
        unawaited(
          repository
              .markChatRead(
            chatId,
            messageId: lastMessageId,
            cancelToken: cancelToken,
          )
              .then((_) {
            return chatStore.markSummaryRead(userId: userId, chatId: chatId);
          }).catchError((_) {}),
        );
      }
      return page.items;
    }

    unawaited(
      refreshMessages().then<void>((_) {}).catchError((_) {}),
    );
    yield* chatStore.watchRecentMessages(userId: userId, chatId: chatId).map(
        (rows) => rows
            .map((json) => BackendChatMessage.fromJson(chatId, json))
            .toList(growable: false));
    return;
  }
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final page = await ref.read(backendRepositoryProvider).fetchChatMessages(
        chatId,
        cancelToken: cancelToken,
      );
  ref
      .read(chatHistoryPaginationProvider(chatId).notifier)
      .setNextCursor(page.nextCursor);
  yield page.items;
});

final chatOptimisticMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatOptimisticMessagesController, List<BackendChatMessage>, String>(
        (ref, chatId) {
  return ChatOptimisticMessagesController(chatId);
});

class ChatOptimisticMessagesController
    extends StateNotifier<List<BackendChatMessage>> {
  ChatOptimisticMessagesController(this.chatId) : super(const []);

  final String chatId;

  void upsert(Map<String, Object?> raw) {
    if (!mounted) {
      return;
    }
    final message = BackendChatMessage.fromJson(chatId, raw);
    final key = _optimisticKey(message);
    state = [
      for (final item in state)
        if (_optimisticKey(item) != key) item,
      message,
    ];
  }

  void patchByClientMessageId(
    String clientMessageId,
    Map<String, Object?> Function(Map<String, Object?> raw) patch,
  ) {
    if (!mounted) {
      return;
    }
    state = [
      for (final item in state)
        if (item.clientMessageId == clientMessageId)
          BackendChatMessage.fromJson(chatId, patch(item.raw))
        else
          item,
    ];
  }

  void remove({
    required String messageId,
    String? clientMessageId,
  }) {
    if (!mounted) {
      return;
    }
    state = [
      for (final item in state)
        if (item.id != messageId &&
            (clientMessageId == null ||
                clientMessageId.isEmpty ||
                item.clientMessageId != clientMessageId))
          item,
    ];
  }

  String _optimisticKey(BackendChatMessage message) {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      return clientMessageId;
    }
    return message.id;
  }
}

final chatHistoryPaginationProvider = StateNotifierProvider.autoDispose.family<
    ChatHistoryPaginationController,
    ChatHistoryPaginationState,
    String>((ref, chatId) {
  return ChatHistoryPaginationController(ref, chatId);
});

final chatMessageSenderProvider = Provider<ChatMessageSender>((ref) {
  return ChatMessageSender(ref);
});

final chatActionsProvider = Provider<ChatActions>((ref) {
  return ChatActions(ref);
});

final signedMediaUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.read(appAttachmentServiceProvider).resolveSignedUrl(path);
});

String? _lastServerMessageId(List<BackendChatMessage> messages) {
  for (var index = messages.length - 1; index >= 0; index -= 1) {
    final message = messages[index];
    if (!message.pending && message.id.isNotEmpty) {
      return message.id;
    }
  }
  return null;
}

class ChatHistoryPaginationState {
  const ChatHistoryPaginationState({
    this.nextCursor,
    this.loading = false,
    this.error = false,
  });

  final String? nextCursor;
  final bool loading;
  final bool error;

  bool get hasNextPage => nextCursor != null && nextCursor!.isNotEmpty;

  ChatHistoryPaginationState copyWith({
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loading,
    bool? error,
  }) {
    return ChatHistoryPaginationState(
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class ChatHistoryPaginationController
    extends StateNotifier<ChatHistoryPaginationState> {
  ChatHistoryPaginationController(this._ref, this._chatId)
      : super(const ChatHistoryPaginationState());

  final Ref _ref;
  final String _chatId;

  void setNextCursor(String? cursor) {
    state = state.copyWith(
      nextCursor: cursor,
      clearNextCursor: cursor == null || cursor.isEmpty,
      error: false,
    );
  }

  Future<void> loadNextPage() async {
    final cursor = state.nextCursor;
    if (state.loading || cursor == null || cursor.isEmpty) {
      return;
    }
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null || store == null) {
      return;
    }
    state = state.copyWith(loading: true, error: false);
    try {
      final page = await _ref.read(backendRepositoryProvider).fetchChatMessages(
            _chatId,
            cursor: cursor,
          );
      await store.upsertMessages(
        userId: userId,
        chatId: _chatId,
        messages: page.items.map((item) => item.raw).toList(),
      );
      _prewarmChatAttachments(_ref, page.items);
      state = state.copyWith(
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null || page.nextCursor!.isEmpty,
        loading: false,
        error: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: true);
    }
  }
}

void _prewarmChatAttachments(Ref ref, List<BackendChatMessage> messages) {
  final paths = _recentChatAttachmentWarmupPaths(messages);
  final service = ref.read(appAttachmentServiceProvider);
  unawaited(service.warmCache(paths.cacheFiles));
  unawaited(service.warmSignedUrls(paths.signedOnly));
}

_ChatAttachmentWarmupPaths _recentChatAttachmentWarmupPaths(
  List<BackendChatMessage> messages,
) {
  final candidates = <_ChatAttachmentWarmupCandidate>[];
  for (final message in messages.reversed) {
    candidates.addAll(
      _chatAttachmentWarmupCandidates(message.raw['attachments']),
    );
    if (candidates.length >= 6) {
      break;
    }
  }
  final selected = candidates.take(6);
  return _ChatAttachmentWarmupPaths(
    cacheFiles: selected
        .where((candidate) => candidate.warmFile)
        .map((candidate) => candidate.path)
        .toList(growable: false),
    signedOnly: selected
        .where((candidate) => !candidate.warmFile)
        .map((candidate) => candidate.path)
        .toList(growable: false),
  );
}

List<_ChatAttachmentWarmupCandidate> _chatAttachmentWarmupCandidates(
  Object? value,
) {
  final candidates = <_ChatAttachmentWarmupCandidate>[];
  if (value is! List) {
    return const [];
  }
  for (final raw in value.whereType<Map>()) {
    final attachment = raw.map((key, value) => MapEntry('$key', value));
    final status = attachment['status']?.toString();
    if (status != 'ready') {
      continue;
    }
    final mimeType = attachment['mimeType']?.toString() ?? '';
    final kind = attachment['kind']?.toString() ?? '';
    final fileName = attachment['fileName']?.toString() ?? '';
    final shouldWarm = mimeType.startsWith('image/') ||
        kind == 'image' ||
        kind == 'chat_attachment' && _looksLikeImageFileName(fileName);
    final shouldWarmSignedOnly =
        kind == 'chat_voice' || mimeType.startsWith('audio/');
    final path = attachment['downloadUrlPath']?.toString();
    if (path == null || path.isEmpty) {
      continue;
    }
    if (shouldWarm) {
      candidates.add(
        _ChatAttachmentWarmupCandidate(path: path, warmFile: true),
      );
    } else if (shouldWarmSignedOnly) {
      candidates.add(
        _ChatAttachmentWarmupCandidate(path: path, warmFile: false),
      );
    }
  }
  return candidates;
}

class _ChatAttachmentWarmupPaths {
  const _ChatAttachmentWarmupPaths({
    this.cacheFiles = const [],
    this.signedOnly = const [],
  });

  final Iterable<String> cacheFiles;
  final Iterable<String> signedOnly;
}

class _ChatAttachmentWarmupCandidate {
  const _ChatAttachmentWarmupCandidate({
    required this.path,
    required this.warmFile,
  });

  final String path;
  final bool warmFile;
}

bool _looksLikeImageFileName(String fileName) {
  final lower = fileName.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic');
}

final chatRealtimeProvider =
    Provider.autoDispose.family<ChatRealtimeSession?, String>((ref, chatId) {
  final userId = ref.watch(currentUserIdProvider);
  final tokens = ref.watch(authTokensProvider);
  final store = ref.watch(chatLocalStoreProvider);
  if (userId == null || tokens == null || store == null) {
    return null;
  }
  final transportFactory = ref.watch(chatSocketTransportFactoryProvider);
  final socketUri = Uri.parse(BackendConfig.chatWebSocketUrl);
  final transport = transportFactory(socketUri);
  final session = ChatRealtimeSession(
    transport: transport,
    store: store,
    userId: userId,
    chatId: chatId,
    accessToken: tokens.accessToken,
    reconnectTransportFactory: transportFactory,
    reconnectUri: socketUri,
    beforeFlushOutbox: (_) async {
      await ref.read(chatMediaUploadQueueProvider)?.processForChats(
            userId: userId,
          );
    },
    onNotificationCreated: (payload) {
      unawaited(
        ref
            .read(notificationsActionsProvider)
            .applyRealtimeNotificationCreated(payload),
      );
    },
  );
  unawaited(session.start());
  ref.onDispose(() => unawaited(session.close()));
  return session;
});

final chatListRealtimeProvider = Provider.autoDispose
    .family<ChatRealtimeSession?, ChatListKind>((ref, kind) {
  final chatIdKey = ref.watch(
    chatListProvider(kind).select(
      (value) => _chatRealtimeKey(value.valueOrNull?.items ?? const []),
    ),
  );
  if (chatIdKey.isEmpty) {
    return null;
  }
  final userId = ref.watch(currentUserIdProvider);
  final tokens = ref.watch(authTokensProvider);
  final store = ref.watch(chatLocalStoreProvider);
  if (userId == null || tokens == null || store == null) {
    return null;
  }

  final chatIds = chatIdKey.split(_chatRealtimeKeySeparator);
  final transportFactory = ref.watch(chatSocketTransportFactoryProvider);
  final socketUri = Uri.parse(BackendConfig.chatWebSocketUrl);
  final transport = transportFactory(socketUri);
  final session = ChatRealtimeSession(
    transport: transport,
    store: store,
    userId: userId,
    chatId: chatIds.first,
    chatIds: chatIds,
    accessToken: tokens.accessToken,
    reconnectTransportFactory: transportFactory,
    reconnectUri: socketUri,
    beforeFlushOutbox: (_) async {
      await ref.read(chatMediaUploadQueueProvider)?.processForChats(
            userId: userId,
          );
    },
    onNotificationCreated: (payload) {
      unawaited(
        ref
            .read(notificationsActionsProvider)
            .applyRealtimeNotificationCreated(payload),
      );
    },
  );
  unawaited(session.start());
  ref.onDispose(() => unawaited(session.close()));
  return session;
});

const _chatRealtimeKeySeparator = '\u001F';

String _chatRealtimeKey(Iterable<BackendChatSummary> items) {
  final ids = items
      .map((item) => item.id.trim())
      .where((id) => id.isNotEmpty)
      .take(50)
      .toSet()
      .toList(growable: false)
    ..sort();
  return ids.join(_chatRealtimeKeySeparator);
}

class ChatMessageSender {
  ChatMessageSender(this._ref);

  final Ref _ref;
  static const Duration _directSendTimeout = Duration(seconds: 12);

  Future<void> sendText({
    required String chatId,
    required String text,
    String? clientMessageId,
    Map<String, Object?>? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null) {
      throw StateError('Current user is unavailable');
    }
    final resolvedClientMessageId =
        clientMessageId ?? 'mobile2-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final user = _ref.read(currentUserProvider);
    Map<String, Object?> buildTextMessage(String status) => <String, Object?>{
          'chatId': chatId,
          'text': trimmed,
          'id': resolvedClientMessageId,
          'clientMessageId': resolvedClientMessageId,
          'senderId': userId,
          'sender': {
            'displayName': user?.name ?? 'Вы',
          },
          'createdAt': now.toIso8601String(),
          'pending': status != 'sent',
          'mine': true,
          'status': status,
          if (replyTo != null) 'replyTo': replyTo,
        };
    if (store == null) {
      final optimistic = _ref.read(
        chatOptimisticMessagesProvider(chatId).notifier,
      );
      optimistic.upsert(buildTextMessage('pending'));
      try {
        await _sendDirect(
          chatId: chatId,
          clientMessageId: resolvedClientMessageId,
          text: trimmed,
          replyToMessageId: _stringOrNull(replyTo?['id']),
        );
        optimistic.patchByClientMessageId(
          resolvedClientMessageId,
          (raw) => {
            ...raw,
            'pending': false,
            'status': 'sent',
          },
        );
      } catch (_) {
        optimistic.patchByClientMessageId(
          resolvedClientMessageId,
          (raw) => {
            ...raw,
            'pending': true,
            'status': 'failed',
          },
        );
        rethrow;
      }
      return;
    }
    await store.upsertMessages(
      userId: userId,
      chatId: chatId,
      messages: [buildTextMessage('pending')],
    );
    await store.enqueuePendingCommand(
      userId: userId,
      commandId: resolvedClientMessageId,
      dedupeKey: 'message.send:$chatId:$resolvedClientMessageId',
      payload: {
        'type': 'message.send',
        'payload': {
          'chatId': chatId,
          'text': trimmed,
          'clientMessageId': resolvedClientMessageId,
          if (_stringOrNull(replyTo?['id']) != null)
            'replyToMessageId': _stringOrNull(replyTo?['id']),
        },
      },
    );
  }

  Future<void> retryMessage({
    required String chatId,
    required String clientMessageId,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null || store == null) {
      return;
    }
    final message = await store.readMessageByClientMessageId(
      userId: userId,
      chatId: chatId,
      clientMessageId: clientMessageId,
    );
    if (message == null) {
      return;
    }
    final attachments = message['attachments'];
    if (attachments is List && attachments.isNotEmpty) {
      await store.retryPendingMediaUpload(
        userId: userId,
        uploadId: clientMessageId,
      );
      await store.patchMessageByClientMessageId(
        userId: userId,
        chatId: chatId,
        clientMessageId: clientMessageId,
        patch: (current) => {
          ...current,
          'pending': true,
          'status': 'uploading',
          'attachments': _withAttachmentStatus(
            current['attachments'],
            'uploading',
          ),
        },
      );
      final uploadQueue = _ref.read(chatMediaUploadQueueProvider);
      if (uploadQueue != null) {
        unawaited(
          (() async {
            await uploadQueue.processForChats(
              userId: userId,
              chatIds: [chatId],
            );
            unawaited(
              _ref.read(chatRealtimeProvider(chatId))?.flushOutbox() ??
                  Future<void>.value(),
            );
          })(),
        );
      }
      return;
    }
    final text = message['text']?.toString() ?? '';
    final location = _objectMap(message['location']);
    if (text.trim().isEmpty && location.isEmpty) {
      return;
    }
    await store.patchMessageByClientMessageId(
      userId: userId,
      chatId: chatId,
      clientMessageId: clientMessageId,
      patch: (current) => {
        ...current,
        'pending': true,
        'status': 'pending',
      },
    );
    await store.enqueuePendingCommand(
      userId: userId,
      commandId: clientMessageId,
      dedupeKey: 'message.send:$chatId:$clientMessageId',
      payload: {
        'type': 'message.send',
        'payload': {
          'chatId': chatId,
          if (text.trim().isNotEmpty) 'text': text.trim(),
          if (location.isNotEmpty) 'location': location,
          'clientMessageId': clientMessageId,
          if (_stringOrNull(message['replyTo'] is Map
                  ? (message['replyTo'] as Map)['id']
                  : null) !=
              null)
            'replyToMessageId': _stringOrNull(
              (message['replyTo'] as Map)['id'],
            ),
        },
      },
    );
    unawaited(
      _ref.read(chatRealtimeProvider(chatId))?.flushOutbox() ??
          Future<void>.value(),
    );
  }

  Future<void> sendLocation({
    required String chatId,
    required double latitude,
    required double longitude,
    String? label,
    Map<String, Object?>? replyTo,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null) {
      throw StateError('Current user is unavailable');
    }
    final clientMessageId = 'mobile2-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 15));
    final user = _ref.read(currentUserProvider);
    final location = <String, Object?>{
      'latitude': latitude,
      'longitude': longitude,
      if (_stringOrNull(label) != null) 'label': _stringOrNull(label),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    };
    Map<String, Object?> buildLocationMessage(String status) =>
        <String, Object?>{
          'chatId': chatId,
          'text': '',
          'id': clientMessageId,
          'clientMessageId': clientMessageId,
          'senderId': userId,
          'sender': {
            'displayName': user?.name ?? 'Вы',
          },
          'createdAt': now.toIso8601String(),
          'pending': status != 'sent',
          'mine': true,
          'status': status,
          'location': location,
          if (replyTo != null) 'replyTo': replyTo,
        };

    if (store == null) {
      final optimistic = _ref.read(
        chatOptimisticMessagesProvider(chatId).notifier,
      );
      optimistic.upsert(buildLocationMessage('pending'));
      try {
        await _sendDirect(
          chatId: chatId,
          clientMessageId: clientMessageId,
          location: location,
          replyToMessageId: _stringOrNull(replyTo?['id']),
        );
        optimistic.patchByClientMessageId(
          clientMessageId,
          (raw) => {
            ...raw,
            'pending': false,
            'status': 'sent',
          },
        );
      } catch (_) {
        optimistic.patchByClientMessageId(
          clientMessageId,
          (raw) => {
            ...raw,
            'pending': true,
            'status': 'failed',
          },
        );
        rethrow;
      }
      return;
    }

    await store.upsertMessages(
      userId: userId,
      chatId: chatId,
      messages: [buildLocationMessage('pending')],
    );
    await store.enqueuePendingCommand(
      userId: userId,
      commandId: clientMessageId,
      dedupeKey: 'message.send:$chatId:$clientMessageId',
      payload: {
        'type': 'message.send',
        'payload': {
          'chatId': chatId,
          'location': location,
          'clientMessageId': clientMessageId,
          if (_stringOrNull(replyTo?['id']) != null)
            'replyToMessageId': _stringOrNull(replyTo?['id']),
        },
      },
    );
  }

  Future<void> sendAttachment({
    required String chatId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String kind = 'chat_attachment',
    int? durationMs,
    List<double> waveform = const [],
    Map<String, Object?>? replyTo,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null) {
      throw StateError('Current user is unavailable');
    }
    final clientMessageId = 'mobile2-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final user = _ref.read(currentUserProvider);
    Map<String, Object?> buildMessage(Map<String, Object?> attachment) {
      final attachmentStatus = attachment['status']?.toString();
      return <String, Object?>{
        'id': clientMessageId,
        'chatId': chatId,
        'text': '',
        'clientMessageId': clientMessageId,
        'senderId': userId,
        'sender': {
          'displayName': user?.name ?? 'Вы',
        },
        'createdAt': now.toIso8601String(),
        'pending': attachmentStatus != null && attachmentStatus != 'ready',
        'mine': true,
        if (attachmentStatus != null && attachmentStatus.isNotEmpty)
          'status': attachmentStatus,
        if (replyTo != null) 'replyTo': replyTo,
        'attachments': [attachment],
      };
    }

    if (store == null) {
      final optimistic = _ref.read(
        chatOptimisticMessagesProvider(chatId).notifier,
      );
      final uploadingAttachment = {
        'id': 'local-$clientMessageId',
        'kind': kind,
        'status': 'uploading',
        'fileName': fileName,
        'mimeType': mimeType,
        'localPath': filePath,
        if (durationMs != null) 'durationMs': durationMs,
        if (waveform.isNotEmpty) 'waveform': waveform,
      };
      optimistic.upsert(buildMessage(uploadingAttachment));
      try {
        final asset =
            await _ref.read(backendRepositoryProvider).uploadChatAttachmentFile(
                  chatId: chatId,
                  filePath: filePath,
                  fileName: fileName,
                  mimeType: mimeType,
                  kind: kind,
                  durationMs: durationMs,
                  waveform: waveform,
                );
        final assetId = _stringOrNull(asset['assetId'] ?? asset['id']);
        if (assetId == null) {
          throw StateError('Attachment upload did not return assetId');
        }
        optimistic.upsert(
          buildMessage({
            ...uploadingAttachment,
            'id': assetId,
            'status': 'pending',
            'url': '/media/$assetId',
            'downloadUrlPath': '/media/$assetId/download-url',
          }),
        );
        await _sendDirect(
          chatId: chatId,
          clientMessageId: clientMessageId,
          attachmentIds: [assetId],
          replyToMessageId: _stringOrNull(replyTo?['id']),
        );
        optimistic.patchByClientMessageId(
          clientMessageId,
          (raw) => {
            ...raw,
            'pending': false,
            'status': 'sent',
            'attachments': _withAttachmentStatus(raw['attachments'], 'ready'),
          },
        );
      } catch (_) {
        optimistic.patchByClientMessageId(
          clientMessageId,
          (raw) => {
            ...raw,
            'pending': true,
            'status': 'failed',
            'attachments': _withAttachmentStatus(raw['attachments'], 'failed'),
          },
        );
        rethrow;
      }
      return;
    }

    String pendingPath;
    try {
      pendingPath =
          await _ref.read(appChatMediaFileStoreProvider).copyForPendingUpload(
                sourcePath: filePath,
                uploadId: clientMessageId,
                fileName: fileName,
              );
    } on FileSystemException {
      pendingPath = filePath;
      await store.upsertMessages(
        userId: userId,
        chatId: chatId,
        messages: [
          buildMessage({
            'id': 'local-$clientMessageId',
            'kind': kind,
            'status': 'failed',
            'fileName': fileName,
            'mimeType': mimeType,
            'localPath': pendingPath,
            if (durationMs != null) 'durationMs': durationMs,
            if (waveform.isNotEmpty) 'waveform': waveform,
          }),
        ],
      );
      await store.enqueuePendingMediaUpload(
        userId: userId,
        uploadId: clientMessageId,
        chatId: chatId,
        clientMessageId: clientMessageId,
        localPath: pendingPath,
        fileName: fileName,
        mimeType: mimeType,
        kind: kind,
        durationMs: durationMs,
        waveform: waveform,
      );
      await store.markPendingMediaUploadFailed(
        userId: userId,
        uploadId: clientMessageId,
        error: 'local_file_missing',
      );
      return;
    }

    final uploadingAttachment = {
      'id': 'local-$clientMessageId',
      'kind': kind,
      'status': 'uploading',
      'fileName': fileName,
      'mimeType': mimeType,
      'localPath': pendingPath,
      if (durationMs != null) 'durationMs': durationMs,
      if (waveform.isNotEmpty) 'waveform': waveform,
    };
    await store.upsertMessages(
      userId: userId,
      chatId: chatId,
      messages: [buildMessage(uploadingAttachment)],
    );
    Future<void> markUploadFailed() {
      return store.upsertMessages(
        userId: userId,
        chatId: chatId,
        messages: [
          buildMessage({
            ...uploadingAttachment,
            'status': 'failed',
          }),
        ],
      );
    }

    await store.enqueuePendingMediaUpload(
      userId: userId,
      uploadId: clientMessageId,
      chatId: chatId,
      clientMessageId: clientMessageId,
      localPath: pendingPath,
      fileName: fileName,
      mimeType: mimeType,
      kind: kind,
      durationMs: durationMs,
      waveform: waveform,
    );
    final uploadQueue = _ref.read(chatMediaUploadQueueProvider);
    if (uploadQueue != null) {
      unawaited(
        (() async {
          try {
            await uploadQueue.processForChats(
              userId: userId,
              chatIds: [chatId],
            );
            unawaited(
              _ref.read(chatRealtimeProvider(chatId))?.flushOutbox() ??
                  Future<void>.value(),
            );
          } catch (_) {
            await markUploadFailed();
          }
        })(),
      );
    }
  }

  Future<void> _sendDirect({
    required String chatId,
    required String clientMessageId,
    String text = '',
    List<String> attachmentIds = const [],
    Map<String, Object?>? location,
    String? replyToMessageId,
  }) async {
    final tokens = _ref.read(authTokensProvider);
    if (tokens == null || tokens.accessToken.isEmpty) {
      throw StateError('Chat auth token is unavailable');
    }
    final transport = _ref
        .read(chatSocketTransportFactoryProvider)
        .call(Uri.parse(BackendConfig.chatWebSocketUrl));
    final done = Completer<void>();
    StreamSubscription<Object?>? subscription;

    void completeError(Object error) {
      if (!done.isCompleted) {
        done.completeError(error);
      }
    }

    try {
      subscription = transport.stream.listen(
        (data) {
          final event = _decodeChatSocketEvent(data);
          if (event.isEmpty || done.isCompleted) {
            return;
          }
          final type = event['type']?.toString();
          final payload = _objectMap(event['payload']);
          if (type == 'session.authenticated') {
            transport.send(
              jsonEncode({
                'type': 'message.send',
                'payload': {
                  'chatId': chatId,
                  'clientMessageId': clientMessageId,
                  if (text.trim().isNotEmpty) 'text': text.trim(),
                  if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
                  if (location != null && location.isNotEmpty)
                    'location': location,
                  if (replyToMessageId != null && replyToMessageId.isNotEmpty)
                    'replyToMessageId': replyToMessageId,
                },
              }),
            );
            return;
          }
          if (type == 'message.created' &&
              payload['chatId']?.toString() == chatId &&
              payload['clientMessageId']?.toString() == clientMessageId) {
            done.complete();
            return;
          }
          if (type == 'error') {
            completeError(
              StateError(
                payload['message']?.toString() ?? 'Unable to send message',
              ),
            );
          }
        },
        onError: completeError,
        onDone: () {
          if (!done.isCompleted) {
            completeError(StateError('Chat socket closed before send ack'));
          }
        },
      );
      transport.send(
        jsonEncode({
          'type': 'session.authenticate',
          'payload': {'accessToken': tokens.accessToken},
        }),
      );
      await done.future.timeout(_directSendTimeout);
    } finally {
      await subscription?.cancel();
      await transport.close();
    }
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    String? clientMessageId,
    bool pending = false,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null) {
      throw StateError('Current user is unavailable');
    }
    if (store == null) {
      _ref.read(chatOptimisticMessagesProvider(chatId).notifier).remove(
            messageId: messageId,
            clientMessageId: clientMessageId,
          );
      if (pending) {
        return;
      }
      await _deleteDirect(chatId: chatId, messageId: messageId);
      return;
    }
    await store.deleteMessage(
      userId: userId,
      chatId: chatId,
      messageId: messageId,
      clientMessageId: clientMessageId,
    );
    final localCommandId =
        clientMessageId?.isNotEmpty == true ? clientMessageId! : messageId;
    if (pending) {
      await store.deletePendingCommand(
        userId: userId,
        commandId: localCommandId,
      );
      await store.deletePendingMediaUpload(
        userId: userId,
        uploadId: localCommandId,
      );
      return;
    }
    await store.enqueuePendingCommand(
      userId: userId,
      commandId: 'message.delete:$messageId',
      dedupeKey: 'message.delete:$chatId:$messageId',
      payload: {
        'type': 'message.delete',
        'payload': {
          'chatId': chatId,
          'messageId': messageId,
        },
      },
    );
    unawaited(
      _ref.read(chatRealtimeProvider(chatId))?.flushOutbox() ??
          Future<void>.value(),
    );
  }

  Future<void> _deleteDirect({
    required String chatId,
    required String messageId,
  }) async {
    final tokens = _ref.read(authTokensProvider);
    if (tokens == null || tokens.accessToken.isEmpty) {
      throw StateError('Chat auth token is unavailable');
    }
    final transport = _ref
        .read(chatSocketTransportFactoryProvider)
        .call(Uri.parse(BackendConfig.chatWebSocketUrl));
    final done = Completer<void>();
    StreamSubscription<Object?>? subscription;

    void completeError(Object error) {
      if (!done.isCompleted) {
        done.completeError(error);
      }
    }

    try {
      subscription = transport.stream.listen(
        (data) {
          final event = _decodeChatSocketEvent(data);
          if (event.isEmpty || done.isCompleted) {
            return;
          }
          final type = event['type']?.toString();
          final payload = _objectMap(event['payload']);
          if (type == 'session.authenticated') {
            transport.send(
              jsonEncode({
                'type': 'message.delete',
                'payload': {
                  'chatId': chatId,
                  'messageId': messageId,
                },
              }),
            );
            return;
          }
          if (type == 'message.deleted' &&
              payload['chatId']?.toString() == chatId &&
              payload['messageId']?.toString() == messageId) {
            done.complete();
            return;
          }
          if (type == 'error') {
            completeError(
              StateError(
                payload['message']?.toString() ?? 'Unable to delete message',
              ),
            );
          }
        },
        onError: completeError,
        onDone: () {
          if (!done.isCompleted) {
            completeError(StateError('Chat socket closed before delete ack'));
          }
        },
      );
      transport.send(
        jsonEncode({
          'type': 'session.authenticate',
          'payload': {'accessToken': tokens.accessToken},
        }),
      );
      await done.future.timeout(_directSendTimeout);
    } finally {
      await subscription?.cancel();
      await transport.close();
    }
  }
}

Map<String, Object?> _decodeChatSocketEvent(Object? data) {
  try {
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
  } catch (_) {}
  return const {};
}

List<Map<String, Object?>> _withAttachmentStatus(
  Object? value,
  String status,
) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map((attachment) {
    return {
      ...attachment.map((key, value) => MapEntry('$key', value)),
      'status': status,
    };
  }).toList(growable: false);
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const {};
}

class ChatActions {
  ChatActions(this._ref);

  final Ref _ref;

  Future<void> setPinned({
    required String chatId,
    required bool isPinned,
  }) async {
    await _ref.read(backendRepositoryProvider).setChatPinned(
          chatId,
          isPinned: isPinned,
        );
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId != null && store != null) {
      await store.setSummaryPinned(
        userId: userId,
        chatId: chatId,
        isPinned: isPinned,
      );
    }
    _ref.invalidate(chatListProvider);
    _ref.invalidate(chatSummaryProvider(chatId));
  }

  Future<void> deleteChat(String chatId) async {
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    List<Map<String, Object?>> rollbackRows = const [];
    if (userId != null && store != null) {
      rollbackRows = await store.readSummariesForChat(
        userId: userId,
        chatId: chatId,
      );
      await store.deleteChat(userId: userId, chatId: chatId);
    }
    try {
      final deletedChat =
          await _ref.read(backendRepositoryProvider).deleteChat(chatId);
      final eventId = _stringOrNull(deletedChat['eventId']);
      if (eventId != null) {
        _invalidateEventAfterChatDelete(eventId);
      }
      _ref.invalidate(chatListProvider);
      _ref.invalidate(chatSummaryProvider(chatId));
    } catch (_) {
      if (userId != null && store != null && rollbackRows.isNotEmpty) {
        await store.restoreSummaries(userId: userId, rows: rollbackRows);
      }
      _ref.invalidate(chatListProvider);
      _ref.invalidate(chatSummaryProvider(chatId));
      rethrow;
    }
  }

  void _invalidateEventAfterChatDelete(String eventId) {
    _ref.invalidate(homeEventsProvider);
    _ref.invalidate(homeEventsQueryProvider);
    _ref.invalidate(meetingsProvider);
    _ref.invalidate(meetingsQueryProvider);
    _ref.invalidate(meetingDetailProvider(eventId));
  }
}

final tokenWalletProvider = FutureProvider.autoDispose<TokenWalletData>((ref) {
  return _privateValueFuture<TokenWalletData>(
    ref,
    fallback: const TokenWalletData(balance: 0),
    namespace: 'wallet',
    cacheValue: 'tokens',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchTokenWallet(
      cancelToken: cancelToken,
    ),
    encode: (wallet) =>
        wallet.raw.isEmpty ? {'balance': wallet.balance} : wallet.raw,
    decode: TokenWalletData.fromJson,
  );
});

final paymentsCatalogProvider =
    FutureProvider.autoDispose<PaymentsCatalog>((ref) {
  return _localFirstValueFuture<PaymentsCatalog>(
    ref,
    namespace: 'payments',
    cacheValue: 'catalog',
    ttl: const Duration(seconds: 30),
    fetch: (repository, cancelToken) => repository.fetchPaymentsCatalog(
      cancelToken: cancelToken,
    ),
    encode: (catalog) => catalog.raw,
    decode: PaymentsCatalog.fromJson,
  );
});

final subscriptionProvider =
    FutureProvider.autoDispose<SubscriptionStateData>((ref) {
  return _privateValueFuture<SubscriptionStateData>(
    ref,
    fallback: const SubscriptionStateData(status: 'inactive'),
    namespace: 'subscription',
    cacheValue: 'state',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchSubscription(
      cancelToken: cancelToken,
    ),
    encode: (subscription) => subscription.raw,
    decode: SubscriptionStateData.fromJson,
  );
});

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) {
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final repository = ref.read(backendRepositoryProvider);
  if (localFirst == null) {
    return repository.fetchSubscriptionPlans(cancelToken: cancelToken);
  }
  return localFirst.fetch<List<SubscriptionPlan>>(
    key: AppCacheKey(
      namespace: 'subscription',
      value: 'plans',
      userScope: ref.watch(currentCacheScopeProvider),
    ),
    ttl: const Duration(seconds: 30),
    network: () async {
      final plans = await repository.fetchSubscriptionPlans(
        cancelToken: cancelToken,
      );
      return {'items': plans.map((plan) => plan.raw).toList(growable: false)};
    },
    decode: (json) =>
        _items(json).map(SubscriptionPlan.fromJson).toList(growable: false),
  );
});

final verificationProvider =
    FutureProvider.autoDispose<VerificationStateData>((ref) {
  return _privateValueFuture<VerificationStateData>(
    ref,
    fallback: const VerificationStateData(
      status: 'not_started',
      selfieDone: false,
      documentDone: false,
    ),
    namespace: 'verification',
    cacheValue: 'state',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchVerification(
      cancelToken: cancelToken,
    ),
    encode: (verification) => verification.raw,
    decode: VerificationStateData.fromJson,
  );
});

final paymentActionsProvider = Provider<PaymentActionsController>(
  PaymentActionsController.new,
);

final appleIapGatewayProvider = Provider<AppleIapGateway>((ref) {
  return InAppPurchaseAppleIapGateway();
});

final appleIapPurchaseControllerProvider =
    Provider<AppleIapPurchaseController>((ref) {
  return AppleIapPurchaseController(
    gateway: ref.read(appleIapGatewayProvider),
    confirmPurchase: (input) {
      return ref.read(backendRepositoryProvider).confirmAppleIapPurchase(
            productKind: input.productKind,
            productId: input.productId,
            appleProductId: input.appleProductId,
            transactionId: input.transactionId,
            verificationData: input.verificationData,
          );
    },
  );
});

final verificationActionsProvider = Provider<VerificationActionsController>(
  VerificationActionsController.new,
);

final frendlySeasonActionsProvider = Provider<FrendlySeasonActionsController>(
  FrendlySeasonActionsController.new,
);

final dropsActionsProvider = Provider<DropsActionsController>(
  DropsActionsController.new,
);

final safetyActionsProvider = Provider<SafetyActionsController>(
  SafetyActionsController.new,
);

final datingActionsProvider = Provider<DatingActionsController>(
  DatingActionsController.new,
);

final afterDarkActionsProvider = Provider<AfterDarkActionsController>(
  AfterDarkActionsController.new,
);

final routeActionsProvider = Provider<RouteActionsController>(
  RouteActionsController.new,
);

final eveningAiActionsProvider = Provider<EveningAiActionsController>(
  EveningAiActionsController.new,
);

class PaymentActionsController {
  PaymentActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<PaymentOrderData> initTokenPayment(String productId) async {
    final cancelToken = _trackToken();
    try {
      return await _ref.read(backendRepositoryProvider).initTokenPayment(
            productId: productId,
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<SubscriptionStateData> subscribeWithTokens(String plan) async {
    final cancelToken = _trackToken();
    try {
      final subscription =
          await _ref.read(backendRepositoryProvider).subscribeWithTokens(
                plan: plan,
                cancelToken: cancelToken,
              );
      _ref.invalidate(tokenWalletProvider);
      _ref.invalidate(subscriptionProvider);
      _ref.invalidate(ownProfileProvider);
      return subscription;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<PaymentOrderData> purchaseAppleProduct({
    required String productKind,
    required String productId,
    required String appleProductId,
  }) async {
    try {
      final order = await _ref.read(appleIapPurchaseControllerProvider).buy(
            AppleIapProductPurchase(
              productKind: productKind,
              productId: productId,
              appleProductId: appleProductId,
            ),
          );
      _ref.invalidate(tokenWalletProvider);
      _ref.invalidate(paymentsCatalogProvider);
      _ref.invalidate(subscriptionProvider);
      _ref.invalidate(subscriptionPlansProvider);
      _ref.invalidate(ownProfileProvider);
      return order;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    }
  }

  Future<void> handlePaymentReturn({String? orderId}) async {
    final normalizedOrderId = orderId?.trim();
    try {
      if (normalizedOrderId != null && normalizedOrderId.isNotEmpty) {
        await _ref.read(backendRepositoryProvider).checkPayment(
              orderId: normalizedOrderId,
            );
      }
    } catch (_) {
      // The webhook may still refresh the order. The wallet must refetch anyway.
    } finally {
      _ref.invalidate(tokenWalletProvider);
      _ref.invalidate(paymentsCatalogProvider);
      _ref.invalidate(subscriptionProvider);
      _ref.invalidate(subscriptionPlansProvider);
      _ref.invalidate(ownProfileProvider);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class VerificationActionsController {
  VerificationActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<VerificationStateData> submitStep({
    required String step,
    required String assetId,
  }) async {
    final cancelToken = _trackToken();
    try {
      final state =
          await _ref.read(backendRepositoryProvider).submitVerification(
                step: step,
                assetId: assetId,
                cancelToken: cancelToken,
              );
      _ref.invalidate(verificationProvider);
      _ref.invalidate(ownProfileProvider);
      _ref.invalidate(subscriptionProvider);
      return state;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class FrendlySeasonActionsController {
  FrendlySeasonActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<void> claimReward(String rewardKey) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).claimFrendlySeasonReward(
            rewardKey,
            cancelToken: cancelToken,
          );
      _ref.invalidate(frendlySeasonProvider);
      _ref.invalidate(tokenWalletProvider);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class DropsActionsController {
  DropsActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<void> claimVerification() async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).claimDropsVerification(
            cancelToken: cancelToken,
          );
      await _invalidateDrops();
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> claimDailyLogin() async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).claimDropsDailyLogin(
            cancelToken: cancelToken,
          );
      await _invalidateDrops();
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<DropApplyResult> applyTickets(String dropId, int ticketCount) async {
    final cancelToken = _trackToken();
    try {
      final result =
          await _ref.read(backendRepositoryProvider).applyDropTickets(
                dropId: dropId,
                ticketCount: ticketCount,
                cancelToken: cancelToken,
              );
      await _invalidateDrops();
      return result;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<DropReferralLinkData> createReferralLink() async {
    final cancelToken = _trackToken();
    try {
      final result =
          await _ref.read(backendRepositoryProvider).createDropsReferralLink(
                cancelToken: cancelToken,
              );
      await _invalidateDrops();
      return result;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  Future<void> _invalidateDrops() async {
    await _clearDropsCache();
    _ref.invalidate(dropsHomeProvider);
  }

  Future<void> _clearDropsCache() async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    await store.deleteKey(
      AppCacheKey(
        namespace: 'drops',
        value: 'home',
        userScope: _ref.read(currentCacheScopeProvider),
      ),
    );
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class SafetyActionsController {
  SafetyActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<Map<String, Object?>> createSos() async {
    final cancelToken = _trackToken();
    try {
      return await _ref.read(backendRepositoryProvider).createSos(
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> createTrustedContact({
    required String name,
    required String value,
    required String channel,
    String mode = 'sos_only',
  }) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).createTrustedContact(
            name: name,
            value: value,
            channel: channel,
            mode: mode,
            cancelToken: cancelToken,
          );
      _ref.invalidate(trustedContactsProvider);
      _ref.invalidate(safetyProvider);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> deleteTrustedContact(String contactId) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).deleteTrustedContact(
            contactId,
            cancelToken: cancelToken,
          );
      _ref.invalidate(trustedContactsProvider);
      _ref.invalidate(safetyProvider);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  Future<SafetyData> updateSafety(Map<String, Object?> data) async {
    final cancelToken = _trackToken();
    try {
      final safety = await _ref.read(backendRepositoryProvider).updateSafety(
            data,
            cancelToken: cancelToken,
          );
      _ref.invalidate(safetyProvider);
      return safety;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class DatingActionsController {
  DatingActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<DatingActionResult> recordAction({
    required String targetUserId,
    required String action,
  }) async {
    final cancelToken = _trackToken();
    try {
      final result =
          await _ref.read(backendRepositoryProvider).recordDatingAction(
                targetUserId: targetUserId,
                action: action,
                cancelToken: cancelToken,
              );
      _ref.read(datingHandledProfileIdsProvider.notifier).add(targetUserId);
      if (result.matched) {
        _ref.invalidate(matchesProvider);
      }
      if (result.chargedTokens > 0) {
        _ref.invalidate(tokenWalletProvider);
      }
      _ref.invalidate(datingLimitsProvider);
      _ref.invalidate(datingLikesProvider);
      return result;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<DatingRewindResult> rewindLastPass() async {
    final cancelToken = _trackToken();
    try {
      final result =
          await _ref.read(backendRepositoryProvider).rewindDatingPass(
                cancelToken: cancelToken,
              );
      if (result.chargedTokens > 0) {
        _ref.invalidate(tokenWalletProvider);
      }
      final peerId = result.peer?.id;
      if (peerId != null && peerId.isNotEmpty) {
        _ref.read(datingHandledProfileIdsProvider.notifier).remove(peerId);
      }
      _ref.invalidate(datingLimitsProvider);
      _ref.invalidate(datingDiscoverProvider);
      return result;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class AfterDarkActionsController {
  AfterDarkActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<void> unlock({
    required String plan,
    required bool ageConfirmed,
    required bool codeAccepted,
  }) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).unlockAfterDark(
            plan: plan,
            ageConfirmed: ageConfirmed,
            codeAccepted: codeAccepted,
            cancelToken: cancelToken,
          );
      _ref.invalidate(afterDarkAccessProvider);
      _ref.invalidate(afterDarkEventsProvider);
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> joinEvent(String eventId) async {
    final cancelToken = _trackToken();
    try {
      final event =
          await _ref.read(backendRepositoryProvider).joinAfterDarkEvent(
                eventId,
                acceptedRules: true,
                cancelToken: cancelToken,
              );
      _ref.invalidate(afterDarkEventProvider(eventId));
      _ref.invalidate(afterDarkEventsProvider);
      return event;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class RouteActionsController {
  RouteActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<EveningRouteSessionData> createTemplateSession({
    required String templateId,
    required DateTime startsAt,
    String privacy = 'open',
    int? capacity,
  }) async {
    final cancelToken = _trackToken();
    try {
      return await _ref
          .read(backendRepositoryProvider)
          .createRouteTemplateSession(
            templateId: templateId,
            startsAt: startsAt,
            privacy: privacy,
            capacity: capacity,
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class EveningAiActionsController {
  EveningAiActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<EveningAiDraftData> createDraft(String prompt) async {
    final cancelToken = _trackToken();
    try {
      final user = _ref.read(currentUserProvider);
      return await _ref.read(backendRepositoryProvider).createEveningAiDraft(
            prompt: prompt,
            city: user?.city,
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<EveningAiDraftData> acceptStep({
    required String draftId,
    required int stepIndex,
  }) async {
    final cancelToken = _trackToken();
    try {
      final draft =
          await _ref.read(backendRepositoryProvider).acceptEveningAiDraftStep(
                draftId: draftId,
                stepIndex: stepIndex,
                cancelToken: cancelToken,
              );
      _ref.invalidate(eveningAiDraftProvider(draft.draftId));
      return draft;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<EveningAiDraftData> regenerate(String draftId) async {
    final cancelToken = _trackToken();
    try {
      final draft =
          await _ref.read(backendRepositoryProvider).regenerateEveningAiDraft(
                draftId,
                cancelToken: cancelToken,
              );
      _ref.invalidate(eveningAiDraftProvider(draft.draftId));
      return draft;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<EveningAiDraftData> regenerateStep({
    required String draftId,
    required int stepIndex,
  }) async {
    final cancelToken = _trackToken();
    try {
      final draft = await _ref
          .read(backendRepositoryProvider)
          .regenerateEveningAiDraftStep(
            draftId: draftId,
            stepIndex: stepIndex,
            cancelToken: cancelToken,
          );
      _ref.invalidate(eveningAiDraftProvider(draft.draftId));
      return draft;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<EveningAiDraftData> confirm(String draftId) async {
    final cancelToken = _trackToken();
    try {
      final draft =
          await _ref.read(backendRepositoryProvider).confirmEveningAiDraft(
                draftId,
                cancelToken: cancelToken,
              );
      _ref.invalidate(eveningAiDraftProvider(draft.draftId));
      return draft;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

final notificationsProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _privatePageStream(
    ref,
    namespace: _notificationsCacheNamespace,
    cacheValue: _notificationsListCacheValue,
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchNotifications(
      cancelToken: cancelToken,
    ),
  );
});

final notificationUnreadCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return _privateValueFuture<int>(
    ref,
    fallback: 0,
    namespace: _notificationsCacheNamespace,
    cacheValue: _notificationsUnreadCountCacheValue,
    ttl: const Duration(minutes: 1),
    fetch: (repository, cancelToken) {
      return repository.fetchNotificationUnreadCount(
        cancelToken: cancelToken,
      );
    },
    encode: (count) => {'unreadCount': count},
    decode: (json) => int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
  );
});

final reportActionsProvider = Provider<ReportActionsController>(
  ReportActionsController.new,
);

final shareActionsProvider = Provider<ShareActionsController>(
  ShareActionsController.new,
);

class ShareActionsController {
  ShareActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<Map<String, Object?>> createShare({
    required String targetType,
    required String targetId,
  }) async {
    final cancelToken = _trackToken();
    try {
      return await _ref.read(backendRepositoryProvider).createShare(
            targetType: targetType,
            targetId: targetId,
            cancelToken: cancelToken,
          );
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

class ReportActionsController {
  ReportActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<void> createReport({
    required String targetUserId,
    required String reason,
    String details = '',
    bool blockRequested = false,
  }) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).createReport(
            targetUserId: targetUserId,
            reason: reason,
            details: details,
            blockRequested: blockRequested,
            cancelToken: cancelToken,
          );
      _ref.invalidate(reportsProvider);
      _ref.invalidate(safetyProvider);
      if (blockRequested) {
        _ref.invalidate(blocksProvider);
        _ref.invalidate(publicUserProvider(targetUserId));
        _ref.invalidate(profileSocialProvider(targetUserId));
      }
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> reportEvent({
    required String eventId,
    String reason = 'bad_content',
    String details = '',
  }) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).createReport(
            targetType: 'event',
            targetEventId: eventId,
            reason: reason,
            details: details,
            blockRequested: false,
            cancelToken: cancelToken,
          );
      final current = _ref.read(reportedEventIdsProvider);
      _ref.read(reportedEventIdsProvider.notifier).state = {
        ...current,
        eventId,
      };
      _ref.invalidate(reportsProvider);
      _ref.invalidate(safetyProvider);
      _ref.invalidate(homeEventsProvider);
      _ref.invalidate(homeEventsQueryProvider);
      _ref.invalidate(meetingsProvider);
      _ref.invalidate(meetingsQueryProvider);
      _ref.invalidate(meetingDetailProvider(eventId));
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BlockedUserData> createBlock({
    required String targetUserId,
  }) async {
    final cancelToken = _trackToken();
    try {
      final block = await _ref.read(backendRepositoryProvider).createBlock(
            targetUserId: targetUserId,
            cancelToken: cancelToken,
          );
      _ref.invalidate(blocksProvider);
      _ref.invalidate(safetyProvider);
      _ref.invalidate(publicUserProvider(targetUserId));
      _ref.invalidate(profileSocialProvider(targetUserId));
      return block;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> deleteBlock({
    required String targetUserId,
  }) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).deleteBlock(
            targetUserId: targetUserId,
            cancelToken: cancelToken,
          );
      _ref.invalidate(blocksProvider);
      _ref.invalidate(safetyProvider);
      _ref.invalidate(publicUserProvider(targetUserId));
      _ref.invalidate(profileSocialProvider(targetUserId));
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

final notificationsActionsProvider = Provider<NotificationsActionsController>(
  NotificationsActionsController.new,
);

final reportsProvider = FutureProvider.autoDispose<SafetyReportPage>((ref) {
  return _privateValueFuture<SafetyReportPage>(
    ref,
    fallback: const BackendPage(items: []),
    namespace: 'reports',
    cacheValue: 'me',
    ttl: const Duration(minutes: 5),
    fetch: (repository, cancelToken) => repository.fetchReports(
      cancelToken: cancelToken,
    ),
    encode: (page) => page.raw,
    decode: _decodeSafetyReportPage,
  );
});

final blocksProvider = FutureProvider.autoDispose<BlockedUserPage>((ref) {
  return _privateValueFuture<BlockedUserPage>(
    ref,
    fallback: const BackendPage(items: []),
    namespace: 'blocks',
    cacheValue: 'me',
    ttl: const Duration(minutes: 5),
    fetch: (repository, cancelToken) => repository.fetchBlocks(
      cancelToken: cancelToken,
    ),
    encode: (page) => page.raw,
    decode: _decodeBlockedUserPage,
  );
});

const _notificationsCacheNamespace = 'notifications';
const _notificationsListCacheValue = 'list?limit=30';
const _notificationsUnreadCountCacheValue = 'unread-count';

class NotificationsActionsController {
  NotificationsActionsController(this._ref) {
    _ref.onDispose(() {
      for (final token in _tokens) {
        token.cancel();
      }
      _tokens.clear();
    });
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<void> markRead(String notificationId) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).markNotificationRead(
            notificationId,
            cancelToken: cancelToken,
          );
      await _markNotificationReadLocally(notificationId);
      _ref.invalidate(notificationUnreadCountProvider);
      _ref.invalidate(notificationsProvider);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> markAllRead() async {
    final cancelToken = _trackToken();
    try {
      await _ref
          .read(backendRepositoryProvider)
          .markAllNotificationsRead(cancelToken: cancelToken);
      await _markAllNotificationsReadLocally();
      _ref.invalidate(notificationUnreadCountProvider);
      _ref.invalidate(notificationsProvider);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> applyRealtimeNotificationCreated(
    Map<String, Object?> payload,
  ) async {
    final notification = _realtimeNotificationFromPayload(payload);
    if (notification == null) {
      _ref.invalidate(notificationUnreadCountProvider);
      _ref.invalidate(notificationsProvider);
      return;
    }
    _invalidateFromRealtimeNotification(notification);

    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      _ref.invalidate(notificationUnreadCountProvider);
      _ref.invalidate(notificationsProvider);
      return;
    }

    final userScope = currentCacheScope(_ref);
    final now = DateTime.now();
    final listKey = AppCacheKey(
      namespace: _notificationsCacheNamespace,
      value: _notificationsListCacheValue,
      userScope: userScope,
    );
    final countKey = AppCacheKey(
      namespace: _notificationsCacheNamespace,
      value: _notificationsUnreadCountCacheValue,
      userScope: userScope,
    );
    final cachedList = await store.getFreshJson(listKey, now: now);
    final cachedCount = await store.getFreshJson(countKey, now: now);
    var insertedUnread = false;

    if (cachedList != null) {
      final notificationId = notification['id']?.toString();
      final existingItems = _items(cachedList);
      final hadItem = existingItems.any(
        (item) => item['id']?.toString() == notificationId,
      );
      insertedUnread = !hadItem && _notificationIsUnread(notification);
      final updatedItems = <Map<String, Object?>>[
        notification,
        ...existingItems.where(
          (item) => item['id']?.toString() != notificationId,
        ),
      ].take(30).toList(growable: false);
      await store.putJson(
        listKey,
        <String, Object?>{
          ...cachedList,
          'items': updatedItems,
        },
        expiresAt: now.add(const Duration(minutes: 2)),
      );
    }

    if (cachedCount != null && insertedUnread) {
      final count =
          int.tryParse(cachedCount['unreadCount']?.toString() ?? '') ?? 0;
      await store.putJson(
        countKey,
        <String, Object?>{'unreadCount': count + 1},
        expiresAt: now.add(const Duration(minutes: 1)),
      );
    } else if (cachedCount == null && _notificationIsUnread(notification)) {
      _ref.invalidate(notificationUnreadCountProvider);
    }

    _ref.invalidate(notificationUnreadCountProvider);
    _ref.invalidate(notificationsProvider);
  }

  void _invalidateFromRealtimeNotification(Map<String, Object?> notification) {
    final kind = notification['kind']?.toString();
    final rawPayload = notification['payload'];
    final payload = rawPayload is Map
        ? rawPayload.map((key, value) => MapEntry('$key', value))
        : const <String, Object?>{};
    if (payload['source'] == 'verification') {
      _ref.invalidate(verificationProvider);
      _ref.invalidate(ownProfileProvider);
      _ref.invalidate(subscriptionProvider);
    }
    if (kind == 'event_joined' || kind == 'event_invite') {
      final eventId = payload['eventId']?.toString();
      if (eventId != null && eventId.isNotEmpty) {
        _ref.invalidate(meetingDetailProvider(eventId));
      }
      _ref.invalidate(homeEventsProvider);
      _ref.invalidate(homeEventsQueryProvider);
      _ref.invalidate(meetingsProvider);
      _ref.invalidate(meetingsQueryProvider);
      _invalidateMapEvents(_ref);
      _ref.invalidate(chatListProvider);
      _ref.invalidate(chatsProvider);
    }
  }

  Future<BackendCardItem> acceptEventInvite({
    required String eventId,
    required String requestId,
  }) async {
    final cancelToken = _trackToken();
    try {
      final event =
          await _ref.read(backendRepositoryProvider).acceptEventInvite(
                eventId: eventId,
                requestId: requestId,
                cancelToken: cancelToken,
              );
      await _dropNotificationCache();
      _ref.invalidate(homeEventsProvider);
      _ref.invalidate(homeEventsQueryProvider);
      _ref.invalidate(meetingsProvider);
      _ref.invalidate(meetingsQueryProvider);
      _ref.invalidate(meetingDetailProvider(eventId));
      _invalidateMapEvents(_ref);
      _ref.invalidate(chatListProvider);
      _ref.invalidate(chatsProvider);
      _ref.invalidate(publicUserProvider);
      _ref.invalidate(notificationUnreadCountProvider);
      _ref.invalidate(notificationsProvider);
      return event;
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<void> declineEventInvite({
    required String eventId,
    required String requestId,
  }) async {
    final cancelToken = _trackToken();
    try {
      await _ref.read(backendRepositoryProvider).declineEventInvite(
            eventId: eventId,
            requestId: requestId,
            cancelToken: cancelToken,
          );
      await _dropNotificationCache();
      _ref.invalidate(meetingDetailProvider(eventId));
      _ref.invalidate(notificationUnreadCountProvider);
      _ref.invalidate(notificationsProvider);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  Future<void> _dropNotificationCache() async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    final userScope = currentCacheScope(_ref);
    await store.deleteKey(
      AppCacheKey(
        namespace: _notificationsCacheNamespace,
        value: _notificationsListCacheValue,
        userScope: userScope,
      ),
    );
    await store.deleteKey(
      AppCacheKey(
        namespace: _notificationsCacheNamespace,
        value: _notificationsUnreadCountCacheValue,
        userScope: userScope,
      ),
    );
  }

  Future<void> _markNotificationReadLocally(String notificationId) async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    final userScope = currentCacheScope(_ref);
    final now = DateTime.now();
    final listKey = AppCacheKey(
      namespace: _notificationsCacheNamespace,
      value: _notificationsListCacheValue,
      userScope: userScope,
    );
    final countKey = AppCacheKey(
      namespace: _notificationsCacheNamespace,
      value: _notificationsUnreadCountCacheValue,
      userScope: userScope,
    );
    final cachedList = await store.getFreshJson(listKey, now: now);
    final cachedCount = await store.getFreshJson(countKey, now: now);
    final items = cachedList == null ? null : _items(cachedList);
    var wasUnread = false;

    if (cachedList != null && items != null) {
      final updatedItems = items.map((item) {
        if (item['id']?.toString() != notificationId) {
          return item;
        }
        wasUnread = _notificationIsUnread(item);
        return <String, Object?>{
          ...item,
          'read': true,
          'isRead': true,
          'readAt': item['readAt'] ?? now.toUtc().toIso8601String(),
        };
      }).toList(growable: false);
      await store.putJson(
        listKey,
        <String, Object?>{
          ...cachedList,
          'items': updatedItems,
        },
        expiresAt: now.add(const Duration(minutes: 2)),
      );
    }

    if (cachedCount != null && (wasUnread || cachedList == null)) {
      final count =
          int.tryParse(cachedCount['unreadCount']?.toString() ?? '') ?? 0;
      await store.putJson(
        countKey,
        <String, Object?>{'unreadCount': count > 0 ? count - 1 : 0},
        expiresAt: now.add(const Duration(minutes: 1)),
      );
    }
  }

  Future<void> _markAllNotificationsReadLocally() async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    final userScope = currentCacheScope(_ref);
    final now = DateTime.now();
    final listKey = AppCacheKey(
      namespace: _notificationsCacheNamespace,
      value: _notificationsListCacheValue,
      userScope: userScope,
    );
    final countKey = AppCacheKey(
      namespace: _notificationsCacheNamespace,
      value: _notificationsUnreadCountCacheValue,
      userScope: userScope,
    );
    final cachedList = await store.getFreshJson(listKey, now: now);

    if (cachedList != null) {
      final readAt = now.toUtc().toIso8601String();
      final updatedItems = _items(cachedList).map((item) {
        return <String, Object?>{
          ...item,
          'read': true,
          'isRead': true,
          'readAt': item['readAt'] ?? readAt,
        };
      }).toList(growable: false);
      await store.putJson(
        listKey,
        <String, Object?>{
          ...cachedList,
          'items': updatedItems,
        },
        expiresAt: now.add(const Duration(minutes: 2)),
      );
    }

    await store.putJson(
      countKey,
      const <String, Object?>{'unreadCount': 0},
      expiresAt: now.add(const Duration(minutes: 1)),
    );
  }
}

bool _notificationIsUnread(Map<String, Object?> item) {
  final read = item['read'];
  if (read is bool) {
    return !read;
  }
  final isRead = item['isRead'];
  if (isRead is bool) {
    return !isRead;
  }
  return item['readAt'] == null;
}

Map<String, Object?>? _realtimeNotificationFromPayload(
  Map<String, Object?> payload,
) {
  final notificationId = payload['notificationId']?.toString();
  final kind = payload['kind']?.toString();
  final title = payload['title']?.toString();
  final body = payload['body']?.toString();
  final createdAt = payload['createdAt']?.toString();
  if (notificationId == null ||
      notificationId.isEmpty ||
      kind == null ||
      kind.isEmpty ||
      title == null ||
      body == null ||
      createdAt == null ||
      createdAt.isEmpty) {
    return null;
  }
  final readAt = payload['readAt']?.toString();
  final rawPayload = payload['payload'];
  return <String, Object?>{
    'id': notificationId,
    'notificationId': notificationId,
    'kind': kind,
    'title': title,
    'body': body,
    'payload': rawPayload is Map
        ? rawPayload.map((key, value) => MapEntry('$key', value))
        : const <String, Object?>{},
    'readAt': readAt == null || readAt.isEmpty ? null : readAt,
    'read': readAt != null && readAt.isNotEmpty,
    'isRead': readAt != null && readAt.isNotEmpty,
    'createdAt': createdAt,
  };
}

final communitiesProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _localFirstPageStream(
    ref,
    namespace: _communitiesCacheNamespace,
    cacheValue: _communitiesListCacheValue,
    ttl: const Duration(minutes: 5),
    fetch: (repository, cancelToken) => repository.fetchCommunities(
      cancelToken: cancelToken,
    ),
  );
});

class CommunityListQuery {
  const CommunityListQuery({
    this.q,
    this.topics = const [],
    this.privacy,
    this.sort = 'popular',
  });

  final String? q;
  final List<String> topics;
  final String? privacy;
  final String sort;

  bool get isDefault {
    return (q == null || q!.trim().isEmpty) &&
        topics.isEmpty &&
        (privacy == null || privacy!.isEmpty) &&
        sort == 'popular';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CommunityListQuery &&
        other.q == q &&
        other.privacy == privacy &&
        other.sort == sort &&
        _stringListsEqual(other.topics, topics);
  }

  @override
  int get hashCode => Object.hash(q, privacy, sort, Object.hashAll(topics));
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

final communitiesQueryProvider = StreamProvider.autoDispose
    .family<CardPage, CommunityListQuery>((ref, query) {
  return _localFirstPageStream(
    ref,
    namespace: _communitiesCacheNamespace,
    cacheValue:
        'list?q=${query.q ?? ''}&topics=${query.topics.join(',')}&privacy=${query.privacy ?? ''}&sort=${query.sort}',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchCommunities(
      q: query.q,
      topics: query.topics,
      privacy: query.privacy,
      sort: query.sort,
      cancelToken: cancelToken,
    ),
  );
});

final communitiesPaginationProvider = StateNotifierProvider.autoDispose<
    CommunitiesPaginationController, CommunitiesPaginationState>((ref) {
  return CommunitiesPaginationController(ref);
});

class CommunitiesPaginationState {
  const CommunitiesPaginationState({
    this.items = const [],
    this.nextCursor,
    this.loading = false,
    this.error = false,
    this.initialized = false,
  });

  final List<BackendCardItem> items;
  final String? nextCursor;
  final bool loading;
  final bool error;
  final bool initialized;

  bool get hasNextPage => nextCursor != null && nextCursor!.isNotEmpty;

  CommunitiesPaginationState copyWith({
    List<BackendCardItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loading,
    bool? error,
    bool? initialized,
  }) {
    return CommunitiesPaginationState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      initialized: initialized ?? this.initialized,
    );
  }
}

class CommunitiesPaginationController
    extends StateNotifier<CommunitiesPaginationState> {
  CommunitiesPaginationController(this._ref)
      : super(const CommunitiesPaginationState()) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = {};

  void primeNextCursor(String? cursor) {
    if (state.items.isNotEmpty || state.loading) {
      return;
    }
    if (state.initialized && state.nextCursor == cursor) {
      return;
    }
    state = state.copyWith(
      nextCursor: cursor,
      clearNextCursor: cursor == null || cursor.isEmpty,
      error: false,
      initialized: true,
    );
  }

  Future<void> loadNextPage() async {
    final cursor = state.nextCursor;
    if (state.loading || cursor == null || cursor.isEmpty) {
      return;
    }
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    state = state.copyWith(loading: true, error: false);
    try {
      final page = await _ref.read(backendRepositoryProvider).fetchCommunities(
            cursor: cursor,
            cancelToken: cancelToken,
          );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null || page.nextCursor!.isEmpty,
        loading: false,
        error: false,
      );
    } catch (_) {
      if (!cancelToken.isCancelled) {
        state = state.copyWith(loading: false, error: true);
      }
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

final communityActionsProvider = Provider<CommunityActionsController>(
  CommunityActionsController.new,
);

const _communitiesCacheNamespace = 'communities';
const _communitiesListCacheValue = 'list?limit=20';

class CommunityActionsController {
  CommunityActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = <CancelToken>{};

  Future<BackendCardItem> createCommunity({
    required Map<String, Object?> data,
    required String idempotencyKey,
  }) async {
    final cancelToken = _trackToken();
    try {
      final community =
          await _ref.read(backendRepositoryProvider).createCommunity(
                data: data,
                idempotencyKey: idempotencyKey,
                cancelToken: cancelToken,
              );
      await _prependCommunityToCaches(community);
      _ref.invalidate(communitiesProvider);
      _invalidateChatLists(chatId: _stringOrNull(community.raw['chatId']));
      return community;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> setJoined({
    required String communityId,
    required bool joined,
  }) async {
    final cancelToken = _trackToken();
    try {
      final community = joined
          ? await _ref.read(backendRepositoryProvider).joinCommunity(
                communityId,
                cancelToken: cancelToken,
              )
          : await _ref.read(backendRepositoryProvider).leaveCommunity(
                communityId,
                cancelToken: cancelToken,
              );
      await _updateCommunityCaches(community);
      final chatId = _stringOrNull(community.raw['chatId']);
      if (!joined) {
        await _deleteLocalChat(chatId);
      }
      _ref.invalidate(communityDetailProvider(communityId));
      _ref.invalidate(communitiesProvider);
      _invalidateChatLists(chatId: chatId);
      return community;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> requestJoin({
    required String communityId,
    String? note,
  }) async {
    final cancelToken = _trackToken();
    try {
      final community =
          await _ref.read(backendRepositoryProvider).createCommunityJoinRequest(
                communityId,
                note: note,
                cancelToken: cancelToken,
              );
      await _updateCommunityCaches(community);
      _ref.invalidate(communityDetailProvider(communityId));
      _ref.invalidate(communitiesProvider);
      return community;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> cancelJoinRequest({
    required String communityId,
  }) async {
    final cancelToken = _trackToken();
    try {
      final community =
          await _ref.read(backendRepositoryProvider).cancelCommunityJoinRequest(
                communityId,
                cancelToken: cancelToken,
              );
      await _updateCommunityCaches(community);
      _ref.invalidate(communityDetailProvider(communityId));
      _ref.invalidate(communitiesProvider);
      return community;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<BackendCardItem> createNews({
    required String communityId,
    required String title,
    required String body,
  }) async {
    final cancelToken = _trackToken();
    try {
      final community =
          await _ref.read(backendRepositoryProvider).createCommunityNews(
                communityId: communityId,
                title: title,
                body: body,
                cancelToken: cancelToken,
              );
      await _writeCommunityDetailCache(community);
      _ref.invalidate(communityDetailProvider(communityId));
      return community;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }

  Future<void> _prependCommunityToCaches(BackendCardItem community) async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    final scope = currentCacheScope(_ref);
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 5));
    final communityJson = _communityCacheJson(community);
    await _writeCommunityDetailCache(
      community,
      store: store,
      scope: scope,
      expiresAt: expiresAt,
    );

    final listKey = AppCacheKey(
      namespace: _communitiesCacheNamespace,
      value: _communitiesListCacheValue,
      userScope: scope,
    );
    final cachedList = await store.getFreshJson(listKey, now: now);
    final items = cachedList?['items'];
    if (cachedList == null || items is! List) {
      await store.putJson(
        listKey,
        {
          'items': [communityJson],
          'nextCursor': null,
        },
        expiresAt: expiresAt,
      );
      return;
    }
    final nextItems = [
      communityJson,
      for (final item in items)
        if (item is! Map || item['id']?.toString() != community.id) item,
    ];
    await store.putJson(
      listKey,
      {...cachedList, 'items': nextItems},
      expiresAt: expiresAt,
    );
  }

  Future<void> _updateCommunityCaches(BackendCardItem community) async {
    final store = _ref.read(appLocalCacheStoreProvider);
    if (store == null) {
      return;
    }
    final scope = currentCacheScope(_ref);
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 5));
    final communityJson = _communityCacheJson(community);
    await _writeCommunityDetailCache(
      community,
      store: store,
      scope: scope,
      expiresAt: expiresAt,
    );

    final listKey = AppCacheKey(
      namespace: _communitiesCacheNamespace,
      value: _communitiesListCacheValue,
      userScope: scope,
    );
    final cachedList = await store.getFreshJson(listKey, now: now);
    final items = cachedList?['items'];
    if (cachedList == null || items is! List) {
      return;
    }
    var updated = false;
    final nextItems = [
      for (final item in items)
        if (item is Map && item['id']?.toString() == community.id) ...[
          _mergeCacheJson(item, communityJson)
        ] else
          item,
    ];
    updated = nextItems.any(
      (item) => item is Map && item['id']?.toString() == community.id,
    );
    if (!updated) {
      return;
    }
    await store.putJson(
      listKey,
      {...cachedList, 'items': nextItems},
      expiresAt: expiresAt,
    );
  }

  Map<String, Object?> _communityCacheJson(BackendCardItem community) {
    return {
      ...community.raw,
      'id': community.id,
      if (community.title.isNotEmpty && !community.raw.containsKey('name'))
        'name': community.title,
      if (community.subtitle != null && !community.raw.containsKey('subtitle'))
        'subtitle': community.subtitle,
      if (community.imageUrl != null && !community.raw.containsKey('imageUrl'))
        'imageUrl': community.imageUrl,
    };
  }

  Future<void> _writeCommunityDetailCache(
    BackendCardItem community, {
    AppLocalCacheStore? store,
    AppCacheUserScope? scope,
    DateTime? expiresAt,
  }) async {
    final cacheStore = store ?? _ref.read(appLocalCacheStoreProvider);
    if (cacheStore == null) {
      return;
    }
    await cacheStore.putJson(
      AppCacheKey(
        namespace: _communitiesCacheNamespace,
        value: 'detail:${community.id}',
        userScope: scope ?? currentCacheScope(_ref),
      ),
      _communityCacheJson(community),
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  Future<void> _deleteLocalChat(String? chatId) async {
    final resolvedChatId = chatId?.trim();
    if (resolvedChatId == null || resolvedChatId.isEmpty) {
      return;
    }
    final userId = _ref.read(currentUserIdProvider);
    final store = _ref.read(chatLocalStoreProvider);
    if (userId == null || store == null) {
      return;
    }
    try {
      await store.deleteChat(userId: userId, chatId: resolvedChatId);
    } catch (_) {}
  }

  void _invalidateChatLists({String? chatId}) {
    _ref.invalidate(chatListProvider);
    _ref.invalidate(chatsProvider);
    final resolvedChatId = chatId?.trim();
    if (resolvedChatId != null && resolvedChatId.isNotEmpty) {
      _ref.invalidate(chatSummaryProvider(resolvedChatId));
    }
  }

  Map<String, Object?> _mergeCacheJson(
    Map<Object?, Object?> cached,
    Map<String, Object?> fresh,
  ) {
    return {
      for (final entry in cached.entries) '${entry.key}': entry.value,
      ...fresh,
    };
  }
}

final communityDetailProvider =
    FutureProvider.autoDispose.family<BackendCardItem, String>((ref, id) {
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final repository = ref.read(backendRepositoryProvider);
  if (localFirst == null) {
    return repository.fetchCommunityDetail(id, cancelToken: cancelToken);
  }
  return localFirst.fetch<BackendCardItem>(
    key: AppCacheKey(
      namespace: 'communities',
      value: 'detail:$id',
      userScope: ref.watch(currentCacheScopeProvider),
    ),
    ttl: const Duration(minutes: 5),
    network: () async {
      final community = await repository.fetchCommunityDetail(
        id,
        cancelToken: cancelToken,
      );
      return community.raw;
    },
    decode: BackendCardItem.fromJson,
  );
});

final communityMediaProvider =
    StreamProvider.autoDispose.family<CardPage, String>((ref, communityId) {
  return _localFirstPageStream(
    ref,
    namespace: 'communities',
    cacheValue: 'media:$communityId?limit=20',
    ttl: const Duration(minutes: 10),
    fetch: (repository, cancelToken) => repository.fetchCommunityMedia(
      communityId,
      cancelToken: cancelToken,
    ),
  );
});

final communityMediaPaginationProvider = StateNotifierProvider.autoDispose
    .family<CommunityMediaPaginationController, CommunityMediaPaginationState,
        String>((ref, communityId) {
  return CommunityMediaPaginationController(ref, communityId);
});

class CommunityMediaPaginationState {
  const CommunityMediaPaginationState({
    this.items = const [],
    this.nextCursor,
    this.loading = false,
    this.error = false,
    this.initialized = false,
  });

  final List<BackendCardItem> items;
  final String? nextCursor;
  final bool loading;
  final bool error;
  final bool initialized;

  bool get hasNextPage => nextCursor != null && nextCursor!.isNotEmpty;

  CommunityMediaPaginationState copyWith({
    List<BackendCardItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loading,
    bool? error,
    bool? initialized,
  }) {
    return CommunityMediaPaginationState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      initialized: initialized ?? this.initialized,
    );
  }
}

class CommunityMediaPaginationController
    extends StateNotifier<CommunityMediaPaginationState> {
  CommunityMediaPaginationController(this._ref, this._communityId)
      : super(const CommunityMediaPaginationState()) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final String _communityId;
  final Set<CancelToken> _tokens = {};

  void primeNextCursor(String? cursor) {
    if (state.items.isNotEmpty || state.loading) {
      return;
    }
    if (state.initialized && state.nextCursor == cursor) {
      return;
    }
    state = state.copyWith(
      nextCursor: cursor,
      clearNextCursor: cursor == null || cursor.isEmpty,
      error: false,
      initialized: true,
    );
  }

  Future<void> loadNextPage() async {
    final cursor = state.nextCursor;
    if (state.loading || cursor == null || cursor.isEmpty) {
      return;
    }
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    state = state.copyWith(loading: true, error: false);
    try {
      final page =
          await _ref.read(backendRepositoryProvider).fetchCommunityMedia(
                _communityId,
                cursor: cursor,
                cancelToken: cancelToken,
              );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null || page.nextCursor!.isEmpty,
        loading: false,
        error: false,
      );
    } catch (_) {
      if (!cancelToken.isCancelled) {
        state = state.copyWith(loading: false, error: true);
      }
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

final eveningAiDraftProvider =
    FutureProvider.autoDispose.family<EveningAiDraftData, String>(
  (ref, draftId) {
    final localFirst = ref.read(localFirstRepositoryProvider);
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);
    final repository = ref.read(backendRepositoryProvider);
    if (localFirst == null) {
      return repository.fetchEveningAiDraft(
        draftId,
        cancelToken: cancelToken,
      );
    }
    return localFirst.fetch<EveningAiDraftData>(
      key: AppCacheKey(
        namespace: 'evening-ai-drafts',
        value: draftId,
        userScope: ref.watch(currentCacheScopeProvider),
      ),
      ttl: const Duration(minutes: 15),
      network: () async {
        final draft = await repository.fetchEveningAiDraft(
          draftId,
          cancelToken: cancelToken,
        );
        return draft.raw;
      },
      decode: EveningAiDraftData.fromJson,
    );
  },
);

final afterDarkAccessProvider =
    FutureProvider.autoDispose<AfterDarkAccessData>((ref) {
  return _privateValueFuture<AfterDarkAccessData>(
    ref,
    fallback: const AfterDarkAccessData(unlocked: false),
    namespace: 'after_dark_access',
    cacheValue: 'me',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchAfterDarkAccess(
      cancelToken: cancelToken,
    ),
    encode: (access) => access.raw,
    decode: AfterDarkAccessData.fromJson,
  );
});

final afterDarkEventsProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _privatePageStream(
    ref,
    namespace: 'after_dark_events',
    cacheValue: 'events?limit=20',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchAfterDarkEvents(
      cancelToken: cancelToken,
    ),
  );
});

final afterDarkEventProvider =
    FutureProvider.autoDispose.family<BackendCardItem, String>((ref, eventId) {
  return _localFirstValueFuture<BackendCardItem>(
    ref,
    namespace: 'after_dark_events',
    cacheValue: 'detail:$eventId',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchAfterDarkEvent(
      eventId,
      cancelToken: cancelToken,
    ),
    encode: (event) => event.raw,
    decode: BackendCardItem.fromJson,
  );
});

final publicUserProvider =
    FutureProvider.autoDispose.family<BackendCardItem, String>((ref, userId) {
  return _localFirstValueFuture<BackendCardItem>(
    ref,
    namespace: 'people',
    cacheValue: 'profile:$userId',
    ttl: const Duration(minutes: 5),
    fetch: (repository, cancelToken) => repository.fetchPublicUser(
      userId,
      cancelToken: cancelToken,
    ),
    encode: (user) => user.raw,
    decode: BackendCardItem.fromJson,
  );
});

final profileSocialProvider =
    FutureProvider.autoDispose.family<ProfileSocialData, String>((ref, userId) {
  return _localFirstValueFuture<ProfileSocialData>(
    ref,
    namespace: 'people',
    cacheValue: 'social:$userId',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchProfileSocial(
      userId,
      cancelToken: cancelToken,
    ),
    encode: (social) => social.raw,
    decode: ProfileSocialData.fromJson,
  );
});

final hostDashboardProvider =
    FutureProvider.autoDispose<HostDashboardData>((ref) {
  return _privateValueFuture<HostDashboardData>(
    ref,
    fallback: const HostDashboardData(stats: HostDashboardStats()),
    namespace: 'host',
    cacheValue: 'dashboard',
    ttl: const Duration(minutes: 1),
    fetch: (repository, cancelToken) => repository.fetchHostDashboard(
      cancelToken: cancelToken,
    ),
    encode: (dashboard) => dashboard.raw,
    decode: HostDashboardData.fromJson,
  );
});

final hostDashboardActionsProvider = Provider<HostDashboardActionsController>(
    HostDashboardActionsController.new);

class HostDashboardActionsController {
  HostDashboardActionsController(this._ref) {
    _ref.onDispose(_cancelActiveRequests);
  }

  final Ref _ref;
  final Set<CancelToken> _tokens = {};

  Future<HostJoinRequestData> approveRequest(String requestId) async {
    final cancelToken = _trackToken();
    try {
      final request =
          await _ref.read(backendRepositoryProvider).approveHostRequest(
                requestId,
                cancelToken: cancelToken,
              );
      _ref.invalidate(hostDashboardProvider);
      return request;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<HostJoinRequestData> rejectRequest(String requestId) async {
    final cancelToken = _trackToken();
    try {
      final request =
          await _ref.read(backendRepositoryProvider).rejectHostRequest(
                requestId,
                cancelToken: cancelToken,
              );
      _ref.invalidate(hostDashboardProvider);
      return request;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  Future<TokenWalletData> boostEvent(
    String eventId, {
    String optionId = 'boost-24',
  }) async {
    final cancelToken = _trackToken();
    try {
      final wallet = await _ref.read(backendRepositoryProvider).createPromotion(
            targetKind: 'event',
            targetId: eventId,
            optionId: optionId,
            cancelToken: cancelToken,
          );
      _ref.invalidate(tokenWalletProvider);
      await _dropMapEventsCache(_ref);
      _invalidateMapEvents(_ref);
      _ref.invalidate(hostDashboardProvider);
      return wallet;
    } on DioException catch (error) {
      throw BackendActionException.fromDio(error);
    } finally {
      _tokens.remove(cancelToken);
    }
  }

  CancelToken _trackToken() {
    final cancelToken = CancelToken();
    _tokens.add(cancelToken);
    return cancelToken;
  }

  void _cancelActiveRequests() {
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
  }
}

final searchResultsProvider =
    FutureProvider.autoDispose.family<CardPage, String>((ref, query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return Future.value(const BackendPage(items: []));
  }
  final city = _currentCity(ref);
  return _privateValueFuture<CardPage>(
    ref,
    fallback: const BackendPage(items: []),
    namespace: 'search',
    cacheValue: 'city:${city ?? ''};q:$trimmed',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.search(
      trimmed,
      city: city,
      cancelToken: cancelToken,
    ),
    encode: (page) => page.raw.isEmpty
        ? {'items': page.items.map((item) => item.raw).toList()}
        : page.raw,
    decode: _decodeCardPage,
  );
});

class MapEventsQuery {
  const MapEventsQuery({
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
    this.southWestLatitude,
    this.southWestLongitude,
    this.northEastLatitude,
    this.northEastLongitude,
    this.limit = 80,
  });

  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;
  final double? southWestLatitude;
  final double? southWestLongitude;
  final double? northEastLatitude;
  final double? northEastLongitude;
  final int limit;

  String get cacheValue => [
        'limit=$limit',
        if (centerLatitude != null) 'lat=${centerLatitude!.toStringAsFixed(3)}',
        if (centerLongitude != null)
          'lng=${centerLongitude!.toStringAsFixed(3)}',
        if (radiusKm != null) 'radius=${radiusKm!.toStringAsFixed(1)}',
        if (southWestLatitude != null)
          'swLat=${southWestLatitude!.toStringAsFixed(3)}',
        if (southWestLongitude != null)
          'swLng=${southWestLongitude!.toStringAsFixed(3)}',
        if (northEastLatitude != null)
          'neLat=${northEastLatitude!.toStringAsFixed(3)}',
        if (northEastLongitude != null)
          'neLng=${northEastLongitude!.toStringAsFixed(3)}',
      ].join('&');

  @override
  bool operator ==(Object other) {
    return other is MapEventsQuery && other.cacheValue == cacheValue;
  }

  @override
  int get hashCode => cacheValue.hashCode;
}

final mapEventsProvider =
    StreamProvider.autoDispose.family<CardPage, MapEventsQuery>((ref, query) {
  ref.watch(_mapEventsRefreshTickProvider);
  final city = _currentCity(ref);
  final date = _todayIsoDate(DateTime.now());
  return _localFirstPageStream(
    ref,
    namespace: 'map_events',
    cacheValue: 'radar-v8:city=${city ?? ''}:date=$date:${query.cacheValue}',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchMapEvents(
      city: city,
      date: date,
      centerLatitude: query.centerLatitude,
      centerLongitude: query.centerLongitude,
      radiusKm: query.radiusKm,
      southWestLatitude: query.southWestLatitude,
      southWestLongitude: query.southWestLongitude,
      northEastLatitude: query.northEastLatitude,
      northEastLongitude: query.northEastLongitude,
      limit: query.limit,
      cancelToken: cancelToken,
    ),
  );
});

final _mapEventsRefreshTickProvider = StateProvider<int>((ref) => 0);

void _invalidateMapEvents(Ref ref) {
  ref.read(_mapEventsRefreshTickProvider.notifier).state += 1;
  ref.invalidate(mapEventsProvider);
}

Future<void> _dropMapEventsCache(Ref ref) async {
  final store = ref.read(appLocalCacheStoreProvider);
  if (store == null) {
    return;
  }
  await store.deleteNamespace(
    namespace: 'map_events',
    userScope: currentCacheScope(ref),
  );
}

final datingDiscoverProvider = StreamProvider.autoDispose<CardPage>((ref) {
  if (ref.watch(authTokensProvider) == null) {
    return Stream.value(const BackendPage(items: []));
  }
  final filters = ref.watch(datingDiscoverFiltersProvider);
  final handledIds = ref.watch(datingHandledProfileIdsProvider);
  return _localFirstPageStream(
    ref,
    namespace: 'dating',
    cacheValue: filters.cacheValue,
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchDatingDiscover(
      gender: filters.gender,
      ageMin: filters.ageMin,
      ageMax: filters.ageMax,
      radiusKm: filters.radiusKm,
      interests: filters.interests,
      verifiedOnly: filters.verifiedOnly,
      onlineOnly: filters.onlineOnly,
      newThisWeekOnly: filters.newThisWeekOnly,
      cancelToken: cancelToken,
    ),
  ).map((page) => _applyDatingClientFilters(page, filters, handledIds));
});

final datingLikesProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _privatePageStream(
    ref,
    namespace: 'dating',
    cacheValue: 'likes?limit=20',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchDatingLikes(
      limit: 20,
      cancelToken: cancelToken,
    ),
  );
});

CardPage _applyDatingClientFilters(
  CardPage page,
  DatingDiscoverFilters filters,
  Set<String> handledIds,
) {
  if (!filters.frendlyPlusOnly && handledIds.isEmpty) {
    return page;
  }
  final items = page.items.where((item) {
    if (handledIds.contains(item.id)) {
      return false;
    }
    final raw = item.raw;
    if (filters.frendlyPlusOnly && raw['premium'] != true) {
      return false;
    }
    return true;
  }).toList(growable: false);
  return BackendPage(
    items: items,
    nextCursor: page.nextCursor,
    raw: page.raw,
  );
}

final perksProvider = perksByCategoryProvider(null);

final perksByCategoryProvider =
    StreamProvider.autoDispose.family<CardPage, String?>((ref, category) {
  final city = _currentCity(ref);
  return _localFirstPageStream(
    ref,
    namespace: 'perks',
    cacheValue: 'promos?city=${city ?? ''}&category=${category ?? ''}&limit=20',
    ttl: const Duration(minutes: 10),
    fetch: (repository, cancelToken) => repository.fetchPerks(
      city: city,
      category: category,
      cancelToken: cancelToken,
    ),
  );
});

final placeSearchProvider =
    StreamProvider.autoDispose.family<CardPage, String>((ref, query) {
  final city = _currentCity(ref);
  return _localFirstPageStream(
    ref,
    namespace: 'places',
    cacheValue: 'search?city=${city ?? ''}&q=$query&limit=20',
    ttl: const Duration(minutes: 10),
    fetch: (repository, cancelToken) => repository.searchPlaces(
      query: query,
      city: city,
      limit: 20,
      cancelToken: cancelToken,
    ),
  );
});

final profileHistoryProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _privatePageStream(
    ref,
    namespace: 'profile',
    cacheValue: 'frendly-history?limit=20',
    ttl: const Duration(minutes: 5),
    fetch: (repository, cancelToken) => repository.fetchHistory(
      cancelToken: cancelToken,
    ),
  );
});

final frendlySeasonProvider =
    FutureProvider.autoDispose<FrendlySeasonData>((ref) {
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final repository = ref.read(backendRepositoryProvider);
  if (localFirst == null) {
    return repository.fetchFrendlySeason(cancelToken: cancelToken);
  }
  return localFirst.fetch<FrendlySeasonData>(
    key: AppCacheKey(
      namespace: 'profile',
      value: 'frendly-season',
      userScope: ref.watch(currentCacheScopeProvider),
    ),
    ttl: const Duration(minutes: 5),
    network: () async {
      final season = await repository.fetchFrendlySeason(
        cancelToken: cancelToken,
      );
      return season.raw;
    },
    decode: FrendlySeasonData.fromJson,
  );
});

final dropsHomeProvider = FutureProvider.autoDispose<DropsHomeData>((ref) {
  if (ref.watch(authTokensProvider) == null ||
      ref.watch(currentUserIdProvider) == null) {
    return Future.value(
      const DropsHomeData(
        ticketProgress: DropTicketProgressData(),
        eligibility: DropUserEligibilityData(),
      ),
    );
  }
  return _localFirstValueFuture<DropsHomeData>(
    ref,
    namespace: 'drops',
    cacheValue: 'home',
    ttl: const Duration(minutes: 1),
    fetch: (repository, cancelToken) => repository.fetchDropsHome(
      cancelToken: cancelToken,
    ),
    encode: (home) => home.raw,
    decode: DropsHomeData.fromJson,
  );
});

final trustedContactsProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _privatePageStream(
    ref,
    namespace: 'safety',
    cacheValue: 'trusted-contacts',
    ttl: const Duration(minutes: 5),
    fetch: (repository, cancelToken) => repository.fetchTrustedContacts(
      cancelToken: cancelToken,
    ),
  );
});

final eventStoriesProvider =
    StreamProvider.autoDispose.family<CardPage, String>((ref, eventId) {
  return _privatePageStream(
    ref,
    namespace: 'stories',
    cacheValue: 'event:$eventId?limit=20',
    ttl: const Duration(minutes: 2),
    fetch: (repository, cancelToken) => repository.fetchEventStories(
      eventId,
      cancelToken: cancelToken,
    ),
  );
});

final memoryPeopleProvider = StreamProvider.autoDispose<CardPage>((ref) {
  return _privatePageStream(
    ref,
    namespace: 'profile',
    cacheValue: 'frendly-people?limit=20',
    ttl: const Duration(minutes: 10),
    fetch: (repository, cancelToken) => repository.fetchMemoryPeople(
      cancelToken: cancelToken,
    ),
  );
});

Stream<CardPage> _privatePageStream(
  Ref ref, {
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required Future<CardPage> Function(BackendRepository, CancelToken) fetch,
}) {
  if (ref.watch(authTokensProvider) == null) {
    return Stream.value(const BackendPage(items: []));
  }
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    return _pendingPrivatePageStream(
      ref,
      namespace: namespace,
      cacheValue: cacheValue,
      ttl: ttl,
      fetch: fetch,
    );
  }
  ref.watch(currentUserIdProvider);
  return _localFirstPageStream(
    ref,
    namespace: namespace,
    cacheValue: cacheValue,
    ttl: ttl,
    fetch: fetch,
  );
}

Future<T> _privateValueFuture<T>(
  Ref ref, {
  required T fallback,
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required Future<T> Function(BackendRepository, CancelToken) fetch,
  required Map<String, Object?> Function(T) encode,
  required T Function(Map<String, Object?>) decode,
  bool Function(Map<String, Object?> json)? useCached,
}) {
  if (ref.watch(authTokensProvider) == null) {
    return Future.value(fallback);
  }
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    return _pendingPrivateValueFuture(
      ref,
      fallback: fallback,
      namespace: namespace,
      cacheValue: cacheValue,
      ttl: ttl,
      fetch: fetch,
      encode: encode,
      decode: decode,
    );
  }
  ref.watch(currentUserIdProvider);
  return _localFirstValueFuture<T>(
    ref,
    namespace: namespace,
    cacheValue: cacheValue,
    ttl: ttl,
    fetch: fetch,
    encode: encode,
    decode: decode,
    useCached: useCached,
  );
}

Stream<CardPage> _pendingPrivatePageStream(
  Ref ref, {
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required Future<CardPage> Function(BackendRepository, CancelToken) fetch,
}) {
  final controller = StreamController<CardPage>();
  final repository = ref.read(backendRepositoryProvider);
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  StreamSubscription<CardPage>? subscription;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    cancelToken.cancel();
    final activeSubscription = subscription;
    if (activeSubscription != null) {
      unawaited(activeSubscription.cancel());
    }
    unawaited(controller.close());
  });
  unawaited(() async {
    try {
      await ref.read(authBootstrapProvider.future);
      if (disposed) {
        return;
      }
      final userId = ref.read(currentUserIdProvider);
      if (userId == null || ref.read(authTokensProvider) == null) {
        controller.add(const BackendPage(items: []));
        await controller.close();
        return;
      }
      final stream = _localFirstPageStreamForScope(
        namespace: namespace,
        cacheValue: cacheValue,
        ttl: ttl,
        repository: repository,
        localFirst: localFirst,
        cancelToken: cancelToken,
        userScope: AppCacheUserScope.user(userId),
        fetch: fetch,
      );
      subscription = stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    } catch (error, stackTrace) {
      if (!disposed) {
        controller.addError(error, stackTrace);
      }
    }
  }());
  return controller.stream;
}

Future<T> _pendingPrivateValueFuture<T>(
  Ref ref, {
  required T fallback,
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required Future<T> Function(BackendRepository, CancelToken) fetch,
  required Map<String, Object?> Function(T) encode,
  required T Function(Map<String, Object?>) decode,
}) async {
  final repository = ref.read(backendRepositoryProvider);
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    cancelToken.cancel();
  });
  await ref.read(authBootstrapProvider.future);
  if (disposed) {
    return fallback;
  }
  final userId = ref.read(currentUserIdProvider);
  if (userId == null || ref.read(authTokensProvider) == null) {
    return fallback;
  }
  return _localFirstValueFutureForScope<T>(
    namespace: namespace,
    cacheValue: cacheValue,
    ttl: ttl,
    repository: repository,
    localFirst: localFirst,
    cancelToken: cancelToken,
    userScope: AppCacheUserScope.user(userId),
    fetch: fetch,
    encode: encode,
    decode: decode,
  );
}

String? _currentCity(Ref ref) {
  final city = ref.watch(currentUserProvider)?.city?.trim();
  return city == null || city.isEmpty ? null : city;
}

String _todayIsoDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

Stream<CardPage> _localFirstPageStream(
  Ref ref, {
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required Future<CardPage> Function(BackendRepository, CancelToken) fetch,
}) {
  final repository = ref.read(backendRepositoryProvider);
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return _localFirstPageStreamForScope(
    namespace: namespace,
    cacheValue: cacheValue,
    ttl: ttl,
    repository: repository,
    localFirst: localFirst,
    cancelToken: cancelToken,
    userScope: ref.watch(currentCacheScopeProvider),
    fetch: fetch,
  );
}

Stream<CardPage> _localFirstPageStreamForScope({
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required BackendRepository repository,
  required LocalFirstRepository? localFirst,
  required CancelToken cancelToken,
  required AppCacheUserScope userScope,
  required Future<CardPage> Function(BackendRepository, CancelToken) fetch,
}) {
  if (localFirst == null) {
    return _withoutCancelledRequestError(
      Stream.fromFuture(fetch(repository, cancelToken)),
    );
  }
  return localFirst.watch<CardPage>(
    key: AppCacheKey(
      namespace: namespace,
      value: cacheValue,
      userScope: userScope,
    ),
    ttl: ttl,
    policy: _cacheReadPolicyForNamespace(namespace),
    network: () async {
      final page = await fetch(repository, cancelToken);
      return page.raw.isEmpty
          ? {'items': page.items.map((item) => item.raw).toList()}
          : page.raw;
    },
    decode: _decodeCardPage,
  );
}

Future<T> _localFirstValueFuture<T>(
  Ref ref, {
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required Future<T> Function(BackendRepository, CancelToken) fetch,
  required Map<String, Object?> Function(T) encode,
  required T Function(Map<String, Object?>) decode,
  bool Function(Map<String, Object?> json)? useCached,
}) {
  final repository = ref.read(backendRepositoryProvider);
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return _localFirstValueFutureForScope<T>(
    namespace: namespace,
    cacheValue: cacheValue,
    ttl: ttl,
    repository: repository,
    localFirst: localFirst,
    cancelToken: cancelToken,
    userScope: ref.watch(currentCacheScopeProvider),
    fetch: fetch,
    encode: encode,
    decode: decode,
    useCached: useCached,
  );
}

Stream<T> _localFirstValueStream<T>(
  Ref ref, {
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required Future<T> Function(BackendRepository, CancelToken) fetch,
  required Map<String, Object?> Function(T) encode,
  required T Function(Map<String, Object?>) decode,
  bool Function(Map<String, Object?> json)? useCached,
}) {
  final repository = ref.read(backendRepositoryProvider);
  final localFirst = ref.read(localFirstRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return _localFirstValueStreamForScope<T>(
    namespace: namespace,
    cacheValue: cacheValue,
    ttl: ttl,
    repository: repository,
    localFirst: localFirst,
    cancelToken: cancelToken,
    userScope: ref.watch(currentCacheScopeProvider),
    fetch: fetch,
    encode: encode,
    decode: decode,
    useCached: useCached,
  );
}

Future<T> _localFirstValueFutureForScope<T>({
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required BackendRepository repository,
  required LocalFirstRepository? localFirst,
  required CancelToken cancelToken,
  required AppCacheUserScope userScope,
  required Future<T> Function(BackendRepository, CancelToken) fetch,
  required Map<String, Object?> Function(T) encode,
  required T Function(Map<String, Object?>) decode,
  bool Function(Map<String, Object?> json)? useCached,
}) {
  if (localFirst == null) {
    return fetch(repository, cancelToken);
  }
  return localFirst.fetch<T>(
    key: AppCacheKey(
      namespace: namespace,
      value: cacheValue,
      userScope: userScope,
    ),
    ttl: ttl,
    policy: _cacheReadPolicyForNamespace(namespace),
    network: () async {
      final value = await fetch(repository, cancelToken);
      return encode(value);
    },
    decode: decode,
    useCached: useCached,
  );
}

Stream<T> _localFirstValueStreamForScope<T>({
  required String namespace,
  required String cacheValue,
  required Duration ttl,
  required BackendRepository repository,
  required LocalFirstRepository? localFirst,
  required CancelToken cancelToken,
  required AppCacheUserScope userScope,
  required Future<T> Function(BackendRepository, CancelToken) fetch,
  required Map<String, Object?> Function(T) encode,
  required T Function(Map<String, Object?>) decode,
  bool Function(Map<String, Object?> json)? useCached,
}) {
  if (localFirst == null) {
    return _withoutCancelledRequestError(
      Stream.fromFuture(fetch(repository, cancelToken)),
    );
  }
  return _withoutCancelledRequestError(
    localFirst.watch<T>(
      key: AppCacheKey(
        namespace: namespace,
        value: cacheValue,
        userScope: userScope,
      ),
      ttl: ttl,
      policy: _cacheReadPolicyForNamespace(namespace),
      network: () async {
        final value = await fetch(repository, cancelToken);
        return encode(value);
      },
      decode: decode,
      useCached: useCached,
    ),
  );
}

Stream<T> _withoutCancelledRequestError<T>(Stream<T> stream) async* {
  try {
    yield* stream;
  } on DioException catch (error) {
    if (error.type == DioExceptionType.cancel) {
      return;
    }
    rethrow;
  }
}

LocalCacheReadPolicy _cacheReadPolicyForNamespace(String namespace) {
  return switch (namespace) {
    'payments' ||
    'subscription' ||
    'verification' ||
    'safety' ||
    'reports' ||
    'blocks' ||
    'after_dark_access' ||
    'settings' ||
    'wallet' =>
      LocalCacheReadPolicy.sensitiveFreshOnly,
    _ => LocalCacheReadPolicy.staleWhileRefresh,
  };
}

bool _canUseCachedMeetingDetail(Map<String, Object?> json) {
  final access = _firstCacheLower(json, const [
    'accessMode',
    'joinMode',
    'visibilityMode',
  ]);
  final requestOnly = access == 'request' || access == 'friends';
  if (!requestOnly) {
    return true;
  }
  final joined = json['joined'] ?? json['isJoined'];
  if (joined is bool) {
    return joined;
  }
  final state = _firstCacheLower(json, const [
    'participantState',
    'viewerState',
    'participationState',
    'attendanceState',
    'rsvpState',
  ]);
  return state == 'joined' ||
      state == 'going' ||
      state == 'approved' ||
      state == 'participant' ||
      state == 'host';
}

String? _firstCacheLower(
  Map<String, Object?> json,
  Iterable<String> keys,
) {
  for (final key in keys) {
    final value = json[key]?.toString().trim().toLowerCase();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

CardPage _decodeCardPage(Map<String, Object?> json) {
  return BackendPage(
    items: _items(json).map(BackendCardItem.fromJson).toList(growable: false),
    nextCursor: json['nextCursor']?.toString(),
    raw: json,
  );
}

SafetyReportPage _decodeSafetyReportPage(Map<String, Object?> json) {
  return BackendPage(
    items: _items(json).map(SafetyReportData.fromJson).toList(growable: false),
    nextCursor: json['nextCursor']?.toString(),
    raw: json,
  );
}

BlockedUserPage _decodeBlockedUserPage(Map<String, Object?> json) {
  return BackendPage(
    items: _items(json).map(BlockedUserData.fromJson).toList(growable: false),
    nextCursor: json['nextCursor']?.toString(),
    raw: json,
  );
}

List<Map<String, Object?>> _items(Map<String, Object?> json) {
  final value = json['items'];
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList(growable: false);
}
