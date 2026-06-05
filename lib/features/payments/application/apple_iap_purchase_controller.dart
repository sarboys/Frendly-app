import 'package:mobile2/shared/models/backend_models.dart';

typedef ConfirmAppleIapPurchase = Future<PaymentOrderData> Function(
  AppleIapPurchaseConfirmation input,
);

class AppleIapPurchaseController {
  AppleIapPurchaseController({
    required AppleIapGateway gateway,
    required ConfirmAppleIapPurchase confirmPurchase,
  })  : _gateway = gateway,
        _confirmPurchase = confirmPurchase;

  final AppleIapGateway _gateway;
  final ConfirmAppleIapPurchase _confirmPurchase;

  Future<PaymentOrderData> buy(AppleIapProductPurchase request) async {
    final appleProductId = request.appleProductId.trim();
    if (appleProductId.isEmpty) {
      throw const AppleIapPurchaseException(
        'missing_apple_product_id',
        'App Store product id is missing',
      );
    }
    if (!await _gateway.isAvailable()) {
      throw const AppleIapPurchaseException(
        'app_store_unavailable',
        'App Store payments are unavailable',
      );
    }

    final product = await _gateway.findProduct(appleProductId);
    if (product == null) {
      throw AppleIapPurchaseException(
        'apple_product_not_found',
        'App Store product not found: $appleProductId',
      );
    }

    final purchase = await _gateway.buy(
      product,
      consumable: request.productKind == 'tokens',
    );
    if (purchase.status == AppleIapPurchaseStatus.canceled) {
      throw const AppleIapPurchaseException(
        'purchase_canceled',
        'Purchase was canceled',
      );
    }
    if (purchase.status == AppleIapPurchaseStatus.pending) {
      throw const AppleIapPurchaseException(
        'purchase_pending',
        'Purchase is pending',
      );
    }
    if (purchase.status == AppleIapPurchaseStatus.error) {
      throw const AppleIapPurchaseException(
        'purchase_failed',
        'Purchase failed',
      );
    }
    if (purchase.productId != appleProductId) {
      throw const AppleIapPurchaseException(
        'purchase_product_mismatch',
        'Purchase product does not match request',
      );
    }

    final order = await _confirmPurchase(
      AppleIapPurchaseConfirmation(
        productKind: request.productKind,
        productId: request.productId,
        appleProductId: appleProductId,
        transactionId: purchase.transactionId,
        verificationData: purchase.verificationData,
      ),
    );
    if (purchase.pendingCompletePurchase) {
      await _gateway.complete(purchase);
    }
    return order;
  }
}

abstract class AppleIapGateway {
  Future<bool> isAvailable();

  Future<AppleIapStoreProduct?> findProduct(String productId);

  Future<AppleIapPurchaseResult> buy(
    AppleIapStoreProduct product, {
    required bool consumable,
  });

  Future<void> complete(AppleIapPurchaseResult purchase);
}

class AppleIapProductPurchase {
  const AppleIapProductPurchase({
    required this.productKind,
    required this.productId,
    required this.appleProductId,
  });

  final String productKind;
  final String productId;
  final String appleProductId;
}

class AppleIapPurchaseConfirmation {
  const AppleIapPurchaseConfirmation({
    required this.productKind,
    required this.productId,
    required this.appleProductId,
    required this.transactionId,
    required this.verificationData,
  });

  final String productKind;
  final String productId;
  final String appleProductId;
  final String transactionId;
  final String verificationData;
}

class AppleIapStoreProduct {
  const AppleIapStoreProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;
  final String price;
}

class AppleIapPurchaseResult {
  const AppleIapPurchaseResult({
    required this.productId,
    required this.transactionId,
    required this.verificationData,
    required this.status,
    required this.pendingCompletePurchase,
  });

  final String productId;
  final String transactionId;
  final String verificationData;
  final AppleIapPurchaseStatus status;
  final bool pendingCompletePurchase;
}

enum AppleIapPurchaseStatus {
  purchased,
  restored,
  pending,
  canceled,
  error,
}

class AppleIapPurchaseException implements Exception {
  const AppleIapPurchaseException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AppleIapPurchaseException($code, $message)';
}
