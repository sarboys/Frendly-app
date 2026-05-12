import 'package:big_break_mobile/features/edit_profile/presentation/edit_profile_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
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
  testWidgets('edit profile keeps age numeric and updates bio counter',
      (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen()));
    await tester.pumpAndSettle();

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

    final bioField = find.byKey(const Key('edit-profile-bio-field'));
    await tester.scrollUntilVisible(
      bioField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(bioField, 'Привет');
    await tester.pumpAndSettle();

    expect(find.text('6/300'), findsOneWidget);
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
}
