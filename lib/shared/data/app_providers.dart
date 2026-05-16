import 'dart:async';
import 'dart:typed_data';

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/chat_cache_serializers.dart';
import 'package:big_break_mobile/app/core/local_cache/chat_local_store.dart';
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
import 'package:big_break_mobile/shared/models/media_variant.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/personal_chat.dart';
import 'package:big_break_mobile/shared/models/payments.dart';
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
  final profile = await _fetchLocalFirst<ProfileData>(
    ref,
    namespace: AppCacheNamespace.profile,
    cacheKey: AppCacheKey.build(path: '/profile/me'),
    policy: AppCachePolicies.profile,
    networkFetch: () => bootstrapProfile ?? repository.fetchMe(),
    fromJson: _profileFromCacheJson,
    toJson: _profileToCacheJson,
  );
  OnboardingData? onboarding;
  try {
    onboarding = await onboardingFuture;
  } catch (_) {
    onboarding = null;
  }
  final mergedProfile =
      onboarding == null ? profile : profile.withOnboarding(onboarding);
  return mergeProfileDraftPhotos(
    mergedProfile,
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
  return _fetchLocalFirst<OnboardingData>(
    ref,
    namespace: AppCacheNamespace.profile,
    cacheKey: AppCacheKey.build(path: '/onboarding/me'),
    policy: AppCachePolicies.profile,
    networkFetch: repository.fetchOnboarding,
    fromJson: _onboardingFromCacheJson,
    toJson: _onboardingToCacheJson,
  );
});

OnboardingData _onboardingFromCacheJson(Object? json) {
  return OnboardingData.fromJson(_jsonMap(json));
}

Map<String, dynamic> _onboardingToCacheJson(OnboardingData onboarding) {
  return {
    ...onboarding.toJson(),
    'birthDate': onboarding.birthDate,
    'requiredContact': onboarding.requiredContact?.toJson(),
  };
}

ProfileData _profileFromCacheJson(Object? json) {
  final payload = _jsonMap(json);
  return ProfileData(
    id: payload['id'] as String? ?? '',
    displayName: payload['displayName'] as String? ?? '',
    verified: payload['verified'] as bool? ?? false,
    frendlyPlus: payload['frendlyPlus'] as bool? ?? false,
    online: payload['online'] as bool? ?? false,
    age: (payload['age'] as num?)?.toInt(),
    gender: payload['gender'] as String?,
    city: payload['city'] as String?,
    area: payload['area'] as String?,
    bio: payload['bio'] as String?,
    vibe: payload['vibe'] as String?,
    rating: (payload['rating'] as num?)?.toDouble() ?? 0,
    meetupCount: (payload['meetupCount'] as num?)?.toInt() ?? 0,
    avatarUrl: payload['avatarUrl'] as String?,
    interests: _stringList(payload['interests']),
    intent: _stringList(payload['intent']),
    photos: _profilePhotosFromCacheJson(payload['photos']),
    social: ProfileSocialData.fromJson(payload['social']),
  );
}

Map<String, dynamic> _profileToCacheJson(ProfileData profile) {
  return {
    'id': profile.id,
    'displayName': profile.displayName,
    'verified': profile.verified,
    'frendlyPlus': profile.frendlyPlus,
    'online': profile.online,
    'age': profile.age,
    'gender': profile.gender,
    'city': profile.city,
    'area': profile.area,
    'bio': profile.bio,
    'vibe': profile.vibe,
    'rating': profile.rating,
    'meetupCount': profile.meetupCount,
    'avatarUrl': profile.avatarUrl,
    'interests': profile.interests,
    'intent': profile.intent,
    'photos': profile.photos.map(_profilePhotoToCacheJson).toList(),
    'social': _profileSocialToCacheJson(profile.social),
  };
}

