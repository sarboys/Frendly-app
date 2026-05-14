import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/payments.dart';
import 'package:big_break_mobile/shared/models/subscription.dart';
import 'package:big_break_mobile/shared/models/token_wallet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const tokenPacks = [
  TokenPack(id: 'p1', tokens: 100, price: 199, label: 'Базовый'),
  TokenPack(
    id: 'p2',
    tokens: 350,
    price: 499,
    label: 'Популярный',
    best: true,
  ),
  TokenPack(id: 'p3', tokens: 900, price: 999, label: 'Хост'),
  TokenPack(id: 'p4', tokens: 2700, price: 2499, label: 'Pro'),
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

final tokenPacksProvider = Provider<List<TokenPack>>((ref) {
  final catalog = ref.watch(paymentCatalogProvider).valueOrNull;
  final packs = catalog?.tokenPacks;
  if (packs == null || packs.isEmpty) {
    return tokenPacks;
  }
  return packs.map(TokenPack.fromPaymentData).toList(growable: false);
});

final tokenWalletProvider =
    StateNotifierProvider<TokenWalletController, TokenWalletState>((ref) {
  final controller = TokenWalletController(ref);
  controller.refresh();
  return controller;
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

  factory TokenPack.fromPaymentData(PaymentTokenPackData data) {
    return TokenPack(
      id: data.id,
      tokens: data.tokens,
      price: data.priceRub,
      label: data.label,
      bonus: data.bonus,
      best: data.best,
    );
  }
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

  factory PromoOption.fromPaymentData(PaymentPromoOptionData data) {
    return PromoOption(
      id: data.id,
      title: data.title,
      subtitle: data.subtitle,
      cost: data.cost,
      durationHours: data.durationHours,
    );
  }
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

  factory TokenTransaction.fromData(TokenWalletTransactionData data) {
    return TokenTransaction(
      id: data.id,
      type: data.type == 'spend'
          ? TokenTransactionType.spend
          : TokenTransactionType.topup,
      amount: data.amount,
      note: data.note,
      timestamp: data.timestamp,
    );
  }
}

class TokenWalletState {
  const TokenWalletState({
    required this.balance,
    required this.promoted,
    required this.history,
    required this.loading,
  });

  const TokenWalletState.initial()
      : balance = 0,
        promoted = const {},
        history = const [],
        loading = true;

  final int balance;
  final Map<String, DateTime> promoted;
  final List<TokenTransaction> history;
  final bool loading;

  bool isPromoted(String id) {
    final expiresAt = promoted[id];
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  TokenWalletState copyWith({
    int? balance,
    Map<String, DateTime>? promoted,
    List<TokenTransaction>? history,
    bool? loading,
  }) {
    return TokenWalletState(
      balance: balance ?? this.balance,
      promoted: promoted ?? this.promoted,
      history: history ?? this.history,
      loading: loading ?? this.loading,
    );
  }
}

class TokenWalletController extends StateNotifier<TokenWalletState> {
  TokenWalletController(this._ref) : super(const TokenWalletState.initial());

  final Ref? _ref;

  Future<void> refresh() async {
    final ref = _ref;
    if (ref == null) {
      state = state.copyWith(loading: false);
      return;
    }
    if (ref.read(authTokensProvider) == null) {
      state = state.copyWith(loading: false);
      return;
    }
    try {
      final repository = ref.read(backendRepositoryProvider);
      final wallet = await repository.fetchTokenWallet();
      state = _fromData(wallet);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<PaymentOrderData> createTopUpPayment(TokenPack pack) async {
    final ref = _ref;
    if (ref == null) {
      throw StateError('Token wallet is not connected');
    }
    await ref.read(authBootstrapProvider.future);
    final repository = ref.read(backendRepositoryProvider);
    return repository.initPayment(
      productKind: 'tokens',
      productId: pack.id,
    );
  }

  Future<bool> promote(String meetupId, PromoOption option) async {
    final ref = _ref;
    if (ref == null) {
      return false;
    }
    try {
      await ref.read(authBootstrapProvider.future);
      final repository = ref.read(backendRepositoryProvider);
      final wallet = await repository.promoteWithTokens(
        targetKind: 'event',
        targetId: meetupId,
        optionId: option.id,
      );
      state = _fromData(wallet);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SubscriptionStateData> subscribeWithTokens(String plan) async {
    final ref = _ref;
    if (ref == null) {
      throw StateError('Token wallet is not connected');
    }
    await ref.read(authBootstrapProvider.future);
    final repository = ref.read(backendRepositoryProvider);
    final subscription = await repository.subscribeWithTokens(plan);
    await refresh();
    ref.invalidate(subscriptionStateProvider);
    return subscription;
  }

  TokenWalletState _fromData(TokenWalletData data) {
    return TokenWalletState(
      balance: data.balance,
      promoted: data.promoted,
      history: data.history
          .map(TokenTransaction.fromData)
          .take(50)
          .toList(growable: false),
      loading: false,
    );
  }
}
