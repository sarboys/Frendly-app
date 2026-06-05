import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/app/core/device/app_media_prewarm_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/dating/presentation/dating_filter_screen.dart';
import 'package:mobile2/features/dating/presentation/dating_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';

void main() {
  test('dating discover filters default to widest active range', () {
    const filters = DatingDiscoverFilters();

    expect(filters.gender, isNull);
    expect(filters.ageMin, 18);
    expect(filters.ageMax, 99);
    expect(filters.radiusKm, 500);
    expect(filters.interests, isEmpty);
    expect(filters.verifiedOnly, isFalse);
    expect(filters.frendlyPlusOnly, isFalse);
    expect(filters.onlineOnly, isFalse);
    expect(filters.newThisWeekOnly, isFalse);
  });

  testWidgets('dating filters apply opposite gender by default',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _DatingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAuthTokensProvider.overrideWith(
            (_) => const AuthTokens(
              accessToken: 'access',
              refreshToken: 'refresh',
            ),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(
              id: 'user-me',
              name: 'Сергей',
              gender: 'male',
              onboardingComplete: true,
            ),
          ),
          tokenWalletProvider.overrideWith(
            (_) async => const TokenWalletData(balance: 50),
          ),
          subscriptionProvider.overrideWith(
            (_) async => const SubscriptionStateData(status: 'inactive'),
          ),
          notificationUnreadCountProvider.overrideWith((_) async => 0),
          backendRepositoryProvider.overrideWithValue(repository),
          appLocalCacheStoreProvider.overrideWith((_) => null),
          appMediaPrewarmServiceProvider.overrideWithValue(
            AppMediaPrewarmService(fetchFile: (_, __) async {}),
          ),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: GoRouter(
            initialLocation: '/dating/filter',
            routes: [
              GoRoute(
                  path: '/dating', builder: (_, __) => const DatingScreen()),
              GoRoute(
                path: '/dating/filter',
                builder: (_, __) => const DatingFilterScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const Scaffold(body: Text('settings')),
              ),
              GoRoute(
                path: '/wallet',
                builder: (_, __) => const Scaffold(body: Text('wallet')),
              ),
              GoRoute(
                path: '/notifications',
                builder: (_, __) => const Scaffold(body: Text('notifications')),
              ),
              GoRoute(
                path: '/profile',
                builder: (_, __) => const Scaffold(body: Text('profile')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Применить фильтры'));
    await tester.pumpAndSettle();

    expect(repository.lastGender, 'female');
    expect(repository.lastAgeMin, 18);
    expect(repository.lastAgeMax, 99);
    expect(repository.lastRadiusKm, 500);
    expect(repository.lastVerifiedOnly, isFalse);
    expect(repository.lastOnlineOnly, isFalse);
    expect(repository.lastNewThisWeekOnly, isFalse);
  });

  testWidgets('dating compact header keeps likes and filters visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAuthTokensProvider.overrideWith(
            (_) => const AuthTokens(
              accessToken: 'access',
              refreshToken: 'refresh',
            ),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(
              id: 'user-me',
              name: 'Сергей',
              onboardingComplete: true,
            ),
          ),
          tokenWalletProvider.overrideWith(
            (_) async => const TokenWalletData(balance: 50),
          ),
          subscriptionProvider.overrideWith(
            (_) async => const SubscriptionStateData(status: 'inactive'),
          ),
          notificationUnreadCountProvider.overrideWith((_) async => 0),
          backendRepositoryProvider.overrideWithValue(_DatingRepository()),
          appLocalCacheStoreProvider.overrideWith((_) => null),
          appMediaPrewarmServiceProvider.overrideWithValue(
            AppMediaPrewarmService(fetchFile: (_, __) async {}),
          ),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: GoRouter(
            initialLocation: '/dating',
            routes: [
              GoRoute(
                  path: '/dating', builder: (_, __) => const DatingScreen()),
              GoRoute(
                path: '/dating/filter',
                builder: (_, __) => const Scaffold(body: Text('filters')),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const Scaffold(body: Text('settings')),
              ),
              GoRoute(
                path: '/wallet',
                builder: (_, __) => const Scaffold(body: Text('wallet')),
              ),
              GoRoute(
                path: '/notifications',
                builder: (_, __) => const Scaffold(body: Text('notifications')),
              ),
              GoRoute(
                path: '/profile',
                builder: (_, __) => const Scaffold(body: Text('profile')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final likesTitle = find.text('Пока нет лайков');
    final filters = find.bySemanticsLabel('Фильтры');

    expect(likesTitle, findsOneWidget);
    expect(filters, findsOneWidget);

    final likesRect = tester.getRect(likesTitle);
    final filtersRect = tester.getRect(filters);

    expect((filtersRect.center.dy - likesRect.center.dy).abs(), lessThan(40));
    expect(filtersRect.right, lessThanOrEqualTo(390));
  });

  testWidgets('dating compact layout keeps photo, actions, and nav separated',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 843));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDatingScreen(
      tester,
      repository: _DatingRepository(
        discoverItems: [_profile('user-nina', 'Нина', age: 26)],
      ),
    );
    await tester.pump();
    await tester.pump();

    final card = find.byKey(const ValueKey('dating-swipe-card'));
    final cardHeight = tester.getSize(card).height;
    final cardBottom = tester.getBottomLeft(card).dy;
    final likeTop = tester.getTopLeft(find.bySemanticsLabel('Лайк')).dy;
    final likeBottom = tester.getBottomLeft(find.bySemanticsLabel('Лайк')).dy;
    final navTop = tester
        .getTopLeft(find.byKey(const ValueKey('dateasy-bottom-nav-surface')))
        .dy;
    final profileTop = tester.getTopLeft(find.text('Нина, 26')).dy;

    expect(cardHeight, greaterThan(470));
    expect(likeTop - cardBottom, inInclusiveRange(12, 36));
    expect(profileTop, lessThan(690));
    expect(likeBottom, lessThanOrEqualTo(navTop - 12));
  });

  testWidgets('dating filter change drops stale discover cards immediately',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _AgeFilteredDatingRepository();
    addTearDown(repository.completeFilteredIfNeeded);

    final container = ProviderContainer(
      overrides: _datingProviderOverrides(repository),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: _datingRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Аня, 27'), findsOneWidget);

    container.read(datingDiscoverFiltersProvider.notifier).state =
        const DatingDiscoverFilters(ageMax: 20);
    await tester.pump();

    expect(find.text('Аня, 27'), findsNothing);
    expect(find.text('Загружаем подборку'), findsOneWidget);

    repository.completeFilteredIfNeeded();
    await tester.pump();
    await tester.pump();

    expect(find.text('Пока нет анкет. Попробуй расширить фильтры'),
        findsOneWidget);
  });

  testWidgets('dating rewind uses backend and returns the previous profile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _DatingRepository(
      discoverItems: [
        _profile('user-nina', 'Нина', age: 26),
        _profile('user-mark', 'Марк', age: 28),
      ],
    );

    await _pumpDatingScreen(tester, repository: repository);
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(find.text('Нина, 26')).dy, lessThan(760));

    await tester.tap(find.bySemanticsLabel('Пропустить'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Марк, 28')).dy, lessThan(760));
    expect(repository.recordedActions, ['user-nina:pass']);

    await tester.tap(find.bySemanticsLabel('Вернуть'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Нина, 26')).dy, lessThan(760));
    expect(repository.rewindCalls, 1);
    expect(_richTextContaining('50 FT'), findsNothing);
    expect(find.text('Вернули Нина'), findsOneWidget);
  });

  testWidgets('dating undo shows an error when there is no previous profile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDatingScreen(
      tester,
      repository: _DatingRepository(
        discoverItems: [_profile('user-nina', 'Нина', age: 26)],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Вернуть'));
    await tester.pumpAndSettle();

    expect(find.text('Можно вернуть только последний пропуск'), findsOneWidget);
    expect(_richTextContaining('50 FT'), findsNothing);
  });

  test('dating prewarms only the next three visible profile images', () {
    final urls = datingPrewarmImageUrls(
      [
        _card('current', 'https://cdn.test/current.jpg'),
        _card('next-1', 'https://cdn.test/next-1.jpg'),
        _card('next-2', 'https://cdn.test/next-2.jpg'),
        _card('next-3', 'https://cdn.test/next-3.jpg'),
        _card('next-4', 'https://cdn.test/next-4.jpg'),
      ],
      currentIndex: 0,
    ).toList(growable: false);

    expect(urls, [
      'https://cdn.test/next-1.jpg',
      'https://cdn.test/next-2.jpg',
      'https://cdn.test/next-3.jpg',
    ]);
  });
}

Future<void> _pumpDatingScreen(
  WidgetTester tester, {
  required _DatingRepository repository,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: _datingProviderOverrides(repository),
      child: MaterialApp.router(
        theme: DateasyTheme.theme,
        routerConfig: _datingRouter(),
      ),
    ),
  );
}

List<Override> _datingProviderOverrides(_DatingRepository repository) {
  return [
    initialAuthTokensProvider.overrideWith(
      (_) => const AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    ),
    currentUserProvider.overrideWith(
      (_) => const BackendUser(
        id: 'user-me',
        name: 'Сергей',
        onboardingComplete: true,
      ),
    ),
    tokenWalletProvider.overrideWith(
      (_) async => const TokenWalletData(balance: 50),
    ),
    subscriptionProvider.overrideWith(
      (_) async => const SubscriptionStateData(status: 'inactive'),
    ),
    notificationUnreadCountProvider.overrideWith((_) async => 0),
    backendRepositoryProvider.overrideWithValue(repository),
    appLocalCacheStoreProvider.overrideWith((_) => null),
    appMediaPrewarmServiceProvider.overrideWithValue(
      AppMediaPrewarmService(fetchFile: (_, __) async {}),
    ),
  ];
}

GoRouter _datingRouter() {
  return GoRouter(
    initialLocation: '/dating',
    routes: [
      GoRoute(path: '/dating', builder: (_, __) => const DatingScreen()),
      GoRoute(
        path: '/dating/filter',
        builder: (_, __) => const Scaffold(body: Text('filters')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('settings')),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, __) => const Scaffold(body: Text('wallet')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const Scaffold(body: Text('notifications')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('profile')),
      ),
      GoRoute(
        path: '/match',
        builder: (_, __) => const Scaffold(body: Text('match')),
      ),
      GoRoute(
        path: '/u/:userId',
        builder: (_, __) => const Scaffold(body: Text('profile')),
      ),
    ],
  );
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(text),
    description: 'RichText containing "$text"',
  );
}

BackendCardItem _card(String id, String imageUrl) {
  return BackendCardItem(
    id: id,
    title: id,
    imageUrl: imageUrl,
    raw: {'id': id, 'imageUrl': imageUrl},
  );
}

BackendCardItem _profile(String id, String name, {int? age}) {
  return BackendCardItem(
    id: id,
    title: name,
    raw: {
      'userId': id,
      'name': name,
      if (age != null) 'age': age,
      'verified': false,
      'online': false,
    },
  );
}

class _DatingRepository extends BackendRepository {
  _DatingRepository({this.discoverItems}) : super(Dio());

  final List<BackendCardItem>? discoverItems;
  final List<String> recordedActions = [];
  int rewindCalls = 0;

  String? lastGender;
  int? lastAgeMin;
  int? lastAgeMax;
  int? lastRadiusKm;
  bool? lastVerifiedOnly;
  bool? lastOnlineOnly;
  bool? lastNewThisWeekOnly;

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
    lastGender = gender;
    lastAgeMin = ageMin;
    lastAgeMax = ageMax;
    lastRadiusKm = radiusKm;
    lastVerifiedOnly = verifiedOnly;
    lastOnlineOnly = onlineOnly;
    lastNewThisWeekOnly = newThisWeekOnly;
    return BackendPage(
      items: discoverItems ??
          const [
            BackendCardItem(
              id: 'user-sonya',
              title: 'Соня',
              raw: {
                'userId': 'user-sonya',
                'name': 'Соня',
                'verified': false,
                'online': false,
              },
            ),
          ],
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchDatingLikes({
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<DatingActionResult> recordDatingAction({
    required String targetUserId,
    required String action,
    CancelToken? cancelToken,
  }) async {
    recordedActions.add('$targetUserId:$action');
    return DatingActionResult.fromJson({
      'ok': true,
      'action': action,
      'matched': false,
      'chargedTokens': 0,
    });
  }

  @override
  Future<DatingRewindResult> rewindDatingPass({
    CancelToken? cancelToken,
  }) async {
    rewindCalls += 1;
    final item = discoverItems?.firstOrNull;
    return DatingRewindResult.fromJson({
      'ok': true,
      'action': 'pass',
      'chargedTokens': 25,
      if (item != null) 'peer': item.raw,
      'rewindQuota': {
        'freeLimit': 0,
        'freeRemaining': 0,
        'paidCost': 25,
        'chargedTokens': 25,
      },
    });
  }

  @override
  Future<DatingLimitsData> fetchDatingLimits({CancelToken? cancelToken}) async {
    return const DatingLimitsData(
      premium: false,
      hourlySwipes: DatingHourlySwipesData(
        unlimited: false,
        limit: 50,
        remaining: 50,
      ),
      superLikes: DatingLimitBucketData(
        freeLimit: 1,
        freeRemaining: 1,
        paidCost: 50,
      ),
      rewinds: DatingLimitBucketData(
        freeLimit: 0,
        freeRemaining: 0,
        paidCost: 25,
      ),
    );
  }
}

class _AgeFilteredDatingRepository extends _DatingRepository {
  final Completer<BackendPage<BackendCardItem>> _filteredPage = Completer();

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
  }) {
    if (ageMax == 20) {
      return _filteredPage.future;
    }
    return Future.value(
      BackendPage(
        items: [_profile('user-anya', 'Аня', age: 27)],
      ),
    );
  }

  void completeFilteredIfNeeded() {
    if (!_filteredPage.isCompleted) {
      _filteredPage.complete(const BackendPage(items: []));
    }
  }
}
