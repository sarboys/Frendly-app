import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/widgets/bb_bottom_nav.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EveningRouteDetailScreen extends ConsumerWidget {
  const EveningRouteDetailScreen({
    required this.templateId,
    this.wantLaunch = false,
    super.key,
  });

  final String templateId;
  final bool wantLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(eveningRouteTemplateProvider(templateId));

    return detailAsync.when(
      data: (route) => _RouteDetailContent(
        route: route,
      ),
      loading: () => const _RouteDetailLoading(),
      error: (_, __) => const _RouteDetailMissing(),
    );
  }
}

class _RouteDetailContent extends StatelessWidget {
  const _RouteDetailContent({
    required this.route,
  });

  final EveningRouteTemplateDetail route;

  @override
  Widget build(BuildContext context) {
    return BbV5Scaffold(
      extendBody: true,
      bottomNavigationBar: BbV5GlassBottomBar(
        child: BbBottomNav(
          location: AppRoute.eveningRoutes.path,
          onTap: (tab) => context.goRoute(tab.route),
        ),
      ),
      child: Stack(
        children: [
          BbV5Page(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Column(
              children: [
                _RouteDetailHeader(route: route),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 188),
                    children: [
                      _RouteHero(route: route),
                      const SizedBox(height: 22),
                      const BbV5Kicker('Шаги вечера'),
                      const SizedBox(height: 12),
                      _RouteSteps(steps: route.steps),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 82 + MediaQuery.paddingOf(context).bottom,
            child: _RouteStickyCta(
              onLaunch: () => context.pushRoute(
                AppRoute.createEveningSession,
                pathParameters: {'templateId': route.id},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailHeader extends StatelessWidget {
  const _RouteDetailHeader({
    required this.route,
  });

  final EveningRouteTemplateDetail route;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: () async {
            final popped = await Navigator.of(context).maybePop();
            if (!popped && context.mounted) {
              context.goRoute(AppRoute.eveningRoutes);
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BbV5Kicker('Маршрут вечера'),
              const SizedBox(height: 2),
              Text(
                route.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bbV5DisplayStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        BbV5IconButton(
          icon: LucideIcons.share_2,
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: '/routes/${route.id}'),
            );
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ссылка скопирована')),
            );
          },
        ),
      ],
    );
  }
}

class _RouteHero extends StatelessWidget {
  const _RouteHero({
    required this.route,
  });

  final EveningRouteTemplateDetail route;

  @override
  Widget build(BuildContext context) {
    final titleParts = _routeTitleParts(route.title);
    final area = route.area ?? route.city;

    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((route.recommendedFor ?? '').trim().isNotEmpty) ...[
            BbV5Kicker(route.recommendedFor!),
            const SizedBox(height: 6),
          ],
          BbV5HeroTitle(
            title: titleParts.title,
            accent: titleParts.accent,
            fontSize: 24,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Text(
            route.blurb,
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkSoft,
              fontSize: 13,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _RouteHeroStat(
                  icon: LucideIcons.clock,
                  value: _firstSegment(route.durationLabel),
                  label: route.durationLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RouteHeroStat(
                  icon: LucideIcons.map_pin,
                  value: _firstSegment(area),
                  label: area,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RouteHeroStat(
                  icon: LucideIcons.users,
                  value: '${route.hostsCount}',
                  label: 'идут',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: BbV5Colors.hairSoft),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Бюджет от',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkSoft,
                      fontSize: 11,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_formatRubles(route.totalPriceFrom)}₽',
                    style: bbV5DisplayStyle(fontSize: 18).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (route.totalSavings > 0)
                    _RouteSavingsBadge(value: route.totalSavings),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHeroStat extends StatelessWidget {
  const _RouteHeroStat({
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: BbV5Colors.inkMute),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bbV5DisplayStyle(fontSize: 14, height: 1),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 10,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSavingsBadge extends StatelessWidget {
  const _RouteSavingsBadge({
    required this.value,
  });

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
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
            'экономия -${_formatRubles(value)}₽',
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.terra,
              fontFamily: 'Sora',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSteps extends StatelessWidget {
  const _RouteSteps({
    required this.steps,
  });

  final List<EveningRouteTemplateStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const BbV5Card(
        radius: 22,
        padding: EdgeInsets.all(18),
        child: Text('Шаги появятся после сборки маршрута'),
      );
    }

    return Stack(
      children: [
        const Positioned(
          left: 27,
          top: 12,
          bottom: 12,
          child: SizedBox(
            width: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: BbV5Colors.hair),
            ),
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              _RouteStepCard(
                step: steps[index],
                index: index,
                isLast: index == steps.length - 1,
              ),
              if (index != steps.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _RouteStepCard extends StatelessWidget {
  const _RouteStepCard({
    required this.step,
    required this.index,
    required this.isLast,
  });

  final EveningRouteTemplateStep step;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final timeLabel = [
      step.time,
      if ((step.endTime ?? '').isNotEmpty) step.endTime!,
    ].join(' — ');

    return Padding(
      padding: const EdgeInsets.only(left: 0),
      child: BbV5Card(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(58, 16, 16, 16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -46,
              top: 0,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                alignment: Alignment.center,
                child: Text(
                  step.emoji,
                  style: const TextStyle(fontSize: 18, height: 1),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$timeLabel · шаг ${index + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: BbV5Colors.inkMute,
                              fontFamily: 'Sora',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.6,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.itemTitle.copyWith(
                              color: BbV5Colors.ink,
                              fontFamily: 'Sora',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${step.venue} · ${step.address}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: BbV5Colors.inkSoft,
                              fontSize: 11.5,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((step.perkShort ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _StepPerkBadge(label: step.perkShort!),
                    ],
                  ],
                ),
                if ((step.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    step.description!,
                    style: AppTextStyles.meta.copyWith(
                      color: BbV5Colors.inkSoft,
                      fontSize: 12,
                      height: 1.625,
                    ),
                  ),
                ],
                if (step.walkMin != null && !isLast) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.map_pin,
                        size: 12,
                        color: BbV5Colors.inkMute,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '~${step.walkMin} мин пешком до следующего',
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPerkBadge extends StatelessWidget {
  const _StepPerkBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.tag,
            size: 11,
            color: BbV5Colors.terra,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.terra,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStickyCta extends StatelessWidget {
  const _RouteStickyCta({
    required this.onLaunch,
  });

  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00F1E6D6),
              Color(0xF2F1E6D6),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: BbV5PillButton(
                label: 'Опубликовать встречу',
                icon: LucideIcons.play,
                onPressed: onLaunch,
                dark: true,
                height: 56,
                fontSize: 14,
                expanded: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteDetailLoading extends StatelessWidget {
  const _RouteDetailLoading();

  @override
  Widget build(BuildContext context) {
    return const BbV5Scaffold(
      child: Center(
        child: BbV5Card(
          padding: EdgeInsets.all(24),
          radius: 24,
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              color: BbV5Colors.ink,
              strokeWidth: 2.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteDetailMissing extends StatelessWidget {
  const _RouteDetailMissing();

  @override
  Widget build(BuildContext context) {
    return BbV5Scaffold(
      child: BbV5Page(
        child: Center(
          child: BbV5Card(
            padding: const EdgeInsets.all(28),
            radius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.map_pin_off,
                  color: BbV5Colors.terra,
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  'Маршрут не найден',
                  style: bbV5DisplayStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({String title, String? accent}) _routeTitleParts(String title) {
  const marker = ' на ';
  if (!title.contains(marker)) {
    return (title: title, accent: null);
  }
  final parts = title.split(marker);
  if (parts.length < 2) {
    return (title: title, accent: null);
  }
  return (title: parts.first, accent: 'на ${parts.sublist(1).join(marker)}');
}

String _firstSegment(String value) {
  if (value.contains(' - ')) {
    return value.split(' - ').first;
  }
  if (value.contains(' — ')) {
    return value.split(' — ').first;
  }
  if (value.contains(' → ')) {
    return value.split(' → ').first;
  }
  return value;
}

String _formatRubles(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final left = raw.length - index;
    buffer.write(raw[index]);
    if (left > 1 && left % 3 == 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}
