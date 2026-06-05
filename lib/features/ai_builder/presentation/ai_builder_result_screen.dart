import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class AiBuilderResultScreen extends ConsumerStatefulWidget {
  const AiBuilderResultScreen({
    super.key,
    this.draftId,
  });

  final String? draftId;

  @override
  ConsumerState<AiBuilderResultScreen> createState() =>
      _AiBuilderResultScreenState();
}

class _AiBuilderResultScreenState extends ConsumerState<AiBuilderResultScreen> {
  EveningAiDraftData? _draft;
  bool _busy = false;
  bool _regeneratingRoute = false;
  int? _regeneratingStepIndex;
  String? _error;

  Future<EveningAiDraftData?> _mutate(
    Future<EveningAiDraftData> Function() action, {
    bool regeneratingRoute = false,
    int? regeneratingStepIndex,
  }) async {
    if (_busy) {
      return null;
    }
    setState(() {
      _busy = true;
      _regeneratingRoute = regeneratingRoute;
      _regeneratingStepIndex = regeneratingStepIndex;
      _error = null;
    });
    try {
      final next = await action();
      if (!mounted) {
        return null;
      }
      setState(() => _draft = next);
      return next;
    } on BackendActionException catch (error) {
      if (!mounted) {
        return null;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Действие не удалось');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _regeneratingRoute = false;
          _regeneratingStepIndex = null;
        });
      }
    }
    return null;
  }

  void _acceptCurrent(EveningAiDraftData draft) {
    final index = draft.currentStepIndex;
    if (index == null) {
      return;
    }
    _mutate(
      () => ref.read(eveningAiActionsProvider).acceptStep(
            draftId: draft.draftId,
            stepIndex: index,
          ),
    );
  }

  void _acceptAll(EveningAiDraftData draft) {
    _mutate(() async {
      var next = draft;
      final actions = ref.read(eveningAiActionsProvider);
      for (var index = 0; index < next.route.steps.length; index++) {
        if (next.acceptedStepIndexes.contains(index)) {
          continue;
        }
        next = await actions.acceptStep(
          draftId: next.draftId,
          stepIndex: index,
        );
      }
      return next;
    });
  }

  void _regenerate(EveningAiDraftData draft) {
    _mutate(
      () => ref.read(eveningAiActionsProvider).regenerate(draft.draftId),
      regeneratingRoute: true,
    );
  }

  void _regenerateStep(EveningAiDraftData draft, int index) {
    _mutate(
      () => ref.read(eveningAiActionsProvider).regenerateStep(
            draftId: draft.draftId,
            stepIndex: index,
          ),
      regeneratingStepIndex: index,
    );
  }

  Future<void> _confirm(EveningAiDraftData draft) async {
    if (!draft.canConfirm) {
      setState(() => _error = 'Сначала прими все шаги маршрута');
      return;
    }
    final confirmed = await _mutate(
      () => ref.read(eveningAiActionsProvider).confirm(draft.draftId),
    );
    if (!mounted || confirmed == null) {
      return;
    }
    final routeId = confirmed.route.id.trim();
    if (routeId.isEmpty) {
      setState(() => _error = 'Backend не вернул маршрут');
      return;
    }
    context.go('/meetings/new?routeId=${Uri.encodeComponent(routeId)}');
  }

  @override
  Widget build(BuildContext context) {
    final draftId = widget.draftId;
    if (draftId == null || draftId.isEmpty) {
      return const DateasyPhoneFrame(
        child: _ResultStatus(
          message: 'Маршрут появится после генерации из AI билдера',
        ),
      );
    }

    return DateasyPhoneFrame(
      child: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(eveningAiDraftProvider(draftId));
          final draft = _draft ?? state.valueOrNull;
          if (state.isLoading && draft == null) {
            return const _ResultStatus(message: 'Загружаем маршрут');
          }
          if (draft == null) {
            return _ResultStatus(
              message: state.hasError
                  ? 'Не удалось загрузить маршрут'
                  : 'Маршрут не найден',
            );
          }
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 16,
                  bottom: 148,
                ),
                children: [
                  _ResultHeader(draftId: draft.draftId),
                  _SummaryCard(
                    draft: draft,
                    busy: _busy,
                    regenerating: _regeneratingRoute,
                    onRegen: () => _regenerate(draft),
                  ),
                  if (_error != null) _InlineError(message: _error!),
                  _RouteSection(
                    draft: draft,
                    busy: _busy,
                    regeneratingStepIndex: _regeneratingStepIndex,
                    onAccept: () => _acceptCurrent(draft),
                    onRegenerate: (index) => _regenerateStep(draft, index),
                  ),
                  _ActionSection(
                    draft: draft,
                    busy: _busy,
                    onPrimary: () {
                      if (draft.canConfirm) {
                        _confirm(draft);
                      } else {
                        _acceptAll(draft);
                      }
                    },
                  ),
                ],
              ),
              const DateasyBottomNav(),
            ],
          );
        },
      ),
    );
  }
}

