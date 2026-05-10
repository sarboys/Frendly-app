import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_filters.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AfficheEventsScreen extends StatelessWidget {
  const AfficheEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BbV5Scaffold(
      child: AfficheEventsBrowser(
        onBack: () => _handleBack(context),
      ),
    );
  }

  void _handleBack(BuildContext context) async {
    final popped = await Navigator.of(context).maybePop();
    if (!popped && context.mounted) {
      context.goRoute(AppRoute.tonight);
    }
  }
}

class AfficheEventsBrowser extends ConsumerStatefulWidget {
  const AfficheEventsBrowser({
    this.initialSelectedEvent,
    this.onEventSelected,
    this.onBack,
    this.backIcon = LucideIcons.arrow_left,
    this.kicker = 'Афиша города',
    this.title = 'Куда пойти',
    this.accent = 'сегодня',
    this.searchHintText = 'Концерт, выставка, стендап…',
    this.safeAreaTop = true,
    this.showDragHandle = false,
    this.headerTopPadding = 32,
    this.bottomSpacer = 112,
    super.key,
  });

  final AfficheEvent? initialSelectedEvent;
  final ValueChanged<AfficheEvent>? onEventSelected;
  final VoidCallback? onBack;
  final IconData backIcon;
  final String kicker;
  final String title;
  final String accent;
  final String searchHintText;
  final bool safeAreaTop;
  final bool showDragHandle;
  final double headerTopPadding;
  final double bottomSpacer;

  @override
  ConsumerState<AfficheEventsBrowser> createState() =>
      _AfficheEventsBrowserState();
}

