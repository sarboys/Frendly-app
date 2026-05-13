import 'package:big_break_mobile/features/paywall/presentation/paywall_screen.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paywall buys Frendly Plus with tokens', (tester) async {
    final walletController = _TestTokenWalletController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenWalletProvider.overrideWith((ref) => walletController),
          subscriptionPlansProvider.overrideWith((ref) async => _plans),
          subscriptionStateProvider.overrideWith(
            (ref) async => const SubscriptionStateData(
              plan: null,
              status: 'inactive',
              startedAt: null,
              renewsAt: null,
              trialEndsAt: null,
            ),
          ),
        ],
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Оплатить 4788 токенов'), findsOneWidget);

    await tester.tap(find.text('Оплатить 4788 токенов'));
    await tester.pumpAndSettle();

    expect(walletController.subscribeCalls, ['year']);
    expect(find.text('Frendly+ активирован'), findsOneWidget);
  });
}

const _plans = [
  SubscriptionPlanData(
    id: 'month',
    label: 'Месячный',
    priceRub: 799,
    priceMonthlyRub: 799,
    tokenCost: 799,
    tokenMonthlyCost: 799,
    trialDays: 0,
    badge: null,
  ),
  SubscriptionPlanData(
    id: 'year',
    label: 'Годовой',
    priceRub: 4788,
    priceMonthlyRub: 399,
    tokenCost: 4788,
    tokenMonthlyCost: 399,
    trialDays: 0,
    badge: '-50%',
  ),
];

class _TestTokenWalletController extends TokenWalletController {
  _TestTokenWalletController() : super(null);

  final List<String> subscribeCalls = [];

  @override
  Future<SubscriptionStateData> subscribeWithTokens(String plan) async {
    subscribeCalls.add(plan);
    return SubscriptionStateData(
      plan: plan,
      status: 'active',
      startedAt: DateTime(2026, 5, 13),
      renewsAt: DateTime(2027, 5, 13),
      trialEndsAt: null,
    );
  }
}
