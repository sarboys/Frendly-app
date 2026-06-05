import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/app/core/device/app_media_prewarm_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/dating/presentation/dating_likes_screen.dart';
import 'package:mobile2/features/dating/presentation/dating_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

void main() {
  testWidgets('dating swipe right advances optimistically and sends like', (
    tester,
  ) async {
    final action = Completer<DatingActionResult>();
    final repository = _DatingTestRepository(action: action.future);

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('Соня, 26'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('dating-swipe-card')),
      const Offset(260, 0),
    );
    await tester.pump();

    expect(repository.actions, ['user-sonya:like']);
    expect(find.text('Лиза, 27'), findsOneWidget);
    expect(find.text('Соня, 26'), findsNothing);

    action.complete(_actionResult(action: 'like'));
    await tester.pumpAndSettle();
  });

  testWidgets('dating card changes photos by tap and resets on next profile', (
    tester,
  ) async {
    final repository = _DatingTestRepository(
      discoverItems: [
        _datingCard(
          'user-sonya',
          'Соня',
          26,
          photos: [
            'https://cdn.test/user-sonya-1.jpg',
            'https://cdn.test/user-sonya-2.jpg',
          ],
        ),
        _datingCard(
          'user-liza',
          'Лиза',
          27,
          photos: [
            'https://cdn.test/user-liza-1.jpg',
            'https://cdn.test/user-liza-2.jpg',
          ],
        ),
      ],
    );

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Фото 1 из 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Следующее фото'), findsOneWidget);

    final cardRect =
        tester.getRect(find.byKey(const ValueKey('dating-swipe-card')));
    await tester.tapAt(Offset(cardRect.right - 52, cardRect.top + 180));
    await tester.pump();

    expect(find.bySemanticsLabel('Фото 2 из 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Лайк'));
    await tester.pumpAndSettle();

    expect(find.text('Лиза, 27'), findsOneWidget);
    expect(find.bySemanticsLabel('Фото 1 из 2'), findsOneWidget);
  });

  testWidgets('dating keeps image variants for secondary profile photos', (
    tester,
  ) async {
    final repository = _DatingTestRepository(
      discoverItems: [
        BackendCardItem.fromJson({
          'userId': 'user-sonya',
          'name': 'Соня',
          'age': 26,
          'distance': '1 км',
          'job': 'Product designer',
          'tags': ['кофе', 'кино'],
          'matchPercent': 91,
          'photos': [
            {
              'url': 'https://cdn.test/user-sonya-1.jpg',
              'variants': {
                'fullscreen': {
                  'url': 'https://cdn.test/user-sonya-1__fullscreen.webp',
                },
              },
            },
            {
              'url': 'https://cdn.test/user-sonya-2.jpg',
              'variants': {
                'fullscreen': {
                  'url': 'https://cdn.test/user-sonya-2__fullscreen.webp',
                },
              },
            },
          ],
          'online': true,
        }),
      ],
    );

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    final cardRect =
        tester.getRect(find.byKey(const ValueKey('dating-swipe-card')));
    await tester.tapAt(Offset(cardRect.right - 52, cardRect.top + 180));
    await tester.pump();

    final image = tester
        .widgetList<DateasyRemoteImage>(
          find.byType(DateasyRemoteImage),
        )
        .firstWhere(
          (widget) => widget.imageUrl == 'https://cdn.test/user-sonya-2.jpg',
        );

    expect(
      DateasyRemoteImage.resolveVariantImageUrl(
        imageUrl: image.imageUrl,
        imageVariants: image.imageVariants,
        usage: DateasyImageUsage.fullscreen,
      ),
      'https://cdn.test/user-sonya-2__fullscreen.webp',
    );
  });

  testWidgets('dating hides next deck preview and bottom token balance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _DatingTestRepository();

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('Следующие в подборке'), findsNothing);
    expect(find.textContaining('100 FT', findRichText: true), findsNothing);
  });

  testWidgets('dating free action badges do not show token icon', (
    tester,
  ) async {
    final repository = _DatingTestRepository();

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('dating-action-token-badge')), findsNothing);
  });

  testWidgets('dating paid action badges show token icon after free limits end',
      (
    tester,
  ) async {
    final repository = _DatingTestRepository(
      limits: const DatingLimitsData(
        premium: true,
        hourlySwipes: DatingHourlySwipesData(unlimited: true),
        superLikes: DatingLimitBucketData(
          freeLimit: 10,
          freeRemaining: 0,
          paidCost: 50,
        ),
        rewinds: DatingLimitBucketData(
          freeLimit: 5,
          freeRemaining: 0,
          paidCost: 25,
        ),
      ),
    );

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dating-action-token-badge')),
      findsNWidgets(2),
    );
  });

  testWidgets('dating opens wallet when paid action has not enough tokens', (
    tester,
  ) async {
    final repository = _DatingTestRepository(
      actionErrorCode: 'tokens_insufficient',
    );

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Super-like'));
    await tester.pumpAndSettle();

    expect(repository.actions, ['user-sonya:super_like']);
    expect(find.text('wallet-opened'), findsOneWidget);
  });

  testWidgets('dating opens locked incoming likes page without Frendly Plus', (
    tester,
  ) async {
    final repository = _DatingTestRepository(subscriptionStatus: 'inactive');

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('1 лайкнул тебя'), findsOneWidget);

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Тебя лайкнули'), findsOneWidget);
    expect(find.text('Открыть 1 лайк'), findsOneWidget);
    expect(find.text('Получить'), findsOneWidget);

    await tester.tap(find.text('Получить'));
    await tester.pumpAndSettle();

    expect(find.text('paywall-opened'), findsOneWidget);
  });

  testWidgets('dating shows real zero incoming likes without mock cards', (
    tester,
  ) async {
    final repository = _DatingTestRepository(
      subscriptionStatus: 'inactive',
      likes: const [],
    );

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('Пока нет лайков'), findsOneWidget);
    expect(find.text('6 лайкнули тебя'), findsNothing);
    final avatarUrls = tester
        .widgetList<DateasyRemoteImage>(find.byType(DateasyRemoteImage))
        .where((widget) => widget.usage == DateasyImageUsage.avatar)
        .map((widget) => widget.imageUrl)
        .whereType<String>()
        .toList(growable: false);
    expect(avatarUrls, isNot(contains('https://cdn.test/user-sonya.jpg')));
    expect(avatarUrls, isNot(contains('https://cdn.test/user-liza.jpg')));

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Пока нет входящих лайков'), findsOneWidget);
    expect(find.text('Получить'), findsNothing);
    expect(find.text('Скрыто'), findsNothing);
  });

  testWidgets('dating opens visible incoming likes for Frendly Plus', (
    tester,
  ) async {
    final repository = _DatingTestRepository(subscriptionStatus: 'active');

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('1 лайкнул тебя'), findsOneWidget);

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Тебя лайкнули'), findsOneWidget);
    expect(find.text('Нина, 25'), findsOneWidget);

    await tester.tap(find.text('Нина, 25'));
    await tester.pumpAndSettle();

    expect(find.text('profile-user-nina'), findsOneWidget);
  });

  testWidgets('dating mutual like opens match with user and chat query', (
    tester,
  ) async {
    final repository = _DatingTestRepository(
      action: Future.value(
        _actionResult(
          action: 'like',
          matched: true,
          chatId: 'chat-sonya',
        ),
      ),
    );

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Лайк'));
    await tester.pumpAndSettle();

    expect(find.text('match-user-sonya-chat-sonya'), findsOneWidget);
  });

  testWidgets('dating does not show matched profile after match screen next', (
    tester,
  ) async {
    final repository = _DatingTestRepository(
      action: Future.value(
        _actionResult(
          action: 'like',
          matched: true,
          chatId: 'chat-sonya',
        ),
      ),
    );

    await tester.pumpWidget(_datingHarness(repository));
    await tester.pumpAndSettle();

    expect(find.text('Соня, 26'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Лайк'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свайпать дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Соня, 26'), findsNothing);
    expect(find.text('Лиза, 27'), findsOneWidget);
  });
}

