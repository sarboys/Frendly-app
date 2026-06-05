import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/device/app_push_token_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/utils/frendly_legal_links.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_refresh_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

const _promoRulesRoute = '/settings/documents/promo-rules';

const _faqItems = <_InfoItem>[
  _InfoItem(
    title: 'Что такое Frendly?',
    body:
        'Frendly помогает находить встречи, маршруты, чаты, дейтинг и планы в городе.',
  ),
  _InfoItem(
    title: 'Как найти встречу?',
    body:
        'Открой «Встречи», выбери событие и отправь заявку или вступи, если вход открыт.',
  ),
  _InfoItem(
    title: 'Как создать встречу?',
    body:
        'Нажми кнопку создания, добавь место, время, формат, описание и опубликуй встречу.',
  ),
  _InfoItem(
    title: 'Как работает дейтинг?',
    body:
        'Листай анкеты и ставь лайк. Если лайк взаимный, появится мэтч и можно написать.',
  ),
  _InfoItem(
    title: 'Что значит скрыть профиль?',
    body: 'Скрытый профиль не показывается в дейтинге и публичной выдаче.',
  ),
  _InfoItem(
    title: 'Зачем нужна верификация?',
    body:
        'Верификация повышает доверие и открывает больше безопасных сценариев.',
  ),
  _InfoItem(
    title: 'Что такое Frendly+?',
    body:
        'Frendly+ дает расширенные возможности и доступ к закрытым сценариям.',
  ),
  _InfoItem(
    title: 'Как работают чаты?',
    body:
        'Есть личные чаты и чаты встреч. Они открываются после нужного действия.',
  ),
  _InfoItem(
    title: 'Что делать при проблеме на встрече?',
    body: 'Открой SOS и доверенные контакты. Там собраны быстрые действия.',
  ),
  _InfoItem(
    title: 'Где посмотреть правила?',
    body: 'Открой «Документы» в настройках. Там лежат правила и согласия.',
  ),
];

const _documentLinks = <_DocumentLink>[
  _DocumentLink(
    title: 'Все документы',
    url: frendlyLegalUrl,
  ),
  _DocumentLink(
    title: 'Пользовательское соглашение',
    url: frendlyTermsUrl,
  ),
  _DocumentLink(
    title: 'Публичная оферта',
    url: 'https://frendly.tech/legal/offer',
  ),
  _DocumentLink(
    title: 'Оплата и возвраты',
    url: 'https://frendly.tech/legal/payment-and-refund',
  ),
  _DocumentLink(
    title: 'Политика обработки персональных данных',
    url: frendlyPrivacyUrl,
  ),
  _DocumentLink(
    title: 'Согласие на обработку персональных данных',
    url: 'https://frendly.tech/legal/personal-data-consent',
  ),
  _DocumentLink(
    title: 'Согласие на распространение персональных данных',
    url: 'https://frendly.tech/legal/public-profile-consent',
  ),
  _DocumentLink(
    title: 'Согласие на биометрию',
    url: 'https://frendly.tech/legal/biometric-consent',
  ),
  _DocumentLink(
    title: 'Согласие на специальные категории данных',
    url: 'https://frendly.tech/legal/special-category-consent',
  ),
  _DocumentLink(
    title: 'Согласие на рекламные сообщения',
    url: 'https://frendly.tech/legal/marketing-consent',
  ),
  _DocumentLink(
    title: 'Cookies и аналитика',
    url: 'https://frendly.tech/legal/cookies',
  ),
  _DocumentLink(
    title: 'Правила сообщества',
    url: frendlyCommunityRulesUrl,
  ),
  _DocumentLink(
    title: 'Условия для партнёров',
    url: 'https://frendly.tech/legal/partner-terms',
  ),
  _DocumentLink(
    title: 'Правила промо и розыгрышей',
    url: 'https://frendly.tech/legal/promo-rules',
  ),
];

