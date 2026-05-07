import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

class PerksScreen extends StatefulWidget {
  const PerksScreen({super.key});

  @override
  State<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends State<PerksScreen> {
  final _redeemed = <String>{};
  String _filter = 'all';

  static const _perks = [
    _PerkData(
      id: 'brix-glass',
      venue: 'Brix',
      type: 'Винный бар',
      perk: 'Бокал оранжа на компанию',
      condition: 'от 3 человек, check-in вместе',
      expires: 'до 2 июня',
      icon: LucideIcons.wine,
      color: BbV5Colors.terra,
      available: true,
    ),
    _PerkData(
      id: 'ph-dessert',
      venue: 'Powerhouse',
      type: 'Джаз-кафе',
      perk: 'Десерт от шефа',
      condition: 'после live-сета, от 4 человек',
      expires: 'до 28 мая',
      icon: LucideIcons.music,
      color: BbV5Colors.brand,
      available: true,
    ),
    _PerkData(
      id: 'kfm-coffee',
      venue: 'Кофемания',
      type: 'Кофе',
      perk: '−30% на завтраки утром',
      condition: 'до 11:00, от 2 человек',
      expires: 'ежедневно',
      icon: LucideIcons.coffee,
      color: BbV5Colors.gold,
      available: true,
    ),
    _PerkData(
      id: 'hidden-1',
      venue: 'Скрытое место',
      type: 'Откроется на 5-й вечер',
      perk: '???',
      condition: 'Frendly Streak ≥ 5',
      expires: 'скоро',
      icon: LucideIcons.sparkles,
      color: BbV5Colors.rose,
      available: false,
    ),
  ];

  List<_PerkData> get _filtered {
    return _perks.where((perk) {
      if (_filter == 'available') {
        return perk.available && !_redeemed.contains(perk.id);
      }
      if (_filter == 'used') {
        return _redeemed.contains(perk.id);
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BbV5TopBar(
                kicker: 'От заведений',
                title: 'Перки',
                accent: 'вечера',
                onBack: () => context.pop(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 16),
                child: Text(
                  'Закреплённые бонусы за check-in компанией. Чем больше людей пришло, тем больше открыто.',
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkSoft,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BbV5Chip(
                    label: 'Все',
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  BbV5Chip(
                    label: 'Доступно',
                    active: _filter == 'available',
                    onTap: () => setState(() => _filter = 'available'),
                  ),
                  BbV5Chip(
                    label: 'Использовано',
                    active: _filter == 'used',
                    onTap: () => setState(() => _filter = 'used'),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverList.separated(
              itemCount: _filtered.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final perk = _filtered[index];
                return _PerkTicket(
                  perk: perk,
                  redeemed: _redeemed.contains(perk.id),
                  onRedeem: !perk.available || _redeemed.contains(perk.id)
                      ? null
                      : () {
                          setState(() {
                            _redeemed.add(perk.id);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${perk.perk} активирован'),
                            ),
                          );
                        },
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: BbV5PillButton(
                label: 'Открыть ещё через Streak',
                icon: LucideIcons.sparkles,
                height: 48,
                expanded: true,
                onPressed: () => context.pushRoute(AppRoute.streak),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerkData {
  const _PerkData({
    required this.id,
    required this.venue,
    required this.type,
    required this.perk,
    required this.condition,
    required this.expires,
    required this.icon,
    required this.color,
    required this.available,
  });

  final String id;
  final String venue;
  final String type;
  final String perk;
  final String condition;
  final String expires;
  final IconData icon;
  final Color color;
  final bool available;
}

class _PerkTicket extends StatelessWidget {
  const _PerkTicket({
    required this.perk,
    required this.redeemed,
    required this.onRedeem,
  });

  final _PerkData perk;
  final bool redeemed;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            left: -10,
            top: 66,
            child: _TicketNotch(),
          ),
          Positioned(
            right: -10,
            top: 66,
            child: _TicketNotch(),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: perk.available
                            ? LinearGradient(
                                colors: [
                                  perk.color,
                                  perk.color.withValues(alpha: 0.86),
                                ],
                              )
                            : null,
                        color: perk.available ? null : BbV5Colors.paperHi,
                        borderRadius: BorderRadius.circular(16),
                        border: perk.available
                            ? null
                            : Border.all(color: BbV5Colors.hair),
                      ),
                      child: Icon(
                        perk.icon,
                        size: 24,
                        color: perk.available
                            ? BbV5Colors.paperHi
                            : BbV5Colors.inkMute,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: BbV5Kicker(
                                  perk.venue.toUpperCase(),
                                  color: perk.color,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '· ${perk.type}',
                                style: AppTextStyles.caption.copyWith(
                                  color: BbV5Colors.inkMute,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            perk.perk,
                            style: bbV5DisplayStyle(
                              fontSize: 16,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.users,
                                size: 12,
                                color: BbV5Colors.inkMute,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  perk.condition,
                                  style: AppTextStyles.caption.copyWith(
                                    color: BbV5Colors.inkMute,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BbV5Colors.hairSoft,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: redeemed
                      ? BbV5Colors.brandSoft.withValues(alpha: 0.35)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 12,
                      color: BbV5Colors.inkMute,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        perk.expires,
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (redeemed)
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.check,
                            size: 14,
                            color: BbV5Colors.brandDeep,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Активирован',
                            style: AppTextStyles.caption.copyWith(
                              color: BbV5Colors.brandDeep,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      )
                    else if (perk.available)
                      BbV5PillButton(
                        label: 'Активировать',
                        icon: LucideIcons.gift,
                        dark: true,
                        height: 32,
                        fontSize: 11,
                        iconSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: onRedeem,
                      )
                    else
                      Text(
                        'ЗАБЛОКИРОВАНО',
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketNotch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.hair),
      ),
    );
  }
}
