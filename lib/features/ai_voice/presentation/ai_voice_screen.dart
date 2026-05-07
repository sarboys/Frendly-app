import 'dart:async';

import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

enum _VoicePhase { idle, listening, thinking, ready }

class AiVoiceScreen extends StatefulWidget {
  const AiVoiceScreen({super.key});

  @override
  State<AiVoiceScreen> createState() => _AiVoiceScreenState();
}

class _AiVoiceScreenState extends State<AiVoiceScreen>
    with SingleTickerProviderStateMixin {
  static const _promptExamples = [
    'Хочу винчик и джаз на двоих в районе центра до 23',
    'Тихий ужин и долгая прогулка, не громко',
    'After work на 4х, бар у работы, не дороже 2000',
  ];

  late final AnimationController _pulseController;
  Timer? _typingTimer;
  Timer? _thinkingTimer;
  int _voiceGeneration = 0;
  _VoicePhase _phase = _VoicePhase.idle;
  String _transcript = '';

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
    _thinkingTimer?.cancel();
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
                    BbV5Kicker(_phaseLabel),
                    const SizedBox(height: 12),
                    if (_transcript.isEmpty)
                      Text(
                        'Скажи, какой вечер хочешь. Я соберу 2-3 места и предложу людей рядом.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.meta.copyWith(
                          color: BbV5Colors.inkSoft,
                          height: 1.5,
                        ),
                      )
                    else
                      Text(
                        '«$_transcript${_phase == _VoicePhase.listening ? '|' : ''}»',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          fontFamily: 'InstrumentSerif',
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: BbV5Colors.ink,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_phase == _VoicePhase.idle) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
                child: _RoutePlan(onReset: _reset),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              const SliverToBoxAdapter(child: _NearbyPeople()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: BbV5PillButton(
                  label: 'Превратить в встречу',
                  icon: LucideIcons.send,
                  dark: true,
                  height: 56,
                  expanded: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Встреча создана')),
                    );
                  },
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
      _VoicePhase.idle => 'Нажми и говори',
      _VoicePhase.listening => 'Слушаю',
      _VoicePhase.thinking => 'Собираю маршрут',
      _VoicePhase.ready => 'Готово',
    };
  }

  void _startListening() {
    final generation = ++_voiceGeneration;
    _typingTimer?.cancel();
    _thinkingTimer?.cancel();
    setState(() {
      _phase = _VoicePhase.listening;
      _transcript = '';
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
        _completeThinking(generation);
      }
    });
  }

  void _stopListening() {
    _voiceGeneration += 1;
    _typingTimer?.cancel();
    _thinkingTimer?.cancel();
    setState(() {
      _phase = _VoicePhase.idle;
    });
  }

  void _usePreset(String text) {
    final generation = ++_voiceGeneration;
    _typingTimer?.cancel();
    _thinkingTimer?.cancel();
    setState(() {
      _transcript = text;
      _phase = _VoicePhase.thinking;
    });
    _thinkingTimer = Timer(
      const Duration(milliseconds: 1200),
      () => _showReady(generation),
    );
  }

  void _completeThinking(int generation) {
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || generation != _voiceGeneration) {
        return;
      }
      setState(() {
        _phase = _VoicePhase.thinking;
      });
      _thinkingTimer = Timer(
        const Duration(milliseconds: 1500),
        () => _showReady(generation),
      );
    });
  }

  void _showReady(int generation) {
    if (!mounted || !context.mounted || generation != _voiceGeneration) {
      return;
    }
    setState(() {
      _phase = _VoicePhase.ready;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Маршрут готов')),
    );
  }

  void _reset() {
    _voiceGeneration += 1;
    _typingTimer?.cancel();
    _thinkingTimer?.cancel();
    setState(() {
      _phase = _VoicePhase.idle;
      _transcript = '';
    });
  }
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
                fontStyle: FontStyle.italic,
                color: BbV5Colors.inkSoft,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePlan extends StatelessWidget {
  const _RoutePlan({required this.onReset});

  final VoidCallback onReset;

  static const _stops = [
    _StopData(
      time: '19:30',
      place: 'Brix',
      subtitle: 'винный бар · оранж и тапас',
      tag: 'Винчик',
      icon: LucideIcons.wine,
      color: BbV5Colors.terra,
    ),
    _StopData(
      time: '21:30',
      place: 'Powerhouse',
      subtitle: 'live jazz set, негромко',
      tag: 'Джаз',
      icon: LucideIcons.music,
      color: BbV5Colors.brand,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'Маршрут',
      right: TextButton.icon(
        onPressed: onReset,
        icon: const Icon(LucideIcons.refresh_cw, size: 12),
        label: const Text('Заново'),
        style: TextButton.styleFrom(
          foregroundColor: BbV5Colors.accent,
          textStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      margin: EdgeInsets.zero,
      child: BbV5Card(
        radius: 24,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (var index = 0; index < _stops.length; index++)
              _StopRow(
                stop: _stops[index],
                showLine: index < _stops.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _StopData {
  const _StopData({
    required this.time,
    required this.place,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.color,
  });

  final String time;
  final String place;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color color;
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.showLine,
  });

  final _StopData stop;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
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
                  color: stop.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(stop.icon, size: 20, color: BbV5Colors.paperHi),
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
                        color: stop.color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${stop.tag}',
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.inkMute,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stop.place,
                  style: bbV5DisplayStyle(fontSize: 15, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(
                  stop.subtitle,
                  style: AppTextStyles.caption.copyWith(
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

class _NearbyPeople extends StatelessWidget {
  const _NearbyPeople();

  static const List<
      ({
        String name,
        String match,
        String tags,
        Color colorOne,
        Color colorTwo,
      })> _people = [
    (
      name: 'Аня',
      match: '94% совпадение',
      tags: 'вино · джаз',
      colorOne: Color(0xFFD8B4A0),
      colorTwo: Color(0xFFA87966),
    ),
    (
      name: 'Лев',
      match: '88% совпадение',
      tags: 'джаз · центр',
      colorOne: Color(0xFF9CB39F),
      colorTwo: Color(0xFF5F7C68),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'Можно позвать',
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          for (final person in _people) ...[
            Expanded(child: _PersonCard(person: person)),
            if (person != _people.last) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final ({
    String name,
    String match,
    String tags,
    Color colorOne,
    Color colorTwo,
  }) person;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [person.colorOne, person.colorTwo],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                person.name,
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.paperHi,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          BbV5Kicker(person.match.toUpperCase(), color: BbV5Colors.accent),
          const SizedBox(height: 4),
          Text(
            person.tags,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
