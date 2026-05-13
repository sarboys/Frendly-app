import 'package:big_break_mobile/app/core/device/payment_link_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/payments/application/payment_return_controller.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/widgets/bb_bottom_nav.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _tokenBalance = 1240;

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  var _pickedPackId = 'p2';
  String? _lastOrderId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(tokenWalletProvider);
    final packs = ref.watch(tokenPacksProvider);
    ref.listen<PaymentReturnState?>(paymentReturnStateProvider,
        (previous, next) {
      if (next == null || previous == next || !context.mounted) {
        return;
      }
      final message = next.confirmed
          ? 'Токены начислены'
          : next.failed
              ? 'Оплата не прошла'
              : 'Платеж еще обрабатывается';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
    final picked = packs.firstWhere(
      (pack) => pack.id == _pickedPackId,
      orElse: () => packs.first,
    );

    return _TokensPageScaffold(
      bottomNavLocation: AppRoute.wallet.path,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 148),
            children: [
              BbV5TopBar(
                kicker: 'Кошелёк',
                title: 'Frendly',
                accent: 'токены',
                onBack: () => _popOrProfile(context),
              ),
              const SizedBox(height: 20),
              _WalletBalanceCard(balance: wallet.balance),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: BbV5Kicker('Пополнить баланс'),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                itemCount: packs.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.08,
                ),
                itemBuilder: (context, index) {
                  final pack = packs[index];
                  return _WalletPackCard(
                    pack: pack,
                    active: pack.id == _pickedPackId,
                    onTap: () => setState(() {
                      _pickedPackId = pack.id;
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              BbV5PillButton(
                label: _busy ? 'Открываем оплату...' : 'Купить пакет',
                icon: LucideIcons.sparkles,
                dark: true,
                height: 52,
                expanded: true,
                onPressed: _busy ? null : () => _buyPack(picked),
              ),
              if (_lastOrderId != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _checkPayment,
                  child: Text(
                    'Проверить оплату',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 12,
                      color: BbV5Colors.inkSoft,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const _WalletSpendCard(),
              if (wallet.history.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: BbV5Kicker('История'),
                ),
                const SizedBox(height: 12),
                _WalletHistoryCard(history: wallet.history.take(10).toList()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _buyPack(TokenPack pack) async {
    setState(() => _busy = true);
    try {
      final order =
          await ref.read(tokenWalletProvider.notifier).createTopUpPayment(pack);
      final paymentUrl = order.paymentUrl;
      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw StateError('Payment URL is empty');
      }
      if (!mounted || !context.mounted) {
        return;
      }
      setState(() => _lastOrderId = order.orderId);
      final opened =
          await ref.read(paymentLinkServiceProvider).openPaymentUrl(paymentUrl);
      if (!opened) {
        throw StateError('Payment URL was not opened');
      }
      if (!mounted || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вернись сюда после оплаты')),
      );
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось открыть оплату')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _checkPayment() async {
    final orderId = _lastOrderId;
    if (orderId == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final order =
          await ref.read(backendRepositoryProvider).checkPayment(orderId);
      if (!mounted || !context.mounted) {
        return;
      }
      if (order.isConfirmed) {
        await ref.read(tokenWalletProvider.notifier).refresh();
        if (!mounted || !context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Токены начислены')),
        );
      } else if (order.isFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оплата не прошла')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Платеж еще обрабатывается')),
        );
      }
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Платеж еще обрабатывается')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BbV5Kicker('На счёте'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$balance',
                style: bbV5DisplayStyle(
                  fontSize: 52,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.coins,
                      size: 15,
                      color: BbV5Colors.terra,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'токенов',
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.terra,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Используй для продвижения встреч, премиум-мест в афише и pinned-сообщений в чатах сообществ.',
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkSoft,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletPackCard extends StatelessWidget {
  const _WalletPackCard({
    required this.pack,
    required this.active,
    required this.onTap,
  });

  final TokenPack pack;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? BbV5Colors.paperHi : BbV5Colors.ink;
    final softFg = active
        ? BbV5Colors.paperHi.withValues(alpha: 0.85)
        : BbV5Colors.inkMute;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? BbV5Colors.accent : BbV5Colors.hair,
          ),
          boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (pack.best)
              Positioned(
                right: 0,
                top: -22,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BbV5Colors.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ХИТ',
                    style: AppTextStyles.caption.copyWith(
                      fontFamily: 'Sora',
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.coins, size: 14, color: fg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pack.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontFamily: 'Sora',
                          color: fg,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${pack.tokens}',
                  style: bbV5DisplayStyle(
                    fontSize: 26,
                    height: 1,
                    color: fg,
                    letterSpacing: 0,
                  ),
                ),
                if (pack.bonus > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(LucideIcons.gift, size: 12, color: softFg),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '+${pack.bonus} бонус',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: softFg,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                Text(
                  '${pack.price} ₽',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSpendCard extends StatelessWidget {
  const _WalletSpendCard();

  @override
  Widget build(BuildContext context) {
    return const BbV5Card(
      radius: 24,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbV5Kicker('На что тратить'),
          SizedBox(height: 14),
          _WalletSpendRow(
            icon: LucideIcons.trending_up,
            title: 'Продвижение встреч',
            text: 'От 80 токенов, топ ленты, бейдж, push-уведомления',
          ),
          _WalletSpendRow(
            icon: LucideIcons.sparkles,
            title: 'Премиум-маршруты',
            text: 'Открой брендированные подборки от партнёров',
          ),
          _WalletSpendRow(
            icon: LucideIcons.gift,
            title: 'Подарок другу',
            text: 'Перевод внутри Frendly без комиссий',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _WalletSpendRow extends StatelessWidget {
  const _WalletSpendRow({
    required this.icon,
    required this.title,
    required this.text,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BbV5Colors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, size: 16, color: BbV5Colors.terra),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: bbV5DisplayStyle(fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHistoryCard extends StatelessWidget {
  const _WalletHistoryCard({required this.history});

  final List<TokenTransaction> history;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++)
            _WalletHistoryRow(
              tx: history[i],
              divider: i > 0,
            ),
        ],
      ),
    );
  }
}

class _WalletHistoryRow extends StatelessWidget {
  const _WalletHistoryRow({
    required this.tx,
    required this.divider,
  });

  final TokenTransaction tx;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final topup = tx.type == TokenTransactionType.topup;
    final date = tx.timestamp;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? const Border(top: BorderSide(color: BbV5Colors.hairSoft))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: topup ? BbV5Colors.brandSoft : BbV5Colors.terraSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                topup
                    ? LucideIcons.arrow_down_left
                    : LucideIcons.arrow_up_right,
                size: 15,
                color: topup ? BbV5Colors.brandDeep : BbV5Colors.accentDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bbV5DisplayStyle(fontSize: 12.5, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date.day}.${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${topup ? '+' : '−'}${tx.amount}',
              style: bbV5DisplayStyle(
                fontSize: 13,
                color: topup ? BbV5Colors.brandDeep : BbV5Colors.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TokensFocusScreen extends StatefulWidget {
  const TokensFocusScreen({super.key});

  @override
  State<TokensFocusScreen> createState() => _TokensFocusScreenState();
}

class _TokensFocusScreenState extends State<TokensFocusScreen> {
  int _activeTab = 1;

  @override
  Widget build(BuildContext context) {
    return _TokensPageScaffold(
      bottomNavLocation: AppRoute.tonight.path,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TokensHeader(
                    kicker: 'Рядом сегодня',
                    title: 'Что в',
                    accent: 'фокусе',
                    right: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BbV5IconButton(
                          icon: LucideIcons.search,
                          onPressed: () {},
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _AiPill(onTap: () {}),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FocusTabs(
                    activeIndex: _activeTab,
                    onChanged: (index) {
                      setState(() {
                        _activeTab = index;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _RaisedInfoCard(),
                  const SizedBox(height: AppSpacing.md),
                  _FocusEventCard(
                    label: 'В фокусе',
                    tokens: 1240,
                    avatarLabel: 'BR',
                    avatarAccent: null,
                    title: 'Brix · вино после работы',
                    meta: const [
                      _EventMeta(
                          icon: LucideIcons.map_pin,
                          text: 'Тверская, 12 · Brix'),
                      _EventMeta(
                          icon: LucideIcons.clock, text: 'Сегодня, 19:50'),
                    ],
                    going: '8 идут',
                    footer: 'Продвигается · Осталось 3 дня',
                    actionLabel: 'Пойду',
                    hot: true,
                    onAction: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FocusEventCard(
                    label: 'Продвигается',
                    tokens: 860,
                    avatarLabel: '🎤',
                    avatarAccent: null,
                    title: 'Иван Усович · сольник',
                    meta: const [
                      _EventMeta(
                          icon: LucideIcons.map_pin,
                          text: 'Stand-Up Store · Пятницкая, 71'),
                      _EventMeta(
                          icon: LucideIcons.calendar,
                          text: 'Пт, 25 апр · 20:00'),
                      _EventMeta(icon: LucideIcons.ticket, text: 'от 2500 ₽'),
                    ],
                    going: null,
                    footer: 'Продвигается · Осталось 2 дня',
                    actionLabel: 'Купить билет',
                    hot: true,
                    onAction: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FocusEventCard(
                    label: null,
                    tokens: null,
                    avatarLabel: '♟',
                    avatarAccent: BbV5Colors.sage,
                    title: 'Шахматы в парке',
                    meta: const [
                      _EventMeta(
                          icon: LucideIcons.map_pin,
                          text: 'Парк Горького · у фонтана'),
                      _EventMeta(
                          icon: LucideIcons.clock, text: 'Завтра, 12:00'),
                    ],
                    going: '6 идут',
                    footer: null,
                    actionLabel: 'Пойду',
                    onAction: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TokensTopUpScreen extends ConsumerStatefulWidget {
  const TokensTopUpScreen({super.key});

  @override
  ConsumerState<TokensTopUpScreen> createState() => _TokensTopUpScreenState();
}

class _TokensTopUpScreenState extends ConsumerState<TokensTopUpScreen> {
  int _selectedPlan = 2;
  bool _busy = false;
  String? _lastOrderId;

  @override
  Widget build(BuildContext context) {
    final packs = ref.watch(tokenPacksProvider);
    if (_selectedPlan >= packs.length) {
      _selectedPlan = 0;
    }
    final selected = packs[_selectedPlan];
    final plans = packs
        .map(
          (pack) => _TokenPlan(
            tokens: pack.total,
            price: '${pack.price} ₽',
            bonus: pack.bonus > 0 ? '+${pack.bonus} бонус' : null,
            badge: pack.best ? 'выгодно' : null,
          ),
        )
        .toList(growable: false);

    return _TokensPageScaffold(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 124),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TokensHeader(
                        kicker: 'Frendly Tokens',
                        title: 'Пополнить',
                        accent: 'баланс',
                        right: _BalanceBadge(onTap: () {
                          context.pushRoute(AppRoute.tokensBalance);
                        }),
                      ),
                      const SizedBox(height: 24),
                      const _TokenIntroCard(),
                      const SizedBox(height: AppSpacing.lg),
                      ...List.generate(plans.length, (index) {
                        final plan = plans[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == plans.length - 1 ? 0 : 8,
                          ),
                          child: _TokenPlanCard(
                            plan: plan,
                            selected: _selectedPlan == index,
                            onTap: () {
                              setState(() {
                                _selectedPlan = index;
                              });
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.lg),
                      const _PaymentCard(),
                      if (_lastOrderId != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : _checkPayment,
                            child: Text(
                              'Проверить оплату',
                              style: AppTextStyles.button.copyWith(
                                fontSize: 12,
                                color: BbV5Colors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const _PaymentHint(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: _FixedPrimaryButton(
              label: _busy
                  ? 'Открываем оплату...'
                  : 'Оплатить ${selected.price} ₽',
              onTap: _busy ? () {} : () => _buyPack(selected),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyPack(TokenPack pack) async {
    setState(() => _busy = true);
    try {
      final order =
          await ref.read(tokenWalletProvider.notifier).createTopUpPayment(pack);
      final paymentUrl = order.paymentUrl;
      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw StateError('Payment URL is empty');
      }
      if (!mounted || !context.mounted) {
        return;
      }
      setState(() => _lastOrderId = order.orderId);
      final opened =
          await ref.read(paymentLinkServiceProvider).openPaymentUrl(paymentUrl);
      if (!opened) {
        throw StateError('Payment URL was not opened');
      }
      if (!mounted || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вернись сюда после оплаты')),
      );
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось открыть оплату')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _checkPayment() async {
    final orderId = _lastOrderId;
    if (orderId == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final order =
          await ref.read(backendRepositoryProvider).checkPayment(orderId);
      if (!mounted || !context.mounted) {
        return;
      }
      if (order.isConfirmed) {
        await ref.read(tokenWalletProvider.notifier).refresh();
        if (!mounted || !context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Токены начислены')),
        );
      } else if (order.isFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оплата не прошла')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Платеж еще обрабатывается')),
        );
      }
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Платеж еще обрабатывается')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class TokensBalanceScreen extends StatelessWidget {
  const TokensBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TokensPageScaffold(
      bottomNavLocation: '/tokens',
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TokensHeader(
                    kicker: 'Frendly Tokens',
                    title: 'Баланс',
                    accent: 'токенов',
                    right: _BalanceBadge(
                      showPlus: true,
                      onTap: () => context.pushRoute(AppRoute.tokensTopUp),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _BalanceSummaryCard(
                    onTopUp: () => context.pushRoute(AppRoute.tokensTopUp),
                  ),
                  const SizedBox(height: 28),
                  const BbV5Kicker('На что можно тратить'),
                  const SizedBox(height: AppSpacing.md),
                  const _SpendOptionsCard(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(child: BbV5Kicker('Последние операции')),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: BbV5Colors.sageDeep,
                          textStyle: AppTextStyles.meta.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Смотреть все'),
                            SizedBox(width: 4),
                            Icon(LucideIcons.chevron_right, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _OperationsCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _TokensPromoCard(
                    onTap: () => context.pushRoute(AppRoute.tokensTopUp),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TokensBoostScreen extends StatefulWidget {
  const TokensBoostScreen({super.key});

  @override
  State<TokensBoostScreen> createState() => _TokensBoostScreenState();
}

class _TokensBoostScreenState extends State<TokensBoostScreen> {
  int _selectedBoost = 1;
  int _selectedDuration = 1;

  static const _boosts = [
    _BoostOption(
      icon: LucideIcons.arrow_up_right,
      title: 'Поднять в ленте',
      duration: '6 часов',
      tokens: 60,
    ),
    _BoostOption(
      icon: LucideIcons.target,
      title: 'Выделить на радаре',
      duration: '12 часов',
      tokens: 120,
    ),
    _BoostOption(
      icon: LucideIcons.sparkles,
      title: 'Показать в подборке рядом',
      duration: '24 часа',
      tokens: 250,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedBoost = _boosts[_selectedBoost];

    return _TokensPageScaffold(
      bottomNavLocation: '/tokens',
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TokensHeader(
                    kicker: 'Хост-панель',
                    title: 'Продвижение',
                    accent: 'встречи',
                    right: _BalanceBadge(
                      onTap: () => context.pushRoute(AppRoute.tokensBalance),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _BoostEventPreview(),
                  const SizedBox(height: 28),
                  Text(
                    'Выбери буст',
                    style: AppTextStyles.itemTitle.copyWith(
                      fontSize: 15,
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...List.generate(_boosts.length, (index) {
                    final boost = _boosts[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _boosts.length - 1 ? 0 : 10,
                      ),
                      child: _BoostOptionCard(
                        boost: boost,
                        selected: _selectedBoost == index,
                        onTap: () {
                          setState(() {
                            _selectedBoost = index;
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  _DurationSegmentedControl(
                    selected: _selectedDuration,
                    onChanged: (value) {
                      setState(() {
                        _selectedDuration = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _ReachCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _FixedPrimaryButton(
                    label: 'Запустить за ${selectedBoost.tokens}',
                    trailing: const _TinyCoin(size: 20),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokensPageScaffold extends StatelessWidget {
  const _TokensPageScaffold({
    required this.child,
    this.bottomNavLocation,
  });

  final Widget child;
  final String? bottomNavLocation;

  @override
  Widget build(BuildContext context) {
    final bottomNavLocation = this.bottomNavLocation;

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Stack(
              children: [
                Positioned.fill(child: child),
                if (bottomNavLocation != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: BbV5GlassBottomBar(
                      child: BbBottomNav(
                        location: bottomNavLocation,
                        onTap: (tab) => context.goRoute(tab.route),
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
}

class _TokensHeader extends StatelessWidget {
  const _TokensHeader({
    required this.kicker,
    required this.title,
    required this.accent,
    this.right,
  });

  final String kicker;
  final String title;
  final String accent;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: () => _popOrProfile(context),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BbV5Kicker(kicker),
                const SizedBox(height: 6),
                _DisplayTitle(title: title, accent: accent),
              ],
            ),
          ),
        ),
        if (right != null) ...[
          const SizedBox(width: AppSpacing.xs),
          right!,
        ],
      ],
    );
  }
}

class _DisplayTitle extends StatelessWidget {
  const _DisplayTitle({
    required this.title,
    required this.accent,
  });

  final String title;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.screenTitle.copyWith(
      fontSize: 25,
      height: 1.08,
      letterSpacing: 0,
      color: BbV5Colors.ink,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: title),
          const TextSpan(text: ' '),
          TextSpan(
            text: accent,
            style: base.copyWith(
              fontFamily: 'InstrumentSerif',
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}

class _AiPill extends StatelessWidget {
  const _AiPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftButton(
      onTap: onTap,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.sparkles, size: 15, color: BbV5Colors.terra),
          const SizedBox(width: 7),
          Text(
            'AI',
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BbV5Colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusTabs extends StatelessWidget {
  const _FocusTabs({
    required this.activeIndex,
    required this.onChanged,
  });

  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = ['Все', 'Продвигаются', 'Встречи', 'Афиша'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
            child: _SegmentChip(
              label: tabs[index],
              active: activeIndex == index,
              onTap: () => onChanged(index),
            ),
          );
        }),
      ),
    );
  }
}

class _RaisedInfoCard extends StatelessWidget {
  const _RaisedInfoCard();

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Row(
        children: [
          const _TokenIconBubble(size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Эти события подняты выше благодаря токенам',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BbV5Colors.inkMute,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Чем больше токенов, тем выше в ленте',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(LucideIcons.x, size: 18, color: BbV5Colors.inkMute),
        ],
      ),
    );
  }
}

class _FocusEventCard extends StatelessWidget {
  const _FocusEventCard({
    required this.label,
    required this.tokens,
    required this.avatarLabel,
    required this.avatarAccent,
    required this.title,
    required this.meta,
    required this.going,
    required this.footer,
    required this.actionLabel,
    required this.onAction,
    this.hot = false,
  });

  final String? label;
  final int? tokens;
  final String avatarLabel;
  final Color? avatarAccent;
  final String title;
  final List<_EventMeta> meta;
  final String? going;
  final String? footer;
  final String actionLabel;
  final VoidCallback onAction;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        hot ? BbV5Colors.accent.withValues(alpha: 0.55) : BbV5Colors.hair;

    return _SoftPanel(
      borderColor: borderColor,
      tint: hot ? BbV5Colors.terraSoft : null,
      padding: const EdgeInsets.all(12),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                _TokenStatusPill(label: label!)
              else
                const Spacer(),
              if (tokens != null) ...[
                const Spacer(),
                _TokensCountPill(tokens: tokens!),
              ] else
                _SoftButton(
                  height: 38,
                  width: 38,
                  onTap: () {},
                  child: const Icon(
                    LucideIcons.ellipsis,
                    size: 18,
                    color: BbV5Colors.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventAvatar(label: avatarLabel, accent: avatarAccent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 17,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...meta.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _MetaLine(icon: item.icon, text: item.text),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const _AvatarStack(),
                        if (going != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              going!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11.5,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: footer == null
                    ? const SizedBox.shrink()
                    : _CardFooter(label: footer!),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 126,
                child: BbV5PillButton(
                  label: actionLabel,
                  dark: hot,
                  height: 40,
                  fontSize: 12.5,
                  expanded: true,
                  onPressed: onAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventMeta {
  const _EventMeta({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;
}

class _TokenPlan {
  const _TokenPlan({
    required this.tokens,
    required this.price,
    required this.bonus,
    required this.badge,
  });

  final int tokens;
  final String price;
  final String? bonus;
  final String? badge;
}

class _TokenIntroCard extends StatelessWidget {
  const _TokenIntroCard();

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.all(22),
      radius: 24,
      child: Row(
        children: [
          const _TokenCoin(size: 68),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Токены помогают продвигать встречи и события',
                  style: AppTextStyles.itemTitle.copyWith(
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Используй токены, чтобы чаще заметили твои события и знакомства.',
                  style: AppTextStyles.bodySoft.copyWith(
                    color: BbV5Colors.inkMute,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenPlanCard extends StatelessWidget {
  const _TokenPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _TokenPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      radius: 22,
      borderColor: selected ? BbV5Colors.accent : BbV5Colors.hair,
      child: Row(
        children: [
          const _TokenCoin(size: 50),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTokens(plan.tokens),
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 26,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'токенов',
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.inkMute,
                  ),
                ),
                if (plan.bonus != null) ...[
                  const SizedBox(height: 8),
                  _MiniTag(
                    label: plan.bonus!,
                    color: BbV5Colors.sageDeep,
                    background: BbV5Colors.brandSoft.withValues(alpha: 0.45),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (plan.badge != null) ...[
                  _MiniTag(
                    label: plan.badge!,
                    color: BbV5Colors.terra,
                    background: BbV5Colors.terraSoft.withValues(alpha: 0.32),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          plan.price,
                          maxLines: 1,
                          style: AppTextStyles.cardTitle.copyWith(
                            fontSize: selected ? 19 : 18,
                            letterSpacing: 0,
                            color: selected ? BbV5Colors.terra : BbV5Colors.ink,
                          ),
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const _RoundCheck(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard();

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Способ оплаты',
            style: AppTextStyles.itemTitle.copyWith(fontSize: 14.5),
          ),
          const SizedBox(height: AppSpacing.md),
          const _PaymentMethodPill(
            active: true,
            label: 'T-Bank Checkout',
            icon: LucideIcons.credit_card,
          ),
        ],
      ),
    );
  }
}

class _PaymentHint extends StatelessWidget {
  const _PaymentHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.shield_check,
              size: 28, color: BbV5Colors.terra),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Покупка активирует токены сразу',
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BbV5Colors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Средства списываются с учётом комиссии вашего банка.',
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({required this.onTopUp});

  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.all(22),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _TokenCoin(size: 72),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1 240',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 36,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'доступно',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 16,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '≈ 1240₽ · 1 токен = 1₽',
                      style: AppTextStyles.meta.copyWith(
                        fontSize: 12.5,
                        color: BbV5Colors.inkMute,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: BbV5PillButton(
                  label: 'Пополнить',
                  icon: LucideIcons.plus,
                  dark: true,
                  height: 44,
                  fontSize: 13,
                  expanded: true,
                  onPressed: onTopUp,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: BbV5PillButton(
                  label: 'История',
                  icon: LucideIcons.history,
                  height: 44,
                  fontSize: 13,
                  expanded: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendOptionsCard extends StatelessWidget {
  const _SpendOptionsCard();

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: LucideIcons.zap, title: 'Продвижение', subtitle: 'встреч'),
      (
        icon: LucideIcons.arrow_up_right,
        title: 'Поднятие',
        subtitle: 'в ленте'
      ),
      (icon: LucideIcons.target, title: 'Выделение', subtitle: 'на радаре'),
    ];

    return _SoftPanel(
      padding: const EdgeInsets.symmetric(vertical: 18),
      radius: 22,
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: index == 0
                      ? BorderSide.none
                      : const BorderSide(color: BbV5Colors.hair),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SoftIcon(icon: item.icon, size: 42),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle.copyWith(
                        fontSize: 12.5,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11.5,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      _OperationData(
        amount: '+500',
        title: 'Покупка пакета «Старт»',
        date: '6 мая · 14:32',
        positive: true,
      ),
      _OperationData(
        amount: '-120',
        title: 'Продвижение встречи Brix',
        date: '6 мая · 12:10',
        positive: false,
      ),
      _OperationData(
        amount: '-60',
        title: 'Поднятие маршрута',
        date: '5 мая · 18:05',
        positive: false,
      ),
    ];

    return _SoftPanel(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: index == 0
                    ? BorderSide.none
                    : const BorderSide(color: BbV5Colors.hairSoft),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  _AmountBubble(item: item),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.itemTitle.copyWith(
                            fontSize: 13.5,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.date,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11.5,
                            color: BbV5Colors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    item.amount,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 16,
                      letterSpacing: 0,
                      color: item.positive
                          ? BbV5Colors.sageDeep
                          : BbV5Colors.terra,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const _TinyCoin(size: 17),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _OperationData {
  const _OperationData({
    required this.amount,
    required this.title,
    required this.date,
    required this.positive,
  });

  final String amount;
  final String title;
  final String date;
  final bool positive;
}

class _TokensPromoCard extends StatelessWidget {
  const _TokensPromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Row(
        children: [
          const _TokenCoin(size: 76),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Токены помогают\n'),
                      TextSpan(
                        text: 'продвигать встречи\n',
                        style: AppTextStyles.cardTitle.copyWith(
                          fontFamily: 'InstrumentSerif',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                          fontSize: 19,
                          letterSpacing: 0,
                        ),
                      ),
                      const TextSpan(text: 'и события'),
                    ],
                  ),
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 16,
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Используй токены, чтобы тебя заметили чаще',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 118,
            child: BbV5PillButton(
              label: 'Купить токены',
              dark: true,
              height: 42,
              fontSize: 12,
              expanded: true,
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostEventPreview extends StatelessWidget {
  const _BoostEventPreview();

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2A1813),
                    Color(0xFFC98A59),
                    Color(0xFF3C221A),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: const Text('🍷', style: TextStyle(fontSize: 46)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brix · вино после работы',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 17,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _MetaLine(
                  icon: LucideIcons.map_pin,
                  text: 'Покровка 12 · сегодня 20:00',
                ),
                const SizedBox(height: AppSpacing.md),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TinyInfoPill(label: 'спокойно'),
                    _TinyInfoPill(label: 'вино'),
                    _TinyInfoPill(label: '8 идут', icon: LucideIcons.users),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostOption {
  const _BoostOption({
    required this.icon,
    required this.title,
    required this.duration,
    required this.tokens,
  });

  final IconData icon;
  final String title;
  final String duration;
  final int tokens;
}

class _BoostOptionCard extends StatelessWidget {
  const _BoostOptionCard({
    required this.boost,
    required this.selected,
    required this.onTap,
  });

  final _BoostOption boost;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 20,
      borderColor: selected ? BbV5Colors.accent : BbV5Colors.hair,
      child: Row(
        children: [
          _SoftIcon(
            icon: boost.icon,
            size: 54,
            selected: selected,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  boost.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.itemTitle.copyWith(
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  boost.duration,
                  style: AppTextStyles.bodySoft.copyWith(
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${boost.tokens}',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 18,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const _TinyCoin(size: 20),
                ],
              ),
              Text(
                'токенов',
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          selected ? const _RoundCheck() : const _EmptyCheck(),
        ],
      ),
    );
  }
}

class _DurationSegmentedControl extends StatelessWidget {
  const _DurationSegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const values = ['6ч', '12ч', '24ч'];

    return _SoftPanel(
      padding: const EdgeInsets.all(3),
      radius: BbV5Radii.pill,
      child: Row(
        children: List.generate(values.length, (index) {
          final active = selected == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? BbV5Colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  boxShadow: active ? BbV5Shadows.pill : null,
                ),
                child: Text(
                  values[index],
                  style: AppTextStyles.button.copyWith(
                    fontSize: 16,
                    color: active ? BbV5Colors.paperHi : BbV5Colors.inkMute,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ReachCard extends StatelessWidget {
  const _ReachCard();

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.all(20),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ожидаемый охват',
                style: AppTextStyles.itemTitle.copyWith(fontSize: 14.5),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(LucideIcons.info, size: 15, color: BbV5Colors.inkMute),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Expanded(
                child: _ReachMetric(
                  icon: LucideIcons.eye,
                  value: '+180',
                  label: 'показов',
                ),
              ),
              Container(width: 1, height: 44, color: BbV5Colors.hair),
              const Expanded(
                child: _ReachMetric(
                  icon: LucideIcons.users,
                  value: '+12',
                  label: 'переходов',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReachMetric extends StatelessWidget {
  const _ReachMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SoftIcon(icon: icon, size: 46, color: BbV5Colors.sageDeep),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: 20,
                  letterSpacing: 0,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: BbV5Colors.inkMute,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.borderColor = BbV5Colors.hair,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decorated = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BbV5Colors.paperHi,
              Color(0xFFF3E7D6),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
          boxShadow: BbV5Shadows.card,
        ),
        child: Stack(
          children: [
            if (tint != null)
              Positioned(
                right: -70,
                top: -70,
                width: 190,
                height: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tint!.withValues(alpha: 0.38),
                        blurRadius: 62,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return decorated;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: decorated,
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.child,
    required this.onTap,
    this.height,
    this.width,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback onTap;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(
              fontSize: 13,
              color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _TokenStatusPill extends StatelessWidget {
  const _TokenStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.terra.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: BbV5Colors.terra),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: BbV5Colors.terra,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokensCountPill extends StatelessWidget {
  const _TokensCountPill({required this.tokens});

  final int tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TinyCoin(size: 22),
          const SizedBox(width: 7),
          Text(
            '$tokens',
            style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({
    this.showPlus = false,
    this.onTap,
  });

  final bool showPlus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftButton(
      onTap: onTap ?? () {},
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TinyCoin(size: 24),
          const SizedBox(width: 7),
          Text(
            _formatTokens(_tokenBalance),
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 13.5,
              letterSpacing: 0,
            ),
          ),
          if (showPlus) ...[
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: BbV5Colors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.plus,
                size: 18,
                color: BbV5Colors.paperHi,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TokenIconBubble extends StatelessWidget {
  const _TokenIconBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: const Icon(LucideIcons.sparkles, color: BbV5Colors.terra),
    );
  }
}

class _TokenCoin extends StatelessWidget {
  const _TokenCoin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE29B72),
            Color(0xFFC9704A),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3AC9704A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x99FFFFFF),
            blurRadius: 1,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Icon(
        LucideIcons.sparkles,
        color: Colors.white,
        size: size * 0.45,
      ),
    );
  }
}

class _TinyCoin extends StatelessWidget {
  const _TinyCoin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: BbV5Colors.accent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        LucideIcons.sparkles,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

class _EventAvatar extends StatelessWidget {
  const _EventAvatar({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final isEmoji = label.runes.length > 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            shape: BoxShape.circle,
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Text(
            label,
            style: isEmoji
                ? const TextStyle(fontSize: 25)
                : AppTextStyles.cardTitle.copyWith(
                    fontSize: 17,
                    letterSpacing: 0,
                  ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: 5,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: accent ?? BbV5Colors.terra,
              shape: BoxShape.circle,
              border: Border.all(color: BbV5Colors.paperHi, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: BbV5Colors.inkMute),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: BbV5Colors.inkMute,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF5B5148),
      const Color(0xFFD4A081),
      const Color(0xFFE2CDBB),
      const Color(0xFF31526A),
    ];

    return SizedBox(
      width: 94,
      height: 28,
      child: Stack(
        children: [
          ...List.generate(colors.length, (index) {
            return Positioned(
              left: index * 18.0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[index],
                  border: Border.all(color: BbV5Colors.paperHi, width: 2),
                ),
              ),
            );
          }),
          Positioned(
            left: colors.length * 18.0,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BbV5Colors.paper,
                border: Border.all(color: BbV5Colors.hair),
              ),
              child: Text(
                '+6',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: BbV5Colors.inkMute,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BbV5Colors.hairSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 14, color: BbV5Colors.terra),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11.5,
                  color: BbV5Colors.inkMute,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodPill extends StatelessWidget {
  const _PaymentMethodPill({
    required this.active,
    required this.label,
    required this.icon,
  });

  final bool active;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? BbV5Colors.ink : BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: active ? BbV5Colors.ink : BbV5Colors.hair),
        boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.meta.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? BbV5Colors.paperHi : BbV5Colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundCheck extends StatelessWidget {
  const _RoundCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: BbV5Colors.accent,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        LucideIcons.check,
        size: 18,
        color: BbV5Colors.paperHi,
      ),
    );
  }
}

class _EmptyCheck extends StatelessWidget {
  const _EmptyCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.hair),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hairSoft),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AmountBubble extends StatelessWidget {
  const _AmountBubble({required this.item});

  final _OperationData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: item.positive
            ? BbV5Colors.brandSoft.withValues(alpha: 0.38)
            : BbV5Colors.terraSoft.withValues(alpha: 0.28),
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.hairSoft),
      ),
      child: Text(
        item.amount,
        style: AppTextStyles.itemTitle.copyWith(
          fontSize: 12.5,
          letterSpacing: 0,
          color: item.positive ? BbV5Colors.sageDeep : BbV5Colors.terra,
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({
    required this.icon,
    required this.size,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final double size;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? (selected ? BbV5Colors.terra : BbV5Colors.terra);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected
            ? BbV5Colors.terraSoft.withValues(alpha: 0.32)
            : BbV5Colors.paper,
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.hairSoft),
      ),
      child: Icon(icon, size: size * 0.42, color: iconColor),
    );
  }
}

class _TinyInfoPill extends StatelessWidget {
  const _TinyInfoPill({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: BbV5Colors.inkSoft),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: BbV5Colors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedPrimaryButton extends StatelessWidget {
  const _FixedPrimaryButton({
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BbV5Colors.accent,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            boxShadow: BbV5Shadows.ink,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    fontSize: 16,
                    color: BbV5Colors.paperHi,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTokens(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    final fromEnd = raw.length - index;
    buffer.write(raw[index]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}

void _popOrProfile(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }

  context.goRoute(AppRoute.profile);
}
