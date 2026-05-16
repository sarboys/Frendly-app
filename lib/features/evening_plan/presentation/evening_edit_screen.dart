import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_providers.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_edit_state.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EveningEditScreen extends ConsumerStatefulWidget {
  const EveningEditScreen({
    required this.routeId,
    this.chatId,
    super.key,
  });

  final String routeId;
  final String? chatId;

  @override
  ConsumerState<EveningEditScreen> createState() => _EveningEditScreenState();
}

class _EveningEditScreenState extends ConsumerState<EveningEditScreen> {
  late final EveningRouteData _initialRoute;
  late final TextEditingController _titleController;
  late final TextEditingController _blurbController;
  late final TextEditingController _areaController;
  late final TextEditingController _durationController;
  late List<EveningRouteStep> _steps;
  late bool _premium;
  EveningPrivacy _privacy = EveningPrivacy.open;
  EveningPrivacy _initialPrivacy = EveningPrivacy.open;
  int? _maxGuests;
  int? _initialMaxGuests;
  String? _syncedChatId;
  String? _openStepId;

  @override
  void initState() {
    super.initState();
    _initialRoute = readEveningRoute(ref, widget.routeId);
    _titleController = TextEditingController(text: _initialRoute.title);
    _blurbController = TextEditingController(text: _initialRoute.blurb);
    _areaController = TextEditingController(text: _initialRoute.area);
    _durationController =
        TextEditingController(text: _initialRoute.durationLabel);
    _steps = [..._initialRoute.steps];
    _premium = _initialRoute.premium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _blurbController.dispose();
    _areaController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chat = _resolveChat();
    _syncChatMeta(chat);
    final policy = EveningEditPolicy.forPhase(chat?.phase);
    final canSave = chat?.phase != MeetupPhase.done;

    return Scaffold(
      backgroundColor: colors.paper,
      body: Stack(
        children: [
          const _V5WashBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  canSave: canSave,
                  phase: chat?.phase,
                  onBack: _pop,
                  onSave: _save,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                        children: [
                          if (chat?.phase == MeetupPhase.live)
                            const _PhaseBanner(
                              icon: LucideIcons.circle_alert,
                              text:
                                  'Вечер уже идёт. Можно править только будущие шаги',
                            ),
                          if (chat?.phase == MeetupPhase.done)
                            const _PhaseBanner(
                              icon: LucideIcons.lock,
                              text: 'Вечер завершён. Редактирование закрыто',
                            ),
                          _Section(
                            title: 'Основное',
                            disabled: !policy.meta,
                            children: [
                              _V5Card(
                                child: Column(
                                  children: [
                                    _Field(
                                      label: 'Название',
                                      child: _TextInput(
                                        controller: _titleController,
                                        enabled: policy.meta,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _Field(
                                      label: 'Описание',
                                      child: _TextInput(
                                        controller: _blurbController,
                                        enabled: policy.meta,
                                        maxLines: 2,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _Field(
                                            label: 'Район',
                                            child: _TextInput(
                                              controller: _areaController,
                                              enabled: policy.meta,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: _Field(
                                            label: 'Время',
                                            child: _TextInput(
                                              controller: _durationController,
                                              enabled: policy.meta,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _PremiumToggle(
                                      value: _premium,
                                      enabled: policy.meta,
                                      onChanged: (value) =>
                                          setState(() => _premium = value),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _Section(
                            title: 'Кто может вписаться',
                            disabled: !policy.meta,
                            children: [
                              _PrivacyOption(
                                icon: LucideIcons.globe,
                                label: 'Открытый',
                                hint: 'Любой может присоединиться',
                                active: _privacy == EveningPrivacy.open,
                                enabled: policy.meta,
                                onTap: () => setState(
                                  () => _privacy = EveningPrivacy.open,
                                ),
                              ),
                              _PrivacyOption(
                                icon: LucideIcons.user_plus,
                                label: 'По заявке',
                                hint: 'Хост одобряет каждую заявку',
                                active: _privacy == EveningPrivacy.request,
                                enabled: policy.meta,
                                onTap: () => setState(
                                  () => _privacy = EveningPrivacy.request,
                                ),
                              ),
                              _PrivacyOption(
                                icon: LucideIcons.lock,
                                label: 'По приглашениям',
                                hint: 'Только приглашённые видят встречу',
                                active: _privacy == EveningPrivacy.invite,
                                enabled: policy.meta,
                                onTap: () => setState(
                                  () => _privacy = EveningPrivacy.invite,
                                ),
                              ),
                              _GuestLimitControl(
                                value: _maxGuests,
                                enabled: policy.meta,
                                onChanged: (value) =>
                                    setState(() => _maxGuests = value),
                              ),
                            ],
                          ),
                          _Section(
                            title:
                                'Маршрут · ${_steps.length} ${_pluralStops(_steps.length)}',
                            children: [
                              for (var i = 0; i < _steps.length; i++)
                                _StepEditorCard(
                                  key: ValueKey(_steps[i].id),
                                  step: _steps[i],
                                  index: i,
                                  total: _steps.length,
                                  editable: policy.stepEditable(
                                    i,
                                    currentStep: chat?.currentStep,
                                  ),
                                  passed: chat?.phase == MeetupPhase.live &&
                                      !policy.stepEditable(
                                        i,
                                        currentStep: chat?.currentStep,
                                      ),
                                  expanded: _openStepId == _steps[i].id,
                                  canMoveUp: policy.reorderStep && i > 0,
                                  canMoveDown: policy.reorderStep &&
                                      i < _steps.length - 1,
                                  canRemove: policy.removeStep,
                                  onToggle: () => setState(() {
                                    _openStepId = _openStepId == _steps[i].id
                                        ? null
                                        : _steps[i].id;
                                  }),
                                  onChanged: (step) => _replaceStep(i, step),
                                  onMoveUp: () =>
                                      _moveStep(i, -1, policy, chat),
                                  onMoveDown: () =>
                                      _moveStep(i, 1, policy, chat),
                                  onRemove: () => _removeStep(i, policy, chat),
                                ),
                              if (policy.addStep)
                                _AddStepButton(onTap: _addStep),
                            ],
                          ),
                        ],
                      ),
                      if (canSave)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _StickySave(onTap: _save),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MeetupChat? _resolveChat() {
    final chatId = widget.chatId;
    if (chatId != null && chatId.isNotEmpty) {
      return ref.watch(meetupChatSummaryProvider(chatId));
    }

    final chats = ref.watch(meetupChatsProvider).valueOrNull ??
        ref.watch(meetupChatsLocalStateProvider);
    if (chats == null) {
      return null;
    }
    for (final chat in chats) {
      if (chat.routeId == widget.routeId) {
        return chat;
      }
    }
    return null;
  }

  void _syncChatMeta(MeetupChat? chat) {
    if (chat == null || _syncedChatId == chat.id) {
      return;
    }
    _syncedChatId = chat.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _privacy = chat.privacy;
        _initialPrivacy = chat.privacy;
        _maxGuests = chat.maxGuests;
        _initialMaxGuests = chat.maxGuests;
      });
    });
  }

  void _replaceStep(int index, EveningRouteStep step) {
    setState(() {
      _steps = [
        for (var i = 0; i < _steps.length; i++) i == index ? step : _steps[i],
      ];
    });
  }

  void _moveStep(
    int index,
    int direction,
    EveningEditPolicy policy,
    MeetupChat? chat,
  ) {
    final target = index + direction;
    if (target < 0 || target >= _steps.length) {
      return;
    }
    if (!policy.stepEditable(index, currentStep: chat?.currentStep) ||
        !policy.stepEditable(target, currentStep: chat?.currentStep)) {
      return;
    }
    setState(() {
      final next = [..._steps];
      final item = next.removeAt(index);
      next.insert(target, item);
      _steps = next;
    });
  }

  void _removeStep(int index, EveningEditPolicy policy, MeetupChat? chat) {
    if (!policy.stepEditable(index, currentStep: chat?.currentStep)) {
      return;
    }
    setState(() {
      _steps = [..._steps]..removeAt(index);
    });
  }

  void _addStep() {
    final last = _steps.isEmpty ? null : _steps.last;
    final step = EveningRouteStep(
      id: 'local-step-${DateTime.now().microsecondsSinceEpoch}',
      time: nextEveningStepTime(last?.endTime ?? last?.time ?? '21:00'),
      kind: EveningStepKind.bar,
      title: 'Новый шаг',
      venue: 'Выбери место',
      address: _areaController.text.trim().isEmpty
          ? _initialRoute.area
          : _areaController.text.trim(),
      emoji: '✨',
      distance: '—',
      lat: 0.5,
      lng: 0.5,
    );
    setState(() {
      _steps = [..._steps, step];
      _openStepId = step.id;
    });
  }

  void _save() {
    final chat = _readChat();
    if (chat?.phase == MeetupPhase.done) {
      return;
    }

    final totalTickets = _steps.fold<int>(
      0,
      (sum, step) => sum + (step.ticketPrice ?? 0),
    );
    final nextRoute = _initialRoute.copyWith(
      title: _fallbackTrim(_titleController.text, _initialRoute.title),
      blurb: _fallbackTrim(_blurbController.text, _initialRoute.blurb),
      area: _fallbackTrim(_areaController.text, _initialRoute.area),
      durationLabel:
          _fallbackTrim(_durationController.text, _initialRoute.durationLabel),
      premium: _premium,
      totalPriceFrom:
          totalTickets == 0 ? _initialRoute.totalPriceFrom : totalTickets,
      steps: _steps,
    );
    final diff = buildEveningEditDiff(
      previous: EveningEditSnapshot(
        route: _initialRoute,
        privacy: _initialPrivacy,
        maxGuests: _initialMaxGuests,
      ),
      next: EveningEditSnapshot(
        route: nextRoute,
        privacy: _privacy,
        maxGuests: _maxGuests,
      ),
    );

    ref.read(eveningRouteOverridesProvider.notifier).state = {
      ...ref.read(eveningRouteOverridesProvider),
      nextRoute.id: nextRoute,
    };

    final chatId = widget.chatId ?? chat?.id;
    if (chatId != null) {
      if (diff.isNotEmpty) {
        ref
            .read(chatThreadProvider(chatId).notifier)
            .addLocalSystemMessage(_diffMessage(diff));
      }
      _patchChatSummary(
        chatId: chatId,
        route: nextRoute,
        diff: diff,
      );
    }

    _pop();
  }

  MeetupChat? _readChat() {
    final chatId = widget.chatId;
    if (chatId != null && chatId.isNotEmpty) {
      final chats = ref.read(meetupChatsLocalStateProvider) ??
          ref.read(meetupChatsProvider).valueOrNull;
      if (chats != null) {
        for (final chat in chats) {
          if (chat.id == chatId) {
            return chat;
          }
        }
      }
      return ref.read(meetupChatSummaryProvider(chatId));
    }

    final chats = ref.read(meetupChatsLocalStateProvider) ??
        ref.read(meetupChatsProvider).valueOrNull;
    if (chats == null) {
      return null;
    }
    for (final chat in chats) {
      if (chat.routeId == widget.routeId) {
        return chat;
      }
    }
    return null;
  }

  void _patchChatSummary({
    required String chatId,
    required EveningRouteData route,
    required List<String> diff,
  }) {
    final local = ref.read(meetupChatsLocalStateProvider);
    final remote = ref.read(meetupChatsProvider).valueOrNull;
    final chats = local ?? remote;
    if (chats == null) {
      ref.invalidate(meetupChatsProvider);
      return;
    }

    ref.read(meetupChatsLocalStateProvider.notifier).state = [
      for (final chat in chats)
        chat.id == chatId
            ? chat.copyWith(
                title: route.title,
                time: route.durationLabel,
                privacy: _privacy,
                maxGuests: _maxGuests,
                clearMaxGuests: _maxGuests == null,
                area: route.area,
                lastAuthor: diff.isEmpty ? chat.lastAuthor : 'Frendly',
                lastMessage:
                    diff.isEmpty ? chat.lastMessage : _diffHeadline(diff),
                lastTime: diff.isEmpty ? chat.lastTime : 'сейчас',
              )
            : chat,
    ];
  }

  String _diffMessage(List<String> diff) {
    if (diff.length == 1) {
      return '✏️ План обновлён · ${diff.first}';
    }
    return '✏️ План обновлён · ${diff.length} изменений\n— ${diff.join('\n— ')}';
  }

  String _diffHeadline(List<String> diff) {
    return diff.length == 1
        ? '✏️ План обновлён · ${diff.first}'
        : '✏️ План обновлён · ${diff.length} изменений';
  }

  String _fallbackTrim(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _pluralStops(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return 'остановка';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'остановки';
    }
    return 'остановок';
  }

  void _pop() {
    final navigator = Navigator.maybeOf(context);
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
    }
  }
}

class _V5WashBackground extends StatelessWidget {
  const _V5WashBackground();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.warmStart,
              colors.paper,
              colors.warmEnd,
            ],
            stops: const [0, 0.56, 1],
          ),
        ),
      ),
    );
  }
}

class _V5Card extends StatelessWidget {
  const _V5Card({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.card, colors.paper],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F241D).withValues(alpha: 0.14),
            blurRadius: 48,
            offset: const Offset(0, 24),
            spreadRadius: -28,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.canSave,
    required this.onBack,
    required this.onSave,
    this.phase,
  });

  final bool canSave;
  final MeetupPhase? phase;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final subtitle = phase == MeetupPhase.live
        ? 'Live · правка только будущих шагов'
        : 'Изменения уйдут в чат участников';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.card.withValues(alpha: 0.96),
            colors.paper.withValues(alpha: 0.92),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          _RoundIconButton(
            onPressed: onBack,
            icon: const Icon(LucideIcons.chevron_left, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Kicker('Вечер'),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Редактировать '),
                      TextSpan(
                        text: 'вечер',
                        style: AppTextStyles.itemTitle.copyWith(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 17),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: colors.inkMute),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: canSave ? onSave : null,
            icon: const Icon(LucideIcons.check, size: 16),
            label: const Text('Сохранить'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.card,
              disabledBackgroundColor: colors.card,
              disabledForegroundColor: colors.inkMute,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
              textStyle: AppTextStyles.meta.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.onPressed,
    required this.icon,
  });

  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.card,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F241D).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
              spreadRadius: -10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        color: colors.inkMute,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.4,
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F241D).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.secondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: AppTextStyles.meta)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.disabled = false,
  });

