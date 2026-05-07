import 'dart:async';
import 'dart:ui' as ui;

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _BuilderStep { goal, mood, budget, format, area, ready }

const _quickPrompts = [
  'Спонтанный вечер на двоих',
  'Тихий вечер без алкоголя',
  'Большая компания, до 2к ₽',
  'Свидание у Патриков',
];

const _stepOrder = [
  _BuilderStep.goal,
  _BuilderStep.mood,
  _BuilderStep.budget,
  _BuilderStep.format,
  _BuilderStep.area,
  _BuilderStep.ready,
];

const _stepTitles = {
  _BuilderStep.goal: 'Повод',
  _BuilderStep.mood: 'Настроение',
  _BuilderStep.budget: 'Бюджет',
  _BuilderStep.format: 'Формат',
  _BuilderStep.area: 'Район',
  _BuilderStep.ready: 'Маршрут',
};

class EveningBuilderScreen extends StatefulWidget {
  const EveningBuilderScreen({
    this.onReady,
    super.key,
  });

  final ValueChanged<EveningRouteData>? onReady;

  @override
  State<EveningBuilderScreen> createState() => _EveningBuilderScreenState();
}

class _EveningBuilderScreenState extends State<EveningBuilderScreen> {
  final _scrollController = ScrollController();
  final _draftController = TextEditingController();
  final _messages = <_EveningMessage>[];
  final _timers = <Timer>[];

