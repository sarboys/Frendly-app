import 'dart:convert';

import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyBalance = 'frendly_v5_tokens';
const _keyPromoted = 'frendly_v5_promoted';
const _keyHistory = 'frendly_v5_token_hist';

const tokenPacks = [
  TokenPack(id: 'p1', tokens: 100, price: 199, label: 'Базовый'),
  TokenPack(
    id: 'p2',
    tokens: 300,
    price: 499,
    bonus: 50,
    label: 'Популярный',
    best: true,
  ),
  TokenPack(id: 'p3', tokens: 700, price: 999, bonus: 200, label: 'Хост'),
  TokenPack(id: 'p4', tokens: 2000, price: 2499, bonus: 700, label: 'Pro'),
];

const promoOptions = [
  PromoOption(
    id: 'boost-24',
    title: 'Буст · 24 часа',
    subtitle: 'Топ ленты + бейдж',
    cost: 80,
    durationHours: 24,
  ),
  PromoOption(
    id: 'boost-72',
    title: 'Буст · 3 дня',
    subtitle: 'Закреп в карусели',
    cost: 200,
    durationHours: 72,
  ),
  PromoOption(
    id: 'spotlight',
    title: 'Spotlight · неделя',
    subtitle: 'Главный экран + push',
    cost: 500,
    durationHours: 168,
  ),
];

final tokenWalletProvider =
    StateNotifierProvider<TokenWalletController, TokenWalletState>((ref) {
  return TokenWalletController(ref.watch(sharedPreferencesProvider));
});

class TokenPack {
  const TokenPack({
    required this.id,
    required this.tokens,
    required this.price,
    required this.label,
    this.bonus = 0,
    this.best = false,
  });

  final String id;
  final int tokens;
  final int price;
  final String label;
  final int bonus;
  final bool best;

  int get total => tokens + bonus;
}

class PromoOption {
  const PromoOption({
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
}

enum TokenTransactionType { topup, spend }

class TokenTransaction {
  const TokenTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.timestamp,
  });

  final String id;
  final TokenTransactionType type;
  final int amount;
  final String note;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'note': note,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  static TokenTransaction? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(value);
    final type = switch (json['type']) {
      'spend' => TokenTransactionType.spend,
      _ => TokenTransactionType.topup,
    };
    final amount = (json['amount'] as num?)?.toInt();
    final timestamp = (json['ts'] as num?)?.toInt();
    if (amount == null || timestamp == null) {
      return null;
    }
    return TokenTransaction(
      id: json['id'] as String? ?? 'tx-$timestamp',
      type: type,
      amount: amount,
      note: json['note'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}

class TokenWalletState {
  const TokenWalletState({
    required this.balance,
    required this.promoted,
    required this.history,
  });

  final int balance;
  final Map<String, DateTime> promoted;
  final List<TokenTransaction> history;

  bool isPromoted(String id) {
    final expiresAt = promoted[id];
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  TokenWalletState copyWith({
    int? balance,
    Map<String, DateTime>? promoted,
    List<TokenTransaction>? history,
  }) {
    return TokenWalletState(
      balance: balance ?? this.balance,
      promoted: promoted ?? this.promoted,
      history: history ?? this.history,
    );
  }
}

class TokenWalletController extends StateNotifier<TokenWalletState> {
  TokenWalletController(this._preferences) : super(_restore(_preferences));

  final SharedPreferences? _preferences;

  Future<void> topUp(TokenPack pack) async {
    final total = pack.total;
    final nextHistory = [
      _transaction(
        type: TokenTransactionType.topup,
        amount: total,
        note: 'Пополнение · ${pack.label}',
      ),
      ...state.history,
    ].take(50).toList(growable: false);
    state = state.copyWith(
      balance: state.balance + total,
      history: nextHistory,
    );
    await _persistState();
  }

  Future<bool> promote(String meetupId, PromoOption option) async {
    if (state.balance < option.cost) {
      return false;
    }
    final nextPromoted = Map<String, DateTime>.from(state.promoted)
      ..[meetupId] = DateTime.now().add(Duration(hours: option.durationHours));
    final nextHistory = [
      _transaction(
        type: TokenTransactionType.spend,
        amount: option.cost,
        note: 'Продвижение · ${option.title}',
      ),
      ...state.history,
    ].take(50).toList(growable: false);
    state = state.copyWith(
      balance: state.balance - option.cost,
      promoted: nextPromoted,
      history: nextHistory,
    );
    await _persistState();
    return true;
  }

  static TokenTransaction _transaction({
    required TokenTransactionType type,
    required int amount,
    required String note,
  }) {
    final now = DateTime.now();
    return TokenTransaction(
      id: 'tx-${now.microsecondsSinceEpoch}',
      type: type,
      amount: amount,
      note: note,
      timestamp: now,
    );
  }

  static TokenWalletState _restore(SharedPreferences? preferences) {
    final now = DateTime.now();
    return TokenWalletState(
      balance: _readInt(preferences, _keyBalance, 250),
      promoted: _readPromoted(preferences) ??
          {'mc1': now.add(const Duration(hours: 24))},
      history: _readHistory(preferences),
    );
  }

  static int _readInt(
    SharedPreferences? preferences,
    String key,
    int fallback,
  ) {
    final value = preferences?.get(key);
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      final decoded = int.tryParse(value);
      if (decoded != null) {
        return decoded;
      }
      final json = jsonDecodeSafe(value);
      if (json is num) {
        return json.toInt();
      }
    }
    return fallback;
  }

  static Map<String, DateTime>? _readPromoted(SharedPreferences? preferences) {
    final raw = preferences?.getString(_keyPromoted);
    final decoded = jsonDecodeSafe(raw);
    if (decoded is! Map) {
      return null;
    }
    return decoded.map((key, value) {
      final expiresAt = value is num
          ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
          : DateTime.fromMillisecondsSinceEpoch(0);
      return MapEntry(key.toString(), expiresAt);
    });
  }

  static List<TokenTransaction> _readHistory(SharedPreferences? preferences) {
    final raw = preferences?.getString(_keyHistory);
    final decoded = jsonDecodeSafe(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .map(TokenTransaction.fromJson)
        .whereType<TokenTransaction>()
        .take(50)
        .toList(growable: false);
  }

  static Object? jsonDecodeSafe(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistState() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    await preferences.setInt(_keyBalance, state.balance);
    await preferences.setString(
      _keyPromoted,
      jsonEncode(
        state.promoted.map(
          (key, value) => MapEntry(key, value.millisecondsSinceEpoch),
        ),
      ),
    );
    await preferences.setString(
      _keyHistory,
      jsonEncode(state.history.map((tx) => tx.toJson()).toList()),
    );
  }
}