  final String title;
  final bool disabled;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Kicker(title),
              ),
              if (disabled)
                Row(
                  children: [
                    Icon(LucideIcons.lock, size: 12, color: colors.inkMute),
                    const SizedBox(width: 4),
                    Text(
                      'заморожено',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.inkMute,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children.expand(
            (child) => [child, const SizedBox(height: AppSpacing.sm)],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: colors.inkMute,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.04,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    this.enabled = true,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

class _PremiumToggle extends StatelessWidget {
  const _PremiumToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: value ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? colors.accent : colors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F241D).withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
              spreadRadius: -14,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.crown,
              size: 16,
              color: value ? colors.background : colors.inkSoft,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Frendly+ маршрут',
                style: AppTextStyles.meta.copyWith(
                  color: value ? colors.background : colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value ? 'Вкл' : 'Выкл',
              style: AppTextStyles.caption.copyWith(
                color: value ? colors.background : colors.inkMute,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.icon,
    required this.label,
    required this.hint,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const activeColor = Color(0xFFB26F4A);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: active ? activeColor : colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? activeColor : colors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F241D).withValues(
                alpha: active ? 0.18 : 0.08,
              ),
              blurRadius: active ? 24 : 18,
              offset: const Offset(0, 12),
              spreadRadius: active ? -14 : -16,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17, color: active ? colors.background : colors.inkSoft),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.meta.copyWith(
                      color: active ? colors.background : colors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hint,
                    style: AppTextStyles.caption.copyWith(
                      color: active
                          ? colors.background.withValues(alpha: 0.72)
                          : colors.inkMute,
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              Icon(LucideIcons.check, size: 16, color: colors.background),
          ],
        ),
      ),
    );
  }
}

