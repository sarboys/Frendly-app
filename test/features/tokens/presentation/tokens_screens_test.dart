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
  testWidgets('wallet screen renders token balance and top up content',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    await tester.pumpWidget(_wrap(const WalletScreen()));
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