class _AfficheEventsBrowserState extends ConsumerState<AfficheEventsBrowser> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _queryDebounce;
  String _debouncedQuery = '';
  String? _date;
  String _timeOfDay = 'any';
  String _priceMode = 'any';
  String? _category;
  Set<String> _categories = const {};
  double _radiusKm = 30;
  AfficheEventsQuery? _currentQuery;
  AfficheEventsPagedState? _lastPageState;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final query = _currentQuery;
    if (query == null || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    if (position.maxScrollExtent - position.pixels > 520) {
      return;
    }
    ref.read(afficheEventsPagedProvider(query).notifier).loadNextPage();
  }

  void _handleQueryChanged(String value) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final query = value.trim();
      if (_debouncedQuery == query) {
        return;
      }
      setState(() {
        _debouncedQuery = query;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final city = afficheCity(ref);
    final query = AfficheEventsQuery(
      city: city,
      query: _debouncedQuery,
      date: _date == 'week' ? null : _date,
      priceMode: _priceMode,
      category: _categories.length == 1 ? _categories.first : _category,
      limit: 18,
    );
    _currentQuery = query;
    final pagedProvider = afficheEventsPagedProvider(query);
    ref.listen<AsyncValue<AfficheEventsPagedState>>(pagedProvider, (_, next) {
      final page = next.valueOrNull;
      if (page != null) {
        _lastPageState = page;
        unawaited(
          ref.read(appMediaPrewarmServiceProvider).warmExternalEventImages(
                page.items.map(
                  (event) => event.imageUrlFor(BbExternalEventImageUsage.card),
                ),
                usage: BbExternalEventImageUsage.card,
                limit: 8,
                concurrency: 2,
              ),
        );
      }
    });
    final eventsAsync = ref.watch(pagedProvider);
    final visibleState = eventsAsync.valueOrNull ?? _lastPageState;
    final showInitialLoading = eventsAsync.isLoading && visibleState == null;
    final visibleEvents = visibleState?.items ?? const <AfficheEvent>[];

    return SafeArea(
      key: const Key('affiche-v5-browser'),
      top: widget.safeAreaTop,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: CustomScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (widget.showDragHandle)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: BbV5Colors.hair,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding:
                    EdgeInsets.fromLTRB(20, widget.headerTopPadding, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _AfficheV5Header(
                    onBack: widget.onBack,
                    backIcon: widget.backIcon,
                    kicker: widget.kicker,
                    title: widget.title,
                    accent: widget.accent,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: BbV5SearchPill(
                          controller: _queryController,
                          onChanged: _handleQueryChanged,
                          hintText: widget.searchHintText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AfficheV5FilterButton(
                        activeCount: _activeFilterCount,
                        onTap: _openFilterSheet,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _AfficheQuickFilterRows(
                  date: _date,
                  priceMode: _priceMode,
                  categories: _categories,
                  onDateChanged: (value) => setState(() => _date = value),
                  onPriceChanged: (value) => setState(
                    () => _priceMode = value ?? 'any',
                  ),
                  onCategoryChanged: _toggleCategory,
                ),
              ),
              if (showInitialLoading)
                const _AfficheStateSliver(
                  icon: LucideIcons.ticket,
                  title: 'Загружаем афишу',
                  message: 'Собираем события рядом.',
                  loading: true,
                )
              else if (visibleState == null)
                const _AfficheStateSliver(
                  icon: LucideIcons.wifi_off,
                  title: 'Не получилось загрузить афишу',
                  message: 'Проверь соединение и попробуй еще раз.',
                )
              else ...[
                if (eventsAsync.isLoading)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: BbV5Colors.accent,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: BbV5Kicker('${visibleEvents.length} событий'),
                  ),
                ),
                if (visibleEvents.isEmpty)
                  const _AfficheStateSliver(
                    icon: LucideIcons.search_x,
                    title: 'Ничего не нашли',
                    message: 'Попробуй другой запрос или категорию.',
                  )
                else
                  _AfficheEventsGrid(
                    events: visibleEvents,
                    selectedEventId: widget.initialSelectedEvent?.id,
                    onEventTap: widget.onEventSelected,
                  ),
                if (visibleState.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BbV5Colors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: widget.bottomSpacer)),
            ],
          ),
        ),
      ),
    );
  }

  int get _activeFilterCount {
    var count = 0;
    if (_date != null) {
      count += 1;
    }
    if (_priceMode != 'any') {
      count += 1;
    }
    if (_timeOfDay != 'any') {
      count += 1;
    }
    if (_categories.isNotEmpty || _category != null) {
      count += 1;
    }
    if (_radiusKm < 30) {
      count += 1;
    }
    return count;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_AfficheFilterSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AfficheFilterSheet(
        date: _date,
        priceMode: _priceMode,
        timeOfDay: _timeOfDay,
        categories: _categories,
        radiusKm: _radiusKm,
        resultsCount: _lastPageState?.items.length ?? 0,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _date = result.date;
      _priceMode = result.priceMode;
      _timeOfDay = result.timeOfDay;
      _categories = result.categories;
      _category = result.categories.isEmpty ? null : result.categories.first;
      _radiusKm = result.radiusKm;
    });
  }

  void _toggleCategory(AfficheFilterOption option) {
    setState(() {
      if (option.value == null) {
        _categories = const {};
        _category = null;
      } else if (_categories.contains(option.value)) {
        _categories = {..._categories}..remove(option.value);
        _category = _categories.isEmpty ? null : _categories.first;
      } else {
        _categories = {..._categories, option.value!};
        _category = option.value;
      }
    });
  }
}

String _categoryChipLabel(AfficheFilterOption option) {
  if (option.value == null) {
    return 'Все';
  }
  final emoji = switch (option.value) {
    'concert' => '🎧',
    'theatre' => '🎭',
    'culture' => '🏛',
    'comedy' => '🎤',
    'cinema' => '🎬',
    'sport' => '🏃',
    'festival' => '🎪',
    'lecture' => '🎓',
    'workshop' => '🎨',
    _ => '🎟',
  };
  return '$emoji ${option.label}';
}

class _AfficheV5Header extends StatelessWidget {
  const _AfficheV5Header({
    required this.onBack,
    required this.backIcon,
    required this.kicker,
    required this.title,
    required this.accent,
  });