List<ProfilePhoto> _profilePhotosFromCacheJson(Object? json) {
  return ((json as List?) ?? const [])
      .whereType<Map>()
      .map((item) => ProfilePhoto.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Map<String, dynamic> _profilePhotoToCacheJson(ProfilePhoto photo) {
  return {
    'id': photo.id,
    'url': photo.url,
    'order': photo.order,
    'variants': _mediaVariantsToCacheJson(photo.variants),
  };
}

Map<String, dynamic> _profileSocialToCacheJson(ProfileSocialData social) {
  return {
    'followers': social.followers,
    'likes': social.likes,
    'superLikes': social.superLikes,
    'iFollow': social.iFollow,
    'iLike': social.iLike,
    'iSuper': social.iSuper,
  };
}

final eventsProvider =
    FutureProvider.family<List<Event>, String>((ref, filter) {
  return _fetchEventFeed(ref, filter);
});

final eventsForceRefreshProvider =
    FutureProvider.autoDispose.family<List<Event>, String>((ref, filter) {
  return _fetchEventFeed(ref, filter, forceRefresh: true);
});

Future<List<Event>> _fetchEventFeed(
  Ref ref,
  String filter, {
  bool forceRefresh = false,
}) async {
  final manualLocation = ref.watch(manualLocationProvider);
  final radiusKm =
      filter == 'nearby' ? ref.watch(nearbyEventsRadiusKmProvider) : null;
  final repository = ref.read(backendRepositoryProvider);
  final locationService = filter == 'nearby' && manualLocation == null
      ? ref.read(appLocationServiceProvider)
      : null;
  final location = await _eventFeedLocation(
    filter,
    manualLocation,
    locationService,
  );
  if (filter == 'nearby' && location == null) {
    return const [];
  }
  final cacheKey = AppCacheKey.build(
    path: '/events',
    query: {
      'filter': filter,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'radiusKm': location == null ? null : radiusKm,
    },
  );
  return _fetchLocalFirst<List<Event>>(
    ref,
    namespace: AppCacheNamespace.meetups,
    cacheKey: cacheKey,
    policy: AppCachePolicies.meetups,
    networkFetch: () => repository
        .fetchEvents(
          filter: filter,
          latitude: location?.latitude,
          longitude: location?.longitude,
          radiusKm: location == null ? null : radiusKm,
        )
        .then((value) => value.items),
    fromJson: (json) => _decodeCacheList(json, Event.fromJson),
    toJson: _eventsToCacheJson,
    forceRefresh: forceRefresh,
  );
}

Future<T> _fetchLocalFirst<T>(
  Ref ref, {
  required AppCacheNamespace namespace,
  required String cacheKey,
  required AppCachePolicy policy,
  required FutureOr<T> Function() networkFetch,
  required T Function(Object? json) fromJson,
  required Object? Function(T value) toJson,
  bool forceRefresh = false,
}) async {
  final repository = ref.read(localFirstRepositoryProvider);
  if (repository == null) {
    return Future<T>.sync(networkFetch);
  }

  final result = await repository.fetch<T>(
    userScope: ref.read(appCacheUserScopeProvider),
    namespace: namespace,
    cacheKey: cacheKey,
    policy: policy,
    networkFetch: networkFetch,
    fromJson: fromJson,
    toJson: toJson,
    forceRefresh: forceRefresh,
  );
  final refresh = result.refresh;
  if (refresh != null) {
    unawaited(refresh);
  }
  return result.data;
}

List<T> _decodeCacheList<T>(
  Object? json,
  T Function(Map<String, dynamic> json) fromJson,
) {
  final items = json is List ? json : const [];
  return items
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Map<String, dynamic> _jsonMap(Object? json) {
  return json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
}

List<String> _stringList(Object? json) {
  return ((json as List?) ?? const [])
      .whereType<String>()
      .toList(growable: false);
}

List<Map<String, dynamic>> _eventsToCacheJson(List<Event> items) {
  return items.map(_eventToCacheJson).toList(growable: false);
}

Map<String, dynamic> _eventToCacheJson(Event event) {
  return {
    'id': event.id,
    'title': event.title,
    'emoji': event.emoji,
    'time': event.time,
    'startsAtIso': event.startsAtIso,
    'imageUrl': event.imageUrl,
    'place': event.place,
    'distance': event.distance,
    'attendees': event.attendees,
    'going': event.going,
    'capacity': event.capacity,
    'vibe': event.vibe,
    'tone': _eventToneToJson(event.tone),
    'lifestyle': event.lifestyle,
    'priceMode': event.priceMode,
    'priceAmountFrom': event.priceAmountFrom,
    'priceAmountTo': event.priceAmountTo,
    'accessMode': event.accessMode,
    'genderMode': event.genderMode,
    'visibilityMode': event.visibilityMode,
    'requiresVerification': event.requiresVerification,
    'requiresFrendlyPlus': event.requiresFrendlyPlus,
    'routeId': event.routeId,
    'routePointCount': event.routePointCount,
    'isAfficheBacked': event.isAfficheBacked,
    'isDate': event.isDate,
    'hostNote': event.hostNote,
    'latitude': event.latitude,
    'longitude': event.longitude,
    'joined': event.joined,
    'joinMode': _eventJoinModeToJson(event.joinMode),
    'joinRequestStatus': _eventJoinRequestStatusToJson(event.joinRequestStatus),
    'attendanceStatus': _eventAttendanceStatusToJson(event.attendanceStatus),
    'liveStatus': _eventLiveStatusToJson(event.liveStatus),
    'isHost': event.isHost,
    'ticketUrl': event.ticketUrl,
    'ticketSourceKind': _eventTicketSourceKindToJson(event.ticketSourceKind),
    'ticketSourceId': event.ticketSourceId,
    'ticketPriceFrom': event.ticketPriceFrom,
    'ticketProvider': event.ticketProvider,
    'ticketVenue': event.ticketVenue,
    'bookingUrl': event.bookingUrl,
    'bookingProvider': event.bookingProvider,
    'bookingPlaceId': event.bookingPlaceId,
    'bookingAverageCheck': event.bookingAverageCheck,
    'bookingCurrency': event.bookingCurrency,
    'bookingPromos': event.bookingPromos.map(_eventBookingPromoToJson).toList(),
  };
}

Map<String, dynamic> _eventBookingPromoToJson(EventBookingPromo promo) {
  return {
    'title': promo.title,
    'description': promo.description,
    'validUntil': promo.validUntil,
    'bookingUrl': promo.bookingUrl,
    'sourceUrl': promo.sourceUrl,
  };
}

String _eventToneToJson(EventTone tone) {
  return switch (tone) {
    EventTone.evening => 'evening',
    EventTone.sage => 'sage',
    EventTone.warm => 'warm',
  };
}

String _eventJoinModeToJson(EventJoinMode mode) {
  return switch (mode) {
    EventJoinMode.request => 'request',
    EventJoinMode.open => 'open',
  };
}

String? _eventJoinRequestStatusToJson(EventJoinRequestStatus? status) {
  return switch (status) {
    EventJoinRequestStatus.pending => 'pending',
    EventJoinRequestStatus.approved => 'approved',
    EventJoinRequestStatus.rejected => 'rejected',
    EventJoinRequestStatus.canceled => 'canceled',
    null => null,
  };
}

String _eventAttendanceStatusToJson(EventAttendanceStatus status) {
  return switch (status) {
    EventAttendanceStatus.checkedIn => 'checked_in',
    EventAttendanceStatus.left => 'left',
    EventAttendanceStatus.notCheckedIn => 'not_checked_in',
  };
}

String _eventLiveStatusToJson(EventLiveStatus status) {
  return switch (status) {
    EventLiveStatus.live => 'live',
    EventLiveStatus.finished => 'finished',
    EventLiveStatus.idle => 'idle',
  };
}

String? _eventTicketSourceKindToJson(EventTicketSourceKind? kind) {
  return switch (kind) {
    EventTicketSourceKind.affiche => 'affiche',
    null => null,
  };
}

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
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  return _fetchLocalFirst<List<Event>>(
    ref,
    namespace: AppCacheNamespace.map,
    cacheKey: _mapEventsCacheKey(query),
    policy: AppCachePolicies.map,
    networkFetch: () => repository
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
        .then((value) => value.items),
    fromJson: (json) => _decodeCacheList(json, Event.fromJson),
    toJson: _eventsToCacheJson,
  );
});

String _mapEventsCacheKey(MapEventsQuery query) {
  return AppCacheKey.build(
    path: '/events/map',
    query: {
      'limit': query.limit,
      'centerLatitude': _roundedCoordinate(query.centerLatitude),
      'centerLongitude': _roundedCoordinate(query.centerLongitude),
      'radiusKm': query.radiusKm,
      'southWestLatitude': _roundedCoordinate(query.southWestLatitude),
      'southWestLongitude': _roundedCoordinate(query.southWestLongitude),
      'northEastLatitude': _roundedCoordinate(query.northEastLatitude),
      'northEastLongitude': _roundedCoordinate(query.northEastLongitude),
    },
  );
}

double? _roundedCoordinate(double? value) {
  if (value == null) {
    return null;
  }
  return double.parse(value.toStringAsFixed(4));
}

final eventDetailProvider = FutureProvider.autoDispose
    .family<EventDetail, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchEventDetail(eventId, cancelToken: cancelToken);
});

