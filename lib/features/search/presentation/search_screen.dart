import 'dart:async';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/after_dark/presentation/after_dark_models.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_event_card.dart';
import 'package:big_break_mobile/features/posters/presentation/widgets/poster_card.dart';
import 'package:big_break_mobile/features/search/presentation/search_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_filters.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_social_actions.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:big_break_mobile/shared/widgets/event_filter_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _searchTrending = ['кино', 'йога', 'бранч', 'выставка', 'концерт'];
const _defaultSearchFilters = {'Сегодня'};
const _searchFilters = [
  'Сегодня',
  'Завтра',
  'Бесплатно',
  'Рядом',
  'Спокойно',
  'Активно'
];

enum SearchPreset {
  evenings,
  nearby;

  static SearchPreset? parse(String? value) {
    switch (value) {
      case 'evenings':
        return SearchPreset.evenings;
      case 'nearby':
        return SearchPreset.nearby;
      default:
        return null;
    }
  }

  String get queryValue {
    switch (this) {
      case SearchPreset.evenings:
        return 'evenings';
      case SearchPreset.nearby:
        return 'nearby';
    }
  }

  String get title {
    switch (this) {
      case SearchPreset.evenings:
        return 'Вечера рядом';
      case SearchPreset.nearby:
        return 'Рядом с тобой';
    }
  }

  IconData get icon {
    switch (this) {
      case SearchPreset.evenings:
        return LucideIcons.sparkles;
      case SearchPreset.nearby:
        return LucideIcons.map_pin;
    }
  }

