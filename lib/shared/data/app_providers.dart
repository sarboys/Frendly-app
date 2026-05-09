import 'dart:async';
import 'dart:typed_data';

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/network/chat_socket_client.dart';
import 'package:big_break_mobile/app/core/device/app_permission_preferences.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/shared/models/match.dart';
import 'package:big_break_mobile/shared/models/after_party_state.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/models/notification_item.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/story.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_check_in.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/host_dashboard.dart';
import 'package:big_break_mobile/shared/models/live_meetup.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/personal_chat.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/models/safety_hub.dart';
import 'package:big_break_mobile/shared/models/subscription.dart';
import 'package:big_break_mobile/shared/models/tokens.dart';
import 'package:big_break_mobile/shared/models/user_settings.dart';
import 'package:big_break_mobile/shared/models/verification_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final profilePhotoDraftProvider =
    StateProvider<List<ProfilePhoto>>((ref) => const []);

final profilePhotoPreviewProvider =
    StateProvider<Map<String, Uint8List>>((ref) => const {});

final profileProvider = FutureProvider<ProfileData>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final draftPhotos = ref.watch(profilePhotoDraftProvider);
  final repository = ref.read(backendRepositoryProvider);
  final onboardingFuture = ref.watch(onboardingProvider.future);
  final bootstrapProfileState = ref.read(authBootstrapProfileProvider.notifier);
  await authBootstrap;
  final bootstrapProfile = bootstrapProfileState.state;
  if (bootstrapProfile != null) {
    bootstrapProfileState.state = null;
  }
  final profileFuture = bootstrapProfile == null
      ? repository.fetchMe()
      : Future.value(bootstrapProfile);
  final profile = await profileFuture;
  final onboarding = await onboardingFuture;
  return mergeProfileDraftPhotos(
    profile.withOnboarding(onboarding),
    draftPhotos,
  );
});

final onboardingLocalStateProvider =
    StateProvider<OnboardingData?>((ref) => null);

final onboardingProvider = FutureProvider<OnboardingData>((ref) async {
  final localValue = ref.watch(onboardingLocalStateProvider);
  if (localValue != null) {
    return localValue;
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchOnboarding();
});

final eventsProvider =
    FutureProvider.family<List<Event>, String>((ref, filter) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final manualLocation = ref.watch(manualLocationProvider);
  final radiusKm =
      filter == 'nearby' ? ref.watch(nearbyEventsRadiusKmProvider) : null;
  final repository = ref.read(backendRepositoryProvider);
  final locationService = filter == 'nearby' && manualLocation == null
      ? ref.read(appLocationServiceProvider)
      : null;
  await authBootstrap;
  final location = await _eventFeedLocation(
    filter,
    manualLocation,
    locationService,
  );
  return repository
      .fetchEvents(
        filter: filter,
        latitude: location?.latitude,
        longitude: location?.longitude,
        radiusKm: location == null ? null : radiusKm,
      )
      .then((value) => value.items);
});

Future<({double latitude, double longitude})?> _eventFeedLocation(
  String filter,
  ManualLocation? manualLocation,
  AppLocationService? locationService,
) async {
  if (filter != 'nearby') {
    return null;
  }

  if (manualLocation != null) {
    return (
      latitude: manualLocation.latitude,
      longitude: manualLocation.longitude,
    );
  }

  try {
    final position = await locationService?.getCurrentPosition();
    if (position == null) {
      return null;
    }
    return (
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (_) {
    return null;
  }
}

class MapEventsQuery {
  const MapEventsQuery({
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
    this.southWestLatitude,
    this.southWestLongitude,
    this.northEastLatitude,
    this.northEastLongitude,
    this.limit = 50,
  });

  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;
  final double? southWestLatitude;
  final double? southWestLongitude;
  final double? northEastLatitude;
  final double? northEastLongitude;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is MapEventsQuery &&
        other.centerLatitude == centerLatitude &&
        other.centerLongitude == centerLongitude &&
        other.radiusKm == radiusKm &&
        other.southWestLatitude == southWestLatitude &&
        other.southWestLongitude == southWestLongitude &&
        other.northEastLatitude == northEastLatitude &&
        other.northEastLongitude == northEastLongitude &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
        centerLatitude,
        centerLongitude,
        radiusKm,
        southWestLatitude,
        southWestLongitude,
        northEastLatitude,
        northEastLongitude,
        limit,
      );
}

final mapEventsProvider = FutureProvider.autoDispose
    .family<List<Event>, MapEventsQuery>((ref, query) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository
      .fetchEvents(
        filter: 'nearby',
        limit: query.limit,
        latitude: query.centerLatitude,
        longitude: query.centerLongitude,
        radiusKm: query.radiusKm,
        southWestLatitude: query.southWestLatitude,
        southWestLongitude: query.southWestLongitude,
        northEastLatitude: query.northEastLatitude,
        northEastLongitude: query.northEastLongitude,
        cancelToken: cancelToken,
      )
      .then((value) => value.items);
});