final eventDetailRouteStopsProvider = FutureProvider.autoDispose
    .family<List<EventDetailRouteStop>, String>((ref, routeId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  final routeJson = await repository.fetchEveningRoute(
    routeId,
    cancelToken: cancelToken,
  );
  final steps = routeJson['steps'];
  if (steps is! List) {
    return const [];
  }
  return EventDetailRouteStop.listFromJson(steps);
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
  final cancelToken = _autoDisposeCancelToken(ref);
  final page = await _fetchAfficheEventsPage(
    ref,
    query,
    cancelToken: cancelToken,
  );
  return page.items;
});

Future<PaginatedResponse<AfficheEvent>> _fetchAfficheEventsPage(
  Ref ref,
  AfficheEventsQuery query, {
  String? cursor,
  CancelToken? cancelToken,
  bool forceRefresh = false,
}) {
  final repository = ref.read(backendRepositoryProvider);
  Future<PaginatedResponse<AfficheEvent>> fetchNetwork() {
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
      cancelToken: cancelToken,
    );
  }

  if (cursor != null) {
    return fetchNetwork();
  }

  return _fetchLocalFirst<PaginatedResponse<AfficheEvent>>(
    ref,
    namespace: AppCacheNamespace.affiche,
    cacheKey: _afficheEventsCacheKey(query),
    policy: AppCachePolicies.affiche,
    networkFetch: fetchNetwork,
    fromJson: _afficheEventsPageFromCacheJson,
    toJson: _afficheEventsPageToCacheJson,
    forceRefresh: forceRefresh,
  );
}

