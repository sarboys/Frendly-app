import 'dart:async';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

const _aiPromptTemplates = [
  'Винный бар, потом джаз и тихое место для разговора',
  'Утро субботы: пробежка, кофе, выставка',
  'Свидание · уютный ужин и долгая прогулка',
  'After work · 4 человека, бар у работы, до полуночи',
  'Спорт + бранч в воскресенье',
];

const _aiVibes = [
  _AiVibe(icon: LucideIcons.wine, label: 'Вино'),
  _AiVibe(icon: LucideIcons.music, label: 'Музыка'),
  _AiVibe(icon: LucideIcons.coffee, label: 'Кофе'),
  _AiVibe(icon: LucideIcons.film, label: 'Кино'),
  _AiVibe(icon: LucideIcons.footprints, label: 'Прогулка'),
  _AiVibe(icon: LucideIcons.heart, label: 'Свидание'),
];

const _aiTimes = ['Сейчас', 'Вечером', 'Завтра', 'На выходных'];
const _aiSizes = ['2', '3–4', '5–8', '9+'];
const _aiBudgets = ['Бесплатно', 'до 1500', '1500–3500', '3500+'];

const _aiPlanTemplate = [
  _AiPlanStep(
    time: '19:30',
    place: 'Brix · винный бар',
    subtitle: 'стартуем с бокала оранжа',
    tag: 'вино',
    color: BbV5Colors.terra,
  ),
  _AiPlanStep(
    time: '21:00',
    place: 'Powerhouse · late jazz',
    subtitle: 'живая музыка, негромко',
    tag: 'музыка',
    color: BbV5Colors.brand,
  ),
  _AiPlanStep(
    time: '23:00',
    place: 'Чистые пруды',
    subtitle: 'ночная прогулка',
    tag: 'прогулка',
    color: BbV5Colors.gold,
  ),
];

class AiCreateScreen extends StatefulWidget {
  const AiCreateScreen({super.key});

  @override
  State<AiCreateScreen> createState() => _AiCreateScreenState();
}

class _AiCreateScreenState extends State<AiCreateScreen> {
  final _promptController = TextEditingController();
  final _selectedVibes = <String>{};
  Timer? _timer;

  var _budget = 'до 1500';
  var _time = 'Вечером';
  var _size = '3–4';
  var _loading = false;
  List<_AiPlanStep>? _plan;