final eventDetailProvider = FutureProvider.autoDispose
    .family<EventDetail, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchEventDetail(eventId, cancelToken: cancelToken);
});

class AfficheEventsQuery {
  const AfficheEventsQuery({
    required this.city,
    this.query = '',
    this.date,
    this.priceMode = 'any',
    this.source,
    this.category,
    this.featured,
    this.limit = 12,
  });

  final String city;
  final String query;
  final String? date;
  final String priceMode;
  final String? source;
  final String? category;
  final bool? featured;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is AfficheEventsQuery &&
        other.city == city &&
        other.query == query &&
        other.date == date &&
        other.priceMode == priceMode &&
        other.source == source &&
        other.category == category &&
        other.featured == featured &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
        city,
        query,
        date,
        priceMode,
        source,
        category,
        featured,
        limit,
      );
}

final afficheEventsProvider =
    FutureProvider.autoDispose.family<List<AfficheEvent>, AfficheEventsQuery>((
  ref,
  query,
) async {
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  return repository
      .fetchAfficheEvents(
        city: query.city,
        q: query.query.isEmpty ? null : query.query,
        date: query.date,
        priceMode: query.priceMode,
        source: query.source,
        category: query.category,
        featured: query.featured,
        limit: query.limit,
        cancelToken: cancelToken,
      )
      .then((value) => value.items);
});

const _afficheFilterPageCacheTtl = Duration(minutes: 3);

class AfficheEventsPagedState {
  const AfficheEventsPagedState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<AfficheEvent> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  AfficheEventsPagedState copyWith({
    List<AfficheEvent>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
  }) {
    return AfficheEventsPagedState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final afficheEventsPagedProvider = StateNotifierProvider.autoDispose.family<
    AfficheEventsPager,
    AsyncValue<AfficheEventsPagedState>,
    AfficheEventsQuery>((ref, query) {
  if (query.query.isEmpty) {
    final keepAliveLink = ref.keepAlive();
    Timer? cacheTimer;

    ref.onCancel(() {
      cacheTimer?.cancel();
      cacheTimer = Timer(_afficheFilterPageCacheTtl, keepAliveLink.close);
    });
    ref.onResume(() {
      cacheTimer?.cancel();
      cacheTimer = null;
    });
    ref.onDispose(() {
      cacheTimer?.cancel();
    });
  }

  final pager = AfficheEventsPager(ref, query);
  unawaited(pager.loadFirstPage());
  return pager;
});

class AfficheEventsPager
    extends StateNotifier<AsyncValue<AfficheEventsPagedState>> {
  AfficheEventsPager(this.ref, this.query) : super(const AsyncLoading()) {
    ref.onDispose(() {
      if (!_cancelToken.isCancelled) {
        _cancelToken.cancel('affiche_pager_disposed');
      }
    });
  }

  final Ref ref;
  final AfficheEventsQuery query;
  final _cancelToken = CancelToken();

  Future<void> loadFirstPage() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final page = await _fetchPage();
      return AfficheEventsPagedState(
        items: page.items,
        nextCursor: page.nextCursor,
      );
    });
    if (!mounted) {
      return;
    }
    state = result;
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.isLoadingMore ||
        current.nextCursor == null) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _fetchPage(cursor: current.nextCursor);
      if (!mounted) {
        return;
      }
      state = AsyncData(
        AfficheEventsPagedState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (mounted) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<PaginatedResponse<AfficheEvent>> _fetchPage({String? cursor}) async {
    final repository = ref.read(backendRepositoryProvider);
    return repository.fetchAfficheEvents(
      city: query.city,
      q: query.query.isEmpty ? null : query.query,
      date: query.date,
      priceMode: query.priceMode,
      source: query.source,
      category: query.category,
      featured: query.featured,
      cursor: cursor,
      limit: query.limit,
      cancelToken: _cancelToken,
    );
  }
}

final afficheEventDetailProvider = FutureProvider.autoDispose
    .family<AfficheEvent, String>((ref, eventId) async {
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  return repository.fetchAfficheEventDetail(eventId, cancelToken: cancelToken);
});

final checkInProvider = FutureProvider.autoDispose
    .family<EventCheckInData, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchCheckIn(eventId, cancelToken: cancelToken);
});

