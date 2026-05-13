import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final paymentLinkServiceProvider = Provider<PaymentLinkService>((ref) {
  final service = PaymentLinkService();
  ref.onDispose(service.dispose);
  return service;
});

class PaymentLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  Future<void> start(Future<void> Function(Uri uri) onLink) async {
    if (_started) {
      return;
    }
    _started = true;

    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      unawaited(onLink(initialLink));
    }

    _subscription = _appLinks.uriLinkStream.listen((uri) {
      unawaited(onLink(uri));
    });
  }

  Future<bool> openPaymentUrl(String paymentUrl) async {
    final uri = Uri.parse(paymentUrl);
    final openedInApp = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
    );
    if (openedInApp) {
      return true;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void dispose() {
    unawaited(_subscription?.cancel());
  }
}
