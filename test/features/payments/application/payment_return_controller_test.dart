import 'package:big_break_mobile/features/payments/application/payment_return_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed token return resolves locally without backend wait', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container
        .read(paymentReturnControllerProvider)
        .handleUri(
          Uri.parse('frendly://payment/fail?orderId=fr_123&productKind=tokens'),
        );

    expect(state, isNotNull);
    expect(state!.orderId, 'fr_123');
    expect(state.status, 'failed');
    expect(state.productKind, 'tokens');
    expect(state.failed, isTrue);
    expect(container.read(paymentReturnStateProvider), same(state));
  });
}