final liveMeetupProvider = FutureProvider.autoDispose
    .family<LiveMeetupData, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchLiveMeetup(eventId, cancelToken: cancelToken);
});

final afterPartyProvider = FutureProvider.autoDispose
    .family<AfterPartyData, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchAfterParty(eventId, cancelToken: cancelToken);
});

final hostDashboardProvider =
    FutureProvider.autoDispose<HostDashboardData>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchHostDashboard(cancelToken: cancelToken);
});

final hostEventProvider = FutureProvider.autoDispose
    .family<HostEventData, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchHostEvent(eventId, cancelToken: cancelToken);
});

final settingsProvider = FutureProvider<UserSettingsData>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final authTokens = ref.read(authTokensProvider.notifier);
  final currentUser = ref.read(currentUserIdProvider.notifier);
  final permissionPreferences = ref.read(appPermissionPreferencesProvider);
  await authBootstrap;
  bool sessionStillCurrent(AuthTokens? expectedTokens, String expectedUserId) {
    final currentTokens = authTokens.currentTokens;
    return currentUser.state == expectedUserId &&
        currentTokens?.accessToken == expectedTokens?.accessToken &&
        currentTokens?.refreshToken == expectedTokens?.refreshToken;
  }

  final userId = currentUser.state;
  final sessionTokens = authTokens.currentTokens;
  if (userId == null || sessionTokens == null) {
    return UserSettingsData.fallback;
  }
  final settings = await repository.fetchSettings();
  if (!sessionStillCurrent(sessionTokens, userId)) {
    return UserSettingsData.fallback;
  }
  await permissionPreferences.syncFromSettings(settings);
  if (!sessionStillCurrent(sessionTokens, userId)) {
    return UserSettingsData.fallback;
  }
  return settings;
});

final verificationProvider =
    FutureProvider.autoDispose<VerificationStateData>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchVerification(cancelToken: cancelToken);
});

final safetyHubProvider =
    FutureProvider.autoDispose<SafetyHubData>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchSafetyHub(cancelToken: cancelToken);
});

final storiesProvider = FutureProvider.autoDispose
    .family<List<StoryData>, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchStories(eventId, cancelToken: cancelToken);
});

final matchesProvider =
    FutureProvider.autoDispose<List<MatchData>>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchMatches(cancelToken: cancelToken);
});

final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanData>>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchSubscriptionPlans();
});

final subscriptionStateProvider =
    FutureProvider<SubscriptionStateData>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchSubscriptionState();
});

final peopleProvider = FutureProvider<List<PersonSummary>>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchPeople().then((value) => value.items);
});

final personProfileProvider =
    FutureProvider.autoDispose.family<ProfileData, String>((ref, userId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchPersonProfile(userId, cancelToken: cancelToken);
});

final profileSocialProvider = StateNotifierProvider.autoDispose
    .family<ProfileSocialController, AsyncValue<ProfileSocialData>, String>(
        (ref, userId) {
  final initial = ref.watch(personProfileProvider(userId)).valueOrNull?.social;
  final controller = ProfileSocialController(ref, userId, initial);
  if (initial == null) {
    unawaited(controller.load());
  }
  return controller;
});

