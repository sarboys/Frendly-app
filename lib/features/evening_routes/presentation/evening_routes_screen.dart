import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/evening_route_card.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/widgets/bb_bottom_nav.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EveningRoutesScreen extends ConsumerStatefulWidget {
  const EveningRoutesScreen({super.key});

  @override
  ConsumerState<EveningRoutesScreen> createState() =>
      _EveningRoutesScreenState();
}

class _EveningRoutesScreenState extends ConsumerState<EveningRoutesScreen> {
  final _searchController = TextEditingController();
  String _activeMood = 'all';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final onboarding = ref.watch(onboardingProvider).valueOrNull;
    final city = _resolveCity(profile?.city, onboarding?.city);
    final routesAsync = ref.watch(eveningRouteTemplatesProvider(city));

    return BbV5Scaffold(
      extendBody: true,
      bottomNavigationBar: BbV5GlassBottomBar(
        child: BbBottomNav(
          location: AppRoute.eveningRoutes.path,
          onTap: (tab) => context.goRoute(tab.route),
        ),
      ),
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
        child: Column(
          children: [
            _RoutesHeader(
              onBack: _goBack,
              onOpenBuilder: _openBuilder,
            ),
            const SizedBox(height: 20),
            _RouteSearchBox(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _query = value;
              }),
            ),
            const SizedBox(height: 16),
            _MoodChips(
              activeMood: _activeMood,
              onChanged: (value) => setState(() {
                _activeMood = value;
              }),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: routesAsync.when(
                data: (routes) {
                  final filtered = _filterRoutes(routes);
                  return _RoutesContent(
                    routes: filtered,
                    city: city,
                    onOpenRoute: _openRoute,
                    onLaunchRoute: _launchRoute,
                    onReset: _resetFilters,
                  );
                },
                loading: () => const _RouteListLoading(),
                error: (_, __) => _RouteCatalogEmpty(onReset: _resetFilters),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<EveningRouteTemplateSummary> _filterRoutes(
    List<EveningRouteTemplateSummary> routes,
  ) {
    final query = _query.trim().toLowerCase();
    return routes.where((route) {
      if (_activeMood != 'all' && route.mood != _activeMood) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        route.title,
        route.area,
        route.blurb,
        route.stepsPreview.map((step) => step.venue).join(' '),
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  void _resetFilters() {
    setState(() {
      _activeMood = 'all';
      _query = '';
      _searchController.clear();
    });
  }

  void _openRoute(EveningRouteTemplateSummary route) {
    context.pushRoute(
      AppRoute.eveningRouteDetail,
      pathParameters: {'templateId': route.id},
    );
  }

  void _launchRoute(EveningRouteTemplateSummary route) {
    context.pushRoute(
      AppRoute.eveningRouteDetail,
      pathParameters: {'templateId': route.id},
      queryParameters: const {'launch': '1'},
    );
  }

  void _openBuilder() {
    context.pushRoute(AppRoute.eveningBuilder);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goRoute(AppRoute.tonight);
  }

  String _resolveCity(String? profileCity, String? onboardingCity) {
    final fromProfile = profileCity?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    final fromOnboarding = onboardingCity?.trim();
    if (fromOnboarding != null && fromOnboarding.isNotEmpty) {
      return fromOnboarding;
    }
    return 'Москва';
  }
}

class _RoutesHeader extends StatelessWidget {
  const _RoutesHeader({
    required this.onBack,
    required this.onOpenBuilder,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenBuilder;

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
              BbV5Kicker('Frendly Routes'),
              SizedBox(height: 3),
              _RoutesHeaderTitle(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        BbV5IconButton(
          icon: LucideIcons.sparkles,
          onPressed: onOpenBuilder,
          dark: true,
          iconSize: 17,
        ),
      ],
    );
  }
}

class _RoutesHeaderTitle extends StatelessWidget {
  const _RoutesHeaderTitle();

  @override
  Widget build(BuildContext context) {
    final base = bbV5DisplayStyle(fontSize: 22, height: 1.1);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Маршруты '),
          TextSpan(
            text: 'вечера',
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}

class _RouteSearchBox extends StatelessWidget {
  const _RouteSearchBox({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return BbV5SearchPill(
      controller: controller,
      onChanged: onChanged,
      hintText: 'Найти место или район…',
    );
  }
}

class _MoodChips extends StatelessWidget {
  const _MoodChips({
    required this.activeMood,
    required this.onChanged,
  });

  final String activeMood;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 37,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final mood = _moodFilters[index];
          return _MoodChipV5(
            mood: mood,
            active: activeMood == mood.key,
            onTap: () => onChanged(mood.key),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _moodFilters.length,
      ),
    );
  }
}

class _MoodChipV5 extends StatelessWidget {
  const _MoodChipV5({
    required this.mood,
    required this.active,
    required this.onTap,
  });

  final _MoodFilter mood;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border:
                Border.all(color: active ? BbV5Colors.accent : BbV5Colors.hair),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mood.emoji != null) ...[
                Text(mood.emoji!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(
                mood.label,
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutesContent extends StatelessWidget {
  const _RoutesContent({
    required this.routes,
    required this.city,
    required this.onOpenRoute,
    required this.onLaunchRoute,
    required this.onReset,
  });

  final List<EveningRouteTemplateSummary> routes;
  final String city;
  final ValueChanged<EveningRouteTemplateSummary> onOpenRoute;
  final ValueChanged<EveningRouteTemplateSummary> onLaunchRoute;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return _RouteCatalogEmpty(onReset: onReset);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: BbV5Kicker(
              '${routes.length} ${routes.length == 1 ? 'маршрут' : 'маршрутов'} · $city',
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) {
                return const SizedBox(height: 12);
              }
              final route = routes[index ~/ 2];
              return EveningRouteCard(
                route: route,
                onOpen: () => onOpenRoute(route),
                onLaunch: () => onLaunchRoute(route),
              );
            },
            childCount: routes.length * 2 - 1,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 128)),
      ],
    );
  }
}

class _RouteListLoading extends StatelessWidget {
  const _RouteListLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _RouteSkeletonCard(),
          SizedBox(height: AppSpacing.md),
          _RouteSkeletonCard(),
          SizedBox(height: AppSpacing.md),
          _RouteSkeletonCard(),
        ],
      ),
    );
  }
}

