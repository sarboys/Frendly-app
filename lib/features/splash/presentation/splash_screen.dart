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
              Positioned.fill(
                child: CustomPaint(
                  painter: _LiquidWashPainter(value),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (stage <= 1) _FallingDrop(value: value),
                      if (stage >= 1 && stage < 4) _InkBlob(value: value),
                      if (stage >= 2 && stage < 4) _LiquidWord(value: value),
                      if (stage >= 4) _LiquidLogo(value: value),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: _LiquidProgress(value: value),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiquidWashPainter extends CustomPainter {
  const _LiquidWashPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, -0.18 + value * 0.08),
        radius: 0.74,
        colors: [
          BbV5Colors.terraSoft.withValues(alpha: 0.42),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidWashPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _FallingDrop extends StatelessWidget {
  const _FallingDrop({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final progress = _interval(value, 0.02, 0.24, curve: Curves.easeInOutCubic);
    final squash = _interval(value, 0.18, 0.27, curve: Curves.easeOutBack);
    return Transform.translate(
      offset: Offset(0, -220 + 220 * progress),
      child: Transform.scale(
        scaleX: 0.74 + 0.28 * squash,
        scaleY: 1.22 - 0.2 * squash,
        child: Container(
          width: 64,
          height: 84,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.35, -0.45),
              colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(42),
              topRight: Radius.circular(42),
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
            boxShadow: BbV5Shadows.ink,
          ),
        ),
      ),
    );
  }
}

class _InkBlob extends StatelessWidget {
  const _InkBlob({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final spread = _interval(value, 0.22, 0.48, curve: Curves.easeInOutCubic);
    final collapse = _interval(value, 0.73, 0.94, curve: Curves.easeInOutCubic);
    final scale = 0.1 + spread * 2.95 - collapse * 2.56;
    final radiusA = 120.0 - 42 * spread + 22 * collapse;
    final radiusB = 98.0 + 28 * spread - 18 * collapse;
    return Transform.scale(
      scale: scale.clamp(0.1, 3.05),
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(-0.28, -0.34),
            colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radiusA),
            topRight: Radius.circular(radiusB),
            bottomLeft: Radius.circular(radiusB + 18),
            bottomRight: Radius.circular(radiusA - 14),
          ),
          boxShadow: BbV5Shadows.ink,
        ),
      ),
    );
  }
}

class _LiquidWord extends StatelessWidget {
  const _LiquidWord({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    const letters = 'Frendly';
    final exit = _interval(value, 0.7, 0.82, curve: Curves.easeOutCubic);
    return Opacity(
      opacity: (1 - exit).clamp(0, 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(letters.length, (index) {
          final progress = _interval(
            value,
            0.44 + index * 0.025,
            0.62 + index * 0.025,
            curve: Curves.easeOutCubic,
          );
          final first = index == 0;
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, 22 * (1 - progress)),
              child: Text(
                letters[index],
                style: TextStyle(
                  fontFamily: first ? 'Sora' : 'InstrumentSerif',
                  fontStyle: first ? FontStyle.normal : FontStyle.italic,
                  fontSize: 56,
                  height: 1,
                  fontWeight: first ? FontWeight.w700 : FontWeight.w400,
                  color: BbV5Colors.paper,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LiquidLogo extends StatelessWidget {
  const _LiquidLogo({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final pop = _interval(value, 0.86, 1, curve: Curves.elasticOut);
    return Transform.scale(
      scale: 0.8 + 0.2 * pop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: BbV5Shadows.ink,
            ),
            child: Text(
              'Fr',
              style: bbV5DisplayStyle(
                fontSize: 30,
                color: BbV5Colors.paper,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _BrandReveal(value: value),
          const SizedBox(height: 12),
          Text(
            'ВЕЧЕР НАЧИНАЕТСЯ МЯГКО',
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidProgress extends StatelessWidget {
  const _LiquidProgress({required this.value});

  final double value;

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
          widthFactor: value.clamp(0, 1),
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

class _BrandReveal extends StatelessWidget {
  const _BrandReveal({required this.value});

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
            0.54 + index * 0.025,
            0.74 + index * 0.025,
            curve: Curves.easeOutCubic,
          );
          final isFirst = index == 0;
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, 28 * (1 - progress)),
              child: Text(
                letters[index],
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontStyle: isFirst ? FontStyle.normal : FontStyle.italic,
                  fontSize: 44,
                  height: 1,
                  fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                  color: isFirst ? BbV5Colors.ink : BbV5Colors.terra,
                ),
              ),
            ),
          );
        }),
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

const _splashIntroDuration = Duration(milliseconds: 3200);
