import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentReturnStateProvider =
    StateProvider<PaymentReturnState?>((ref) => null);

final paymentReturnControllerProvider = Provider<PaymentReturnController>(
  (ref) => PaymentReturnController(ref),
);

class PaymentReturnState {
  const PaymentReturnState({
    required this.orderId,
    required this.status,
    required this.productKind,
  });

  final String orderId;
  final String status;
  final String productKind;

  bool get confirmed => status == 'confirmed';
  bool get failed =>
      status == 'failed' || status == 'expired' || status == 'canceled';
}

class PaymentReturnController {
  PaymentReturnController(this._ref);

  final Ref _ref;

  Future<PaymentReturnState?> handleUri(Uri uri) async {
    if (uri.scheme != 'frendly' || uri.host != 'payment') {
      return null;
    }
    final result = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    final orderId = uri.queryParameters['orderId'];
    final returnedProductKind = uri.queryParameters['productKind'] ?? '';
    if (orderId == null || orderId.isEmpty) {
      return null;
    }

    if (result != 'success' && result != 'fail') {
      return null;
    }

    if (result == 'fail') {
      final state = PaymentReturnState(
        orderId: orderId,
        status: 'failed',
        productKind: returnedProductKind,
      );
      _ref.read(paymentReturnStateProvider.notifier).state = state;
      return state;
    }

    try {
      await _ref.read(authBootstrapProvider.future);
      final repository = _ref.read(backendRepositoryProvider);
      final order = await repository.checkPayment(orderId);
      _ref.invalidate(subscriptionStateProvider);
      _ref.invalidate(paymentCatalogProvider);
      _ref.read(tokenWalletProvider.notifier).refresh();
      final state = PaymentReturnState(
        orderId: orderId,
        status: order.status,
        productKind: order.productKind.isNotEmpty
            ? order.productKind
            : returnedProductKind,
      );
      _ref.read(paymentReturnStateProvider.notifier).state = state;
      return state;
    } catch (_) {
      final state = PaymentReturnState(
        orderId: orderId,
        status: result == 'fail' ? 'failed' : 'pending',
        productKind: returnedProductKind,
      );
      _ref.read(paymentReturnStateProvider.notifier).state = state;
      return state;
    }
  }
}
