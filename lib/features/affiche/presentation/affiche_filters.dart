import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AfficheFilterOption {
  const AfficheFilterOption({
    required this.label,
    this.value,
    this.icon,
  });

  final String label;
  final String? value;
  final IconData? icon;
}

const affichePriceOptions = [
  AfficheFilterOption(label: 'Все', value: 'any'),
  AfficheFilterOption(label: 'Платные', value: 'paid'),
  AfficheFilterOption(label: 'Бесплатные', value: 'free'),
];

const afficheCategoryOptions = [
  AfficheFilterOption(label: 'Все', icon: LucideIcons.sparkles),
  AfficheFilterOption(
    label: 'Концерты',
    value: 'concert',
    icon: LucideIcons.music,
  ),
  AfficheFilterOption(
    label: 'Театр',
    value: 'theatre',
    icon: LucideIcons.venetian_mask,
  ),
  AfficheFilterOption(
    label: 'Культура',
    value: 'culture',
    icon: LucideIcons.landmark,
  ),
  AfficheFilterOption(
    label: 'Стендап',
    value: 'standup',
    icon: LucideIcons.mic,
  ),
  AfficheFilterOption(
    label: 'Кино',
    value: 'cinema',
    icon: LucideIcons.clapperboard,
  ),
  AfficheFilterOption(
    label: 'Спорт',
    value: 'sport',
    icon: LucideIcons.dumbbell,
  ),
  AfficheFilterOption(
    label: 'Фестивали',
    value: 'festival',
    icon: LucideIcons.party_popper,
  ),
  AfficheFilterOption(
    label: 'Лекции',
    value: 'lecture',
    icon: LucideIcons.presentation,
  ),
  AfficheFilterOption(
    label: 'Мастерские',
    value: 'workshop',
    icon: LucideIcons.palette,
  ),
];

List<AfficheFilterOption> afficheDateOptions([DateTime? now]) {
  final base = now ?? DateTime.now();
  final today = DateTime(base.year, base.month, base.day);
  return [
    const AfficheFilterOption(label: 'Все даты'),
    for (var offset = 0; offset < 7; offset += 1)
      AfficheFilterOption(
        label: _dateOptionLabel(today.add(Duration(days: offset)), offset),
        value: _isoDate(today.add(Duration(days: offset))),
      ),
  ];
}

class AfficheSearchField extends StatelessWidget {
  const AfficheSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
    this.hintText = 'Событие, артист, площадка',
    this.height = 44,
    this.iconSize = 16,
    this.fontSize = 13,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final double height;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: iconSize, color: colors.inkMute),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: AppTextStyles.bodySoft.copyWith(
                  color: colors.inkMute,
                  fontSize: fontSize,
                  height: 1.2,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTextStyles.bodySoft.copyWith(
                color: colors.foreground,
                fontSize: fontSize,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AfficheFilterSection extends StatelessWidget {
  const AfficheFilterSection({
    required this.options,
    required this.activeValue,
    required this.onChanged,
    super.key,
  });

  final List<AfficheFilterOption> options;
  final String? activeValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final option = options[index];
          return AfficheFilterChip(
            label: option.label,
            icon: option.icon,
            active: activeValue == option.value,
            onTap: () => onChanged(option.value),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemCount: options.length,
      ),
    );
  }
}

class AfficheFilterChip extends StatelessWidget {
  const AfficheFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = active ? colors.background : colors.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.foreground : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? colors.foreground : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.meta.copyWith(
                fontFamily: 'Sora',
                color: foreground,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.1,
                letterSpacing: 0.23,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String afficheCity(WidgetRef ref) {
  final manualLocation = ref.watch(manualLocationProvider);
  final raw = manualLocation?.city ?? manualLocation?.label;
  final normalized = raw
          ?.toLowerCase()
          .replaceAll('ё', 'е')
          .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
          .trim() ??
      '';
  if (normalized.contains('санкт петербург') ||
      normalized.contains('saint petersburg') ||
      normalized.contains('st petersburg') ||
      RegExp(r'(^|\s)(спб|питер)(\s|$)').hasMatch(normalized)) {
    return 'Санкт-Петербург';
  }
  return 'Москва';
}

String _dateOptionLabel(DateTime date, int offset) {
  if (offset == 0) {
    return 'Сегодня';
  }
  if (offset == 1) {
    return 'Завтра';
  }
  return '${_weekdayLabel(date.weekday)} ${date.day}';
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Пн';
    case DateTime.tuesday:
      return 'Вт';
    case DateTime.wednesday:
      return 'Ср';
    case DateTime.thursday:
      return 'Чт';
    case DateTime.friday:
      return 'Пт';
    case DateTime.saturday:
      return 'Сб';
    case DateTime.sunday:
      return 'Вс';
    default:
      return '';
  }
}

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
