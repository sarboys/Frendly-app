import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';
import 'package:mobile2/shared/widgets/dateasy_top_bar.dart';
import 'package:url_launcher/url_launcher.dart';

const double _datingTopInset = 12;
const double _datingTopControlsGap = 14;
const double _datingCardTopGap = 12;
const double _datingCardActionGap = 18;
const double _datingActionNavGap = 14;
const double _datingActionMaxDiameter = 58;
const double _datingMinCardHeight = 320;
const double _datingMaxCardHeight = 600;

class DatingScreen extends StatefulWidget {
  const DatingScreen({super.key});

  @override
  State<DatingScreen> createState() => _DatingScreenState();
}

class _DatingScreenState extends State<DatingScreen> {
  static const int _discoverPageSize = 10;
  static const int _prefetchRemaining = 5;

  final List<BackendCardItem> _deckCards = <BackendCardItem>[];
  final Set<String> _handledIds = <String>{};
  final List<_DatingActionHistoryItem> _history = <_DatingActionHistoryItem>[];
  int _index = 0;
  bool _submitting = false;
  bool _loadingMore = false;
  bool _pagingExhausted = false;
  bool _loadedMore = false;
  String? _nextCursor;
  String? _filtersKey;
  String? _initialPageSignature;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: DateasyColors.surface2,
      ),
    );
  }

  Future<void> _rewind(WidgetRef ref, BuildContext context) async {
    if (_submitting) {
      return;
    }
    final last = _history.isEmpty ? null : _history.last;
    if (last == null || last.action != 'pass') {
      _showSnackBar(context, 'Можно вернуть только последний пропуск');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final result = await ref.read(datingActionsProvider).rewindLastPass();
      if (!mounted || !context.mounted) {
        return;
      }
      final restored = result.peer ?? last.card;
      setState(() {
        _history.removeLast();
        _handledIds.remove(last.card.id);
        _index = last.index;
        _restoreCard(restored, last.index);
      });
      _showSnackBar(
          context, 'Вернули ${_DatingProfile.fromBackend(restored).name}');
    } on BackendActionException catch (error) {
      if (!context.mounted) {
        return;
      }
      _handleBackendActionError(ref, context, error);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _sendAction(
      WidgetRef ref, BuildContext context, BackendCardItem card, String action,
      {required int cardIndex, bool fromLikes = false}) async {
    if (_submitting || card.id.isEmpty) {
      return;
    }

    final previousIndex = _index;
    setState(() {
      _submitting = true;
      if (!fromLikes) {
        _handledIds.add(card.id);
        _history.add(
          _DatingActionHistoryItem(
            card: card,
            action: action,
            index: cardIndex,
          ),
        );
        _index = cardIndex + 1;
      }
    });

    try {
      final result = await ref.read(datingActionsProvider).recordAction(
            targetUserId: card.id,
            action: action,
          );
      if (!mounted || !context.mounted) {
        return;
      }
      if (result.matched) {
        _openMatch(context, card.id, result.chatId);
        return;
      }
      if (fromLikes) {
        _showSnackBar(context, 'Лайк отправлен');
      }
    } on BackendActionException catch (error) {
      if (!fromLikes && mounted) {
        setState(() {
          _handledIds.remove(card.id);
          _history.removeWhere((item) => item.card.id == card.id);
          _index = previousIndex;
        });
      }
      if (!context.mounted) {
        return;
      }
      _handleBackendActionError(ref, context, error);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: Consumer(
        builder: (context, ref, _) {
          final filters = ref.watch(datingDiscoverFiltersProvider);
          final cardsState = ref.watch(datingDiscoverProvider);
          _syncFilters(filters);
          final page = cardsState.asData?.value;
          if (page != null) {
            _mergeInitialPage(page);
          }
          final subscription = ref.watch(subscriptionProvider).valueOrNull;
          final hasPlus = _hasFrendlyPlus(subscription);
          final likesState = ref.watch(datingLikesProvider);
          final limits = ref.watch(datingLimitsProvider).valueOrNull;
          final currentEntry = _currentEntry();
          final currentIndex = currentEntry?.key ?? _index;
          final currentCard = currentEntry?.value;
          final current = currentCard == null
              ? null
              : _DatingProfile.fromBackend(currentCard);
          final prewarmUrls = datingPrewarmImageUrls(
            _deckCards,
            currentIndex: currentIndex,
          );
          if (prewarmUrls.isNotEmpty) {
            unawaited(
              ref.read(appMediaPrewarmServiceProvider).warmRemoteImages(
                    prewarmUrls,
                    usage: DateasyImageUsage.fullscreen,
                    limit: 3,
                    concurrency: 2,
                  ),
            );
          }
          _maybePrefetch(ref, currentIndex);
          final isFirstLoading = cardsState.isLoading && _deckCards.isEmpty;
          final likePreviewProfiles = _likePreviewProfiles(
            likesState: likesState,
          );
          final likesPage = likesState.valueOrNull;
          final likesCount =
              likesPage?.items.length ?? (likesState.isLoading ? null : 0);

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + _datingTopInset,
                  bottom: DateasyBottomNavMetrics.reservedHeight(
                    context,
                    extraGap: _datingActionNavGap,
                  ),
                ),
                child: Column(
                  children: [
                    const DateasyTopBar(),
                    const SizedBox(height: _datingTopControlsGap),
                    _DatingHeaderControls(
                      hasPlus: hasPlus,
                      count: likesCount,
                      profiles: likePreviewProfiles,
                      onTap: () => context.go(
                        Uri(
                          path: '/dating/likes',
                          queryParameters: {
                            if (likesCount != null) 'count': '$likesCount',
                          },
                        ).toString(),
                      ),
                    ),
                    const SizedBox(height: _datingCardTopGap),
                    Expanded(
                      child: isFirstLoading
                          ? const Align(
                              alignment: Alignment.topCenter,
                              child: _DatingStatusCard(
                                message: 'Загружаем подборку',
                              ),
                            )
                          : current == null
                              ? Align(
                                  alignment: Alignment.topCenter,
                                  child: _DatingStatusCard(
                                    message: cardsState.hasError
                                        ? 'Не удалось загрузить подборку'
                                        : 'Пока нет анкет. Попробуй расширить фильтры',
                                  ),
                                )
                              : _DatingDeckLayout(
                                  enabled: !_submitting,
                                  card: current,
                                  limits: limits,
                                  onSwipe: (action) => unawaited(
                                    _sendAction(
                                      ref,
                                      context,
                                      currentCard!,
                                      action,
                                      cardIndex: currentIndex,
                                    ),
                                  ),
                                  onRewind: () =>
                                      unawaited(_rewind(ref, context)),
                                  onPass: () => unawaited(
                                    _sendAction(
                                      ref,
                                      context,
                                      currentCard!,
                                      'pass',
                                      cardIndex: currentIndex,
                                    ),
                                  ),
                                  onSuper: () => unawaited(
                                    _sendAction(
                                      ref,
                                      context,
                                      currentCard!,
                                      'super_like',
                                      cardIndex: currentIndex,
                                    ),
                                  ),
                                  onLike: () => unawaited(
                                    _sendAction(
                                      ref,
                                      context,
                                      currentCard!,
                                      'like',
                                      cardIndex: currentIndex,
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
              const DateasyBottomNav(),
            ],
          );
        },
      ),
    );
  }

  void _syncFilters(DatingDiscoverFilters filters) {
    if (_filtersKey == filters.cacheValue) {
      return;
    }
    _filtersKey = filters.cacheValue;
    _deckCards.clear();
    _handledIds.clear();
    _history.clear();
    _index = 0;
    _nextCursor = null;
    _pagingExhausted = false;
    _loadingMore = false;
    _loadedMore = false;
    _initialPageSignature = null;
  }

  void _mergeInitialPage(CardPage page) {
    final signature =
        '${page.items.map((item) => item.id).join(',')}|${page.nextCursor ?? ''}';
    if (_initialPageSignature == signature) {
      return;
    }
    _initialPageSignature = signature;
    _mergeCards(page.items);
    if (!_loadedMore) {
      _nextCursor = page.nextCursor;
      _pagingExhausted = page.nextCursor == null || page.nextCursor!.isEmpty;
    }
  }

  void _mergeCards(List<BackendCardItem> cards) {
    for (final card in cards) {
      if (card.id.isEmpty) {
        continue;
      }
      final index = _deckCards.indexWhere((item) => item.id == card.id);
      if (index == -1) {
        _deckCards.add(card);
      } else {
        _deckCards[index] = card;
      }
    }
  }

  MapEntry<int, BackendCardItem>? _currentEntry() {
    for (var index = _index; index < _deckCards.length; index += 1) {
      final card = _deckCards[index];
      if (!_handledIds.contains(card.id)) {
        return MapEntry(index, card);
      }
    }
    return null;
  }

  List<_DatingProfile> _likePreviewProfiles({
    required AsyncValue<CardPage>? likesState,
  }) {
    return likesState?.valueOrNull?.items
            .map(_DatingProfile.fromBackend)
            .take(3)
            .toList(growable: false) ??
        const <_DatingProfile>[];
  }

  void _restoreCard(BackendCardItem card, int index) {
    final existing = _deckCards.indexWhere((item) => item.id == card.id);
    if (existing == -1) {
      _deckCards.insert(index.clamp(0, _deckCards.length), card);
    } else {
      _deckCards[existing] = card;
    }
  }

  void _maybePrefetch(WidgetRef ref, int currentIndex) {
    if (_loadingMore || _pagingExhausted || _nextCursor == null) {
      return;
    }
    final remaining = _deckCards.length - currentIndex - 1;
    if (remaining <= _prefetchRemaining) {
      unawaited(_loadMore(ref));
    }
  }

  Future<void> _loadMore(WidgetRef ref) async {
    final cursor = _nextCursor;
    if (_loadingMore || cursor == null || cursor.isEmpty) {
      return;
    }
    _loadingMore = true;
    try {
      final filters = ref.read(datingDiscoverFiltersProvider);
      final requestFiltersKey = filters.cacheValue;
      final page =
          await ref.read(backendRepositoryProvider).fetchDatingDiscover(
                limit: _discoverPageSize,
                cursor: cursor,
                gender: filters.gender,
                ageMin: filters.ageMin,
                ageMax: filters.ageMax,
                radiusKm: filters.radiusKm,
                interests: filters.interests,
                verifiedOnly: filters.verifiedOnly,
                onlineOnly: filters.onlineOnly,
                newThisWeekOnly: filters.newThisWeekOnly,
              );
      if (!mounted) {
        return;
      }
      if (_filtersKey != requestFiltersKey) {
        return;
      }
      setState(() {
        _loadedMore = true;
        _mergeCards(page.items);
        _nextCursor = page.nextCursor;
        _pagingExhausted = page.nextCursor == null || page.nextCursor!.isEmpty;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      _loadingMore = false;
    }
  }

  bool _hasFrendlyPlus(SubscriptionStateData? subscription) {
    return subscription?.status == 'active' || subscription?.status == 'trial';
  }

  void _openMatch(BuildContext context, String userId, String? chatId) {
    context.go(
      Uri(
        path: '/match',
        queryParameters: {
          'userId': userId,
          if (chatId != null && chatId.isNotEmpty) 'chatId': chatId,
        },
      ).toString(),
    );
  }

  void _handleBackendActionError(
    WidgetRef ref,
    BuildContext context,
    BackendActionException error,
  ) {
    switch (error.code) {
      case 'tokens_insufficient':
        context.push('/wallet');
        return;
      case 'frendly_plus_required':
        context.push('/paywall');
        return;
      case 'dating_swipe_rate_limited':
        _showSwipeLimitDialog(ref, context);
        return;
      case 'dating_rewind_unavailable':
        _showSnackBar(context, 'Можно вернуть только последний пропуск');
        return;
      default:
        _showSnackBar(context, 'Не удалось сохранить действие');
        return;
    }
  }

  void _showSwipeLimitDialog(WidgetRef ref, BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var loading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: DateasyColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Лимиты кончились'),
              content: const Text(
                'Можно получить больше свайпов через Frendly+.',
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Позже'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setDialogState(() => loading = true);
                          try {
                            final session = await ref
                                .read(paymentActionsProvider)
                                .createCheckoutSession(
                                  source: 'dating_swipe_limit',
                                  returnTo: '/dating',
                                );
                            final url = Uri.tryParse(session.checkoutUrl);
                            if (url == null) {
                              throw const FormatException('Invalid checkout URL');
                            }
                            final opened = await launchUrl(
                              url,
                              mode: LaunchMode.inAppBrowserView,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (!opened && context.mounted) {
                              _showSnackBar(context, 'Не удалось открыть оплату');
                            }
                          } catch (_) {
                            if (context.mounted) {
                              _showSnackBar(context, 'Не удалось открыть оплату');
                            }
                            if (dialogContext.mounted) {
                              setDialogState(() => loading = false);
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Получить больше'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Iterable<String> datingPrewarmImageUrls(
  List<BackendCardItem> cards, {
  required int currentIndex,
}) sync* {
  var emitted = 0;
  for (var index = currentIndex + 1;
      index < cards.length && emitted < 3;
      index += 1) {
    final profile = _DatingProfile.fromBackend(cards[index]);
    final url = _preferredDatingPhotoUrl(profile)?.trim();
    if (url == null || url.isEmpty) {
      continue;
    }
    emitted += 1;
    yield url;
  }
}

class _DatingHeaderControls extends StatelessWidget {
  const _DatingHeaderControls({
    required this.hasPlus,
    required this.count,
    required this.profiles,
    required this.onTap,
  });

  final bool hasPlus;
  final int? count;
  final List<_DatingProfile> profiles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _LikesYouBanner(
              hasPlus: hasPlus,
              count: count,
              profiles: profiles,
              onTap: onTap,
            ),
          ),
          const SizedBox(width: 10),
          const _FilterButton(),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Фильтры',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/dating/filter'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: dateasyLimeGradient,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55BEFF67),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.slidersHorizontal,
                color: DateasyColors.backgroundDeep,
                size: 20,
              ),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: DateasyColors.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: DateasyColors.background, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikesYouBanner extends StatelessWidget {
  const _LikesYouBanner({
    required this.hasPlus,
    required this.count,
    required this.profiles,
    required this.onTap,
  });

  final bool hasPlus;
  final int? count;
  final List<_DatingProfile> profiles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final safeCount = count ?? 0;
    final title = count == null
        ? 'Проверяем лайки'
        : safeCount > 0
            ? _likedYouTitle(safeCount)
            : 'Пока нет лайков';

    return Semantics(
      button: true,
      label: 'Кто тебя лайкнул',
      child: GestureDetector(
        onTap: onTap,
        child: _GlassBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _LikesAvatarStack(
                  profiles: profiles,
                  locked: !hasPlus,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasPlus ? LucideIcons.heart : LucideIcons.lock,
                            size: 13,
                            color: hasPlus
                                ? DateasyColors.lime
                                : DateasyColors.pink,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPlus
                            ? 'Открой список и перейди в профиль'
                            : safeCount > 0
                                ? 'Открой с Frendly+'
                                : 'Здесь появятся новые симпатии',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.muted,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: dateasyLimeGradient,
                  ),
                  child: Text(
                    'Открыть',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.backgroundDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _likedYouTitle(int count) {
  return count == 1 ? '1 лайкнул тебя' : '$count лайкнули тебя';
}

class _LikesAvatarStack extends StatelessWidget {
  const _LikesAvatarStack({
    required this.profiles,
    required this.locked,
  });

  final List<_DatingProfile> profiles;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final items = profiles.take(3).toList(growable: false);
    return SizedBox(
      width: 74,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < 3; index += 1)
            Positioned(
              left: index * 18,
              child: _LikesPreviewAvatar(
                profile: index < items.length ? items[index] : null,
                locked: locked,
              ),
            ),
          if (locked)
            Positioned(
              right: 0,
              bottom: -1,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DateasyColors.backgroundDeep,
                  border: Border.all(color: DateasyColors.border),
                ),
                child: const Icon(
                  LucideIcons.lock,
                  size: 10,
                  color: DateasyColors.lime,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LikesPreviewAvatar extends StatelessWidget {
  const _LikesPreviewAvatar({
    required this.profile,
    required this.locked,
  });

  final _DatingProfile? profile;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    Widget image = DateasyRemoteImage(
      imageUrl: profile?.imageUrl,
      usage: DateasyImageUsage.avatar,
    );
    if (locked) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: image,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: DateasyColors.surface2,
          border: Border.all(color: DateasyColors.background, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: image,
      ),
    );
  }
}

class _DatingDeckLayout extends StatelessWidget {
  const _DatingDeckLayout({
    required this.enabled,
    required this.card,
    required this.limits,
    required this.onSwipe,
    required this.onRewind,
    required this.onPass,
    required this.onSuper,
    required this.onLike,
  });

  final bool enabled;
  final _DatingProfile card;
  final DatingLimitsData? limits;
  final ValueChanged<String> onSwipe;
  final VoidCallback onRewind;
  final VoidCallback onPass;
  final VoidCallback onSuper;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = _cardHeightFor(constraints.maxHeight);
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SwipeableDatingCard(
              enabled: enabled,
              onSwipe: onSwipe,
              child: _CardStack(
                card: card,
                height: cardHeight,
              ),
            ),
            const SizedBox(height: _datingCardActionGap),
            IgnorePointer(
              ignoring: !enabled,
              child: _Actions(
                enabled: enabled,
                limits: limits,
                onRewind: onRewind,
                onPass: onPass,
                onSuper: onSuper,
                onLike: onLike,
              ),
            ),
          ],
        );
        final contentHeight =
            cardHeight + _datingCardActionGap + _datingActionMaxDiameter;

        if (contentHeight <= constraints.maxHeight) {
          return Align(
            alignment: Alignment.topCenter,
            child: content,
          );
        }

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: content,
        );
      },
    );
  }

  double _cardHeightFor(double availableHeight) {
    final height =
        availableHeight - _datingCardActionGap - _datingActionMaxDiameter;
    return height.clamp(_datingMinCardHeight, _datingMaxCardHeight).toDouble();
  }
}

class _SwipeableDatingCard extends StatefulWidget {
  const _SwipeableDatingCard({
    required this.child,
    required this.enabled,
    required this.onSwipe,
  });

  final Widget child;
  final bool enabled;
  final ValueChanged<String> onSwipe;

  @override
  State<_SwipeableDatingCard> createState() => _SwipeableDatingCardState();
}

class _SwipeableDatingCardState extends State<_SwipeableDatingCard> {
  static const double _threshold = 92;

  double _dragX = 0;

  @override
  void didUpdateWidget(covariant _SwipeableDatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _dragX != 0) {
      _dragX = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('dating-swipe-card'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: widget.enabled
          ? (details) {
              setState(() {
                _dragX += details.delta.dx;
              });
            }
          : null,
      onHorizontalDragEnd: widget.enabled ? _finishDrag : null,
      onHorizontalDragCancel: _resetDrag,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(_dragX, 0, 0, 1)
          ..rotateZ((_dragX / 900).clamp(-0.16, 0.16)),
        child: widget.child,
      ),
    );
  }

  void _finishDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldLike = _dragX > _threshold || velocity > 720;
    final shouldPass = _dragX < -_threshold || velocity < -720;
    if (shouldLike) {
      widget.onSwipe('like');
    } else if (shouldPass) {
      widget.onSwipe('pass');
    }
    _resetDrag();
  }

  void _resetDrag() {
    if (!mounted) {
      return;
    }
    setState(() {
      _dragX = 0;
    });
  }
}

class _CardStack extends StatefulWidget {
  const _CardStack({
    required this.card,
    required this.height,
  });

  final _DatingProfile card;
  final double height;

  @override
  State<_CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<_CardStack> {
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant _CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _photoIndex = 0;
    } else {
      final maxIndex = widget.card.photos.length - 1;
      if (maxIndex < 0) {
        _photoIndex = 0;
      } else if (_photoIndex > maxIndex) {
        _photoIndex = maxIndex;
      }
    }
  }

  void _showPreviousPhoto() {
    if (_photoIndex == 0) {
      return;
    }
    setState(() {
      _photoIndex -= 1;
    });
  }

  void _showNextPhoto() {
    final maxIndex = widget.card.photos.length - 1;
    if (_photoIndex >= maxIndex) {
      return;
    }
    setState(() {
      _photoIndex += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final height = widget.height;
    final photos = card.photos;
    final activePhoto = photos.isEmpty
        ? _DatingPhoto(
            imageUrl: card.imageUrl, imageVariants: card.imageVariants)
        : photos[_photoIndex];
    final photoCount = photos.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 18,
              right: 18,
              top: 12,
              height: height - 26,
              child: Transform.scale(
                scale: 0.96,
                child: const _StackBackCard(color: DateasyColors.surface2),
              ),
            ),
            Positioned(
              left: 34,
              right: 34,
              top: 24,
              height: height - 34,
              child: Transform.scale(
                scale: 0.92,
                child: const _StackBackCard(color: DateasyColors.surface),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: DateasyColors.border),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.34),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        container: true,
                        excludeSemantics: true,
                        label: photoCount > 1
                            ? 'Фото ${_photoIndex + 1} из $photoCount'
                            : null,
                        image: true,
                        child: DateasyRemoteImage(
                          imageUrl: activePhoto.imageUrl,
                          imageVariants: activePhoto.imageVariants,
                          usage: DateasyImageUsage.fullscreen,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x661F0C3F),
                              DateasyColors.background,
                            ],
                            stops: [0.22, 0.58, 1],
                          ),
                        ),
                      ),
                      if (photoCount > 1) ...[
                        Positioned(
                          top: 8,
                          left: 12,
                          right: 12,
                          child: _PhotoProgress(
                            count: photoCount,
                            activeIndex: _photoIndex,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 32,
                          bottom: 104,
                          width: 120,
                          child: _PhotoTapZone(
                            semanticsLabel: 'Предыдущее фото',
                            alignment: Alignment.centerLeft,
                            enabled: _photoIndex > 0,
                            icon: LucideIcons.chevronLeft,
                            onTap: _showPreviousPhoto,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 32,
                          bottom: 104,
                          width: 120,
                          child: _PhotoTapZone(
                            semanticsLabel: 'Следующее фото',
                            alignment: Alignment.centerRight,
                            enabled: _photoIndex < photoCount - 1,
                            icon: LucideIcons.chevronRight,
                            onTap: _showNextPhoto,
                          ),
                        ),
                      ],
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (card.online) const _OnlineBadge(),
                            if (card.matchPercent != null)
                              _MatchBadge(value: card.matchPercent!),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 13,
                        right: 13,
                        bottom: 13,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.age == null
                                            ? card.name
                                            : '${card.name}, ${card.age}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontFamily: 'Sora',
                                              fontSize: 24,
                                              height: 1.08,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 7),
                                      Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.mapPin,
                                            size: 13,
                                            color: DateasyColors.muted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            card.distanceLabel,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: DateasyColors.muted,
                                                  fontSize: 11,
                                                ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(
                                            LucideIcons.briefcaseBusiness,
                                            size: 13,
                                            color: DateasyColors.muted,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              card.job,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: DateasyColors.muted,
                                                    fontSize: 11,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => context.push('/u/${card.id}'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: DateasyColors.foreground,
                                    ),
                                    child: Text(
                                      'Профиль',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: DateasyColors.backgroundDeep,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (card.interests.isNotEmpty) ...[
                              _Interests(items: card.interests),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoProgress extends StatelessWidget {
  const _PhotoProgress({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < count; index += 1) ...[
          if (index > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(
                  alpha: index == activeIndex ? 1 : 0.3,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoTapZone extends StatelessWidget {
  const _PhotoTapZone({
    required this.semanticsLabel,
    required this.alignment,
    required this.enabled,
    required this.icon,
    required this.onTap,
  });

  final String semanticsLabel;
  final Alignment alignment;
  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Align(
          alignment: alignment,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: enabled ? 1 : 0,
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DateasyColors.glass,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Icon(
                icon,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StackBackCard extends StatelessWidget {
  const _StackBackCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: color.withValues(alpha: 0.6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: DateasyColors.glass,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DateasyColors.lime,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'онлайн',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: dateasyLimeGradient,
      ),
      child: Text(
        '$value% мэтч',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.backgroundDeep,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Interests extends StatelessWidget {
  const _Interests({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: DateasyColors.glass,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 12,
                color: DateasyColors.lime,
              ),
              const SizedBox(width: 5),
              Text(
                item,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.enabled,
    required this.limits,
    required this.onRewind,
    required this.onPass,
    required this.onSuper,
    required this.onLike,
  });

  final bool enabled;
  final DatingLimitsData? limits;
  final VoidCallback onRewind;
  final VoidCallback onPass;
  final VoidCallback onSuper;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final rewindBadge = _limitBadge(limits?.rewinds);
    final superBadge = _limitBadge(limits?.superLikes);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundAction(
          icon: LucideIcons.undo2,
          size: 48,
          iconColor: DateasyColors.pink,
          badge: rewindBadge?.label,
          badgeShowsTokens: rewindBadge?.showsTokens ?? false,
          onTap: enabled ? onRewind : null,
          semanticLabel: 'Вернуть',
        ),
        const SizedBox(width: 12),
        _RoundAction(
          icon: LucideIcons.x,
          size: 48,
          onTap: enabled ? onPass : null,
          semanticLabel: 'Пропустить',
        ),
        const SizedBox(width: 12),
        _RoundAction(
          icon: Icons.favorite,
          size: 58,
          gradient: dateasyLimeGradient,
          iconColor: DateasyColors.backgroundDeep,
          onTap: enabled ? onLike : null,
          semanticLabel: 'Лайк',
        ),
        const SizedBox(width: 12),
        _RoundAction(
          icon: LucideIcons.star,
          size: 48,
          color: DateasyColors.lilac,
          iconColor: DateasyColors.backgroundDeep,
          badge: superBadge?.label,
          badgeShowsTokens: superBadge?.showsTokens ?? false,
          onTap: enabled ? onSuper : null,
          semanticLabel: 'Super-like',
        ),
      ],
    );
  }

  _ActionLimitBadge? _limitBadge(DatingLimitBucketData? limit) {
    if (limit == null) {
      return null;
    }
    if (limit.freeRemaining > 0) {
      return _ActionLimitBadge(
        label: '${limit.freeRemaining}',
        showsTokens: false,
      );
    }
    return _ActionLimitBadge(
      label: '${limit.paidCost}',
      showsTokens: true,
    );
  }
}

class _ActionLimitBadge {
  const _ActionLimitBadge({
    required this.label,
    required this.showsTokens,
  });

  final String label;
  final bool showsTokens;
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.size,
    required this.semanticLabel,
    this.onTap,
    this.color,
    this.gradient,
    this.iconColor,
    this.badge,
    this.badgeShowsTokens = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Color? color;
  final Gradient? gradient;
  final Color? iconColor;
  final String? badge;
  final bool badgeShowsTokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color ?? DateasyColors.glass,
                gradient: gradient,
                border: gradient == null && color == null
                    ? Border.all(color: DateasyColors.border)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: onTap == null ? 0.08 : 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: size >= 56 ? 26 : 20,
                color: onTap == null
                    ? DateasyColors.muted.withValues(alpha: 0.45)
                    : iconColor ?? DateasyColors.muted,
              ),
            ),
            if (badge != null)
              Positioned(
                top: -3,
                right: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: DateasyColors.foreground,
                  ),
                  child: Row(
                    children: [
                      if (badgeShowsTokens) ...[
                        const Icon(
                          LucideIcons.coins,
                          key: ValueKey('dating-action-token-badge'),
                          size: 10,
                          color: DateasyColors.backgroundDeep,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        badge!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.backgroundDeep,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: DateasyColors.glass,
        border: Border.all(color: DateasyColors.border),
      ),
      child: child,
    );
  }
}

class _DatingActionHistoryItem {
  const _DatingActionHistoryItem({
    required this.card,
    required this.action,
    required this.index,
  });

  final BackendCardItem card;
  final String action;
  final int index;
}

class _DatingProfile {
  const _DatingProfile({
    required this.id,
    required this.name,
    required this.job,
    required this.distanceLabel,
    this.age,
    this.imageUrl,
    this.imageVariants,
    this.photos = const [],
    this.matchPercent,
    this.interests = const [],
    this.online = false,
  });

  final String id;
  final String name;
  final String job;
  final String distanceLabel;
  final int? age;
  final String? imageUrl;
  final Object? imageVariants;
  final List<_DatingPhoto> photos;
  final int? matchPercent;
  final List<String> interests;
  final bool online;

  factory _DatingProfile.fromBackend(BackendCardItem item) {
    final raw = item.raw;
    final profile = _map(raw['profile']);
    final imageVariants = _profileImageVariants(raw);
    return _DatingProfile(
      id: item.id,
      name: item.title.isEmpty ? 'Профиль' : item.title,
      age: _intOrNull(raw['age'] ?? profile['age']),
      imageUrl: item.imageUrl,
      imageVariants: imageVariants,
      photos: _photoList(
        raw['photos'],
        fallbackUrl: item.imageUrl,
        fallbackVariants: imageVariants,
      ),
      matchPercent: _intOrNull(
        raw['matchPercent'] ??
            raw['match'] ??
            raw['matchScore'] ??
            raw['compatibility'] ??
            raw['compatibilityPercent'],
      ),
      job: _stringOrNull(
            raw['job'] ??
                raw['profession'] ??
                raw['occupation'] ??
                raw['vibe'] ??
                profile['vibe'],
          ) ??
          item.city ??
          'Готов к встрече',
      distanceLabel: _stringOrNull(raw['distance'] ?? raw['distanceLabel']) ??
          item.city ??
          '',
      interests: _stringList(
        raw['commonInterests'] ??
            raw['tags'] ??
            raw['interests'] ??
            profile['interests'],
      ),
      online: raw['online'] == true,
    );
  }
}

class _DatingPhoto {
  const _DatingPhoto({
    required this.imageUrl,
    this.imageVariants,
  });

  final String? imageUrl;
  final Object? imageVariants;
}

class _DatingStatusCard extends StatelessWidget {
  const _DatingStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _GlassBox(
        height: 320,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DateasyColors.muted,
                ),
          ),
        ),
      ),
    );
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const {};
}

List<Object?> _list(Object? value) {
  if (value is List) {
    return value;
  }
  return const [];
}

String? _stringOrNull(Object? value) {
  final result = value?.toString();
  if (result == null || result.isEmpty) {
    return null;
  }
  return result;
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

List<_DatingPhoto> _photoList(
  Object? value, {
  String? fallbackUrl,
  Object? fallbackVariants,
}) {
  final photos = <_DatingPhoto>[];
  final urls = <String>{};
  void add(Object? candidate, Object? variants) {
    final url = _stringOrNull(candidate)?.trim();
    if (url == null || url.isEmpty || !urls.add(url)) {
      return;
    }
    photos.add(_DatingPhoto(imageUrl: url, imageVariants: variants));
  }

  for (final item in _list(value)) {
    if (item is String) {
      add(item, null);
      continue;
    }
    final photo = _map(item);
    final media = _map(photo['media']);
    final variants = _photoImageVariants(photo);
    add(
      photo['url'] ??
          photo['imageUrl'] ??
          photo['photoUrl'] ??
          photo['avatarUrl'] ??
          photo['downloadUrl'] ??
          media['url'] ??
          media['downloadUrl'],
      variants,
    );
  }
  if (photos.isEmpty) {
    add(fallbackUrl, fallbackVariants);
  }
  return photos;
}

Object? _profileImageVariants(Map<String, Object?> raw) {
  final primaryPhoto = _map(raw['primaryPhoto']);
  return raw['imageVariants'] ?? _photoImageVariants(primaryPhoto);
}

Object? _photoImageVariants(Map<String, Object?> photo) {
  final media = _map(photo['media']);
  return photo['variants'] ?? media['variants'];
}

String? _preferredDatingPhotoUrl(_DatingProfile profile) {
  final photo = profile.photos.isEmpty
      ? _DatingPhoto(
          imageUrl: profile.imageUrl,
          imageVariants: profile.imageVariants,
        )
      : profile.photos.first;
  return DateasyRemoteImage.resolveVariantImageUrl(
    imageUrl: photo.imageUrl,
    imageVariants: photo.imageVariants,
    usage: DateasyImageUsage.fullscreen,
  );
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}
