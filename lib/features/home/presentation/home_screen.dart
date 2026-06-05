import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/communities/application/community_access.dart';
import 'package:mobile2/features/giveaways/presentation/giveaway_teaser.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_highlight_text.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_refresh_indicator.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';
import 'package:mobile2/shared/widgets/dateasy_top_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({this.initialHomeTab = 0, super.key});

  final int initialHomeTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _activeChip = 0;
  late int _activeHomeTab;

  @override
  void initState() {
    super.initState();
    _activeHomeTab = widget.initialHomeTab;
  }

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: Stack(
        children: [
          DateasyRefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 16,
                bottom: 144,
              ),
              children: [
                const DateasyTopBar(),
                const _Greeting(),
                _HomeSegmentedControl(
                  active: _activeHomeTab,
                  onChanged: (value) => setState(() => _activeHomeTab = value),
                ),
                if (_activeHomeTab == 0) ...[
                  _Chips(
                    active: _activeChip,
                    onChanged: (index) => setState(() => _activeChip = index),
                  ),
                  const _RadarCard(),
                  const GiveawayTeaser(),
                  _MeetingsList(query: _chips[_activeChip].query),
                  const _Posters(),
                  const _AiBuilder(),
                ] else
                  const _HomeCommunitiesFeed(),
              ],
            ),
          ),
          const DateasyBottomNav(),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(homeEventsProvider);
    ref.invalidate(homeEventsQueryProvider);
    ref.invalidate(postersProvider);
    ref.invalidate(communitiesProvider);
  }
}

class _HomeSegmentedControl extends StatelessWidget {
  const _HomeSegmentedControl({
    required this.active,
    required this.onChanged,
  });

  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DateasyColors.border),
        ),
        child: Row(
          children: [
            _HomeSegmentButton(
              label: 'Для тебя',
              active: active == 0,
              onTap: () => onChanged(0),
            ),
            _HomeSegmentButton(
              label: 'Сообщества',
              active: active == 1,
              onTap: () => onChanged(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSegmentButton extends StatelessWidget {
  const _HomeSegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? dateasyLimeGradient : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: active
                      ? DateasyColors.backgroundDeep
                      : DateasyColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(
      currentUserProvider.select((user) => user?.name.split(' ').first),
    );
    final headline = Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 34,
          height: 1.05,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null || name.isEmpty ? 'Привет' : 'Привет, $name 👋',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DateasyColors.muted,
                ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Найди свою '),
                dateasyHeadlineHighlightSpan(
                  text: 'встречу',
                  style: headline,
                ),
              ],
            ),
            style: headline,
          ),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.active,
    required this.onChanged,
  });

  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final chip = _chips[index];
          final isActive = index == active;
          return _ChipButton(
            label: chip.label,
            active: isActive,
            onTap: () => onChanged(index),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _chips.length,
      ),
    );
  }
}

class _RadarCard extends ConsumerStatefulWidget {
  const _RadarCard();

  @override
  ConsumerState<_RadarCard> createState() => _RadarCardState();
}

