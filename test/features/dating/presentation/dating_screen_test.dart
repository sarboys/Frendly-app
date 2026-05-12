import 'dart:async';
import 'dart:io';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/dating_profile.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/models/subscription.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../test_overrides.dart';

Widget _wrap({
  required List<Override> overrides,
  String? initialProfileId,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ProviderScope(
          overrides: [
            ...buildTestOverrides(),
            ...overrides,
          ],
          child: DatingScreen(initialProfileId: initialProfileId),
        ),
      ),
      GoRoute(
        path: AppRoute.paywall.path,
        name: AppRoute.paywall.name,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('paywall-opened')),
        ),
      ),
      GoRoute(
        path: AppRoute.personalChat.path,
        name: AppRoute.personalChat.name,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('chat-${state.pathParameters['chatId']}'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoute.createMeetup.path,
        name: AppRoute.createMeetup.name,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('create-${state.uri.queryParameters['mode']}'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoute.userProfile.path,
        name: AppRoute.userProfile.name,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('profile-${state.pathParameters['userId']}'),
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  test('dating screen uses shared profile photo image widget', () {
    final source = File(
      'lib/features/dating/presentation/dating_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('CachedNetworkImage(')));
    expect(source, contains('BbProfilePhotoImage'));
  });

  testWidgets('dating is available without Frendly+ subscription',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          authBootstrapProvider.overrideWith((ref) async {}),
          currentUserIdProvider.overrideWith((ref) => 'user-me'),
          backendRepositoryProvider.overrideWith(
            (ref) => _MutableDatingRepository(ref: ref, dio: Dio()),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => const SubscriptionStateData(
              plan: null,
              status: 'inactive',
              startedAt: null,
              renewsAt: null,
              trialEndsAt: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лента'), findsOneWidget);
    expect(find.text('Лайки'), findsOneWidget);
    expect(find.text('Соня, 26'), findsOneWidget);
    expect(find.text('Открыть Frendly+'), findsNothing);
  });

  testWidgets('dating likes are locked without Frendly+', (tester) async {
    var likesReads = 0;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          authBootstrapProvider.overrideWith((ref) async {}),
          currentUserIdProvider.overrideWith((ref) => 'user-me'),
          backendRepositoryProvider.overrideWith(
            (ref) => _MutableDatingRepository(ref: ref, dio: Dio()),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => const SubscriptionStateData(
              plan: null,
              status: 'inactive',
              startedAt: null,
              renewsAt: null,
              trialEndsAt: null,
            ),
          ),
          datingLikesProvider.overrideWith((ref) async {
            likesReads += 1;
            return const <DatingProfileData>[];
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Лайки'));
    await tester.pumpAndSettle();

    expect(find.text('Лайки доступны с Frendly+'), findsOneWidget);
    expect(find.text('Открыть Frendly+'), findsOneWidget);
    expect(likesReads, 0);
  });

  testWidgets('dating filter controls expose labels and selected state',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => const SubscriptionStateData(
              plan: null,
              status: 'inactive',
              startedAt: null,
              renewsAt: null,
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [_sonyaProfile],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Фильтры дейтинга'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Район Все')),
      matchesSemantics(
        label: 'Район Все',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Интерес кофе')),
      matchesSemantics(
        label: 'Интерес кофе',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );

    semantics.dispose();
  });

  testWidgets('dating feed reserves space for bottom actions', (tester) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView).first);
    final padding = listView.padding as EdgeInsets;

    expect(padding.bottom, greaterThanOrEqualTo(148));
  });

  testWidgets('dating action row clears bottom navigation on iPhone height',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => const SubscriptionStateData(
              plan: null,
              status: 'inactive',
              startedAt: null,
              renewsAt: null,
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [_sonyaProfile],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final likeButton = find
        .ancestor(
          of: find.text('Лайк'),
          matching: find.byType(GestureDetector),
        )
        .last;
    final actionBottom = tester.getBottomLeft(likeButton).dy;

    expect(actionBottom, lessThanOrEqualTo(806));
  });

  testWidgets('dating state shows discover content', (tester) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лента'), findsOneWidget);
    expect(find.text('Лайки'), findsOneWidget);
    expect(find.text('Соня, 26'), findsOneWidget);
    expect(find.text('Дейтинг'), findsOneWidget);
    expect(find.text('Frendly+'), findsNothing);
  });

  testWidgets('dating discover card hides social follow row', (tester) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Подпис'), findsNothing);
    expect(find.text('Пропустить'), findsOneWidget);
    expect(find.text('Супер'), findsOneWidget);
    expect(find.text('Лайк'), findsOneWidget);
  });

  testWidgets('dating can start on the requested profile', (tester) async {
    await tester.pumpWidget(
      _wrap(
        initialProfileId: 'user-dasha',
        overrides: [
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины.',
                tags: ['ужины'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: false,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
              DatingProfileData(
                userId: 'user-dasha',
                name: 'Даша',
                age: 34,
                distance: '2 км',
                about: 'Кофе и прогулки.',
                tags: ['кофе'],
                prompt: 'Идеальный вечер в центре.',
                photoEmoji: '☕',
                avatarUrl: null,
                likedYou: false,
                premium: false,
                vibe: 'Вечер',
                area: 'Патрики',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Даша, 34'), findsOneWidget);
    expect(find.text('Соня, 26'), findsNothing);
  });

  testWidgets('dating likes item sends like action', (tester) async {
    late _FakeDatingRepository fakeRepository;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          backendRepositoryProvider.overrideWith(
            (ref) => fakeRepository = _FakeDatingRepository(
              ref: ref,
              dio: Dio(),
            ),
          ),
          datingDiscoverProvider.overrideWith((ref) async => const []),
          datingLikesProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: true,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Лайки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Соня, 26'));
    await tester.pumpAndSettle();

    expect(fakeRepository.actionTargets, ['user-sonya']);
    expect(fakeRepository.actionKinds, ['like']);
  });

  testWidgets('dating action advances before backend response', (
    tester,
  ) async {
    late _PendingDatingRepository repository;
    final action = Completer<DatingActionResult>();

    await tester.pumpWidget(
      _wrap(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => repository = _PendingDatingRepository(
              ref: ref,
              dio: Dio(),
              action: action.future,
            ),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [_sonyaProfile, _lizaProfile],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Соня, 26'), findsOneWidget);

    await tester.ensureVisible(find.text('Лайк'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Лайк'));
    await tester.pump();

    expect(repository.actionTargets, ['user-sonya']);
    expect(find.text('Лиза, 27'), findsOneWidget);
    expect(find.text('Соня, 26'), findsNothing);

    action.complete(
      const DatingActionResult(
        ok: true,
        action: 'like',
        matched: false,
        chatId: null,
        peer: null,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('dating action rolls back profile on backend error', (
    tester,
  ) async {
    final action = Completer<DatingActionResult>();

    await tester.pumpWidget(
      _wrap(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _PendingDatingRepository(
              ref: ref,
              dio: Dio(),
              action: action.future,
            ),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [_sonyaProfile, _lizaProfile],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Лайк'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Лайк'));
    await tester.pump();

    expect(find.text('Лиза, 27'), findsOneWidget);

    action.completeError(
      DioException(requestOptions: RequestOptions(path: '/dating/actions')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Соня, 26'), findsOneWidget);
    expect(find.text('Лиза, 27'), findsNothing);
    expect(find.text('Не получилось сохранить действие'), findsOneWidget);
  });

  testWidgets('dating likes shows match pill before opening chat', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _MatchDatingRepository(ref: ref, dio: Dio()),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith((ref) async => const []),
          datingLikesProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: true,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Лайки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Соня, 26'));
    await tester.pumpAndSettle();

    expect(find.text('MATCH · ОТКРЫТЬ ЧАТ'), findsOneWidget);
    expect(find.text('chat-chat-sonya'), findsNothing);

    await tester.tap(find.text('MATCH · ОТКРЫТЬ ЧАТ'));
    await tester.pumpAndSettle();

    expect(find.text('chat-chat-sonya'), findsOneWidget);
  });

  testWidgets('dating super button sends super like action', (tester) async {
    late _FakeDatingRepository fakeRepository;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => fakeRepository = _FakeDatingRepository(
              ref: ref,
              dio: Dio(),
            ),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Супер'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Супер'));
    await tester.pumpAndSettle();

    expect(fakeRepository.actionTargets, ['user-sonya']);
    expect(fakeRepository.actionKinds, ['super_like']);
  });

  testWidgets('dating opens paywall on super like limit', (tester) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _PaywallDatingRepository(ref: ref, dio: Dio()),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => const SubscriptionStateData(
              plan: null,
              status: 'inactive',
              startedAt: null,
              renewsAt: null,
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Супер'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Супер'));
    await tester.pumpAndSettle();

    expect(find.text('paywall-opened'), findsOneWidget);
  });

  testWidgets('dating state can change profile photo', (tester) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: 'https://cdn.example.com/sonya-1.jpg',
                photos: [
                  ProfilePhoto(
                    id: 'ph1',
                    url: 'https://cdn.example.com/sonya-1.jpg',
                    order: 0,
                  ),
                  ProfilePhoto(
                    id: 'ph2',
                    url: 'https://cdn.example.com/sonya-2.jpg',
                    order: 1,
                  ),
                ],
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    var photo = tester.widget<BbProfilePhotoImage>(
      find.byType(BbProfilePhotoImage).first,
    );
    expect(photo.imageUrl, 'https://cdn.example.com/sonya-1.jpg');

    final card = find.byKey(const ValueKey('dating-discover-card'));
    await tester.tapAt(tester.getTopLeft(card) + const Offset(580, 120));
    await tester.pumpAndSettle();

    photo = tester.widget<BbProfilePhotoImage>(
      find.byType(BbProfilePhotoImage).first,
    );
    expect(photo.imageUrl, 'https://cdn.example.com/sonya-2.jpg');
  });

  testWidgets('dating swipe right advances to the next profile',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        overrides: [
          authBootstrapProvider.overrideWith((ref) async {}),
          currentUserIdProvider.overrideWith((ref) => 'user-me'),
          backendRepositoryProvider.overrideWith(
            (ref) => _FakeDatingRepository(ref: ref, dio: Dio()),
          ),
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
              DatingProfileData(
                userId: 'user-liza',
                name: 'Лиза',
                age: 27,
                distance: '2.0 км',
                about: 'Люблю концерты и спонтанные планы.',
                tags: ['концерты', 'вечер'],
                prompt: 'Лучший вечер начинается без долгой переписки.',
                photoEmoji: '🌆',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Активно',
                area: 'Центр',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Соня, 26'), findsOneWidget);

    final card = find.byKey(const ValueKey('dating-discover-card'));
    await tester.dragFrom(
      tester.getTopLeft(card) + const Offset(180, 120),
      const Offset(260, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лиза, 27'), findsOneWidget);
  });

  testWidgets('dating does not skip first fresh profile after backend refetch',
      (tester) async {
    late _MutableDatingRepository repository;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          authBootstrapProvider.overrideWith((ref) async {}),
          currentUserIdProvider.overrideWith((ref) => 'user-me'),
          backendRepositoryProvider.overrideWith((ref) {
            repository = _MutableDatingRepository(ref: ref, dio: Dio());
            return repository;
          }),
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Соня, 26'), findsOneWidget);

    final card = find.byKey(const ValueKey('dating-discover-card'));
    await tester.dragFrom(
      tester.getTopLeft(card) + const Offset(180, 120),
      const Offset(260, 0),
    );
    await tester.pumpAndSettle();

    expect(repository.actionTargets, ['user-sonya']);
    expect(find.text('Лиза, 27'), findsOneWidget);
    expect(find.text('Маша, 28'), findsNothing);
  });

  testWidgets('dating drag keeps card near the viewport while held',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrap(
        overrides: [
          subscriptionStateProvider.overrideWith(
            (ref) async => SubscriptionStateData(
              plan: 'year',
              status: 'active',
              startedAt: DateTime(2026, 4, 18),
              renewsAt: DateTime(2027, 4, 18),
              trialEndsAt: null,
            ),
          ),
          datingDiscoverProvider.overrideWith(
            (ref) async => const [
              DatingProfileData(
                userId: 'user-sonya',
                name: 'Соня',
                age: 26,
                distance: '1.4 км',
                about: 'Люблю тихие ужины plus длинные разговоры.',
                tags: ['ужины', 'джаз'],
                prompt: 'Лучший first date без спешки.',
                photoEmoji: '🕯️',
                avatarUrl: null,
                likedYou: false,
                premium: true,
                vibe: 'Спокойно',
                area: 'Замоскворечье',
                verified: true,
                online: true,
              ),
            ],
          ),
          datingLikesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('dating-discover-card'));
    final surface = find.byKey(const ValueKey('dating-swipeable-card-surface'));
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(260, 0));
    await tester.pump();

    expect(tester.getTopLeft(surface).dx, lessThanOrEqualTo(150));

    await gesture.up();
    await tester.pumpAndSettle();
  });
}

const _sonyaProfile = DatingProfileData(
  userId: 'user-sonya',
  name: 'Соня',
  age: 26,
  distance: '1.4 км',
  about: 'Люблю тихие ужины plus длинные разговоры.',
  tags: ['ужины', 'джаз'],
  prompt: 'Лучший first date без спешки.',
  photoEmoji: '🕯️',
  avatarUrl: null,
  likedYou: false,
  premium: true,
  vibe: 'Спокойно',
  area: 'Замоскворечье',
  verified: true,
  online: true,
);

const _lizaProfile = DatingProfileData(
  userId: 'user-liza',
  name: 'Лиза',
  age: 27,
  distance: '2.0 км',
  about: 'Люблю концерты и спонтанные планы.',
  tags: ['концерты', 'вечер'],
  prompt: 'Лучший вечер начинается без долгой переписки.',
  photoEmoji: '🌆',
  avatarUrl: null,
  likedYou: false,
  premium: true,
  vibe: 'Активно',
  area: 'Центр',
  verified: true,
  online: true,
);

class _PendingDatingRepository extends BackendRepository {
  _PendingDatingRepository({
    required super.ref,
    required super.dio,
    required this.action,
  });

  final Future<DatingActionResult> action;
  final actionTargets = <String>[];

  @override
  Future<DatingActionResult> sendDatingAction({
    required String targetUserId,
    required String action,
  }) async {
    actionTargets.add(targetUserId);
    return this.action;
  }
}

class _MatchDatingRepository extends BackendRepository {
  _MatchDatingRepository({
    required super.ref,
    required super.dio,
  });

  @override
  Future<DatingActionResult> sendDatingAction({
    required String targetUserId,
    required String action,
  }) async {
    return DatingActionResult(
      ok: true,
      action: action,
      matched: true,
      chatId: 'chat-sonya',
      peer: null,
    );
  }
}

class _FakeDatingRepository extends BackendRepository {
  _FakeDatingRepository({
    required super.ref,
    required super.dio,
  });

  final actionTargets = <String>[];
  final actionKinds = <String>[];

  @override
  Future<DatingActionResult> sendDatingAction({
    required String targetUserId,
    required String action,
  }) async {
    actionTargets.add(targetUserId);
    actionKinds.add(action);
    return DatingActionResult(
      ok: true,
      action: action,
      matched: false,
      chatId: null,
      peer: null,
    );
  }
}

class _MutableDatingRepository extends BackendRepository {
  _MutableDatingRepository({
    required super.ref,
    required super.dio,
  });

  final actionTargets = <String>[];
  var _profiles = const [
    DatingProfileData(
      userId: 'user-sonya',
      name: 'Соня',
      age: 26,
      distance: '1.4 км',
      about: 'Люблю тихие ужины plus длинные разговоры.',
      tags: ['ужины', 'джаз'],
      prompt: 'Лучший first date без спешки.',
      photoEmoji: '🕯️',
      avatarUrl: null,
      likedYou: false,
      premium: true,
      vibe: 'Спокойно',
      area: 'Замоскворечье',
      verified: true,
      online: true,
    ),
    DatingProfileData(
      userId: 'user-liza',
      name: 'Лиза',
      age: 27,
      distance: '2.0 км',
      about: 'Люблю концерты и спонтанные планы.',
      tags: ['концерты', 'вечер'],
      prompt: 'Лучший вечер начинается без долгой переписки.',
      photoEmoji: '🌆',
      avatarUrl: null,
      likedYou: false,
      premium: true,
      vibe: 'Активно',
      area: 'Центр',
      verified: true,
      online: true,
    ),
    DatingProfileData(
      userId: 'user-masha',
      name: 'Маша',
      age: 28,
      distance: '2.5 км',
      about: 'Кофе, выставки, прогулки.',
      tags: ['кофе', 'выставки'],
      prompt: 'Идеальное свидание начинается с короткого плана.',
      photoEmoji: '☕',
      avatarUrl: null,
      likedYou: false,
      premium: true,
      vibe: 'Спокойно',
      area: 'Центр',
      verified: true,
      online: true,
    ),
  ];

  @override
  Future<PaginatedResponse<DatingProfileData>> fetchDatingDiscover({
    CancelToken? cancelToken,
    String? cursor,
    int limit = 20,
  }) async {
    return PaginatedResponse(
      items: _profiles,
      nextCursor: null,
    );
  }

  @override
  Future<DatingActionResult> sendDatingAction({
    required String targetUserId,
    required String action,
  }) async {
    actionTargets.add(targetUserId);
    _profiles = _profiles
        .where((profile) => profile.userId != targetUserId)
        .toList(growable: false);
    return DatingActionResult(
      ok: true,
      action: action,
      matched: false,
      chatId: null,
      peer: null,
    );
  }
}

class _PaywallDatingRepository extends BackendRepository {
  _PaywallDatingRepository({
    required super.ref,
    required super.dio,
  });

  @override
  Future<DatingActionResult> sendDatingAction({
    required String targetUserId,
    required String action,
  }) async {
    final requestOptions = RequestOptions(path: '/dating/actions');
    throw DioException(
      requestOptions: requestOptions,
      response: Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 402,
        data: const {'code': 'super_like_limit_reached'},
      ),
    );
  }
}