String _afficheEventsCacheKey(AfficheEventsQuery query) {
  return AppCacheKey.build(
    path: '/affiche/events',
    query: {
      'city': query.city,
      'q': query.query.isEmpty ? null : query.query,
      'date': query.date,
      'priceMode': query.priceMode,
      'source': query.source,
      'category': query.category,
      'featured': query.featured,
      'limit': query.limit,
    },
  );
}

PaginatedResponse<AfficheEvent> _afficheEventsPageFromCacheJson(
  Object? json,
) {
  final payload =
      json is Map ? Map<String, dynamic>.from(json) : const <String, dynamic>{};
  return PaginatedResponse.fromJson(payload, AfficheEvent.fromJson);
}

Map<String, dynamic> _afficheEventsPageToCacheJson(
  PaginatedResponse<AfficheEvent> page,
) {
  return {
    'items': page.items.map(_afficheEventToCacheJson).toList(growable: false),
    'nextCursor': page.nextCursor,
    'lastEventId': page.lastEventId,
  };
}

Map<String, dynamic> _afficheEventToCacheJson(AfficheEvent event) {
  return {
    'id': event.id,
    'title': event.title,
    'description': event.description,
    'city': event.city,
    'venue': event.venue,
    'address': event.address,
    'lat': event.latitude,
    'lng': event.longitude,
    'startsAt': event.startsAt?.toUtc().toIso8601String(),
    'endsAt': event.endsAt?.toUtc().toIso8601String(),
    'dateLabel': event.dateLabel,
    'timeLabel': event.timeLabel,
    'category': event.category,
    'priceFrom': event.priceFrom,
    'priceMode': _affichePriceModeToJson(event.priceMode),
    'currency': event.currency,
    'imageUrl': event.imageUrl,
    'imageVariants': _mediaVariantsToCacheJson(event.imageVariants),
    'provider': event.provider,
    'sourceCode': event.sourceCode,
    'actionUrl': event.actionUrl,
    'actionKind': event.actionKind,
    'isAffiliate': event.isAffiliate,
    'tags': event.tags,
  };
}

String _affichePriceModeToJson(AffichePriceMode mode) {
  return switch (mode) {
    AffichePriceMode.free => 'free',
    AffichePriceMode.paid => 'paid',
    AffichePriceMode.unknown => 'unknown',
  };
}

