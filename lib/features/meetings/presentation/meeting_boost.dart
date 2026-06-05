import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';

enum MeetingBoostTone { lime, pink, gold }

class MeetingBoostTier {
  const MeetingBoostTier({
    required this.id,
    required this.optionId,
    required this.hours,
    required this.label,
    required this.price,
    required this.description,
    required this.badge,
    required this.tone,
    required this.icon,
  });

  final String id;
  final String optionId;
  final int hours;
  final String label;
  final int price;
  final String description;
  final String badge;
  final MeetingBoostTone tone;
  final IconData icon;
}

const meetingBoostTiers = [
  MeetingBoostTier(
    id: '1h',
    optionId: 'boost-6',
    hours: 1,
    label: 'Импульс',
    price: 100,
    description: 'Топ радара · 1 час',
    badge: 'Boost 1ч',
    tone: MeetingBoostTone.lime,
    icon: LucideIcons.zap,
  ),
  MeetingBoostTier(
    id: '5h',
    optionId: 'boost-24',
    hours: 5,
    label: 'Разгон',
    price: 300,
    description: 'Топ радара + карта · 5 часов',
    badge: 'Boost 5ч',
    tone: MeetingBoostTone.pink,
    icon: LucideIcons.flame,
  ),
  MeetingBoostTier(
    id: '24h',
    optionId: 'boost-72',
    hours: 24,
    label: 'Сутки',
    price: 500,
    description: 'Закреп в радаре, карте, афише · 24 часа',
    badge: 'Boost 24ч',
    tone: MeetingBoostTone.gold,
    icon: LucideIcons.crown,
  ),
];

MeetingBoostTier? meetingBoostTierByOption(String? optionId) {
  if (optionId == null || optionId.isEmpty) {
    return null;
  }
  for (final tier in meetingBoostTiers) {
    if (tier.optionId == optionId) {
      return tier;
    }
  }
  return null;
}

MeetingBoostTier? meetingBoostTierById(String? id) {
  if (id == null || id.isEmpty) {
    return null;
  }
  for (final tier in meetingBoostTiers) {
    if (tier.id == id) {
      return tier;
    }
  }
  return null;
}

MeetingBoostTier? meetingBoostTierFromRaw(Map<String, Object?> raw) {
  if (raw['promoted'] == false) {
    return null;
  }
  final boost = raw['boost'];
  if (boost is Map) {
    return meetingBoostTierByOption(boost['optionId']?.toString()) ??
        meetingBoostTierById(boost['tierId']?.toString());
  }
  final tier = meetingBoostTierByOption(raw['boostOptionId']?.toString()) ??
      meetingBoostTierById(raw['boostTier']?.toString()) ??
      meetingBoostTierById(raw['boostTierId']?.toString());
  if (tier != null) {
    return tier;
  }
  if (raw['promoted'] == true) {
    return meetingBoostTierByOption(raw['promotionOptionId']?.toString());
  }
  return null;
}

class MeetingBoostVisual {
  const MeetingBoostVisual({
    required this.primary,
    required this.foreground,
    required this.gradient,
    required this.glow,
  });

  final Color primary;
  final Color foreground;
  final LinearGradient gradient;
  final Color glow;
}

MeetingBoostVisual meetingBoostVisual(MeetingBoostTier tier) {
  switch (tier.tone) {
    case MeetingBoostTone.gold:
      return const MeetingBoostVisual(
        primary: Color(0xFFFFD86B),
        foreground: DateasyColors.backgroundDeep,
        gradient: LinearGradient(
          colors: [Color(0xFFFFE18A), Color(0xFFFFB84D)],
        ),
        glow: Color(0x99FFD86B),
      );
    case MeetingBoostTone.pink:
      return const MeetingBoostVisual(
        primary: DateasyColors.pink,
        foreground: DateasyColors.foreground,
        gradient: dateasyPinkGradient,
        glow: Color(0x99FF639F),
      );
    case MeetingBoostTone.lime:
      return const MeetingBoostVisual(
        primary: DateasyColors.lime,
        foreground: DateasyColors.backgroundDeep,
        gradient: dateasyLimeGradient,
        glow: Color(0x80BEFF67),
      );
  }
}

class MeetingBoostBadge extends StatelessWidget {
  const MeetingBoostBadge({
    super.key,
    required this.tier,
    this.compact = false,
  });

  final MeetingBoostTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visual = meetingBoostVisual(tier);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: visual.gradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: visual.glow.withValues(alpha: 0.34),
            blurRadius: compact ? 12 : 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tier.icon,
            size: compact ? 11 : 13,
            color: visual.foreground,
          ),
          SizedBox(width: compact ? 3 : 5),
          Text(
            compact ? '${tier.hours}ч' : tier.badge,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: visual.foreground,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }
}
