import 'package:big_break_mobile/features/tokens/presentation/tokens_screens.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {int walletBalance = 0}) {
  return ProviderScope(
    overrides: [
      tokenWalletProvider
          .overrideWith((ref) => _TestTokenWalletController(walletBalance)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('token screens render their main content', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const TokensFocusScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Что в'), findsOneWidget);
    expect(find.textContaining('фокусе'), findsWidgets);
    expect(find.text('Brix · вино после работы'), findsOneWidget);

    await tester.pumpWidget(_wrap(const TokensTopUpScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Пополнить'), findsOneWidget);
    expect(find.textContaining('баланс'), findsWidgets);
    expect(find.text('Оплатить 999 ₽'), findsOneWidget);

    await tester.pumpWidget(_wrap(const TokensBalanceScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Баланс'), findsOneWidget);
    expect(find.textContaining('токенов'), findsWidgets);
    expect(find.text('Последние операции'), findsOneWidget);

    await tester.pumpWidget(_wrap(const TokensBoostScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Продвижение'), findsWidgets);
    expect(find.textContaining('встречи'), findsWidgets);
    expect(find.text('Запустить за 120'), findsOneWidget);

    await tester.pumpWidget(_wrap(const WalletScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Кошелёк'), findsOneWidget);
    expect(find.textContaining('Frendly'), findsWidgets);
    expect(find.text('Купить пакет'), findsOneWidget);
    expect(find.text('На что тратить'), findsOneWidget);

    final exception = tester.takeException();
    expect(exception, isNull);
  });

  testWidgets('tokens balance screen reads backend wallet state', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const TokensBalanceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsWidgets);
    expect(find.text('1 240'), findsNothing);
    expect(find.textContaining('1240'), findsNothing);
  });
}

class _TestTokenWalletController extends TokenWalletController {
  _TestTokenWalletController(int balance) : super(null) {
    state = TokenWalletState(
      balance: balance,
      promoted: const {},
      history: const [],
      loading: false,
    );
  }
}
