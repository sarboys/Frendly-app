import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/event_filters.dart';
import 'package:flutter/material.dart';

Future<EventFilters?> showEventFilterSheet(
  BuildContext context, {
  required EventFilters initialValue,
  int? resultsCount,
  int Function(EventFilters filters)? resultsCountBuilder,
}) {
  return showModalBottomSheet<EventFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EventFilterSheet(
      initialValue: initialValue,
      resultsCount: resultsCount,
      resultsCountBuilder: resultsCountBuilder,
    ),
  );
}

class _EventFilterSheet extends StatefulWidget {
  const _EventFilterSheet({
    required this.initialValue,
    this.resultsCount,
    this.resultsCountBuilder,
  });

  final EventFilters initialValue;
  final int? resultsCount;
  final int Function(EventFilters filters)? resultsCountBuilder;

  @override
  State<_EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<_EventFilterSheet> {
  late EventFilters _value = widget.initialValue;
  late final ScrollController _dateScrollController = ScrollController();
  late final List<_DateOption> _dates = _buildDateOptions();

  int? get _resultsCount =>
      widget.resultsCountBuilder?.call(_value) ?? widget.resultsCount;

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() {
                        _value = EventFilters.defaults;
                      }),
                      child: Text(
                        'Сбросить',
                        style: AppTextStyles.meta.copyWith(
                          color: colors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Фильтры',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 15),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border.withValues(alpha: 0.6)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateNavigation(
                        value: _value.date,
                        dates: _dates,
                        controller: _dateScrollController,
                        onChanged: (date) => setState(() {
                          _value = _value.copyWith(date: date);
                        }),
                      ),
                      const SizedBox(height: 14),
                      const _SectionLabel(
                        icon: Icons.eco_outlined,
                        title: 'Образ жизни',
                      ),
                      const SizedBox(height: 6),
                      GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.6,
                        children: [
                          _SegmentButton(
                            label: 'Любой',
                            active: _value.lifestyle == 'any',
                            onTap: () => setState(() {
                              _value = _value.copyWith(lifestyle: 'any');
                            }),
                          ),
                          _SegmentButton(
                            label: 'ЗОЖ',
                            icon: Icons.eco_outlined,
                            active: _value.lifestyle == 'zozh',
                            onTap: () => setState(() {
                              _value = _value.copyWith(lifestyle: 'zozh');
                            }),
                          ),
                          _SegmentButton(
                            label: 'Нейтр.',
                            active: _value.lifestyle == 'neutral',
                            onTap: () => setState(() {
                              _value = _value.copyWith(lifestyle: 'neutral');
                            }),
                          ),
                          _SegmentButton(
                            label: 'Не ЗОЖ',
                            icon: Icons.wine_bar_outlined,
                            active: _value.lifestyle == 'anti',
                            onTap: () => setState(() {
                              _value = _value.copyWith(lifestyle: 'anti');
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _SectionLabel(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Стоимость',
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ('any', 'Любая'),
                          ('free', 'Бесплатно'),
                          ('cheap', 'до 1к'),
                          ('mid', '1–3к'),
                          ('premium', '3к+'),
                        ]
                            .map(
                              (item) => _ChipButton(
                                label: item.$2,
                                active: _value.price == item.$1,
                                onTap: () => setState(() {
                                  _value = _value.copyWith(price: item.$1);
                                }),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 14),
                      const _SectionLabel(
                        icon: Icons.person_outline_rounded,
                        title: 'Состав',
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _SegmentButton(
                              label: 'Все',
                              active: _value.gender == 'any',
                              onTap: () => setState(() {
                                _value = _value.copyWith(gender: 'any');
                              }),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _SegmentButton(
                              label: 'Девушки',
                              active: _value.gender == 'female',
                              onTap: () => setState(() {
                                _value = _value.copyWith(gender: 'female');
                              }),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _SegmentButton(
                              label: 'Парни',
                              active: _value.gender == 'male',
                              onTap: () => setState(() {
                                _value = _value.copyWith(gender: 'male');
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _SectionLabel(
                        icon: Icons.shield_outlined,
                        title: 'Тип доступа',
                      ),
                      const SizedBox(height: 6),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 4.1,
                        children: [
                          _AccessButton(
                            title: 'Любой',
                            active: _value.access == 'any',
                            icon: Icons.public_rounded,
                            onTap: () => setState(() {
                              _value = _value.copyWith(access: 'any');
                            }),
                          ),
                          _AccessButton(
                            title: 'Открытое',
                            active: _value.access == 'open',
                            icon: Icons.door_front_door_outlined,
                            onTap: () => setState(() {
                              _value = _value.copyWith(access: 'open');
                            }),
                          ),
                          _AccessButton(
                            title: 'По заявке',
                            active: _value.access == 'request',
                            icon: Icons.verified_user_outlined,
                            onTap: () => setState(() {
                              _value = _value.copyWith(access: 'request');
                            }),
                          ),
                          _AccessButton(
                            title: 'Свободный',
                            active: _value.access == 'free',
                            icon: Icons.public_rounded,
                            onTap: () => setState(() {
                              _value = _value.copyWith(access: 'free');
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border.withValues(alpha: 0.6)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(_value),
                    child: Text(
                      _resultsCount != null
                          ? 'Показать $_resultsCount'
                          : 'Применить',
                      style: AppTextStyles.button.copyWith(
                        color: colors.primaryForeground,
                        fontSize: 14,
                      ),
                    ),
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

class _DateNavigation extends StatelessWidget {
  const _DateNavigation({
    required this.value,
    required this.dates,
    required this.controller,
    required this.onChanged,
  });

  final String value;
  final List<_DateOption> dates;
  final ScrollController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final anchors = _dateAnchors(dates);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          icon: Icons.calendar_month_outlined,
          title: 'Когда',
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _DateAnchorChip(
              label: 'Любая',
              active: value == 'any',
              onTap: () => onChanged('any'),
            ),
            for (final anchor in anchors)
              _DateAnchorChip(
                label: anchor.label,
                active: false,
                onTap: () => _scrollTo(anchor.index),
                showArrow: true,
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final date = dates[index];
              return _DateTile(
                date: date,
                active: value == date.iso,
                onTap: () => onChanged(date.iso),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemCount: dates.length,
          ),
        ),
      ],
    );
  }

  void _scrollTo(int index) {
    if (!controller.hasClients) {
      return;
    }
    final offset = index * 58.0;
    final maxOffset = controller.position.maxScrollExtent;
    controller.animateTo(
      offset.clamp(0, maxOffset),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.active,
    required this.onTap,
  });

  final _DateOption date;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = active ? colors.primaryForeground : colors.inkSoft;
    final mute = active
        ? colors.primaryForeground.withValues(alpha: 0.72)
        : colors.inkMute;
    return SizedBox(
      width: 52,
      child: Material(
        color: active ? colors.foreground : colors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? colors.foreground : colors.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: mute,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date.day,
                  style: AppTextStyles.itemTitle.copyWith(
                    color: foreground,
                    fontSize: 15,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date.month,
                  style: AppTextStyles.caption.copyWith(
                    color: mute,
                    fontSize: 9.5,
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

class _DateAnchorChip extends StatelessWidget {
  const _DateAnchorChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.showArrow = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.foreground : colors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? colors.foreground : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.meta.copyWith(
                  color: active ? colors.primaryForeground : colors.inkSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showArrow) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: colors.inkSoft,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateOption {
  const _DateOption({
    required this.iso,
    required this.label,
    required this.day,
    required this.month,
    required this.isWeekStart,
  });

  final String iso;
  final String label;
  final String day;
  final String month;
  final bool isWeekStart;
}

class _DateAnchor {
  const _DateAnchor({
    required this.label,
    required this.index,
  });

  final String label;
  final int index;
}

const _weekdays = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
const _months = [
  'янв',
  'фев',
  'мар',
  'апр',
  'май',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

List<_DateOption> _buildDateOptions() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(21, (index) {
    final date = today.add(Duration(days: index));
    final weekdayIndex = date.weekday % 7;
    return _DateOption(
      iso: _isoDate(date),
      label: index == 0
          ? 'сегодня'
          : index == 1
              ? 'завтра'
              : _weekdays[weekdayIndex],
      day: '${date.day}',
      month: _months[date.month - 1],
      isWeekStart: date.weekday == DateTime.monday,
    );
  });
}

List<_DateAnchor> _dateAnchors(List<_DateOption> dates) {
  final today = DateTime.now();
  final tomorrow =
      DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
  final weekendIndex = dates.indexWhere((date) {
    final parsed = DateTime.parse(date.iso);
    return parsed.weekday == DateTime.saturday && parsed.isAfter(tomorrow);
  });
  final nextWeekIndex = dates.indexWhere((date) {
    final parsed = DateTime.parse(date.iso);
    return date.isWeekStart && parsed.isAfter(tomorrow);
  });
  return [
    const _DateAnchor(label: 'Сегодня', index: 0),
    if (weekendIndex >= 0)
      _DateAnchor(label: 'Эти выходные', index: weekendIndex),
    if (nextWeekIndex >= 0)
      _DateAnchor(label: 'Следующая неделя', index: nextWeekIndex),
  ];
}

String _isoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: colors.inkMute),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: colors.inkMute,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.foreground : colors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? colors.foreground : colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: active ? colors.primaryForeground : colors.inkSoft,
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: active ? colors.primaryForeground : colors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.foreground : colors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? colors.foreground : colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.meta.copyWith(
              color: active ? colors.primaryForeground : colors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessButton extends StatelessWidget {
  const _AccessButton({
    required this.title,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.foreground : colors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? colors.foreground : colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? colors.primaryForeground : colors.inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: active ? colors.primaryForeground : colors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
