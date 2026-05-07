import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  static const _days = [
    3,
    5,
    6,
    11,
    12,
    18,
    19,
    20,
    24,
    25,
  ];

  @override
  Widget build(BuildContext context) {
    const current = 3;
    const monthGoal = 5;

    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          children: [
            BbV5TopBar(
              kicker: 'Геймификация',
              title: 'Frendly',
              accent: 'streak',
              onBack: () => context.pop(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: BbV5Card(
                          tint: BbV5Colors.terraSoft,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          BbV5Colors.accent,
                                          BbV5Colors.accentDeep,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: BbV5Shadows.ink,
                                    ),
                                    child: const Icon(
                                      LucideIcons.flame,
                                      size: 36,
                                      color: BbV5Colors.paperHi,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const BbV5Kicker('В этом месяце'),
                                        const SizedBox(height: 4),
                                        Text.rich(
                                          const TextSpan(
                                            children: [
                                              TextSpan(text: '$current'),
                                              TextSpan(
                                                text: ' / $monthGoal вечеров',
                                              ),
                                            ],
                                          ),
                                          style: bbV5DisplayStyle(
                                            fontSize: 42,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Ещё 2 встречи. Потом откроется десерт у Powerhouse.',
                                          style: AppTextStyles.meta.copyWith(
                                            height: 1.4,
                                            color: BbV5Colors.inkSoft,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(BbV5Radii.pill),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: current / monthGoal,
                                  color: BbV5Colors.accent,
                                  backgroundColor:
                                      BbV5Colors.ink.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      const SliverToBoxAdapter(
                        child: _MonthMapCard(),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      const SliverToBoxAdapter(child: _RewardsList()),
                      const SliverToBoxAdapter(child: SizedBox(height: 90)),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 14),
                      child: BbV5PillButton(
                        label: 'Посмотреть перки заведений',
                        icon: LucideIcons.gift,
                        trailingIcon: LucideIcons.chevron_right,
                        dark: true,
                        height: 48,
                        expanded: true,
                        onPressed: () => context.pushRoute(AppRoute.perks),
                      ),
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

class _MonthMapCard extends StatelessWidget {
  const _MonthMapCard();

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'Май · карта вечеров',
      right: Row(
        children: [
          const Icon(
            LucideIcons.calendar,
            size: 12,
            color: BbV5Colors.inkMute,
          ),
          const SizedBox(width: 4),
          Text(
            '30 дней',
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
      margin: EdgeInsets.zero,
      child: BbV5Card(
        padding: const EdgeInsets.all(16),
        radius: 24,
        child: Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 30,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final day = index + 1;
                final went = StreakScreen._days.contains(day);
                final today = day == 25;
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: went
                        ? const LinearGradient(
                            colors: [
                              BbV5Colors.accent,
                              BbV5Colors.accentDeep,
                            ],
                          )
                        : null,
                    color: went ? null : BbV5Colors.paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: today ? BbV5Colors.accent : BbV5Colors.hair,
                    ),
                  ),
                  child: Text(
                    '$day',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                      color: went ? BbV5Colors.paperHi : BbV5Colors.inkMute,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            const Divider(color: BbV5Colors.hairSoft),
            const SizedBox(height: 6),
            const Row(
              children: [
                _LegendDot(color: BbV5Colors.accent, label: 'Встречи'),
                SizedBox(width: 18),
                _LegendDot(
                  color: BbV5Colors.paper,
                  border: BbV5Colors.accent,
                  label: 'Сегодня',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.border,
  });

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: BbV5Colors.inkSoft,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _RewardsList extends StatelessWidget {
  const _RewardsList();

  static const List<
      ({
        String threshold,
        String title,
        String subtitle,
        bool unlocked,
        IconData icon,
      })> _items = [
    (
      threshold: '1 ВЕЧЕР',
      title: 'Первая искра',
      subtitle: 'Бейдж в профиле',
      unlocked: true,
      icon: LucideIcons.sparkles,
    ),
    (
      threshold: '3 ВЕЧЕРА',
      title: 'Тёплый круг',
      subtitle: 'Скрытое место от Brix',
      unlocked: true,
      icon: LucideIcons.gift,
    ),
    (
      threshold: '5 ВЕЧЕРОВ',
      title: 'Свой человек',
      subtitle: 'Бесплатный десерт у Powerhouse',
      unlocked: false,
      icon: LucideIcons.gift,
    ),
    (
      threshold: '7 ВЕЧЕРОВ',
      title: 'Знаток вечера',
      subtitle: 'Доступ к After-Dark подборкам',
      unlocked: false,
      icon: LucideIcons.sparkles,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'Что открывается',
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in _items) ...[
            _RewardCard(item: item),
            if (item != _items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.item});

  final ({
    String threshold,
    String title,
    String subtitle,
    bool unlocked,
    IconData icon,
  }) item;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: item.unlocked
                  ? const LinearGradient(
                      colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
                    )
                  : null,
              color: item.unlocked ? null : BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: item.unlocked ? Colors.transparent : BbV5Colors.hair,
              ),
            ),
            child: Icon(
              item.unlocked ? item.icon : LucideIcons.lock,
              size: 20,
              color: item.unlocked ? BbV5Colors.paperHi : BbV5Colors.inkMute,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BbV5Kicker(item.threshold),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: bbV5DisplayStyle(fontSize: 15, height: 1.1),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (item.unlocked)
            const Icon(
              LucideIcons.chevron_right,
              size: 16,
              color: BbV5Colors.inkMute,
            ),
        ],
      ),
    );
  }
}