class _GuestLimitControl extends StatelessWidget {
  const _GuestLimitControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _Field(
      label: 'Лимит мест',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SquareButton(
                icon: LucideIcons.minus,
                enabled: enabled,
                onTap: () =>
                    onChanged((value ?? 6) <= 2 ? 2 : (value ?? 6) - 1),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.users,
                        size: 16,
                        color: colors.inkMute,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        value == null ? 'без лимита' : '$value мест',
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _SquareButton(
                icon: LucideIcons.plus,
                enabled: enabled,
                onTap: () =>
                    onChanged((value ?? 6) >= 50 ? 50 : (value ?? 6) + 1),
              ),
            ],
          ),
          if (value != null && enabled)
            TextButton(
              onPressed: () => onChanged(null),
              child: const Text('Убрать лимит'),
            ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: colors.foreground),
      ),
    );
  }
}

class _StepEditorCard extends StatelessWidget {
  const _StepEditorCard({
    required this.step,
    required this.index,
    required this.total,
    required this.editable,
    required this.passed,
    required this.expanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.onToggle,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    super.key,
  });

  final EveningRouteStep step;
  final int index;
  final int total;
  final bool editable;
  final bool passed;
  final bool expanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final VoidCallback onToggle;
  final ValueChanged<EveningRouteStep> onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Opacity(
      opacity: editable ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.card, colors.paper],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.border,
            style: editable ? BorderStyle.solid : BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F241D).withValues(alpha: 0.1),
              blurRadius: 28,
              offset: const Offset(0, 16),
              spreadRadius: -22,
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: editable ? onToggle : null,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: expanded ? colors.accent : colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: expanded ? colors.accent : colors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: AppTextStyles.meta.copyWith(
                          color: expanded ? colors.card : colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(step.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTextStyles.itemTitle.copyWith(fontSize: 14),
                          ),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: 12,
                                color: colors.inkMute,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${step.time}${step.endTime == null ? '' : ' — ${step.endTime}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: colors.inkMute,
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Text(
                                  '·',
                                  style: AppTextStyles.caption.copyWith(
                                    color: colors.inkMute.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                              ),
                              Icon(
                                LucideIcons.map_pin,
                                size: 12,
                                color: colors.inkMute,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  step.venue,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: colors.inkMute,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (passed)
                      Text(
                        'пройден',
                        style: AppTextStyles.caption.copyWith(
                          color: colors.inkMute,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (expanded && editable)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MiniField(
                            label: 'Старт',
                            value: step.time,
                            onChanged: (value) =>
                                onChanged(step.copyWith(time: value)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _MiniField(
                            label: 'Конец',
                            value: step.endTime ?? '',
                            onChanged: (value) => onChanged(
                              step.copyWith(
                                endTime: value,
                                clearEndTime: value.trim().isEmpty,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _MiniField(
                      label: 'Название',
                      value: step.title,
                      onChanged: (value) =>
                          onChanged(step.copyWith(title: value)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniField(
                            label: 'Место',
                            value: step.venue,
                            onChanged: (value) =>
                                onChanged(step.copyWith(venue: value)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _MiniField(
                            label: 'Эмодзи',
                            value: step.emoji,
                            textAlign: TextAlign.center,
                            onChanged: (value) => onChanged(
                              step.copyWith(
                                emoji: value.characters.take(2).toString(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _MiniField(
                      label: 'Адрес',
                      value: step.address,
                      onChanged: (value) =>
                          onChanged(step.copyWith(address: value)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniField(
                            label: 'Перк',
                            value: step.perk ?? '',
                            onChanged: (value) => onChanged(
                              step.copyWith(
                                perk: value,
                                clearPerk: value.trim().isEmpty,
                                perkShort: value.trim().isEmpty
                                    ? null
                                    : step.perkShort ?? value.trim(),
                                clearPerkShort: value.trim().isEmpty,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _MiniField(
                            label: 'Билет, ₽',
                            value: step.ticketPrice?.toString() ?? '',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) => onChanged(
                              step.copyWith(
                                ticketPrice: int.tryParse(value),
                                clearTicketPrice: value.trim().isEmpty,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: canMoveUp ? onMoveUp : null,
                          icon: const Icon(LucideIcons.arrow_up, size: 16),
                        ),
                        IconButton(
                          onPressed: canMoveDown ? onMoveDown : null,
                          icon: const Icon(LucideIcons.arrow_down, size: 16),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: canRemove && total > 1 ? onRemove : null,
                          icon: const Icon(LucideIcons.trash_2, size: 16),
                          label: const Text('Удалить'),
                        ),
                      ],
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

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9.5,
              color: colors.inkMute,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textAlign: textAlign,
            style: AppTextStyles.meta.copyWith(color: colors.foreground),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStepButton extends StatelessWidget {
  const _AddStepButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 16, color: colors.inkSoft),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Добавить шаг',
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 13,
                color: colors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickySave extends StatelessWidget {
  const _StickySave({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.paper.withValues(alpha: 0),
            colors.paper,
          ],
          stops: const [0, 0.34],
        ),
      ),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(LucideIcons.sparkles, size: 17),
        label: const Text('Сохранить и уведомить чат'),
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.card,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.meta.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