class _RouteSkeletonCard extends StatelessWidget {
  const _RouteSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            width: 120,
            decoration: BoxDecoration(
              color: BbV5Colors.paperDeep,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 22,
            width: 220,
            decoration: BoxDecoration(
              color: BbV5Colors.paperDeep,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 14,
            width: 260,
            decoration: BoxDecoration(
              color: BbV5Colors.paperDeep,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCatalogEmpty extends StatelessWidget {
  const _RouteCatalogEmpty({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              shape: BoxShape.circle,
              border: Border.all(color: BbV5Colors.hair),
              boxShadow: BbV5Shadows.pill,
            ),
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.map_pin,
              size: 24,
              color: BbV5Colors.inkMute,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Маршрутов пока нет',
          textAlign: TextAlign.center,
          style: AppTextStyles.itemTitle.copyWith(
            color: BbV5Colors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Под выбранный фильтр ничего не нашлось. Попробуй другое настроение или сбрось фильтры.',
          textAlign: TextAlign.center,
          style: AppTextStyles.meta.copyWith(
            color: BbV5Colors.inkMute,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: BbV5Colors.ink,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: BbV5Shadows.ink,
                ),
                child: Center(
                  child: Text(
                    'Сбросить фильтры',
                    style: AppTextStyles.button.copyWith(
                      color: BbV5Colors.paperHi,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodFilter {
  const _MoodFilter({
    required this.key,
    required this.label,
    this.emoji,
  });

  final String key;
  final String label;
  final String? emoji;
}

const _moodFilters = [
  _MoodFilter(key: 'all', label: 'Все'),
  _MoodFilter(key: 'chill', emoji: '🌿', label: 'Спокойно'),
  _MoodFilter(key: 'social', emoji: '✨', label: 'Знакомства'),
  _MoodFilter(key: 'date', emoji: '🌹', label: 'Свидание'),
  _MoodFilter(key: 'wild', emoji: '🔥', label: 'Огонь'),
  _MoodFilter(key: 'outdoor', emoji: '🌳', label: 'На природе'),
  _MoodFilter(key: 'afterdark', emoji: '🌙', label: 'After Dark'),
];
