import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/after_dark/presentation/after_dark_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/subscription.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _plan = 'year';
  bool _subscribing = false;
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final stateAsync = ref.watch(subscriptionStateProvider);

    return BbV5Scaffold(
      child: plansAsync.when(
        loading: () => const _PaywallLoadingState(),
        error: (_, __) => _PaywallErrorState(
          onRetry: () => ref.invalidate(subscriptionPlansProvider),
        ),
        data: (plans) => stateAsync.when(
          loading: () => const _PaywallLoadingState(),
          error: (_, __) => _PaywallErrorState(
            onRetry: () => ref.invalidate(subscriptionStateProvider),
          ),
          data: (state) => _PaywallContent(
            plans: plans,
            state: state,
            selectedPlanId: _plan,
            subscribing: _subscribing,
            restoring: _restoring,
            onPlanChanged: (planId) => setState(() => _plan = planId),
            onRestore: _restore,
            onSubscribe: _subscribe,
          ),
        ),
      ),
    );
  }

  Future<void> _restore() async {
    if (_restoring) {
      return;
    }
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _restoring = true);
    try {
      if (!mounted) {
        return;
      }
      await repository.restoreSubscription();
      if (!mounted || !context.mounted) {
        return;
      }
      container.invalidate(subscriptionStateProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подписки восстановлены')),
      );
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Восстановление пока недоступно')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  Future<void> _subscribe() async {
    if (_subscribing) {
      return;
    }
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _subscribing = true);
    try {
      await repository.subscribe(_plan);
      if (!mounted || !context.mounted) {
        return;
      }
      container.invalidate(subscriptionStateProvider);
      container.invalidate(afterDarkAccessProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Frendly+ активирован')),
      );
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось подключить подписку')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _subscribing = false);
      }
    }
  }
}

class _PaywallContent extends StatelessWidget {
  const _PaywallContent({
    required this.plans,
    required this.state,
    required this.selectedPlanId,
    required this.subscribing,
    required this.restoring,
    required this.onPlanChanged,
    required this.onRestore,
    required this.onSubscribe,
  });

  final List<SubscriptionPlanData> plans;
  final SubscriptionStateData state;
  final String selectedPlanId;
  final bool subscribing;
  final bool restoring;
  final ValueChanged<String> onPlanChanged;
  final VoidCallback onRestore;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final year = _planById(plans, 'year');
    final month = _planById(plans, 'month');
    if (year == null || month == null) {
      return _PaywallErrorState(
        onRetry: () {},
        message: 'Тарифы пока недоступны',
      );
    }

