import 'dart:math' as math;

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/session/app_session_controller.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/welcome/application/social_auth_controller.dart';
import 'package:big_break_mobile/shared/models/auth_flow.dart';
import 'package:big_break_mobile/shared/widgets/bb_brand_icon.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  String? _pendingProvider;

  Future<void> _submitSocialAuth(
    String provider,
    Future<PhoneAuthSession> Function() signIn,
  ) async {
    if (_pendingProvider != null) {
      return;
    }

    setState(() {
      _pendingProvider = provider;
    });

    try {
      final sessionController = ref.read(appSessionControllerProvider);
      final session = await signIn();
      if (!mounted) {
        return;
      }

      await sessionController.replaceAuthenticatedSession(
        tokens: session.tokens,
        userId: session.userId,
      );
      if (!mounted || !context.mounted) {
        return;
      }
      context.goRoute(
        session.isNewUser ? AppRoute.permissions : AppRoute.tonight,
      );
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$provider вход пока не настроен')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingProvider = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialAuth = ref.watch(socialAuthServiceProvider);
    final pendingProvider = _pendingProvider;
    return BbV5Scaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _WelcomeHeroBlock(),
                        const SizedBox(height: AppSpacing.xxl),
                        Column(
                          children: [
                            BbV5PillButton(
                              label: 'Начать',
                              icon: LucideIcons.arrow_right,
                              dark: true,
                              height: 56,
                              expanded: true,
                              fontSize: 15,
                              onPressed: () =>
                                  context.pushRoute(AppRoute.phoneAuth),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            BbV5PillButton(
                              label: 'Войти по SMS',
                              icon: LucideIcons.phone,
                              height: 48,
                              expanded: true,
                              fontSize: 13,
                              onPressed: pendingProvider == null
                                  ? () => context.pushRoute(AppRoute.phoneAuth)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const _AuthDivider(),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: _AuthIconButton(
                                    key: const Key('auth-provider-telegram'),
                                    label: 'Войти через Telegram',
                                    onPressed: pendingProvider == null
                                        ? () => context.pushRoute(
                                              AppRoute.telegramAuth,
                                            )
                                        : null,
                                    child: const _AuthIconContent(
                                      loading: false,
                                      child: _TelegramIcon(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _AuthIconButton(
                                    key: const Key('auth-provider-google'),
                                    label: 'Войти через Google',
                                    onPressed: pendingProvider == null
                                        ? () => _submitSocialAuth(
                                              'Google',
                                              socialAuth.signInWithGoogle,
                                            )
                                        : null,
                                    child: _AuthIconContent(
                                      loading: pendingProvider == 'Google',
                                      child: const _GoogleIcon(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _AuthIconButton(
                                    key: const Key('auth-provider-yandex'),
                                    label: 'Войти через Яндекс',
                                    onPressed: pendingProvider == null
                                        ? () => _submitSocialAuth(
                                              'Yandex',
                                              socialAuth.signInWithYandex,
                                            )
                                        : null,
                                    child: _AuthIconContent(
                                      loading: pendingProvider == 'Yandex',
                                      child: const _YandexIcon(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Продолжая, ты принимаешь Условия и\nПолитику приватности',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10.5,
                                height: 1.45,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeHeroBlock extends StatelessWidget {
  const _WelcomeHeroBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _WelcomeBrandTile(),
        SizedBox(height: AppSpacing.xxl),
        BbV5Kicker('Frendly'),
        SizedBox(height: AppSpacing.sm),
        _WelcomeTitle(),
        SizedBox(height: AppSpacing.md),
        _WelcomeSubtitle(),
      ],
    );
  }
}

class _WelcomeBrandTile extends StatelessWidget {
  const _WelcomeBrandTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.card,
      ),
      child: const BbBrandIcon(
        size: 96,
        radius: 28,
      ),
    );
  }
}

class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle();

  @override
  Widget build(BuildContext context) {
    final base = bbV5DisplayStyle(
      fontSize: 34,
      height: 1.05,
      fontWeight: FontWeight.w600,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Знакомства через '),
            TextSpan(
              text: 'вечера',
              style: base.copyWith(
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
            const TextSpan(text: ',\nа не свайпы.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: base,
      ),
    );
  }
}

class _WelcomeSubtitle extends StatelessWidget {
  const _WelcomeSubtitle();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Text(
        'Frendly собирает камерные встречи с людьми, которые рядом и в твоём настроении.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySoft.copyWith(
          color: BbV5Colors.inkSoft,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BbV5Colors.hair, height: 1)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'или войти через',
          style: AppTextStyles.caption.copyWith(
            color: BbV5Colors.inkMute,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: Divider(color: BbV5Colors.hair, height: 1)),
      ],
    );
  }
}

class _AuthIconContent extends StatelessWidget {
  const _AuthIconContent({
    required this.loading,
    required this.child,
  });

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return child;
    }

    return const SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _AuthIconButton extends StatelessWidget {
  const _AuthIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        height: 56,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: BbV5Colors.paperHi,
            disabledBackgroundColor: BbV5Colors.paperHi.withValues(alpha: 0.45),
            side: const BorderSide(color: BbV5Colors.hair),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            shadowColor: const Color(0x4D1F241D),
          ),
          onPressed: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(24),
      painter: _GoogleIconPainter(),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);

    final rect = Rect.fromCircle(center: const Offset(12, 12), radius: 7.2);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square;

    canvas.drawArc(
      rect,
      math.pi * 1.04,
      math.pi * 0.58,
      false,
      strokePaint..color = const Color(0xFFFBBC05),
    );
    canvas.drawArc(
      rect,
      math.pi * 0.47,
      math.pi * 0.62,
      false,
      strokePaint..color = const Color(0xFFEA4335),
    );
    canvas.drawArc(
      rect,
      math.pi * 1.54,
      math.pi * 0.45,
      false,
      strokePaint..color = const Color(0xFF34A853),
    );
    canvas.drawArc(
      rect,
      math.pi * 1.82,
      math.pi * 0.56,
      false,
      strokePaint..color = const Color(0xFF4285F4),
    );

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(12, 12), const Offset(19.2, 12), bluePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleIconPainter oldDelegate) => false;
}

class _YandexIcon extends StatelessWidget {
  const _YandexIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFFC3F1D),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'Я',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Sora',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TelegramIcon extends StatelessWidget {
  const _TelegramIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(24),
      painter: _TelegramIconPainter(),
    );
  }
}

class _TelegramIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);

    final circlePaint = Paint()
      ..color = const Color(0xFF229ED9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(12, 12), 10, circlePaint);

    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final arrowPath = Path()
      ..moveTo(16.94, 7.6)
      ..lineTo(15.2, 15.82)
      ..cubicTo(15.07, 16.4, 14.73, 16.54, 14.24, 16.27)
      ..lineTo(11.58, 14.31)
      ..lineTo(10.3, 15.55)
      ..cubicTo(10.16, 15.69, 10.04, 15.81, 9.76, 15.81)
      ..lineTo(9.95, 13.09)
      ..lineTo(14.9, 8.62)
      ..cubicTo(15.12, 8.43, 14.85, 8.32, 14.57, 8.51)
      ..lineTo(8.45, 12.37)
      ..lineTo(5.81, 11.54)
      ..cubicTo(5.24, 11.36, 5.22, 10.97, 5.93, 10.69)
      ..lineTo(16.25, 6.71)
      ..cubicTo(16.73, 6.53, 17.15, 6.82, 16.99, 7.6)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TelegramIconPainter oldDelegate) => false;
}