  @override
  void dispose() {
    _timer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  void _toggleVibe(String vibe) {
    setState(() {
      if (_selectedVibes.contains(vibe)) {
        _selectedVibes.remove(vibe);
      } else {
        _selectedVibes.add(vibe);
      }
    });
  }

  void _generatePlan() {
    if (_promptController.text.trim().isEmpty && _selectedVibes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опиши вечер или выбери настроение')),
      );
      return;
    }

    _timer?.cancel();
    setState(() {
      _loading = true;
      _plan = null;
    });

    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || !context.mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _plan = _aiPlanTemplate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Готово · 3 шага собраны')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final bottomPadding = 120 + MediaQuery.paddingOf(context).bottom;

    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: BbV5TopBar(
                  kicker: 'Frendly · AI compass',
                  title: 'Опиши вечер —',
                  accent: 'соберу план',
                  right: BbV5IconButton(
                    icon: LucideIcons.sparkles,
                    dark: true,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: BbV5Card(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BbV5Kicker('твой запрос'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _promptController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Например: винный бар, джаз и долгий разговор у воды',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: BbV5Colors.inkMute,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: AppTextStyles.body.copyWith(
                        color: BbV5Colors.ink,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: BbV5Colors.hairSoft),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final prompt in _aiPromptTemplates)
                          _PromptTemplateChip(
                            label: prompt,
                            onTap: () {
                              _promptController.text = prompt;
                              _promptController.selection =
                                  TextSelection.collapsed(
                                offset: prompt.length,
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: BbV5Section(
                title: 'настроение',
                margin: const EdgeInsets.only(top: 16),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.72,
                  children: [
                    for (final vibe in _aiVibes)
                      _VibeTile(
                        vibe: vibe,
                        active: _selectedVibes.contains(vibe.label),
                        onTap: () => _toggleVibe(vibe.label),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: BbV5Card(
                  padding: const EdgeInsets.all(16),
                  radius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ParamChips(
                        title: 'когда',
                        values: _aiTimes,
                        selected: _time,
                        onChanged: (value) => setState(() => _time = value),
                      ),
                      const _ParamDivider(),
                      _ParamChips(
                        title: 'сколько вас',
                        values: _aiSizes,
                        selected: _size,
                        onChanged: (value) => setState(() => _size = value),
                      ),
                      const _ParamDivider(),
                      _ParamChips(
                        title: 'бюджет',
                        values: _aiBudgets,
                        selected: _budget,
                        onChanged: (value) => setState(() => _budget = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: BbV5PillButton(
                  label: _loading ? 'Собираю вечер…' : 'Собрать план',
                  icon: _loading ? LucideIcons.loader : LucideIcons.wand,
                  dark: true,
                  height: 56,
                  fontSize: 14,
                  expanded: true,
                  onPressed: _loading ? null : _generatePlan,
                ),
              ),
            ),
            if (plan == null && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 13,
                        color: BbV5Colors.inkMute,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'AI учитывает погоду, твой круг, афишу города',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11.5,
                          color: BbV5Colors.inkMute,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (plan != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _GeneratedPlanCard(
                    time: _time,
                    plan: plan,
                    onRefresh: _generatePlan,
                    onEdit: () => context.pushRoute(AppRoute.createMeetup),
                    onCreate: () => context.pushRoute(AppRoute.createMeetup),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
          ],
        ),
      ),
    );
  }
}

class _AiVibe {
  const _AiVibe({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _AiPlanStep {
  const _AiPlanStep({
    required this.time,
    required this.place,
    required this.subtitle,
    required this.tag,
    required this.color,
  });

  final String time;
  final String place;
  final String subtitle;
  final String tag;
  final Color color;
}

class _PromptTemplateChip extends StatelessWidget {
  const _PromptTemplateChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BbV5Colors.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: BbV5Colors.hair),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: BbV5Colors.inkSoft,
            fontSize: 11,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _VibeTile extends StatelessWidget {
  const _VibeTile({
    required this.vibe,
    required this.active,
    required this.onTap,
  });

  final _AiVibe vibe;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? BbV5Colors.accent : BbV5Colors.hair,
          ),
          boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              vibe.icon,
              size: 16,
              color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
            ),
            const SizedBox(height: 6),
            Text(
              vibe.label,
              style: AppTextStyles.caption.copyWith(
                fontFamily: 'Sora',
                fontSize: 11,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
                color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParamChips extends StatelessWidget {
  const _ParamChips({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5Kicker(title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final value in values)
              BbV5Chip(
                label: value,
                active: selected == value,
                onTap: () => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _ParamDivider extends StatelessWidget {
  const _ParamDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: BbV5Colors.hairSoft),
    );
  }
}

class _GeneratedPlanCard extends StatelessWidget {
  const _GeneratedPlanCard({
    required this.time,
    required this.plan,
    required this.onRefresh,
    required this.onEdit,
    required this.onCreate,
  });

  final String time;
  final List<_AiPlanStep> plan;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BbV5Kicker('AI · план вечера'),
                      const SizedBox(height: 6),
                      Text(
                        '3 шага · ${time.toLowerCase()}',
                        style: bbV5DisplayStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
                BbV5IconButton(
                  icon: LucideIcons.refresh_cw,
                  size: 36,
                  iconSize: 14,
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),
          for (final step in plan) _PlanStepRow(step: step),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: BbV5PillButton(
                    label: 'Править вручную',
                    height: 48,
                    fontSize: 12.5,
                    expanded: true,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: BbV5PillButton(
                    label: 'Создать встречу',
                    icon: LucideIcons.arrow_up_right,
                    dark: true,
                    height: 48,
                    fontSize: 12.5,
                    expanded: true,
                    onPressed: onCreate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStepRow extends StatelessWidget {
  const _PlanStepRow({required this.step});

  final _AiPlanStep step;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BbV5Colors.hairSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.time,
                    style: AppTextStyles.body.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: BbV5Colors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.tag,
                    style: AppTextStyles.caption.copyWith(
                      color: step.color,
                      fontSize: 9,
                      letterSpacing: 1.44,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: step.color,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: BbV5Colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.arrow_up_right,
              size: 14,
              color: BbV5Colors.inkMute,
            ),
          ],
        ),
      ),
    );
  }
}