class ProfileSocialController
    extends StateNotifier<AsyncValue<ProfileSocialData>> {
  ProfileSocialController(this.ref, this.userId, ProfileSocialData? initial)
      : super(initial == null ? const AsyncLoading() : AsyncData(initial)) {
    ref.onDispose(() {
      final cancelToken = _loadCancelToken;
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('profile_social_disposed');
      }
    });
  }

  final Ref ref;
  final String userId;
  CancelToken? _loadCancelToken;

  Future<void> load() async {
    final cancelToken = _replaceLoadCancelToken();
    final repository = ref.read(backendRepositoryProvider);
    final result = await AsyncValue.guard(
      () => repository.fetchProfileSocial(userId, cancelToken: cancelToken),
    );
    try {
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_loadCancelToken, cancelToken)) {
        return;
      }
      state = result;
    } finally {
      if (identical(_loadCancelToken, cancelToken)) {
        _loadCancelToken = null;
      }
    }
  }

  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final next = current.copyWith(
      iFollow: !current.iFollow,
      followers: current.followers + (current.iFollow ? -1 : 1),
    );
    final repository = ref.read(backendRepositoryProvider);
    await _submitOptimistic(
      next,
      () => repository.setProfileFollow(
        userId,
        follow: !current.iFollow,
      ),
    );
  }

  Future<void> toggleLike() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final next = current.copyWith(
      iLike: !current.iLike,
      likes: current.likes + (current.iLike ? -1 : 1),
    );
    final repository = ref.read(backendRepositoryProvider);
    await _submitOptimistic(
      next,
      () => repository.setProfileReaction(
        userId,
        kind: 'like',
        active: !current.iLike,
      ),
    );
  }

  Future<void> toggleSuper() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final next = current.copyWith(
      iSuper: !current.iSuper,
      superLikes: current.superLikes + (current.iSuper ? -1 : 1),
    );
    final repository = ref.read(backendRepositoryProvider);
    await _submitOptimistic(
      next,
      () => repository.setProfileReaction(
        userId,
        kind: 'super_like',
        active: !current.iSuper,
      ),
    );
  }

  Future<void> _submitOptimistic(
    ProfileSocialData optimistic,
    Future<ProfileSocialData> Function() submit,
  ) async {
    final previous = state;
    state = AsyncData(optimistic);
    try {
      final result = await submit();
      if (!mounted) {
        return;
      }
      state = AsyncData(result);
    } catch (error, stackTrace) {
      if (mounted) {
        state = previous;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  CancelToken _replaceLoadCancelToken() {
    final activeToken = _loadCancelToken;
    if (activeToken != null && !activeToken.isCancelled) {
      activeToken.cancel('profile_social_load_replaced');
    }
    final cancelToken = CancelToken();
    _loadCancelToken = cancelToken;
    return cancelToken;
  }
}

final meetupChatsLocalStateProvider =
    StateProvider<List<MeetupChat>?>((ref) => null);

final meetupChatsProvider = FutureProvider<List<MeetupChat>>((ref) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final localItems = ref.watch(meetupChatsLocalStateProvider);
  if (localItems != null) {
    return localItems;
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchMeetupChats().then((value) => value.items);
});

final meetupChatSummaryProvider =
    Provider.autoDispose.family<MeetupChat?, String>((ref, chatId) {
  return ref.watch(meetupChatsProvider.select((value) {
    final items = value.valueOrNull;
    if (items == null) {
      return null;
    }

    for (final chat in items) {
      if (chat.id == chatId) {
        return chat;
      }
    }

    return null;
  }));
});

final eveningSessionsProvider =
    FutureProvider<List<EveningSessionSummary>>((ref) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchEveningSessions().then((value) => value.items);
});

final eveningSessionProvider = FutureProvider.autoDispose
    .family<EveningSessionDetail, String>((ref, sessionId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchEveningSession(sessionId, cancelToken: cancelToken);
});

final eveningRouteTemplatesProvider =
    FutureProvider.family<List<EveningRouteTemplateSummary>, String>(
        (ref, city) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository
      .fetchEveningRouteTemplates(city: city)
      .then((value) => value.items);
});

final eveningRouteTemplateProvider = FutureProvider.autoDispose
    .family<EveningRouteTemplateDetail, String>((ref, templateId) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    throw StateError('Evening route template requires auth');
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchEveningRouteTemplate(
    templateId,
    cancelToken: cancelToken,
  );
});

final eveningRouteTemplateSessionsProvider = FutureProvider.autoDispose
    .family<List<EveningRouteTemplateSession>, String>((ref, templateId) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository
      .fetchEveningRouteTemplateSessions(
        templateId,
        cancelToken: cancelToken,
      )
      .then((value) => value.items);
});

final personalChatsLocalStateProvider =
    StateProvider<List<PersonalChat>?>((ref) => null);

final personalChatsProvider = FutureProvider<List<PersonalChat>>((ref) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final localItems = ref.watch(personalChatsLocalStateProvider);
  if (localItems != null) {
    return localItems;
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchPersonalChats().then((value) => value.items);
});

final personalChatSummaryProvider =
    Provider.autoDispose.family<PersonalChat?, String>((ref, chatId) {
  return ref.watch(personalChatsProvider.select((value) {
    final items = value.valueOrNull;
    if (items == null) {
      return null;
    }

    for (final chat in items) {
      if (chat.id == chatId) {
        return chat;
      }
    }

    return null;
  }));
});

final notificationsLocalStateProvider =
    StateProvider<List<NotificationItem>?>((ref) => null);

final notificationsProvider =
    FutureProvider<List<NotificationItem>>((ref) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }

  final localItems = ref.watch(notificationsLocalStateProvider);
  if (localItems != null) {
    return localItems;
  }
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchNotifications().then((value) => value.items);
});

final notificationUnreadCountOverrideProvider =
    StateProvider<int?>((ref) => null);