  Set<String> get chips {
    switch (this) {
      case SearchPreset.evenings:
        return const {'Сегодня', 'Live', 'Собираются'};
      case SearchPreset.nearby:
        return const {'Сегодня', 'Рядом'};
    }
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    this.preset,
    super.key,
  });

  final SearchPreset? preset;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  late final Set<String> _active;
  EventFilters _sheetFilters = EventFilters.defaults;
  Timer? _debounce;
  String _debouncedQuery = '';

  bool get _showResults =>
      _controller.text.isNotEmpty ||
      _sheetFilters.hasActiveFilters ||
      widget.preset != null ||
      !setEquals(_active, _defaultSearchFilters);

  @override
  void initState() {
    super.initState();
    _active = {...(widget.preset?.chips ?? _defaultSearchFilters)};
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _toggleFilter(String value) {
    setState(() {
      if (_active.contains(value)) {
        _active.remove(value);
      } else {
        _active.add(value);
      }
    });
  }

  void _applyRecent(String value) {
    _setQuery(value);
  }

  void _removeRecent(String value) {
    ref.read(searchRecentQueriesProvider.notifier).remove(value);
  }

  void _clearRecents() {
    ref.read(searchRecentQueriesProvider.notifier).clear();
  }

  void _setQuery(String value) {
    _controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    _handleQueryChanged(value);
  }

  void _handleQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final trimmed = value.trim();
      if (_debouncedQuery == trimmed) {
        return;
      }
      setState(() {
        _debouncedQuery = trimmed;
      });
      _recordRecentSearch(trimmed);
    });
  }

  void _submitQuery(String value) {
    final trimmed = value.trim();
    _debounce?.cancel();
    if (_debouncedQuery == trimmed) {
      _recordRecentSearch(trimmed);
      return;
    }
    setState(() {
      _debouncedQuery = trimmed;
    });
    _recordRecentSearch(trimmed);
  }

  void _recordRecentSearch(String value) {
    ref.read(searchRecentQueriesProvider.notifier).add(value);
  }

  @override
  Widget build(BuildContext context) {
    final rawTextQuery = _controller.text.trim();
    final currentQuery = SearchResultsQuery(
      query: _debouncedQuery,
      activeFilters: _active.toList(growable: false)..sort(),
      sheetFilters: _sheetFilters,
    );
    final hasPendingDebounce =
        rawTextQuery.isNotEmpty && _debouncedQuery != rawTextQuery;
    final isRemoteSearchActive = _showResults && !hasPendingDebounce;
    final discoveryEvents = isRemoteSearchActive
        ? const <Event>[]
        : ref.watch(eventsProvider('nearby')).valueOrNull ?? const <Event>[];
    final filteredDiscoveryEvents = filterSearchEvents(
      events: discoveryEvents,
      query: rawTextQuery,
      activeFilters: currentQuery.activeFilters,
      sheetFilters: currentQuery.sheetFilters,
    );
    final searchResultsAsync = !_showResults || hasPendingDebounce
        ? null
        : ref.watch(searchResultsProvider(currentQuery));
    final remoteResults = searchResultsAsync?.valueOrNull;
    final searchResultsCount = remoteResults == null
        ? filteredDiscoveryEvents.length
        : remoteResults.meetups.length +
            remoteResults.evenings.length +
            remoteResults.routes.length +
            remoteResults.posters.length +
            remoteResults.affiche.length;
    final people = isRemoteSearchActive
        ? const <PersonSummary>[]
        : ref.watch(peopleProvider).valueOrNull ?? const <PersonSummary>[];
    final recents = ref.watch(searchRecentQueriesProvider);
    final showInlineLoading = _showResults &&
        (hasPendingDebounce || searchResultsAsync?.isLoading == true);
    final resultEvents = widget.preset == SearchPreset.evenings
        ? const <Event>[]
        : remoteResults?.meetups ?? filteredDiscoveryEvents;
    final resultEvenings = remoteResults?.evenings ?? const <AfterDarkEvent>[];
    final resultRoutes =
        remoteResults?.routes ?? const <EveningRouteTemplateSummary>[];
    final resultPosters = remoteResults?.posters ?? const <Poster>[];
    final resultAffiche = remoteResults?.affiche ?? const <AfficheEvent>[];
    final presetCount = widget.preset == SearchPreset.evenings
        ? resultEvenings.length
        : resultEvents.length +
            resultEvenings.length +
            resultRoutes.length +
            resultPosters.length +
            resultAffiche.length;
    final visibleFilters = [
      for (final filter in _active) filter,
      for (final filter in _searchFilters)
        if (!_active.contains(filter)) filter,
    ];

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      BbV5IconButton(
                        icon: LucideIcons.arrow_left,
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _V5SearchInput(
                          controller: _controller,
                          onChanged: _handleQueryChanged,
                          onSubmitted: _submitQuery,
                        ),
                      ),
                      const SizedBox(width: 8),
                      BbV5IconButton(
                        icon: Icons.map_outlined,
                        onPressed: () => context.pushRoute(AppRoute.map),
                      ),
                    ],
                  ),
                ),
                if (widget.preset != null)
                  _PresetHeader(
                    preset: widget.preset!,
                    count: presetCount,
                  ),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _FilterLauncherChip(
                          activeCount: _sheetFilters.activeCount,
                          onTap: () async {
                            final next = await showEventFilterSheet(
                              context,
                              initialValue: _sheetFilters,
                              resultsCount: searchResultsCount,
                              resultsCountBuilder: (filters) =>
                                  filterSearchEvents(
                                events: discoveryEvents,
                                query: rawTextQuery,
                                activeFilters: currentQuery.activeFilters,
                                sheetFilters: filters,
                              ).length,
                            );
                            if (next != null) {
                              setState(() {
                                _sheetFilters = next;
                              });
                            }
                          },
                        );
                      }

                      final filter = visibleFilters[index - 1];
                      return _SearchFilterChip(
                        label: filter,
                        active: _active.contains(filter),
                        onTap: () => _toggleFilter(filter),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemCount: visibleFilters.length + 1,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: !_showResults
                            ? SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 120),
                                child: _buildDiscover(context, people, recents),
                              )
                            : CustomScrollView(
                                slivers: _buildResultSlivers(
                                  context,
                                  resultEvents,
                                  resultEvenings,
                                  resultRoutes,
                                  resultPosters,
                                  resultAffiche,
                                ),
                              ),
                      ),
                      if (showInlineLoading)
                        Positioned(
                          left: 20,
                          right: 20,
                          top: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: const LinearProgressIndicator(
                              minHeight: 3,
                              color: BbV5Colors.accent,
                              backgroundColor: BbV5Colors.hairSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscover(
    BuildContext context,
    List<PersonSummary> people,
    List<String> recents,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xs),
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Недавнее',
                  style: AppTextStyles.caption.copyWith(letterSpacing: 0),
                ),
              ),
              InkWell(
                key: const ValueKey('search-recents-clear'),
                onTap: _clearRecents,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Очистить',
                    style: AppTextStyles.meta.copyWith(
                      color: BbV5Colors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final recent in recents)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.history,
                    size: 16,
                    color: BbV5Colors.inkMute,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      onTap: () => _applyRecent(recent),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(recent, style: AppTextStyles.body),
                      ),
                    ),
                  ),
                  InkWell(
                    key: ValueKey('recent-remove-$recent'),
                    onTap: () => _removeRecent(recent),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Row(
          children: [
            const Icon(
              LucideIcons.trending_up,
              size: 14,
              color: BbV5Colors.inkMute,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'В тренде',
              style: AppTextStyles.caption.copyWith(letterSpacing: 0),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _searchTrending
              .map(
                (tag) => InkWell(
                  onTap: () => _setQuery(tag),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: BbV5Colors.paperHi,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: BbV5Colors.hair),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#$tag',
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Люди, которых ты можешь знать',
          style: AppTextStyles.caption.copyWith(letterSpacing: 0),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final person in people.take(3))
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Row(
              children: [
                BbAvatar(name: person.name, size: BbAvatarSize.md),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name,
                          style:
                              AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                      Text(
                        _suggestedPersonSubtitle(
                            person, people.indexOf(person)),
                        style: AppTextStyles.meta,
                      ),
                      if (person.social.hasSignal) ...[
                        const SizedBox(height: 4),
                        BbSocialActions(
                          userId: person.id,
                          initialSocial: person.social,
                          variant: BbSocialActionsVariant.row,
                        ),
                      ],
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => context.pushRoute(
                    AppRoute.userProfile,
                    pathParameters: {'userId': person.id},
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: BbV5Colors.hair),
                    ),
                    child: Text('Открыть',
                        style: AppTextStyles.caption
                            .copyWith(color: BbV5Colors.ink)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _suggestedPersonSubtitle(PersonSummary person, int index) {
    if (person.common.isNotEmpty) {
      return '${person.common.length} общих интереса';
    }
    if ((person.area ?? '').isNotEmpty) {
      return person.area!;
    }
    return person.online ? 'Сейчас в сети' : 'Рядом с тобой';
  }

  List<Widget> _buildResultSlivers(
    BuildContext context,
    List<Event> events,
    List<AfterDarkEvent> evenings,
    List<EveningRouteTemplateSummary> routes,
    List<Poster> posters,
    List<AfficheEvent> affiche,
  ) {
    final hasResults = events.isNotEmpty ||
        evenings.isNotEmpty ||
        routes.isNotEmpty ||
        posters.isNotEmpty ||
        affiche.isNotEmpty;
    return [
      const SliverPadding(
        padding: EdgeInsets.only(top: AppSpacing.xs),
      ),
      if (events.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _SearchGroupHeader(
            icon: Icons.group_outlined,
            title: 'Встречи',
            count: events.length,
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemBuilder: (context, index) {
              final event = events[index];
              return _SearchMeetupResultCard(
                event: event,
                onTap: () => context.pushRoute(
                  AppRoute.eventDetail,
                  pathParameters: {'eventId': event.id},
                ),
              );
            },
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemCount: events.take(4).length,
          ),
        ),
      ],
      if (evenings.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: events.isNotEmpty ? AppSpacing.xl : 0,
            ),
            child: _SearchGroupHeader(
              icon: Icons.auto_awesome_rounded,
              title: 'Вечера',
              count: evenings.length,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemBuilder: (context, index) {
              final event = evenings[index];
              return _SearchAfterDarkResultTile(
                event: event,
                onOpen: () => context.pushRoute(
                  AppRoute.afterDarkEvent,
                  pathParameters: {'eventId': event.id},
                ),
              );
            },
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.xs),
            itemCount: evenings.take(3).length,
          ),
        ),
      ],
      if (routes.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: events.isNotEmpty || evenings.isNotEmpty ? AppSpacing.xl : 0,
            ),
            child: _SearchGroupHeader(
              icon: Icons.route_outlined,
              title: 'Маршруты',
              count: routes.length,
              onAll: () => context.pushRoute(AppRoute.eveningRoutes),
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemBuilder: (context, index) {
              final route = routes[index];
              return _SearchRouteResultTile(
                route: route,
                onOpen: () => context.pushRoute(
                  AppRoute.eveningRoutes,
                ),
              );
            },
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.xs),
            itemCount: routes.take(3).length,
          ),
        ),
      ],
      if (posters.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: events.isNotEmpty || evenings.isNotEmpty || routes.isNotEmpty
                  ? AppSpacing.xl
                  : 0,
            ),
            child: _SearchGroupHeader(
              icon: Icons.calendar_month_outlined,
              title: 'Афиша',
              count: posters.length,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 230,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final poster = posters[index];
                return PosterCard(
                  poster: poster,
                  variant: PosterCardVariant.compact,
                  onTap: () => context.pushRoute(
                    AppRoute.poster,
                    pathParameters: {'posterId': poster.id},
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemCount: posters.take(6).length,
            ),
          ),
        ),
      ],
      if (affiche.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: events.isNotEmpty ||
                      evenings.isNotEmpty ||
                      routes.isNotEmpty ||
                      posters.isNotEmpty
                  ? AppSpacing.xl
                  : 0,
            ),
            child: _SearchGroupHeader(
              icon: Icons.confirmation_number_outlined,
              title: 'Билеты и события',
              count: affiche.length,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 250,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final event = affiche[index];
                return AfficheEventCard(
                  event: event,
                  compact: true,
                  onTap: () => context.pushRoute(
                    AppRoute.afficheEvent,
                    pathParameters: {'eventId': event.id},
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemCount: affiche.take(6).length,
            ),
          ),
        ),
      ],
      if (!hasResults)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, AppSpacing.lg, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Ничего не нашлось. Попробуй другой запрос.',
              style: AppTextStyles.bodySoft.copyWith(
                color: BbV5Colors.inkMute,
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 120)),
    ];
  }
}

