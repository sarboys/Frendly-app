import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mobile2/features/payments/application/apple_iap_purchase_controller.dart';

class InAppPurchaseAppleIapGateway implements AppleIapGateway {
  InAppPurchaseAppleIapGateway({InAppPurchase? inAppPurchase})
      : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  @override
  Future<bool> isAvailable() {
    return _inAppPurchase.isAvailable();
  }

  @override
  Future<AppleIapStoreProduct?> findProduct(String productId) async {
    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) {
      return null;
    }
    final details = response.productDetails.firstWhere(
      (item) => item.id == productId,
      orElse: () => response.productDetails.first,
    );
    return _InAppPurchaseStoreProduct(details);
  }

  @override
  Future<AppleIapPurchaseResult> buy(
    AppleIapStoreProduct product, {
    required bool consumable,
  }) async {
    final details = product is _InAppPurchaseStoreProduct
        ? product.details
        : (await findProduct(product.id) as _InAppPurchaseStoreProduct?)
            ?.details;
    if (details == null) {
      throw AppleIapPurchaseException(
        'apple_product_not_found',
        'App Store product not found: ${product.id}',
      );
    }

    final completer = Completer<AppleIapPurchaseResult>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _inAppPurchase.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          if (purchase.productID != product.id) {
            continue;
          }
          final result = _mapPurchase(purchase);
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(
            AppleIapPurchaseException('purchase_failed', error.toString()),
          );
        }
      },
    );

    final purchaseParam = PurchaseParam(productDetails: details);
    final started = consumable
        ? await _inAppPurchase.buyConsumable(
            purchaseParam: purchaseParam,
            autoConsume: true,
          )
        : await _inAppPurchase.buyNonConsumable(
            purchaseParam: purchaseParam,
          );
    if (!started) {
      await subscription.cancel();
      throw const AppleIapPurchaseException(
        'purchase_not_started',
        'Purchase was not started',
      );
    }

    try {
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw const AppleIapPurchaseException(
            'purchase_timeout',
            'Purchase timed out',
          );
        },
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> complete(AppleIapPurchaseResult purchase) async {
    final raw = purchase is _InAppPurchaseResult ? purchase.details : null;
    if (raw != null) {
      await _inAppPurchase.completePurchase(raw);
    }
  }

  AppleIapPurchaseResult _mapPurchase(PurchaseDetails purchase) {
    return _InAppPurchaseResult(
      details: purchase,
      productId: purchase.productID,
      transactionId: purchase.purchaseID ?? '',
      verificationData: purchase.verificationData.serverVerificationData,
      pendingCompletePurchase: purchase.pendingCompletePurchase,
      status: switch (purchase.status) {
        PurchaseStatus.purchased => AppleIapPurchaseStatus.purchased,
        PurchaseStatus.restored => AppleIapPurchaseStatus.restored,
        PurchaseStatus.pending => AppleIapPurchaseStatus.pending,
        PurchaseStatus.canceled => AppleIapPurchaseStatus.canceled,
        PurchaseStatus.error => AppleIapPurchaseStatus.error,
      },
    );
  }
}

class _InAppPurchaseStoreProduct extends AppleIapStoreProduct {
  _InAppPurchaseStoreProduct(this.details)
      : super(id: details.id, title: details.title, price: details.price);

  final ProductDetails details;
}

class _InAppPurchaseResult extends AppleIapPurchaseResult {
  const _InAppPurchaseResult({
    required this.details,
    required super.productId,
    required super.transactionId,
    required super.verificationData,
    required super.status,
    required super.pendingCompletePurchase,
  });

  final PurchaseDetails details;
}