final notificationUnreadCountProvider = FutureProvider<int>((ref) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return 0;
  }

  final overrideCount = ref.watch(notificationUnreadCountOverrideProvider);
  if (overrideCount != null) {
    return overrideCount;
  }

  final localItems = ref.watch(notificationsLocalStateProvider);
  if (localItems != null) {
    return localItems.where((item) => item.unread).length;
  }

  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchUnreadNotificationCount();
});

final chatUnreadBadgeProvider = Provider<int>((ref) {
  final meetupUnread = ref.watch(meetupChatsProvider.select((value) {
    final items = value.valueOrNull;
    if (items == null) {
      return 0;
    }

    return items.fold<int>(0, (sum, item) => sum + item.unread);
  }));
  final personalUnread = ref.watch(personalChatsProvider.select((value) {
    final items = value.valueOrNull;
    if (items == null) {
      return 0;
    }

    return items.fold<int>(0, (sum, item) => sum + item.unread);
  }));

  return meetupUnread + personalUnread;
});

CancelToken _autoDisposeCancelToken(Ref ref) {
  final cancelToken = CancelToken();
  ref.onDispose(() {
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('provider_disposed');
    }
  });
  return cancelToken;
}

final hasLiveMeetupChatProvider = Provider<bool>((ref) {
  return ref.watch(meetupChatsProvider.select((value) {
    final items = value.valueOrNull;
    if (items == null) {
      return false;
    }

    return items.any((item) => item.phase == MeetupPhase.live);
  }));
});

final chatRealtimeSyncProvider = Provider<void>((ref) {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return;
  }

  final coordinator = _ChatRealtimeSyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);
});

ProfileData mergeProfileDraftPhotos(
  ProfileData profile,
  List<ProfilePhoto> draftPhotos,
) {
  if (draftPhotos.isEmpty) {
    return profile;
  }

  final existingIds = profile.photos.map((photo) => photo.id).toSet();
  final mergedPhotos = [
    ...profile.photos,
    ...draftPhotos.where((photo) => !existingIds.contains(photo.id)),
  ];

  if (mergedPhotos.isEmpty) {
    return profile;
  }

  return profile.copyWith(
    avatarUrl: mergedPhotos.first.url,
    photos: mergedPhotos,
  );
}

List<MeetupChat> upsertMeetupChatSummary(
  List<MeetupChat> chats, {
  required String chatId,
  required String lastMessage,
  required String lastAuthor,
  required String lastTime,
  required int unread,
}) {
  final updated = chats
      .map(
        (chat) => chat.id == chatId
            ? chat.copyWith(
                lastMessage: lastMessage,
                lastAuthor: lastAuthor,
                lastTime: lastTime,
                unread: unread,
                typing: false,
              )
            : chat,
      )
      .toList(growable: false);

  final index = updated.indexWhere((chat) => chat.id == chatId);
  if (index <= 0) {
    return sortMeetupChatsByPinned(updated);
  }

  return sortMeetupChatsByPinned([
    updated[index],
    ...updated.take(index),
    ...updated.skip(index + 1),
  ]);
}

List<MeetupChat> upsertMeetupChat(
  List<MeetupChat> chats,
  MeetupChat nextChat,
) {
  return sortMeetupChatsByPinned([
    nextChat,
    ...chats.where((chat) => chat.id != nextChat.id),
  ]);
}

void clearChatListLocalStateForRefetch(Ref ref) {
  ref.read(meetupChatsLocalStateProvider.notifier).state = null;
  ref.read(personalChatsLocalStateProvider.notifier).state = null;
}

List<PersonalChat> upsertPersonalChatSummary(
  List<PersonalChat> chats, {
  required String chatId,
  required String lastMessage,
  required String lastTime,
  required int unread,
}) {
  final updated = chats
      .map(
        (chat) => chat.id == chatId
            ? chat.copyWith(
                lastMessage: lastMessage,
                lastTime: lastTime,
                unread: unread,
              )
            : chat,
      )
      .toList(growable: false);

  final index = updated.indexWhere((chat) => chat.id == chatId);
  if (index <= 0) {
    return sortPersonalChatsByPinned(updated);
  }

  return sortPersonalChatsByPinned([
    updated[index],
    ...updated.take(index),
    ...updated.skip(index + 1),
  ]);
}

List<MeetupChat> sortMeetupChatsByPinned(List<MeetupChat> chats) {
  return [
    ...chats.where((chat) => chat.isPinned),
    ...chats.where((chat) => !chat.isPinned),
  ];
}

List<PersonalChat> sortPersonalChatsByPinned(List<PersonalChat> chats) {
  return [
    ...chats.where((chat) => chat.isPinned),
    ...chats.where((chat) => !chat.isPinned),
  ];
}