class _InfoItem {
  const _InfoItem({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _DocumentLink {
  const _DocumentLink({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  String get host => Uri.parse(url).host;
}

Future<void> _openExternalUrl(BuildContext context, String url) async {
  await openFrendlyLegalUrlOrNotify(context, url);
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _push = false;
  bool _pushBusy = false;
  bool _supportBusy = false;
  final Map<String, bool> _settingOverrides = <String, bool>{};
  final Set<String> _settingsBusy = <String>{};

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(sharedPreferencesProvider);
    _push = preferences?.getBool(pushNotificationsEnabledStorageKey) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final ownProfile = ref.watch(ownProfileProvider);
    final verification = ref.watch(verificationProvider);
    final settingsState = ref.watch(appSettingsProvider);
    final settings = settingsState.valueOrNull;
    final city = currentUser?.city ??
        ownProfile.valueOrNull?.city ??
        ownProfile.valueOrNull?.raw['city']?.toString();
    final pushValue =
        _settingOverrides['allowPush'] ?? settings?.allowPush ?? _push;
    final discoverableValue =
        _settingOverrides['discoverable'] ?? settings?.discoverable ?? true;

    return DateasyPhoneFrame(
      child: DateasyRefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 16,
            bottom: 40,
          ),
          children: [
            const _SettingsHeader(title: 'Настройки', backPath: '/profile'),
            const _PlusCard(),
            _SettingsGroup(
              title: 'Аккаунт',
              rows: [
                _SettingRow(
                  icon: LucideIcons.eye,
                  label: 'Видимость профиля',
                  right: discoverableValue ? 'Все' : 'Скрыт',
                  onTap: _settingsBusy.contains('discoverable')
                      ? null
                      : () => _handleBackendToggle(
                            'discoverable',
                            !discoverableValue,
                          ),
                ),
                _SettingRow(
                  icon: LucideIcons.mapPin,
                  label: 'Город',
                  right: city == null || city.isEmpty ? 'Москва' : city,
                ),
                const _SettingRow(
                  icon: LucideIcons.languages,
                  label: 'Язык',
                  right: 'Русский',
                ),
                const _SettingRow(
                  icon: LucideIcons.lock,
                  label: 'Редактировать профиль',
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Уведомления',
              rows: [
                _SettingRow(
                  icon: LucideIcons.bell,
                  label: 'Push',
                  toggleValue: pushValue,
                  onToggle: _pushBusy
                      ? (_) {}
                      : (value) {
                          _handlePushToggle(value);
                        },
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Безопасность',
              rows: [
                const _SettingRow(
                  icon: LucideIcons.shieldAlert,
                  label: 'SOS и доверенные',
                ),
                const _SettingRow(
                  icon: LucideIcons.ban,
                  label: 'Заблокированные',
                ),
                _SettingRow(
                  icon: LucideIcons.shieldAlert,
                  label: 'Верификация',
                  right: _verificationLabel(verification.valueOrNull),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Помощь',
              rows: [
                _SettingRow(
                  icon: LucideIcons.messageCircle,
                  label: 'Техподдержка',
                  onTap: _openSupport,
                ),
                const _SettingRow(
                  icon: LucideIcons.circleQuestionMark,
                  label: 'FAQ',
                ),
                const _SettingRow(
                  icon: LucideIcons.globe,
                  label: 'О Frendly',
                ),
                const _SettingRow(
                  icon: LucideIcons.fileText,
                  label: 'Документы',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _LogoutButton(onTap: _logout),
            const SizedBox(height: 18),
            Text(
              'v 1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(appSettingsProvider);
    ref.invalidate(ownProfileProvider);
    ref.invalidate(verificationProvider);
  }

  String _verificationLabel(VerificationStateData? verification) {
    switch (verification?.status) {
      case 'verified':
        return 'Готово';
      case 'under_review':
      case 'selfie_submitted':
        return 'На проверке';
      case 'rejected':
        return 'Повторить';
      default:
        return 'Пройти';
    }
  }

  Future<void> _handleBackendToggle(
    String key,
    bool value,
  ) async {
    if (_settingsBusy.contains(key)) {
      return;
    }
    setState(() {
      _settingsBusy.add(key);
      _settingOverrides[key] = value;
    });
    try {
      await ref.read(settingsActionsProvider).update({key: value});
    } catch (_) {
      if (mounted) {
        setState(() {
          _settingOverrides.remove(key);
        });
        _showNotice('Не удалось сохранить настройку.');
      }
    } finally {
      if (mounted) {
        setState(() => _settingsBusy.remove(key));
      }
    }
  }

  Future<void> _handlePushToggle(bool nextValue) async {
    if (_pushBusy) {
      return;
    }
    final previousValue = _push;
    setState(() {
      _push = nextValue;
      _settingOverrides['allowPush'] = nextValue;
      _pushBusy = true;
    });

    try {
      await ref.read(settingsActionsProvider).setPushEnabled(nextValue);
    } catch (_) {
      if (mounted) {
        setState(() {
          _push = previousValue;
          _settingOverrides.remove('allowPush');
        });
        _showNotice(
          nextValue
              ? 'Push пока недоступны в этом билде.'
              : 'Не получилось отключить push.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pushBusy = false);
      }
    }
  }

  Future<void> _openSupport() async {
    if (_supportBusy) {
      return;
    }
    setState(() => _supportBusy = true);
    try {
      final support =
          await ref.read(backendRepositoryProvider).startTelegramSupport();
      if (!mounted || !context.mounted) {
        return;
      }
      final opened = await launchUrl(
        Uri.parse(support.botUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _showNotice('Не удалось открыть поддержку');
      }
    } catch (_) {
      if (mounted) {
        _showNotice('Не удалось открыть поддержку');
      }
    } finally {
      if (mounted) {
        setState(() => _supportBusy = false);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(settingsActionsProvider).logout();

    if (mounted && context.mounted) {
      context.go('/welcome');
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class SettingsFaqScreen extends StatelessWidget {
  const SettingsFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 16,
          bottom: 40,
        ),
        children: const [
          _SettingsHeader(title: 'FAQ', backPath: '/settings'),
          SizedBox(height: 20),
          _SettingsIntro(
            title: 'Коротко о Frendly',
            body: 'Ответы по главным функциям приложения.',
          ),
          SizedBox(height: 8),
          _FaqList(),
        ],
      ),
    );
  }
}

class SettingsDocumentsScreen extends StatelessWidget {
  const SettingsDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 16,
          bottom: 40,
        ),
        children: const [
          _SettingsHeader(title: 'Документы', backPath: '/settings'),
          SizedBox(height: 20),
          _SettingsIntro(
            title: 'Правовая информация',
            body:
                'Официальные правила Drops открываются внутри приложения. Остальные документы откроются на frendly.tech.',
          ),
          SizedBox(height: 8),
          _DocumentsList(),
        ],
      ),
    );
  }
}

class SettingsPromoRulesScreen extends StatelessWidget {
  const SettingsPromoRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 16,
          bottom: 40,
        ),
        children: const [
          _SettingsHeader(
            title: 'Правила Drops',
            backPath: '/settings/documents',
          ),
          SizedBox(height: 20),
          _SettingsIntro(
            title: 'Официальные правила Frendly Drops',
            body:
                'Эти правила действуют для конкурсов и розыгрышей внутри Frendly. Они доступны в приложении постоянно.',
          ),
          SizedBox(height: 16),
          _PromoRulesAppleNotice(),
          SizedBox(height: 12),
          _PromoRulesSection(
            title: '1. Организатор',
            body:
                'Организатор конкурса, владелец и разработчик приложения Frendly. Конкурс проводится внутри приложения Frendly.',
          ),
          _PromoRulesSection(
            title: '2. Участие',
            body:
                'Участие бесплатное. Покупка подписки, токенов или других товаров не является обязательным условием участия и не гарантирует победу. Билеты нельзя купить. Они начисляются за действия в приложении, которые указаны в разделе «Задания месяца».',
          ),
          _PromoRulesSection(
            title: '3. Кто может участвовать',
            body:
                'Участвовать может активный пользователь Frendly, если он соответствует условиям конкретного Drops. Условия могут включать верификацию, активную Frendly+ подписку, город, возраст или другие ограничения, показанные на карточке конкурса.',
          ),
          _PromoRulesSection(
            title: '4. Билеты',
            body:
                'Каждый билет дает одну заявку на участие в выбранном Drops. Пользователь сам применяет доступные билеты к активному конкурсу до даты розыгрыша. Лимит билетов за месяц и условия начисления указаны на экране Drops.',
          ),
          _PromoRulesSection(
            title: '5. Победители',
            body:
                'Победители выбираются среди примененных билетов после окончания приема заявок. Чем больше билетов пользователь применил к конкурсу, тем больше его шанс. После розыгрыша Frendly может проверить личность победителя и соблюдение правил.',
          ),
          _PromoRulesSection(
            title: '6. Призы',
            body:
                'Приз, количество победителей и дата розыгрыша указаны на карточке конкретного Drops. Организатор может заменить приз на аналогичный по стоимости, если исходный приз недоступен. Денежная замена приза не гарантируется.',
          ),
          _PromoRulesSection(
            title: '7. Отмена и ограничения',
            body:
                'Организатор может отменить участие пользователя, если обнаружены накрутка, повторные аккаунты, нарушение правил сообщества, техническая ошибка или иное недобросовестное поведение.',
          ),
          _PromoRulesSection(
            title: '8. Связь',
            body:
                'По вопросам конкурса можно обратиться в поддержку Frendly через раздел «Техподдержка» в настройках приложения.',
          ),
        ],
      ),
    );
  }
}

class SettingsBlockedUsersScreen extends ConsumerStatefulWidget {
  const SettingsBlockedUsersScreen({super.key});

  @override
  ConsumerState<SettingsBlockedUsersScreen> createState() =>
      _SettingsBlockedUsersScreenState();
}

class _SettingsBlockedUsersScreenState
    extends ConsumerState<SettingsBlockedUsersScreen> {
  final Set<String> _busyIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final blocksState = ref.watch(blocksProvider);

    return DateasyPhoneFrame(
      child: DateasyRefreshIndicator(
        onRefresh: _refresh,
        child: blocksState.when(
          data: (page) => _BlockedUsersList(
            items: page.items,
            busyIds: _busyIds,
            onUnblock: _unblock,
          ),
          loading: () => const _BlockedUsersLoading(),
          error: (_, __) => _BlockedUsersError(onRefresh: _refresh),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(blocksProvider);
    await ref.read(blocksProvider.future);
  }

  Future<void> _unblock(BlockedUserData user) async {
    final targetUserId = user.blockedUserId;
    if (_busyIds.contains(targetUserId)) {
      return;
    }
    setState(() => _busyIds.add(targetUserId));
    try {
      await ref.read(reportActionsProvider).deleteBlock(
            targetUserId: targetUserId,
          );
      if (!mounted || !context.mounted) {
        return;
      }
      _showNotice('Пользователь разблокирован');
    } catch (_) {
      if (mounted && context.mounted) {
        _showNotice('Не удалось разблокировать');
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(targetUserId));
      }
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _BlockedUsersList extends StatelessWidget {
  const _BlockedUsersList({
    required this.items,
    required this.busyIds,
    required this.onUnblock,
  });

  final List<BlockedUserData> items;
  final Set<String> busyIds;
  final ValueChanged<BlockedUserData> onUnblock;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        bottom: 40,
      ),
      itemCount: items.isEmpty ? 3 : items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _SettingsHeader(
            title: 'Заблокированные',
            backPath: '/settings',
          );
        }
        if (index == 1) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: _SettingsIntro(
              title: 'Список блокировок',
              body: 'Открой профиль или разблокируй человека из списка.',
            ),
          );
        }
        if (items.isEmpty) {
          return const _BlockedUsersEmpty();
        }
        final item = items[index - 2];
        return _BlockedUserRow(
          user: item,
          busy: busyIds.contains(item.blockedUserId),
          onUnblock: () => onUnblock(item),
        );
      },
    );
  }
}

class _BlockedUsersLoading extends StatelessWidget {
  const _BlockedUsersLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        bottom: 40,
      ),
      children: const [
        _SettingsHeader(title: 'Заблокированные', backPath: '/settings'),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _GlassPanel(
            borderRadius: 18,
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ],
    );
  }
}

class _BlockedUsersError extends StatelessWidget {
  const _BlockedUsersError({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        bottom: 40,
      ),
      children: [
        const _SettingsHeader(title: 'Заблокированные', backPath: '/settings'),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _GlassPanel(
            borderRadius: 18,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  'Не удалось загрузить список',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onRefresh,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockedUsersEmpty extends StatelessWidget {
  const _BlockedUsersEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _GlassPanel(
        borderRadius: 18,
        padding: const EdgeInsets.all(18),
        child: Text(
          'Заблокированных пользователей нет',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}

class _BlockedUserRow extends StatelessWidget {
  const _BlockedUserRow({
    required this.user,
    required this.busy,
    required this.onUnblock,
  });

  final BlockedUserData user;
  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Пользователь';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            context.push('/u/${Uri.encodeComponent(user.blockedUserId)}'),
        child: _GlassPanel(
          borderRadius: 18,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.ban, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Профиль заблокирован',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: busy ? null : onUnblock,
                child: Opacity(
                  opacity: busy ? 0.55 : 1,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: DateasyColors.lime.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: DateasyColors.lime.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        busy ? '...' : 'Разблокировать',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.lime,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
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
  const _SettingsHeader({
    required this.title,
    required this.backPath,
  });

  final String title;
  final String backPath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _GlassPanel(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.go(backPath),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(LucideIcons.chevronLeft, size: 20),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _GlassPanel(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusCard extends StatelessWidget {
  const _PlusCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () => context.push('/paywall'),
        child: Container(
          decoration: BoxDecoration(
            gradient: dateasyPinkGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55FF639F),
                blurRadius: 28,
                spreadRadius: -12,
                offset: Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DateasyColors.background.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.crown,
                  color: DateasyColors.foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frendly Plus',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DateasyColors.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Безлимит свайпов и приоритет',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.foreground
                                .withValues(alpha: 0.78),
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: DateasyColors.foreground,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_SettingRow> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
            ),
          ),
          _GlassPanel(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (var index = 0; index < rows.length; index++) ...[
                    rows[index],
                    if (index != rows.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.right,
    this.toggleValue,
    this.onToggle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? right;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  bool get _isToggle => toggleValue != null;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
          ),
        ),
        if (_isToggle)
          _SwitchPill(
            value: toggleValue!,
            onChanged: onToggle ?? (_) {},
          )
        else ...[
          if (right != null) ...[
            Text(
              right!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: DateasyColors.muted,
          ),
        ],
      ],
    );

    if (_isToggle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: content,
      );
    }

    return GestureDetector(
      onTap: onTap ?? () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: content,
      ),
    );
  }

  void _handleTap(BuildContext context) {
    switch (label) {
      case 'Город':
        context.go('/city');
      case 'Язык':
        _showNotice(context, 'Язык: Русский');
      case 'Редактировать профиль':
        context.push('/profile/edit');
      case 'SOS и доверенные':
        context.go('/sos');
      case 'Заблокированные':
        context.go('/settings/blocked');
      case 'Верификация':
        context.push('/verify');
      case 'FAQ':
        context.go('/settings/faq');
      case 'О Frendly':
        _openExternalUrl(context, 'https://frendly.tech');
      case 'Документы':
        context.go('/settings/documents');
    }
  }

  void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _FaqList extends StatelessWidget {
  const _FaqList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _GlassPanel(
        borderRadius: 18,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              for (var index = 0; index < _faqItems.length; index++) ...[
                _InfoTextRow(item: _faqItems[index]),
                if (index != _faqItems.length - 1)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _GlassPanel(
        borderRadius: 18,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              const _InternalDocumentRow(
                title: 'Официальные правила Frendly Drops',
                subtitle: 'Открывается внутри приложения',
                route: _promoRulesRoute,
              ),
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              for (var index = 0; index < _documentLinks.length; index++) ...[
                _DocumentRow(link: _documentLinks[index]),
                if (index != _documentLinks.length - 1)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InternalDocumentRow extends StatelessWidget {
  const _InternalDocumentRow({
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: DateasyColors.lime.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.fileCheck,
                size: 16,
                color: DateasyColors.lime,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: DateasyColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoRulesAppleNotice extends StatelessWidget {
  const _PromoRulesAppleNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _GlassPanel(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DateasyColors.lime.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                color: DateasyColors.lime,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apple не является спонсором конкурса',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Apple не участвует в организации, проведении, финансировании, выборе победителей или выдаче призов Frendly Drops.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoRulesSection extends StatelessWidget {
  const _PromoRulesSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: _GlassPanel(
        borderRadius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    height: 1.42,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTextRow extends StatelessWidget {
  const _InfoTextRow({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.link});

  final _DocumentLink link;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openExternalUrl(context, link.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.fileText, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    link.host,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.externalLink,
              size: 16,
              color: DateasyColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: value ? dateasyLimeGradient : null,
          color: value ? null : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: DateasyColors.background,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: DateasyColors.pink.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.logOut,
                size: 16,
                color: DateasyColors.pink,
              ),
              const SizedBox(width: 8),
              Text(
                'Выйти',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DateasyColors.pink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
