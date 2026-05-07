import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_permission_service.dart';
import 'package:big_break_mobile/app/core/device/app_push_token_service.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/session/app_session_controller.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/app/theme/app_theme_mode.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/user_settings.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserSettingsData? _settings;
  bool _didHydrateFromRemote = false;
  bool _isSavingSettings = false;
  UserSettingsData? _queuedSettings;
  UserSettingsData? _lastConfirmedSettings;
  String _language = 'Русский';
  String _city = 'Москва';

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final remoteSettings = settingsAsync.valueOrNull;
    if (remoteSettings != null && !_didHydrateFromRemote) {
      _settings = remoteSettings;
      _lastConfirmedSettings = remoteSettings;
      _didHydrateFromRemote = true;
    }
    final current = _settings ?? UserSettingsData.fallback;
    final isLoadingRemote = settingsAsync.isLoading && remoteSettings == null;
    final hasRemoteError = settingsAsync.hasError && remoteSettings == null;

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
              children: [
                _SettingsHeader(onBack: () => context.pop()),
                if (isLoadingRemote || hasRemoteError) ...[
                  const SizedBox(height: AppSpacing.md),
                  _RemoteSettingsBanner(
                    loading: isLoadingRemote,
                    error: hasRemoteError,
                  ),
                ],
                _SettingsGroup(
                  title: 'Аккаунт',
                  children: [
                    _SettingsRow(
                      label: 'Аккаунт и безопасность',
                      sub: '+7 ··· 87, Apple ID',
                      icon: LucideIcons.shield_check,
                      chevron: true,
                      onTap: _showAccountSecuritySheet,
                    ),
                    _SettingsRow(
                      label: 'Язык',
                      sub: _language,
                      icon: LucideIcons.globe,
                      chevron: true,
                      onTap: _showLanguageSheet,
                    ),
                    _SettingsRow(
                      label: 'Город',
                      sub: _city,
                      icon: LucideIcons.map_pin,
                      chevron: true,
                      onTap: _showCitySheet,
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: 'Уведомления',
                  children: [
                    _SettingsToggle(
                      label: 'Push-уведомления',
                      sub: 'Приглашения, сообщения, напоминания',
                      icon: LucideIcons.bell,
                      value: current.allowPush,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) => _handlePushToggle(current, v),
                    ),
                    _SettingsToggle(
                      label: 'Тихие часы',
                      sub: 'С 23:00 до 08:00',
                      icon: LucideIcons.moon,
                      value: current.quietHours,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) =>
                          _saveSettings(current.copyWith(quietHours: v)),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: 'Приватность',
                  children: [
                    _SettingsToggle(
                      label: 'Показывать в поиске',
                      sub: 'Тебя смогут найти люди рядом',
                      icon: LucideIcons.eye,
                      value: current.discoverable,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) =>
                          _saveSettings(current.copyWith(discoverable: v)),
                    ),
                    _SettingsToggle(
                      label: 'Показывать возраст',
                      icon: LucideIcons.shield_check,
                      value: current.showAge,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) =>
                          _saveSettings(current.copyWith(showAge: v)),
                    ),
                    _SettingsRow(
                      label: 'Заблокированные',
                      icon: LucideIcons.eye,
                      chevron: true,
                      onTap: () => context.pushRoute(AppRoute.safetyHub),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: 'Внешний вид',
                  children: [
                    _SettingsToggle(
                      label: 'Тёмная тема',
                      icon: LucideIcons.moon,
                      value: current.darkMode,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) =>
                          _saveSettings(current.copyWith(darkMode: v)),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: 'Поддержка',
                  children: [
                    _SettingsRow(
                      label: 'Помощь',
                      icon: LucideIcons.circle_question_mark,
                      chevron: true,
                      onTap: _showHelpSheet,
                    ),
                    _SettingsRow(
                      label: 'Условия и приватность',
                      icon: LucideIcons.circle_question_mark,
                      chevron: true,
                      onTap: _showPrivacySheet,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _LogoutButton(onTap: _logout),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'FRENDLY · v1.0',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 0,
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveSettings(UserSettingsData next) {
    setState(() {
      _settings = next;
    });
    ref.read(appThemeModeProvider.notifier).syncFromSettings(next);
    _queuedSettings = next;
    unawaited(_flushQueuedSettings());
  }

  Future<void> _flushQueuedSettings() async {
    if (_isSavingSettings) {
      return;
    }

    final repository = ref.read(backendRepositoryProvider);
    final themeMode = ref.read(appThemeModeProvider.notifier);
    _isSavingSettings = true;
    UserSettingsData? lastSavedSettings;

    try {
      while (_queuedSettings != null) {
        final next = _queuedSettings!;
        _queuedSettings = null;
        lastSavedSettings = await repository.updateSettings(next);
        if (!mounted) {
          return;
        }
      }

      if (!mounted || lastSavedSettings == null) {
        return;
      }

      setState(() {
        _settings = lastSavedSettings;
        _lastConfirmedSettings = lastSavedSettings;
        _didHydrateFromRemote = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      final fallback = _lastConfirmedSettings;
      if (fallback != null) {
        setState(() {
          _settings = fallback;
        });
        themeMode.syncFromSettings(fallback);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось сохранить настройки')),
      );
    } finally {
      _isSavingSettings = false;
    }
  }

  Future<void> _logout() async {
    final repository = ref.read(backendRepositoryProvider);
    final sessionController = ref.read(appSessionControllerProvider);
    final authTokens = ref.read(authTokensProvider.notifier);
    final currentUserId = ref.read(currentUserIdProvider.notifier);
    final pushTokenService = ref.read(appPushTokenServiceProvider);
    final logoutTokens = ref.read(authTokensProvider);
    final logoutUserId = ref.read(currentUserIdProvider);
    bool logoutSessionStillCurrent() {
      final currentTokens = authTokens.currentTokens;
      return currentUserId.state == logoutUserId &&
          currentTokens?.accessToken == logoutTokens?.accessToken &&
          currentTokens?.refreshToken == logoutTokens?.refreshToken;
    }

    final pushDeviceId = await pushTokenService.currentDeviceId();
    if (!logoutSessionStillCurrent()) {
      return;
    }
    if (pushDeviceId != null) {
      try {
        await repository.deletePushTokenByDeviceId(pushDeviceId);
      } catch (_) {}
    }
    if (!logoutSessionStillCurrent()) {
      return;
    }

    try {
      await repository.logout();
    } catch (_) {}
    if (!logoutSessionStillCurrent()) {
      return;
    }

    await pushTokenService.clearRegisteredToken();
    if (!logoutSessionStillCurrent()) {
      return;
    }
    await sessionController.clearSessionRuntime(clearPersistedChatState: true);
    if (!logoutSessionStillCurrent()) {
      return;
    }
    authTokens.clear();
    currentUserId.state = null;

    if (mounted && context.mounted) {
      context.goRoute(AppRoute.welcome);
    }
  }

  Future<void> _handlePushToggle(
    UserSettingsData current,
    bool nextValue,
  ) async {
    if (!nextValue) {
      _saveSettings(current.copyWith(allowPush: false));
      return;
    }

    final permissionService = ref.read(appPermissionServiceProvider);
    final pushTokenService = ref.read(appPushTokenServiceProvider);
    final repository = ref.read(backendRepositoryProvider);

    final granted = await permissionService.requestNotifications();
    if (!mounted || !granted) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Доступ к уведомлениям не выдан.')),
        );
      }
      return;
    }

    final pushToken = await pushTokenService.registerDeviceToken();
    if (!mounted || pushToken == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push пока недоступны в этом билде.')),
        );
      }
      return;
    }

    try {
      await repository.registerPushToken(
        token: pushToken.token,
        provider: pushToken.provider,
        deviceId: pushToken.deviceId,
        platform: pushToken.platform,
      );
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось включить push.')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    _saveSettings(current.copyWith(allowPush: true));
  }

  Future<void> _showAccountSecuritySheet() async {
    final colors = AppColors.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Аккаунт и безопасность',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Телефон: +7 ··· 87',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 6),
              Text(
                'Вход: Apple ID',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 6),
              Text(
                'Пароль здесь не используется. Вход идет по коду и Apple ID.',
                style: AppTextStyles.meta.copyWith(color: colors.inkMute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHelpSheet() async {
    final colors = AppColors.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Помощь',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Если что-то сломалось, открой Безопасность и поддержку или напиши в саппорт из Safety Hub.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacySheet() async {
    final colors = AppColors.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Условия и приватность',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Мы показываем только нужные данные для встреч, не публикуем точную точку без согласия и даём управлять приватностью прямо в настройках.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageSheet() async {
    final next = await _showOptionSheet(
      title: 'Выбери язык',
      currentValue: _language,
      options: const ['Русский', 'English'],
    );

    if (next == null || !mounted) {
      return;
    }

    setState(() {
      _language = next;
    });
  }

  Future<void> _showCitySheet() async {
    final next = await _showOptionSheet(
      title: 'Выбери город',
      currentValue: _city,
      options: const ['Москва', 'Санкт-Петербург', 'Казань'],
    );

    if (next == null || !mounted) {
      return;
    }

    setState(() {
      _city = next;
    });
  }

  Future<String?> _showOptionSheet({
    required String title,
    required String currentValue,
    required List<String> options,
  }) {
    final colors = AppColors.of(context);

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: option == currentValue
                            ? colors.primarySoft
                            : colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: option == currentValue
                              ? colors.primary.withValues(alpha: 0.25)
                              : colors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (option == currentValue)
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.xs),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker('Управление'),
              BbV5HeroTitle(
                title: 'Настройки',
                accent: 'аккаунта',
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RemoteSettingsBanner extends StatelessWidget {
  const _RemoteSettingsBanner({
    required this.loading,
    required this.error,
  });

  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        children: [
          if (loading) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BbV5Colors.ink,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              loading
                  ? 'Загружаем настройки'
                  : 'Не удалось загрузить настройки. Можно вернуться позже.',
              style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(LucideIcons.log_out, size: 17),
        label: const Text('Выйти'),
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: BbV5Colors.paperHi,
          foregroundColor: const Color(0xFFB5443B),
          shape: const StadiumBorder(
            side: BorderSide(color: BbV5Colors.hair),
          ),
          textStyle: AppTextStyles.button.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(title, style: bbV5KickerStyle()),
          ),
          const SizedBox(height: 8),
          BbV5Card(
            radius: 20,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: BbV5Colors.hairSoft,
                      ),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsIconTile extends StatelessWidget {
  const _SettingsIconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Icon(icon, size: 15, color: BbV5Colors.inkSoft),
    );
  }
}

class _SettingsTextBlock extends StatelessWidget {
  const _SettingsTextBlock({
    required this.label,
    this.sub,
  });

  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bbV5DisplayStyle(fontSize: 13.5),
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta.copyWith(
              fontSize: 11.5,
              color: BbV5Colors.inkMute,
            ),
          ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.icon,
    this.sub,
    this.chevron = false,
    this.onTap,
  });

  final String label;
  final String? sub;
  final IconData icon;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _SettingsIconTile(icon: icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _SettingsTextBlock(label: label, sub: sub)),
              if (chevron)
                const Icon(
                  LucideIcons.chevron_right,
                  size: 18,
                  color: BbV5Colors.inkMute,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.sub,
  });

  final String label;
  final String? sub;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _SettingsIconTile(icon: icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _SettingsTextBlock(label: label, sub: sub)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 24,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value
                      ? BbV5Colors.ink
                      : const Color(0x2E3C281C)
                          .withValues(alpha: enabled ? 1 : 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: BbV5Colors.paperHi
                        .withValues(alpha: enabled ? 1 : 0.72),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
