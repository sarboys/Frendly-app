import 'package:big_break_mobile/shared/models/backend_url.dart';
import 'package:big_break_mobile/shared/models/media_variant.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';

class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.url,
    required this.order,
    this.variants = const {},
  });

  final String id;
  final String url;
  final int order;
  final Map<String, MediaVariantData> variants;

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) {
    return ProfilePhoto(
      id: json['id'] as String,
      url: resolveBackendUrl(json['url'] as String)!,
      order: (json['order'] as num?)?.toInt() ?? 0,
      variants: parseMediaVariants(json['variants']),
    );
  }

  String bestUrlFor(BbImageUsageProfile usageProfile) {
    return variants[usageProfile.name]?.url ?? url;
  }
}

class ProfileSocialData {
  const ProfileSocialData({
    required this.followers,
    required this.likes,
    required this.superLikes,
    required this.iFollow,
    required this.iLike,
    required this.iSuper,
  });

  const ProfileSocialData.empty()
      : followers = 0,
        likes = 0,
        superLikes = 0,
        iFollow = false,
        iLike = false,
        iSuper = false;

  final int followers;
  final int likes;
  final int superLikes;
  final bool iFollow;
  final bool iLike;
  final bool iSuper;

  bool get hasSignal =>
      followers > 0 ||
      likes > 0 ||
      superLikes > 0 ||
      iFollow ||
      iLike ||
      iSuper;

  factory ProfileSocialData.fromJson(Object? raw) {
    if (raw is! Map) {
      return const ProfileSocialData.empty();
    }
    final json = Map<String, dynamic>.from(raw);
    return ProfileSocialData(
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      superLikes: (json['superLikes'] as num?)?.toInt() ?? 0,
      iFollow: (json['iFollow'] as bool?) ?? false,
      iLike: (json['iLike'] as bool?) ?? false,
      iSuper: (json['iSuper'] as bool?) ?? false,
    );
  }

  ProfileSocialData copyWith({
    int? followers,
    int? likes,
    int? superLikes,
    bool? iFollow,
    bool? iLike,
    bool? iSuper,
  }) {
    return ProfileSocialData(
      followers: followers ?? this.followers,
      likes: likes ?? this.likes,
      superLikes: superLikes ?? this.superLikes,
      iFollow: iFollow ?? this.iFollow,
      iLike: iLike ?? this.iLike,
      iSuper: iSuper ?? this.iSuper,
    );
  }
}

class ProfileData {
  const ProfileData({
    required this.id,
    required this.displayName,
    required this.verified,
    required this.online,
    required this.age,
    this.gender,
    required this.city,
    required this.area,
    required this.bio,
    required this.vibe,
    required this.rating,
    required this.meetupCount,
    required this.avatarUrl,
    required this.interests,
    required this.intent,
    this.photos = const [],
    this.social = const ProfileSocialData.empty(),
  });

  final String id;
  final String displayName;
  final bool verified;
  final bool online;
  final int? age;
  final String? gender;
  final String? city;
  final String? area;
  final String? bio;
  final String? vibe;
  final double rating;
  final int meetupCount;
  final String? avatarUrl;
  final List<String> interests;
  final List<String> intent;
  final List<ProfilePhoto> photos;
  final ProfileSocialData social;

  factory ProfileData.fromProfileJson(
    Map<String, dynamic> profileJson, {
    Map<String, dynamic>? onboardingJson,
  }) {
    final parsedPhotos = _parsePhotos(
      profileJson['photos'],
      fallbackAvatarUrl: profileJson['avatarUrl'] as String?,
    );
    return ProfileData(
      id: profileJson['id'] as String,
      displayName: profileJson['displayName'] as String,
      verified: (profileJson['verified'] as bool?) ?? false,
      online: (profileJson['online'] as bool?) ?? false,
      age: profileJson['age'] as int?,
      gender: profileJson['gender'] as String?,
      city: profileJson['city'] as String?,
      area: profileJson['area'] as String?,
      bio: profileJson['bio'] as String?,
      vibe: profileJson['vibe'] as String?,
      rating: (profileJson['rating'] as num?)?.toDouble() ?? 0,
      meetupCount: (profileJson['meetupCount'] as num?)?.toInt() ?? 0,
      avatarUrl: resolveBackendUrl((profileJson['avatarUrl'] as String?)) ??
          parsedPhotos.firstOrNull?.url,
      interests: (((onboardingJson?['interests']) as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      intent: _mapIntent(onboardingJson?['intent'] as String?),
      photos: parsedPhotos,
      social: ProfileSocialData.fromJson(profileJson['social']),
    );
  }

  factory ProfileData.fromPersonJson(Map<String, dynamic> json) {
    final parsedPhotos = _parsePhotos(
      json['photos'],
      fallbackAvatarUrl: json['avatarUrl'] as String?,
    );
    return ProfileData(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      verified: (json['verified'] as bool?) ?? false,
      online: (json['online'] as bool?) ?? false,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      city: json['city'] as String?,
      area: json['area'] as String?,
      bio: json['bio'] as String?,
      vibe: json['vibe'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      meetupCount: (json['meetupCount'] as num?)?.toInt() ?? 0,
      avatarUrl: resolveBackendUrl(json['avatarUrl'] as String?) ??
          parsedPhotos.firstOrNull?.url,
      interests: ((json['interests'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      intent: _mapIntent(json['intent'] as String?),
      photos: parsedPhotos,
      social: ProfileSocialData.fromJson(json['social']),
    );
  }

  ProfileData copyWith({
    String? displayName,
    bool? verified,
    bool? online,
    int? age,
    String? gender,
    String? city,
    String? area,
    String? bio,
    String? vibe,
    double? rating,
    int? meetupCount,
    String? avatarUrl,
    List<String>? interests,
    List<String>? intent,
    List<ProfilePhoto>? photos,
    ProfileSocialData? social,
  }) {
    return ProfileData(
      id: id,
      displayName: displayName ?? this.displayName,
      verified: verified ?? this.verified,
      online: online ?? this.online,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      area: area ?? this.area,
      bio: bio ?? this.bio,
      vibe: vibe ?? this.vibe,
      rating: rating ?? this.rating,
      meetupCount: meetupCount ?? this.meetupCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      interests: interests ?? this.interests,
      intent: intent ?? this.intent,
      photos: photos ?? this.photos,
      social: social ?? this.social,
    );
  }

  ProfileData withOnboarding(OnboardingData onboarding) {
    return copyWith(
      interests: onboarding.interests.toList(growable: false),
      intent: _mapIntent(onboarding.intent),
    );
  }

  static List<String> _mapIntent(String? raw) {
    switch (raw) {
      case 'dating':
        return const ['Свидания'];
      case 'friendship':
        return const ['Друзья'];
      case 'network':
        return const ['Нетворк'];
      case 'both':
        return const ['Свидания', 'Друзья'];
      default:
        return const [];
    }
  }

  static List<ProfilePhoto> _parsePhotos(
    Object? rawPhotos, {
    required String? fallbackAvatarUrl,
  }) {
    final parsed = ((rawPhotos as List?) ?? const [])
        .whereType<Map>()
        .map((item) => ProfilePhoto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false)
      ..sort((left, right) => left.order.compareTo(right.order));

    if (parsed.isNotEmpty) {
      return parsed;
    }

    final fallbackUrl = resolveBackendUrl(fallbackAvatarUrl);
    if (fallbackUrl == null || fallbackUrl.isEmpty) {
      return const [];
    }

    return [
      ProfilePhoto(
        id: 'avatar-fallback',
        url: fallbackUrl,
        order: 0,
      ),
    ];
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