Map<String, dynamic> _mediaVariantsToCacheJson(
  Map<String, MediaVariantData> variants,
) {
  return variants.map(
    (key, value) => MapEntry(
      key,
      {
        'url': value.url,
        'downloadUrl': value.downloadUrl,
        'mimeType': value.mimeType,
        'byteSize': value.byteSize,
        'cacheKey': value.cacheKey,
        'expiresAt': value.expiresAt?.toUtc().toIso8601String(),
      },
    ),
  );
}

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

  Future<bool> loadFirstPage({bool forceRefresh = false}) async {
    final current = state.valueOrNull;
    if (current == null) {
      state = const AsyncLoading();
    }
    try {
      final page = await _fetchPage(forceRefresh: forceRefresh);
      if (!mounted) {
        return false;
      }
      state = AsyncData(
        AfficheEventsPagedState(
          items: page.items,
          nextCursor: page.nextCursor,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      if (!mounted) {
        return false;
      }
      if (current != null) {
        state = AsyncData(current);
        return false;
      }
      state = AsyncError(error, stackTrace);
      return false;
    }
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

  Future<PaginatedResponse<AfficheEvent>> _fetchPage({
    String? cursor,
    bool forceRefresh = false,
  }) async {
    return _fetchAfficheEventsPage(
      ref,
      query,
      cursor: cursor,
      cancelToken: _cancelToken,
      forceRefresh: forceRefresh,
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
  final watchedTokens = ref.watch(authTokensProvider);
  if (watchedTokens == null) {
    return UserSettingsData.fallback;
  }
  final repository = ref.read(backendRepositoryProvider);
  final authTokens = ref.read(authTokensProvider.notifier);
  final currentUser = ref.read(currentUserIdProvider.notifier);
  final permissionPreferences = ref.read(appPermissionPreferencesProvider);
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
  Future<UserSettingsData> fetchAndSyncSettings() async {
    final settings = await repository.fetchSettings();
    if (!sessionStillCurrent(sessionTokens, userId)) {
      return UserSettingsData.fallback;
    }
    await permissionPreferences.syncFromSettings(settings);
    if (!sessionStillCurrent(sessionTokens, userId)) {
      return UserSettingsData.fallback;
    }
    return settings;
  }

  final settings = await _fetchLocalFirst<UserSettingsData>(
    ref,
    namespace: AppCacheNamespace.settings,
    cacheKey: AppCacheKey.build(path: '/settings/me'),
    policy: AppCachePolicies.settings,
    networkFetch: fetchAndSyncSettings,
    fromJson: (json) => UserSettingsData.fromJson(_jsonMap(json)),
    toJson: (value) => value.toJson(),
  );
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

final paymentCatalogProvider = FutureProvider<PaymentCatalog>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchPaymentCatalog();
});

final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanData>>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  try {
    return (await repository.fetchPaymentCatalog()).subscriptions;
  } catch (_) {
    return repository.fetchSubscriptionPlans();
  }
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
  return _fetchLocalFirst<ProfileData>(
    ref,
    namespace: AppCacheNamespace.publicProfile,
    cacheKey: AppCacheKey.build(path: '/people/$userId'),
    policy: AppCachePolicies.publicProfile,
    networkFetch: () =>
        repository.fetchPersonProfile(userId, cancelToken: cancelToken),
    fromJson: _profileFromCacheJson,
    toJson: _profileToCacheJson,
  );
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
  final localStore = ref.read(chatLocalStoreProvider);
  final userScope = ref.read(appCacheUserScopeProvider);
  if (localStore != null) {
    final cached = await _readChatSummariesCache(
      ref,
      localStore,
      userScope: userScope,
      kind: ChatSummaryKind.meetup,
    );
    if (cached.isNotEmpty) {
      unawaited(_refreshMeetupChatsCache(ref, localStore, userScope));
      return sortMeetupChatsByPinned(
        cached.map(MeetupChat.fromJson).toList(growable: false),
      );
    }
  }
  final repository = ref.read(backendRepositoryProvider);
  final result = await repository.fetchMeetupChats();
  if (localStore != null) {
    unawaited(
      _writeMeetupChatsCache(localStore, userScope, result.items).catchError(
        (_) {},
      ),
    );
  }
  return sortMeetupChatsByPinned(result.items);
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
  final repository = ref.read(backendRepositoryProvider);
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
  final normalizedCity = city.trim();
  if (normalizedCity.isEmpty) {
    return const [];
  }
  final repository = ref.read(backendRepositoryProvider);
  return _fetchLocalFirst<List<EveningRouteTemplateSummary>>(
    ref,
    namespace: AppCacheNamespace.routeTemplates,
    cacheKey: AppCacheKey.build(
      path: '/evening/route-templates',
      query: {
        'city': normalizedCity,
        'limit': 20,
      },
    ),
    policy: AppCachePolicies.routeTemplates,
    networkFetch: () => repository
        .fetchEveningRouteTemplates(city: normalizedCity)
        .then((value) => value.items),
    fromJson: (json) =>
        _decodeCacheList(json, EveningRouteTemplateSummary.fromJson),
    toJson: _routeTemplatesToCacheJson,
  );
});

List<Map<String, dynamic>> _routeTemplatesToCacheJson(
  List<EveningRouteTemplateSummary> items,
) {
  return items.map(_routeTemplateToCacheJson).toList(growable: false);
}

Map<String, dynamic> _routeTemplateToCacheJson(
  EveningRouteTemplateSummary template,
) {
  return {
    'id': template.id,
    'routeId': template.routeId,
    'title': template.title,
    'blurb': template.blurb,
    'city': template.city,
    'area': template.area,
    'badgeLabel': template.badgeLabel,
    'coverUrl': template.coverUrl,
    'vibe': template.vibe,
    'budget': template.budget,
    'durationLabel': template.durationLabel,
    'totalPriceFrom': template.totalPriceFrom,
    'totalSavings': template.totalSavings,
    'mood': template.mood,
    'premium': template.premium,
    'hostsCount': template.hostsCount,
    'stepsPreview':
        template.stepsPreview.map(_routeStepPreviewToCacheJson).toList(),
    'partnerOffersPreview': template.partnerOffersPreview
        .map(_routePartnerOfferPreviewToCacheJson)
        .toList(),
    'nearestSessions':
        template.nearestSessions.map(_routeSessionToCacheJson).toList(),
  };
}

Map<String, dynamic> _routeStepPreviewToCacheJson(
  EveningRouteTemplateStepPreview step,
) {
  return {
    'title': step.title,
    'venue': step.venue,
    'emoji': step.emoji,
    'time': step.time,
    'kind': step.kind,
  };
}

Map<String, dynamic> _routePartnerOfferPreviewToCacheJson(
  EveningPartnerOfferPreview offer,
) {
  return {
    'partnerId': offer.partnerId,
    'title': offer.title,
    'shortLabel': offer.shortLabel,
  };
}

Map<String, dynamic> _routeSessionToCacheJson(
  EveningRouteTemplateSession session,
) {
  return {
    'sessionId': session.sessionId,
    'startsAt': session.startsAt,
    'joinedCount': session.joinedCount,
    'capacity': session.capacity,
  };
}

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

final knownPersonalChatsProvider =
    StateProvider<Map<String, PersonalChat>>((ref) => const {});

final personalChatsProvider = FutureProvider<List<PersonalChat>>((ref) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final localItems = ref.watch(personalChatsLocalStateProvider);
  if (localItems != null) {
    return localItems;
  }
  final localStore = ref.read(chatLocalStoreProvider);
  final userScope = ref.read(appCacheUserScopeProvider);
  if (localStore != null) {
    final cached = await _readChatSummariesCache(
      ref,
      localStore,
      userScope: userScope,
      kind: ChatSummaryKind.personal,
    );
    if (cached.isNotEmpty) {
      unawaited(_refreshPersonalChatsCache(ref, localStore, userScope));
      return sortPersonalChatsByPinned(
        cached.map(PersonalChat.fromJson).toList(growable: false),
      );
    }
  }
  final repository = ref.read(backendRepositoryProvider);
  final result = await repository.fetchPersonalChats();
  if (localStore != null) {
    unawaited(
      _writePersonalChatsCache(localStore, userScope, result.items).catchError(
        (_) {},
      ),
    );
  }
  return sortPersonalChatsByPinned(result.items);
});

