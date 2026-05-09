import 'dart:async';
import 'dart:ui';

import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/search_results.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> showV5SearchModal(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Закрыть поиск',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _V5SearchOverlay(originContext: context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

const _searchRecentKey = 'v5.search.recent';

enum _V5SearchKind { all, meetup, club, person, route, affiche }

class _V5SearchFilter {
  const _V5SearchFilter(this.kind, this.label);

  final _V5SearchKind kind;
  final String label;
}

class _V5SearchItem {
  const _V5SearchItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.id,
  });

  final _V5SearchKind kind;
  final String title;
  final String subtitle;
  final String? id;
}

const _searchFilters = [
  _V5SearchFilter(_V5SearchKind.all, 'Всё'),
  _V5SearchFilter(_V5SearchKind.meetup, 'Встречи'),
  _V5SearchFilter(_V5SearchKind.club, 'Клубы'),
  _V5SearchFilter(_V5SearchKind.person, 'Люди'),
  _V5SearchFilter(_V5SearchKind.route, 'Маршруты'),
  _V5SearchFilter(_V5SearchKind.affiche, 'Афиша'),
];

class _V5SearchOverlay extends ConsumerStatefulWidget {
  const _V5SearchOverlay({required this.originContext});

  final BuildContext originContext;

  @override
  ConsumerState<_V5SearchOverlay> createState() => _V5SearchOverlayState();
}

