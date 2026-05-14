import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/utils/event_time_labels.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_promo.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _whenOptions = ['Сегодня', 'Завтра', 'Выходные', 'На неделе'];
const _timeOfDayOptions = ['Утро', 'День', 'Вечер', 'Ночь'];
const _categoryOptions = [
  'Винчик',
  'Кофе',
  'Прогулка',
  'Спорт',
  'Кино',
  'Настолки',
  'Музыка',
];
const _vibeOptions = [
  'Камерно',
  'Шумно',
  'Активно',
  'Романтично',
  'Разговоры',
];
const _accessOptions = ['Открытое', 'По заявке'];

enum _MeetupsSort { time, near, popular }

@visibleForTesting
enum MeetupsSortForTest { time, near, popular }

final _meetupsFeedProvider =
    FutureProvider.autoDispose.family<List<Event>, _MeetupsQuery>(
  (ref, query) async {
    final authBootstrap = ref.watch(authBootstrapProvider.future);
    final manualLocation = ref.watch(manualLocationProvider);
    final repository = ref.read(backendRepositoryProvider);
    final locationService =
        manualLocation == null ? ref.read(appLocationServiceProvider) : null;
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);

    await authBootstrap;

    final location = await _meetupsLocation(manualLocation, locationService);
    if (location == null) {
      return const [];
    }
    final page = await repository.fetchEvents(
      filter: 'nearby',
      q: query.q,
      access: query.backendAccess,
      date: query.backendDate,
      latitude: location.latitude,
      longitude: location.longitude,
      radiusKm: query.radiusKm.toDouble(),
      limit: 60,
      cancelToken: cancelToken,
    );
    return page.items;
  },
);

class MeetupsScreen extends ConsumerStatefulWidget {
  const MeetupsScreen({super.key});

  @override
  ConsumerState<MeetupsScreen> createState() => _MeetupsScreenState();
}