class _V5SearchInput extends StatelessWidget {
  const _V5SearchInput({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 16,
            color: BbV5Colors.inkMute,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: BbV5Colors.accent,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: BbV5Colors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Встречи, места, люди',
                hintStyle: AppTextStyles.meta.copyWith(
                  fontSize: 13,
                  color: BbV5Colors.inkMute,
                ),
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetHeader extends StatelessWidget {
  const _PresetHeader({
    required this.preset,
    required this.count,
  });

  final SearchPreset preset;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: BbV5Colors.accent.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              preset.icon,
              size: 14,
              color: BbV5Colors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              preset.title,
              style: bbV5DisplayStyle(fontSize: 18),
            ),
          ),
          Text(
            '$count',
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkMute,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchGroupHeader extends StatelessWidget {
  const _SearchGroupHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.onAll,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback? onAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icon, size: 13, color: BbV5Colors.inkMute),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$title · $count',
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.inkMute,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onAll != null)
            InkWell(
              onTap: onAll,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Все',
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevron_right,
                      size: 14,
                      color: BbV5Colors.accent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchAfterDarkResultTile extends StatelessWidget {
  const _SearchAfterDarkResultTile({
    required this.event,
    required this.onOpen,
  });

  final AfterDarkEvent event;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _CompactResultTile(
      emoji: event.emoji,
      title: event.title,
      meta: '${event.time} · ${event.district}',
      onOpen: onOpen,
      showChevron: true,
    );
  }
}

class _SearchMeetupResultCard extends StatelessWidget {
  const _SearchMeetupResultCard({
    required this.event,
    required this.onTap,
  });

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spotsLeft = (event.capacity - event.going).clamp(0, event.capacity);

    return Material(
      color: BbV5Colors.paperHi,
      borderRadius: BorderRadius.circular(BbV5Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BbV5Radii.md),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BbV5Colors.hair),
                ),
                alignment: Alignment.center,
                child: Text(event.emoji, style: const TextStyle(fontSize: 27)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: bbV5DisplayStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${event.time} · ${event.place}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        fontSize: 12,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _V5MiniPill(
                          icon: LucideIcons.users,
                          label: '${event.going}/${event.capacity}',
                        ),
                        const SizedBox(width: 6),
                        _V5MiniPill(
                          icon: LucideIcons.map_pin,
                          label: event.distance,
                        ),
                        if (spotsLeft > 0) ...[
                          const SizedBox(width: 6),
                          _V5MiniPill(label: '$spotsLeft мест'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                LucideIcons.chevron_right,
                size: 18,
                color: BbV5Colors.inkMute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchRouteResultTile extends StatelessWidget {
  const _SearchRouteResultTile({
    required this.route,
    required this.onOpen,
  });

  final EveningRouteTemplateSummary route;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _CompactResultTile(
      emoji: '🧭',
      title: route.title,
      meta: '${route.durationLabel} · ${route.area ?? route.city}',
      trailing: '≈ ${_formatRubles(route.totalPriceFrom)} ₽',
      onOpen: onOpen,
    );
  }
}

class _CompactResultTile extends StatelessWidget {
  const _CompactResultTile({
    required this.emoji,
    required this.title,
    required this.meta,
    required this.onOpen,
    this.trailing,
    this.showChevron = false,
  });

  final String emoji;
  final String title;
  final String meta;
  final String? trailing;
  final bool showChevron;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbV5Colors.paperHi,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  trailing!,
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  LucideIcons.chevron_right,
                  size: 18,
                  color: BbV5Colors.inkMute,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatRubles(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i += 1) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(raw[i]);
  }
  return buffer.toString();
}

class _FilterLauncherChip extends StatelessWidget {
  const _FilterLauncherChip({
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbV5Colors.ink,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(
                LucideIcons.sliders_horizontal,
                size: 14,
                color: BbV5Colors.paperHi,
              ),
              const SizedBox(width: 6),
              Text(
                'Фильтры',
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.paperHi,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: BbV5Colors.paperHi,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$activeCount',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.ink,
                      fontWeight: FontWeight.w600,
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

class _SearchFilterChip extends StatelessWidget {
  const _SearchFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
      borderRadius: BorderRadius.circular(BbV5Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _V5MiniPill extends StatelessWidget {
  const _V5MiniPill({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: BbV5Colors.inkMute),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.5,
              color: BbV5Colors.inkSoft,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
