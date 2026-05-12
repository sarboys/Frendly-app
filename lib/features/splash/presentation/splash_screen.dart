import 'dart:async';

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
              Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: _FrendlySplashMark(value: value),
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

class _FrendlySplashMark extends StatelessWidget {
  const _FrendlySplashMark({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final tile = _interval(value, 0.08, 0.36, curve: Curves.easeOutCubic);
    final word = _interval(value, 0.28, 0.56, curve: Curves.easeOutCubic);
    final caption = _interval(value, 0.46, 0.72, curve: Curves.easeOutCubic);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Opacity(
          opacity: tile,
          child: Transform.scale(
            scale: 0.86 + 0.14 * tile,
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BbV5Colors.accent,
                borderRadius: BorderRadius.circular(24),
                boxShadow: BbV5Shadows.ink,
              ),
              child: const Text(
                'Fr',
                style: TextStyle(
                  color: BbV5Colors.paperHi,
                  fontFamily: 'Sora',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Opacity(
          opacity: word,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - word)),
            child: _CircleSplashWord(value: value),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: caption,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - caption)),
            child: const Text(
              'ГОРОД  ЛЮДИ  ВЕЧЕР',
              style: TextStyle(
                color: BbV5Colors.inkMute,
                fontFamily: 'Sora',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.2,
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

double _interval(
  double value,
  double begin,
  double end, {
  Curve curve = Curves.linear,
}) {
  final normalized = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
  return curve.transform(normalized);
}

const _splashIntroDuration = Duration(milliseconds: 1600);
