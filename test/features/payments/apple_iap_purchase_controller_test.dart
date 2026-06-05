import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/payments/application/apple_iap_purchase_controller.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('buys token pack as Apple consumable and confirms it on backend',
      () async {
    final gateway = _FakeAppleIapGateway(
      product: const AppleIapStoreProduct(
        id: 'frendly.tokens.p2',
        title: '350 FT',
        price: '499 ₽',
      ),
      purchase: const AppleIapPurchaseResult(
        productId: 'frendly.tokens.p2',
        transactionId: 'tx-1',
        verificationData: 'signed-transaction',
        status: AppleIapPurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
    );
    late AppleIapPurchaseConfirmation confirmation;
    final controller = AppleIapPurchaseController(
      gateway: gateway,
      confirmPurchase: (input) async {
        confirmation = input;
        return const PaymentOrderData(
          orderId: 'apple_tx-1',
          status: 'confirmed',
          productKind: 'tokens',
          productId: 'p2',
          paymentId: 'tx-1',
        );
      },
    );

    final order = await controller.buy(
      const AppleIapProductPurchase(
        productKind: 'tokens',
        productId: 'p2',
        appleProductId: 'frendly.tokens.p2',
      ),
    );

    expect(order.status, 'confirmed');
    expect(gateway.lastConsumable, isTrue);
    expect(gateway.completedTransactionId, 'tx-1');
    expect(confirmation.productKind, 'tokens');
    expect(confirmation.productId, 'p2');
    expect(confirmation.appleProductId, 'frendly.tokens.p2');
    expect(confirmation.transactionId, 'tx-1');
    expect(confirmation.verificationData, 'signed-transaction');
  });

  test('buys subscription as Apple non consumable and confirms it on backend',
      () async {
    final gateway = _FakeAppleIapGateway(
      product: const AppleIapStoreProduct(
        id: 'frendly.plus.year',
        title: 'Frendly+ год',
        price: '4 788 ₽',
      ),
      purchase: const AppleIapPurchaseResult(
        productId: 'frendly.plus.year',
        transactionId: 'tx-year',
        verificationData: 'signed-year',
        status: AppleIapPurchaseStatus.purchased,
        pendingCompletePurchase: false,
      ),
    );
    final controller = AppleIapPurchaseController(
      gateway: gateway,
      confirmPurchase: (_) async {
        return const PaymentOrderData(
          orderId: 'apple_tx-year',
          status: 'confirmed',
          productKind: 'subscription',
          productId: 'year',
          paymentId: 'tx-year',
        );
      },
    );

    await controller.buy(
      const AppleIapProductPurchase(
        productKind: 'subscription',
        productId: 'year',
        appleProductId: 'frendly.plus.year',
      ),
    );

    expect(gateway.lastConsumable, isFalse);
    expect(gateway.completedTransactionId, isNull);
  });

  test('fails before purchase when App Store product id is missing', () async {
    final gateway = _FakeAppleIapGateway();
    final controller = AppleIapPurchaseController(
      gateway: gateway,
      confirmPurchase: (_) async {
        fail('backend must not be called');
      },
    );

    await expectLater(
      controller.buy(
        const AppleIapProductPurchase(
          productKind: 'tokens',
          productId: 'p1',
          appleProductId: '',
        ),
      ),
      throwsA(
        isA<AppleIapPurchaseException>().having(
          (error) => error.code,
          'code',
          'missing_apple_product_id',
        ),
      ),
    );
  });
}

class _FakeAppleIapGateway implements AppleIapGateway {
  _FakeAppleIapGateway({this.product, this.purchase});

  final AppleIapStoreProduct? product;
  final AppleIapPurchaseResult? purchase;
  bool? lastConsumable;
  String? completedTransactionId;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AppleIapStoreProduct?> findProduct(String productId) async => product;

  @override
  Future<AppleIapPurchaseResult> buy(
    AppleIapStoreProduct product, {
    required bool consumable,
  }) async {
    lastConsumable = consumable;
    return purchase!;
  }

  @override
  Future<void> complete(AppleIapPurchaseResult purchase) async {
    completedTransactionId = purchase.transactionId;
  }
}