List<MeetupChat> setMeetupChatTyping(
  List<MeetupChat> chats, {
  required String chatId,
  required bool isTyping,
}) {
  return chats
      .map(
        (chat) => chat.id == chatId ? chat.copyWith(typing: isTyping) : chat,
      )
      .toList(growable: false);
}

List<MeetupChat> setMeetupChatUnread(
  List<MeetupChat> chats, {
  required String chatId,
  required int unread,
}) {
  return chats
      .map(
        (chat) => chat.id == chatId ? chat.copyWith(unread: unread) : chat,
      )
      .toList(growable: false);
}

List<PersonalChat> setPersonalChatUnread(
  List<PersonalChat> chats, {
  required String chatId,
  required int unread,
}) {
  return chats
      .map(
        (chat) => chat.id == chatId ? chat.copyWith(unread: unread) : chat,
      )
      .toList(growable: false);
}

List<MeetupChat> updateMeetupChatFromRealtime(
  List<MeetupChat> chats, {
  required String chatId,
  MeetupPhase? phase,
  bool hasCurrentStep = false,
  int? currentStep,
  bool hasTotalSteps = false,
  int? totalSteps,
  bool hasCurrentPlace = false,
  String? currentPlace,
  bool hasEndTime = false,
  String? endTime,
  String? startsInLabel,
}) {
  return chats
      .map(
        (chat) => chat.id == chatId
            ? MeetupChat(
                id: chat.id,
                eventId: chat.eventId,
                title: chat.title,
                emoji: chat.emoji,
                time: chat.time,
                lastMessage: chat.lastMessage,
                lastAuthor: chat.lastAuthor,
                lastTime: chat.lastTime,
                unread: chat.unread,
                members: chat.members,
                memberProfiles: chat.memberProfiles,
                status: chat.status,
                isPinned: chat.isPinned,
                typing: chat.typing,
                isAfterDark: chat.isAfterDark,
                afterDarkGlow: chat.afterDarkGlow,
                phase: phase ?? chat.phase,
                currentStep: hasCurrentStep ? currentStep : chat.currentStep,
                totalSteps: hasTotalSteps ? totalSteps : chat.totalSteps,
                currentPlace:
                    hasCurrentPlace ? currentPlace : chat.currentPlace,
                endTime: hasEndTime ? endTime : chat.endTime,
                startsInLabel: startsInLabel ?? chat.startsInLabel,
                routeId: chat.routeId,
                routeTemplateId: chat.routeTemplateId,
                isCurated: chat.isCurated,
                badgeLabel: chat.badgeLabel,
                sessionId: chat.sessionId,
                mode: chat.mode,
                privacy: chat.privacy,
                joinedCount: chat.joinedCount,
                maxGuests: chat.maxGuests,
                hostUserId: chat.hostUserId,
                hostName: chat.hostName,
                area: chat.area,
                ticketUrl: chat.ticketUrl,
                ticketSourceKind: chat.ticketSourceKind,
                ticketSourceId: chat.ticketSourceId,
                ticketPriceFrom: chat.ticketPriceFrom,
                ticketProvider: chat.ticketProvider,
                ticketVenue: chat.ticketVenue,
              )
            : chat,
      )
      .toList(growable: false);
}

List<NotificationItem> prependNotificationItem(
  List<NotificationItem> items,
  NotificationItem notification,
) {
  return [
    notification,
    ...items.where((item) => item.id != notification.id),
  ];
}

class _ChatRealtimeSyncCoordinator {
  _ChatRealtimeSyncCoordinator(this.ref)
      : _socket = ref.read(chatSocketClientProvider) {
    _eventsSubscription = _socket.events.listen(_handleSocketEvent);

    ref.listen<AsyncValue<List<MeetupChat>>>(meetupChatsProvider, (_, __) {
      _syncSubscriptions();
    });
    ref.listen<AsyncValue<List<PersonalChat>>>(personalChatsProvider, (_, __) {
      _syncSubscriptions();
    });

    unawaited(_connectAndSync());
  }

  final Ref ref;
  final ChatSocketClient _socket;
  final _subscribedChatIds = <String>{};
  late final StreamSubscription<Map<String, dynamic>> _eventsSubscription;
  bool _disposed = false;

  Future<void> dispose() async {
    _disposed = true;
    for (final chatId in _subscribedChatIds) {
      _socket.unsubscribe(chatId);
    }
    _subscribedChatIds.clear();
    await _eventsSubscription.cancel();
  }