    final selectedPlan = selectedPlanId == 'month' ? month : year;
    final hasActiveSubscription =
        state.status == 'active' || state.status == 'trial';

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 156),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PaywallHeader(
                            restoring: restoring,
                            onBack: () => context.pop(),
                            onRestore: onRestore,
                          ),
                          const SizedBox(height: 28),
                          const _PaywallHero(),
                          const SizedBox(height: AppSpacing.lg),
                          const _FeaturesCard(),
                          const SizedBox(height: AppSpacing.lg),
                          _PlanTile(
                            plan: year,
                            active: selectedPlanId == 'year',
                            activeSubscription:
                                hasActiveSubscription && state.plan == 'year',
                            summary:
                                '${year.priceMonthlyRub} ₽/мес · списание раз в год',
                            strikePrice: year.priceRub * 2,
                            onTap: () => onPlanChanged('year'),
                          ),
                          const SizedBox(height: 10),
                          _PlanTile(
                            plan: month,
                            active: selectedPlanId == 'month',
                            activeSubscription:
                                hasActiveSubscription && state.plan == 'month',
                            summary: 'Можно отменить в любой момент',
                            onTap: () => onPlanChanged('month'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Авто-продление можно отключить в настройках. Условия и приватность.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10.5,
                              height: 1.45,
                              letterSpacing: 0,
                              color: BbV5Colors.inkMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickySubscribeBar(
                  plan: selectedPlan,
                  subscribing: subscribing,
                  onSubscribe: onSubscribe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SubscriptionPlanData? _planById(
    List<SubscriptionPlanData> plans,
    String id,
  ) {
    for (final plan in plans) {
      if (plan.id == id) {
        return plan;
      }
    }
    return null;
  }
}

class _PaywallHeader extends StatelessWidget {
  const _PaywallHeader({
    required this.restoring,
    required this.onBack,
    required this.onRestore,
  });

  final bool restoring;
  final VoidCallback onBack;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: onBack,
        ),
        const Spacer(),
        TextButton(
          onPressed: restoring ? null : onRestore,
          child: Text(
            restoring ? '...' : 'Восстановить',
            style: AppTextStyles.button.copyWith(
              fontSize: 12,
              color: BbV5Colors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaywallHero extends StatelessWidget {
  const _PaywallHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: BbV5Colors.accent,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            boxShadow: BbV5Shadows.ink,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 13,
                color: BbV5Colors.paperHi,
              ),
              const SizedBox(width: 6),
              Text(
                'Frendly+',
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.89,
                  color: BbV5Colors.paperHi,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Больше встреч,\n'),
              TextSpan(
                text: 'своих людей.',
                style: bbV5DisplayStyle(
                  fontSize: 32,
                  height: 1.05,
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: bbV5DisplayStyle(fontSize: 32, height: 1.05),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Чтобы ни один интересный вечер не прошёл мимо.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            height: 1.45,
            color: BbV5Colors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  static const _features = [
    _FeatureData(
      icon: LucideIcons.sliders_horizontal,
      title: 'Расширенные фильтры',
      subtitle: 'Возраст, верификация, вайб, общие интересы',
    ),
    _FeatureData(
      icon: LucideIcons.zap,
      title: 'Приоритет в заявках',
      subtitle: 'Хосты видят твою заявку первой',
    ),
    _FeatureData(
      icon: LucideIcons.calendar,
      title: 'Безлимит встреч',
      subtitle: 'Создавай и присоединяйся без ограничений',
    ),
    _FeatureData(
      icon: LucideIcons.eye,
      title: 'Кто смотрел профиль',
      subtitle: 'Видишь, кому ты понравился',
    ),
    _FeatureData(
      icon: LucideIcons.crown,
      title: 'Доступ к Dating',
      subtitle: 'Полноценные знакомства один на один',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < _features.length; index++) ...[
            _FeatureRow(data: _features[index]),
            if (index != _features.length - 1)
              const Divider(height: 1, color: BbV5Colors.hairSoft),
          ],
        ],
      ),
    );
  }
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.data});

  final _FeatureData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BbV5Colors.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(data.icon, size: 18, color: BbV5Colors.terra),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: bbV5DisplayStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 11.5,
                    height: 1.2,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            LucideIcons.check,
            size: 17,
            color: BbV5Colors.brand,
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.active,
    required this.activeSubscription,
    required this.summary,
    required this.onTap,
    this.strikePrice,
  });

  final SubscriptionPlanData plan;
  final bool active;
  final bool activeSubscription;
  final String summary;
  final VoidCallback onTap;
  final int? strikePrice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BbV5Colors.paperHi, BbV5Colors.paper],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? BbV5Colors.ink : BbV5Colors.hair,
              width: active ? 2 : 1,
            ),
            boxShadow: BbV5Shadows.card,
          ),
          child: Stack(
            children: [
              if (plan.badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _PlanBadge(label: plan.badge!),
                ),
              if (activeSubscription)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: _PlanBadge(label: 'Активно'),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.label,
                    style: bbV5DisplayStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: AppTextStyles.meta.copyWith(
                      fontSize: 11.5,
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${plan.priceRub} ₽',
                        style:
                            bbV5DisplayStyle(fontSize: 22, height: 1).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (plan.id == 'month')
                        Text(
                          '/мес',
                          style: AppTextStyles.meta.copyWith(
                            color: BbV5Colors.inkMute,
                          ),
                        ),
                      if (strikePrice != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '$strikePrice ₽',
                          style: AppTextStyles.meta.copyWith(
                            color: BbV5Colors.inkMute,
                            decoration: TextDecoration.lineThrough,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (plan.id == 'year' && plan.trialDays > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${plan.trialDays} дней бесплатно',
                      style: AppTextStyles.caption.copyWith(
                        letterSpacing: 0,
                        color: BbV5Colors.inkMute,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BbV5Colors.terra,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: BbV5Colors.paperHi,
        ),
      ),
    );
  }
}

class _StickySubscribeBar extends StatelessWidget {
  const _StickySubscribeBar({
    required this.plan,
    required this.subscribing,
    required this.onSubscribe,
  });

  final SubscriptionPlanData plan;
  final bool subscribing;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final label = plan.id == 'year'
        ? 'Попробовать ${plan.trialDays} дней бесплатно'
        : 'Подключить за ${plan.priceRub} ₽/мес';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00F1E6D6),
            Color(0xF2F1E6D6),
            BbV5Colors.paper,
          ],
          stops: [0, 0.34, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: BbV5PillButton(
            label: subscribing ? 'Подключаем...' : label,
            onPressed: subscribing ? null : onSubscribe,
            dark: true,
            height: 56,
            fontSize: 14,
            expanded: true,
          ),
        ),
      ),
    );
  }
}

class _PaywallLoadingState extends StatelessWidget {
  const _PaywallLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

class _PaywallErrorState extends StatelessWidget {
  const _PaywallErrorState({
    required this.onRetry,
    this.message = 'Не получилось загрузить подписку',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BbV5Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: bbV5DisplayStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Попробуй ещё раз через пару секунд.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.meta.copyWith(
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BbV5PillButton(
                    label: 'Повторить',
                    onPressed: onRetry,
                    dark: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
