import 'package:big_break_mobile/features/communities/domain/community.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final communitiesFeedProvider = StateNotifierProvider.autoDispose<
    CommunitiesFeedController, AsyncValue<CommunitiesFeedState>>(
  (ref) => CommunitiesFeedController(ref),
);

final communityMediaFeedProvider = StateNotifierProvider.autoDispose.family<
    CommunityMediaFeedController, AsyncValue<CommunityMediaFeedState>, String>(
  (ref, communityId) => CommunityMediaFeedController(ref, communityId),
);

final communitiesProvider = FutureProvider<List<Community>>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchCommunities().then((value) => value.items);
});

final communityProvider =
    FutureProvider.autoDispose.family<Community?, String>((ref, id) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  try {
    return await repository.fetchCommunity(id, cancelToken: cancelToken);
  } catch (_) {
    if (cancelToken.isCancelled) {
      return null;
    }
    final communities = await repository.fetchCommunities(
      cancelToken: cancelToken,
    );
    for (final community in communities.items) {
      if (community.id == id) {
        return community;
      }
    }
    return null;
  }
});

class CommunitiesFeedState {
  const CommunitiesFeedState({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Community> items;
  final String? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  CommunitiesFeedState copyWith({
    List<Community>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return CommunitiesFeedState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError:
          clearLoadMoreError ? null : loadMoreError ?? this.loadMoreError,
    );
  }
}

class CommunityMediaFeedState {
  const CommunityMediaFeedState({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<CommunityMediaItem> items;
  final String? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  CommunityMediaFeedState copyWith({
    List<CommunityMediaItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return CommunityMediaFeedState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError:
          clearLoadMoreError ? null : loadMoreError ?? this.loadMoreError,
    );
  }
}

class CommunityMediaFeedController
    extends StateNotifier<AsyncValue<CommunityMediaFeedState>> {
  CommunityMediaFeedController(this.ref, this.communityId)
      : super(const AsyncValue.loading()) {
    ref.onDispose(() {
      _cancelToken?.cancel('community_media_feed_disposed');
    });
    _loadInitial();
  }

  final Ref ref;
  final String communityId;
  CancelToken? _cancelToken;

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || current.nextCursor == null) {
      return;
    }

    state = AsyncValue.data(
      current.copyWith(
        loadingMore: true,
        clearLoadMoreError: true,
      ),
    );

    final cancelToken = _replaceCancelToken('community_media_next_replaced');
    final repository = ref.read(backendRepositoryProvider);
    try {
      final page = await repository.fetchCommunityMedia(
        communityId,
        cursor: current.nextCursor,
        cancelToken: cancelToken,
      );
      if (!mounted) {
        return;
      }

      final latest = state.valueOrNull ?? current;
      state = AsyncValue.data(
        latest.copyWith(
          items: _mergeMedia(latest.items, page.items),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = AsyncValue.data(
        current.copyWith(
          loadingMore: false,
          loadMoreError: error,
        ),
      );
    } finally {
      _clearCancelToken(cancelToken);
    }
  }

  Future<void> _loadInitial() async {
    final cancelToken = _replaceCancelToken('community_media_initial_replaced');
    final authBootstrap = ref.read(authBootstrapProvider.future);
    final repository = ref.read(backendRepositoryProvider);
    try {
      await authBootstrap;
      final page = await repository.fetchCommunityMedia(
        communityId,
        cancelToken: cancelToken,
      );
      if (!mounted) {
        return;
      }

      state = AsyncValue.data(
        CommunityMediaFeedState(
          items: page.items,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    } finally {
      _clearCancelToken(cancelToken);
    }
  }

  CancelToken _replaceCancelToken(String reason) {
    _cancelToken?.cancel(reason);
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    return cancelToken;
  }

  void _clearCancelToken(CancelToken cancelToken) {
    if (identical(_cancelToken, cancelToken)) {
      _cancelToken = null;
    }
  }

  List<CommunityMediaItem> _mergeMedia(
    List<CommunityMediaItem> current,
    List<CommunityMediaItem> nextPage,
  ) {
    final byId = <String, CommunityMediaItem>{
      for (final item in current) item.id: item,
    };
    for (final item in nextPage) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }
}

class CommunitiesFeedController
    extends StateNotifier<AsyncValue<CommunitiesFeedState>> {
  CommunitiesFeedController(
    this.ref, {
    CommunitiesFeedState? initialState,
  }) : super(
          initialState == null
              ? const AsyncValue.loading()
              : AsyncValue.data(initialState),
        ) {
    ref.onDispose(() {
      _cancelToken?.cancel('communities_feed_disposed');
    });
    if (initialState == null) {
      _loadInitial();
    }
  }

  final Ref ref;
  CancelToken? _cancelToken;

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || current.nextCursor == null) {
      return;
    }

    state = AsyncValue.data(
      current.copyWith(
        loadingMore: true,
        clearLoadMoreError: true,
      ),
    );

    final cancelToken = _replaceCancelToken('communities_next_replaced');
    final repository = ref.read(backendRepositoryProvider);
    try {
      final page = await repository.fetchCommunities(
        cursor: current.nextCursor,
        cancelToken: cancelToken,
      );
      if (!mounted) {
        return;
      }

      final latest = state.valueOrNull ?? current;
      state = AsyncValue.data(
        latest.copyWith(
          items: _mergeCommunities(latest.items, page.items),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = AsyncValue.data(
        current.copyWith(
          loadingMore: false,
          loadMoreError: error,
        ),
      );
    } finally {
      _clearCancelToken(cancelToken);
    }
  }

  Future<void> _loadInitial() async {
    final cancelToken = _replaceCancelToken('communities_initial_replaced');
    final authBootstrap = ref.read(authBootstrapProvider.future);
    final repository = ref.read(backendRepositoryProvider);
    try {
      await authBootstrap;
      final page = await repository.fetchCommunities(cancelToken: cancelToken);
      if (!mounted) {
        return;
      }

      state = AsyncValue.data(
        CommunitiesFeedState(
          items: page.items,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    } finally {
      _clearCancelToken(cancelToken);
    }
  }

  CancelToken _replaceCancelToken(String reason) {
    _cancelToken?.cancel(reason);
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    return cancelToken;
  }

  void _clearCancelToken(CancelToken cancelToken) {
    if (identical(_cancelToken, cancelToken)) {
      _cancelToken = null;
    }
  }

  List<Community> _mergeCommunities(
    List<Community> current,
    List<Community> nextPage,
  ) {
    final byId = <String, Community>{
      for (final community in current) community.id: community,
    };
    for (final community in nextPage) {
      byId[community.id] = community;
    }
    return byId.values.toList(growable: false);
  }
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
