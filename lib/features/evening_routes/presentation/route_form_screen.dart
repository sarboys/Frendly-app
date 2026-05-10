import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/evening_routes/application/custom_route_controller.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _routeMoods = ['Уютно', 'Шумно', 'Романтика', 'Slow night', 'Активно'];
const _durations = ['1ч', '2ч', '2.5ч', '3ч+'];
const _stepIcons = [
  ('coffee', LucideIcons.coffee),
  ('wine', LucideIcons.wine),
  ('music', LucideIcons.music),
  ('film', LucideIcons.film),
  ('walk', LucideIcons.footprints),
];

class RouteFormScreen extends ConsumerStatefulWidget {
  const RouteFormScreen({super.key});

  @override
  ConsumerState<RouteFormScreen> createState() => _RouteFormScreenState();
}

class _RouteFormScreenState extends ConsumerState<RouteFormScreen> {
  final _titleController = TextEditingController();
  var _mood = _routeMoods.first;
  var _duration = '2.5ч';
  late final List<_RouteStepDraft> _steps = [
    _RouteStepDraft(iconIndex: 0),
    _RouteStepDraft(iconIndex: 1),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _valid;

    return BbV5Scaffold(
      child: Stack(
        children: [
          BbV5Page(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const BbV5TopBar(
                  kicker: 'Свой маршрут',
                  title: 'Собери',
                  accent: 'вечер',
                ),
                const SizedBox(height: 20),
                BbV5Card(
                  radius: BbV5Radii.md,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BbV5Kicker('название маршрута'),
                      TextField(
                        controller: _titleController,
                        maxLength: 50,
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.itemTitle.copyWith(
                          fontSize: 16,
                          color: BbV5Colors.ink,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: 'Slow night на Патриках',
                          hintStyle: AppTextStyles.bodySoft.copyWith(
                            fontSize: 16,
                            color: BbV5Colors.inkMute,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                BbV5Section(
                  title: 'Настроение',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final mood in _routeMoods)
                        BbV5Chip(
                          label: mood,
                          active: mood == _mood,
                          onTap: () => setState(() {
                            _mood = mood;
                          }),
                        ),
                    ],
                  ),
                ),
                BbV5Section(
                  title: 'Длительность',
                  child: Row(
                    children: [
                      for (var index = 0;
                          index < _durations.length;
                          index++) ...[
                        Expanded(
                          child: _DurationChip(
                            label: _durations[index],
                            active: _duration == _durations[index],
                            onTap: () => setState(() {
                              _duration = _durations[index];
                            }),
                          ),
                        ),
                        if (index != _durations.length - 1)
                          const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                BbV5Section(
                  title: 'Шаги вечера · ${_steps.length}',
                  child: Column(
                    children: [
                      for (var index = 0; index < _steps.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RouteStepCard(
                            step: _steps[index],
                            index: index,
                            canRemove: _steps.length > 2,
                            onChanged: () => setState(() {}),
                            onCycleIcon: () => setState(() {
                              _steps[index].iconIndex =
                                  (_steps[index].iconIndex + 1) %
                                      _stepIcons.length;
                            }),
                            onRemove: () => _removeStep(_steps[index]),
                          ),
                        ),
                      _AddStepButton(
                        count: _steps.length,
                        onTap: _steps.length >= 6 ? null : _addStep,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                BbV5Card(
                  radius: BbV5Radii.md,
                  padding: const EdgeInsets.all(16),
                  borderColor: BbV5Colors.hair,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: BbV5Colors.paper,
                          shape: BoxShape.circle,
                          border: Border.all(color: BbV5Colors.hair),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          size: 17,
                          color: BbV5Colors.terra,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BbV5Kicker('AI compass'),
                            const SizedBox(height: 3),
                            Text(
                              'Дособрать маршрут',
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'Sora',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BbV5Colors.ink,
                              ),
                            ),
                            Text(
                              'предложит места по вайбу и району',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10.5,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevron_right,
                        size: 17,
                        color: BbV5Colors.inkMute,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BbV5FixedBottomBar(
              footer: Text(
                'Минимум 2 шага. Можно прикреплять к встречам.',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  color: BbV5Colors.inkMute,
                ),
              ),
              child: BbV5PillButton(
                label: 'Сохранить маршрут',
                icon: LucideIcons.save,
                dark: true,
                height: 52,
                fontSize: 14,
                expanded: true,
                onPressed: valid ? _save : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _valid {
    final filledSteps =
        _steps.where((step) => step.place.text.trim().isNotEmpty).length;
    return _titleController.text.trim().length >= 3 && filledSteps >= 2;
  }

  void _addStep() {
    if (_steps.length >= 6) {
      return;
    }
    setState(() {
      _steps.add(_RouteStepDraft(iconIndex: _steps.length % _stepIcons.length));
    });
  }

  void _removeStep(_RouteStepDraft step) {
    if (_steps.length <= 2) {
      return;
    }
    setState(() {
      _steps.remove(step);
      step.dispose();
    });
  }

  Future<void> _save() async {
    final route = CustomEveningRoute(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      mood: _mood,
      duration: _duration,
      createdAt: DateTime.now(),
      steps: _steps
          .where((step) => step.place.text.trim().isNotEmpty)
          .map(
            (step) => CustomEveningRouteStep(
              iconKey: _stepIcons[step.iconIndex].$1,
              place: step.place.text.trim(),
              subtitle: step.subtitle.text.trim(),
            ),
          )
          .toList(growable: false),
    );
    await ref.read(customEveningRoutesProvider.notifier).save(route);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Маршрут сохранён')),
    );
    context.goRoute(AppRoute.eveningRoutes);
  }
}

class _RouteStepDraft {
  _RouteStepDraft({required this.iconIndex});

  int iconIndex;
  final place = TextEditingController();
  final subtitle = TextEditingController();

  void dispose() {
    place.dispose();
    subtitle.dispose();
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Chip(
      label: label,
      active: active,
      icon: LucideIcons.clock,
      onTap: onTap,
    );
  }
}

class _RouteStepCard extends StatelessWidget {
  const _RouteStepCard({
    required this.step,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onCycleIcon,
    required this.onRemove,
  });

  final _RouteStepDraft step;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onCycleIcon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = _stepIcons[step.iconIndex].$2;
    return BbV5Card(
      radius: BbV5Radii.md,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onCycleIcon,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: BbV5Colors.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BbV5Colors.hair),
                  ),
                  child: Icon(icon, size: 17, color: BbV5Colors.ink),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BbV5Colors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: BbV5Colors.paper, width: 2),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: AppTextStyles.caption.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: BbV5Colors.paperHi,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              children: [
                _InlineField(
                  controller: step.place,
                  hint: _placeHint(index),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 4),
                _InlineField(
                  controller: step.subtitle,
                  hint: 'Адрес или ориентир',
                  fontSize: 11.5,
                  color: BbV5Colors.inkMute,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  LucideIcons.grip_vertical,
                  size: 16,
                  color: BbV5Colors.inkMute,
                ),
              ),
              if (canRemove)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      LucideIcons.x,
                      size: 14,
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _placeHint(int index) {
    const hints = ['Бар или кафе', 'Прогулка', 'Финал вечера', 'Куда дальше'];
    return hints[index % hints.length];
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.hint,
    required this.fontSize,
    required this.onChanged,
    this.fontWeight = FontWeight.w400,
    this.color = BbV5Colors.ink,
  });

  final TextEditingController controller;
  final String hint;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: AppTextStyles.bodySoft.copyWith(
        fontFamily: fontWeight == FontWeight.w600 ? 'Sora' : 'Manrope',
        fontSize: fontSize,
        height: 1.15,
        fontWeight: fontWeight,
        color: color,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: AppTextStyles.bodySoft.copyWith(
          fontSize: fontSize,
          color: BbV5Colors.inkMute,
        ),
      ),
    );
  }
}

class _AddStepButton extends StatelessWidget {
  const _AddStepButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: BbV5Colors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.plus, size: 16, color: BbV5Colors.terra),
              const SizedBox(width: 8),
              Text(
                'Добавить шаг ($count/6)',
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: BbV5Colors.terra,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
