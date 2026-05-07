import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_social_actions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSocialBackendRepository extends BackendRepository {
  _FakeSocialBackendRepository({
    required super.ref,
    required this.snapshot,
  }) : super(dio: Dio());

  ProfileSocialData snapshot;
  var followCalls = 0;
  var likeCalls = 0;

  @override
  Future<ProfileSocialData> setProfileFollow(
    String userId, {
    required bool follow,
  }) async {
    followCalls += 1;
    snapshot = snapshot.copyWith(
      iFollow: follow,
      followers: snapshot.followers + (follow ? 1 : -1),
    );
    return snapshot;
  }

  @override
  Future<ProfileSocialData> setProfileReaction(
    String userId, {
    required String kind,
    required bool active,
  }) async {
    if (kind == 'like') {
      likeCalls += 1;
      snapshot = snapshot.copyWith(
        iLike: active,
        likes: snapshot.likes + (active ? 1 : -1),
      );
    }
    return snapshot;
  }
}

void main() {
  const social = ProfileSocialData(
    followers: 248,
    likes: 1340,
    superLikes: 10000,
    iFollow: false,
    iLike: true,
    iSuper: false,
  );

  testWidgets('full variant renders counts and actions', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BbSocialActions(
          userId: 'user-anya',
          initialSocial: social,
        ),
        social,
      ),
    );

    expect(find.text('Подписчики'), findsOneWidget);
    expect(find.text('Лайков'), findsOneWidget);
    expect(find.text('Супер'), findsOneWidget);
    expect(find.text('248'), findsOneWidget);
    expect(find.text('1.3k'), findsOneWidget);
    expect(find.text('10k'), findsOneWidget);
    expect(find.text('Подписаться'), findsOneWidget);
  });

  testWidgets('compact variant toggles follow and like optimistically', (
    tester,
  ) async {
    _FakeSocialBackendRepository? fake;

    await tester.pumpWidget(
      _wrap(
        const BbSocialActions(
          userId: 'user-anya',
          initialSocial: social,
          variant: BbSocialActionsVariant.compact,
        ),
        social,
        onBackendCreated: (value) => fake = value,
      ),
    );

    await tester.tap(find.text('Подписаться'));
    await tester.pump();

    expect(fake?.followCalls, 1);
    expect(find.text('Подписан'), findsOneWidget);

    final likeButton = find.byType(InkWell).last;
    await tester.tap(likeButton);
    await tester.pump();

    expect(fake?.likeCalls, 1);
  });

  testWidgets('row variant renders only compact counters', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BbSocialActions(
          userId: 'user-anya',
          initialSocial: social,
          variant: BbSocialActionsVariant.row,
        ),
        social,
      ),
    );

    expect(find.text('248'), findsOneWidget);
    expect(find.text('1.3k'), findsOneWidget);
    expect(find.text('10k'), findsOneWidget);
    expect(find.text('Подписаться'), findsNothing);
  });
}

Widget _wrap(
  Widget child,
  ProfileSocialData social, {
  void Function(_FakeSocialBackendRepository backend)? onBackendCreated,
}) {
  return ProviderScope(
    overrides: [
      profileSocialProvider.overrideWith(
        (ref, userId) => ProfileSocialController(ref, userId, social),
      ),
      backendRepositoryProvider.overrideWith((ref) {
        final backend = _FakeSocialBackendRepository(
          ref: ref,
          snapshot: social,
        );
        onBackendCreated?.call(backend);
        return backend;
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}
