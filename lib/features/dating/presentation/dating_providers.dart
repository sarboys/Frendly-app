import 'dart:async';

import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/dating_profile.dart';
import 'package:big_break_mobile/shared/models/media_variant.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final datingActionTombstonesProvider =
    StateProvider<Map<String, String>>((ref) => const {});

final datingDiscoverFiltersProvider =
    StateProvider.autoDispose<DatingDiscoverFilters>(
  (ref) => const DatingDiscoverFilters(
    ageMin: 22,
    ageMax: 35,
    radiusKm: 10,
  ),
);

final datingDiscoverProvider =
    FutureProvider.autoDispose<List<DatingProfileData>>((ref) async {
  final filters = ref.watch(datingDiscoverFiltersProvider);
  return _fetchDatingDiscover(
    ref,
    limit: 20,
    filters: filters,
    allowPeopleFallback: true,
  );
});

final datingHomePreviewProvider =
    FutureProvider.autoDispose<List<DatingProfileData>>((ref) async {
  return _fetchDatingDiscover(
    ref,
    limit: 4,
    filters: const DatingDiscoverFilters(),
    allowPeopleFallback: false,
  );
});

Future<List<DatingProfileData>> _fetchDatingDiscover(
  Ref ref, {
  required int limit,
  required DatingDiscoverFilters filters,
  required bool allowPeopleFallback,
}) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  if (cancelToken.isCancelled) {
    return const [];
  }

  try {
    final profiles = await _fetchDatingLocalFirst(
      ref,
      cacheKey: AppCacheKey.build(
        path: '/dating/discover',
        query: filters.toQuery(limit: limit),
      ),
      networkFetch: () async {
        try {
          return await repository
              .fetchDatingDiscover(
                limit: limit,
                ageMin: filters.ageMin,
                ageMax: filters.ageMax,
                radiusKm: filters.radiusKm,
                interests: filters.interests,
                cancelToken: cancelToken,
              )
              .then((value) => value.items);
        } catch (_) {
          if (cancelToken.isCancelled) {
            return const [];
          }
          if (!allowPeopleFallback) {
            rethrow;
          }
          final people = await repository.fetchPeople(
            limit: limit,
            cancelToken: cancelToken,
          );
          return people.items
              .map(_mapPersonToDatingFallback)
              .toList(growable: false);
        }
      },
    );
    return _filterDatingTombstones(ref, profiles);
  } catch (_) {
    return const [];
  }
}

class DatingDiscoverFilters {
  const DatingDiscoverFilters({
    this.ageMin,
    this.ageMax,
    this.radiusKm,
    this.interests = const [],
  });

  final int? ageMin;
  final int? ageMax;
  final double? radiusKm;
  final List<String> interests;

  Map<String, Object> toQuery({required int limit}) {
    return {
      'limit': limit,
      if (ageMin != null) 'ageMin': ageMin!,
      if (ageMax != null) 'ageMax': ageMax!,
      if (radiusKm != null) 'radiusKm': radiusKm!,
      if (interests.isNotEmpty) 'interests': interests.join(','),
    };
  }
}

final datingLikesProvider =
    FutureProvider.autoDispose<List<DatingProfileData>>((ref) async {
  final authTokens = ref.watch(authTokensProvider);
  if (authTokens == null) {
    return const [];
  }
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  if (cancelToken.isCancelled) {
    return const [];
  }

  try {
    final profiles = await _fetchDatingLocalFirst(
      ref,
      cacheKey: AppCacheKey.build(
        path: '/dating/likes',
        query: const {'limit': 20},
      ),
      networkFetch: () => repository
          .fetchDatingLikes(cancelToken: cancelToken)
          .then((value) => value.items),
    );
    return _filterDatingTombstones(ref, profiles);
  } catch (_) {
    return const [];
  }
});

