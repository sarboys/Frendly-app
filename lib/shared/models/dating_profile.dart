import 'package:big_break_mobile/shared/models/backend_url.dart';
import 'package:big_break_mobile/shared/models/profile.dart';

class DatingProfileData {
  const DatingProfileData({
    required this.userId,
    required this.name,
    required this.age,
    this.city,
    required this.distance,
    required this.about,
    required this.tags,
    required this.prompt,
    required this.photoEmoji,
    required this.avatarUrl,
    this.primaryPhoto,
    this.photos = const [],
    required this.likedYou,
    required this.premium,
    required this.vibe,
    required this.area,
    this.latitude,
    this.longitude,
    required this.verified,
    required this.online,
    this.languages = const [],
    this.nationality,
  });

  final String userId;
  final String name;
  final int? age;
  final String? city;
  final String distance;
  final String about;
  final List<String> tags;
  final String prompt;
  final String photoEmoji;
  final String? avatarUrl;
  final ProfilePhoto? primaryPhoto;
  final List<ProfilePhoto> photos;
  final bool likedYou;
  final bool premium;
  final String? vibe;
  final String? area;
  final double? latitude;
  final double? longitude;
  final bool verified;
  final bool online;
  final List<DatingLanguageData> languages;
  final DatingLanguageData? nationality;

  factory DatingProfileData.fromJson(Map<String, dynamic> json) {
    final parsedPhotos = ((json['photos'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => ProfilePhoto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false)
      ..sort((left, right) => left.order.compareTo(right.order));
    final parsedPrimaryPhoto = json['primaryPhoto'] is Map<String, dynamic>
        ? ProfilePhoto.fromJson(json['primaryPhoto'] as Map<String, dynamic>)
        : json['primaryPhoto'] is Map
            ? ProfilePhoto.fromJson(
                Map<String, dynamic>.from(json['primaryPhoto'] as Map),
              )
            : parsedPhotos.firstOrNull;

    return DatingProfileData(
      userId: json['userId'] as String,
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt(),
      city: json['city'] as String?,
      distance: json['distance'] as String? ?? '',
      about: json['about'] as String? ?? '',
      tags: ((json['tags'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      prompt: json['prompt'] as String? ?? '',
      photoEmoji: json['photoEmoji'] as String? ?? '💘',
      avatarUrl: resolveBackendUrl(json['avatarUrl'] as String?) ??
          parsedPrimaryPhoto?.url,
      primaryPhoto: parsedPrimaryPhoto,
      photos: parsedPhotos,
      likedYou: (json['likedYou'] as bool?) ?? false,
      premium: (json['premium'] as bool?) ?? false,
      vibe: json['vibe'] as String?,
      area: json['area'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      verified: (json['verified'] as bool?) ?? false,
      online: (json['online'] as bool?) ?? false,
      languages: ((json['languages'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                DatingLanguageData.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      nationality: json['nationality'] is Map<String, dynamic>
          ? DatingLanguageData.fromJson(
              json['nationality'] as Map<String, dynamic>,
            )
          : json['nationality'] is Map
              ? DatingLanguageData.fromJson(
                  Map<String, dynamic>.from(json['nationality'] as Map),
                )
              : null,
    );
  }
}

class DatingLanguageData {
  const DatingLanguageData({
    required this.flag,
    required this.label,
  });

  final String flag;
  final String label;

  factory DatingLanguageData.fromJson(Map<String, dynamic> json) {
    return DatingLanguageData(
      flag: json['flag'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class DatingSuperLikeQuotaData {
  const DatingSuperLikeQuotaData({
    required this.limit,
    required this.remaining,
    required this.premium,
    required this.resetAt,
  });

  final int limit;
  final int remaining;
  final bool premium;
  final DateTime? resetAt;

  factory DatingSuperLikeQuotaData.fromJson(Map<String, dynamic> json) {
    final resetAtRaw = json['resetAt'];
    return DatingSuperLikeQuotaData(
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      premium: json['premium'] as bool? ?? false,
      resetAt: resetAtRaw is String ? DateTime.tryParse(resetAtRaw) : null,
    );
  }
}

class DatingActionResult {
  const DatingActionResult({
    required this.ok,
    required this.action,
    required this.matched,
    required this.chatId,
    required this.peer,
    this.superLikeQuota,
  });

  final bool ok;
  final String action;
  final bool matched;
  final String? chatId;
  final DatingProfileData? peer;
  final DatingSuperLikeQuotaData? superLikeQuota;

  factory DatingActionResult.fromJson(Map<String, dynamic> json) {
    final superLikeQuota = json['superLikeQuota'];
    return DatingActionResult(
      ok: (json['ok'] as bool?) ?? false,
      action: json['action'] as String? ?? '',
      matched: (json['matched'] as bool?) ?? false,
      chatId: json['chatId'] as String?,
      superLikeQuota: superLikeQuota is Map<String, dynamic>
          ? DatingSuperLikeQuotaData.fromJson(superLikeQuota)
          : superLikeQuota is Map
              ? DatingSuperLikeQuotaData.fromJson(
                  Map<String, dynamic>.from(superLikeQuota),
                )
              : null,
      peer: json['peer'] is Map<String, dynamic>
          ? DatingProfileData.fromJson(json['peer'] as Map<String, dynamic>)
          : json['peer'] is Map
              ? DatingProfileData.fromJson(
                  Map<String, dynamic>.from(json['peer'] as Map),
                )
              : null,
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
