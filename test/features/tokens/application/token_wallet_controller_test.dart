import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/payments.dart';
import 'package:big_break_mobile/shared/models/token_wallet.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog fallback keeps backend product prices', () {
    expect(tokenPacks.map((pack) => pack.total), [100, 350, 900, 2700]);
    expect(tokenPacks.map((pack) => pack.price), [199, 499, 999, 2499]);
    expect(promoOptions.map((option) => option.cost), [80, 200, 500]);
  });

  test('refresh loads wallet from backend', () async {
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        backendRepositoryProvider.overrideWith(_FakeBackendRepository.new),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(tokenWalletProvider.notifier);
    await controller.refresh();

    expect(controller.state.balance, 350);
    expect(controller.state.history.single.amount, 350);
    expect(controller.state.isPromoted('mc1'), isTrue);
  });

  test('promotion spends tokens through backend wallet', () async {
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        backendRepositoryProvider.overrideWith(_FakeBackendRepository.new),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(tokenWalletProvider.notifier);
    await controller.refresh();
    final ok = await controller.promote('mc2', promoOptions.first);

    expect(ok, isTrue);
    expect(controller.state.balance, 270);
    expect(controller.state.isPromoted('mc2'), isTrue);
  });

  test('top up creates a backend payment order', () async {
    late _FakeBackendRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _FakeBackendRepository(ref);
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(tokenWalletProvider.notifier);
    final order = await controller.createTopUpPayment(tokenPacks[1]);

    expect(order.orderId, 'order-1');
    expect(repository.lastProductKind, 'tokens');
    expect(repository.lastProductId, 'p2');
  });
}

class _FakeBackendRepository extends BackendRepository {
  _FakeBackendRepository(Ref ref) : super(ref: ref, dio: Dio());

  String? lastProductKind;
  String? lastProductId;

  @override
  Future<TokenWalletData> fetchTokenWallet() async {
    return TokenWalletData(
      balance: 350,
      history: [
        TokenWalletTransactionData(
          id: 'tx-1',
          type: 'topup',
          amount: 350,
          note: 'Пополнение токенов',
          timestamp: DateTime(2026, 5, 13),
        ),
      ],
      promoted: {
        'mc1': DateTime.now().add(const Duration(hours: 1)),
      },
      promoOptions: const [],
    );
  }

  @override
  Future<TokenWalletData> promoteWithTokens({
    required String targetKind,
    required String targetId,
    required String optionId,
  }) async {
    return TokenWalletData(
      balance: 270,
      history: const [],
      promoted: {
        targetId: DateTime.now().add(const Duration(hours: 24)),
      },
      promoOptions: const [],
    );
  }

  @override
  Future<PaymentOrderData> initPayment({
    required String productKind,
    required String productId,
  }) async {
    lastProductKind = productKind;
    lastProductId = productId;
    return const PaymentOrderData(
      orderId: 'order-1',
      paymentId: 'payment-1',
      paymentUrl: 'https://pay.test/form',
      status: 'pending',
    );
  }
}
