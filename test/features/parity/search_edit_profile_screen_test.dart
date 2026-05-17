import 'package:big_break_mobile/features/edit_profile/presentation/edit_profile_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

Widget _wrap(Widget child, {List<Override> extraOverrides = const []}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      ...extraOverrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('edit profile mirrors v5 edit copy and keeps field constraints',
      (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Расскажи'), findsOneWidget);
    expect(find.textContaining('о себе'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Основа'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Основа'), findsOneWidget);

    final ageField = find.byKey(const Key('edit-profile-age-field'));
    await tester.scrollUntilVisible(
      ageField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(ageField, '2a8');
    await tester.pumpAndSettle();

    expect(find.text('28'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Какое у тебя настроение чаще'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Какое у тебя настроение чаще'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Зачем ты здесь'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Зачем ты здесь'), findsOneWidget);

    final bioField = find.byKey(const Key('edit-profile-bio-field'));
    await tester.scrollUntilVisible(
      bioField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(bioField, 'Привет');
    await tester.pumpAndSettle();

    expect(find.text('6/280'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Видимость'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Скрыть возраст'), findsOneWidget);
    expect(find.text('Показывать на радаре'), findsOneWidget);
  });

  testWidgets('edit profile shows photo thumbnails under hero', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EditProfileScreen(),
        extraOverrides: [
          profileProvider.overrideWith(
            (ref) async => const ProfileData(
              id: 'user-me',
              displayName: 'Сергей',
              verified: true,
              online: true,
              age: 32,
              city: 'Москва',
              area: 'Нячанг',
              bio: 'bio',
              vibe: 'Спокойно',
              rating: 4.8,
              meetupCount: 12,
              avatarUrl: null,
              interests: ['Кофе'],
              intent: ['Друзья'],
              photos: [
                ProfilePhoto(
                  id: 'ph1',
                  url: 'https://cdn.example.com/ph1.jpg',
                  order: 0,
                ),
                ProfilePhoto(
                  id: 'ph2',
                  url: 'https://cdn.example.com/ph2.jpg',
                  order: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final thumbnails = find.descendant(
      of: find.byKey(const Key('edit-profile-photo-strip')),
      matching: find.byType(BbProfilePhotoImage),
    );

    expect(thumbnails, findsNWidgets(2));
    expect(
      tester.widget<BbProfilePhotoImage>(thumbnails.first).imageUrl,
      'https://cdn.example.com/ph1.jpg',
    );
  });

  testWidgets('edit profile chips keep phone width on wide screens',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2000, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(const EditProfileScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Интересы · 6'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final interestsWrap = find.byWidgetPredicate(
      (widget) => widget is Wrap && widget.children.length == 14,
    );

    expect(tester.getSize(interestsWrap).width, lessThanOrEqualTo(350));
  });

  testWidgets('edit profile saves selected chips into local profile state',
      (tester) async {
    late _RecordingEditProfileRepository repository;
    final container = ProviderContainer(
      overrides: [
        ...buildTestOverrides(),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _RecordingEditProfileRepository(ref: ref);
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Нетворк'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нетворк'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Музыка'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Музыка'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Сохранить профиль'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить профиль'));
    await tester.pumpAndSettle();

    expect(
      repository.savedOnboarding?.intent,
      'dating,friendship,network',
    );
    expect(repository.savedOnboarding?.interests, contains('Музыка'));
    expect(container.read(onboardingLocalStateProvider)?.intent,
        'dating,friendship,network');
    expect(container.read(onboardingLocalStateProvider)?.interests,
        contains('Музыка'));
    expect(container.read(profileLocalStateProvider)?.intent,
        ['Свидания', 'Друзья', 'Нетворк']);
  });
}

class _RecordingEditProfileRepository extends BackendRepository {
  _RecordingEditProfileRepository({required super.ref}) : super(dio: Dio());

  Map<String, dynamic>? updatedProfile;
  OnboardingData? savedOnboarding;

  @override
  Future<ProfileData> updateProfile(Map<String, dynamic> payload) async {
    updatedProfile = payload;
    return ProfileData(
      id: 'user-me',
      displayName: payload['displayName'] as String,
      verified: true,
      online: true,
      age: payload['age'] as int?,
      city: payload['city'] as String?,
      area: payload['area'] as String?,
      bio: payload['bio'] as String?,
      vibe: payload['vibe'] as String?,
      rating: 4.8,
      meetupCount: 12,
      avatarUrl: null,
      interests: const ['Кофе', 'Бары', 'Настолки'],
      intent: const ['Свидания', 'Друзья'],
    );
  }

  @override
  Future<OnboardingData> saveOnboarding(OnboardingData data) async {
    savedOnboarding = data;
    return data;
  }
}
