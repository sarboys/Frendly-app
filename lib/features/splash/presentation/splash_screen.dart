import 'dart:async';
import 'dart:math' as math;

import 'package:big_break_mobile/app/core/device/app_haptic_service.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_router.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
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
              Center(child: _CircleOfFriendsSplashScene(value: value)),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.sizeOf(context).height * 0.18,
                child: _CircleSplashLogo(value: value),
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

class _CircleOfFriendsSplashScene extends StatelessWidget {
  const _CircleOfFriendsSplashScene({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final stage = _stageFromValue(value);
    final ring = _interval(value, 0.34, 0.56, curve: Curves.easeOutBack);
    final orbitOpacity = stage >= 2 ? 1.0 : 0.0;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (stage >= 2)
            Opacity(
              opacity: ring.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: (0.2 + ring * 0.8).clamp(0.2, 1.08),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        BbV5Colors.paperHi,
                        BbV5Colors.terraSoft.withValues(alpha: 0.2),
                        BbV5Colors.terraSoft.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.6, 0.8],
                    ),
                  ),
                ),
              ),
            ),
          if (stage >= 1)
            AnimatedOpacity(
              opacity: orbitOpacity,
              duration: const Duration(milliseconds: 400),
              child: Transform.rotate(
                angle: value * math.pi * 2,
                child: const SizedBox(
                  width: 192,
                  height: 192,
                  child: CustomPaint(painter: _DashedCirclePainter()),
                ),
              ),
            ),
          if (stage >= 2) _CircleSplashHeart(value: value),
          if (stage >= 1)
            for (var i = 0; i < _circleSplashPeople.length; i++)
              _CircleSplashPerson(
                person: _circleSplashPeople[i],
                index: i,
                value: value,
              ),
          if (stage >= 2)
            for (var i = 0; i < 6; i++)
              _CircleSplashSpark(index: i, value: value),
        ],
      ),
    );
  }
}

class _CircleSplashHeart extends StatelessWidget {
  const _CircleSplashHeart({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final grow = _interval(value, 0.34, 0.53, curve: Curves.easeOutBack);
    final pulse = (math.sin(value * math.pi * 5.6) + 1) / 2;

    return Opacity(
      opacity: grow.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: (0.2 + grow * 0.8).clamp(0.2, 1.08),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: BbV5Colors.accentDeep.withValues(alpha: 0.52),
                blurRadius: 32,
                spreadRadius: -10,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: BbV5Colors.terra.withValues(alpha: 0.2 * pulse),
                blurRadius: 18 + 16 * pulse,
                spreadRadius: 2 + 8 * pulse,
              ),
            ],
          ),
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
    );
  }
}

class _CircleSplashPerson extends StatelessWidget {
  const _CircleSplashPerson({
    required this.person,
    required this.index,
    required this.value,
  });

  final _CircleSplashPersonData person;
  final int index;
  final double value;

  @override
  Widget build(BuildContext context) {
    final begin = (80 + index * 70) / 3200;
    final end = (980 + index * 70) / 3200;
    final fly = _interval(value, begin, end, curve: Curves.easeOutBack);
    final opacity = _interval(value, begin, begin + 0.12).clamp(0.0, 1.0);
    final bobPhase = value * math.pi * 2.8 + index * 0.72;
    final bob = value >= 0.34 ? -4 * ((math.sin(bobPhase) + 1) / 2) : 0.0;
    final from = Offset(person.offset.dx * 5, person.offset.dy * 5);
    final to = Offset(person.offset.dx, person.offset.dy + bob);
    final offset = Offset(
      from.dx + (to.dx - from.dx) * fly,
      from.dy + (to.dy - from.dy) * fly,
    );

    return Positioned(
      left: 120 - 24 + offset.dx,
      top: 120 - 24 + offset.dy,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: (0.4 + 0.6 * fly).clamp(0.4, 1.06),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: person.color,
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
            child: Text(
              person.emoji,
              style: const TextStyle(
                color: BbV5Colors.paperHi,
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

class _CircleSplashSpark extends StatelessWidget {
  const _CircleSplashSpark({
    required this.index,
    required this.value,
  });

  final int index;
  final double value;

  @override
  Widget build(BuildContext context) {
    final begin = (1100 + 600 + index * 120) / 3200;
    final progress = ((value - begin) / (1400 / 3200)) % 1.0;
    final active = value >= begin;
    final scale = progress < 0.4 ? progress / 0.4 : 1 - (progress - 0.4) / 0.6;
    final opacity =
        active ? (progress < 0.4 ? progress / 0.4 : 1 - progress) : 0.0;
    final angle = index * math.pi / 3;
    final x = math.sin(angle) * 46;
    final y = -math.cos(angle) * 46;

    return Positioned(
      left: 120 - 8 + x,
      top: 120 - 8 + y,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle + progress * math.pi,
          child: Transform.scale(
            scale: scale.clamp(0.0, 1.0),
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
    );
  }
}

class _CircleSplashLogo extends StatelessWidget {
  const _CircleSplashLogo({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final word = _interval(value, 0.59, 0.78, curve: Curves.easeOutCubic);
    final caption = _interval(value, 0.65, 0.84, curve: Curves.easeOutCubic);

    if (word == 0 && caption == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: word.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - word.clamp(0.0, 1.0))),
            child: _CircleSplashWord(value: value),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: caption.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - caption.clamp(0.0, 1.0))),
            child: const Text(
              'ГОРОД · ЛЮДИ · ВЕЧЕР',
              style: TextStyle(
                color: BbV5Colors.inkMute,
                fontFamily: 'Sora',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.76,
                height: 1,
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
            0.59 + index * 0.018,
            0.78 + index * 0.018,
            curve: Curves.easeOutCubic,
          ).clamp(0.0, 1.0);
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
                  letterSpacing: 0,
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

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BbV5Colors.terra.withValues(alpha: 0.34)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - paint.strokeWidth) / 2;
    const dashCount = 42;
    const gapRadians = 0.045;
    final dashRadians = (math.pi * 2 / dashCount) - gapRadians;

    for (var i = 0; i < dashCount; i++) {
      final start = i * math.pi * 2 / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashRadians,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}

int _stageFromValue(double value) {
  if (value < 0.025) {
    return 0;
  }
  if (value < 0.34) {
    return 1;
  }
  if (value < 0.59) {
    return 2;
  }
  return 3;
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

class _CircleSplashPersonData {
  const _CircleSplashPersonData({
    required this.offset,
    required this.color,
    required this.emoji,
  });

  final Offset offset;
  final Color color;
  final String emoji;
}

const _circleSplashPeople = [
  _CircleSplashPersonData(
    offset: Offset(0, -90),
    color: BbV5Colors.terra,
    emoji: '👋',
  ),
  _CircleSplashPersonData(
    offset: Offset(78, -45),
    color: BbV5Colors.brand,
    emoji: '✨',
  ),
  _CircleSplashPersonData(
    offset: Offset(78, 45),
    color: BbV5Colors.gold,
    emoji: '🍷',
  ),
  _CircleSplashPersonData(
    offset: Offset(0, 90),
    color: BbV5Colors.rose,
    emoji: '💛',
  ),
  _CircleSplashPersonData(
    offset: Offset(-78, 45),
    color: BbV5Colors.brandDeep,
    emoji: '🎷',
  ),
  _CircleSplashPersonData(
    offset: Offset(-78, -45),
    color: BbV5Colors.accent,
    emoji: '☕',
  ),
];

const _splashIntroDuration = Duration(milliseconds: 3200);
