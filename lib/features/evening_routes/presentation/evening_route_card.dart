import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class EveningRouteCard extends StatelessWidget {
  const EveningRouteCard({
    required this.route,
    required this.onOpen,
    required this.onLaunch,
    this.compact = false,
    super.key,
  });

  final EveningRouteTemplateSummary route;
  final VoidCallback onOpen;
  final VoidCallback onLaunch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visibleSteps = route.stepsPreview
        .where((step) => step.kind != 'followup')
        .take(5)
        .toList(growable: false);
    final kicker = (route.badgeLabel ?? route.vibe).trim();

    return SizedBox(
      width: compact ? 300 : double.infinity,
      child: BbV5Card(
        padding: const EdgeInsets.all(20),
        radius: 24,
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kicker.isNotEmpty) ...[
                        BbV5Kicker(kicker, maxLines: 1),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        route.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bbV5DisplayStyle(fontSize: 18, height: 1.25),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        route.blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.meta.copyWith(
                          color: BbV5Colors.inkSoft,
                          fontSize: 12,
                          height: 1.625,
                        ),
                      ),
                    ],
                  ),
                ),
                if (route.totalSavings > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _SavingsBadge(value: route.totalSavings),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _RouteMeta(icon: LucideIcons.clock, label: route.durationLabel),
                _RouteMeta(
                  icon: LucideIcons.map_pin,
                  label: route.area ?? route.city,
                ),
                _RouteMeta(
                  icon: LucideIcons.users,
                  label: '${route.hostsCount}',
                ),
              ],
            ),
            if (visibleSteps.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RouteStepStrip(steps: visibleSteps),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BbV5PillButton(
                    label: 'Подробнее',
                    onPressed: onOpen,
                    height: 44,
                    fontSize: 12.5,
                    expanded: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BbV5PillButton(
                    label: 'Запустить',
                    trailingIcon: LucideIcons.chevron_right,
                    onPressed: onLaunch,
                    dark: true,
                    height: 44,
                    fontSize: 12.5,
                    expanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsBadge extends StatelessWidget {
  const _SavingsBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Text(
        '−${_formatRubles(value)}₽',
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          letterSpacing: 0.6,
          color: BbV5Colors.terra,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RouteMeta extends StatelessWidget {
  const _RouteMeta({
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkSoft,
              fontSize: 11,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteStepStrip extends StatelessWidget {
  const _RouteStepStrip({required this.steps});

  final List<EveningRouteTemplateStepPreview> steps;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi,
                shape: BoxShape.circle,
                border: Border.all(color: BbV5Colors.hair),
              ),
              child: Text(
                steps[index].emoji,
                style: const TextStyle(fontSize: 15, height: 1),
              ),
            ),
            if (index != steps.length - 1)
              Container(
                width: 12,
                height: 1,
                color: BbV5Colors.hair,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
          ],
        ],
      ),
    );
  }
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
