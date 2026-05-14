import 'dart:async';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/evening_route_publish_draft.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _VoicePhase { idle, listening, thinking, ready }

class AiVoiceScreen extends ConsumerStatefulWidget {
  const AiVoiceScreen({super.key});

  @override
  ConsumerState<AiVoiceScreen> createState() => _AiVoiceScreenState();
}

class _AiVoiceScreenState extends ConsumerState<AiVoiceScreen>
    with SingleTickerProviderStateMixin {
  static const _promptExamples = [
    'Хочу винчик и джаз на двоих в районе центра до 23',
    'Тихий ужин и долгая прогулка, не громко',
    'After work на 4х, бар у работы, не дороже 2000',
  ];

  late final AnimationController _pulseController;
  Timer? _typingTimer;
  CancelToken? _resolveCancelToken;
  int _voiceGeneration = 0;
  _VoicePhase _phase = _VoicePhase.idle;
  String _transcript = '';
  String? _errorText;
  EveningRouteData? _route;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _voiceGeneration += 1;
    _typingTimer?.cancel();
    _cancelResolveRequest('ai_voice_disposed');
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BbV5TopBar(
                kicker: 'AI · голос',
                title: 'Собрать',
                accent: 'вечер',
                onBack: () => context.pop(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: BbV5Card(
                tint: BbV5Colors.terraSoft,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _MicButton(
                      phase: _phase,
                      pulseController: _pulseController,
                      onTap: _phase == _VoicePhase.thinking
                          ? null
                          : _phase == _VoicePhase.listening
                              ? _stopListening
                              : _startListening,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _phaseLabel,
                      style: bbV5KickerStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_transcript.isEmpty)
                      Text(
                        'Скажи, какой вечер хочешь. Я соберу 2-3 места и предложу людей рядом.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.meta.copyWith(
                          fontSize: 13,
                          color: BbV5Colors.inkSoft,
                          height: 1.625,
                        ),
                      )
                    else
                      Text(
                        '«$_transcript${_phase == _VoicePhase.listening ? '|' : ''}»',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          fontFamily: 'InstrumentSerif',
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: BbV5Colors.ink,
                          height: 1.375,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_phase == _VoicePhase.idle) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: BbV5Section(
                  title: 'Или выбери пример',
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final prompt in _promptExamples) ...[
                        _PromptPreset(
                          text: prompt,
                          onTap: () => _usePreset(prompt),
                        ),
                        if (prompt != _promptExamples.last)
                          const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (_phase == _VoicePhase.ready) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: _RoutePlan(route: _route, onReset: _reset),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: BbV5PillButton(
                  label: 'Превратить в встречу',
                  icon: LucideIcons.send,
                  dark: true,
                  height: 56,
                  fontSize: 14,
                  expanded: true,
                  onPressed: _route == null ? null : _openRoute,
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
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
            ],
          ],
        ),
      ),
    );
  }

  String get _phaseLabel {
    return switch (_phase) {
      _VoicePhase.idle => 'НАЖМИ И ГОВОРИ',
      _VoicePhase.listening => 'СЛУШАЮ…',
      _VoicePhase.thinking => 'СОБИРАЮ МАРШРУТ',
      _VoicePhase.ready => 'ГОТОВО',
    };
  }

  void _startListening() {
    final generation = ++_voiceGeneration;
    _typingTimer?.cancel();
    _cancelResolveRequest('ai_voice_replaced');
    setState(() {
      _phase = _VoicePhase.listening;
      _transcript = '';
      _route = null;
      _errorText = null;
    });

    final text = _promptExamples[0];
    var index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted || generation != _voiceGeneration) {
        timer.cancel();
        return;
      }
      index += 1;
      setState(() {
        _transcript = text.substring(0, index.clamp(0, text.length));
      });
      if (index >= text.length) {
        timer.cancel();
        _resolveVoicePrompt(text, generation);
      }
    });
  }

  void _stopListening() {
    _voiceGeneration += 1;
    _typingTimer?.cancel();
    _cancelResolveRequest('ai_voice_stopped');
    setState(() {
      _phase = _VoicePhase.idle;
    });
  }

  void _usePreset(String text) {
    final generation = ++_voiceGeneration;
    _typingTimer?.cancel();
    _cancelResolveRequest('ai_voice_replaced');
    setState(() {
      _transcript = text;
      _phase = _VoicePhase.thinking;
      _route = null;
      _errorText = null;
    });
    unawaited(_resolveVoicePrompt(text, generation));
  }

  Future<void> _resolveVoicePrompt(String text, int generation) async {
    _cancelResolveRequest('ai_voice_resolve_replaced');
    final cancelToken = CancelToken();
    _resolveCancelToken = cancelToken;
    if (mounted) {
      setState(() {
        _phase = _VoicePhase.thinking;
      });
    }
    try {
      final json =
          await ref.read(backendRepositoryProvider).resolveEveningRoute(
                goal: _goalKeyForPrompt(text),
                mood: _moodKeyForPrompt(text),
                budget: _budgetKeyForPrompt(text),
                format: _formatKeyForPrompt(text),
                prompt: text,
                cancelToken: cancelToken,
              );
      if (!mounted ||
          generation != _voiceGeneration ||
          cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return;
      }
      final route = eveningRouteFromJson(json);
      if (route.steps.isEmpty) {
        setState(() {
          _phase = _VoicePhase.idle;
          _errorText = 'Маршрут не собрался. Попробуй сказать чуть подробнее.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Маршрут не собран')),
        );
        return;
      }
      setState(() {
        _route = route;
        _phase = _VoicePhase.ready;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Маршрут готов')),
      );
    } catch (_) {
      if (!mounted ||
          generation != _voiceGeneration ||
          cancelToken.isCancelled ||
          !identical(_resolveCancelToken, cancelToken)) {
        return;
      }
      setState(() {
        _phase = _VoicePhase.idle;
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

  void _reset() {
    _voiceGeneration += 1;
    _typingTimer?.cancel();
    _cancelResolveRequest('ai_voice_reset');
    setState(() {
      _phase = _VoicePhase.idle;
      _transcript = '';
      _route = null;
      _errorText = null;
    });
  }

  void _cancelResolveRequest(String reason) {
    final cancelToken = _resolveCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
  }

  void _openRoute() {
    final route = _route;
    if (route == null || route.id.isEmpty) {
      return;
    }
    context.pushRoute(
      AppRoute.publishMeetup,
      extra: publishDraftFromEveningRoute(route),
    );
  }
}

String _goalKeyForPrompt(String prompt) {
  final text = prompt.toLowerCase();
  if (text.contains('дво') || text.contains('свид')) {
    return 'date';
  }
  if (text.contains('компан') || text.contains('4') || text.contains('5')) {
    return 'company';
  }
  return 'newfriends';
}

String _moodKeyForPrompt(String prompt) {
  final text = prompt.toLowerCase();
  if (text.contains('тих') || text.contains('спокой')) {
    return 'chill';
  }
  if (text.contains('свид') || text.contains('роман')) {
    return 'date';
  }
  return 'social';
}

String _budgetKeyForPrompt(String prompt) {
  final text = prompt.toLowerCase();
  if (text.contains('бесплат')) {
    return 'free';
  }
  if (text.contains('1500') || text.contains('2000')) {
    return 'low';
  }
  if (text.contains('3500')) {
    return 'mid';
  }
  return 'mid';
}

String _formatKeyForPrompt(String prompt) {
  final text = prompt.toLowerCase();
  if (text.contains('бар') || text.contains('вин')) {
    return 'bar';
  }
  if (text.contains('джаз') || text.contains('концерт')) {
    return 'show';
  }
  if (text.contains('прогул') || text.contains('спорт')) {
    return 'active';
  }
  return 'mixed';
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.phase,
    required this.pulseController,
    required this.onTap,
  });

  final _VoicePhase phase;
  final AnimationController pulseController;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final listening = phase == _VoicePhase.listening;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (listening)
              AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) {
                  final value = pulseController.value;
                  return Container(
                    width: 118 + value * 28,
                    height: 118 + value * 28,
                    decoration: BoxDecoration(
                      color: BbV5Colors.accent.withValues(
                        alpha: (1 - value) * 0.35,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            Container(
              width: 128,
              height: 128,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
                ),
                boxShadow: BbV5Shadows.ink,
              ),
              child: phase == _VoicePhase.thinking
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: BbV5Colors.paperHi,
                      ),
                    )
                  : Icon(
                      listening ? LucideIcons.mic_off : LucideIcons.mic,
                      size: 48,
                      color: BbV5Colors.paperHi,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptPreset extends StatelessWidget {
  const _PromptPreset({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            LucideIcons.sparkles,
            size: 16,
            color: BbV5Colors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '«$text»',
              style: AppTextStyles.body.copyWith(
                fontFamily: 'InstrumentSerif',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: BbV5Colors.inkSoft,
                height: 1.375,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePlan extends StatelessWidget {
  const _RoutePlan({
    required this.route,
    required this.onReset,
  });

  final EveningRouteData? route;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final steps = route?.steps ?? const <EveningRouteStep>[];
    return BbV5Section(
      title: 'Маршрут',
      right: TextButton.icon(
        onPressed: onReset,
        icon: const Icon(LucideIcons.refresh_cw, size: 12),
        label: const Text('Заново'),
        style: TextButton.styleFrom(
          foregroundColor: BbV5Colors.accent,
          textStyle: AppTextStyles.caption.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      margin: EdgeInsets.zero,
      child: BbV5Card(
        radius: 24,
        padding: const EdgeInsets.all(8),
        child: steps.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Маршрут появится после ответа сервера.',
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkMute,
                    height: 1.45,
                  ),
                ),
              )
            : Column(
                children: [
                  for (var index = 0; index < steps.length; index++)
                    _StopRow(
                      stop: steps[index],
                      showLine: index < steps.length - 1,
                    ),
                ],
              ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.showLine,
  });

  final EveningRouteStep stop;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final color = _stopColor(stop.kind);
    final place = stop.venue.trim().isNotEmpty ? stop.venue : stop.title;
    final subtitle = stop.description?.trim().isNotEmpty == true
        ? stop.description!.trim()
        : stop.address.trim().isNotEmpty
            ? stop.address
            : stop.distance;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _stopIcon(stop.kind),
                  size: 20,
                  color: BbV5Colors.paperHi,
                ),
              ),
              if (showLine)
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.only(top: 8),
                  color: BbV5Colors.hair,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stop.time,
                      style: AppTextStyles.caption.copyWith(
                        fontFamily: 'Sora',
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${eveningKindLabel(stop.kind)}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: BbV5Colors.inkMute,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  place,
                  style: bbV5DisplayStyle(fontSize: 15, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: BbV5Colors.inkMute,
                    letterSpacing: 0,
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

Color _stopColor(EveningStepKind kind) {
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

IconData _stopIcon(EveningStepKind kind) {
  return switch (kind) {
    EveningStepKind.bar => LucideIcons.wine,
    EveningStepKind.show => LucideIcons.music,
    EveningStepKind.active => LucideIcons.footprints,
    EveningStepKind.dinner => LucideIcons.utensils,
    EveningStepKind.wellness => LucideIcons.sparkles,
    EveningStepKind.afterparty => LucideIcons.moon,
    EveningStepKind.followup => LucideIcons.sun,
  };
}
