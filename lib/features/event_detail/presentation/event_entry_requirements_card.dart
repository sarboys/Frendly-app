import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class EventEntryRequirementsCard extends StatelessWidget {
  const EventEntryRequirementsCard({
    required this.requirements,
    super.key,
  });

  final EventEntryRequirements requirements;

  @override
  Widget build(BuildContext context) {
    if (!requirements.hasMissing) {
      return const SizedBox.shrink();
    }

    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      borderColor: BbV5Colors.accent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _RequirementIconBubble(icon: LucideIcons.lock),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Нужен доступ',
                  style: bbV5DisplayStyle(fontSize: 18, height: 1.15),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Чтобы вступить в эту встречу, выполни условия хоста.',
            style: AppTextStyles.bodySoft.copyWith(
              color: BbV5Colors.inkSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final requirement in requirements.missing)
                BbV5Chip(
                  label: eventEntryRequirementLabel(requirement),
                  icon: eventEntryRequirementIcon(requirement),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class EventEntryRequirementActions extends StatelessWidget {
  const EventEntryRequirementActions({
    required this.requirements,
    required this.onTap,
    this.dark = true,
    super.key,
  });

  final EventEntryRequirements requirements;
  final ValueChanged<EventEntryRequirement> onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final missing = requirements.missing;
    if (missing.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < missing.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xs),
          BbV5PillButton(
            label: eventEntryRequirementActionLabel(missing[index]),
            icon: eventEntryRequirementIcon(missing[index]),
            dark: dark,
            height: 52,
            fontSize: 13,
            expanded: true,
            onPressed: () => onTap(missing[index]),
          ),
        ],
      ],
    );
  }
}

String eventEntryRequirementLabel(EventEntryRequirement requirement) {
  switch (requirement) {
    case EventEntryRequirement.verification:
      return 'Верификация';
    case EventEntryRequirement.frendlyPlus:
      return 'Frendly+';
  }
}

String eventEntryRequirementActionLabel(EventEntryRequirement requirement) {
  switch (requirement) {
    case EventEntryRequirement.verification:
      return 'Пройти верификацию';
    case EventEntryRequirement.frendlyPlus:
      return 'Оформить Frendly+';
  }
}

IconData eventEntryRequirementIcon(EventEntryRequirement requirement) {
  switch (requirement) {
    case EventEntryRequirement.verification:
      return LucideIcons.badge_check;
    case EventEntryRequirement.frendlyPlus:
      return LucideIcons.sparkles;
  }
}

class _RequirementIconBubble extends StatelessWidget {
  const _RequirementIconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: BbV5Colors.accent,
        shape: BoxShape.circle,
        boxShadow: BbV5Shadows.pill,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 19,
        color: BbV5Colors.paperHi,
      ),
    );
  }
}