  Future<void> _connectAndSync() async {
    try {
      await _socket.connect();
      if (_disposed) {
        return;
      }
      _syncSubscriptions();
    } catch (_) {}
  }

  void _syncSubscriptions() {
    if (_disposed) {
      return;
    }

    final nextChatIds = <String>{
      ...(ref.read(meetupChatsProvider).valueOrNull ?? const <MeetupChat>[])
          .map((chat) => chat.id),
      ...(ref.read(personalChatsProvider).valueOrNull ?? const <PersonalChat>[])
          .map((chat) => chat.id),
    };

    final removedChatIds = _subscribedChatIds.difference(nextChatIds);
    for (final chatId in removedChatIds) {
      _socket.unsubscribe(chatId);
    }

    final addedChatIds = nextChatIds.difference(_subscribedChatIds);
    for (final chatId in addedChatIds) {
      _socket.subscribe(chatId);
    }

    _subscribedChatIds
      ..clear()
      ..addAll(nextChatIds);
  }

  void _handleSocketEvent(Map<String, dynamic> envelope) {
    final type = envelope['type'] as String?;
    final payload = envelope['payload'];

    if (payload is! Map<String, dynamic>) {
      return;
    }

    switch (type) {
      case 'message.created':
        _applyMessageCreated(payload);
        return;
      case 'typing.changed':
        _applyTypingChanged(payload);
        return;
      case 'unread.updated':
        _applyUnreadUpdated(payload);
        return;
      case 'chat.updated':
        _applyChatUpdated(payload);
        return;
      case 'notification.created':
        _applyNotificationCreated(payload);
        return;
    }
  }

  void _applyMessageCreated(Map<String, dynamic> payload) {
    final chatId = payload['chatId'] as String?;
    if (chatId == null) {
      return;
    }

    final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
    final message = Message.fromJson(payload, currentUserId: currentUserId);
    final preview = _buildMessagePreview(message);

    final meetupChats = ref.read(meetupChatsProvider).valueOrNull ?? const [];
    final meetupChat =
        meetupChats.where((chat) => chat.id == chatId).firstOrNull;
    if (meetupChat != null) {
      ref.read(meetupChatsLocalStateProvider.notifier).state =
          upsertMeetupChatSummary(
        meetupChats,
        chatId: chatId,
        lastMessage: preview,
        lastAuthor: message.author,
        lastTime: message.time,
        unread: meetupChat.unread,
      );
      return;
    }

    final personalChats =
        ref.read(personalChatsProvider).valueOrNull ?? const [];
    final personalChat =
        personalChats.where((chat) => chat.id == chatId).firstOrNull;
    if (personalChat != null) {
      ref.read(personalChatsLocalStateProvider.notifier).state =
          upsertPersonalChatSummary(
        personalChats,
        chatId: chatId,
        lastMessage: preview,
        lastTime: message.time,
        unread: personalChat.unread,
      );
      return;
    }

    clearChatListLocalStateForRefetch(ref);
    ref.invalidate(meetupChatsProvider);
    ref.invalidate(personalChatsProvider);
  }

  void _applyTypingChanged(Map<String, dynamic> payload) {
    final chatId = payload['chatId'] as String?;
    final isTyping = payload['isTyping'] as bool?;
    if (chatId == null || isTyping == null) {
      return;
    }

    final meetupChats = ref.read(meetupChatsProvider).valueOrNull ?? const [];
    if (meetupChats.any((chat) => chat.id == chatId)) {
      ref.read(meetupChatsLocalStateProvider.notifier).state =
          setMeetupChatTyping(
        meetupChats,
        chatId: chatId,
        isTyping: isTyping,
      );
    }
  }

  void _applyUnreadUpdated(Map<String, dynamic> payload) {
    final chatId = payload['chatId'] as String?;
    final unread = (payload['unreadCount'] as num?)?.toInt();
    if (chatId == null || unread == null) {
      return;
    }

    final meetupChats = ref.read(meetupChatsProvider).valueOrNull ?? const [];
    if (meetupChats.any((chat) => chat.id == chatId)) {
      ref.read(meetupChatsLocalStateProvider.notifier).state =
          setMeetupChatUnread(
        meetupChats,
        chatId: chatId,
        unread: unread,
      );
      return;
    }

    final personalChats =
        ref.read(personalChatsProvider).valueOrNull ?? const [];
    if (personalChats.any((chat) => chat.id == chatId)) {
      ref.read(personalChatsLocalStateProvider.notifier).state =
          setPersonalChatUnread(
        personalChats,
        chatId: chatId,
        unread: unread,
      );
    }
  }

