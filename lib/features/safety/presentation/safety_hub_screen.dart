// ignore_for_file: unused_element

import 'dart:async';

import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/safety_hub.dart';
import 'package:big_break_mobile/shared/models/user_settings.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyHubScreen extends ConsumerStatefulWidget {
  const SafetyHubScreen({super.key});

  @override
  ConsumerState<SafetyHubScreen> createState() => _SafetyHubScreenState();
}

class _SafetyHubScreenState extends ConsumerState<SafetyHubScreen> {
  bool _saving = false;
  bool _sosActive = false;
  bool _firingSos = false;
  double _holdProgress = 0;
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safetyAsync = ref.watch(safetyHubProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return BbV5Scaffold(
      child: safetyAsync.when(
        data: (safety) => settingsAsync.when(
          data: (settings) => BbV5Page(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 88),
            child: ListView(
              cacheExtent: 1200,
              padding: EdgeInsets.zero,
              children: [
                const BbV5TopBar(
                  kicker: 'Безопасность',
                  title: 'Кнопка',
                  accent: 'SOS',
                ),
                const SizedBox(height: 20),
                _SosHoldCard(
                  active: _sosActive,
                  progress: _holdProgress,
                  loading: _firingSos,
                  onDown: _startHold,
                  onUp: _cancelHold,
                  onCancelActive: () => setState(() {
                    _sosActive = false;
                  }),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.26,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _QuickAction(
                      icon: LucideIcons.phone,
                      label: 'Позвонить 112',
                      onTap: _callEmergency,
                    ),
                    _QuickAction(
                      icon: LucideIcons.share_2,
                      label: 'Поделиться гео',
                      onTap: _shareLocation,
                    ),
                    _QuickAction(
                      icon: LucideIcons.map_pin,
                      label: 'Safe Walk',
                      onTap: _startSafeWalk,
                    ),
                    _QuickAction(
                      icon: LucideIcons.message_circle,
                      label: 'Чат с поддержкой',
                      onTap: _openSupport,
                    ),
                  ],
                ),
                const _HotlinesSection(),
                _V5TrustedContactsSection(
                  contacts: safety.trustedContacts,
                  onAdd: _showAddContactSheet,
                  onDelete: _deleteContact,
                ),
                const _PrivacyNote(),
                _SafetyGroup(
                  title: 'Автоматическая защита',
                  children: [
                    _ToggleRow(
                      icon: LucideIcons.share_2,
                      label: 'Делиться планом автоматически',
                      sub: 'Перед выходом на встречу',
                      value: settings.autoSharePlans,
                      onChanged: _saving
                          ? null
                          : (value) => _saveSafety(
                                settings.copyWith(autoSharePlans: value),
                              ),
                    ),
                    _ToggleRow(
                      icon: LucideIcons.eye,
                      label: 'Скрыть точную геолокацию',
                      sub: 'Контактам видна только зона',
                      value: settings.hideExactLocation,
                      onChanged: _saving
                          ? null
                          : (value) => _saveSafety(
                                settings.copyWith(hideExactLocation: value),
                              ),
                    ),
                  ],
                ),
                _SafetyGroup(
                  title: 'Модерация',
                  children: [
                    _ActionRow(
                      icon: LucideIcons.user_minus,
                      label: 'Заблокированные',
                      sub: '${safety.blockedUsersCount} пользователя',
                      onTap: _showBlockedUsersSheet,
                    ),
                    _ActionRow(
                      icon: LucideIcons.flag,
                      label: 'Мои жалобы',
                      sub: '${safety.reportsCount} в работе',
                      onTap: _showReportsSheet,
                    ),
                  ],
                ),
              ],
            ),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: BbV5Colors.accent),
          ),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: BbV5Colors.accent),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  void _startHold() {
    if (_sosActive || _firingSos) {
      return;
    }
    _holdTimer?.cancel();
    setState(() {
      _holdProgress = 0.02;
    });
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = (_holdProgress + 0.025).clamp(0.0, 1.0);
      setState(() {
        _holdProgress = next;
      });
      if (next >= 1) {
        timer.cancel();
        unawaited(_fireSos());
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (_holdProgress < 1 && mounted) {
      setState(() {
        _holdProgress = 0;
      });
    }
  }

  Future<void> _fireSos() async {
    if (_firingSos) {
      return;
    }
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _firingSos = true;
    });
    try {
      final result = await repository.createSos();
      if (!mounted) {
        return;
      }
      container.invalidate(safetyHubProvider);
      setState(() {
        _sosActive = true;
        _holdProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SOS отправлен. Контактов уведомлено: ${result.notifiedContactsCount}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _holdProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось отправить SOS')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _firingSos = false;
        });
      }
    }
  }

  Future<void> _saveSafety(UserSettingsData settings) async {
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _saving = true;
    });
    try {
      await repository.updateSafety(
        autoSharePlans: settings.autoSharePlans,
        hideExactLocation: settings.hideExactLocation,
      );
      if (!mounted) {
        return;
      }
      container.invalidate(safetyHubProvider);
      container.invalidate(settingsProvider);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _showAddContactSheet() async {
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddContactSheet(
        onAdd: (contact) async {
          await repository.createTrustedContact(
            name: contact.name,
            channel: contact.channel,
            value: contact.value,
            mode: contact.mode,
          );
        },
      ),
    );

    if (created == true) {
      if (!mounted) {
        return;
      }
      container.invalidate(safetyHubProvider);
    }
  }

  Future<void> _deleteContact(String contactId) async {
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await repository.deleteTrustedContact(contactId);
      if (!mounted) {
        return;
      }
      container.invalidate(safetyHubProvider);
    } catch (_) {
      if (!mounted || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось удалить контакт')),
      );
    }
  }

  Future<void> _showSosSheet(List<TrustedContactData> contacts) {
    final repository = ref.read(backendRepositoryProvider);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SosConfirmSheet(
        contacts: contacts,
        onFire: repository.createSos,
      ),
    );
  }

  Future<void> _showBlockedUsersSheet() async {
    final repository = ref.read(backendRepositoryProvider);
    final blocks = await repository.fetchBlocks();
    if (!mounted) {
      return;
    }
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
                'Заблокированные',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              if (blocks.isEmpty)
                Text(
                  'Список пуст.',
                  style: AppTextStyles.bodySoft.copyWith(color: colors.inkMute),
                ),
              ...blocks.map(
                (block) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(block.displayName, style: AppTextStyles.body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReportsSheet() async {
    final repository = ref.read(backendRepositoryProvider);
    final reports = await repository.fetchReports();
    if (!mounted) {
      return;
    }
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
                'Мои жалобы',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              if (reports.isEmpty)
                Text(
                  'Пока ничего нет.',
                  style: AppTextStyles.bodySoft.copyWith(color: colors.inkMute),
                ),
              ...reports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    '${report.reason} · ${report.status}',
                    style: AppTextStyles.body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('tel:112');
    final opened = await launchUrl(uri);
    if (opened || !mounted || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не получилось открыть поддержку')),
    );
  }

  Future<void> _callEmergency() async {
    final opened = await launchUrl(Uri.parse('tel:112'));
    if (opened || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не получилось открыть звонок 112')),
    );
  }

  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Гео отправлено доверенным контактам')),
    );
  }

  void _startSafeWalk() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Safe Walk запущен')),
    );
  }
}