class _MeetupsScreenState extends ConsumerState<MeetupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _q = '';
  String _when = _whenOptions.first;
  _MeetupsSort _sort = _MeetupsSort.time;
  List<String> _categories = const [];
  List<String> _vibes = const [];
  List<String> _timeOfDay = const [];
  List<String> _access = const [];
  double _radiusKm = nearbyEventsDefaultRadiusKm;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _MeetupsQuery(
      q: _q.trim(),
      when: _when,
      categories: _categories,
      vibes: _vibes,
      timeOfDay: _timeOfDay,
      access: _access,
      radiusKm: _radiusKm.round(),
    );
    final usesSharedNearbyFeed = _usesSharedNearbyFeed;
    final feedAsync = usesSharedNearbyFeed
        ? ref.watch(eventsProvider('nearby'))
        : ref.watch(_meetupsFeedProvider(query));
    final wallet = ref.watch(tokenWalletProvider);
    final promotedIds = wallet.promoted.keys
        .where((eventId) => wallet.isPromoted(eventId))
        .toSet();
    final activeCount = _activeFilterCount;

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: BbV5TopBar(
                    kicker: 'Сейчас собираются',
                    title: 'Встречи',
                    accent: 'рядом',
                    right: BbV5IconButton(
                      icon: LucideIcons.sparkles,
                      onPressed: () =>
                          context.pushRoute(AppRoute.hostDashboard),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: BbV5SearchPill(
                          controller: _searchController,
                          hintText: 'Винчик, джаз, прогулка...',
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _FilterButton(
                        count: activeCount,
                        onTap: _showFilters,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    itemBuilder: (context, index) {
                      final value = _whenOptions[index];
                      return BbV5Chip(
                        label: value,
                        active: _when == value,
                        onTap: () {
                          setState(() {
                            _when = value;
                          });
                        },
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemCount: _whenOptions.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                  child: feedAsync.when(
                    data: (events) {
                      final visible = _visibleEvents(events, promotedIds);
                      return _SortHeader(
                        count: visible.length,
                        sort: _sort,
                        onChanged: (sort) {
                          setState(() {
                            _sort = sort;
                          });
                        },
                      );
                    },
                    loading: () => _SortHeader(
                      count: 0,
                      sort: _sort,
                      loading: true,
                      onChanged: (sort) {
                        setState(() {
                          _sort = sort;
                        });
                      },
                    ),
                    error: (_, __) => _SortHeader(
                      count: 0,
                      sort: _sort,
                      onChanged: (sort) {
                        setState(() {
                          _sort = sort;
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: feedAsync.when(
                    data: (events) {
                      final visible = _visibleEvents(events, promotedIds);
                      if (visible.isEmpty) {
                        return _MeetupsEmptyState(
                          onReset: _resetFilters,
                        );
                      }
                      return RefreshIndicator(
                        color: BbV5Colors.accent,
                        onRefresh: () async {
                          if (usesSharedNearbyFeed) {
                            ref.invalidate(eventsProvider('nearby'));
                            await ref.read(eventsProvider('nearby').future);
                            return;
                          }
                          ref.invalidate(_meetupsFeedProvider(query));
                          await ref.read(_meetupsFeedProvider(query).future);
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemBuilder: (context, index) => _MeetupListCard(
                            event: visible[index],
                            promoted: promotedIds.contains(visible[index].id),
                            onTap: () => context.pushRoute(
                              AppRoute.eventDetail,
                              pathParameters: {'eventId': visible[index].id},
                            ),
                          ),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemCount: visible.length,
                        ),
                      );
                    },
                    loading: () => const _MeetupsSkeletonList(),
                    error: (_, __) => _MeetupsErrorState(
                      onRetry: () {
                        if (usesSharedNearbyFeed) {
                          ref.invalidate(eventsProvider('nearby'));
                          return;
                        }
                        ref.invalidate(_meetupsFeedProvider(query));
                      },
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

  bool get _usesSharedNearbyFeed {
    return _q.trim().isEmpty &&
        _when == _whenOptions.first &&
        _categories.isEmpty &&
        _vibes.isEmpty &&
        _timeOfDay.isEmpty &&
        _access.isEmpty &&
        _radiusKm.round() == nearbyEventsDefaultRadiusKm.round();
  }

  int get _activeFilterCount {
    return _categories.length +
        _vibes.length +
        _timeOfDay.length +
        _access.length +
        (_when == _whenOptions.first ? 0 : 1) +
        (_radiusKm.round() == nearbyEventsDefaultRadiusKm.round() ? 0 : 1);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) {
        return;
      }
      final next = value.trim();
      if (next == _q) {
        return;
      }
      setState(() {
        _q = next;
      });
    });
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _q = '';
      _when = _whenOptions.first;
      _sort = _MeetupsSort.time;
      _categories = const [];
      _vibes = const [];
      _timeOfDay = const [];
      _access = const [];
      _radiusKm = nearbyEventsDefaultRadiusKm;
    });
    ref
        .read(nearbyEventsRadiusKmProvider.notifier)
        .setRadiusKm(nearbyEventsDefaultRadiusKm);
  }

  List<Event> _visibleEvents(List<Event> source, Set<String> promotedIds) {
    final result = source.where(_matchesFilters).toList(growable: false);
    return _sortMeetups(result, promotedIds: promotedIds, sort: _sort);
  }

  bool _matchesFilters(Event event) {
    if (!_matchesWhen(event, _when)) {
      return false;
    }

    if (_timeOfDay.isNotEmpty &&
        !_timeOfDay.any((item) {
          return _matchesTimeOfDay(event, item);
        })) {
      return false;
    }

    if (_categories.isNotEmpty &&
        !_categories.any((item) {
          return _eventText(event).contains(_norm(item));
        })) {
      return false;
    }

    if (_vibes.isNotEmpty &&
        !_vibes.any((item) {
          return _eventText(event).contains(_norm(item));
        })) {
      return false;
    }

    if (_access.isNotEmpty &&
        !_access.any((item) {
          return _matchesAccess(event, item);
        })) {
      return false;
    }

    return true;
  }

  void _showFilters() {
    var categories = [..._categories];
    var vibes = [..._vibes];
    var timeOfDay = [..._timeOfDay];
    var access = [..._access];
    var when = _when;
    var radius = _radiusKm;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x8014100C),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggle(List<String> list, String value) {
              setSheetState(() {
                if (list.contains(value)) {
                  list.remove(value);
                } else {
                  list.add(value);
                }
              });
            }

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: Material(
                    color: BbV5Colors.paper,
                    child: SafeArea(
                      top: false,
                      child: DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.84,
                        maxChildSize: 0.92,
                        minChildSize: 0.5,
                        builder: (context, scrollController) {
                          return Column(
                            children: [
                              Expanded(
                                child: ListView(
                                  controller: scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 12, 20, 20),
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 48,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: BbV5Colors.hair,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Row(
                                      children: [
                                        Text(
                                          'Фильтры',
                                          style: bbV5DisplayStyle(
                                            fontSize: 20,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            setSheetState(() {
                                              categories = [];
                                              vibes = [];
                                              timeOfDay = [];
                                              access = [];
                                              when = _whenOptions.first;
                                              radius =
                                                  nearbyEventsDefaultRadiusKm;
                                            });
                                          },
                                          child: Text(
                                            'Сбросить',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              fontFamily: 'Sora',
                                              fontWeight: FontWeight.w600,
                                              color: BbV5Colors.terra,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    _FilterGroup(
                                      title: 'Когда',
                                      children: [
                                        for (final value in _whenOptions)
                                          BbV5Chip(
                                            label: value,
                                            active: when == value,
                                            onTap: () {
                                              setSheetState(() {
                                                when = value;
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                    _FilterGroup(
                                      title: 'Время суток',
                                      children: [
                                        for (final value in _timeOfDayOptions)
                                          BbV5Chip(
                                            label: value,
                                            active: timeOfDay.contains(value),
                                            onTap: () =>
                                                toggle(timeOfDay, value),
                                          ),
                                      ],
                                    ),
                                    _FilterGroup(
                                      title: 'Категории',
                                      children: [
                                        for (final value in _categoryOptions)
                                          BbV5Chip(
                                            label: value,
                                            active: categories.contains(value),
                                            onTap: () =>
                                                toggle(categories, value),
                                          ),
                                      ],
                                    ),
                                    _FilterGroup(
                                      title: 'Атмосфера',
                                      children: [
                                        for (final value in _vibeOptions)
                                          BbV5Chip(
                                            label: value,
                                            active: vibes.contains(value),
                                            onTap: () => toggle(vibes, value),
                                          ),
                                      ],
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          BbV5Kicker(
                                            'РАДИУС · ${radius.round()} КМ',
                                          ),
                                          Slider(
                                            min: 1,
                                            max: nearbyEventsMaxRadiusKm,
                                            divisions: nearbyEventsMaxRadiusKm
                                                    .round() -
                                                1,
                                            value: radius,
                                            activeColor: BbV5Colors.accent,
                                            inactiveColor: BbV5Colors.hair,
                                            onChanged: (value) {
                                              setSheetState(() {
                                                radius = value;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    _FilterGroup(
                                      title: 'Доступ',
                                      children: [
                                        for (final value in _accessOptions)
                                          BbV5Chip(
                                            label: value,
                                            active: access.contains(value),
                                            onTap: () => toggle(access, value),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                child: BbV5PillButton(
                                  label: 'Показать встречи',
                                  dark: true,
                                  height: 52,
                                  expanded: true,
                                  onPressed: () {
                                    setState(() {
                                      _categories =
                                          List.unmodifiable(categories);
                                      _vibes = List.unmodifiable(vibes);
                                      _timeOfDay = List.unmodifiable(timeOfDay);
                                      _access = List.unmodifiable(access);
                                      _when = when;
                                      _radiusKm =
                                          clampNearbyEventsRadiusKm(radius);
                                    });
                                    ref
                                        .read(
                                          nearbyEventsRadiusKmProvider.notifier,
                                        )
                                        .setRadiusKm(radius);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            ],
                          );
                        },
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

class _MeetupsQuery {
  const _MeetupsQuery({
    required this.q,
    required this.when,
    required this.categories,
    required this.vibes,
    required this.timeOfDay,
    required this.access,
    required this.radiusKm,
  });

  final String q;
  final String when;
  final List<String> categories;
  final List<String> vibes;
  final List<String> timeOfDay;
  final List<String> access;
  final int radiusKm;

  String? get backendDate {
    final now = DateTime.now();
    return switch (when) {
      'Сегодня' => _isoDate(now),
      'Завтра' => _isoDate(now.add(const Duration(days: 1))),
      _ => null,
    };
  }

  String? get backendAccess {
    if (access.length != 1) {
      return null;
    }
    return switch (access.first) {
      'Открытое' => 'open',
      'По заявке' => 'request',
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _MeetupsQuery &&
            q == other.q &&
            when == other.when &&
            radiusKm == other.radiusKm &&
            listEquals(categories, other.categories) &&
            listEquals(vibes, other.vibes) &&
            listEquals(timeOfDay, other.timeOfDay) &&
            listEquals(access, other.access);
  }

  @override
  int get hashCode => Object.hash(
        q,
        when,
        Object.hashAll(categories),
        Object.hashAll(vibes),
        Object.hashAll(timeOfDay),
        Object.hashAll(access),
        radiusKm,
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        BbV5PillButton(
          label: 'Фильтры',
          icon: LucideIcons.sliders_horizontal,
          height: 44,
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: BbV5Colors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: BbV5Colors.paperHi,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.count,
    required this.sort,
    required this.onChanged,
    this.loading = false,
  });

  final int count;
  final _MeetupsSort sort;
  final ValueChanged<_MeetupsSort> onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          loading ? 'ЗАГРУЖАЕМ' : '$count ВСТРЕЧ',
          style: bbV5KickerStyle(fontSize: 11, letterSpacing: 1.54),
        ),
        const Spacer(),
        _SortChip(
          label: 'Скоро',
          active: sort == _MeetupsSort.time,
          onTap: () => onChanged(_MeetupsSort.time),
        ),
        _SortChip(
          label: 'Ближе',
          active: sort == _MeetupsSort.near,
          onTap: () => onChanged(_MeetupsSort.near),
        ),
        _SortChip(
          label: 'Топ',
          active: sort == _MeetupsSort.popular,
          onTap: () => onChanged(_MeetupsSort.popular),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: active ? BbV5Colors.accentDeep : BbV5Colors.inkMute,
        backgroundColor: active ? BbV5Colors.terraSoft : Colors.transparent,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontFamily: 'Sora',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? BbV5Colors.accentDeep : BbV5Colors.inkMute,
        ),
      ),
    );
  }
}

class _MeetupListCard extends StatelessWidget {
  const _MeetupListCard({
    required this.event,
    required this.promoted,
    required this.onTap,
  });

  final Event event;
  final bool promoted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.imageUrl?.trim();
    return BbV5Card(
      padding: const EdgeInsets.all(10),
      radius: 24,
      tint: promoted ? BbV5Colors.terraSoft : null,
      borderColor: promoted ? BbV5Colors.accent : BbV5Colors.hair,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    BbExternalEventImage(
                      imageUrl: imageUrl,
                      usage: BbExternalEventImageUsage.card,
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _eventGradient(event.tone),
                      ),
                      child: Center(
                        child: Text(
                          event.emoji,
                          style: const TextStyle(fontSize: 38, height: 1),
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x8C000000),
                        ],
                        stops: [0.5, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7,
                    bottom: 6,
                    child: Text(
                      event.time,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (promoted)
                    const Positioned(
                      left: 7,
                      top: 7,
                      child: _PromotedMeetupBadge(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(
              height: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (promoted) ...[
                        const _PromotedMeetupBadge(dark: true),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _phaseColor(event),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _phaseLabel(event),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontFamily: 'Sora',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.33,
                            color: _phaseColor(event),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bbV5DisplayStyle(fontSize: 14, letterSpacing: 0),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${event.place} · ${event.distance}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: BbV5Colors.hairSoft),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.users,
                            size: 13,
                            color: BbV5Colors.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${event.going}/${event.capacity}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BbV5Colors.inkSoft,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _accessLabel(event),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: BbV5Colors.inkMute,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _PromotedMeetupBadge extends StatelessWidget {
  const _PromotedMeetupBadge({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return BbV5PromoBadge(compact: true, dark: dark);
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbV5Kicker(title.toUpperCase()),
          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _MeetupsSkeletonList extends StatelessWidget {
  const _MeetupsSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemBuilder: (_, __) => Container(
        height: 132,
        decoration: BoxDecoration(
          color: BbV5Colors.paperHi.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: BbV5Colors.hair),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemCount: 5,
    );
  }
}

class _MeetupsEmptyState extends StatelessWidget {
  const _MeetupsEmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        BbV5Card(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Пока нет подходящих встреч',
                style: bbV5DisplayStyle(fontSize: 18, letterSpacing: 0),
              ),
              const SizedBox(height: 8),
              Text(
                'Попробуй другой день, радиус или убери часть фильтров.',
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              BbV5PillButton(
                label: 'Сбросить',
                icon: LucideIcons.rotate_ccw,
                onPressed: onReset,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeetupsErrorState extends StatelessWidget {
  const _MeetupsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        BbV5Card(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Не получилось загрузить встречи',
                style: bbV5DisplayStyle(fontSize: 18, letterSpacing: 0),
              ),
              const SizedBox(height: 8),
              Text(
                'Проверь соединение и попробуй ещё раз.',
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              BbV5PillButton(
                label: 'Повторить',
                icon: LucideIcons.refresh_cw,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<({double latitude, double longitude})?> _meetupsLocation(
  ManualLocation? manualLocation,
  AppLocationService? locationService,
) async {
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

bool _matchesWhen(Event event, String when) {
  return _matchesWhenAt(event, when, DateTime.now());
}

@visibleForTesting
bool meetupMatchesWhenForTest(
  Event event,
  String when, {
  required DateTime now,
}) {
  return _matchesWhenAt(event, when, now);
}

bool _matchesWhenAt(Event event, String when, DateTime now) {
  final date = _eventDate(event);
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);

  switch (when) {
    case 'Сегодня':
      return day == today;
    case 'Завтра':
      return day == today.add(const Duration(days: 1));
    case 'Выходные':
      final weekend = _weekendWindow(today);
      return !day.isBefore(weekend.start) && day.isBefore(weekend.end);
    case 'На неделе':
      final end = today.add(
        Duration(days: DateTime.daysPerWeek - today.weekday + 1),
      );
      return !day.isBefore(today) && day.isBefore(end);
    default:
      return true;
  }
}

bool _matchesTimeOfDay(Event event, String label) {
  final hour = _eventDate(event).hour;
  return switch (label) {
    'Утро' => hour >= 5 && hour < 12,
    'День' => hour >= 12 && hour < 17,
    'Вечер' => hour >= 17 && hour < 23,
    'Ночь' => hour >= 23 || hour < 5,
    _ => true,
  };
}

bool _matchesAccess(Event event, String label) {
  return switch (label) {
    'Открытое' => event.joinMode == EventJoinMode.open ||
        event.accessMode == 'open' ||
        event.accessMode == 'free',
    'По заявке' =>
      event.joinMode == EventJoinMode.request || event.accessMode == 'request',
    _ => true,
  };
}

@visibleForTesting
DateTime eventDateForTest(Event event) => _eventDate(event);

DateTime _eventDate(Event event) {
  return DateTime.tryParse(event.startsAtIso ?? '')?.toLocal() ??
      DateTime.now();
}

({DateTime start, DateTime end}) _weekendWindow(DateTime today) {
  if (today.weekday == DateTime.sunday) {
    final saturday = today.subtract(const Duration(days: 1));
    return (start: saturday, end: today.add(const Duration(days: 1)));
  }
  final daysUntilSaturday = (DateTime.saturday - today.weekday) % 7;
  final start = today.add(Duration(days: daysUntilSaturday));
  return (start: start, end: start.add(const Duration(days: 2)));
}

String _eventText(Event event) {
  return _norm(
    [
      event.title,
      event.place,
      event.vibe,
      event.lifestyle,
      event.hostNote,
    ].whereType<String>().join(' '),
  );
}

String _norm(String value) => value.toLowerCase().trim();

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

double _distanceValue(String value) {
  final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(value);
  if (match == null) {
    return double.infinity;
  }
  return double.tryParse(match.group(1)!.replaceAll(',', '.')) ??
      double.infinity;
}

String _phaseLabel(Event event) {
  if (event.liveStatus == EventLiveStatus.live) {
    return 'ИДЁТ СЕЙЧАС';
  }
  final startsAt = _eventDate(event);
  final diff = startsAt.difference(DateTime.now());
  if (diff.inMinutes > 0 && diff.inMinutes <= 90) {
    return 'СКОРО';
  }
  return eventDayLabel(
    time: event.time,
    startsAtIso: event.startsAtIso,
  ).toUpperCase();
}

Color _phaseColor(Event event) {
  if (event.liveStatus == EventLiveStatus.live) {
    return BbV5Colors.terra;
  }
  return switch (event.tone) {
    EventTone.sage => BbV5Colors.brand,
    EventTone.evening => BbV5Colors.gold,
    EventTone.warm => BbV5Colors.brandDeep,
  };
}

String _accessLabel(Event event) {
  if (event.joinMode == EventJoinMode.request ||
      event.accessMode == 'request') {
    return 'По заявке';
  }
  return 'Открытое';
}

List<Event> _sortMeetups(
  List<Event> source, {
  required Set<String> promotedIds,
  required _MeetupsSort sort,
}) {
  final sorted = [...source];
  sorted.sort((a, b) => _compareMeetupsBySort(a, b, sort));
  return [
    ...sorted.where((event) => promotedIds.contains(event.id)),
    ...sorted.where((event) => !promotedIds.contains(event.id)),
  ];
}

int _compareMeetupsBySort(Event a, Event b, _MeetupsSort sort) {
  switch (sort) {
    case _MeetupsSort.near:
      return _distanceValue(a.distance).compareTo(_distanceValue(b.distance));
    case _MeetupsSort.popular:
      return b.going.compareTo(a.going);
    case _MeetupsSort.time:
      return _eventDate(a).compareTo(_eventDate(b));
  }
}

@visibleForTesting
List<Event> sortMeetupsForTest(
  List<Event> source, {
  required Set<String> promotedIds,
  required MeetupsSortForTest sort,
}) {
  final mappedSort = switch (sort) {
    MeetupsSortForTest.time => _MeetupsSort.time,
    MeetupsSortForTest.near => _MeetupsSort.near,
    MeetupsSortForTest.popular => _MeetupsSort.popular,
  };
  return _sortMeetups(source, promotedIds: promotedIds, sort: mappedSort);
}

LinearGradient _eventGradient(EventTone tone) {
  return switch (tone) {
    EventTone.sage => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BbV5Colors.brandSoft, BbV5Colors.brand],
      ),
    EventTone.evening => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BbV5Colors.gold, BbV5Colors.terra],
      ),
    EventTone.warm => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BbV5Colors.terraSoft, BbV5Colors.paperDeep],
      ),
  };
}