class _ResultStatus extends StatelessWidget {
  const _ResultStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: _GlassPanel(
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.pink,
                fontSize: 12,
              ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.muted,
              fontSize: 12,
            ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.draftId});

  final String draftId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go('/ai-builder'),
            child: const _GlassSquare(
              child: Icon(
                LucideIcons.arrowLeft,
                size: 20,
                color: DateasyColors.foreground,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 19,
                  color: DateasyColors.lime,
                ),
                const SizedBox(width: 8),
                Text(
                  'Маршрут вечера',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go(
              '/share?targetType=ai_draft&targetId=${Uri.encodeComponent(draftId)}',
            ),
            child: const _GlassSquare(
              child: Icon(
                LucideIcons.share2,
                size: 20,
                color: DateasyColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.draft,
    required this.busy,
    required this.regenerating,
    required this.onRegen,
  });

  final EveningAiDraftData draft;
  final bool busy;
  final bool regenerating;
  final VoidCallback onRegen;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: 24,
          height: 1.1,
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -54,
              top: -54,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DateasyColors.lime.withValues(alpha: 0.30),
                  boxShadow: [
                    BoxShadow(
                      color: DateasyColors.lime.withValues(alpha: 0.26),
                      blurRadius: 54,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 14,
                      color: DateasyColors.lime,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${draft.canConfirm ? 'Готово' : 'Проверка'} · ${draft.route.steps.length} точки',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.lime,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  draft.route.title.isEmpty
                      ? 'Маршрут вечера'
                      : draft.route.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (draft.route.area != null)
                  Text(
                    draft.route.area!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle?.copyWith(color: DateasyColors.lime),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      icon: LucideIcons.clock,
                      text: draft.route.durationLabel ?? 'Время не указано',
                    ),
                    _MetricChip(
                      icon: LucideIcons.wallet,
                      text: draft.route.totalPriceFrom > 0
                          ? 'от ${draft.route.totalPriceFrom} ₽'
                          : 'Бюджет не указан',
                    ),
                    _MetricChip(
                      icon: LucideIcons.mapPin,
                      text: draft.route.area ?? 'Район не указан',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Принято ${draft.acceptedStepIndexes.length}/${draft.route.steps.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: busy ? null : onRegen,
                          child: _GlassPanel(
                            borderRadius: 999,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (regenerating)
                                  const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        DateasyColors.foreground,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    LucideIcons.refreshCw,
                                    size: 13,
                                    color: DateasyColors.foreground,
                                  ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    regenerating
                                        ? 'Перегенерируем...'
                                        : 'Перегенерить',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DateasyColors.background.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: DateasyColors.foreground),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({
    required this.draft,
    required this.busy,
    required this.regeneratingStepIndex,
    required this.onAccept,
    required this.onRegenerate,
  });

  final EveningAiDraftData draft;
  final bool busy;
  final int? regeneratingStepIndex;
  final VoidCallback onAccept;
  final ValueChanged<int> onRegenerate;

  @override
  Widget build(BuildContext context) {
    final steps = draft.route.steps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Маршрут',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          if (steps.isEmpty)
            const _InlineNotice(message: 'Backend не вернул шаги маршрута'),
          for (var index = 0; index < steps.length; index++) ...[
            _StopCard(
              stop: steps[index],
              index: index,
              accepted: draft.acceptedStepIndexes.contains(index),
              active: draft.currentStepIndex == index,
              busy: busy,
              regenerating: regeneratingStepIndex == index,
              onAccept: onAccept,
              onRegenerate: () => onRegenerate(index),
            ),
            if (index != steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.index,
    required this.accepted,
    required this.active,
    required this.busy,
    required this.regenerating,
    required this.onAccept,
    required this.onRegenerate,
  });

  final EveningAiRouteStepData stop;
  final int index;
  final bool accepted;
  final bool active;
  final bool busy;
  final bool regenerating;
  final VoidCallback onAccept;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final tagLabel = stop.tagLabel?.trim();
    final warningText = _matchWarningText(stop);
    return _GlassPanel(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 142,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DateasyRemoteImage(
                  imageUrl: stop.imageUrl,
                  imageVariants: stop.imageVariants,
                  usage: DateasyImageUsage.card,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Color(0x661F0C3F)],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: DateasyColors.background.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.foreground,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                if (accepted)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: DateasyColors.lime,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        size: 14,
                        color: DateasyColors.backgroundDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 13,
                        color: DateasyColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            stop.time,
                            stop.durationLabel,
                          ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DateasyColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                        ),
                      ),
                      if (tagLabel != null && tagLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _StopTag(label: tagLabel),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stop.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 13,
                        color: DateasyColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          stop.place ?? 'Место уточняется',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DateasyColors.muted,
                                    fontSize: 12,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  if (warningText != null) ...[
                    const SizedBox(height: 8),
                    _StopMatchWarning(text: warningText),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          stop.price > 0
                              ? 'от ${stop.price} ₽'
                              : 'Цена не указана',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 6,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StopRegenerateButton(
                                enabled: !busy,
                                loading: regenerating,
                                onTap: onRegenerate,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: _StopButton(
                                  stop: stop,
                                  active: active,
                                  accepted: accepted,
                                  busy: busy,
                                  onAccept: onAccept,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _matchWarningText(EveningAiRouteStepData stop) {
  final quality = stop.matchQuality?.trim();
  if (quality == 'partial') {
    return 'Не все пожелания подтверждены';
  }
  if (quality != 'substitution') {
    return null;
  }
  final reason = stop.substitutionReason?.trim();
  return reason == null || reason.isEmpty
      ? 'Не все пожелания подтверждены'
      : reason;
}

class _StopMatchWarning extends StatelessWidget {
  const _StopMatchWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            LucideIcons.triangleAlert,
            size: 13,
            color: DateasyColors.lime,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontSize: 11,
                  height: 1.22,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _StopRegenerateButton extends StatelessWidget {
  const _StopRegenerateButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Перегенерировать шаг',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? DateasyColors.glass : DateasyColors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled ? DateasyColors.border : DateasyColors.glass,
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(DateasyColors.foreground),
                  ),
                )
              : Icon(
                  LucideIcons.refreshCw,
                  size: 14,
                  color:
                      enabled ? DateasyColors.foreground : DateasyColors.muted,
                ),
        ),
      ),
    );
  }
}

class _StopTag extends StatelessWidget {
  const _StopTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DateasyColors.border),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.lime,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.stop,
    required this.active,
    required this.accepted,
    required this.busy,
    required this.onAccept,
  });

  final EveningAiRouteStepData stop;
  final bool active;
  final bool accepted;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final enabled = active && !accepted && !busy;
    final label = accepted
        ? 'Принято'
        : active
            ? 'Принять'
            : 'Ждёт';

    return GestureDetector(
      onTap: enabled ? onAccept : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled || accepted ? DateasyColors.lime : DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                enabled || accepted ? DateasyColors.lime : DateasyColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              accepted ? LucideIcons.check : LucideIcons.ticket,
              size: 14,
              color: enabled || accepted
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.muted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: enabled || accepted
                          ? DateasyColors.backgroundDeep
                          : DateasyColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.draft,
    required this.busy,
    required this.onPrimary,
  });

  final EveningAiDraftData draft;
  final bool busy;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        children: [
          GestureDetector(
            onTap: busy ? null : onPrimary,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: dateasyLimeGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66BEFF67),
                    blurRadius: 30,
                    spreadRadius: -14,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.ticket,
                      size: 20,
                      color: DateasyColors.backgroundDeep,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        draft.canConfirm
                            ? (busy ? 'Подтверждаем' : 'Подтвердить маршрут')
                            : (busy ? 'Принимаем' : 'Принять все'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DateasyColors.backgroundDeep,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go('/meetings/new'),
            child: _GlassPanel(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.heart,
                      size: 17,
                      color: DateasyColors.foreground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Позвать друзей',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DateasyColors.foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 17,
                      color: DateasyColors.foreground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSquare extends StatelessWidget {
  const _GlassSquare({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DateasyColors.border),
      ),
      child: child,
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clipBehavior,
      padding: padding,
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: DateasyColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            spreadRadius: -14,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