  _BuilderStep _step = _BuilderStep.goal;
  bool _typing = false;
  String _draft = '';
  String? _freePrompt;
  EveningGoal? _goal;
  EveningMood? _mood;
  EveningBudget? _budget;
  EveningFormat? _format;
  String? _goalKey;
  String? _moodKey;
  String? _budgetKey;
  String? _formatKey;
  String? _area;
  List<EveningOption> _goalOptions = eveningGoals;
  List<EveningOption> _moodOptions = eveningMoods;
  List<EveningOption> _budgetOptions = eveningBudgets;
  List<EveningOption> _formatOptions = eveningFormats;
  List<EveningOption> _areaOptions = eveningAreas;
  CancelToken? _optionsCancelToken;
  CancelToken? _resolveCancelToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadBackendOptions();
    });
    _pushBot(
      step: _BuilderStep.goal,
      text:
          'Привет 👋 Я Frendly. Соберу вечер за минуту. С чего начнём — какой повод?',
      options: _goalOptions,
    );
  }

  @override
  void dispose() {
    _cancelOptionsRequest('evening_builder_disposed');
    _cancelResolveRequest('evening_builder_disposed');
    for (final timer in _timers) {
      timer.cancel();
    }
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _pushBot({
    required _BuilderStep step,
    required String text,
    List<EveningOption>? options,
  }) {
    setState(() {
      _typing = true;
    });
    final timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _typing = false;
        _messages.add(
          _EveningMessage.bot(
            id: 'b-${DateTime.now().microsecondsSinceEpoch}',
            text: text,
            step: step,
            options: options,
          ),
        );
      });
      _scrollToBottom();
    });
    _timers.add(timer);
  }

  void _pushUser(EveningOption option) {
    _pushUserText(option.label, emoji: option.emoji, step: _step);
  }

  void _pushUserText(String text, {String? emoji, _BuilderStep? step}) {
    setState(() {
      _messages.add(
        _EveningMessage.user(
          id: 'u-${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          emoji: emoji,
          step: step,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _loadBackendOptions() async {
    _cancelOptionsRequest('evening_options_replaced');
    final cancelToken = CancelToken();
    _optionsCancelToken = cancelToken;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final json = await container
          .read(backendRepositoryProvider)
          .fetchEveningOptions(cancelToken: cancelToken);
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_optionsCancelToken, cancelToken)) {
        return;
      }
      final options = EveningBuilderOptions.fromJson(json);
      setState(() {
        _goalOptions = options.goals;
        _moodOptions = options.moods;
        _budgetOptions = options.budgets;
        _formatOptions = options.formats;
        _areaOptions = options.areas;
      });
    } catch (_) {
    } finally {
      if (identical(_optionsCancelToken, cancelToken)) {
        _optionsCancelToken = null;
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handlePick(EveningOption option) {
    _pushUser(option);
    switch (_step) {
      case _BuilderStep.goal:
        _goalKey = option.key;
        _goal = eveningGoalFromKey(option.key);
        break;
      case _BuilderStep.mood:
        _moodKey = option.key;
        _mood = eveningMoodFromKey(option.key);
        break;
      case _BuilderStep.budget:
        _budgetKey = option.key;
        _budget = eveningBudgetFromKey(option.key);
        break;
      case _BuilderStep.format:
        _formatKey = option.key;
        _format = eveningFormatFromKey(option.key);
        break;
      case _BuilderStep.area:
        _area = option.key;
        break;
      case _BuilderStep.ready:
        break;
    }

    final next = _nextStep(_step);
    setState(() {
      _step = next;
    });

    _askForStep(next);
  }

  void _askForStep(_BuilderStep step) {
    switch (step) {
      case _BuilderStep.goal:
        _pushBot(
          step: _BuilderStep.goal,
          text:
              'Привет 👋 Я Frendly. Соберу вечер за минуту. С чего начнём — какой повод?',
          options: _goalOptions,
        );
        break;
      case _BuilderStep.mood:
        _pushBot(
          step: _BuilderStep.mood,
          text: 'Лови. А настроение какое сегодня?',
          options: _moodOptions,
        );
        break;
      case _BuilderStep.budget:
        _pushBot(
          step: _BuilderStep.budget,
          text: 'Бюджет на человека — чтобы не закидывать лишнее',
          options: _budgetOptions,
        );
        break;
      case _BuilderStep.format:
        _pushBot(
          step: _BuilderStep.format,
          text: 'Что хочется добавить в вечер?',
          options: _formatOptions,
        );
        break;
      case _BuilderStep.area:
        _pushBot(
          step: _BuilderStep.area,
          text: 'Где удобнее стартовать?',
          options: _areaOptions,
        );
        break;
      case _BuilderStep.ready:
        _openReadyRoute();
        break;
    }
  }

  void _editStep(_BuilderStep step) {
    if (step == _step) {
      return;
    }
    setState(() {
      _step = step;
    });
    _askForStep(step);
  }

  void _handleQuick(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return;
    }
    _freePrompt = value;
    _pushUserText(value, emoji: '✨', step: _step);
    _pushBot(
      step: _step,
      text:
          'Понял! Подберу под этот вайб. Уточни ещё пару деталей — и собираю.',
      options: _optionsForStep(_step),
    );
  }

  void _sendDraft() {
    final text = _draftController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _handleQuick(text);
    _draftController.clear();
    setState(() {
      _draft = '';
    });
  }

  List<EveningOption>? _optionsForStep(_BuilderStep step) {
    switch (step) {
      case _BuilderStep.goal:
        return _goalOptions;
      case _BuilderStep.mood:
        return _moodOptions;
      case _BuilderStep.budget:
        return _budgetOptions;
      case _BuilderStep.format:
        return _formatOptions;
      case _BuilderStep.area:
        return _areaOptions;
      case _BuilderStep.ready:
        return null;
    }
  }

  void _openReadyRoute() {
    final fallbackRoute = matchEveningRoute(
      goal: _goal,
      mood: _mood,
      budget: _budget,
      format: _format,
      area: _area,
    );
    unawaited(_finishReadyRoute(fallbackRoute));
  }

  Future<void> _finishReadyRoute(EveningRouteData fallbackRoute) async {
    final route = await _resolveBackendRoute(fallbackRoute);
    if (!mounted || route == null) {
      return;
    }
    _pushBot(
      step: _BuilderStep.ready,
      text:
          'Готово ✨ Собрал маршрут «${route.title}» — ${route.durationLabel}, ${route.area}. Сэкономишь ${route.totalSavings} ₽ по перкам.',
    );

    final timer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted || !context.mounted) {
        return;
      }
      final onReady = widget.onReady;
      if (onReady != null) {
        onReady(route);
        return;
      }
      context.pushReplacementNamed(
        AppRoute.eveningPlan.name,
        pathParameters: {'routeId': route.id},
      );
    });
    _timers.add(timer);
  }

  Future<EveningRouteData?> _resolveBackendRoute(
    EveningRouteData fallbackRoute,
  ) async {
    _cancelResolveRequest('evening_route_resolve_replaced');
    final cancelToken = CancelToken();
    _resolveCancelToken = cancelToken;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final json =
          await container.read(backendRepositoryProvider).resolveEveningRoute(
                goal: _goalKey,
                mood: _moodKey,
                budget: _budgetKey,
                format: _formatKey,
                area: _area,
                prompt: _freePrompt,
                cancelToken: cancelToken,
              );
      if (cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return null;
      }
      return eveningRouteFromJson(json, fallback: fallbackRoute);
    } catch (_) {
      if (cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return null;
      }
      return fallbackRoute;
    } finally {
      if (identical(_resolveCancelToken, cancelToken)) {
        _resolveCancelToken = null;
      }
    }
  }

  void _reset() {
    _cancelResolveRequest('evening_builder_reset');
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    setState(() {
      _messages.clear();
      _step = _BuilderStep.goal;
      _typing = false;
      _draft = '';
      _freePrompt = null;
      _goal = null;
      _mood = null;
      _budget = null;
      _format = null;
      _goalKey = null;
      _moodKey = null;
      _budgetKey = null;
      _formatKey = null;
      _area = null;
    });
    _draftController.clear();
    _pushBot(
      step: _BuilderStep.goal,
      text: 'Окей, начнём заново. Какой повод?',
      options: _goalOptions,
    );
  }

  void _cancelOptionsRequest(String reason) {
    final cancelToken = _optionsCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
  }

  void _cancelResolveRequest(String reason) {
    final cancelToken = _resolveCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
  }

  List<_StepChipData> _answerChips() {
    final chips = <_StepChipData>[];
    if (_goalKey != null) {
      final option = _goalOptions.optionByKey(_goalKey!);
      chips.add(
        _StepChipData(
          step: _BuilderStep.goal,
          label: option?.label ?? 'Повод',
          emoji: option?.emoji,
        ),
      );
    }
    if (_moodKey != null) {
      final option = _moodOptions.optionByKey(_moodKey!);
      chips.add(
        _StepChipData(
          step: _BuilderStep.mood,
          label: option?.label ?? 'Настроение',
          emoji: option?.emoji,
        ),
      );
    }
    if (_budgetKey != null) {
      final option = _budgetOptions.optionByKey(_budgetKey!);
      chips.add(
        _StepChipData(
          step: _BuilderStep.budget,
          label: option?.label ?? 'Бюджет',
        ),
      );
    }
    if (_formatKey != null) {
      final option = _formatOptions.optionByKey(_formatKey!);
      chips.add(
        _StepChipData(
          step: _BuilderStep.format,
          label: option?.label ?? 'Формат',
          emoji: option?.emoji,
        ),
      );
    }
    if (_area != null) {
      final option = _areaOptions.optionByKey(_area!);
      chips.add(
        _StepChipData(
          step: _BuilderStep.area,
          label: option?.label ?? 'Район',
          emoji: option?.emoji,
        ),
      );
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final stepIndex = _stepOrder.indexOf(_step);
    final last = _messages.isEmpty ? null : _messages.last;
    final showOptions = !_typing &&
        last != null &&
        last.isBot &&
        last.step == _step &&
        last.options != null;
    final chips = _answerChips();

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          _AmbientGlow(
            top: -96,
            left: -64,
            size: 288,
            colors: [
              colors.primary.withValues(alpha: 0.40),
              colors.secondary.withValues(alpha: 0),
            ],
          ),
          _AmbientGlow(
            top: -48,
            right: -80,
            size: 256,
            colors: [
              colors.secondary.withValues(alpha: 0.40),
              colors.primary.withValues(alpha: 0),
            ],
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: LucideIcons.chevron_left,
                        tooltip: 'Назад',
                        onTap: () => Navigator.of(context).maybePop(),
                        background: Colors.transparent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Row(
                          children: [
                            const _SparkleBadge(
                              size: 36,
                              iconSize: 16,
                              rounded: true,
                              live: true,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Frendly · AI',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.itemTitle.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: colors.foreground,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _step == _BuilderStep.ready
                                        ? 'маршрут готов'
                                        : '${_stepTitles[_step]} · шаг ${stepIndex + 1}/${_stepOrder.length - 1}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 10.5,
                                      color: colors.inkMute,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _RoundIconButton(
                        icon: LucideIcons.rotate_ccw,
                        tooltip: 'Начать заново',
                        onTap: _reset,
                        background: colors.card,
                        iconColor: colors.inkSoft,
                        size: 36,
                        iconSize: 16,
                        borderColor: colors.border,
                      ),
                    ],
                  ),
                ),
                _StepPills(
                  step: _step,
                  chips: chips,
                  onEdit: _editStep,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    itemCount: _messages.length + (_typing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_typing && index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _TypingBubble(),
                        );
                      }
                      final message = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: message.isBot
                            ? _BotBubble(message: message)
                            : _UserBubble(message: message),
                      );
                    },
                  ),
                ),
                if (showOptions && last.options != null)
                  _OptionsPanel(
                    options: last.options!,
                    onPick: _handlePick,
                  ),
                if (_step != _BuilderStep.ready)
                  _ComposerPanel(
                    controller: _draftController,
                    draft: _draft,
                    showQuickPrompts: _messages.length <= 2,
                    bottomInset: bottomInset,
                    onChanged: (value) {
                      setState(() {
                        _draft = value;
                      });
                    },
                    onQuick: _handleQuick,
                    onSend: _sendDraft,
                  )
                else
                  _ReadyPanel(bottomInset: bottomInset),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepChipData {
  const _StepChipData({
    required this.step,
    required this.label,
    this.emoji,
  });

  final _BuilderStep step;
  final String label;
  final String? emoji;
}