class _V5SearchOverlayState extends ConsumerState<_V5SearchOverlay> {
  late final TextEditingController _controller;
  late final Future<SharedPreferences> _preferencesFuture;
  Timer? _searchDebounce;
  var _searchGeneration = 0;
  var _query = '';
  var _filter = _V5SearchKind.all;
  var _recent = const <String>[];
  var _remoteItems = const <_V5SearchItem>[];
  var _searching = false;
  var _searchFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final preferences = ref.read(sharedPreferencesProvider);
    _preferencesFuture = preferences == null
        ? SharedPreferences.getInstance()
        : Future.value(preferences);
    unawaited(_loadRecent());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchGeneration += 1;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await _preferencesFuture;
    if (!mounted) {
      return;
    }
    setState(() {
      _recent = prefs.getStringList(_searchRecentKey) ?? const <String>[];
    });
  }

  Future<void> _rememberRecent(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) {
      return;
    }
    final next = [clean, ..._recent.where((item) => item != clean)]
        .take(5)
        .toList(growable: false);
    if (mounted) {
      setState(() => _recent = next);
    }
    final prefs = await _preferencesFuture;
    await prefs.setStringList(_searchRecentKey, next);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const <String>[]);
    final prefs = await _preferencesFuture;
    await prefs.remove(_searchRecentKey);
  }

  List<_V5SearchItem> get _results {
    final normalized = _query.trim().toLowerCase();
    return _remoteItems.where((item) {
      if (_filter != _V5SearchKind.all && item.kind != _filter) {
        return false;
      }
      if (normalized.isEmpty) {
        return true;
      }
      final source = '${item.title} ${item.subtitle}'.toLowerCase();
      return source.contains(normalized);
    }).toList(growable: false);
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _searchFailed = false;
    });
    _searchDebounce?.cancel();
    final clean = value.trim();
    if (clean.isEmpty) {
      _searchGeneration += 1;
      setState(() {
        _remoteItems = const [];
        _searching = false;
      });
      return;
    }

    final generation = ++_searchGeneration;
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(_loadRemoteResults(clean, generation));
    });
  }

  Future<void> _loadRemoteResults(String query, int generation) async {
    final repository = ref.read(backendRepositoryProvider);
    final city = _searchCity(ref.read(manualLocationProvider));
    if (mounted) {
      setState(() {
        _searching = true;
        _searchFailed = false;
      });
    }

    try {
      final results = await repository.fetchGroupedSearch(
        q: query,
        city: city,
      );
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _remoteItems = _itemsFromGroupedResults(results);
        _searching = false;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _remoteItems = const [];
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _openItem(_V5SearchItem item) {
    unawaited(_rememberRecent(item.title));
    _close();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final origin = widget.originContext;
      if (!origin.mounted) {
        return;
      }

      switch (item.kind) {
        case _V5SearchKind.all:
        case _V5SearchKind.meetup:
          final eventId = item.id;
          if (eventId == null || eventId.isEmpty) {
            origin.goRoute(AppRoute.tonight);
          } else {
            origin.pushRoute(
              AppRoute.eventDetail,
              pathParameters: {'eventId': eventId},
            );
          }
        case _V5SearchKind.club:
          origin.goRoute(AppRoute.communities);
        case _V5SearchKind.person:
          origin.goRoute(AppRoute.dating);
        case _V5SearchKind.route:
          final templateId = item.id;
          if (templateId == null || templateId.isEmpty) {
            origin.pushRoute(AppRoute.eveningRoutes);
          } else {
            origin.pushRoute(
              AppRoute.eveningRouteDetail,
              pathParameters: {'templateId': templateId},
            );
          }
        case _V5SearchKind.affiche:
          final eventId = item.id;
          if (eventId == null || eventId.isEmpty) {
            origin.pushRoute(AppRoute.affiche);
          } else {
            origin.pushRoute(
              AppRoute.afficheEvent,
              pathParameters: {'eventId': eventId},
            );
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final modalMaxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final resultsMaxHeight =
        (modalMaxHeight - 156).clamp(160.0, 460.0).toDouble();
    final results = _results;
    final showRecent = _query.trim().isEmpty && _recent.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ColoredBox(
                  color: BbV5Colors.ink.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    maxHeight: modalMaxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [BbV5Colors.paperHi, BbV5Colors.paper],
                      ),
                      border: Border.all(color: BbV5Colors.hair),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4A1F241D),
                          blurRadius: 36,
                          spreadRadius: -14,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _V5SearchInput(
                                  controller: _controller,
                                  onChanged: _onQueryChanged,
                                  onSubmitted: (value) {
                                    unawaited(_rememberRecent(value));
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              _V5SearchCloseButton(onTap: _close),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 32,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.hardEdge,
                              itemBuilder: (context, index) {
                                final filter = _searchFilters[index];
                                return _V5SearchFilterChip(
                                  label: filter.label,
                                  active: filter.kind == _filter,
                                  onTap: () {
                                    setState(() => _filter = filter.kind);
                                  },
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemCount: _searchFilters.length,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: resultsMaxHeight,
                            ),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              children: [
                                if (showRecent) ...[
                                  _V5SearchRecentHeader(
                                    onClear: () => unawaited(_clearRecent()),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final recent in _recent) ...[
                                    _V5SearchRecentRow(
                                      title: recent,
                                      onTap: () {
                                        _controller.text = recent;
                                        _controller.selection =
                                            TextSelection.collapsed(
                                          offset: recent.length,
                                        );
                                        setState(() => _query = recent);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      top: 2,
                                      bottom: 8,
                                    ),
                                    child: BbV5Kicker('Подсказки'),
                                  ),
                                ],
                                for (var index = 0;
                                    index < results.length;
                                    index++) ...[
                                  _V5SearchResultRow(
                                    item: results[index],
                                    onTap: () => _openItem(results[index]),
                                  ),
                                  if (index != results.length - 1)
                                    const SizedBox(height: 6),
                                ],
                                if (_searching)
                                  const _V5SearchLoadingState()
                                else if (_searchFailed)
                                  const _V5SearchEmptyState(
                                    title: 'Поиск не загрузился',
                                    subtitle: 'Проверь соединение',
                                  )
                                else if (results.isEmpty)
                                  const _V5SearchEmptyState(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
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
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: BbV5Colors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Найти людей, клубы, места...',
                hintStyle: AppTextStyles.body.copyWith(
                  fontSize: 14,
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

class _V5SearchCloseButton extends StatelessWidget {
  const _V5SearchCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            shape: BoxShape.circle,
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: const Icon(
            LucideIcons.x,
            size: 17,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

class _V5SearchFilterChip extends StatelessWidget {
  const _V5SearchFilterChip({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Ink(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontFamily: 'Sora',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.23,
                color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _V5SearchResultRow extends StatelessWidget {
  const _V5SearchResultRow({
    required this.item,
    required this.onTap,
  });

  final _V5SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: Icon(
                  _searchIcon(item.kind),
                  size: 16,
                  color: BbV5Colors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.26,
                        color: BbV5Colors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.map_pin,
                          size: 11,
                          color: BbV5Colors.inkMute,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              letterSpacing: 0,
                              color: BbV5Colors.inkMute,
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
        ),
      ),
    );
  }
}

class _V5SearchRecentHeader extends StatelessWidget {
  const _V5SearchRecentHeader({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: BbV5Kicker('Недавние')),
        InkWell(
          onTap: onClear,
          borderRadius: BorderRadius.circular(BbV5Radii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              'Очистить',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                letterSpacing: 0,
                color: BbV5Colors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _V5SearchRecentRow extends StatelessWidget {
  const _V5SearchRecentRow({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.clock,
                size: 15,
                color: BbV5Colors.inkMute,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12.5,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                    color: BbV5Colors.ink,
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

class _V5SearchEmptyState extends StatelessWidget {
  const _V5SearchEmptyState({
    this.title = 'Ничего не нашли',
    this.subtitle = 'Попробуй другой запрос',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: bbV5DisplayStyle(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              letterSpacing: 0,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _V5SearchLoadingState extends StatelessWidget {
  const _V5SearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: BbV5Colors.accent,
        ),
      ),
    );
  }
}

List<_V5SearchItem> _itemsFromGroupedResults(GroupedSearchResults results) {
  return [
    for (final event in results.meetups)
      _V5SearchItem(
        id: event.id,
        kind: _V5SearchKind.meetup,
        title: event.title,
        subtitle: event.place,
      ),
    for (final route in results.routes)
      _V5SearchItem(
        id: route.id,
        kind: _V5SearchKind.route,
        title: route.title,
        subtitle: route.area == null || route.area!.trim().isEmpty
            ? route.city
            : '${route.city} · ${route.area}',
      ),
    for (final event in results.affiche)
      _V5SearchItem(
        id: event.id,
        kind: _V5SearchKind.affiche,
        title: event.title,
        subtitle: event.placeLabel,
      ),
  ];
}

String _searchCity(ManualLocation? manualLocation) {
  final city = manualLocation?.city?.trim();
  if (city != null && city.isNotEmpty) {
    return city;
  }
  final label = manualLocation?.label.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return 'Москва';
}

IconData _searchIcon(_V5SearchKind kind) {
  return switch (kind) {
    _V5SearchKind.person => LucideIcons.users,
    _V5SearchKind.club => LucideIcons.heart,
    _V5SearchKind.meetup => LucideIcons.calendar,
    _V5SearchKind.route => LucideIcons.route,
    _V5SearchKind.affiche => LucideIcons.ticket,
    _V5SearchKind.all => LucideIcons.search,
  };
}