Widget _datingHarness(_DatingTestRepository repository) {
  final router = GoRouter(
    initialLocation: '/dating',
    routes: [
      GoRoute(
        path: '/dating',
        builder: (_, __) => const DatingScreen(),
      ),
      GoRoute(
        path: '/dating/likes',
        builder: (_, state) => DatingLikesScreen(
          initialCount: int.tryParse(state.uri.queryParameters['count'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/dating/filter',
        builder: (_, __) => const Scaffold(body: Text('filters-opened')),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, __) => const Scaffold(body: Text('wallet-opened')),
      ),
      GoRoute(
        path: '/paywall',
        builder: (_, __) => const Scaffold(body: Text('paywall-opened')),
      ),
      GoRoute(
        path: '/match',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return Scaffold(
            body: Column(
              children: [
                Text('match-${query['userId']}-${query['chatId']}'),
                TextButton(
                  onPressed: () => context.go('/dating'),
                  child: const Text('Свайпать дальше'),
                ),
              ],
            ),
          );
        },
      ),
      GoRoute(
        path: '/u/:userId',
        builder: (_, state) => Scaffold(
          body: Text('profile-${state.pathParameters['userId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      appMediaPrewarmServiceProvider.overrideWithValue(
        AppMediaPrewarmService(fetchFile: (_, __) async {}),
      ),
      initialAuthTokensProvider.overrideWithValue(
        const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      ),
      currentUserProvider.overrideWith(
        (_) => const BackendUser(
          id: 'user-me',
          name: 'Алекс',
          gender: 'male',
          onboardingComplete: true,
        ),
      ),
      backendRepositoryProvider.overrideWithValue(repository),
      tokenWalletProvider.overrideWith(
        (_) async => const TokenWalletData(balance: 100),
      ),
      subscriptionProvider.overrideWith(
        (_) async =>
            SubscriptionStateData(status: repository.subscriptionStatus),
      ),
    ],
    child: MaterialApp.router(
      theme: DateasyTheme.theme,
      routerConfig: router,
    ),
  );
}

class _DatingTestRepository extends BackendRepository {
  _DatingTestRepository({
    Future<DatingActionResult>? action,
    this.actionErrorCode,
    this.subscriptionStatus = 'active',
    this.likes,
    this.discoverItems,
    this.limits = const DatingLimitsData(
      premium: true,
      hourlySwipes: DatingHourlySwipesData(unlimited: true),
      superLikes: DatingLimitBucketData(
        freeLimit: 10,
        freeRemaining: 9,
        paidCost: 50,
      ),
      rewinds: DatingLimitBucketData(
        freeLimit: 5,
        freeRemaining: 5,
        paidCost: 25,
      ),
    ),
  })  : action = action ?? Future.value(_actionResult()),
        super(Dio());

  final Future<DatingActionResult> action;
  final String? actionErrorCode;
  final String subscriptionStatus;
  final List<BackendCardItem>? likes;
  final List<BackendCardItem>? discoverItems;
  final DatingLimitsData limits;
  final actions = <String>[];

  @override
  Future<BackendPage<BackendCardItem>> fetchDatingDiscover({
    int limit = 10,
    String? cursor,
    String? gender,
    int? ageMin,
    int? ageMax,
    int? radiusKm,
    List<String> interests = const [],
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? newThisWeekOnly,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: discoverItems ??
          [
            _datingCard('user-sonya', 'Соня', 26),
            _datingCard('user-liza', 'Лиза', 27),
          ],
      nextCursor: null,
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchDatingLikes({
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: likes ?? [_datingCard('user-nina', 'Нина', 25)],
    );
  }

  @override
  Future<DatingLimitsData> fetchDatingLimits({CancelToken? cancelToken}) async {
    return limits;
  }

  @override
  Future<DatingActionResult> recordDatingAction({
    required String targetUserId,
    required String action,
    CancelToken? cancelToken,
  }) async {
    actions.add('$targetUserId:$action');
    final code = actionErrorCode;
    if (code != null) {
      final options = RequestOptions(path: '/dating/actions');
      throw DioException(
        requestOptions: options,
        response: Response<Map<String, Object?>>(
          requestOptions: options,
          statusCode: 402,
          data: {'code': code, 'message': code},
        ),
      );
    }
    return this.action;
  }
}

BackendCardItem _datingCard(
  String id,
  String name,
  int age, {
  List<String>? photos,
}) {
  return BackendCardItem.fromJson({
    'userId': id,
    'name': name,
    'age': age,
    'distance': '1 км',
    'job': 'Product designer',
    'tags': ['кофе', 'кино'],
    'matchPercent': 91,
    'imageUrl': 'https://cdn.test/$id.jpg',
    if (photos != null)
      'photos': [
        for (final photo in photos) {'url': photo},
      ],
    'online': true,
  });
}

DatingActionResult _actionResult({
  String action = 'like',
  bool matched = false,
  String? chatId,
}) {
  return DatingActionResult.fromJson({
    'ok': true,
    'action': action,
    'matched': matched,
    'chatId': chatId,
    'peer': {'userId': 'user-sonya', 'name': 'Соня'},
  });
}
