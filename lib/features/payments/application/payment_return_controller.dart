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
  });

  final String orderId;
  final String status;

  bool get confirmed => status == 'confirmed';
  bool get failed =>
      status == 'failed' || status == 'expired' || status == 'canceled';
}

class PaymentReturnController {
  PaymentReturnController(this._ref);

  final Ref _ref;

  Future<void> handleUri(Uri uri) async {
    if (uri.scheme != 'frendly' || uri.host != 'payment') {
      return;
    }
    final result = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    final orderId = uri.queryParameters['orderId'];
    if (orderId == null || orderId.isEmpty) {
      return;
    }

    if (result == 'fail') {
      _ref.read(paymentReturnStateProvider.notifier).state =
          PaymentReturnState(orderId: orderId, status: 'failed');
      return;
    }

    if (result != 'success') {
      return;
    }

    try {
      await _ref.read(authBootstrapProvider.future);
      final repository = _ref.read(backendRepositoryProvider);
      final order = await repository.checkPayment(orderId);
      _ref.invalidate(subscriptionStateProvider);
      _ref.invalidate(paymentCatalogProvider);
      _ref.read(tokenWalletProvider.notifier).refresh();
      _ref.read(paymentReturnStateProvider.notifier).state =
          PaymentReturnState(orderId: orderId, status: order.status);
    } catch (_) {
      _ref.read(paymentReturnStateProvider.notifier).state =
          PaymentReturnState(orderId: orderId, status: 'pending');
    }
  }
}
