import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/evening_route_publish_draft.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
const _aiStepCounts = ['2', '3', '4'];

class AiCreateScreen extends ConsumerStatefulWidget {
  const AiCreateScreen({super.key});

  @override
  ConsumerState<AiCreateScreen> createState() => _AiCreateScreenState();
}

class _AiCreateScreenState extends ConsumerState<AiCreateScreen> {
  final _promptController = TextEditingController();
  final _selectedVibes = <String>{};
  CancelToken? _resolveCancelToken;

  var _budget = 'до 1500';
  var _time = 'Вечером';
  var _size = '3–4';
  var _stepCount = 2;
  var _loading = false;
  var _confirming = false;
  int? _busyStepIndex;
  String? _errorText;
  AiRouteDraft? _draft;

  @override
  void dispose() {
    _cancelResolveRequest('ai_create_disposed');
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

  Future<void> _generatePlan() async {
    if (_promptController.text.trim().isEmpty && _selectedVibes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опиши вечер или выбери настроение')),
      );
      return;
    }

    _cancelResolveRequest('ai_create_replaced');
    final cancelToken = CancelToken();
    _resolveCancelToken = cancelToken;

    setState(() {
      _loading = true;
      _draft = null;
      _errorText = null;
    });

    try {
      final manualLocation = ref.read(manualLocationProvider);
      final json =
          await ref.read(backendRepositoryProvider).createAiRouteDraft(
                goal: _goalKey,
                mood: _moodKey,
                budget: _budgetKey,
                format: _formatKey,
                prompt: _resolvePrompt,
                stepCount: _stepCount,
                city: manualLocation?.city,
                latitude: manualLocation?.latitude,
                longitude: manualLocation?.longitude,
                cancelToken: cancelToken,
              );
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return;
      }
      final draft = AiRouteDraft.fromJson(json);
      if (draft.route.steps.isEmpty) {
        setState(() {
          _loading = false;
          _errorText = 'Не удалось собрать маршрут. Попробуй уточнить запрос.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Маршрут не собран')),
        );
        return;
      }
      setState(() {
        _loading = false;
        _draft = draft;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Готово · ${draft.route.steps.length} шага собраны'),
        ),
      );
    } catch (_) {
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = 'Сервер не ответил. Попробуй еще раз.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось собрать маршрут')),
      );
    } finally {
      if (identical(_resolveCancelToken, cancelToken)) {
        _resolveCancelToken = null;
      }
    }
  }

  Future<void> _regenerateDraftPlan() async {
    final draft = _draft;
    if (draft == null) {
      await _generatePlan();
      return;
    }
    if (_loading || _busyStepIndex != null) {
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .regenerateAiRouteDraft(draft.draftId);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _draft = AiRouteDraft.fromJson(json);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Собрал другой вариант')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = 'Не удалось заменить маршрут. Попробуй еще раз.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось заменить маршрут')),
      );
    }
  }

  String get _resolvePrompt {
    final parts = <String>[
      _promptController.text.trim(),
      if (_selectedVibes.isNotEmpty) 'Настроение: ${_selectedVibes.join(', ')}',
      'Когда: $_time',
      'Сколько людей: $_size',
      'Бюджет: $_budget',
      'Шагов: $_stepCount',
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);
    return parts.join('. ');
  }

  String get _goalKey {
    if (_selectedVibes.contains('Свидание') || _size == '2') {
      return 'date';
    }
    if (_size == '5–8' || _size == '9+') {
      return 'company';
    }
    return 'newfriends';
  }

  String get _moodKey {
    if (_selectedVibes.contains('Свидание')) {
      return 'date';
    }
    if (_selectedVibes.contains('Музыка') || _selectedVibes.contains('Вино')) {
      return 'social';
    }
    return 'chill';
  }

  String get _formatKey {
    if (_selectedVibes.contains('Вино')) {
      return 'bar';
    }
    if (_selectedVibes.contains('Музыка') || _selectedVibes.contains('Кино')) {
      return 'show';
    }
    if (_selectedVibes.contains('Прогулка')) {
      return 'active';
    }
    return 'mixed';
  }

  String get _budgetKey {
    return switch (_budget) {
      'Бесплатно' => 'free',
      'до 1500' => 'low',
      '1500–3500' => 'mid',
      _ => 'high',
    };
  }

  void _cancelResolveRequest(String reason) {
    final cancelToken = _resolveCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
  }

  Future<void> _acceptStep(int index) async {
    final draft = _draft;
    if (draft == null || _busyStepIndex != null) {
      return;
    }
    setState(() => _busyStepIndex = index);
    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .acceptAiRouteDraftStep(draft.draftId, index);
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = AiRouteDraft.fromJson(json);
        _busyStepIndex = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busyStepIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось принять шаг')),
      );
    }
  }

  Future<void> _regenerateStep(int index) async {
    final draft = _draft;
    if (draft == null || _busyStepIndex != null) {
      return;
    }
    setState(() => _busyStepIndex = index);
    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .regenerateAiRouteDraftStep(draft.draftId, index);
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = AiRouteDraft.fromJson(json);
        _busyStepIndex = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busyStepIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось заменить шаг')),
      );
    }
  }

  Future<void> _openDraftRoute({required bool launch}) async {
    final draft = _draft;
    if (draft == null || _confirming) {
      return;
    }
    if (!draft.canConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала прими все шаги маршрута')),
      );
      return;
    }

    setState(() => _confirming = true);
    try {
      final json = await ref
          .read(backendRepositoryProvider)
          .confirmAiRouteDraft(draft.draftId);
      if (!mounted) {
        return;
      }
      final confirmed = AiRouteDraft.fromJson(json);
      setState(() {
        _draft = confirmed;
        _confirming = false;
      });
      _openRoute(confirmed.route, launch: launch);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось подтвердить маршрут')),
      );
    }
  }

  void _openRoute(EveningRouteData route, {required bool launch}) {
    if (route.id.isEmpty) {
      context.pushRoute(AppRoute.createMeetup);
      return;
    }
    if (launch) {
      context.pushRoute(
        AppRoute.publishMeetup,
        extra: publishDraftFromEveningRoute(route),
      );
      return;
    }
    context.pushRoute(
      AppRoute.eveningPlan,
      pathParameters: {'routeId': route.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final route = draft?.route;
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
                    Row(
                      children: [
                        const Expanded(child: BbV5Kicker('твой запрос')),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: BbV5Colors.paperHi,
                              shape: BoxShape.circle,
                              border: Border.all(color: BbV5Colors.hair),
                              boxShadow: BbV5Shadows.pill,
                            ),
                            child: IconButton(
                              tooltip: 'Сказать вслух',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => context.pushRoute(
                                AppRoute.aiVoice,
                              ),
                              icon: const Icon(
                                LucideIcons.mic,
                                size: 15,
                                color: BbV5Colors.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      const _ParamDivider(),
                      _ParamChips(
                        title: 'шагов',
                        values: _aiStepCounts,
                        selected: _stepCount.toString(),
                        onChanged: (value) => setState(
                          () => _stepCount = int.tryParse(value) ?? 2,
                        ),
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
            if (route == null && !_loading)
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
                      Flexible(
                        child: Text(
                          'AI учитывает погоду, твой круг, афишу города',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11.5,
                            color: BbV5Colors.inkMute,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_errorText != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: BbV5Card(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorText!,
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkMute,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
            if (route != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _GeneratedPlanCard(
                    time: _time,
                    draft: draft!,
                    route: route,
                    busyStepIndex: _busyStepIndex,
                    confirming: _confirming,
                    refreshing: _loading,
                    onRefresh: _regenerateDraftPlan,
                    onAcceptStep: _acceptStep,
                    onRegenerateStep: _regenerateStep,
                    onEdit: () => _openDraftRoute(launch: false),
                    onCreate: () => _openDraftRoute(launch: true),
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
    required this.draft,
    required this.route,
    required this.busyStepIndex,
    required this.confirming,
    required this.refreshing,
    required this.onRefresh,
    required this.onAcceptStep,
    required this.onRegenerateStep,
    required this.onEdit,
    required this.onCreate,
  });

  final String time;
  final AiRouteDraft draft;
  final EveningRouteData route;
  final int? busyStepIndex;
  final bool confirming;
  final bool refreshing;
  final VoidCallback onRefresh;
  final ValueChanged<int> onAcceptStep;
  final ValueChanged<int> onRegenerateStep;
  final VoidCallback onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final steps = route.steps;
    final hasPlan = steps.isNotEmpty;

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
                        hasPlan
                            ? '${steps.length} шага · ${time.toLowerCase()}'
                            : 'План пока не собран',
                        style: bbV5DisplayStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
                BbV5IconButton(
                  icon: LucideIcons.refresh_cw,
                  size: 36,
                  iconSize: 14,
                  onPressed: refreshing ? null : onRefresh,
                ),
              ],
            ),
          ),
          if (!hasPlan)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                'План появится после ответа AI.',
                style: AppTextStyles.meta.copyWith(
                  color: BbV5Colors.inkMute,
                  height: 1.45,
                ),
              ),
            )
          else
            for (final entry in steps.asMap().entries)
              _PlanStepRow(
                index: entry.key,
                step: entry.value,
                accepted: draft.acceptedStepIndexes.contains(entry.key),
                active: draft.currentStepIndex == entry.key,
                busy: busyStepIndex == entry.key,
                locked: draft.currentStepIndex != null &&
                    entry.key > draft.currentStepIndex!,
                onAccept: () => onAcceptStep(entry.key),
                onRegenerate: () => onRegenerateStep(entry.key),
              ),
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
                    onPressed: hasPlan && draft.canConfirm && !confirming
                        ? onEdit
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: BbV5PillButton(
                    label: confirming ? 'Готовлю…' : 'Создать встречу',
                    icon: LucideIcons.arrow_up_right,
                    dark: true,
                    height: 48,
                    fontSize: 12.5,
                    expanded: true,
                    onPressed: hasPlan && draft.canConfirm && !confirming
                        ? onCreate
                        : null,
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
  const _PlanStepRow({
    required this.index,
    required this.step,
    required this.accepted,
    required this.active,
    required this.busy,
    required this.locked,
    required this.onAccept,
    required this.onRegenerate,
  });

  final int index;
  final EveningRouteStep step;
  final bool accepted;
  final bool active;
  final bool busy;
  final bool locked;
  final VoidCallback onAccept;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final color = _stepColor(step.kind);
    final place = step.venue.trim().isNotEmpty ? step.venue : step.title;
    final subtitle = step.description?.trim().isNotEmpty == true
        ? step.description!.trim()
        : step.address.trim().isNotEmpty
            ? step.address
            : step.distance;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BbV5Colors.hairSoft)),
      ),
      child: Opacity(
        opacity: locked ? 0.58 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
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
                          eveningKindLabel(step.kind).toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: color,
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
                    color: color,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place,
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
                          subtitle,
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
                  Icon(
                    accepted ? LucideIcons.check : LucideIcons.arrow_up_right,
                    size: accepted ? 18 : 14,
                    color: accepted ? BbV5Colors.accent : BbV5Colors.inkMute,
                  ),
                ],
              ),
              if (active && !accepted) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: BbV5PillButton(
                        label: busy ? 'Меняю…' : 'Заменить',
                        height: 40,
                        fontSize: 12,
                        expanded: true,
                        onPressed: busy ? null : onRegenerate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BbV5PillButton(
                        label: busy ? 'Сохраняю…' : 'Принять шаг',
                        dark: true,
                        height: 40,
                        fontSize: 12,
                        expanded: true,
                        onPressed: busy ? null : onAccept,
                      ),
                    ),
                  ],
                ),
              ] else if (locked) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Сначала прими предыдущий шаг',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _stepColor(EveningStepKind kind) {
  return switch (kind) {
    EveningStepKind.bar => BbV5Colors.terra,
    EveningStepKind.show => BbV5Colors.brandDeep,
    EveningStepKind.active => BbV5Colors.gold,
    EveningStepKind.dinner => BbV5Colors.accent,
    EveningStepKind.wellness => BbV5Colors.rose,
    EveningStepKind.afterparty => BbV5Colors.ink,
    EveningStepKind.followup => BbV5Colors.inkSoft,
  };
}
