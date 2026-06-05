import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/features/auth/presentation/auth_controls.dart';
import 'package:mobile2/features/welcome/application/apple_auth_client.dart';
import 'package:mobile2/features/welcome/application/google_auth_client.dart';
import 'package:mobile2/features/welcome/application/yandex_auth_client.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_highlight_text.dart';
import 'package:mobile2/shared/widgets/dateasy_logo.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_social_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _authenticating = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DateasyPhoneFrame(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DateasyLogo(size: DateasyLogoSize.md),
                            const SizedBox(height: 40),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _WelcomeHero(theme: Theme.of(context)),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _WelcomeActions(
                              onAuthenticatingChanged: (value) {
                                if (mounted) {
                                  setState(() => _authenticating = value);
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                            const _LegalText(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        AuthLoadingOverlay(visible: _authenticating),
      ],
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final headlineStyle = theme.textTheme.displayLarge?.copyWith(
      color: DateasyColors.foreground,
      letterSpacing: 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Реальные '),
              dateasyHeadlineHighlightSpan(
                text: 'встречи',
                style: headlineStyle,
              ),
              const TextSpan(text: ' рядом с тобой'),
            ],
          ),
          style: headlineStyle,
        ),
        const SizedBox(height: 16),
        Text(
          'Собирай вечера, знакомься на событиях и находи свою компанию в городе.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: DateasyColors.muted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _WelcomeActions extends ConsumerStatefulWidget {
  const _WelcomeActions({
    required this.onAuthenticatingChanged,
  });

  final ValueChanged<bool> onAuthenticatingChanged;

  @override
  ConsumerState<_WelcomeActions> createState() => _WelcomeActionsState();
}

class _WelcomeActionsState extends ConsumerState<_WelcomeActions> {
  bool _googleLoading = false;
  bool _yandexLoading = false;
  bool _appleLoading = false;

  @override
  Widget build(BuildContext context) {
    final showAppleAuth = Theme.of(context).platform == TargetPlatform.iOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialButton(
          label: 'Войти по номеру телефона',
          icon: const Icon(
            Icons.phone_rounded,
            size: 20,
            color: DateasyColors.backgroundDeep,
          ),
          isPrimary: true,
          onTap: _openPhoneAuth,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _IconSocialButton(
                key: const ValueKey('welcome-google-auth'),
                label: 'Войти через Google',
                icon: _googleLoading
                    ? const _SocialProgressIndicator()
                    : const DateasyGoogleIcon(size: 24),
                onTap: _signInWithGoogle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IconSocialButton(
                key: const ValueKey('welcome-yandex-auth'),
                label: 'Войти через Яндекс',
                icon: _yandexLoading
                    ? const _SocialProgressIndicator()
                    : const DateasyYandexIcon(size: 24),
                onTap: _signInWithYandex,
              ),
            ),
            if (showAppleAuth) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _IconSocialButton(
                  key: const ValueKey('welcome-apple-auth'),
                  label: 'Войти через Apple',
                  icon: _appleLoading
                      ? const _SocialProgressIndicator(color: Colors.white)
                      : const DateasyAppleIcon(size: 25),
                  backgroundColor: Colors.black,
                  borderColor: Colors.black,
                  onTap: _signInWithApple,
                ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: _IconSocialButton(
                key: const ValueKey('welcome-telegram-auth'),
                label: 'Войти через Telegram',
                icon: const DateasyTelegramIcon(size: 25),
                onTap: _openTelegramAuth,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openPhoneAuth() {
    context.go('/auth/phone');
  }

  void _openTelegramAuth() {
    context.go('/auth/telegram');
  }

  Future<void> _signInWithGoogle() async {
    if (_googleLoading) {
      return;
    }
    setState(() => _googleLoading = true);
    widget.onAuthenticatingChanged(true);
    try {
      final idToken = await ref.read(googleAuthClientProvider).signIn();
      final session = await ref.read(authActionsProvider).verifyGoogleAuth(
            idToken: idToken,
          );
      if (!mounted) {
        return;
      }
      context.go(session.isNewUser ? '/onboarding' : '/');
    } on PlatformException catch (error) {
      if (!mounted || error.code == 'google_auth_cancelled') {
        return;
      }
      _showSocialError(_googleErrorText(error.code));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSocialError('Не удалось войти через Google');
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
        widget.onAuthenticatingChanged(false);
      }
    }
  }

  Future<void> _signInWithYandex() async {
    if (_yandexLoading) {
      return;
    }
    setState(() => _yandexLoading = true);
    widget.onAuthenticatingChanged(true);
    try {
      final oauthToken = await const YandexAuthClient().signIn();
      final session = await ref.read(authActionsProvider).verifyYandexAuth(
            oauthToken: oauthToken,
          );
      if (!mounted) {
        return;
      }
      context.go(session.isNewUser ? '/onboarding' : '/');
    } on PlatformException catch (error) {
      if (!mounted || error.code == 'yandex_auth_cancelled') {
        return;
      }
      _showSocialError(_yandexErrorText(error.code));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSocialError('Не удалось войти через Яндекс');
    } finally {
      if (mounted) {
        setState(() => _yandexLoading = false);
        widget.onAuthenticatingChanged(false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (_appleLoading) {
      return;
    }
    setState(() => _appleLoading = true);
    widget.onAuthenticatingChanged(true);
    try {
      final result = await AppleAuthClient().signIn();
      final session = await ref.read(authActionsProvider).verifyAppleAuth(
            identityToken: result.identityToken,
            authorizationCode: result.authorizationCode,
            fullName: result.fullName,
          );
      if (!mounted) {
        return;
      }
      context.go(session.isNewUser ? '/onboarding' : '/');
    } on PlatformException catch (error) {
      if (!mounted || error.code == 'apple_auth_cancelled') {
        return;
      }
      _showSocialError(_appleErrorText(error.code));
    } on BackendActionException catch (error) {
      if (!mounted) {
        return;
      }
      _showSocialError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSocialError('Не удалось войти через Apple');
    } finally {
      if (mounted) {
        setState(() => _appleLoading = false);
        widget.onAuthenticatingChanged(false);
      }
    }
  }

  void _showSocialError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _googleErrorText(String code) {
    return switch (code) {
      'google_auth_not_configured' =>
        'Вход через Google не настроен в этом билде',
      'google_auth_ui_unavailable' => 'Не удалось открыть окно входа Google',
      'missing_google_id_token' => 'Google не вернул токен входа',
      _ => 'Не удалось войти через Google',
    };
  }

  String _yandexErrorText(String code) {
    return switch (code) {
      'yandex_android_not_ready' => 'Вход через Яндекс пока доступен на iPhone',
      'yandex_auth_not_configured' =>
        'Вход через Яндекс не настроен в этом билде',
      'yandex_auth_timeout' =>
        'Яндекс не вернул вход в приложение. Попробуй еще раз',
      'missing_yandex_token' => 'Яндекс не вернул токен входа',
      _ => 'Не удалось войти через Яндекс',
    };
  }

  String _appleErrorText(String code) {
    return switch (code) {
      'apple_auth_ui_unavailable' => 'Не удалось открыть окно входа Apple',
      'missing_apple_identity_token' => 'Apple не вернул токен входа',
      _ => 'Не удалось войти через Apple',
    };
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return _ButtonSurface(
      height: 68,
      isPrimary: isPrimary,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isPrimary
                      ? DateasyColors.backgroundDeep
                      : DateasyColors.foreground,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconSocialButton extends StatelessWidget {
  const _IconSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: label,
        child: _ButtonSurface(
          height: 64,
          onTap: onTap,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _SocialProgressIndicator extends StatelessWidget {
  const _SocialProgressIndicator({this.color = DateasyColors.foreground});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
}

class DateasyAppleIcon extends StatelessWidget {
  const DateasyAppleIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const AppleLogoPainter(color: Colors.white),
    );
  }
}

class _ButtonSurface extends StatelessWidget {
  const _ButtonSurface({
    required this.height,
    required this.child,
    required this.onTap,
    this.isPrimary = false,
    this.backgroundColor,
    this.borderColor,
  });

  final double height;
  final Widget child;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isPrimary ? dateasyLimeGradient : null,
            color: isPrimary ? null : backgroundColor ?? DateasyColors.glass,
            border: isPrimary
                ? null
                : Border.all(
                    color: borderColor ?? Colors.white.withValues(alpha: 0.1),
                  ),
            boxShadow: isPrimary
                ? const [
                    BoxShadow(
                      color: Color(0x59BEFF67),
                      blurRadius: 60,
                      spreadRadius: -20,
                      offset: Offset(0, 20),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: DateasyColors.muted,
          height: 1.3,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            'Продолжая, ты соглашаешься с документами Frendly.',
            textAlign: TextAlign.center,
            style: style,
          ),
          const SizedBox(height: 6),
          const Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              _LegalLink(
                key: ValueKey('welcome-legal-terms'),
                label: 'условия использования (EULA)',
                route: '/legal/terms',
              ),
              _LegalSeparator(),
              _LegalLink(
                key: ValueKey('welcome-legal-privacy'),
                label: 'политика конфиденциальности',
                route: '/legal/privacy',
              ),
              _LegalSeparator(),
              _LegalLink(
                key: ValueKey('welcome-legal-community-rules'),
                label: 'правила сообщества',
                route: '/legal/community-rules',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    super.key,
    required this.label,
    required this.route,
  });

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: DateasyColors.foreground,
          decoration: TextDecoration.underline,
          decorationColor: DateasyColors.foreground,
          height: 1.3,
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

class _LegalSeparator extends StatelessWidget {
  const _LegalSeparator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '·',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DateasyColors.muted,
          ),
    );
  }
}
