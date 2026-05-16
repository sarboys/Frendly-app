import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/frendly_season_provider.dart';
import 'package:big_break_mobile/shared/models/frendly_season.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  String? _claimingRewardKey;

  @override
  Widget build(BuildContext context) {
    final seasonAsync = ref.watch(frendlySeasonProvider);
    final season = seasonAsync.valueOrNull;
    final current = season?.checkedInCount ?? 0;
    final nextReward = season?.nextReward;
    final monthGoal = nextReward?.threshold ?? 25;
    final remaining = (monthGoal - current).clamp(0, monthGoal);
    final progress =
        monthGoal == 0 ? 0.0 : (current / monthGoal).clamp(0, 1).toDouble();

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
            const SizedBox(height: 20),
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
                                          TextSpan(
                                            children: [
                                              TextSpan(text: '$current'),
                                              TextSpan(
                                                text: ' / $monthGoal вечеров',
                                                style: AppTextStyles.screenTitle
                                                    .copyWith(
                                                  fontFamily: 'Sora',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1,
                                                  letterSpacing: 0,
                                                  color: BbV5Colors.inkMute,
                                                  fontFeatures: const [
                                                    FontFeature
                                                        .tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          style: bbV5DisplayStyle(
                                            fontSize: 42,
                                            height: 1,
                                            letterSpacing: -1.26,
                                          ).copyWith(
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          nextReward == null
                                              ? 'Все подарки сезона уже открыты.'
                                              : 'Ещё $remaining check-in. Потом откроется ${nextReward.rewardLabel}.',
                                          style: AppTextStyles.meta.copyWith(
                                            fontSize: 12.5,
                                            height: 1.625,
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
                                  value: progress,
                                  color: BbV5Colors.accent,
                                  backgroundColor:
                                      BbV5Colors.ink.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(
                        child: _MonthMapCard(
                          days: season?.calendarDays ?? const [],
                          title: season?.seasonLabel ?? 'Сезон',
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(
                        child: _RewardsList(
                          rewards: season?.rewards ?? const [],
                          loading: seasonAsync.isLoading,
                          claimingRewardKey: _claimingRewardKey,
                          onClaim: _claimReward,
                        ),
                      ),
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
                        label: 'Посмотреть промо заведений',
                        icon: LucideIcons.gift,
                        trailingIcon: LucideIcons.chevron_right,
                        dark: true,
                        height: 48,
                        fontSize: 13,
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

  Future<void> _claimReward(FrendlySeasonRewardData reward) async {
    if (!reward.canClaim || _claimingRewardKey != null) {
      return;
    }
    setState(() => _claimingRewardKey = reward.key);
    try {
      final result = await ref
          .read(backendRepositoryProvider)
          .claimFrendlySeasonReward(reward.key);
      if (!mounted) {
        return;
      }
      ref.invalidate(frendlySeasonProvider);
      ref.invalidate(tokenWalletProvider);
      ref.invalidate(subscriptionStateProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.reward.rewardLabel} начислено')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось забрать подарок')),
      );
    } finally {
      if (mounted) {
        setState(() => _claimingRewardKey = null);
      }
    }
  }
}

class _MonthMapCard extends StatelessWidget {
  const _MonthMapCard({
    required this.days,
    required this.title,
  });

  final List<int> days;
  final String title;

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: title,
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
              fontSize: 10.5,
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
                final went = days.contains(day);
                final today = day == DateTime.now().day;
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
                      fontFeatures: const [FontFeature.tabularFigures()],
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
            fontSize: 10.5,
            color: BbV5Colors.inkSoft,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _RewardsList extends StatelessWidget {
  const _RewardsList({
    required this.rewards,
    required this.loading,
    required this.claimingRewardKey,
    required this.onClaim,
  });

  final List<FrendlySeasonRewardData> rewards;
  final bool loading;
  final String? claimingRewardKey;
  final ValueChanged<FrendlySeasonRewardData> onClaim;

  @override
  Widget build(BuildContext context) {
    final items = rewards.isEmpty && loading ? _fallbackRewards : rewards;
    return BbV5Section(
      title: 'Что открывается',
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in items) ...[
            _RewardCard(
              item: item,
              claiming: claimingRewardKey == item.key,
              onClaim: () => onClaim(item),
            ),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.item,
    required this.claiming,
    required this.onClaim,
  });

  final FrendlySeasonRewardData item;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.unlocked;
    final icon = item.rewardKind == FrendlySeasonRewardKind.tokens
        ? LucideIcons.coins
        : LucideIcons.sparkles;
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
              gradient: unlocked
                  ? const LinearGradient(
                      colors: [BbV5Colors.accent, BbV5Colors.accentDeep],
                    )
                  : null,
              color: unlocked ? null : BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: unlocked ? Colors.transparent : BbV5Colors.hair,
              ),
            ),
            child: Icon(
              unlocked ? icon : LucideIcons.lock,
              size: 20,
              color: unlocked ? BbV5Colors.paperHi : BbV5Colors.inkMute,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.threshold} CHECK-IN',
                  style: bbV5KickerStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: bbV5DisplayStyle(fontSize: 14.5, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text(
                  item.rewardLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: BbV5Colors.inkMute,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (item.claimed)
            const Icon(
              LucideIcons.check,
              size: 18,
              color: BbV5Colors.brandDeep,
            )
          else if (item.canClaim)
            BbV5PillButton(
              label: claiming ? '...' : 'Забрать',
              height: 32,
              fontSize: 11,
              icon: LucideIcons.gift,
              iconSize: 12,
              dark: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: claiming ? null : onClaim,
            )
          else
            const Icon(
              LucideIcons.lock,
              size: 16,
              color: BbV5Colors.inkMute,
            ),
        ],
      ),
    );
  }
}

const _fallbackRewards = [
  FrendlySeasonRewardData(
    key: 'checkin-1',
    threshold: 1,
    statusTitle: 'Искра',
    title: 'Первая искра',
    description: '50 токенов за первый вечер сезона',
    rewardKind: FrendlySeasonRewardKind.tokens,
    rewardAmount: 50,
    unlocked: false,
    claimed: false,
    claimedAt: null,
  ),
  FrendlySeasonRewardData(
    key: 'checkin-5',
    threshold: 5,
    statusTitle: 'Свой круг',
    title: 'Свой круг',
    description: '150 токенов за 5 вечеров',
    rewardKind: FrendlySeasonRewardKind.tokens,
    rewardAmount: 150,
    unlocked: false,
    claimed: false,
    claimedAt: null,
  ),
  FrendlySeasonRewardData(
    key: 'checkin-10',
    threshold: 10,
    statusTitle: 'Человек вечера',
    title: 'Человек вечера',
    description: 'Frendly+ на 1 месяц',
    rewardKind: FrendlySeasonRewardKind.subscription,
    rewardAmount: 30,
    unlocked: false,
    claimed: false,
    claimedAt: null,
  ),
  FrendlySeasonRewardData(
    key: 'checkin-15',
    threshold: 15,
    statusTitle: 'Городской ритм',
    title: 'Городской ритм',
    description: '500 токенов за 15 вечеров',
    rewardKind: FrendlySeasonRewardKind.tokens,
    rewardAmount: 500,
    unlocked: false,
    claimed: false,
    claimedAt: null,
  ),
  FrendlySeasonRewardData(
    key: 'checkin-25',
    threshold: 25,
    statusTitle: 'Легенда месяца',
    title: 'Легенда месяца',
    description: 'Frendly+ на 6 месяцев',
    rewardKind: FrendlySeasonRewardKind.subscription,
    rewardAmount: 180,
    unlocked: false,
    claimed: false,
    claimedAt: null,
  ),
];
