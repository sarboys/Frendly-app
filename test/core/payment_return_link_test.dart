import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/deep_links/payment_return_link.dart';

void main() {
  test('maps frendly payment return link to wallet route', () {
    final route = paymentReturnRouteForUri(
      Uri.parse('frendly://payment/success?orderId=order-1&productKind=tokens'),
    );

    expect(
      route,
      '/wallet?paymentResult=success&orderId=order-1&productKind=tokens',
    );
  });

  test('maps dateasy payment return link to wallet route', () {
    final route = paymentReturnRouteForUri(
      Uri.parse('dateasy://payment/fail?orderId=order-2'),
    );

    expect(route, '/wallet?paymentResult=fail&orderId=order-2');
  });

  test('maps universal payment return link to wallet route', () {
    final route = paymentReturnRouteForUri(
      Uri.parse(
        'https://frendly.tech/payment/success?orderId=order-3&productKind=tokens',
      ),
    );

    expect(
      route,
      '/wallet?paymentResult=success&orderId=order-3&productKind=tokens',
    );
  });

  test('maps checkout payment return link to wallet route', () {
    final route = paymentReturnRouteForUri(
      Uri.parse(
        'frendly://payment/success?checkoutToken=token-1&returnTo=/dating',
      ),
    );

    expect(
      route,
      '/wallet?paymentResult=success&checkoutToken=token-1&returnTo=%2Fdating',
    );
  });

  test('maps payment host with result query to wallet route', () {
    final route = paymentReturnRouteForUri(
      Uri.parse(
        'frendly://payment?result=success&orderId=order-4&productKind=tokens',
      ),
    );

    expect(
      route,
      '/wallet?paymentResult=success&result=success&orderId=order-4&productKind=tokens',
    );
  });

  test('keeps normalized payment result authoritative', () {
    final route = paymentReturnRouteForUri(
      Uri.parse('frendly://payment/success?paymentResult=fail&orderId=order-5'),
    );

    expect(route, '/wallet?paymentResult=success&orderId=order-5');
  });

  test('ignores unrelated links', () {
    expect(
        paymentReturnRouteForUri(Uri.parse('frendly://event/event-1')), null);
  });

  test('ignores foreign universal payment links', () {
    expect(
      paymentReturnRouteForUri(
        Uri.parse('https://example.com/payment/success?orderId=order-6'),
      ),
      null,
    );
  });
}
