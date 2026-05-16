import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PublishMeetupScreen extends ConsumerStatefulWidget {
  const PublishMeetupScreen({
    this.initialDraft,
    super.key,
  });

  final CreateMeetupDraft? initialDraft;

  @override
  ConsumerState<PublishMeetupScreen> createState() =>
      _PublishMeetupScreenState();
}

class _PublishMeetupScreenState extends ConsumerState<PublishMeetupScreen> {
  String? _visibility;
  int _promo = 0;
  bool _terms = true;
  bool _publishing = false;

  @override
  Widget build(BuildContext context) {
    final draft = widget.initialDraft ?? ref.watch(createMeetupDraftProvider);
    final wallet = ref.watch(tokenWalletProvider);

    if (draft == null) {
      return BbV5Scaffold(
        child: BbV5Page(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BbV5TopBar(
                kicker: 'Финальный шаг',
                title: 'Черновик',
                accent: 'не найден',
              ),
              const SizedBox(height: 24),
              BbV5Card(
                child: Text(
                  'Вернись к созданию встречи и заполни основные поля.',
                  style: AppTextStyles.bodySoft.copyWith(
                    color: BbV5Colors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BbV5PillButton(
                label: 'К созданию',
                icon: LucideIcons.plus,
                dark: true,
                height: 52,
                expanded: true,
                onPressed: () => context.goRoute(AppRoute.createMeetup),
              ),
            ],
          ),
        ),
      );
    }

    final visibility = _visibility ?? draft.visibilityMode;

    return BbV5Scaffold(
      child: Stack(
        children: [
          BbV5Page(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 96),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const BbV5TopBar(
                  kicker: 'Финальный шаг',
                  title: 'Опубликовать',
                  accent: 'встречу',
                ),
                const SizedBox(height: 20),
                _PreviewCard(draft: draft),
                BbV5Section(
                  title: 'Кто увидит',
                  child: Row(
                    children: [
                      Expanded(
                        child: _VisibilityTile(
                          active: visibility == 'public',
                          icon: LucideIcons.globe,
                          title: 'Все рядом',
                          subtitle: 'видно на радаре',
                          onTap: () => setState(() {
                            _visibility = 'public';
                          }),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _VisibilityTile(
                          active: visibility == 'friends',
                          icon: LucideIcons.lock,
                          title: 'По ссылке',
                          subtitle: 'только по приглашению',
                          onTap: () => setState(() {
                            _visibility = 'friends';
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                BbV5Section(
                  title: 'Продвинуть',
                  child: _PromoCard(
                    balance: wallet.balance,
                    selected: _promo,
                    onChanged: (value) => setState(() {
                      _promo = value;
                    }),
                    onTopUp: () => context.pushRoute(AppRoute.wallet),
                  ),
                ),
                const SizedBox(height: 20),
                _TermsCard(
                  checked: _terms,
                  onChanged: () => setState(() {
                    _terms = !_terms;
                  }),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BbV5FixedBottomBar(
              fadeStop: 0.72,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: BbV5PillButton(
                label: _publishing ? 'Публикуем' : 'Опубликовать',
                icon: LucideIcons.send,
                dark: true,
                height: 52,
                fontSize: 14,
                expanded: true,
                onPressed: _publishing
                    ? null
                    : () => _publish(
                          draft,
                          visibility,
                          wallet.balance,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publish(
    CreateMeetupDraft draft,
    String visibility,
    int balance,
  ) async {
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подтверди правила сообщества')),
      );
      return;
    }
    if (_promo > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостаточно токенов')),
      );
      context.pushRoute(AppRoute.wallet);
      return;
    }

    final publishDraft = draft.copyWith(
      visibilityMode: visibility,
      joinMode: visibility == 'friends' || draft.accessMode == 'request'
          ? EventJoinMode.request
          : EventJoinMode.open,
    );

    setState(() {
      _publishing = true;
    });
    try {
      final event = await submitCreateMeetupDraft(ref, publishDraft);
      if (_promo > 0) {
        final option = PromoOption(
          id: _promo == 80 ? 'boost-24' : 'boost-72',
          title: _promo == 80 ? 'Буст · 24 часа' : 'Буст · 3 дня',
          subtitle: 'Промо встречи',
          cost: _promo,
          durationHours: _promo == 80 ? 24 : 72,
        );
        final promoted = await ref
            .read(tokenWalletProvider.notifier)
            .promote(event.id, option);
        if (!promoted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Недостаточно токенов')),
          );
          context.pushRoute(AppRoute.wallet);
          return;
        }
      }
      if (!mounted) {
        return;
      }
      ref.read(createMeetupDraftProvider.notifier).state = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _promo > 0
                ? 'Встреча опубликована. + ТОП ${_promo == 80 ? '24ч' : '3 дня'}'
                : 'Встреча опубликована',
          ),
        ),
      );
      context.pushReplacementNamed(
        AppRoute.eventDetail.name,
        pathParameters: {'eventId': event.id},
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось опубликовать встречу')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
      }
    }
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.draft});

  final CreateMeetupDraft draft;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BbV5Kicker('превью карточки'),
          const SizedBox(height: 8),
          Text(
            draft.title,
            style: bbV5DisplayStyle(fontSize: 24, height: 1.12),
          ),
          const SizedBox(height: 12),
          _MetaLine(icon: LucideIcons.calendar, label: draft.timeLabel),
          const SizedBox(height: 6),
          _MetaLine(icon: LucideIcons.map_pin, label: draft.place),
          const SizedBox(height: 6),
          _MetaLine(icon: LucideIcons.users, label: draft.capacityLabel),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SmallTag(draft.vibe),
              _SmallTag(draft.priceLabel),
              _SmallTag(
                draft.visibilityMode == 'friends' ? 'по ссылке' : 'открытая',
              ),
              if (draft.requiresVerification) const _SmallTag('верификация'),
              if (draft.requiresFrendlyPlus) const _SmallTag('Frendly+'),
            ],
          ),
          if (draft.attachmentTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BbV5Colors.hair),
              ),
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
                    child: Icon(
                      draft.attachmentIcon,
                      size: 16,
                      color: BbV5Colors.ink,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.attachmentTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontFamily: 'Sora',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: BbV5Colors.ink,
                          ),
                        ),
                        if (draft.attachmentSubtitle != null)
                          Text(
                            draft.attachmentSubtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10.5,
                              color: BbV5Colors.inkMute,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: BbV5Colors.inkSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12.5,
              color: BbV5Colors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontFamily: 'Sora',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: BbV5Colors.inkSoft,
        ),
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.md),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.md),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  color: active
                      ? BbV5Colors.paperHi.withValues(alpha: 0.72)
                      : BbV5Colors.inkMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.balance,
    required this.selected,
    required this.onChanged,
    required this.onTopUp,
  });

  final int balance;
  final int selected;
  final ValueChanged<int> onChanged;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    const options = [
      (0, 'Без промо', 'обычно'),
      (80, 'ТОП 24ч', '80 токенов'),
      (200, 'ТОП 3 дня', '200 токенов'),
    ];

    return BbV5Card(
      radius: BbV5Radii.md,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 15,
                color: BbV5Colors.terra,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ТОП в радаре',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.coins,
                size: 13,
                color: BbV5Colors.inkMute,
              ),
              const SizedBox(width: 4),
              Text(
                'баланс $balance',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: BbV5Colors.inkMute,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 0; index < options.length; index++) ...[
                Expanded(
                  child: _PromoOptionTile(
                    active: selected == options[index].$1,
                    title: options[index].$2,
                    subtitle: options[index].$3,
                    onTap: () => onChanged(options[index].$1),
                  ),
                ),
                if (index != options.length - 1)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onTopUp,
              icon: const Icon(LucideIcons.chevron_right, size: 14),
              label: const Text('Пополнить баланс'),
              style: TextButton.styleFrom(
                foregroundColor: BbV5Colors.terra,
                textStyle: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoOptionTile extends StatelessWidget {
  const _PromoOptionTile({
    required this.active,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool active;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: active
                      ? BbV5Colors.paperHi.withValues(alpha: 0.72)
                      : BbV5Colors.inkMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({
    required this.checked,
    required this.onChanged,
  });

  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: BbV5Radii.md,
      padding: const EdgeInsets.all(16),
      onTap: onChanged,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: checked ? BbV5Colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: checked ? BbV5Colors.accent : BbV5Colors.hair,
                width: 1.5,
              ),
            ),
            child: checked
                ? const Icon(
                    LucideIcons.check,
                    size: 14,
                    color: BbV5Colors.paperHi,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Соблюдаю правила Frendly',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Без агрессии, спама и оскорблений. Хост отвечает за участников.',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    height: 1.35,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.shield_check,
            size: 17,
            color: BbV5Colors.brand,
          ),
        ],
      ),
    );
  }
}
