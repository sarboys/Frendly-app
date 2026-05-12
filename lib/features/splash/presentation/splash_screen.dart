import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_haptic_service.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_router.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _hapticTimer;
  bool _readyToClose = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _splashIntroDuration,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _readyToClose = true;
          });
        }
      })
      ..forward();
    final hapticService = ref.read(appHapticServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _hapticTimer = Timer(const Duration(milliseconds: 140), () {
        if (!mounted) {
          return;
        }
        hapticService.lightImpact();
      });
    });
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authTokens = ref.watch(authTokensProvider);
    final authBootstrap = ref.watch(authBootstrapProvider);
    final onboardingAsync =
        authTokens != null ? ref.watch(onboardingProvider) : null;
    final onboardingLoading =
        authTokens != null && (onboardingAsync?.isLoading ?? false);
    final onboarding = onboardingAsync?.valueOrNull;

    if (_readyToClose &&
        !_navigated &&
        !authBootstrap.isLoading &&
        !onboardingLoading) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.mounted) {
          return;
        }
        final pendingSetup = resolvePendingSetupRoute(onboarding);
        if (authTokens == null) {
          context.goRoute(AppRoute.welcome);
          return;
        }
        if (pendingSetup != null) {
          context.go(pendingSetup);
          return;
        }
        context.goRoute(AppRoute.tonight);
      });
    }

    return BbV5Scaffold(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          final stage = _stageFromValue(value);
          return Stack(
            children: [
              Positioned.fill(child: _CircleSplashWash(value: value)),
              Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _PeopleCircleScene(value: value, stage: stage),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: _CircleSplashProgress(stage: stage),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleSplashWash extends StatelessWidget {
  const _CircleSplashWash({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: BbV5Colors.paper),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.16 + value * 0.08),
              radius: 0.72,
              colors: const [
                BbV5Colors.terraSoft,
                Color(0x00EBC0A0),
              ],
              stops: const [0, 1],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: -150,
          height: 360,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x66C9D5BE), Color(0x00C9D5BE)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeopleCircleScene extends StatelessWidget {
  const _PeopleCircleScene({
    required this.value,
    required this.stage,
  });

  final double value;
  final int stage;

  @override
  Widget build(BuildContext context) {
    final ring = _interval(value, 0.34, 0.56, curve: Curves.easeOutBack);
    final logo = _interval(value, 0.58, 0.78, curve: Curves.easeOutCubic);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (stage >= 2)
          Transform.scale(
            scale: 0.18 + ring * 0.82,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BbV5Colors.paperHi,
                    BbV5Colors.terraSoft.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
          ),
        if (stage >= 1)
          Transform.rotate(
            angle: value * 1.1,
            child: Opacity(
              opacity: stage >= 2 ? 1 : 0,
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: BbV5Colors.terra.withValues(alpha: 0.34),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        if (stage >= 2) _Sparkles(value: value),
        if (stage >= 2)
          Transform.scale(
            scale: 0.72 + 0.09 * _pulse(value),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
                ),
                boxShadow: [
                  ...BbV5Shadows.ink,
                  BoxShadow(
                    color: BbV5Colors.terra.withValues(alpha: 0.22),
                    blurRadius: 28 + 18 * _pulse(value),
                    spreadRadius: 2 + 8 * _pulse(value),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '❤',
                style: TextStyle(
                  color: BbV5Colors.paperHi,
                  fontSize: 24,
                  height: 1,
                ),
              ),
            ),
          ),
        for (var i = 0; i < _splashPeople.length; i++)
          _FlyingPerson(
            data: _splashPeople[i],
            index: i,
            value: value,
            bob: stage >= 2,
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 276,
          child: Opacity(
            opacity: logo,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - logo)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleSplashWord(value: value),
                  const SizedBox(height: 12),
                  Text(
                    'ГОРОД · ЛЮДИ · ВЕЧЕР',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontFamily: 'Sora',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.76,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlyingPerson extends StatelessWidget {
  const _FlyingPerson({
    required this.data,
    required this.index,
    required this.value,
    required this.bob,
  });

  final _SplashPerson data;
  final int index;
  final double value;
  final bool bob;

  @override
  Widget build(BuildContext context) {
    final start = 0.04 + index * 0.035;
    final fly =
        _interval(value, start, start + 0.28, curve: Curves.easeOutBack);
    final from = Offset(data.offset.dx * 5, data.offset.dy * 5);
    final bobDy = bob ? -4 * _pulse(value + index * 0.08) : 0.0;
    final current = Offset.lerp(from, data.offset, fly)! + Offset(0, bobDy);
    return Transform.translate(
      offset: current,
      child: Opacity(
        opacity: fly,
        child: Transform.scale(
          scale: 0.42 + 0.58 * fly,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: data.color,
              shape: BoxShape.circle,
              border: Border.all(color: BbV5Colors.paperHi, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x591F241D),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              data.emoji,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 20,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sparkles extends StatelessWidget {
  const _Sparkles({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    const sparkOffsets = [
      Offset(0, -48),
      Offset(42, -24),
      Offset(42, 24),
      Offset(0, 48),
      Offset(-42, 24),
      Offset(-42, -24),
    ];
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < sparkOffsets.length; i++)
          Transform.translate(
            offset: sparkOffsets[i],
            child: Transform.rotate(
              angle: value * 5 + i * 0.35,
              child: Opacity(
                opacity: (0.35 + 0.65 * _pulse(value + i * 0.12)).clamp(0, 1),
                child: const Text(
                  '✦',
                  style: TextStyle(
                    color: BbV5Colors.gold,
                    fontSize: 14,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CircleSplashWord extends StatelessWidget {
  const _CircleSplashWord({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    const letters = 'Frendly';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(letters.length, (index) {
          final progress = _interval(
            value,
            0.58 + index * 0.018,
            0.72 + index * 0.018,
            curve: Curves.easeOutCubic,
          );
          final first = index == 0;
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - progress)),
              child: Text(
                letters[index],
                style: TextStyle(
                  fontFamily: first ? 'Sora' : 'InstrumentSerif',
                  fontStyle: first ? FontStyle.normal : FontStyle.italic,
                  fontSize: 40,
                  height: 1,
                  fontWeight: first ? FontWeight.w700 : FontWeight.w400,
                  color: first ? BbV5Colors.ink : BbV5Colors.accentDeep,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CircleSplashProgress extends StatelessWidget {
  const _CircleSplashProgress({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 128,
        height: 3,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: BbV5Colors.ink.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: FractionallySizedBox(
          widthFactor: (stage * 0.33).clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
              ),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashPerson {
  const _SplashPerson(this.offset, this.color, this.emoji);

  final Offset offset;
  final Color color;
  final String emoji;
}

const _splashPeople = [
  _SplashPerson(Offset(0, -90), BbV5Colors.terra, '👋'),
  _SplashPerson(Offset(78, -45), BbV5Colors.brand, '✨'),
  _SplashPerson(Offset(78, 45), BbV5Colors.gold, '🍷'),
  _SplashPerson(Offset(0, 90), BbV5Colors.rose, '💛'),
  _SplashPerson(Offset(-78, 45), BbV5Colors.brandDeep, '🎷'),
  _SplashPerson(Offset(-78, -45), BbV5Colors.accent, '☕'),
];

int _stageFromValue(double value) {
  if (value < 0.22) {
    return 0;
  }
  if (value < 0.44) {
    return 1;
  }
  if (value < 0.7) {
    return 2;
  }
  if (value < 0.86) {
    return 3;
  }
  return 4;
}

double _pulse(double value) {
  final loop = (value * 2.4) % 1;
  return loop < 0.5 ? loop * 2 : (1 - loop) * 2;
}

double _interval(
  double value,
  double begin,
  double end, {
  Curve curve = Curves.linear,
}) {
  final normalized = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
  return curve.transform(normalized);
}

const _splashIntroDuration = Duration(milliseconds: 3200);