extension _EveningOptionLookup on List<EveningOption> {
  EveningOption? optionByKey(String key) {
    for (final option in this) {
      if (option.key == key) {
        return option;
      }
    }
    return null;
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.top,
    required this.size,
    required this.colors,
    this.left,
    this.right,
  });

  final double top;
  final double? left;
  final double? right;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepPills extends StatelessWidget {
  const _StepPills({
    required this.step,
    required this.chips,
    required this.onEdit,
  });

  final _BuilderStep step;
  final List<_StepChipData> chips;
  final ValueChanged<_BuilderStep> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final activeIndex = _stepOrder.indexOf(step);

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final itemStep = _stepOrder[index];
          final done = index < activeIndex;
          final active = index == activeIndex;
          final matchingChips =
              chips.where((item) => item.step == itemStep).toList();
          final chip = matchingChips.isEmpty ? null : matchingChips.first;
          final background = active
              ? colors.foreground
              : done
                  ? colors.card
                  : Colors.transparent;
          final foreground = active
              ? colors.background
              : done
                  ? colors.foreground
                  : colors.inkMute;
          final borderColor = active
              ? colors.foreground
              : done
                  ? colors.border
                  : colors.border.withValues(alpha: 0.60);

          return InkWell(
            onTap: done ? () => onEdit(itemStep) : null,
            borderRadius: AppRadii.pillBorder,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadii.pillBorder,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done)
                    Icon(LucideIcons.check, size: 12, color: foreground)
                  else
                    SizedBox(
                      width: 12,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: foreground.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  if (chip?.emoji != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      chip!.emoji!,
                      style: const TextStyle(fontSize: 11, height: 1),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Text(
                    chip?.label ?? _stepTitles[itemStep] ?? '',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.pencil,
                      size: 10,
                      color: foreground.withValues(alpha: 0.50),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: _stepOrder.length - 1,
      ),
    );
  }
}

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({
    required this.options,
    required this.onPick,
  });

  final List<EveningOption> options;
  final ValueChanged<EveningOption> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.background.withValues(alpha: 0),
            colors.background.withValues(alpha: 0.95),
            colors.background,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Icon(LucideIcons.wand, size: 12, color: colors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'варианты',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.inkMute,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              childAspectRatio: 2.45,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final option in options)
                  _OptionTile(option: option, onTap: () => onPick(option)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.onTap,
  });

  final EveningOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            if (option.emoji != null) ...[
              Text(
                option.emoji!,
                style: const TextStyle(fontSize: 22, height: 1),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                      letterSpacing: 0,
                    ),
                  ),
                  if (option.blurb != null)
                    Text(
                      option.blurb!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.inkMute,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyPanel extends StatelessWidget {
  const _ReadyPanel({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.send, size: 14, color: colors.inkMute),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Открываю маршрут…',
              style: AppTextStyles.meta.copyWith(color: colors.inkMute),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerPanel extends StatelessWidget {
  const _ComposerPanel({
    required this.controller,
    required this.draft,
    required this.showQuickPrompts,
    required this.bottomInset,
    required this.onChanged,
    required this.onQuick,
    required this.onSend,
  });

  final TextEditingController controller;
  final String draft;
  final bool showQuickPrompts;
  final double bottomInset;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onQuick;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasText = draft.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showQuickPrompts)
            SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return InkWell(
                    onTap: () => onQuick(prompt),
                    borderRadius: AppRadii.pillBorder,
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: colors.secondarySoft,
                        borderRadius: AppRadii.pillBorder,
                        border: Border.all(
                          color: colors.secondary.withValues(alpha: 0.30),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '✨ $prompt',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.secondary,
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemCount: _quickPrompts.length,
              ),
            ),
          Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 4),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: AppRadii.pillBorder,
              border: Border.all(color: colors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x261A1A1F),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                  spreadRadius: -18,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Опиши вечер своими словами…',
                      hintStyle: AppTextStyles.bodySoft.copyWith(
                        fontSize: 14,
                        color: colors.inkMute,
                      ),
                    ),
                    style: AppTextStyles.bodySoft.copyWith(
                      fontSize: 14,
                      color: colors.foreground,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Отправить',
                  child: InkWell(
                    onTap: hasText ? onSend : null,
                    borderRadius: AppRadii.pillBorder,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasText ? null : colors.muted,
                        gradient: hasText
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [colors.primary, colors.secondary],
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.send,
                        size: 16,
                        color:
                            hasText ? colors.primaryForeground : colors.inkMute,
                      ),
                    ),
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

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.message});

  final _EveningMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _SparkleBadge(size: 28, iconSize: 14),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
                bottomLeft: Radius.circular(6),
              ),
              border: Border.all(color: colors.border),
              boxShadow: AppShadows.soft,
            ),
            child: Text(
              message.text,
              style: AppTextStyles.bodySoft.copyWith(
                color: colors.foreground,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final _EveningMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Spacer(flex: 1),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.foreground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.emoji != null) ...[
                  Text(message.emoji!),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    message.text,
                    style: AppTextStyles.bodySoft.copyWith(
                      color: colors.background,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _SparkleBadge(size: 28, iconSize: 14),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
              bottomLeft: Radius.circular(6),
            ),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypingDot(color: colors.inkMute),
              const SizedBox(width: 4),
              _TypingDot(color: colors.inkMute),
              const SizedBox(width: 4),
              _TypingDot(color: colors.inkMute),
              const SizedBox(width: 8),
              Text(
                'думаю…',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: colors.inkMute,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SparkleBadge extends StatelessWidget {
  const _SparkleBadge({
    required this.size,
    required this.iconSize,
    this.rounded = false,
    this.live = false,
  });

  final double size;
  final double iconSize;
  final bool rounded;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: rounded ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: rounded ? BorderRadius.circular(16) : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primary, colors.primary, colors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.sparkles,
            size: iconSize,
            color: colors.primaryForeground,
          ),
        ),
        if (live)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.online,
                shape: BoxShape.circle,
                border: Border.all(color: colors.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.background,
    this.iconColor,
    this.borderColor,
    this.size = 40,
    this.iconSize = 24,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color background;
  final Color? iconColor;
  final Color? borderColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillBorder,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border:
                borderColor == null ? null : Border.all(color: borderColor!),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor ?? colors.foreground,
          ),
        ),
      ),
    );
  }
}

