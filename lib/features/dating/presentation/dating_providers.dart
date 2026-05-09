import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/dating_profile.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final datingDiscoverProvider =
    FutureProvider.autoDispose<List<DatingProfileData>>((ref) async {
  final repository = ref.read(backendRepositoryProvider);
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final cancelToken = _autoDisposeCancelToken(ref);
  try {
    await authBootstrap;
  } catch (_) {
    return const [];
  }

  if (cancelToken.isCancelled) {
    return const [];
  }

  try {
    return await repository
        .fetchDatingDiscover(cancelToken: cancelToken)
        .then((value) => value.items);
  } catch (_) {
    if (cancelToken.isCancelled) {
      return const [];
    }
    final people = await repository.fetchPeople(cancelToken: cancelToken);
    return people.items.map(_mapPersonToDatingFallback).toList(growable: false);
  }
});

final datingLikesProvider =
    FutureProvider.autoDispose<List<DatingProfileData>>((ref) async {
  final repository = ref.read(backendRepositoryProvider);
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final cancelToken = _autoDisposeCancelToken(ref);
  try {
    await authBootstrap;
  } catch (_) {
    return const [];
  }

  if (cancelToken.isCancelled) {
    return const [];
  }

  try {
    return await repository
        .fetchDatingLikes(cancelToken: cancelToken)
        .then((value) => value.items);
  } catch (_) {
    return const [];
  }
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
