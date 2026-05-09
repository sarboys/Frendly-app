import 'package:big_break_mobile/app/core/config/backend_config.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile parses photos and keeps avatar fallback from first photo', () {
    final profile = ProfileData.fromProfileJson(
      {
        'id': 'user-me',
        'displayName': 'Никита М',
        'verified': true,
        'online': true,
        'rating': 4.8,
        'meetupCount': 12,
        'photos': [
          {
            'id': 'ph1',
            'url': 'https://cdn.example.com/ph1.jpg',
            'order': 0,
          },
          {
            'id': 'ph2',
            'url': 'https://cdn.example.com/ph2.jpg',
            'order': 1,
          },
        ],
      },
      onboardingJson: const {
        'interests': ['Кофе'],
        'intent': 'both',
      },
    );

    expect(profile.photos, hasLength(2));
    expect(profile.photos.first.id, 'ph1');
    expect(profile.avatarUrl, 'https://cdn.example.com/ph1.jpg');
  });

  test('profile resolves relative media urls through api base url', () {
    final profile = ProfileData.fromProfileJson(
      {
        'id': 'user-me',
        'displayName': 'Никита М',
        'verified': true,
        'online': true,
        'avatarUrl': '/media/avatar-1',
        'rating': 4.8,
        'meetupCount': 12,
        'photos': [
          {
            'id': 'ph1',
            'url': '/media/photo-1',
            'order': 0,
          },
        ],
      },
    );

    expect(profile.avatarUrl, '${BackendConfig.apiBaseUrl}/media/avatar-1');
    expect(
        profile.photos.first.url, '${BackendConfig.apiBaseUrl}/media/photo-1');
  });

  test('profile photo returns image variant for requested usage', () {
    final photo = ProfilePhoto.fromJson({
      'id': 'ph1',
      'url': '/media/photo-1',
      'order': 0,
      'variants': {
        'avatar': {
          'url': '/media/photo-1/variants/avatar',
        },
        'hero': {
          'url': '/media/photo-1/variants/hero',
        },
      },
    });

    expect(
      photo.bestUrlFor(BbImageUsageProfile.avatar),
      '${BackendConfig.apiBaseUrl}/media/photo-1/variants/avatar',
    );
    expect(
      photo.bestUrlFor(BbImageUsageProfile.hero),
      '${BackendConfig.apiBaseUrl}/media/photo-1/variants/hero',
    );
  });

  test('profile resolves relative avatar fallback used as gallery photo', () {
    final profile = ProfileData.fromProfileJson(
      {
        'id': 'user-me',
        'displayName': 'Никита М',
        'verified': true,
        'online': true,
        'avatarUrl': '/media/avatar-1',
        'rating': 4.8,
        'meetupCount': 12,
        'photos': [],
      },
    );

    expect(profile.photos, hasLength(1));
    expect(
      profile.photos.first.url,
      '${BackendConfig.apiBaseUrl}/media/avatar-1',
    );
  });

  test('person profile parses social snapshot', () {
    final profile = ProfileData.fromPersonJson(
      {
        'id': 'user-anya',
        'displayName': 'Аня К',
        'verified': true,
        'online': true,
        'rating': 4.9,
        'meetupCount': 23,
        'interests': ['Кофе'],
        'intent': 'both',
        'social': {
          'followers': 248,
          'likes': 1340,
          'superLikes': 32,
          'iFollow': true,
          'iLike': true,
          'iSuper': false,
        },
      },
    );

    expect(profile.social.followers, 248);
    expect(profile.social.likes, 1340);
    expect(profile.social.superLikes, 32);
    expect(profile.social.iFollow, isTrue);
    expect(profile.social.iLike, isTrue);
    expect(profile.social.iSuper, isFalse);
  });
}