class _EveningMessage {
  const _EveningMessage._({
    required this.id,
    required this.text,
    required this.isBot,
    this.emoji,
    this.step,
    this.options,
  });

  factory _EveningMessage.bot({
    required String id,
    required String text,
    required _BuilderStep step,
    List<EveningOption>? options,
  }) {
    return _EveningMessage._(
      id: id,
      text: text,
      isBot: true,
      step: step,
      options: options,
    );
  }

  factory _EveningMessage.user({
    required String id,
    required String text,
    String? emoji,
    _BuilderStep? step,
  }) {
    return _EveningMessage._(
      id: id,
      text: text,
      isBot: false,
      emoji: emoji,
      step: step,
    );
  }

  final String id;
  final String text;
  final bool isBot;
  final String? emoji;
  final _BuilderStep? step;
  final List<EveningOption>? options;
}

_BuilderStep _nextStep(_BuilderStep step) {
  switch (step) {
    case _BuilderStep.goal:
      return _BuilderStep.mood;
    case _BuilderStep.mood:
      return _BuilderStep.budget;
    case _BuilderStep.budget:
      return _BuilderStep.format;
    case _BuilderStep.format:
      return _BuilderStep.area;
    case _BuilderStep.area:
    case _BuilderStep.ready:
      return _BuilderStep.ready;
  }
}