class _RadarCardState extends ConsumerState<_RadarCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.of(context).disableAnimations || _isAutomatedWidgetTest;
    if (disableAnimations) {
      _pulseController.stop();
      _floatController.stop();
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
      if (!_floatController.isAnimating) {
        _floatController.repeat();
      }
    }
  }

  bool get _isAutomatedWidgetTest {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('TestWidgetsFlutterBinding');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    const nearbyLabel = 'Встречи рядом';
    final locationLabel = user?.city == null || user!.city!.isEmpty
        ? 'Радар встреч'
        : 'Радар встреч · ${user.city}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        key: const Key('home-radar-card'),
        constraints: const BoxConstraints(minHeight: 250),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [DateasyColors.surface2, DateasyColors.background],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 40,
              spreadRadius: -16,
              offset: Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            color: DateasyColors.muted,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: DateasyColors.muted,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nearbyLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                _LimePillButton(
                  label: 'Открыть',
                  onTap: () => context.go('/map'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final inset in [0.0, 34.0, 68.0, 102.0])
                      Positioned.fill(
                        left: inset,
                        top: inset,
                        right: inset,
                        bottom: inset,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 178,
                      height: 178,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DateasyColors.lime.withValues(alpha: 0.08),
                        boxShadow: [
                          BoxShadow(
                            color: DateasyColors.lime.withValues(alpha: 0.16),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    _RadarPulse(animation: _pulseController),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DateasyColors.lime.withValues(alpha: 0.12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/map'),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: dateasyLimeGradient,
                          boxShadow: _activeShadow,
                        ),
                        child: const Icon(
                          LucideIcons.users,
                          color: DateasyColors.backgroundDeep,
                          size: 20,
                        ),
                      ),
                    ),
                    for (final item in _radarMockIcons)
                      _RadarMockIcon(
                        item: item,
                        animation: _floatController,
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

class _RadarPulse extends StatelessWidget {
  const _RadarPulse({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = Curves.easeOut.transform(animation.value);
        final scale = lerpDouble(0.6, 1.6, value)!;
        final opacity = lerpDouble(0.6, 0, value)!;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DateasyColors.lime.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _MeetingsList extends ConsumerWidget {
  const _MeetingsList({required this.query});

  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetings = ref.watch(
      homeEventsQueryProvider(
        EventListQuery(query: query, sort: 'time', limit: 5),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        children: [
          _SectionHeader(
            title: 'Ближайшие встречи',
            action: 'Все',
            onTap: () => context.go('/meetings'),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (_) {
              final page = meetings.valueOrNull;
              if (page != null) {
                if (page.items.isEmpty) {
                  return const _InlineState(text: 'Пока нет встреч рядом');
                }
                final items = page.items.take(5).toList(growable: false);
                unawaited(
                  ref.read(appMediaPrewarmServiceProvider).warmRemoteImages(
                        homeMeetingPrewarmAvatarUrls(items),
                        usage: DateasyImageUsage.avatar,
                        limit: 5,
                        concurrency: 2,
                      ),
                );
                return Column(
                  children: [
                    for (final item in items) ...[
                      _MeetingTile(meeting: _Meeting.fromBackend(item)),
                      if (item != items.last) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              if (meetings.isLoading) {
                return const _InlineState(text: 'Загружаю встречи');
              }
              return const _InlineState(text: 'Не удалось обновить');
            },
          ),
        ],
      ),
    );
  }
}

class _Posters extends ConsumerWidget {
  const _Posters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posters = ref.watch(postersProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SectionHeader(
              title: 'Афиша',
              action: 'Все события',
              onTap: () => context.go('/posters'),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (_) {
              final page = posters.valueOrNull;
              if (page != null) {
                if (page.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _InlineState(text: 'Афиша пока пустая'),
                  );
                }
                final items = page.items.take(8).toList(growable: false);
                unawaited(
                  ref.read(appMediaPrewarmServiceProvider).warmRemoteImages(
                        items.map(_cardImageUrlForPrewarm),
                        usage: DateasyImageUsage.card,
                        limit: 8,
                        concurrency: 2,
                      ),
                );
                return SizedBox(
                  height: 290,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _PosterCard(poster: items[index]);
                    },
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _InlineState(
                  text:
                      posters.isLoading ? 'Загружаю афишу' : 'Афиша недоступна',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiBuilder extends StatelessWidget {
  const _AiBuilder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: GestureDetector(
        onTap: () => context.go('/ai-builder'),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: dateasyLimeGradient,
            boxShadow: _activeShadow,
          ),
          child: Stack(
            children: [
              const Positioned(
                right: -64,
                top: -64,
                child: _SoftCardGlow(size: 224, opacity: 0.30),
              ),
              const Positioned(
                left: -40,
                bottom: -64,
                child: _SoftCardGlow(size: 160, opacity: 0.20),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          LucideIcons.sparkles,
                          size: 16,
                          color: DateasyColors.backgroundDeep,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AI DATE BUILDER',
                          style: TextStyle(
                            color: DateasyColors.backgroundDeep,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Соберём идеальную\nвстречу за 30 секунд',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: DateasyColors.backgroundDeep,
                                fontSize: 28,
                                height: 1.05,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        'Опиши вайб одним предложением — AI подберёт место, время и компанию рядом.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DateasyColors.backgroundDeep
                                  .withValues(alpha: 0.8),
                              height: 1.25,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: DateasyColors.foreground,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.wand,
                                  size: 16,
                                  color: DateasyColors.background,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Открыть билдер',
                                  style: TextStyle(
                                    color: DateasyColors.background,
                                    fontSize: 16,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                DateasyColors.background.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.arrowRight,
                            color: DateasyColors.foreground,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCommunitiesFeed extends ConsumerStatefulWidget {
  const _HomeCommunitiesFeed();

  @override
  ConsumerState<_HomeCommunitiesFeed> createState() =>
      _HomeCommunitiesFeedState();
}

class _HomeCommunitiesFeedState extends ConsumerState<_HomeCommunitiesFeed> {
  final _searchController = TextEditingController();
  final Set<String> _topics = <String>{};
  bool _filtersOpen = false;
  String _query = '';
  String _sort = 'popular';
  String? _privacy;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      _topics.length +
      (_privacy == null ? 0 : 1) +
      (_sort == 'popular' ? 0 : 1);

  bool get _hasActiveQueryOrFilters =>
      _query.isNotEmpty ||
      _topics.isNotEmpty ||
      _privacy != null ||
      _sort != 'popular';

  CommunityListQuery get _communityQuery => CommunityListQuery(
        q: _query.isEmpty ? null : _query,
        topics: _topics.toList(growable: false)..sort(),
        privacy: _privacy,
        sort: _sort,
      );

  @override
  Widget build(BuildContext context) {
    final communities = _hasActiveQueryOrFilters
        ? ref.watch(communitiesQueryProvider(_communityQuery))
        : ref.watch(communitiesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeCommunityHeader(onCreateTap: () => _openHomeCommunityCreate()),
          const SizedBox(height: 14),
          _HomeCommunitySearchBar(controller: _searchController),
          const SizedBox(height: 12),
          _HomeCommunitySortAndFilter(
            sort: _sort,
            filtersOpen: _filtersOpen,
            activeCount: _activeFilterCount,
            onSortChanged: (value) => setState(() => _sort = value),
            onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
          if (_filtersOpen) ...[
            const SizedBox(height: 12),
            _HomeCommunityFilterPanel(
              topics: _topics,
              privacy: _privacy,
              onTopicToggled: (topic) {
                setState(() {
                  if (_topics.contains(topic)) {
                    _topics.remove(topic);
                  } else {
                    _topics.add(topic);
                  }
                });
              },
              onPrivacyChanged: (value) => setState(() => _privacy = value),
              onReset: () => setState(() {
                _topics.clear();
                _privacy = null;
                _sort = 'popular';
              }),
            ),
          ],
          const SizedBox(height: 18),
          communities.when(
            data: _buildCommunityContent,
            loading: () => const _InlineState(text: 'Загружаю сообщества'),
            error: (_, __) => const _InlineState(text: 'Сообщества недоступны'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityContent(BackendPage<BackendCardItem> page) {
    if (_hasActiveQueryOrFilters) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Найдено: ${page.items.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          if (page.items.isEmpty)
            const _InlineState(text: 'Ничего не нашли. Попробуй сменить фильтр')
          else
            for (final item in page.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HomeCommunityRow(item: item),
              ),
        ],
      );
    }

    if (page.items.isEmpty) {
      return const _HomeCommunityEmpty();
    }

    final popular = page.items.take(5).toList(growable: false);
    final myItems = page.items
        .where(
            (item) => item.raw['joined'] == true || item.raw['isOwner'] == true)
        .take(4)
        .toList(growable: false);
    final trend = page.items.skip(1).take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: popular.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _HomeCommunityCard(item: popular[index]);
            },
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Мои',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        for (final item in (myItems.isEmpty ? popular.take(2) : myItems))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HomeCommunityRow(item: item),
          ),
        const SizedBox(height: 10),
        Text(
          'В тренде',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        for (final item in trend)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HomeCommunityRow(item: item, compact: true),
          ),
      ],
    );
  }

  Future<void> _openHomeCommunityCreate() async {
    SubscriptionStateData? subscription;
    try {
      subscription = await ref.read(subscriptionProvider.future);
    } catch (_) {
      subscription = null;
    }
    if (!mounted) {
      return;
    }
    if (communityHasFrendlyPlusAccess(subscription)) {
      context.push('/communities/new');
    } else {
      context.push('/paywall');
    }
  }
}

const _homeCommunityTopics = [
  'Вино',
  'Кофе',
  'Бег',
  'Арт',
  'Музыка',
  'Книги',
  'Йога',
  'Кино',
];

class _HomeCommunityHeader extends StatelessWidget {
  const _HomeCommunityHeader({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Сообщества',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  height: 1.12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
        ),
        Semantics(
          label: 'Создать сообщество',
          button: true,
          container: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCreateTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: dateasyLimeGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: DateasyColors.lime.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.plus,
                size: 22,
                color: DateasyColors.backgroundDeep,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeCommunitySearchBar extends StatelessWidget {
  const _HomeCommunitySearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassBox(
      borderRadius: 16,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                LucideIcons.search,
                size: 18,
                color: DateasyColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'Йога, гастро, музыка...',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  cursorColor: DateasyColors.lime,
                ),
              ),
              if (controller.text.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Semantics(
                  label: 'Очистить поиск',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.clear,
                    child: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: DateasyColors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCommunitySortAndFilter extends StatelessWidget {
  const _HomeCommunitySortAndFilter({
    required this.sort,
    required this.filtersOpen,
    required this.activeCount,
    required this.onSortChanged,
    required this.onToggleFilters,
  });

  final String sort;
  final bool filtersOpen;
  final int activeCount;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    final filterActive = filtersOpen || activeCount > 0;
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _HomeCommunityFilterPill(
                  label: 'Популярные',
                  active: sort == 'popular',
                  onTap: () => onSortChanged('popular'),
                ),
                const SizedBox(width: 8),
                _HomeCommunityFilterPill(
                  label: 'Новые',
                  active: sort == 'new',
                  onTap: () => onSortChanged('new'),
                ),
                const SizedBox(width: 8),
                _HomeCommunityFilterPill(
                  label: 'Рядом',
                  active: sort == 'nearby',
                  onTap: () => onSortChanged('nearby'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: 'Фильтры',
          button: true,
          container: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleFilters,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: filterActive ? dateasyLimeGradient : null,
                color: filterActive ? null : DateasyColors.glass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      filterActive ? Colors.transparent : DateasyColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    size: 16,
                    color: filterActive
                        ? DateasyColors.backgroundDeep
                        : DateasyColors.foreground,
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 7),
                    Text(
                      '$activeCount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.backgroundDeep,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeCommunityFilterPanel extends StatelessWidget {
  const _HomeCommunityFilterPanel({
    required this.topics,
    required this.privacy,
    required this.onTopicToggled,
    required this.onPrivacyChanged,
    required this.onReset,
  });

  final Set<String> topics;
  final String? privacy;
  final ValueChanged<String> onTopicToggled;
  final ValueChanged<String?> onPrivacyChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _GlassBox(
      borderRadius: 18,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HomeCommunityFilterLabel(text: 'Темы'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in _homeCommunityTopics)
                  _HomeCommunityFilterPill(
                    label: topic,
                    active: topics.contains(topic),
                    onTap: () => onTopicToggled(topic),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const _HomeCommunityFilterLabel(text: 'Тип'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HomeCommunityFilterPill(
                  label: 'Все',
                  active: privacy == null,
                  onTap: () => onPrivacyChanged(null),
                ),
                _HomeCommunityFilterPill(
                  label: 'Открытые',
                  active: privacy == 'public',
                  onTap: () => onPrivacyChanged('public'),
                ),
                _HomeCommunityFilterPill(
                  label: 'Закрытые',
                  active: privacy == 'private',
                  onTap: () => onPrivacyChanged('private'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReset,
              child: Text(
                'Сбросить',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DateasyColors.lime,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCommunityFilterPill extends StatelessWidget {
  const _HomeCommunityFilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active ? dateasyLimeGradient : null,
          color: active ? null : DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.transparent : DateasyColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: active
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _HomeCommunityFilterLabel extends StatelessWidget {
  const _HomeCommunityFilterLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DateasyColors.muted,
            fontSize: 11,
            letterSpacing: 1.1,
          ),
    );
  }
}

class _HomeCommunityCard extends StatelessWidget {
  const _HomeCommunityCard({required this.item});

  final BackendCardItem item;

  @override
  Widget build(BuildContext context) {
    final members = _extractCommunityMembers(item.raw);
    return GestureDetector(
      onTap: () => context.push('/communities/${item.id}'),
      child: Container(
        width: 176,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: DateasyColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DateasyRemoteImage(
              imageUrl: item.imageUrl,
              usage: DateasyImageUsage.card,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? 'Сообщество' : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$members участников',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCommunityRow extends StatelessWidget {
  const _HomeCommunityRow({
    required this.item,
    this.compact = false,
  });

  final BackendCardItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final members = _extractCommunityMembers(item.raw);
    return GestureDetector(
      onTap: () => context.push('/communities/${item.id}'),
      child: _GlassBox(
        borderRadius: 18,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: compact ? 40 : 48,
                  height: compact ? 40 : 48,
                  child: DateasyRemoteImage(
                    imageUrl: item.imageUrl,
                    usage: DateasyImageUsage.avatar,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? 'Сообщество' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      compact ? 'тренд недели' : '$members участников',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 17,
                color: DateasyColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCommunityEmpty extends StatelessWidget {
  const _HomeCommunityEmpty();

  @override
  Widget build(BuildContext context) {
    return _GlassBox(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Сообществ пока нет',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}

class _SoftCardGlow extends StatelessWidget {
  const _SoftCardGlow({
    required this.size,
    required this.opacity,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? DateasyColors.foreground : DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label,
          style: TextStyle(
            color: active ? DateasyColors.background : DateasyColors.foreground,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LimePillButton extends StatelessWidget {
  const _LimePillButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          gradient: dateasyLimeGradient,
          boxShadow: _activeShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: DateasyColors.backgroundDeep,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RadarMockIcon extends StatelessWidget {
  const _RadarMockIcon({
    required this.item,
    required this.animation,
  });

  final _RadarMockIconData item;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(
          (animation.value + item.floatOffset) % 1,
        );
        final dy = lerpDouble(0, -6, value <= 0.5 ? value * 2 : 2 - value * 2)!;
        return Align(
          alignment: item.alignment,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: Container(
        key: Key('home-radar-mock-icon-${item.key}'),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: DateasyColors.background, width: 4),
          boxShadow: [
            BoxShadow(color: item.ring, spreadRadius: 2),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: item.gradient,
          ),
          child: Icon(
            item.icon,
            color: DateasyColors.backgroundDeep,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _RadarMockIconData {
  const _RadarMockIconData({
    required this.key,
    required this.icon,
    required this.alignment,
    required this.ring,
    required this.gradient,
    this.floatOffset = 0,
  });

  final String key;
  final IconData icon;
  final Alignment alignment;
  final Color ring;
  final Gradient gradient;
  final double floatOffset;
}

const _radarMockIcons = [
  _RadarMockIconData(
    key: 'wine',
    icon: LucideIcons.wine,
    alignment: Alignment(-0.44, -0.56),
    ring: DateasyColors.pink,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [DateasyColors.pink, DateasyColors.lilac],
    ),
  ),
  _RadarMockIconData(
    key: 'music',
    icon: LucideIcons.music2,
    alignment: Alignment(0.54, 0.18),
    ring: DateasyColors.lime,
    gradient: dateasyLimeGradient,
    floatOffset: 0.18,
  ),
  _RadarMockIconData(
    key: 'coffee',
    icon: LucideIcons.coffee,
    alignment: Alignment(-0.40, 0.42),
    ring: DateasyColors.lilac,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [DateasyColors.lilac, DateasyColors.surface2],
    ),
    floatOffset: 0.34,
  ),
];

String _peopleWord(int count) {
  final lastTwo = count % 100;
  if (lastTwo >= 11 && lastTwo <= 14) {
    return 'человек';
  }
  return switch (count % 10) {
    1 => 'человек',
    2 || 3 || 4 => 'человека',
    _ => 'человек',
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  height: 1.12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DateasyColors.muted,
                ),
          ),
        ),
      ],
    );
  }
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({required this.meeting});

  final _Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final visiblePeople = meeting.people.take(3).toList(growable: false);
    final extraPeople = (meeting.count - visiblePeople.length).clamp(0, 999);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/meetings/${meeting.id}'),
      child: _GlassBox(
        borderRadius: 24,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: meeting.tone.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${meeting.count}',
                  style: TextStyle(
                    color: meeting.tone.foreground,
                    fontFamily: 'Sora',
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DateasyColors.foreground,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _Meta(
                            icon: LucideIcons.clock,
                            label: meeting.time,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Meta(
                              icon: LucideIcons.mapPin, label: meeting.place),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (visiblePeople.isNotEmpty || extraPeople > 0)
                      Row(
                        children: [
                          if (visiblePeople.isNotEmpty)
                            SizedBox(
                              width: 24.0 + (visiblePeople.length - 1) * 16,
                              height: 24,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (var i = 0; i < visiblePeople.length; i++)
                                    Positioned(
                                      left: i * 16,
                                      child: _SmallAvatar(
                                        imageUrl: visiblePeople[i],
                                        size: 24,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (visiblePeople.isNotEmpty && extraPeople > 0)
                            const SizedBox(width: 8),
                          if (extraPeople > 0)
                            Flexible(
                              child: Text(
                                '+$extraPeople ${_peopleWord(extraPeople)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: DateasyColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.push('/meetings/${meeting.id}'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DateasyColors.foreground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    LucideIcons.arrowUpRight,
                    color: DateasyColors.background,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: DateasyColors.background,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DateasyRemoteImage(
        imageUrl: imageUrl,
        usage: DateasyImageUsage.avatar,
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
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
        Icon(icon, size: 12, color: DateasyColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontSize: 12,
                  height: 1.2,
                ),
          ),
        ),
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.poster});

  final BackendCardItem poster;

  @override
  Widget build(BuildContext context) {
    final event = _Poster.fromBackend(poster);
    return GestureDetector(
      onTap: () => context.push(
        '/posters/${Uri.encodeComponent(event.id)}',
        extra: poster,
      ),
      child: Container(
        width: 230,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 40,
              spreadRadius: -16,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DateasyRemoteImage(
              imageUrl: event.imageUrl,
              imageVariants: event.imageVariants,
              usage: DateasyImageUsage.card,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xCC000000),
                    Color(0x1A000000),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                decoration: const BoxDecoration(
                  color: DateasyColors.lime,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  event.tag.toUpperCase(),
                  style: const TextStyle(
                    color: DateasyColors.backgroundDeep,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Sora',
                      fontSize: 18,
                      height: 1.12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.meta,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _GlassBox(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({
    required this.borderRadius,
    required this.child,
  });

  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

class _Meeting {
  const _Meeting({
    required this.id,
    required this.title,
    required this.time,
    required this.place,
    required this.people,
    required this.count,
    required this.tone,
  });

  final String id;
  final String title;
  final String time;
  final String place;
  final List<String> people;
  final int count;
  final _Tone tone;

  factory _Meeting.fromBackend(BackendCardItem item) {
    return _Meeting(
      id: item.id,
      title: item.title,
      time: _formatDate(item.startsAt),
      place: item.subtitle ?? item.city ?? 'Место уточняется',
      people: _avatarUrls(item.raw),
      count: _extractCount(item.raw),
      tone: _toneLime,
    );
  }
}

List<String> _avatarUrls(Map<String, Object?> raw) {
  for (final source in [
    raw['attendees'],
    raw['participants'],
    raw['members'],
    raw['memberProfiles'],
  ]) {
    final urls = _avatarUrlsFromSource(source);
    if (urls.isNotEmpty) {
      return urls;
    }
  }
  return const [];
}

Iterable<String> homeMeetingPrewarmAvatarUrls(
    List<BackendCardItem> meetings) sync* {
  var emitted = 0;
  for (final meeting in meetings) {
    for (final rawUrl in _avatarUrls(meeting.raw)) {
      if (emitted >= 6) {
        return;
      }
      final url = rawUrl.trim();
      if (url.isEmpty) {
        continue;
      }
      emitted += 1;
      yield url;
    }
  }
}

List<String> _avatarUrlsFromSource(Object? source) {
  if (source is! List) {
    return const [];
  }
  return source
      .whereType<Map>()
      .map((item) {
        final profile = item['profile'];
        final user = item['user'];
        return item['avatarUrl'] ??
            item['photoUrl'] ??
            (profile is Map
                ? profile['avatarUrl'] ?? profile['photoUrl']
                : null) ??
            (user is Map ? user['avatarUrl'] ?? user['photoUrl'] : null);
      })
      .map((value) => value?.toString() ?? '')
      .where((value) => value.isNotEmpty)
      .take(3)
      .toList(growable: false);
}

class _Poster {
  const _Poster({
    required this.id,
    required this.imageUrl,
    required this.imageVariants,
    required this.tag,
    required this.title,
    required this.meta,
  });

  final String id;
  final String? imageUrl;
  final Object? imageVariants;
  final String tag;
  final String title;
  final String meta;

  factory _Poster.fromBackend(BackendCardItem item) {
    return _Poster(
      id: item.id,
      imageUrl: item.imageUrl,
      imageVariants: item.raw['imageVariants'],
      tag: item.city ?? 'event',
      title: item.title,
      meta: _formatDate(item.startsAt),
    );
  }
}

String? _cardImageUrlForPrewarm(BackendCardItem item) {
  return DateasyRemoteImage.resolveVariantImageUrl(
    imageUrl: item.imageUrl,
    imageVariants: item.raw['imageVariants'],
    usage: DateasyImageUsage.card,
  );
}

class _Tone {
  const _Tone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

const _chips = [
  _HomeChip('Все'),
  _HomeChip('Кофе', 'кофе'),
  _HomeChip('Спорт', 'спорт'),
  _HomeChip('Музыка', 'музыка'),
  _HomeChip('Прогулка', 'прогулка'),
  _HomeChip('Бар', 'бар'),
];

class _HomeChip {
  const _HomeChip(this.label, [this.query]);

  final String label;
  final String? query;
}

const _toneLime = _Tone(DateasyColors.lime, DateasyColors.backgroundDeep);

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Время уточняется';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}.${local.month} · $hour:$minute';
}

int _extractCount(Map<String, Object?> raw) {
  final value = raw['going'] ?? raw['participantCount'] ?? raw['joinedCount'];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _extractCommunityMembers(Map<String, Object?> raw) {
  final value = raw['membersCount'] ?? raw['memberCount'];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

const _activeShadow = [
  BoxShadow(
    color: Color(0x59BEFF67),
    blurRadius: 60,
    spreadRadius: -20,
    offset: Offset(0, 20),
  ),
];
