import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_permission_service.dart';
import 'package:big_break_mobile/app/core/device/app_push_token_service.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/session/app_session_controller.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/models/user_settings.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
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
  bool _isLoggingOut = false;
  UserSettingsData? _queuedSettings;
  UserSettingsData? _lastConfirmedSettings;
  String _language = 'Русский';
  String _city = 'Москва';

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final profileAsync = ref.watch(profileProvider);
    final wallet = ref.watch(tokenWalletProvider);
    final remoteSettings = settingsAsync.valueOrNull;
    if (remoteSettings != null && !_didHydrateFromRemote) {
      final nextSettings = _withoutDarkMode(remoteSettings);
      _settings = nextSettings;
      _lastConfirmedSettings = nextSettings;
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
                const SizedBox(height: 20),
                _ProfileSettingsTile(
                  profileAsync: profileAsync,
                  onTap: () => context.pushRoute(AppRoute.profile),
                ),
                const SizedBox(height: 12),
                _SettingsQuickGrid(
                  walletBalance: wallet.balance,
                  onPlus: () => context.pushRoute(AppRoute.paywall),
                  onWallet: () => context.pushRoute(AppRoute.wallet),
                ),
                const SizedBox(height: 12),
                _TrustStrip(
                  onVerification: () =>
                      context.pushRoute(AppRoute.verification),
                  onSos: () => context.pushRoute(AppRoute.sos),
                ),
                if (isLoadingRemote || hasRemoteError) ...[
                  const SizedBox(height: AppSpacing.md),
                  _RemoteSettingsBanner(
                    loading: isLoadingRemote,
                    error: hasRemoteError,
                  ),
                ],
                _SettingsGroup(
                  title: 'Вечера и поиск',
                  children: [
                    _SettingsRow(
                      label: 'Радар рядом',
                      sub: current.allowLocation
                          ? 'Геолокация включена'
                          : 'Включи доступ к месту',
                      icon: LucideIcons.radar,
                      chevron: true,
                      onTap: () => context.pushRoute(AppRoute.map),
                    ),
                    _SettingsRow(
                      label: 'AI compass',
                      sub: 'Собрать вечер по настроению',
                      icon: LucideIcons.compass,
                      chevron: true,
                      onTap: () => context.pushRoute(AppRoute.aiCreate),
                    ),
                    _SettingsToggle(
                      label: 'Авто-вечер',
                      sub: 'Делиться планами с компанией',
                      icon: LucideIcons.calendar_clock,
                      value: current.autoSharePlans,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) =>
                          _saveSettings(current.copyWith(autoSharePlans: v)),
                    ),
                    _SettingsRow(
                      label: 'After Dark',
                      sub: 'Ночной режим 18+',
                      icon: LucideIcons.moon_star,
                      chevron: true,
                      onTap: () => context.pushRoute(AppRoute.afterDark),
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
                    _SettingsToggle(
                      label: 'Скрывать точную точку',
                      sub: 'Показывать район вместо адреса',
                      icon: LucideIcons.map_pin_off,
                      value: current.hideExactLocation,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) =>
                          _saveSettings(current.copyWith(hideExactLocation: v)),
                    ),
                    _SettingsToggle(
                      label: 'Доступ к контактам',
                      sub: 'Для быстрых приглашений',
                      icon: LucideIcons.contact,
                      value: current.allowContacts,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) =>
                          _saveSettings(current.copyWith(allowContacts: v)),
                    ),
                    _SettingsRow(
                      label: 'Заблокированные',
                      icon: LucideIcons.user_x,
                      chevron: true,
                      onTap: () => context.pushRoute(AppRoute.safetyHub),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: 'Уведомления',
                  children: [
                    _SettingsToggle(
                      label: 'Push-уведомления',
                      sub: 'Главный переключатель',
                      icon: LucideIcons.bell,
                      value: current.allowPush,
                      enabled: !isLoadingRemote && !hasRemoteError,
                      onChanged: (v) => _handlePushToggle(current, v),
                    ),
                    _SettingsRow(
                      label: 'Приглашения',
                      sub: current.allowPush
                          ? 'Заявки, гости, ответы хоста'
                          : 'Отключены главным тумблером',
                      icon: LucideIcons.ticket_check,
                      chevron: true,
                      onTap: () => context.pushRoute(AppRoute.notifications),
                    ),
                    _SettingsRow(
                      label: 'Чаты',
                      sub: current.allowPush
                          ? 'Сообщения и новые ветки'
                          : 'Отключены главным тумблером',
                      icon: LucideIcons.messages_square,
                      chevron: true,
                      onTap: () => context.pushRoute(AppRoute.notifications),
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
                  title: 'Опасная зона',
                  children: [
                    _SettingsRow(
                      label: 'Поддержка и условия',
                      sub: 'Помощь, приватность, правила',
                      icon: LucideIcons.circle_question_mark,
                      chevron: true,
                      onTap: _showHelpSheet,
                    ),
                    _SettingsRow(
                      label: 'Удаление аккаунта',
                      sub: 'Связаться с поддержкой',
                      icon: LucideIcons.trash_2,
                      chevron: true,
                      onTap: _showPrivacySheet,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _LogoutButton(
                  loading: _isLoggingOut,
                  onTap: _logout,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'FRENDLY · v1.0',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 1.68,
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
    final normalized = _withoutDarkMode(next);
    setState(() {
      _settings = normalized;
    });
    _queuedSettings = normalized;
    unawaited(_flushQueuedSettings());
  }

  Future<void> _flushQueuedSettings() async {
    if (_isSavingSettings) {
      return;
    }

    final repository = ref.read(backendRepositoryProvider);
    _isSavingSettings = true;
    UserSettingsData? lastSavedSettings;

    try {
      while (_queuedSettings != null) {
        final next = _queuedSettings!;
        _queuedSettings = null;
        lastSavedSettings =
            _withoutDarkMode(await repository.updateSettings(next));
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
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось сохранить настройки')),
      );
    } finally {
      _isSavingSettings = false;
    }
  }

  UserSettingsData _withoutDarkMode(UserSettingsData settings) {
    return settings.darkMode ? settings.copyWith(darkMode: false) : settings;
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }
    setState(() {
      _isLoggingOut = true;
    });

    final repository = ref.read(backendRepositoryProvider);
    final sessionController = ref.read(appSessionControllerProvider);
    final authTokens = ref.read(authTokensProvider.notifier);
    final currentUserId = ref.read(currentUserIdProvider.notifier);
    final pushTokenService = ref.read(appPushTokenServiceProvider);

    unawaited(_logoutRemoteBestEffort(repository, pushTokenService));
    await sessionController.clearSessionRuntime(clearPersistedChatState: true);
    authTokens.clear();
    currentUserId.state = null;

    if (mounted && context.mounted) {
      context.goRoute(AppRoute.welcome);
    }
  }

  Future<void> _logoutRemoteBestEffort(
    BackendRepository repository,
    AppPushTokenService pushTokenService,
  ) async {
    try {
      final pushDeviceId = await pushTokenService.currentDeviceId();
      if (pushDeviceId != null) {
        try {
          await repository.deletePushTokenByDeviceId(pushDeviceId);
        } catch (_) {}
      }
      try {
        await repository.logout();
      } catch (_) {}
      await pushTokenService.clearRegisteredToken();
    } catch (_) {}
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
                style: bbV5DisplayStyle(fontSize: 18, height: 1.2),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Телефон: +7 ··· 87',
                style: bbV5DisplayStyle(fontSize: 13.5, height: 1.25),
              ),
              const SizedBox(height: 6),
              Text(
                'Вход: Apple ID',
                style: bbV5DisplayStyle(fontSize: 13.5, height: 1.25),
              ),
              const SizedBox(height: 6),
              Text(
                'Пароль здесь не используется. Вход идет по коду и Apple ID.',
                style: AppTextStyles.meta.copyWith(
                  color: colors.inkMute,
                  fontSize: 12.5,
                  height: 1.45,
                ),
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
                style: bbV5DisplayStyle(fontSize: 18, height: 1.2),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Если что-то сломалось, открой Безопасность и поддержку или напиши в саппорт из Safety Hub.',
                style: AppTextStyles.bodySoft.copyWith(
                  color: colors.foreground,
                  fontSize: 13.5,
                  height: 1.625,
                ),
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
                style: bbV5DisplayStyle(fontSize: 18, height: 1.2),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Мы показываем только нужные данные для встреч, не публикуем точную точку без согласия и даём управлять приватностью прямо в настройках.',
                style: AppTextStyles.bodySoft.copyWith(
                  color: colors.foreground,
                  fontSize: 13.5,
                  height: 1.625,
                ),
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
                style: bbV5DisplayStyle(fontSize: 18, height: 1.2),
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
                              style: AppTextStyles.itemTitle.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                letterSpacing: -0.27,
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

class _ProfileSettingsTile extends StatelessWidget {
  const _ProfileSettingsTile({
    required this.profileAsync,
    required this.onTap,
  });

  final AsyncValue<ProfileData> profileAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.valueOrNull;
    final name = profile?.displayName ?? 'Мой профиль';
    final location = [
      profile?.city,
      profile?.area,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');
    final subtitle = location.isEmpty ? 'Открыть карточку профиля' : location;
    final intent = profile == null || profile.intent.isEmpty
        ? 'Вечера'
        : profile.intent.first;

    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      tint: BbV5Colors.terraSoft,
      onTap: onTap,
      child: Row(
        children: [
          BbAvatar(
            name: name,
            imageUrl: profile?.avatarUrl,
            online: profile?.online ?? false,
            size: BbAvatarSize.lg,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bbV5DisplayStyle(fontSize: 18, height: 1.15),
                      ),
                    ),
                    if (profile?.verified ?? false) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.badge_check,
                        size: 16,
                        color: BbV5Colors.brandDeep,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 12,
                    color: BbV5Colors.inkMute,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniBadge(
                      icon: LucideIcons.heart,
                      label: intent,
                    ),
                    _MiniBadge(
                      icon: LucideIcons.star,
                      label: profile?.rating.toStringAsFixed(1) ?? '4.8',
                    ),
                    _MiniBadge(
                      icon: LucideIcons.users,
                      label: '${profile?.meetupCount ?? 0} встреч',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            LucideIcons.chevron_right,
            size: 18,
            color: BbV5Colors.inkMute,
          ),
        ],
      ),
    );
  }
}

class _SettingsQuickGrid extends StatelessWidget {
  const _SettingsQuickGrid({
    required this.walletBalance,
    required this.onPlus,
    required this.onWallet,
  });

  final int walletBalance;
  final VoidCallback onPlus;
  final VoidCallback onWallet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeatureCard(
            icon: LucideIcons.crown,
            title: 'Frendly+',
            subtitle: 'Фильтры, лайки, закрытые вечера',
            tone: BbV5Colors.gold,
            onTap: onPlus,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            icon: LucideIcons.wallet,
            title: 'Wallet',
            subtitle: '$walletBalance токенов',
            tone: BbV5Colors.brand,
            onTap: onWallet,
          ),
        ),
      ],
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({
    required this.onVerification,
    required this.onSos,
  });

  final VoidCallback onVerification;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TrustButton(
            icon: LucideIcons.badge_check,
            label: 'Верификация',
            sub: 'Быстрее проходят заявки',
            onTap: onVerification,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TrustButton(
            icon: LucideIcons.shield_alert,
            label: 'SOS',
            sub: 'Контакты и быстрый сигнал',
            danger: true,
            onTap: onSos,
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 20,
      padding: const EdgeInsets.all(14),
      tint: tone.withValues(alpha: 0.55),
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tone.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, size: 16, color: tone),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bbV5DisplayStyle(fontSize: 14, height: 1.15),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.8,
                height: 1.2,
                color: BbV5Colors.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustButton extends StatelessWidget {
  const _TrustButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tone = danger ? const Color(0xFFB5443B) : BbV5Colors.brandDeep;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 17, color: tone),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bbV5DisplayStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        height: 1.15,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: BbV5Colors.inkSoft),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: BbV5Colors.inkSoft,
            ),
          ),
        ],
      ),
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
  const _LogoutButton({
    required this.loading,
    required this.onTap,
  });

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.log_out, size: 17),
        label: Text(loading ? 'Выходим' : 'Выйти'),
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
