import 'dart:async';
import 'dart:ui';

import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/dating_profile.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _datingInterestFilters = [
  'вино',
  'кофе',
  'кино',
  'концерты',
  'wellness',
  'юмор',
  'книги',
];
const _datingAreaFilters = [
  'Все',
  'Центр',
  'Патрики',
  'Чистые пруды',
  'Тверская',
  'Хамовники',
];
const _datingTimeFilters = [
  'Сейчас',
  'Сегодня вечером',
  'Эти выходные',
  'Всегда онлайн',
];

class DatingScreen extends ConsumerStatefulWidget {
  const DatingScreen({
    this.initialProfileId,
    super.key,
  });

  final String? initialProfileId;

  @override
  ConsumerState<DatingScreen> createState() => _DatingScreenState();
}

class _DatingScreenState extends ConsumerState<DatingScreen> {
  String _tab = 'discover';
  bool _submitting = false;
  final Map<String, int> _photoIndexes = <String, int>{};
  final Set<String> _handledProfileIds = <String>{};
  final Map<String, String> _matchedChatIds = <String, String>{};
  final Set<String> _savedProfileIds = <String>{};
  List<DatingProfileData> _lastDiscoverProfiles = const [];
  final Set<String> _filterInterests = <String>{};
  String _filterArea = 'Все';
  String _filterTime = 'Сегодня вечером';
  RangeValues _filterAge = const RangeValues(22, 35);