  final VoidCallback? onBack;
  final IconData backIcon;
  final String kicker;
  final String title;
  final String accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          BbV5IconButton(
            icon: backIcon,
            onPressed: onBack!,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker(kicker),
              const SizedBox(height: 4),
              BbV5HeroTitle(
                title: title,
                accent: accent,
                fontSize: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AfficheQuickFilterRows extends StatelessWidget {
  const _AfficheQuickFilterRows({
    required this.date,
    required this.priceMode,
    required this.categories,
    required this.onDateChanged,
    required this.onPriceChanged,
    required this.onCategoryChanged,
  });

  final String? date;
  final String priceMode;
  final Set<String> categories;
  final ValueChanged<String?> onDateChanged;
  final ValueChanged<String?> onPriceChanged;
  final ValueChanged<AfficheFilterOption> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 18),
      child: Column(
        children: [
          _AfficheV5FilterRow(
            key: const Key('affiche-v5-filter-row-date'),
            options: afficheDateOptions(),
            isActive: (option) => date == option.value,
            onTap: (option) => onDateChanged(option.value),
          ),
          const SizedBox(height: 8),
          _AfficheV5FilterRow(
            key: const Key('affiche-v5-filter-row-price'),
            options: affichePriceOptions,
            isActive: (option) => priceMode == option.value,
            onTap: (option) => onPriceChanged(option.value),
          ),
          const SizedBox(height: 8),
          _AfficheV5FilterRow(
            key: const Key('affiche-v5-filter-row-category'),
            options: afficheCategoryOptions,
            labelFor: _categoryChipLabel,
            isActive: (option) => option.value == null
                ? categories.isEmpty
                : categories.contains(option.value),
            onTap: onCategoryChanged,
          ),
        ],
      ),
    );
  }
}

class _AfficheV5FilterRow extends StatelessWidget {
  const _AfficheV5FilterRow({
    required this.options,
    required this.isActive,
    required this.onTap,
    this.labelFor,
    super.key,
  });

  final List<AfficheFilterOption> options;
  final bool Function(AfficheFilterOption option) isActive;
  final ValueChanged<AfficheFilterOption> onTap;
  final String Function(AfficheFilterOption option)? labelFor;

  @override
  Widget build(BuildContext context) {
    final labelBuilder = labelFor ?? (option) => option.label;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final option = options[index];
          return BbV5Chip(
            label: labelBuilder(option),
            active: isActive(option),
            icon: labelFor == null ? option.icon : null,
            onTap: () => onTap(option),
          );
        },
      ),
    );
  }
}

