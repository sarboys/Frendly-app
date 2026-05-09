import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('wallet starts from the v5 demo balance', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = TokenWalletController(prefs);

    expect(controller.state.balance, 250);
    expect(controller.state.history, isEmpty);
    expect(tokenPacks, hasLength(4));
    expect(promoOptions.map((option) => option.cost), [80, 200, 500]);
  });

  test('top up adds tokens with bonus and stores a history row', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = TokenWalletController(prefs);

    await controller.topUp(tokenPacks[1]);

    expect(controller.state.balance, 600);
    expect(controller.state.history.single.type, TokenTransactionType.topup);
    expect(controller.state.history.single.amount, 350);
    expect(controller.state.history.single.note, 'Пополнение · Популярный');
  });

  test('promotion spends tokens and marks meetup as promoted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = TokenWalletController(prefs);

    final ok = await controller.promote('mc2', promoOptions.first);

    expect(ok, isTrue);
    expect(controller.state.balance, 170);
    expect(controller.state.isPromoted('mc2'), isTrue);
    expect(controller.state.history.single.type, TokenTransactionType.spend);
    expect(controller.state.history.single.amount, 80);
  });

  test('promotion returns false when balance is not enough', () async {
    SharedPreferences.setMockInitialValues({'frendly_v5_tokens': 20});
    final prefs = await SharedPreferences.getInstance();
    final controller = TokenWalletController(prefs);

    final ok = await controller.promote('mc3', promoOptions.first);

    expect(ok, isFalse);
    expect(controller.state.balance, 20);
    expect(controller.state.isPromoted('mc3'), isFalse);
    expect(controller.state.history, isEmpty);
  });
}
