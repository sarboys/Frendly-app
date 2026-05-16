import 'package:big_break_mobile/shared/models/backend_url.dart';

enum FrendlySeasonRewardKind { tokens, subscription }

FrendlySeasonRewardKind parseFrendlySeasonRewardKind(Object? raw) {
  return switch (raw) {
    'subscription' => FrendlySeasonRewardKind.subscription,
    _ => FrendlySeasonRewardKind.tokens,
  };
}

class FrendlySeasonStatusData {
  const FrendlySeasonStatusData({
    required this.key,
    required this.title,
    required this.threshold,
  });

  final String key;
  final String title;
  final int threshold;

  factory FrendlySeasonStatusData.fromJson(Map<String, dynamic> json) {
    return FrendlySeasonStatusData(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      threshold: (json['threshold'] as num?)?.toInt() ?? 0,
    );
  }
}

class FrendlySeasonStatsData {
  const FrendlySeasonStatsData({
    required this.checkIns,
    required this.places,
    required this.people,
  });

  final int checkIns;
  final int places;
  final int people;

  factory FrendlySeasonStatsData.fromJson(Object? raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return FrendlySeasonStatsData(
      checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
      places: (json['places'] as num?)?.toInt() ?? 0,
      people: (json['people'] as num?)?.toInt() ?? 0,
    );
  }
}

class FrendlySeasonRewardData {
  const FrendlySeasonRewardData({
    required this.key,
    required this.threshold,
    required this.statusTitle,
    required this.title,
    required this.description,
    required this.rewardKind,
    required this.rewardAmount,
    required this.unlocked,
    required this.claimed,
    required this.claimedAt,
  });

  final String key;
  final int threshold;
  final String statusTitle;
  final String title;
  final String description;
  final FrendlySeasonRewardKind rewardKind;
  final int rewardAmount;
  final bool unlocked;
  final bool claimed;
  final DateTime? claimedAt;

  bool get canClaim => unlocked && !claimed;

  String get rewardLabel {
    return switch (rewardKind) {
      FrendlySeasonRewardKind.tokens => '$rewardAmount токенов',
      FrendlySeasonRewardKind.subscription =>
        rewardAmount >= 180 ? 'Frendly+ на 6 месяцев' : 'Frendly+ на месяц',
    };
  }

  factory FrendlySeasonRewardData.fromJson(Map<String, dynamic> json) {
    return FrendlySeasonRewardData(
      key: json['key'] as String? ?? '',
      threshold: (json['threshold'] as num?)?.toInt() ?? 0,
      statusTitle: json['statusTitle'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rewardKind: parseFrendlySeasonRewardKind(json['rewardKind']),
      rewardAmount: (json['rewardAmount'] as num?)?.toInt() ?? 0,
      unlocked: (json['unlocked'] as bool?) ?? false,
      claimed: (json['claimed'] as bool?) ?? false,
      claimedAt: DateTime.tryParse(json['claimedAt'] as String? ?? ''),
    );
  }
}

class FrendlySeasonData {
  const FrendlySeasonData({
    required this.seasonKey,
    required this.seasonLabel,
    required this.checkedInCount,
    required this.calendarDays,
    required this.currentStatus,
    required this.nextReward,
    required this.stats,
    required this.rewards,
  });

  final String seasonKey;
  final String seasonLabel;
  final int checkedInCount;
  final List<int> calendarDays;
  final FrendlySeasonStatusData currentStatus;
  final FrendlySeasonRewardData? nextReward;
  final FrendlySeasonStatsData stats;
  final List<FrendlySeasonRewardData> rewards;