  void _applyChatUpdated(Map<String, dynamic> payload) {
    final chatId = payload['chatId'] as String?;
    if (chatId == null) {
      return;
    }

    final sessionId = payload['sessionId'] as String?;
    final phaseRaw = payload['phase'] as String?;
    final currentStep = (payload['currentStep'] as num?)?.toInt();
    final totalSteps = (payload['totalSteps'] as num?)?.toInt();
    final currentPlace = payload['currentPlace'] as String?;
    final endTime = payload['endTime'] as String?;

    final meetupChats = ref.read(meetupChatsProvider).valueOrNull ?? const [];
    if (meetupChats.any((chat) => chat.id == chatId)) {
      ref.read(meetupChatsLocalStateProvider.notifier).state =
          updateMeetupChatFromRealtime(
        meetupChats,
        chatId: chatId,
        phase: phaseRaw == null ? null : parseMeetupPhase(phaseRaw),
        hasCurrentStep: payload.containsKey('currentStep'),
        currentStep: currentStep,
        hasTotalSteps: payload.containsKey('totalSteps'),
        totalSteps: totalSteps,
        hasCurrentPlace: payload.containsKey('currentPlace'),
        currentPlace: currentPlace,
        hasEndTime: payload.containsKey('endTime'),
        endTime: endTime,
        startsInLabel: payload['startsInLabel'] as String?,
      );
    } else {
      ref.read(meetupChatsLocalStateProvider.notifier).state = null;
      ref.invalidate(meetupChatsProvider);
    }

    ref.invalidate(eveningSessionsProvider);
    if (sessionId != null) {
      ref.invalidate(eveningSessionProvider(sessionId));
    }
  }

  void _applyNotificationCreated(Map<String, dynamic> payload) {
    final nextNotification = _mapRealtimeNotification(payload);

    final currentOverride = ref.read(notificationUnreadCountOverrideProvider);
    if (currentOverride != null) {
      ref.read(notificationUnreadCountOverrideProvider.notifier).state =
          currentOverride + 1;
    } else {
      final currentCount =
          ref.read(notificationUnreadCountProvider).valueOrNull;
      if (currentCount != null) {
        ref.read(notificationUnreadCountOverrideProvider.notifier).state =
            currentCount + 1;
      } else {
        ref.invalidate(notificationUnreadCountProvider);
      }
    }

    if (nextNotification == null) {
      ref.read(notificationsLocalStateProvider.notifier).state = null;
      ref.invalidate(notificationsProvider);
      return;
    }
    _invalidateEveningFromNotification(nextNotification.payload);

    final localItems = ref.read(notificationsLocalStateProvider);
    if (localItems != null) {
      ref.read(notificationsLocalStateProvider.notifier).state =
          prependNotificationItem(localItems, nextNotification);
      return;
    }

    final fetchedItems = ref.read(notificationsProvider).valueOrNull;
    if (fetchedItems != null) {
      ref.read(notificationsLocalStateProvider.notifier).state =
          prependNotificationItem(fetchedItems, nextNotification);
      return;
    }

    ref.invalidate(notificationsProvider);
  }

  void _invalidateEveningFromNotification(Map<String, dynamic> payload) {
    final sessionId = payload['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    ref.invalidate(eveningSessionsProvider);
    ref.invalidate(eveningSessionProvider(sessionId));
  }

  NotificationItem? _mapRealtimeNotification(Map<String, dynamic> payload) {
    final notificationId = payload['notificationId'] as String?;
    final kind = payload['kind'] as String?;
    final title = payload['title'] as String?;
    final body = payload['body'] as String?;
    final createdAtRaw = payload['createdAt'] as String?;

    if (notificationId == null ||
        kind == null ||
        title == null ||
        body == null ||
        createdAtRaw == null) {
      return null;
    }

    final rawPayload = payload['payload'];
    return NotificationItem(
      id: notificationId,
      kind: kind,
      title: title,
      body: body,
      payload: rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const <String, dynamic>{},
      readAt: payload['readAt'] == null
          ? null
          : DateTime.parse(payload['readAt'] as String),
      createdAt: DateTime.parse(createdAtRaw),
    );
  }

  String _buildMessagePreview(Message message) {
    final text = message.text.trim();
    if (text.isNotEmpty) {
      return text;
    }

    if (message.attachments.any((attachment) => attachment.isVoice)) {
      return 'Голосовое сообщение';
    }

    if (message.attachments.any((attachment) => attachment.isLocation)) {
      return 'Локация';
    }

    if (message.attachments.isNotEmpty) {
      return 'Вложение';
    }

    return '';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
