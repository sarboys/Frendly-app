import 'dart:async';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/payments/application/payment_return_controller.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentReturnScreen extends ConsumerStatefulWidget {
  const PaymentReturnScreen({
    super.key,
    required this.result,
    required this.orderId,
    required this.productKind,
  });

  final String result;
  final String? orderId;
  final String? productKind;

  @override
  ConsumerState<PaymentReturnScreen> createState() =>
      _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends ConsumerState<PaymentReturnScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_handleReturn());
  }

  Future<void> _handleReturn() async {
    PaymentReturnState? paymentState;
    final orderId = widget.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      paymentState = await ref.read(paymentReturnControllerProvider).handleUri(
            Uri(
              scheme: 'frendly',
              host: 'payment',
              path: '/${widget.result}',
              queryParameters: {
                'orderId': orderId,
                if (widget.productKind != null &&
                    widget.productKind!.isNotEmpty)
                  'productKind': widget.productKind!,
              },
            ),
          );
    }

    if (!mounted) {
      return;
    }
    context.goRoute(
      paymentState?.productKind == 'tokens'
          ? AppRoute.wallet
          : AppRoute.paywall,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const BbV5Scaffold(
      child: Center(
        child: CircularProgressIndicator(color: BbV5Colors.accent),
      ),
    );
  }
}
