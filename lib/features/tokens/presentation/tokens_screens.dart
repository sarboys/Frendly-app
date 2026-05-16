import 'package:big_break_mobile/app/core/device/payment_link_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/payments/application/payment_return_controller.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/widgets/bb_bottom_nav.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _popOrProfile(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.goRoute(AppRoute.profile);
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
