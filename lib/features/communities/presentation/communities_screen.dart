import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/communities/domain/community.dart';
import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/features/communities/presentation/community_widgets.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _clubTagFilters = [
  'ужины',
  'wellness',
  'fine dining',
  'дегустации',
  'афиша',
  'nightlife',
];
const _clubAreaFilters = [
  'Все',
  'Центр',
  'Патрики',
  'Чистые пруды',
  'Тверская',
];

class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _tagFilters = <String>{};
  String _areaFilter = 'Все';
  String _privacyFilter = 'all';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(communitiesFeedProvider);
    final subscription = ref.watch(subscriptionStateProvider).valueOrNull;
    final canCreate = hasFrendlyPlusAccess(subscription);

    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
        child: Column(
          children: [
            _ClubsHeader(
              onBack: () => _handleBack(context),
              onCreate: () => _openCreate(context, canCreate),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BbV5SearchPill(
                    controller: _searchController,
                    hintText: 'Найти клуб или интерес…',
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    BbV5IconButton(
                      icon: LucideIcons.list_filter,
                      onPressed: () => _openFilters(
                        context,
                        communitiesAsync.asData?.value.items ??
                            const <Community>[],
                      ),
                    ),
                    if (_filtersActive)
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
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: communitiesAsync.when(
                data: (feedState) {
                  final filtered = _filterCommunities(feedState.items);
                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis != Axis.vertical) {
                        return false;
                      }

                      final distanceToBottom =
                          notification.metrics.maxScrollExtent -
                              notification.metrics.pixels;
                      if (distanceToBottom <= 600) {
                        ref
                            .read(communitiesFeedProvider.notifier)
                            .loadNextPage();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      cacheExtent: 2000,
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
                      itemCount: _communityFeedItemCount(
                        feedState,
                        filtered.length,
                      ),
                      itemBuilder: (context, index) {
                        final contentCount =
                            filtered.isEmpty ? 1 : filtered.length * 2;
                        if (index >= 4 + contentCount) {
                          return _CommunitiesPaginationFooter(
                            feedState: feedState,
                            onRetry: () => ref
                                .read(communitiesFeedProvider.notifier)
                                .loadNextPage(),
                          );
                        }

                        return switch (index) {
                          0 => _CommunitiesHeroCard(
                              communities: feedState.items,
                            ),
                          1 => const SizedBox(height: 24),
                          2 => _CommunitiesSectionHeader(
                              count: filtered.length,
                              filtersActive: _filtersActive,
                              onReset: _resetFilters,
                            ),
                          3 => const SizedBox(height: 12),
                          4 when filtered.isEmpty => const _CommunitiesEmpty(),
                          _ => _CommunityFeedListItem(
                              index: index - 4,
                              communities: filtered,
                            ),
                        };
                      },
                    ),
                  );
                },
                loading: () => const _CommunitiesLoading(),
                error: (_, __) => const _CommunitiesError(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) async {
    final popped = await Navigator.of(context).maybePop();
    if (!popped && context.mounted) {
      context.goRoute(AppRoute.tonight);
    }
  }

  void _openCreate(BuildContext context, bool canCreate) {
    if (canCreate) {
      context.pushRoute(AppRoute.createCommunity);
      return;
    }

    context.pushRoute(AppRoute.paywall);
  }

  List<Community> _filterCommunities(List<Community> communities) {
    final query = _query.trim().toLowerCase();
    return communities.where((community) {
      if (query.isNotEmpty) {
        final haystack = [
          community.name,
          community.description,
          community.tags.join(' '),
          community.mood,
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }

      if (_privacyFilter == 'public' &&
          community.privacy != CommunityPrivacy.public) {
        return false;
      }
      if (_privacyFilter == 'private' &&
          community.privacy != CommunityPrivacy.private) {
        return false;
      }

      if (_tagFilters.isNotEmpty) {
        final tags = community.tags.map((tag) => tag.toLowerCase()).toSet();
        final hasTag = _tagFilters.any(
          (tag) => tags.contains(tag.toLowerCase()),
        );
        if (!hasTag) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  bool get _filtersActive {
    return _query.trim().isNotEmpty ||
        _tagFilters.isNotEmpty ||
        _areaFilter != 'Все' ||
        _privacyFilter != 'all';
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _tagFilters.clear();
      _areaFilter = 'Все';
      _privacyFilter = 'all';
    });
  }

  void _openFilters(BuildContext context, List<Community> communities) {
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
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BbV5Kicker('Фильтры клубов'),
                                    SizedBox(height: 3),
                                    BbV5HeroTitle(
                                      title: 'Подобрать под себя',
                                      fontSize: 18,
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
                          const SizedBox(height: 20),
                          const BbV5Kicker('Доступ'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              BbV5Chip(
                                label: 'Все',
                                active: _privacyFilter == 'all',
                                onTap: () => update(() {
                                  _privacyFilter = 'all';
                                }),
                              ),
                              BbV5Chip(
                                label: 'Открытые',
                                active: _privacyFilter == 'public',
                                onTap: () => update(() {
                                  _privacyFilter = 'public';
                                }),
                              ),
                              BbV5Chip(
                                label: 'Закрытые',
                                active: _privacyFilter == 'private',
                                onTap: () => update(() {
                                  _privacyFilter = 'private';
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const BbV5Kicker('Район'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _clubAreaFilters
                                .map(
                                  (area) => BbV5Chip(
                                    label: area,
                                    active: _areaFilter == area,
                                    onTap: () => update(() {
                                      _areaFilter = area;
                                    }),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 18),
                          const BbV5Kicker('Интересы'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _clubTagFilters
                                .map(
                                  (tag) => BbV5Chip(
                                    label: '#$tag',
                                    active: _tagFilters.contains(tag),
                                    onTap: () => update(() {
                                      if (_tagFilters.contains(tag)) {
                                        _tagFilters.remove(tag);
                                      } else {
                                        _tagFilters.add(tag);
                                      }
                                    }),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 20),
                          BbV5PillButton(
                            label:
                                'Показать ${_filterCommunities(communities).length}',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            dark: true,
                            height: 48,
                            fontSize: 13,
                            expanded: true,
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
}

int _communityFeedItemCount(
  CommunitiesFeedState feedState,
  int visibleCount,
) {
  final hasFooter = feedState.hasMore ||
      feedState.loadingMore ||
      feedState.loadMoreError != null;
  final contentCount = visibleCount == 0 ? 1 : visibleCount * 2;
  return 4 + contentCount + (hasFooter ? 1 : 0);
}

class _ClubsHeader extends StatelessWidget {
  const _ClubsHeader({
    required this.onBack,
    required this.onCreate,
  });

  final VoidCallback onBack;
  final VoidCallback onCreate;

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
              BbV5Kicker('Frendly+ · Клубы'),
              SizedBox(height: 3),
              _ClubsHeaderTitle(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        BbV5IconButton(
          icon: LucideIcons.plus,
          onPressed: onCreate,
          dark: true,
          iconSize: 18,
        ),
      ],
    );
  }
}

class _ClubsHeaderTitle extends StatelessWidget {
  const _ClubsHeaderTitle();

  @override
  Widget build(BuildContext context) {
    final base = bbV5DisplayStyle(fontSize: 22, height: 1.25);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Сообщества '),
          TextSpan(
            text: 'города',
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}

class _CommunitiesHeroCard extends StatelessWidget {
  const _CommunitiesHeroCard({
    required this.communities,
  });

  final List<Community> communities;

  @override
  Widget build(BuildContext context) {
    final totalMembers = communities.fold<int>(
      0,
      (sum, community) => sum + community.members,
    );
    final onlineNow = communities.fold<int>(
      0,
      (sum, community) => sum + community.online,
    );

    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BbV5Kicker('Новый сервис'),
                    SizedBox(height: 6),
                    _CommunitiesHeroTitle(),
                  ],
                ),
              ),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
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
                    const SizedBox(width: 5),
                    Text(
                      'FRENDLY+',
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.terra,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CommunityHeroStat(
                  icon: LucideIcons.users,
                  value: '$totalMembers',
                  label: 'участников',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CommunityHeroStat(
                  icon: LucideIcons.sparkles,
                  value: '$onlineNow',
                  label: 'онлайн',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CommunityHeroStat(
                  icon: LucideIcons.calendar,
                  value: '${communities.length}',
                  label: 'клуба',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunitiesHeroTitle extends StatelessWidget {
  const _CommunitiesHeroTitle();

  @override
  Widget build(BuildContext context) {
    final base = bbV5DisplayStyle(fontSize: 19, height: 1.25);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Клубы, чаты и встречи\n'),
          TextSpan(
            text: 'в одном месте',
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}

class _CommunityHeroStat extends StatelessWidget {
  const _CommunityHeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: BbV5Colors.inkMute),
          const SizedBox(height: 8),
          Text(
            value,
            style: bbV5DisplayStyle(fontSize: 18, height: 1).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 10,
              letterSpacing: 0.57,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunitiesSectionHeader extends StatelessWidget {
  const _CommunitiesSectionHeader({
    required this.count,
    required this.filtersActive,
    required this.onReset,
  });

  final int count;
  final bool filtersActive;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: BbV5Kicker('$count ${count == 1 ? 'клуб' : 'клубов'}'),
          ),
          if (filtersActive)
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Сбросить',
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkSoft,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommunityFeedListItem extends StatelessWidget {
  const _CommunityFeedListItem({
    required this.index,
    required this.communities,
  });

  final int index;
  final List<Community> communities;

  @override
  Widget build(BuildContext context) {
    if (index.isOdd) {
      return const SizedBox(height: 12);
    }

    return _CommunityListCard(community: communities[index ~/ 2]);
  }
}

class _CommunityListCard extends StatelessWidget {
  const _CommunityListCard({
    required this.community,
  });

  final Community community;

  @override
  Widget build(BuildContext context) {
    final tone = _communityTone(community);

    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pushRoute(
              AppRoute.communityDetail,
              pathParameters: {'communityId': community.id},
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommunityInitialsBox(community: community, tone: tone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            community.name,
                            style:
                                bbV5DisplayStyle(fontSize: 15.5, height: 1.25),
                          ),
                          if (community.privacy == CommunityPrivacy.private)
                            const _CommunityMiniBadge(
                              icon: LucideIcons.lock,
                              label: 'ЗАКРЫТЫЙ',
                              tone: BbV5Colors.inkSoft,
                            ),
                          if (community.premiumOnly)
                            const _CommunityMiniBadge(
                              icon: LucideIcons.crown,
                              label: '+',
                              tone: BbV5Colors.terra,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        community.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySoft.copyWith(
                          color: BbV5Colors.inkMute,
                          fontSize: 11.5,
                          height: 1.375,
                        ),
                      ),
                    ],
                  ),
                ),
                if (community.unread > 0) ...[
                  const SizedBox(width: 8),
                  _CommunityUnreadBadge(count: community.unread),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: BbV5Colors.hairSoft),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  _CommunityMetaPill(
                    icon: LucideIcons.users,
                    label: '${community.members}',
                  ),
                  const SizedBox(width: 12),
                  _CommunityOnlinePill(
                    online: community.online,
                    tone: tone,
                  ),
                  const SizedBox(width: 12),
                  _CommunityMetaPill(
                    icon: LucideIcons.images,
                    label: '${community.media.length}',
                  ),
                  const Spacer(),
                  BbV5PillButton(
                    label: 'Открыть',
                    icon: LucideIcons.chevron_right,
                    onPressed: () => context.pushRoute(
                      AppRoute.communityDetail,
                      pathParameters: {'communityId': community.id},
                    ),
                    dark: true,
                    height: 32,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ],
              ),
            ),
          ),
          if (community.nextMeetup case final meetup?) ...[
            const SizedBox(height: 12),
            _CommunityNextMeetup(
              meetup: meetup,
              tone: tone,
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityInitialsBox extends StatelessWidget {
  const _CommunityInitialsBox({
    required this.community,
    required this.tone,
  });

  final Community community;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BbV5Colors.hair),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: Text(
        _communityInitials(community.name),
        style: bbV5DisplayStyle(
          fontSize: 15,
          color: tone,
          height: 1,
        ),
      ),
    );
  }
}

class _CommunityMiniBadge extends StatelessWidget {
  const _CommunityMiniBadge({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tone),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: tone,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityUnreadBadge extends StatelessWidget {
  const _CommunityUnreadBadge({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: BbV5Colors.accent,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: AppTextStyles.caption.copyWith(
          color: BbV5Colors.paperHi,
          fontFamily: 'Sora',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _CommunityMetaPill extends StatelessWidget {
  const _CommunityMetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: BbV5Colors.inkSoft),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: BbV5Colors.inkSoft,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _CommunityOnlinePill extends StatelessWidget {
  const _CommunityOnlinePill({
    required this.online,
    required this.tone,
  });

  final int online;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: tone,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$online онлайн',
          style: AppTextStyles.caption.copyWith(
            color: BbV5Colors.inkSoft,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _CommunityNextMeetup extends StatelessWidget {
  const _CommunityNextMeetup({
    required this.meetup,
    required this.tone,
  });

  final CommunityMeetupItem meetup;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pushRoute(
        AppRoute.meetupChat,
        pathParameters: {'chatId': meetup.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BbV5Colors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BbV5Colors.hair),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi,
                shape: BoxShape.circle,
                border: Border.all(color: BbV5Colors.hair),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.calendar,
                size: 16,
                color: tone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ближайшая встреча',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bbV5KickerStyle(letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meetup.title} · ${meetup.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta.copyWith(
                      color: BbV5Colors.ink,
                      fontFamily: 'Sora',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${meetup.going} идут',
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.inkSoft,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
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

class _CommunitiesPaginationFooter extends StatelessWidget {
  const _CommunitiesPaginationFooter({
    required this.feedState,
    required this.onRetry,
  });

  final CommunitiesFeedState feedState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (feedState.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: TextButton(
            onPressed: onRetry,
            child: Text(
              'Повторить загрузку',
              style: AppTextStyles.meta.copyWith(color: BbV5Colors.terra),
            ),
          ),
        ),
      );
    }

    if (feedState.loadingMore) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              color: BbV5Colors.ink,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }
}

class _CommunitiesLoading extends StatelessWidget {
  const _CommunitiesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: BbV5Card(
        padding: EdgeInsets.all(24),
        radius: 24,
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

class _CommunitiesError extends StatelessWidget {
  const _CommunitiesError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: BbV5Card(
        padding: EdgeInsets.all(28),
        radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.wifi_off,
              size: 30,
              color: BbV5Colors.terra,
            ),
            SizedBox(height: 12),
            BbV5HeroTitle(
              title: 'Не получилось загрузить сообщества',
              fontSize: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunitiesEmpty extends StatelessWidget {
  const _CommunitiesEmpty();

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(28),
      radius: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.search_x,
            size: 30,
            color: BbV5Colors.terra,
          ),
          const SizedBox(height: 12),
          Text(
            'Ничего не нашли',
            style: bbV5DisplayStyle(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Попробуй другой поиск или сбрось фильтры',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySoft.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

Color _communityTone(Community community) {
  return switch (community.id.hashCode.abs() % 3) {
    0 => BbV5Colors.brand,
    1 => BbV5Colors.terra,
    _ => BbV5Colors.gold,
  };
}

String _communityInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return 'CL';
  }
  return words.take(2).map((word) => word.substring(0, 1)).join().toUpperCase();
}