  factory FrendlySeasonData.fromJson(Map<String, dynamic> json) {
    final currentStatus = json['currentStatus'];
    return FrendlySeasonData(
      seasonKey: json['seasonKey'] as String? ?? '',
      seasonLabel: json['seasonLabel'] as String? ?? '',
      checkedInCount: (json['checkedInCount'] as num?)?.toInt() ?? 0,
      calendarDays: ((json['calendarDays'] as List?) ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
      currentStatus: currentStatus is Map
          ? FrendlySeasonStatusData.fromJson(
              Map<String, dynamic>.from(currentStatus),
            )
          : const FrendlySeasonStatusData(
              key: 'checkin-1',
              title: 'Искра',
              threshold: 1,
            ),
      nextReward: json['nextReward'] is Map
          ? FrendlySeasonRewardData.fromJson(
              Map<String, dynamic>.from(json['nextReward'] as Map),
            )
          : null,
      stats: FrendlySeasonStatsData.fromJson(json['stats']),
      rewards: ((json['rewards'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => FrendlySeasonRewardData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class FrendlySeasonClaimData {
  const FrendlySeasonClaimData({
    required this.claimed,
    required this.alreadyClaimed,
    required this.claimedAt,
    required this.reward,
  });

  final bool claimed;
  final bool alreadyClaimed;
  final DateTime? claimedAt;
  final FrendlySeasonRewardData reward;

  factory FrendlySeasonClaimData.fromJson(Map<String, dynamic> json) {
    return FrendlySeasonClaimData(
      claimed: (json['claimed'] as bool?) ?? false,
      alreadyClaimed: (json['alreadyClaimed'] as bool?) ?? false,
      claimedAt: DateTime.tryParse(json['claimedAt'] as String? ?? ''),
      reward: FrendlySeasonRewardData.fromJson(
        Map<String, dynamic>.from(json['reward'] as Map),
      ),
    );
  }
}

class FrendlyHistoryPersonData {
  const FrendlyHistoryPersonData({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.verified,
    required this.online,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool verified;
  final bool online;

  factory FrendlyHistoryPersonData.fromJson(Map<String, dynamic> json) {
    return FrendlyHistoryPersonData(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: resolveBackendUrl(json['avatarUrl'] as String?),
      verified: (json['verified'] as bool?) ?? false,
      online: (json['online'] as bool?) ?? false,
    );
  }
}

class FrendlyHistoryItemData {
  const FrendlyHistoryItemData({
    required this.eventId,
    required this.title,
    required this.emoji,
    required this.startsAt,
    required this.place,
    required this.latitude,
    required this.longitude,
    required this.chatId,
    required this.people,
  });

  final String eventId;
  final String title;
  final String emoji;
  final DateTime? startsAt;
  final String place;
  final double? latitude;
  final double? longitude;
  final String? chatId;
  final List<FrendlyHistoryPersonData> people;

  factory FrendlyHistoryItemData.fromJson(Map<String, dynamic> json) {
    return FrendlyHistoryItemData(
      eventId: json['eventId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      startsAt: DateTime.tryParse(json['startsAt'] as String? ?? ''),
      place: json['place'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      chatId: json['chatId'] as String?,
      people: ((json['people'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => FrendlyHistoryPersonData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class FrendlyPersonData extends FrendlyHistoryPersonData {
  const FrendlyPersonData({
    required super.userId,
    required super.displayName,
    required super.avatarUrl,
    required super.verified,
    required super.online,
    required this.meetupsCount,
    required this.lastMetAt,
    required this.lastEventTitle,
    required this.lastEventPlace,
  });

  final int meetupsCount;
  final DateTime? lastMetAt;
  final String lastEventTitle;
  final String lastEventPlace;

  factory FrendlyPersonData.fromJson(Map<String, dynamic> json) {
    return FrendlyPersonData(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: resolveBackendUrl(json['avatarUrl'] as String?),
      verified: (json['verified'] as bool?) ?? false,
      online: (json['online'] as bool?) ?? false,
      meetupsCount: (json['meetupsCount'] as num?)?.toInt() ?? 0,
      lastMetAt: DateTime.tryParse(json['lastMetAt'] as String? ?? ''),
      lastEventTitle: json['lastEventTitle'] as String? ?? '',
      lastEventPlace: json['lastEventPlace'] as String? ?? '',
    );
  }
}