class _SosHoldCard extends StatelessWidget {
  const _SosHoldCard({
    required this.active,
    required this.progress,
    required this.loading,
    required this.onDown,
    required this.onUp,
    required this.onCancelActive,
  });

  final bool active;
  final double progress;
  final bool loading;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onCancelActive;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      tint: const Color(0xFFE8806E),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            active ? 'СИГНАЛ ОТПРАВЛЕН' : 'УДЕРЖИВАЙ КНОПКУ',
            style: bbV5KickerStyle(
              color: const Color(0xFFB5443B),
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTapDown: (_) => onDown(),
            onTapUp: (_) => onUp(),
            onTapCancel: onUp,
            child: SizedBox(
              width: 176,
              height: 176,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFB5443B)
                          : const Color(0xFFD85B4A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFD85B4A).withValues(alpha: 0.18),
                          spreadRadius: 8,
                        ),
                        const BoxShadow(
                          color: Color(0x991F241D),
                          blurRadius: 60,
                          spreadRadius: -20,
                          offset: Offset(0, 30),
                        ),
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                  SizedBox(
                    width: 176,
                    height: 176,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: BbV5Colors.paperHi,
                      backgroundColor:
                          BbV5Colors.paperHi.withValues(alpha: 0.3),
                    ),
                  ),
                  loading
                      ? const CircularProgressIndicator(
                          color: BbV5Colors.paperHi,
                        )
                      : const Icon(
                          LucideIcons.shield_alert,
                          size: 56,
                          color: BbV5Colors.paperHi,
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            active
                ? 'Геолокация отправлена доверенным контактам и в Frendly'
                : 'Зажми на 2 секунды. Мы пришлём твою геолокацию доверенным и предложим вызвать 112.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              height: 1.45,
              color: BbV5Colors.inkSoft,
            ),
          ),
          if (active) ...[
            const SizedBox(height: 16),
            BbV5PillButton(
              label: 'Отменить тревогу',
              icon: LucideIcons.x,
              height: 40,
              fontSize: 12,
              onPressed: onCancelActive,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: BbV5Radii.md,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BbV5Colors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, size: 17, color: BbV5Colors.terra),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 12.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: BbV5Colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _V5TrustedContactsSection extends StatelessWidget {
  const _V5TrustedContactsSection({
    required this.contacts,
    required this.onAdd,
    required this.onDelete,
  });

  final List<TrustedContactData> contacts;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'ДОВЕРЕННЫЕ КОНТАКТЫ',
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var index = 0; index < contacts.length; index++) ...[
              _V5ContactRow(
                contact: contacts[index],
                onDelete: () => onDelete(contacts[index].id),
              ),
              if (index != contacts.length - 1)
                const Divider(height: 1, color: BbV5Colors.hairSoft),
            ],
            if (contacts.isNotEmpty)
              const Divider(height: 1, color: BbV5Colors.hairSoft),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: contacts.length < 5 ? onAdd : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.users,
                        size: 17,
                        color: BbV5Colors.terra,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Добавить контакт',
                        style: AppTextStyles.caption.copyWith(
                          fontFamily: 'Sora',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: BbV5Colors.terra,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _V5ContactRow extends StatelessWidget {
  const _V5ContactRow({
    required this.contact,
    required this.onDelete,
  });

  final TrustedContactData contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = switch (contact.mode) {
      'sos_only' => 'только SOS',
      _ => 'встречи + SOS',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BbV5Colors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Text(
              contact.name.isEmpty ? '?' : contact.name.characters.first,
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 14,
                color: BbV5Colors.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.check, size: 16, color: BbV5Colors.brand),
          IconButton(
            tooltip: 'Удалить',
            onPressed: onDelete,
            icon: const Icon(
              LucideIcons.trash_2,
              size: 15,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotlinesSection extends StatelessWidget {
  const _HotlinesSection();

  @override
  Widget build(BuildContext context) {
    const hotlines = [
      ('112 — экстренные службы', '112'),
      ('8 800 2000 122 — психологическая помощь', '88002000122'),
      ('Поддержка Frendly', '112'),
    ];

    return BbV5Section(
      title: 'ГОРЯЧИЕ ЛИНИИ',
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var index = 0; index < hotlines.length; index++) ...[
              _HotlineRow(label: hotlines[index].$1, phone: hotlines[index].$2),
              if (index != hotlines.length - 1)
                const Divider(height: 1, color: BbV5Colors.hairSoft),
            ],
          ],
        ),
      ),
    );
  }
}

class _HotlineRow extends StatelessWidget {
  const _HotlineRow({
    required this.label,
    required this.phone,
  });

  final String label;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse('tel:$phone')),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: const Icon(
                  LucideIcons.phone,
                  size: 16,
                  color: BbV5Colors.terra,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
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

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.md),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.bell, size: 17, color: BbV5Colors.terra),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Frendly не передаёт геолокацию третьим сторонам. SOS-сигнал хранится 7 дней и потом удаляется.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                height: 1.45,
                color: BbV5Colors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyHeader extends StatelessWidget {
  const _SafetyHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: LucideIcons.chevron_left,
            onTap: () => context.pop(),
            size: 24,
          ),
          Expanded(
            child: Text(
              'Безопасность',
              textAlign: TextAlign.center,
              style: AppTextStyles.itemTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final level = score >= 80 ? 'Высокий' : 'Средний';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.secondarySoft, colors.warmStart],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardBorder,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _IconTile(
                icon: LucideIcons.shield_check,
                background: colors.secondary,
                color: colors.secondaryForeground,
                size: 48,
                radius: 16,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Уровень доверия',
                      style: AppTextStyles.itemTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$score из 100 · $level',
                      style: AppTextStyles.meta.copyWith(
                        fontSize: 12,
                        height: 1.25,
                        color: colors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (score.clamp(0, 100)) / 100,
              color: colors.secondary,
              backgroundColor: colors.background.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosHeroCard extends StatelessWidget {
  const _SosHeroCard({
    required this.contactsCount,
    required this.onTap,
  });

  final int contactsCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.destructive.withValues(alpha: 0.05),
        border: Border.all(color: colors.destructive.withValues(alpha: 0.25)),
        borderRadius: AppRadii.cardBorder,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(
                icon: LucideIcons.shield_alert,
                background: colors.destructive,
                color: colors.destructiveForeground,
                size: 44,
                radius: 16,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS-рассылка',
                      style: AppTextStyles.itemTitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Одно нажатие — все доверенные контакты получат ссылку на встречу, список участников и твою геолокацию.',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        height: 1.625,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: colors.destructive,
                disabledBackgroundColor:
                    colors.destructive.withValues(alpha: 0.45),
                foregroundColor: colors.destructiveForeground,
                disabledForegroundColor: colors.destructiveForeground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                contactsCount == 0
                    ? 'Добавь контакт, чтобы включить SOS'
                    : 'Отправить SOS',
                style: AppTextStyles.button.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: colors.destructiveForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustedContactsSection extends StatelessWidget {
  const _TrustedContactsSection({
    required this.contacts,
    required this.onAdd,
    required this.onDelete,
  });

  final List<TrustedContactData> contacts;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Доверенные контакты',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.inkMute,
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.55,
                    ),
                  ),
                ),
                Text(
                  '${contacts.length}/5',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < contacts.length; index++) ...[
                  _ContactRow(
                    contact: contacts[index],
                    onDelete: () => onDelete(contacts[index].id),
                  ),
                  if (index != contacts.length - 1) const _DividerInset(),
                ],
                if (contacts.isNotEmpty) const _DividerInset(),
                _AddContactRow(
                  enabled: contacts.length < 5,
                  onTap: onAdd,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Контакты не видят твой профиль. Они получают сообщение, только когда ты сама нажмёшь SOS или поделишься планом.',
              style: AppTextStyles.caption.copyWith(
                color: colors.inkMute,
                height: 1.625,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.onDelete,
  });

  final TrustedContactData contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final channel = _channelInfo(contact.channel);
    final allPlans = contact.mode == 'all_plans';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _IconTile(
            icon: channel.icon,
            background: colors.muted,
            color: colors.inkSoft,
            size: 36,
            radius: 12,
            iconSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ScopeBadge(allPlans: allPlans),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${channel.label} · ${contact.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              LucideIcons.trash_2,
              size: 16,
              color: colors.inkMute,
            ),
            tooltip: 'Удалить',
          ),
        ],
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.allPlans});

  final bool allPlans;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = allPlans ? colors.secondary : colors.destructive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: allPlans ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        allPlans ? 'Встречи + SOS' : 'Только SOS',
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AddContactRow extends StatelessWidget {
  const _AddContactRow({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _IconTile(
                icon: LucideIcons.plus,
                background: colors.primary.withValues(alpha: 0.1),
                color: colors.primary,
                size: 36,
                radius: 12,
                iconSize: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Добавить контакт',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      'Телефон, Telegram или email',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        fontWeight: FontWeight.w400,
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

class _SosIncludedCard extends StatelessWidget {
  const _SosIncludedCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Что попадёт в SOS-сообщение',
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          const _Bullet(
              icon: LucideIcons.link_2,
              text: 'Ссылка на текущую встречу и её план'),
          const _Bullet(
              icon: LucideIcons.users,
              text: 'Имена и контакты всех участников'),
          const _Bullet(
              icon: LucideIcons.map_pin,
              text: 'Твоя геолокация в реальном времени (15 мин)'),
          const _Bullet(
              icon: LucideIcons.shield_alert,
              text: 'Прямая кнопка «Позвонить мне» и «112»'),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(
            icon: icon,
            background: colors.muted,
            color: colors.inkSoft,
            size: 24,
            radius: 6,
            iconSize: 14,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.meta.copyWith(
                fontSize: 12.5,
                color: colors.inkSoft,
                height: 1.375,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyGroup extends StatelessWidget {
  const _SafetyGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  color: colors.inkMute,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.55,
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1) const _DividerInset(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _IconTile(
            icon: icon,
            background: colors.muted,
            color: colors.inkSoft,
            size: 32,
            radius: 10,
            iconSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                Text(
                  sub,
                  style: AppTextStyles.meta.copyWith(
                    color: colors.inkMute,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _SwitchPill(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.sub,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconTile(
              icon: icon,
              background: colors.muted,
              color: colors.inkSoft,
              size: 32,
              radius: 10,
              iconSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    sub,
                    style: AppTextStyles.meta.copyWith(
                      color: colors.inkMute,
                      fontWeight: FontWeight.w400,
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

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Что-то случилось?',
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Команда саппорта Frendly отвечает 24/7. В чрезвычайной ситуации звони 112.',
            style: AppTextStyles.meta.copyWith(
              color: colors.inkMute,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: colors.foreground,
                foregroundColor: colors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Написать в саппорт',
                style: AppTextStyles.body.copyWith(
                  color: colors.background,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.onAdd});

  final Future<void> Function(_TrustedContactDraft contact) onAdd;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  String _channel = 'phone';
  String _scope = 'all_plans';
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameController.text.trim().isNotEmpty &&
      _valueController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final info = _channelInfo(_channel);
    return _SheetFrame(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetTitle(
                title: 'Доверенный контакт',
                onClose: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final channel in ['phone', 'telegram', 'email']) ...[
                    Expanded(
                      child: _ChannelButton(
                        channel: channel,
                        active: channel == _channel,
                        onTap: () {
                          setState(() {
                            _channel = channel;
                            _valueController.clear();
                          });
                        },
                      ),
                    ),
                    if (channel != 'email') const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              const _FieldLabel(text: 'Как подписать'),
              _SheetTextField(
                controller: _nameController,
                hintText: 'Мама, Лёша, сестра…',
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _FieldLabel(text: info.label),
              _SheetTextField(
                controller: _valueController,
                hintText: info.placeholder,
                keyboardType: _keyboardType(_channel),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                'Доставим через: ${info.hint}',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  height: 1.2,
                  color: colors.inkMute,
                ),
              ),
              const SizedBox(height: 16),
              const _FieldLabel(text: 'Когда уведомлять'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ScopeOption(
                      active: _scope == 'all_plans',
                      title: 'Встречи + SOS',
                      sub: 'План перед выходом и тревога',
                      onTap: () => setState(() {
                        _scope = 'all_plans';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ScopeOption(
                      active: _scope == 'sos_only',
                      title: 'Только SOS',
                      sub: 'Сообщение лишь в тревоге',
                      onTap: () => setState(() {
                        _scope = 'sos_only';
                      }),
                    ),
                  ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: AppTextStyles.meta.copyWith(
                    color: colors.destructive,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: !_valid || _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.foreground,
                    disabledBackgroundColor:
                        colors.foreground.withValues(alpha: 0.35),
                    foregroundColor: colors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _submitting ? 'Сохраняем' : 'Сохранить контакт',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: colors.background,
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

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.onAdd(
        _TrustedContactDraft(
          name: _nameController.text.trim(),
          channel: _channel,
          value: _valueController.text.trim(),
          mode: _scope,
        ),
      );
      if (mounted && context.mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = 'Не получилось сохранить контакт';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _SosConfirmSheet extends StatefulWidget {
  const _SosConfirmSheet({
    required this.contacts,
    required this.onFire,
  });

  final List<TrustedContactData> contacts;
  final Future<SafetySosData> Function() onFire;

  @override
  State<_SosConfirmSheet> createState() => _SosConfirmSheetState();
}

class _SosConfirmSheetState extends State<_SosConfirmSheet> {
  bool _sent = false;
  bool _submitting = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _SheetFrame(
      scrimColor: colors.foreground.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: _sent
            ? _SentState(count: widget.contacts.length)
            : _ConfirmState(
                contacts: widget.contacts,
                submitting: _submitting,
                errorText: _errorText,
                onCancel:
                    _submitting ? null : () => Navigator.of(context).pop(),
                onFire: _submitting ? null : _fire,
              ),
      ),
    );
  }

  Future<void> _fire() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.onFire();
      if (!mounted) {
        return;
      }
      setState(() {
        _sent = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted && context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = 'SOS сейчас недоступен';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _ConfirmState extends StatelessWidget {
  const _ConfirmState({
    required this.contacts,
    required this.submitting,
    required this.errorText,
    required this.onCancel,
    required this.onFire,
  });

  final List<TrustedContactData> contacts;
  final bool submitting;
  final String? errorText;
  final VoidCallback? onCancel;
  final VoidCallback? onFire;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.shield_alert, size: 20, color: colors.destructive),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Подтвердить SOS',
                style: AppTextStyles.itemTitle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
            _CircleIconButton(
              icon: LucideIcons.x,
              onTap: onCancel,
              color: colors.inkSoft,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Сообщение уйдёт ${contacts.length} контактам через выбранные каналы. Вместе с ним — ссылка на встречу, список участников и твоя текущая геолокация.',
          style: AppTextStyles.meta.copyWith(
            color: colors.inkMute,
            fontSize: 12.5,
            height: 1.625,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < contacts.length; index++) ...[
                _SosRecipientRow(contact: contacts[index]),
                if (index != contacts.length - 1) const _DividerInset(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.muted.withValues(alpha: 0.4),
            border: Border.all(
              color: colors.border,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Предпросмотр сообщения',
                style: AppTextStyles.caption.copyWith(
                  color: colors.inkMute,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '🚨 SOS от Кати. Я на встрече «Ужин у Pinch», нужна помощь.\n'
                '📍 Геолокация: frnd.ly/sos/8af2\n'
                '👥 Участники: Алекс, Маша, Дима (контакты внутри)\n'
                '☎️ Позвонить мне: +7 ··· 11 · Экстренный: 112',
                style: AppTextStyles.meta.copyWith(
                  fontSize: 12.5,
                  color: colors.inkSoft,
                  height: 1.625,
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            errorText!,
            style: AppTextStyles.meta.copyWith(color: colors.destructive),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    foregroundColor: colors.foreground,
                    backgroundColor: colors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Отмена',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: onFire,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.destructive,
                    foregroundColor: colors.destructiveForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    submitting ? 'Отправляем' : 'Отправить SOS',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: colors.destructiveForeground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SentState extends StatelessWidget {
  const _SentState({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconTile(
            icon: LucideIcons.check,
            background: colors.secondary.withValues(alpha: 0.15),
            color: colors.secondary,
            size: 64,
            radius: 999,
            iconSize: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'SOS отправлен',
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count контактов получают сообщение прямо сейчас',
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(
              color: colors.inkMute,
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _SosRecipientRow extends StatelessWidget {
  const _SosRecipientRow({required this.contact});

  final TrustedContactData contact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final channel = _channelInfo(contact.channel);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _IconTile(
            icon: channel.icon,
            background: colors.muted,
            color: colors.inkSoft,
            size: 32,
            radius: 10,
            iconSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                Text(
                  '${channel.label} · ${contact.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'готово',
            style: AppTextStyles.caption.copyWith(
              color: colors.secondary,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.child,
    this.scrimColor,
  });

  final Widget child;
  final Color? scrimColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scrimColor ?? colors.foreground.withValues(alpha: 0.4),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ),
        _CircleIconButton(
          icon: LucideIcons.x,
          onTap: onClose,
          color: colors.inkSoft,
          size: 20,
        ),
      ],
    );
  }
}

class _ChannelButton extends StatelessWidget {
  const _ChannelButton({
    required this.channel,
    required this.active,
    required this.onTap,
  });

  final String channel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final info = _channelInfo(channel);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.05) : colors.card,
          border: Border.all(color: active ? colors.primary : colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              info.icon,
              size: 20,
              color: active ? colors.primary : colors.inkSoft,
            ),
            const SizedBox(height: 4),
            Text(
              info.label,
              style: AppTextStyles.meta.copyWith(
                color: active ? colors.primary : colors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.active,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final bool active;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.05) : colors.card,
          border: Border.all(color: active ? colors.primary : colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.meta.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
                if (active)
                  Icon(LucideIcons.check, size: 14, color: colors.primary),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: AppTextStyles.caption.copyWith(
                color: colors.inkMute,
                height: 1.375,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTextStyles.meta.copyWith(
          color: colors.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.hintText,
    required this.textInputAction,
    required this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        style: AppTextStyles.body.copyWith(
          fontSize: 14,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.body.copyWith(
            fontSize: 14,
            height: 1.2,
            color: colors.inkMute,
          ),
          filled: true,
          fillColor: colors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary),
          ),
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
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? colors.primary : colors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.background,
    required this.color,
    required this.size,
    required this.radius,
    required this.iconSize,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: size, color: color ?? colors.foreground),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _DividerInset extends StatelessWidget {
  const _DividerInset();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.border,
    );
  }
}

class _TrustedContactDraft {
  const _TrustedContactDraft({
    required this.name,
    required this.channel,
    required this.value,
    required this.mode,
  });

  final String name;
  final String channel;
  final String value;
  final String mode;
}

class _ChannelInfo {
  const _ChannelInfo({
    required this.label,
    required this.icon,
    required this.placeholder,
    required this.hint,
  });

  final String label;
  final IconData icon;
  final String placeholder;
  final String hint;
}

_ChannelInfo _channelInfo(String channel) {
  switch (channel) {
    case 'telegram':
      return const _ChannelInfo(
        label: 'Telegram',
        icon: LucideIcons.send,
        placeholder: '@username',
        hint: 'Бот Frendly',
      );
    case 'email':
      return const _ChannelInfo(
        label: 'Email',
        icon: LucideIcons.mail,
        placeholder: 'name@mail.com',
        hint: 'Письмо',
      );
    case 'phone':
    default:
      return const _ChannelInfo(
        label: 'Телефон',
        icon: LucideIcons.phone,
        placeholder: '+7 999 123 45 67',
        hint: 'SMS',
      );
  }
}

TextInputType _keyboardType(String channel) {
  switch (channel) {
    case 'email':
      return TextInputType.emailAddress;
    case 'phone':
      return TextInputType.phone;
    case 'telegram':
    default:
      return TextInputType.text;
  }
}