final personalChatSummaryProvider =
    Provider.autoDispose.family<PersonalChat?, String>((ref, chatId) {
  final loadedChat = ref.watch(personalChatsProvider.select((value) {
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
  if (loadedChat != null) {
    return loadedChat;
  }

  return ref.watch(
    knownPersonalChatsProvider.select((value) => value[chatId]),
  );
});

Future<void> _refreshMeetupChatsCache(
  Ref ref,
  ChatLocalStore localStore,
  AppCacheUserScope userScope,
) async {
  try {
    final result = await ref.read(backendRepositoryProvider).fetchMeetupChats();
    await _writeMeetupChatsCache(localStore, userScope, result.items);
    ref.read(meetupChatsLocalStateProvider.notifier).state =
        sortMeetupChatsByPinned(result.items);
  } catch (_) {}
}

Future<void> _refreshPersonalChatsCache(
  Ref ref,
  ChatLocalStore localStore,
  AppCacheUserScope userScope,
) async {
  try {
    final result =
        await ref.read(backendRepositoryProvider).fetchPersonalChats();
    await _writePersonalChatsCache(localStore, userScope, result.items);
    ref.read(personalChatsLocalStateProvider.notifier).state =
        sortPersonalChatsByPinned(result.items);
  } catch (_) {}
}

Future<List<Map<String, dynamic>>> _readChatSummariesCache(
  Ref ref,
  ChatLocalStore localStore, {
  required AppCacheUserScope userScope,
  required ChatSummaryKind kind,
}) async {
  try {
    return await localStore.readSummaries(
      userScope: userScope,
      kind: kind,
    );
  } catch (_) {
    _disableLocalCacheAfterFailure(ref);
    return const [];
  }
}

void _disableLocalCacheAfterFailure(Ref ref) {
  Future<void>.microtask(() {
    try {
      ref.read(appLocalCacheRuntimeDisabledProvider.notifier).state = true;
    } catch (_) {}
  });
}

Future<void> _writeMeetupChatsCache(
  ChatLocalStore localStore,
  AppCacheUserScope userScope,
  List<MeetupChat> chats,
) async {
  final now = DateTime.now();
  await localStore.replaceSummariesForKind(
    userScope: userScope,
    kind: ChatSummaryKind.meetup,
    summaries: chats
        .map(
          (chat) => ChatSummaryCachePayload(
            chatId: chat.id,
            summaryJson: meetupChatToCacheJson(chat),
            updatedAt: chat.lastMessageAt ?? now,
          ),
        )
        .toList(growable: false),
  );
}

Future<void> _writePersonalChatsCache(
  ChatLocalStore localStore,
  AppCacheUserScope userScope,
  List<PersonalChat> chats,
) async {
  final now = DateTime.now();
  await localStore.replaceSummariesForKind(
    userScope: userScope,
    kind: ChatSummaryKind.personal,
    summaries: chats
        .map(
          (chat) => ChatSummaryCachePayload(
            chatId: chat.id,
            summaryJson: personalChatToCacheJson(chat),
            updatedAt: chat.lastMessageAt ?? now,
          ),
        )
        .toList(growable: false),
  );
}

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
  final repository = ref.read(backendRepositoryProvider);
  return _fetchLocalFirst<List<NotificationItem>>(
    ref,
    namespace: AppCacheNamespace.notifications,
    cacheKey: AppCacheKey.build(
      path: '/notifications',
      query: const {'limit': 20},
    ),
    policy: AppCachePolicies.notifications,
    networkFetch: () =>
        repository.fetchNotifications().then((value) => value.items),
    fromJson: (json) => _decodeCacheList(json, NotificationItem.fromJson),
    toJson: _notificationsToCacheJson,
  );
});

List<Map<String, dynamic>> _notificationsToCacheJson(
  List<NotificationItem> items,
) {
  return items.map(_notificationToCacheJson).toList(growable: false);
}

Map<String, dynamic> _notificationToCacheJson(NotificationItem item) {
  return {
    'id': item.id,
    'kind': item.kind,
    'title': item.title,
    'body': item.body,
    'payload': item.payload,
    'readAt': item.readAt?.toIso8601String(),
    'createdAt': item.createdAt.toIso8601String(),
  };
}

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

  final repository = ref.read(backendRepositoryProvider);
  return _fetchLocalFirst<int>(
    ref,
    namespace: AppCacheNamespace.notifications,
    cacheKey: AppCacheKey.build(path: '/notifications/unread-count'),
    policy: AppCachePolicies.notifications,
    networkFetch: repository.fetchUnreadNotificationCount,
    fromJson: (json) => (json as num?)?.toInt() ?? 0,
    toJson: (value) => value,
  );
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

enum ChatRealtimeSyncScope { all, meetups, personal }

final chatRealtimeSyncProvider = Provider<void>((ref) {
  ref.watch(chatRealtimeSyncForScopeProvider(ChatRealtimeSyncScope.all));
});

final chatRealtimeSyncForScopeProvider =
    Provider.family<void, ChatRealtimeSyncScope>((ref, scope) {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return;
  }

  final coordinator = _ChatRealtimeSyncCoordinator(
    ref,
    syncMeetups: scope == ChatRealtimeSyncScope.all ||
        scope == ChatRealtimeSyncScope.meetups,
    syncPersonal: scope == ChatRealtimeSyncScope.all ||
        scope == ChatRealtimeSyncScope.personal,
  );
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
  String? lastMessageId,
  DateTime? lastMessageAt,
}) {
  final updated = chats
      .map(
        (chat) => chat.id == chatId
            ? chat.copyWith(
                lastMessage: lastMessage,
                lastMessageId: lastMessageId,
                lastAuthor: lastAuthor,
                lastTime: lastTime,
                lastMessageAt: lastMessageAt ?? DateTime.now(),
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

List<PersonalChat> mergeKnownPersonalChats(
  List<PersonalChat> chats,
  Iterable<PersonalChat> knownChats,
) {
  final byId = <String, PersonalChat>{
    for (final chat in chats) chat.id: chat,
  };
  for (final chat in knownChats) {
    byId.putIfAbsent(chat.id, () => chat);
  }
  return sortPersonalChatsByPinned(byId.values.toList(growable: false));
}

List<PersonalChat> upsertPersonalChatSummary(
  List<PersonalChat> chats, {
  required String chatId,
  required String lastMessage,
  required String lastTime,
  required int unread,
  String? lastMessageId,
  DateTime? lastMessageAt,
}) {
  final updated = chats
      .map(
        (chat) => chat.id == chatId
            ? chat.copyWith(
                lastMessage: lastMessage,
                lastMessageId: lastMessageId,
                lastTime: lastTime,
                lastMessageAt: lastMessageAt ?? DateTime.now(),
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
  final indexed = chats.indexed.toList(growable: false);
  indexed.sort((left, right) {
    final pinComparison = _comparePinned(left.$2.isPinned, right.$2.isPinned);
    if (pinComparison != 0) {
      return pinComparison;
    }
    final recencyComparison =
        _compareNullableDateDesc(left.$2.lastMessageAt, right.$2.lastMessageAt);
    if (recencyComparison != 0) {
      return recencyComparison;
    }
    return left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

List<PersonalChat> sortPersonalChatsByPinned(List<PersonalChat> chats) {
  final indexed = chats.indexed.toList(growable: false);
  indexed.sort((left, right) {
    final pinComparison = _comparePinned(left.$2.isPinned, right.$2.isPinned);
    if (pinComparison != 0) {
      return pinComparison;
    }
    final recencyComparison =
        _compareNullableDateDesc(left.$2.lastMessageAt, right.$2.lastMessageAt);
    if (recencyComparison != 0) {
      return recencyComparison;
    }
    return left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

int _comparePinned(bool left, bool right) {
  if (left == right) {
    return 0;
  }
  return left ? -1 : 1;
}

int _compareNullableDateDesc(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
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
                lastMessageId: chat.lastMessageId,
                lastAuthor: chat.lastAuthor,
                lastTime: chat.lastTime,
                lastMessageAt: chat.lastMessageAt,
                unread: chat.unread,
                members: chat.members,
                memberProfiles: chat.memberProfiles,
                status: chat.status,
                isPinned: chat.isPinned,
                typing: chat.typing,
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
  _ChatRealtimeSyncCoordinator(
    this.ref, {
    required this.syncMeetups,
    required this.syncPersonal,
  }) : _socket = ref.read(chatSocketClientProvider) {
    _eventsSubscription = _socket.events.listen(_handleSocketEvent);

    if (syncMeetups) {
      ref.listen<AsyncValue<List<MeetupChat>>>(meetupChatsProvider, (_, __) {
        _syncSubscriptions();
      });
    }
    if (syncPersonal) {
      ref.listen<AsyncValue<List<PersonalChat>>>(personalChatsProvider,
          (_, __) {
        _syncSubscriptions();
      });
    }

    unawaited(_connectAndSync());
  }

  final Ref ref;
  final bool syncMeetups;
  final bool syncPersonal;
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
      if (syncMeetups)
        ...(ref.read(meetupChatsProvider).valueOrNull ?? const <MeetupChat>[])
            .map((chat) => chat.id),
      if (syncPersonal)
        ...(ref.read(personalChatsProvider).valueOrNull ??
                const <PersonalChat>[])
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

    final meetupChats = _currentMeetupChats();
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
        lastMessageAt: message.createdAt,
        unread: meetupChat.unread,
        lastMessageId: message.id,
      );
      return;
    }

    final personalChats = _currentPersonalChats();
    final personalChat =
        personalChats.where((chat) => chat.id == chatId).firstOrNull;
    if (personalChat != null) {
      ref.read(personalChatsLocalStateProvider.notifier).state =
          upsertPersonalChatSummary(
        personalChats,
        chatId: chatId,
        lastMessage: preview,
        lastTime: message.time,
        lastMessageAt: message.createdAt,
        unread: personalChat.unread,
        lastMessageId: message.id,
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

    final meetupChats = _currentMeetupChats();
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

    final meetupChats = _currentMeetupChats();
    if (meetupChats.any((chat) => chat.id == chatId)) {
      ref.read(meetupChatsLocalStateProvider.notifier).state =
          setMeetupChatUnread(
        meetupChats,
        chatId: chatId,
        unread: unread,
      );
      return;
    }

    final personalChats = _currentPersonalChats();
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

    final meetupChats = _currentMeetupChats();
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

  List<MeetupChat> _currentMeetupChats() {
    return ref.read(meetupChatsLocalStateProvider) ??
        ref.read(meetupChatsProvider).valueOrNull ??
        const <MeetupChat>[];
  }

  List<PersonalChat> _currentPersonalChats() {
    return ref.read(personalChatsLocalStateProvider) ??
        ref.read(personalChatsProvider).valueOrNull ??
        const <PersonalChat>[];
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
