import 'package:big_break_mobile/shared/models/payments.dart';

class TokenWalletData {
  const TokenWalletData({
    required this.balance,
    required this.history,
    required this.promoted,
    required this.promoOptions,
  });

  final int balance;
  final List<TokenWalletTransactionData> history;
  final Map<String, DateTime> promoted;
  final List<PaymentPromoOptionData> promoOptions;

  factory TokenWalletData.fromJson(Map<String, dynamic> json) {
    return TokenWalletData(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      history: ((json['history'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => TokenWalletTransactionData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      promoted: _readPromoted(json['promoted']),
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

  static Map<String, DateTime> _readPromoted(Object? value) {
    if (value is! List) {
      return const {};
    }
    final result = <String, DateTime>{};
    for (final item in value.whereType<Map>()) {
      final json = Map<String, dynamic>.from(item);
      final targetId = json['targetId'] as String?;
      final expiresAt = json['expiresAt'] as String?;
      if (targetId == null || expiresAt == null) {
        continue;
      }
      result[targetId] = DateTime.parse(expiresAt);
    }
    return result;
  }
}

class TokenWalletTransactionData {
  const TokenWalletTransactionData({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.timestamp,
  });

  final String id;
  final String type;
  final int amount;
  final String note;
  final DateTime timestamp;

  factory TokenWalletTransactionData.fromJson(Map<String, dynamic> json) {
    return TokenWalletTransactionData(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'topup',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
