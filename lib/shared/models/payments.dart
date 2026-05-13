import 'package:big_break_mobile/shared/models/subscription.dart';

class PaymentCatalog {
  const PaymentCatalog({
    required this.tbankEnabled,
    required this.subscriptions,
    required this.tokenPacks,
    required this.promoOptions,
  });

  final bool tbankEnabled;
  final List<SubscriptionPlanData> subscriptions;
  final List<PaymentTokenPackData> tokenPacks;
  final List<PaymentPromoOptionData> promoOptions;

  factory PaymentCatalog.fromJson(Map<String, dynamic> json) {
    return PaymentCatalog(
      tbankEnabled: json['tbankEnabled'] as bool? ?? false,
      subscriptions: ((json['subscriptions'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => SubscriptionPlanData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      tokenPacks: ((json['tokenPacks'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => PaymentTokenPackData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      promoOptions: ((json['promoOptions'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => PaymentPromoOptionData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class PaymentTokenPackData {
  const PaymentTokenPackData({
    required this.id,
    required this.label,
    required this.tokens,
    required this.bonus,
    required this.priceRub,
    required this.best,
  });

  final String id;
  final String label;
  final int tokens;
  final int bonus;
  final int priceRub;
  final bool best;

  int get total => tokens + bonus;

  factory PaymentTokenPackData.fromJson(Map<String, dynamic> json) {
    return PaymentTokenPackData(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      bonus: (json['bonus'] as num?)?.toInt() ?? 0,
      priceRub: (json['priceRub'] as num?)?.toInt() ?? 0,
      best: json['best'] as bool? ?? false,
    );
  }
}

class PaymentPromoOptionData {
  const PaymentPromoOptionData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.durationHours,
  });

  final String id;
  final String title;
  final String subtitle;
  final int cost;
  final int durationHours;

  factory PaymentPromoOptionData.fromJson(Map<String, dynamic> json) {
    return PaymentPromoOptionData(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      durationHours: (json['durationHours'] as num?)?.toInt() ?? 0,
    );
  }
}

class PaymentOrderData {
  const PaymentOrderData({
    required this.orderId,
    required this.paymentId,
    required this.paymentUrl,
    required this.status,
  });

  final String orderId;
  final String? paymentId;
  final String? paymentUrl;
  final String status;

  bool get isConfirmed => status == 'confirmed';
  bool get isFailed =>
      status == 'failed' || status == 'expired' || status == 'canceled';

  factory PaymentOrderData.fromJson(Map<String, dynamic> json) {
    return PaymentOrderData(
      orderId: json['orderId'] as String? ?? '',
      paymentId: json['paymentId'] as String?,
      paymentUrl: json['paymentUrl'] as String?,
      status: json['status'] as String? ?? 'pending',
    );
  }
}