Future<List<DatingProfileData>> _fetchDatingLocalFirst(
  Ref ref, {
  required String cacheKey,
  required FutureOr<List<DatingProfileData>> Function() networkFetch,
}) async {
  final repository = ref.read(localFirstRepositoryProvider);
  if (repository == null) {
    return Future<List<DatingProfileData>>.sync(networkFetch);
  }

  final result = await repository.fetch<List<DatingProfileData>>(
    userScope: ref.read(appCacheUserScopeProvider),
    namespace: AppCacheNamespace.dating,
    cacheKey: cacheKey,
    policy: AppCachePolicies.dating,
    networkFetch: networkFetch,
    fromJson: _datingProfilesFromCacheJson,
    toJson: _datingProfilesToCacheJson,
  );
  final refresh = result.refresh;
  if (refresh != null) {
    unawaited(refresh);
  }
  return result.data;
}

List<DatingProfileData> _filterDatingTombstones(
  Ref ref,
  List<DatingProfileData> profiles,
) {
  final tombstones = ref.watch(datingActionTombstonesProvider);
  if (tombstones.isEmpty) {
    return profiles;
  }
  return profiles
      .where((profile) => !tombstones.containsKey(profile.userId))
      .toList(growable: false);
}

List<DatingProfileData> _datingProfilesFromCacheJson(Object? json) {
  return ((json as List?) ?? const [])
      .whereType<Map>()
      .map(
          (item) => DatingProfileData.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<Map<String, dynamic>> _datingProfilesToCacheJson(
  List<DatingProfileData> profiles,
) {
  return profiles.map(_datingProfileToCacheJson).toList(growable: false);
}

Map<String, dynamic> _datingProfileToCacheJson(DatingProfileData profile) {
  return {
    'userId': profile.userId,
    'name': profile.name,
    'age': profile.age,
    'city': profile.city,
    'distance': profile.distance,
    'about': profile.about,
    'tags': profile.tags,
    'prompt': profile.prompt,
    'photoEmoji': profile.photoEmoji,
    'avatarUrl': profile.avatarUrl,
    'primaryPhoto': profile.primaryPhoto == null
        ? null
        : _profilePhotoToCacheJson(profile.primaryPhoto!),
    'photos': profile.photos.map(_profilePhotoToCacheJson).toList(),
    'likedYou': profile.likedYou,
    'premium': profile.premium,
    'vibe': profile.vibe,
    'area': profile.area,
    'latitude': profile.latitude,
    'longitude': profile.longitude,
    'verified': profile.verified,
    'online': profile.online,
    'languages': profile.languages.map(_datingLanguageToCacheJson).toList(),
    'nationality': profile.nationality == null
        ? null
        : _datingLanguageToCacheJson(profile.nationality!),
  };
}

Map<String, dynamic> _datingLanguageToCacheJson(DatingLanguageData language) {
  return {
    'flag': language.flag,
    'label': language.label,
  };
}

Map<String, dynamic> _profilePhotoToCacheJson(ProfilePhoto photo) {
  return {
    'id': photo.id,
    'url': photo.url,
    'order': photo.order,
    'variants': _mediaVariantsToCacheJson(photo.variants),
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

CancelToken _autoDisposeCancelToken(Ref ref) {
  final cancelToken = CancelToken();
  ref.onDispose(() {
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('provider_disposed');
    }
  });
  return cancelToken;
}

DatingProfileData _mapPersonToDatingFallback(PersonSummary person) {
  final tags = person.common.isNotEmpty
      ? person.common.take(3).toList(growable: false)
      : <String>[
          if ((person.area ?? '').isNotEmpty) person.area!,
          if ((person.vibe ?? '').isNotEmpty) person.vibe!,
        ];

  return DatingProfileData(
    userId: person.id,
    name: person.name,
    age: person.age,
    distance: 'Рядом',
    about: 'Пока используем fallback список, чтобы dating экран не ломался.',
    tags: tags,
    prompt: 'Можно начать с лайка plus потом перевести в чат.',
    photoEmoji: person.online ? '💘' : '✨',
    avatarUrl: person.avatarUrl,
    likedYou: false,
    premium: true,
    vibe: person.vibe,
    area: person.area,
    verified: person.verified,
    online: person.online,
  );
}