  @override
  Widget build(BuildContext context) {
    final discoverAsync = ref.watch(datingDiscoverProvider);
    final subscriptionAsync =
        _tab == 'likes' ? ref.watch(subscriptionStateProvider) : null;
    final subscription = subscriptionAsync?.valueOrNull;
    final hasFrendlyPlus =
        subscription?.status == 'trial' || subscription?.status == 'active';
    final subscriptionLoading = subscriptionAsync != null &&
        subscriptionAsync.isLoading &&
        !subscriptionAsync.hasValue;
    final likesAsync = _tab == 'likes' && hasFrendlyPlus
        ? ref.watch(datingLikesProvider)
        : null;
    final likes = likesAsync?.valueOrNull ?? const <DatingProfileData>[];
    final loadedDiscover = discoverAsync.valueOrNull;
    if (loadedDiscover != null) {
      _lastDiscoverProfiles = loadedDiscover;
    }
    final discover = loadedDiscover ?? _lastDiscoverProfiles;
    final filteredDiscover = _filterProfiles(discover);
    final current = _currentProfile(filteredDiscover);
    if (_tab == 'discover' && filteredDiscover.isNotEmpty) {
      unawaited(
        ref.read(appMediaPrewarmServiceProvider).warmProfileImages(
              _prewarmPhotoUrls(filteredDiscover),
              usageProfile: BbImageUsageProfile.hero,
              limit: 3,
              concurrency: 2,
            ),
      );
    }
    final hasWidePhotoTapZone = _tab == 'discover' &&
        current != null &&
        _photosFor(current).length > 1 &&
        MediaQuery.sizeOf(context).width > 520;

    return BbV5Scaffold(
      child: Stack(
        children: [
          BbV5Page(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Column(
              children: [
                _DatingHeader(
                  filtersActive: _filtersActive,
                  onBack: () => _handleBack(context),
                  onFilter: () => _openFilters(context),
                ),
                const SizedBox(height: 20),
                _DatingTabs(
                  activeTab: _tab,
                  likesCount: likes.length,
                  onTabChanged: (tab) {
                    setState(() {
                      _tab = tab;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _tab == 'discover'
                      ? _buildDiscover(
                          context,
                          current,
                          discoverAsync,
                          filteredDiscover,
                        )
                      : !hasFrendlyPlus
                          ? subscriptionLoading
                              ? const _DatingLoadingState()
                              : _DatingPlusLockedState(
                                  onOpenPaywall: () =>
                                      context.pushRoute(AppRoute.paywall),
                                )
                          : _buildLikes(context, likesAsync, likes),
                ),
              ],
            ),
          ),
          if (hasWidePhotoTapZone)
            Positioned(
              top: 128,
              right: 0,
              width: MediaQuery.sizeOf(context).width * 0.34,
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _submitting ? null : () => _showNextPhoto(current),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }

  void _handleBack(BuildContext context) async {
    final popped = await Navigator.of(context).maybePop();
    if (!popped && context.mounted) {
      context.goRoute(AppRoute.tonight);
    }
  }

  Widget _buildDiscover(
    BuildContext context,
    DatingProfileData? current,
    AsyncValue<List<DatingProfileData>> discoverAsync,
    List<DatingProfileData> visibleProfiles,
  ) {
    if (visibleProfiles.isNotEmpty && current != null) {
      return _buildDiscoverList(context, current, visibleProfiles);
    }
    if (visibleProfiles.isNotEmpty && current == null) {
      return const _DatingEmptyState(
        icon: LucideIcons.sparkles,
        title: 'Пока нет новых профилей',
        subtitle: 'Загляни позже, когда рядом появятся новые анкеты',
      );
    }

    return discoverAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return const _DatingEmptyState(
            icon: LucideIcons.sparkles,
            title: 'Пока нет новых профилей',
            subtitle: 'Загляни позже, когда рядом появятся новые анкеты',
          );
        }

        if (visibleProfiles.isEmpty || current == null) {
          return const _DatingEmptyState(
            icon: LucideIcons.sparkles,
            title: 'Никого под фильтр',
            subtitle: 'Попробуй сбросить интересы или район',
          );
        }

        return const _DatingEmptyState(
          icon: LucideIcons.sparkles,
          title: 'Пока нет новых профилей',
          subtitle: 'Загляни позже, когда рядом появятся новые анкеты',
        );
      },
      loading: () => const _DatingLoadingState(),
      error: (_, __) => const _DatingEmptyState(
        icon: LucideIcons.wifi_off,
        title: 'Не получилось загрузить анкеты',
        subtitle: 'Проверь соединение и попробуй обновить экран',
      ),
    );
  }

  Widget _buildDiscoverList(
    BuildContext context,
    DatingProfileData current,
    List<DatingProfileData> visibleProfiles,
  ) {
    final currentIndex = visibleProfiles.indexWhere(
          (profile) => profile.userId == current.userId,
        ) +
        1;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        0,
        _datingBottomScrollPadding(context, base: 156),
      ),
      children: [
        _SwipeableDatingCard(
          key: const ValueKey('dating-discover-card'),
          enabled: !_submitting,
          onSwipe: (direction) => _handleAction(
            context,
            current,
            action: direction == DatingSwipeDirection.like ? 'like' : 'pass',
          ),
          child: _DatingProfileCard(
            key: ValueKey('dating-profile-card-${current.userId}'),
            profile: current,
            saved: _savedProfileIds.contains(current.userId),
            photoIndex: _photoIndexFor(current),
            actionsEnabled: !_submitting,
            onPreviousPhoto:
                _submitting ? null : () => _showPreviousPhoto(current),
            onNextPhoto: _submitting ? null : () => _showNextPhoto(current),
            onSaveToggle: () {
              setState(() {
                if (_savedProfileIds.contains(current.userId)) {
                  _savedProfileIds.remove(current.userId);
                } else {
                  _savedProfileIds.add(current.userId);
                }
              });
            },
            onSkip: () => _handleAction(context, current, action: 'pass'),
            onSuper: () => _handleAction(
              context,
              current,
              action: 'super_like',
            ),
            onLike: () => _handleAction(context, current, action: 'like'),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${currentIndex.toString().padLeft(2, '0')} / '
          '${visibleProfiles.length.toString().padLeft(2, '0')}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: BbV5Colors.inkMute,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.68,
          ),
        ),
      ],
    );
  }

  Widget _buildLikes(
    BuildContext context,
    AsyncValue<List<DatingProfileData>>? likesAsync,
    List<DatingProfileData> likes,
  ) {
    return likesAsync!.when(
      data: (_) {
        if (likes.isEmpty) {
          return const _DatingEmptyState(
            icon: LucideIcons.heart,
            title: 'Пока нет входящих лайков',
            subtitle: 'Лайкни пару карточек, и здесь появятся ответы',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            _datingBottomScrollPadding(context, base: 156),
          ),
          itemCount: likes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final profile = likes[index];
            final chatId = _matchedChatIds[profile.userId];
            final isMatch = chatId != null;
            return BbV5Card(
              radius: 24,
              padding: const EdgeInsets.all(14),
              onTap: _submitting
                  ? null
                  : () {
                      if (chatId != null) {
                        context.pushRoute(
                          AppRoute.personalChat,
                          pathParameters: {'chatId': chatId},
                        );
                        return;
                      }
                      _handleAction(
                        context,
                        profile,
                        action: 'like',
                        fromLikes: true,
                      );
                    },
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          BbV5Colors.terraSoft,
                          BbV5Colors.brandSoft,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BbV5Colors.hair),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: _DatingThumbnail(profile: profile),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.age == null
                              ? profile.name
                              : '${profile.name}, ${profile.age}',
                          overflow: TextOverflow.ellipsis,
                          style: bbV5DisplayStyle(
                            fontSize: 15,
                            height: 1.25,
                          ).copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.about,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySoft.copyWith(
                            color: BbV5Colors.inkMute,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isMatch ? LucideIcons.check : LucideIcons.eye,
                              size: 12,
                              color:
                                  isMatch ? BbV5Colors.brand : BbV5Colors.terra,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isMatch
                                  ? 'MATCH · ОТКРЫТЬ ЧАТ'
                                  : 'Лайкнул(а) тебя',
                              style: AppTextStyles.caption.copyWith(
                                color: isMatch
                                    ? BbV5Colors.brand
                                    : BbV5Colors.terra,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: BbV5Colors.accent,
                        shape: BoxShape.circle,
                        boxShadow: BbV5Shadows.ink,
                      ),
                      child: Icon(
                        LucideIcons.message_circle,
                        size: 16,
                        color: BbV5Colors.paperHi,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const _DatingLoadingState(),
      error: (_, __) => const _DatingEmptyState(
        icon: LucideIcons.wifi_off,
        title: 'Не получилось загрузить лайки',
        subtitle: 'Проверь соединение и вернись к вкладке позже',
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    DatingProfileData profile, {
    required String action,
    bool fromLikes = false,
  }) async {
    if (_submitting) {
      return;
    }

    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final targetUserId = profile.userId;
    final previousPhotoIndex = _photoIndexes[targetUserId];
    final previousTombstones = ref.read(datingActionTombstonesProvider);
    final shouldAdvanceOptimistically = !fromLikes;
    final tombstoneAction = action == 'pass' ? 'skip' : action;
    setState(() {
      _submitting = true;
      if (shouldAdvanceOptimistically) {
        _handledProfileIds.add(targetUserId);
        _photoIndexes.remove(targetUserId);
      }
    });
    ref.read(datingActionTombstonesProvider.notifier).state = {
      ...previousTombstones,
      targetUserId: tombstoneAction,
    };

    try {
      final result = await repository.sendDatingAction(
        targetUserId: targetUserId,
        action: action,
      );

      if (!mounted || !context.mounted) {
        return;
      }

      final isMatched = result.matched;
      final matchedChatId = isMatched ? result.chatId : null;
      setState(() {
        if (matchedChatId != null) {
          _matchedChatIds[targetUserId] = matchedChatId;
        }
      });
      if (isMatched) {
        ref.read(datingActionTombstonesProvider.notifier).state = {
          ...ref.read(datingActionTombstonesProvider),
          targetUserId: 'match_open',
        };
      }

      container.invalidate(datingDiscoverProvider);
      if (isMatched) {
        container.invalidate(matchesProvider);
      }
      if (!(fromLikes && matchedChatId != null)) {
        container.invalidate(datingLikesProvider);
      }

      final remaining = result.superLikeQuota?.remaining;
      if (action == 'super_like' && remaining != null && !result.matched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Суперлайков осталось: $remaining')),
        );
      }

      if (isMatched && !fromLikes) {
        context.pushRoute(
          AppRoute.match,
          pathParameters: {'userId': targetUserId},
        );
      }
    } on DioException catch (error) {
      _rollbackOptimisticAction(
        targetUserId,
        shouldAdvanceOptimistically,
        previousPhotoIndex,
        previousTombstones,
      );
      if (!context.mounted) {
        return;
      }
      if (_isDatingPaywallError(error)) {
        await context.pushRoute(AppRoute.paywall);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось сохранить действие')),
      );
    } catch (_) {
      _rollbackOptimisticAction(
        targetUserId,
        shouldAdvanceOptimistically,
        previousPhotoIndex,
        previousTombstones,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось сохранить действие')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _rollbackOptimisticAction(
    String targetUserId,
    bool shouldRollback,
    int? previousPhotoIndex,
    Map<String, String> previousTombstones,
  ) {
    ref.read(datingActionTombstonesProvider.notifier).state =
        previousTombstones;
    if (!shouldRollback || !mounted) {
      return;
    }
    setState(() {
      _handledProfileIds.remove(targetUserId);
      if (previousPhotoIndex == null) {
        _photoIndexes.remove(targetUserId);
      } else {
        _photoIndexes[targetUserId] = previousPhotoIndex;
      }
    });
  }

  bool _isDatingPaywallError(DioException error) {
    final data = error.response?.data;
    final code = data is Map ? data['code'] : null;
    return code == 'super_like_limit_reached' ||
        code == 'frendly_plus_required';
  }

  List<DatingProfileData> _filterProfiles(List<DatingProfileData> profiles) {
    return profiles.where((profile) {
      final age = profile.age;
      if (age != null &&
          (age < _filterAge.start.round() || age > _filterAge.end.round())) {
        return false;
      }

      if (_filterArea != 'Все') {
        final area = (profile.area ?? '').toLowerCase();
        if (area.isNotEmpty && !area.contains(_filterArea.toLowerCase())) {
          return false;
        }
      }

      if (_filterInterests.isNotEmpty) {
        final tags = profile.tags.map((tag) => tag.toLowerCase()).toSet();
        final hasCommonInterest = _filterInterests.any(
          (interest) => tags.contains(interest.toLowerCase()),
        );
        if (!hasCommonInterest) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  bool get _filtersActive {
    return _filterArea != 'Все' ||
        _filterTime != 'Сегодня вечером' ||
        _filterInterests.isNotEmpty ||
        _filterAge.start.round() != 22 ||
        _filterAge.end.round() != 35;
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: BbV5Colors.ink.withValues(alpha: 0.5),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            void update(VoidCallback fn) {
              setState(fn);
              sheetSetState(() {});
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: BbV5Card(
                    padding: const EdgeInsets.all(20),
                    radius: 28,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const BbV5Kicker('Фильтры'),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Найти своих',
                                      style: bbV5DisplayStyle(
                                        fontSize: 18,
                                        height: 1.25,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              BbV5IconButton(
                                icon: LucideIcons.x,
                                size: 36,
                                iconSize: 16,
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const BbV5Kicker('Район'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _datingAreaFilters
                                .map(
                                  (area) => _DatingFilterChip(
                                    group: 'Район',
                                    label: area,
                                    active: _filterArea == area,
                                    onTap: () => update(() {
                                      _filterArea = area;
                                    }),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 16),
                          const BbV5Kicker('Когда'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _datingTimeFilters
                                .map(
                                  (time) => _DatingFilterChip(
                                    group: 'Когда',
                                    label: time,
                                    active: _filterTime == time,
                                    onTap: () => update(() {
                                      _filterTime = time;
                                    }),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 16),
                          const BbV5Kicker('Интересы'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _datingInterestFilters
                                .map(
                                  (interest) => _DatingFilterChip(
                                    group: 'Интерес',
                                    label: interest,
                                    visualLabel: '#$interest',
                                    active: _filterInterests.contains(interest),
                                    onTap: () => update(() {
                                      if (_filterInterests.contains(interest)) {
                                        _filterInterests.remove(interest);
                                      } else {
                                        _filterInterests.add(interest);
                                      }
                                    }),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 16),
                          BbV5Kicker(
                            'Возраст · ${_filterAge.start.round()}-'
                            '${_filterAge.end.round()}',
                          ),
                          const SizedBox(height: 8),
                          RangeSlider(
                            min: 18,
                            max: 50,
                            divisions: 32,
                            values: _filterAge,
                            activeColor: BbV5Colors.accent,
                            inactiveColor: BbV5Colors.hair,
                            labels: RangeLabels(
                              _filterAge.start.round().toString(),
                              _filterAge.end.round().toString(),
                            ),
                            onChanged: (values) => update(() {
                              _filterAge = values;
                            }),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: BbV5PillButton(
                                  label: 'Сбросить',
                                  onPressed: () => update(() {
                                    _filterArea = 'Все';
                                    _filterTime = 'Сегодня вечером';
                                    _filterInterests.clear();
                                    _filterAge = const RangeValues(22, 35);
                                  }),
                                  height: 48,
                                  fontSize: 13,
                                  expanded: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: BbV5PillButton(
                                  label: 'Показать',
                                  onPressed: () {
                                    Navigator.of(sheetContext).pop();
                                    setState(() {
                                      _photoIndexes.clear();
                                    });
                                  },
                                  dark: true,
                                  height: 48,
                                  fontSize: 13,
                                  expanded: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  DatingProfileData? _currentProfile(List<DatingProfileData> profiles) {
    if (profiles.isEmpty) {
      return null;
    }

    final initialProfileId = widget.initialProfileId;
    if (initialProfileId != null &&
        initialProfileId.isNotEmpty &&
        !_handledProfileIds.contains(initialProfileId)) {
      for (final profile in profiles) {
        if (profile.userId == initialProfileId) {
          return profile;
        }
      }
    }

    for (final profile in profiles) {
      if (!_handledProfileIds.contains(profile.userId)) {
        return profile;
      }
    }

    return null;
  }

  List<ProfilePhoto> _photosFor(DatingProfileData profile) {
    if (profile.photos.isNotEmpty) {
      return profile.photos;
    }
    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      return const [];
    }
    return [
      ProfilePhoto(
        id: '${profile.userId}-avatar',
        url: profile.avatarUrl!,
        order: 0,
      ),
    ];
  }

  Iterable<String?> _prewarmPhotoUrls(List<DatingProfileData> profiles) sync* {
    var emittedProfiles = 0;
    for (final profile in profiles) {
      if (_handledProfileIds.contains(profile.userId)) {
        continue;
      }
      final photo = _photosFor(profile).firstOrNull;
      if (photo != null) {
        yield photo.bestUrlFor(BbImageUsageProfile.hero);
      }
      emittedProfiles += 1;
      if (emittedProfiles >= 3) {
        break;
      }
    }
  }

  int _photoIndexFor(DatingProfileData profile) {
    final photos = _photosFor(profile);
    if (photos.isEmpty) {
      return 0;
    }
    final stored = _photoIndexes[profile.userId] ?? 0;
    return stored.clamp(0, photos.length - 1);
  }

  void _showPreviousPhoto(DatingProfileData profile) {
    final photos = _photosFor(profile);
    if (photos.length <= 1) {
      return;
    }
    final currentIndex = _photoIndexFor(profile);
    if (currentIndex == 0) {
      return;
    }
    setState(() {
      _photoIndexes[profile.userId] = currentIndex - 1;
    });
  }

  void _showNextPhoto(DatingProfileData profile) {
    final photos = _photosFor(profile);
    if (photos.length <= 1) {
      return;
    }
    final currentIndex = _photoIndexFor(profile);
    if (currentIndex >= photos.length - 1) {
      return;
    }
    setState(() {
      _photoIndexes[profile.userId] = currentIndex + 1;
    });
  }

  double _datingBottomScrollPadding(BuildContext context, {double base = 132}) {
    return base + MediaQuery.paddingOf(context).bottom;
  }
}

class _DatingHeader extends StatelessWidget {
  const _DatingHeader({
    required this.filtersActive,
    required this.onBack,
    required this.onFilter,
  });

  final bool filtersActive;
  final VoidCallback onBack;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: onBack,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker('Дейтинг · свидания'),
              SizedBox(height: 3),
              BbV5HeroTitle(
                title: 'Свидания',
                accent: 'рядом',
                fontSize: 22,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Фильтры дейтинга',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              BbV5IconButton(
                icon: LucideIcons.list_filter,
                onPressed: onFilter,
              ),
              if (filtersActive)
                const Positioned(
                  top: 7,
                  right: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: BbV5Colors.terra,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DatingTabs extends StatelessWidget {
  const _DatingTabs({
    required this.activeTab,
    required this.likesCount,
    required this.onTabChanged,
  });

  final String activeTab;
  final int likesCount;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FFFFFFF),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _DatingTabButton(
              label: 'Лента',
              active: activeTab == 'discover',
              onTap: () => onTabChanged('discover'),
            ),
          ),
          Expanded(
            child: _DatingTabButton(
              label: 'Лайки',
              suffix: likesCount > 0 ? ' · $likesCount' : null,
              active: activeTab == 'likes',
              onTap: () => onTabChanged('likes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatingTabButton extends StatelessWidget {
  const _DatingTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.suffix,
  });

  final String label;
  final String? suffix;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BbV5Radii.pill),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: active ? BbV5Colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(BbV5Radii.pill),
          boxShadow: active ? BbV5Shadows.ink : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.button.copyWith(
                fontFamily: 'Sora',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                letterSpacing: 0,
              ),
            ),
            if (suffix != null)
              Text(
                suffix!,
                style: AppTextStyles.button.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DatingPlusLockedState extends StatelessWidget {
  const _DatingPlusLockedState({
    required this.onOpenPaywall,
  });

  final VoidCallback onOpenPaywall;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BbV5Card(
        padding: const EdgeInsets.all(28),
        radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.lock,
              size: 32,
              color: BbV5Colors.terra,
            ),
            const SizedBox(height: 12),
            Text(
              'Лайки доступны с Frendly+',
              textAlign: TextAlign.center,
              style: bbV5DisplayStyle(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Открой входящие лайки и отвечай тем, кто уже выбрал тебя',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySoft.copyWith(
                color: BbV5Colors.inkMute,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            BbV5PillButton(
              label: 'Открыть Frendly+',
              onPressed: onOpenPaywall,
              dark: true,
              height: 46,
              fontSize: 13,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatingFilterChip extends StatelessWidget {
  const _DatingFilterChip({
    required this.group,
    required this.label,
    required this.active,
    required this.onTap,
    this.visualLabel,
  });

  final String group;
  final String label;
  final String? visualLabel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: '$group $label',
      onTap: onTap,
      child: ExcludeSemantics(
        child: BbV5Chip(
          label: visualLabel ?? label,
          active: active,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _DatingLoadingState extends StatelessWidget {
  const _DatingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: BbV5Card(
        padding: EdgeInsets.all(24),
        radius: 24,
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

class _DatingEmptyState extends StatelessWidget {
  const _DatingEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BbV5Card(
        padding: const EdgeInsets.all(28),
        radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: BbV5Colors.terra),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: bbV5DisplayStyle(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySoft.copyWith(
                color: BbV5Colors.inkMute,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum DatingSwipeDirection { pass, like }

class _SwipeableDatingCard extends StatefulWidget {
  const _SwipeableDatingCard({
    required this.child,
    required this.onSwipe,
    super.key,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;
  final void Function(DatingSwipeDirection direction) onSwipe;

  @override
  State<_SwipeableDatingCard> createState() => _SwipeableDatingCardState();
}

class _SwipeableDatingCardState extends State<_SwipeableDatingCard> {
  final ValueNotifier<double> _dragDx = ValueNotifier<double>(0);

  @override
  void didUpdateWidget(covariant _SwipeableDatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _dragDx.value = 0;
    }
    if (!widget.enabled && _dragDx.value != 0) {
      _dragDx.value = 0;
    }
  }

  @override
  void dispose() {
    _dragDx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxVisualDx =
            (constraints.maxWidth * 0.34).clamp(96.0, 132.0).toDouble();
        final swipeThreshold = (maxVisualDx * 0.75).clamp(72.0, 110.0);

        return GestureDetector(
          onHorizontalDragUpdate: widget.enabled
              ? (details) => _handleDragUpdate(details, maxVisualDx)
              : null,
          onHorizontalDragEnd:
              widget.enabled ? (_) => _handleDragEnd(swipeThreshold) : null,
          onHorizontalDragCancel: widget.enabled ? _resetDrag : null,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragDx,
            child: KeyedSubtree(
              key: const ValueKey('dating-swipeable-card-surface'),
              child: RepaintBoundary(child: widget.child),
            ),
            builder: (context, dx, child) {
              final direction = dx == 0
                  ? null
                  : dx > 0
                      ? DatingSwipeDirection.like
                      : DatingSwipeDirection.pass;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(dx, 0, 0, 1)
                  ..rotateZ(dx / 1800),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child!,
                    if (direction != null)
                      Positioned(
                        top: 26,
                        right:
                            direction == DatingSwipeDirection.like ? 26 : null,
                        left:
                            direction == DatingSwipeDirection.pass ? 26 : null,
                        child: _SwipeDecisionPill(direction: direction),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxVisualDx) {
    final next = (_dragDx.value + details.delta.dx)
        .clamp(-maxVisualDx, maxVisualDx)
        .toDouble();
    if (next != _dragDx.value) {
      _dragDx.value = next;
    }
  }

  void _handleDragEnd(double threshold) {
    final dx = _dragDx.value;
    final direction = dx >= threshold
        ? DatingSwipeDirection.like
        : dx <= -threshold
            ? DatingSwipeDirection.pass
            : null;

    _resetDrag();

    if (direction != null) {
      widget.onSwipe(direction);
    }
  }

  void _resetDrag() {
    if (_dragDx.value != 0) {
      _dragDx.value = 0;
    }
  }
}

class _DatingProfileCard extends StatelessWidget {
  const _DatingProfileCard({
    required this.profile,
    required this.saved,
    required this.photoIndex,
    required this.actionsEnabled,
    required this.onPreviousPhoto,
    required this.onNextPhoto,
    required this.onSaveToggle,
    required this.onSkip,
    required this.onSuper,
    required this.onLike,
    super.key,
  });

  final DatingProfileData profile;
  final bool saved;
  final int photoIndex;
  final bool actionsEnabled;
  final VoidCallback? onPreviousPhoto;
  final VoidCallback? onNextPhoto;
  final VoidCallback onSaveToggle;
  final VoidCallback onSkip;
  final VoidCallback onSuper;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final photos = profile.photos.isNotEmpty
        ? profile.photos
        : profile.avatarUrl == null || profile.avatarUrl!.isEmpty
            ? const <ProfilePhoto>[]
            : [
                ProfilePhoto(
                  id: '${profile.userId}-avatar',
                  url: profile.avatarUrl!,
                  order: 0,
                ),
              ];
    final clampedPhotoIndex =
        photos.isEmpty ? 0 : photoIndex.clamp(0, photos.length - 1);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BbV5Colors.paperHi, BbV5Colors.paper],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.74,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BbProfilePhotoImage(
                    imageUrl: photos.isEmpty
                        ? null
                        : photos[clampedPhotoIndex]
                            .bestUrlFor(BbImageUsageProfile.hero),
                    fallbackText: profile.photoEmoji,
                    usageProfile: BbImageUsageProfile.hero,
                    fallbackFontSize: 80,
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 112,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x59000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.34, 0.62, 1],
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x73000000),
                          Color(0xB3000000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: onPreviousPhoto,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          key: const ValueKey('dating-photo-next-zone'),
                          behavior: HitTestBehavior.translucent,
                          onTap: onNextPhoto,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: BbV5Colors.paperHi.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(BbV5Radii.pill),
                          border: Border.all(color: BbV5Colors.hair),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.sparkles,
                              size: 12,
                              color: BbV5Colors.terra,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Дейтинг',
                              style: AppTextStyles.caption.copyWith(
                                color: BbV5Colors.ink,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.84,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: 'Сохранить',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onSaveToggle,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: BbV5Colors.paperHi.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              border: Border.all(color: BbV5Colors.hair),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              saved
                                  ? Icons.bookmark_rounded
                                  : LucideIcons.bookmark,
                              size: 16,
                              color: saved ? BbV5Colors.terra : BbV5Colors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 96,
                  child: _DatingPhotoInfoOverlay(profile: profile),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CircleActionButton(
                        semanticsLabel: 'Пропустить',
                        icon: LucideIcons.x,
                        onTap: actionsEnabled ? onSkip : null,
                      ),
                      const SizedBox(width: 12),
                      _CircleActionButton(
                        semanticsLabel: 'Супер',
                        icon: LucideIcons.star,
                        size: _CircleActionSize.large,
                        tone: _CircleActionTone.gold,
                        onTap: actionsEnabled ? onSuper : null,
                      ),
                      const SizedBox(width: 12),
                      _CircleActionButton(
                        semanticsLabel: 'Лайк',
                        icon: LucideIcons.heart,
                        size: _CircleActionSize.extraLarge,
                        tone: _CircleActionTone.like,
                        fillIcon: true,
                        onTap: actionsEnabled ? onLike : null,
                      ),
                      const SizedBox(width: 12),
                      _CircleActionButton(
                        semanticsLabel: 'Сохранить',
                        icon: saved
                            ? Icons.bookmark_rounded
                            : LucideIcons.bookmark,
                        fillIcon: saved,
                        onTap: actionsEnabled ? onSaveToggle : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '“',
                        style: bbV5DisplayStyle(
                          fontSize: 16,
                          color: BbV5Colors.terra,
                          height: 1,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySoft.copyWith(
                          color: BbV5Colors.inkSoft,
                          fontSize: 12.5,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatingPhotoInfoOverlay extends StatelessWidget {
  const _DatingPhotoInfoOverlay({required this.profile});

  static const _defaultLanguage = DatingLanguageData(
    flag: '🇷🇺',
    label: 'Русский',
  );
  static const _defaultNationality = DatingLanguageData(
    flag: '🇷🇺',
    label: 'Россия',
  );

  final DatingProfileData profile;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel(profile);
    final languages = profile.languages
        .where(
            (language) => language.flag.isNotEmpty || language.label.isNotEmpty)
        .toList(growable: false);
    final visibleLanguages =
        (languages.isEmpty ? const [_defaultLanguage] : languages)
            .take(2)
            .toList(growable: false);
    final extraLanguages =
        (languages.isEmpty ? 1 : languages.length) - visibleLanguages.length;
    final nationality = profile.nationality ?? _defaultNationality;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.map_pin, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.meta.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          profile.age == null
              ? profile.name
              : '${profile.name}, ${profile.age}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.screenTitle.copyWith(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: -0.56,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          profile.about,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.meta.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12.5,
            height: 1.375,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _GlassPill(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.languages,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _languageLabel(visibleLanguages, extraLanguages),
                    style: AppTextStyles.meta.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _GlassPill(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text(
                '${nationality.flag} ${nationality.label}'.trim(),
                style: AppTextStyles.meta.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...profile.tags.take(2).map(
                  (tag) => _GlassPill(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      '#$tag',
                      style: AppTextStyles.meta.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  static String _locationLabel(DatingProfileData profile) {
    final city = _firstText([profile.city, 'Москва']);
    final distance = _firstText([profile.distance, 'Рядом']);
    return '$city · $distance';
  }

  static String _firstText(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static String _languageLabel(
    List<DatingLanguageData> languages,
    int extraLanguages,
  ) {
    final flags = languages
        .map((language) => language.flag)
        .where((flag) => flag.isNotEmpty)
        .join(' ');
    final firstLabel = languages.firstOrNull?.label ?? '';
    final base =
        [flags, firstLabel].where((part) => part.trim().isNotEmpty).join(' ');
    if (extraLanguages <= 0) {
      return base;
    }
    return '$base +$extraLanguages';
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.child,
    required this.height,
    required this.padding,
  });

  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

enum _CircleActionTone { ghost, gold, like }

enum _CircleActionSize { medium, large, extraLarge }

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.semanticsLabel,
    required this.icon,
    required this.onTap,
    this.tone = _CircleActionTone.ghost,
    this.size = _CircleActionSize.medium,
    this.fillIcon = false,
  });

  final String semanticsLabel;
  final IconData icon;
  final VoidCallback? onTap;
  final _CircleActionTone tone;
  final _CircleActionSize size;
  final bool fillIcon;

  @override
  Widget build(BuildContext context) {
    final dimension = switch (size) {
      _CircleActionSize.medium => 48.0,
      _CircleActionSize.large => 56.0,
      _CircleActionSize.extraLarge => 68.0,
    };
    final iconSize = switch (size) {
      _CircleActionSize.medium => 20.0,
      _CircleActionSize.large => 21.0,
      _CircleActionSize.extraLarge => 25.0,
    };
    final background = switch (tone) {
      _CircleActionTone.ghost => BbV5Colors.paperHi.withValues(alpha: 0.95),
      _CircleActionTone.gold => BbV5Colors.paperHi,
      _CircleActionTone.like => BbV5Colors.accent,
    };
    final foreground = switch (tone) {
      _CircleActionTone.ghost => BbV5Colors.ink,
      _CircleActionTone.gold => BbV5Colors.gold,
      _CircleActionTone.like => BbV5Colors.paperHi,
    };
    final border = switch (tone) {
      _CircleActionTone.ghost => BbV5Colors.hair,
      _CircleActionTone.gold => BbV5Colors.gold.withValues(alpha: 0.35),
      _CircleActionTone.like => Colors.white.withValues(alpha: 0.4),
    };
    final shadows = switch (tone) {
      _CircleActionTone.ghost => const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            spreadRadius: -8,
            offset: Offset(0, 12),
          ),
        ],
      _CircleActionTone.gold => [
          BoxShadow(
            color: BbV5Colors.gold.withValues(alpha: 0.55),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      _CircleActionTone.like => const [
          BoxShadow(
            color: Color(0xCCB26F4A),
            blurRadius: 32,
            spreadRadius: -8,
            offset: Offset(0, 16),
          ),
        ],
    };

    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: dimension,
          height: dimension,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: border),
            boxShadow: shadows,
            gradient: tone == _CircleActionTone.like
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [BbV5Colors.terra, BbV5Colors.accentDeep],
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize,
            color: foreground,
            fill: fillIcon ? 1 : 0,
          ),
        ),
      ),
    );
  }
}

class _DatingThumbnail extends StatelessWidget {
  const _DatingThumbnail({
    required this.profile,
  });

  final DatingProfileData profile;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.primaryPhoto
            ?.bestUrlFor(BbImageUsageProfile.avatar) ??
        profile.photos.firstOrNull?.bestUrlFor(BbImageUsageProfile.avatar) ??
        profile.avatarUrl;

    return BbProfilePhotoImage(
      imageUrl: imageUrl,
      fallbackText: profile.photoEmoji,
      usageProfile: BbImageUsageProfile.avatar,
      fallbackFontSize: 24,
    );
  }
}

class _SwipeDecisionPill extends StatelessWidget {
  const _SwipeDecisionPill({
    required this.direction,
  });

  final DatingSwipeDirection direction;

  @override
  Widget build(BuildContext context) {
    final isLike = direction == DatingSwipeDirection.like;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLike
            ? BbV5Colors.accent.withValues(alpha: 0.92)
            : BbV5Colors.paperHi.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLike ? 'Лайк' : 'Пропустить',
        style: AppTextStyles.meta.copyWith(
          color: isLike ? BbV5Colors.paperHi : BbV5Colors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