class _AfficheV5FilterButton extends StatelessWidget {
  const _AfficheV5FilterButton({
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Фильтры',
      child: Stack(
        key: const ValueKey('affiche-filter-summary'),
        clipBehavior: Clip.none,
        children: [
          BbV5IconButton(
            icon: LucideIcons.sliders_horizontal,
            onPressed: onTap,
          ),
          if (activeCount > 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BbV5Colors.accent,
                  borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  border: Border.all(color: BbV5Colors.paperHi, width: 1.5),
                ),
                child: Text(
                  '$activeCount',
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.paperHi,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AfficheEventsGrid extends StatelessWidget {
  const _AfficheEventsGrid({
    required this.events,
    this.selectedEventId,
    this.onEventTap,
  });

  final List<AfficheEvent> events;
  final String? selectedEventId;
  final ValueChanged<AfficheEvent>? onEventTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final event = events[index];
            final selectionHandler = onEventTap;
            return _AfficheGridCardV5(
              event: event,
              selected: selectedEventId == event.id,
              onTap: selectionHandler == null
                  ? () => context.pushRoute(
                        AppRoute.afficheEvent,
                        pathParameters: {'eventId': event.id},
                      )
                  : () => selectionHandler(event),
            );
          },
          childCount: events.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
      ),
    );
  }
}

class _AfficheGridCardV5 extends StatelessWidget {
  const _AfficheGridCardV5({
    required this.event,
    required this.onTap,
    this.selected = false,
  });

  final AfficheEvent event;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('affiche-v5-event-${event.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.md),
        child: Ink(
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.md),
            border: Border.all(
              color: selected ? BbV5Colors.accent : BbV5Colors.hair,
              width: selected ? 2 : 1,
            ),
            boxShadow: BbV5Shadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BbV5Radii.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: BbExternalEventImage(
                          imageUrl:
                              event.imageUrlFor(BbExternalEventImageUsage.card),
                          usage: BbExternalEventImageUsage.card,
                          fallbackIconSize: 44,
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                BbV5Colors.ink.withValues(alpha: 0.10),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: BbV5Colors.paperHi.withValues(alpha: 0.92),
                              borderRadius:
                                  BorderRadius.circular(BbV5Radii.pill),
                              border: Border.all(color: BbV5Colors.hair),
                            ),
                            child: Text(
                              _dateBadgeLabel(event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'Sora',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.57,
                                color: BbV5Colors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 36,
                          child: Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontFamily: 'Sora',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              letterSpacing: 0,
                              color: BbV5Colors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.map_pin,
                              size: 10,
                              color: BbV5Colors.inkMute,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.venue?.trim().isNotEmpty == true
                                    ? event.venue!.trim()
                                    : event.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta.copyWith(
                                  fontSize: 10.5,
                                  color: BbV5Colors.inkMute,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Divider(height: 13, color: BbV5Colors.hairSoft),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.isFree ? 'free' : event.compactPriceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta.copyWith(
                                  fontFamily: 'Sora',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: BbV5Colors.terra,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            const Icon(
                              LucideIcons.ticket,
                              size: 14,
                              color: BbV5Colors.inkMute,
                            ),
                          ],
                        ),
                      ],
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

String _dateBadgeLabel(AfficheEvent event) {
  final raw = (event.dateLabel ?? '').trim();
  if (raw.isEmpty) {
    return (event.timeLabel ?? '').trim().isEmpty
        ? 'Сегодня'
        : event.timeLabel!.trim();
  }
  final comma = raw.indexOf(',');
  if (comma > 0 && raw.length > comma + 1) {
    return raw.substring(comma + 1).trim();
  }
  return raw.length > 12 ? raw.substring(0, 12) : raw;
}

class _AfficheStateSliver extends StatelessWidget {
  const _AfficheStateSliver({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Center(
          child: BbV5Card(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BbV5Colors.ink,
                    ),
                  )
                else
                  Icon(icon, size: 28, color: BbV5Colors.inkSoft),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: bbV5DisplayStyle(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkMute,
                    height: 1.35,
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

class _AfficheFilterSelection {
  const _AfficheFilterSelection({
    required this.date,
    required this.priceMode,
    required this.timeOfDay,
    required this.categories,
    required this.radiusKm,
  });

  final String? date;
  final String priceMode;
  final String timeOfDay;
  final Set<String> categories;
  final double radiusKm;
}

class _AfficheFilterSheet extends StatefulWidget {
  const _AfficheFilterSheet({
    required this.date,
    required this.priceMode,
    required this.timeOfDay,
    required this.categories,
    required this.radiusKm,
    required this.resultsCount,
  });

  final String? date;
  final String priceMode;
  final String timeOfDay;
  final Set<String> categories;
  final double radiusKm;
  final int resultsCount;

  @override
  State<_AfficheFilterSheet> createState() => _AfficheFilterSheetState();
}

class _AfficheFilterSheetState extends State<_AfficheFilterSheet> {
  late String? _date = widget.date;
  late String _priceMode = widget.priceMode;
  late String _timeOfDay = widget.timeOfDay;
  late Set<String> _categories = {...widget.categories};
  late double _radiusKm = widget.radiusKm;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.64,
      minChildSize: 0.42,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          key: const Key('affiche-v5-filter-sheet'),
          decoration: BoxDecoration(
            color: BbV5Colors.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.card,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BbV5Colors.hair,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Фильтры афиши',
                        style: bbV5DisplayStyle(
                          fontSize: 22,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _date = null;
                          _priceMode = 'any';
                          _timeOfDay = 'any';
                          _categories = {};
                          _radiusKm = 30;
                        });
                      },
                      child: Text(
                        'Сбросить',
                        style: AppTextStyles.meta.copyWith(
                          color: BbV5Colors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    _FilterGroup(
                      title: 'Когда',
                      options: _rangeDateOptions(),
                      activeValue: _date,
                      onChanged: (value) => setState(() => _date = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FilterGroup(
                      title: 'Время суток',
                      options: _timeOfDayOptions,
                      activeValue: _timeOfDay,
                      onChanged: (value) =>
                          setState(() => _timeOfDay = value ?? 'any'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _MultiFilterGroup(
                      title: 'Категории',
                      options: afficheCategoryOptions
                          .where((option) => option.value != null)
                          .toList(growable: false),
                      activeValues: _categories,
                      onChanged: (value) {
                        setState(() {
                          if (_categories.contains(value)) {
                            _categories = {..._categories}..remove(value);
                          } else {
                            _categories = {..._categories, value};
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Радиус · ${_radiusKm.round()} км',
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    Slider(
                      value: _radiusKm,
                      min: 0,
                      max: 30,
                      divisions: 30,
                      activeColor: BbV5Colors.accent,
                      inactiveColor: BbV5Colors.hair,
                      label: '${_radiusKm.round()} км',
                      onChanged: (value) => setState(() {
                        _radiusKm = value;
                      }),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: _RadiusScaleLabels(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FilterGroup(
                      title: 'Цена',
                      options: affichePriceOptions,
                      activeValue: _priceMode,
                      onChanged: (value) =>
                          setState(() => _priceMode = value ?? 'any'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _AfficheFilterSelection(
                      date: _date,
                      priceMode: _priceMode,
                      timeOfDay: _timeOfDay,
                      categories: _categories,
                      radiusKm: _radiusKm,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: BbV5Colors.ink,
                    foregroundColor: BbV5Colors.paperHi,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Показать события · ${widget.resultsCount}',
                    style: AppTextStyles.button.copyWith(
                      color: BbV5Colors.paperHi,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<AfficheFilterOption> _rangeDateOptions() {
  final options = afficheDateOptions();
  final today = options.length > 1 ? options[1].value : null;
  final tomorrow = options.length > 2 ? options[2].value : null;
  final weekend = options.length > 6 ? options[6].value : null;
  return [
    const AfficheFilterOption(label: 'Все даты'),
    AfficheFilterOption(label: 'Сегодня', value: today),
    AfficheFilterOption(label: 'Завтра', value: tomorrow),
    AfficheFilterOption(label: 'Выходные', value: weekend),
    const AfficheFilterOption(label: 'Неделя', value: 'week'),
  ];
}

const _timeOfDayOptions = [
  AfficheFilterOption(label: 'Любое', value: 'any'),
  AfficheFilterOption(label: 'Утро', value: 'morning'),
  AfficheFilterOption(label: 'День', value: 'day'),
  AfficheFilterOption(label: 'Вечер', value: 'evening'),
  AfficheFilterOption(label: 'Ночь', value: 'night'),
];

class _RadiusScaleLabels extends StatelessWidget {
  const _RadiusScaleLabels();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppTextStyles.meta.copyWith(
      fontFamily: 'Sora',
      color: colors.inkMute,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      height: 1.1,
      letterSpacing: 1.47,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('ВСЕ', style: style),
        Text('10 км', style: style),
        Text('20 км', style: style),
        Text('30 км', style: style),
      ],
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.options,
    required this.activeValue,
    required this.onChanged,
  });

  final String title;
  final List<AfficheFilterOption> options;
  final String? activeValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.meta.copyWith(
            color: AppColors.of(context).inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in options)
              AfficheFilterChip(
                label: option.label,
                icon: option.icon,
                active: activeValue == option.value,
                onTap: () => onChanged(option.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _MultiFilterGroup extends StatelessWidget {
  const _MultiFilterGroup({
    required this.title,
    required this.options,
    required this.activeValues,
    required this.onChanged,
  });

  final String title;
  final List<AfficheFilterOption> options;
  final Set<String> activeValues;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.meta.copyWith(
            color: AppColors.of(context).inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in options)
              AfficheFilterChip(
                label: option.label,
                icon: option.icon,
                active: activeValues.contains(option.value),
                onTap: () {
                  final value = option.value;
                  if (value != null) {
                    onChanged(value);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}
