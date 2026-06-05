import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/device/app_media_prewarm_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/home/presentation/home_screen.dart';
import 'package:mobile2/features/meetings/presentation/meeting_detail_screen.dart';
import 'package:mobile2/features/meetings/presentation/meetings_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

void main() {
  testWidgets('home communities tab shows controls even when empty',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _visualHarness(
        home: const HomeScreen(initialHomeTab: 1),
        communities: const [],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Сообщества'), findsWidgets);
    expect(find.bySemanticsLabel('Создать сообщество'), findsOneWidget);
    expect(find.text('Йога, гастро, музыка...'), findsOneWidget);
    expect(find.bySemanticsLabel('Фильтры'), findsOneWidget);
    expect(find.text('Сообществ пока нет'), findsOneWidget);
  });

  testWidgets('home communities create opens paywall for non Plus user',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const HomeScreen(initialHomeTab: 1),
        ),
        GoRoute(
          path: '/paywall',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('Paywall route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _visualHarness(
        router: router,
        communities: const [],
        subscription: const SubscriptionStateData(status: 'inactive'),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Создать сообщество'));
    await tester.pumpAndSettle();

    expect(find.text('Paywall route'), findsOneWidget);
  });

  testWidgets('home radar keeps enough height to show its content',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_visualHarness(home: const HomeScreen()));
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('сегодня вечером', findRichText: true),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const Key('home-radar-card'))).height,
      greaterThanOrEqualTo(220),
    );
  });

  testWidgets('home radar shows nearby meetings with three mock icons',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_visualHarness(home: const HomeScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Встречи рядом'), findsOneWidget);
    expect(find.text('Люди рядом'), findsNothing);
    expect(find.byKey(const Key('home-radar-mock-icon-wine')), findsOneWidget);
    expect(find.byKey(const Key('home-radar-mock-icon-music')), findsOneWidget);
    expect(
        find.byKey(const Key('home-radar-mock-icon-coffee')), findsOneWidget);
  });

  testWidgets('home nearby meetings show attendee avatars and extra count',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _visualHarness(
        home: const HomeScreen(),
        homeEvents: const [
          BackendCardItem(
            id: 'meeting-1',
            title: 'Идем на стендап',
            subtitle: 'Brew Lab',
            raw: {
              'going': 6,
              'participants': [
                {'avatarUrl': 'https://cdn.example.com/a.jpg'},
                {'avatarUrl': 'https://cdn.example.com/b.jpg'},
                {'avatarUrl': 'https://cdn.example.com/c.jpg'},
                {'avatarUrl': 'https://cdn.example.com/d.jpg'},
                {'avatarUrl': 'https://cdn.example.com/e.jpg'},
                {'avatarUrl': 'https://cdn.example.com/f.jpg'},
              ],
            },
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Ближайшие встречи'));
    await tester.pumpAndSettle();

    expect(find.text('+3 человека'), findsOneWidget);
  });

  testWidgets('home nearby meetings prewarm attendee avatars, not covers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prewarmed = <String>[];
    final prewarmService = AppMediaPrewarmService(
      fetchFile: (url, _) async {
        prewarmed.add(url);
      },
    );

    await tester.pumpWidget(
      _visualHarness(
        home: const HomeScreen(),
        prewarmService: prewarmService,
        homeEvents: const [
          BackendCardItem(
            id: 'meeting-1',
            title: 'Идем на стендап',
            subtitle: 'Brew Lab',
            imageUrl: 'https://cdn.example.com/cover.jpg',
            raw: {
              'going': 4,
              'attendees': ['Анна', 'Ира'],
              'memberProfiles': [
                {
                  'userId': 'user-a',
                  'displayName': 'Анна',
                  'avatarUrl': 'https://cdn.example.com/a.jpg',
                },
                {
                  'userId': 'user-b',
                  'displayName': 'Ира',
                  'avatarUrl': 'https://cdn.example.com/b.jpg',
                },
              ],
            },
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text('Ближайшие встречи'));
    await tester.pumpAndSettle();

    expect(
        prewarmed,
        containsAll([
          'https://cdn.example.com/a.jpg',
          'https://cdn.example.com/b.jpg',
        ]));
    expect(prewarmed, isNot(contains('https://cdn.example.com/cover.jpg')));
  });

  testWidgets('home notification dot follows unread count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _visualHarness(
        home: const HomeScreen(),
        unreadNotifications: 0,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('home-notification-dot')), findsNothing);
  });

  testWidgets('home shows the Frendly Drops teaser from front2',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_visualHarness(home: const HomeScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('frendly drops · июнь'), findsOneWidget);
    expect(find.text('Июньский Drop · 3 × iPhone 16 Pro'), findsOneWidget);
    expect(
      find.text(
        'Бесплатно для верифицированных · получай билеты за активность',
      ),
      findsOneWidget,
    );
  });

  testWidgets('home nearby meeting tile opens meeting detail when tapped',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => Scaffold(
            body: Text('detail ${state.pathParameters['meetingId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _visualHarness(
        router: router,
        homeEvents: const [
          BackendCardItem(
            id: 'meeting-1',
            title: 'Идем на стендап',
            subtitle: 'Brew Lab',
            raw: {'going': 2},
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Идем на стендап'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Идем на стендап'));
    await tester.pumpAndSettle();

    expect(find.text('detail meeting-1'), findsOneWidget);
  });

  testWidgets('meeting detail opened from invite notification shows accept',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _visualHarness(
        home: const MeetingDetailScreen(
          meetingId: 'meeting-1',
          inviteRequestId: 'request-1',
        ),
        meetingDetail: const BackendCardItem(
          id: 'meeting-1',
          title: 'Винный вечер',
          raw: {
            'joinMode': 'request',
            'joinRequestStatus': 'pending',
            'entryRequirements': {'canJoin': true, 'missing': []},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Принять'), findsOneWidget);
    expect(find.text('Заявка отправлена'), findsNothing);
  });

  testWidgets('meetings cards open detail when tapped', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings',
      routes: [
        GoRoute(path: '/meetings', builder: (_, __) => const MeetingsScreen()),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => Scaffold(
            body: Text('detail ${state.pathParameters['meetingId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _visualHarness(
        router: router,
        meetings: const [
          BackendCardItem(
            id: 'meeting-1',
            title: 'Идем на стендап',
            subtitle: 'Brew Lab',
            raw: {'going': 1, 'capacity': 6},
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Идем на стендап'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Идем на стендап'));
    await tester.pumpAndSettle();

    expect(find.text('detail meeting-1'), findsOneWidget);
  });

  testWidgets('meetings page does not show dating filter shortcut',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _visualHarness(
        home: const MeetingsScreen(),
        meetings: const [
          BackendCardItem(
            id: 'meeting-1',
            title: 'Идем на стендап',
            subtitle: 'Brew Lab',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(LucideIcons.slidersHorizontal), findsNothing);
  });

  testWidgets('meetings cards keep backend image variants', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _visualHarness(
        home: const MeetingsScreen(),
        meetings: const [
          BackendCardItem(
            id: 'meeting-1',
            title: 'Идем на стендап',
            subtitle: 'Brew Lab',
            imageUrl: 'https://cdn.example.com/cover.jpg',
            raw: {
              'imageVariants': {
                'card': {'url': 'https://cdn.example.com/cover-card.webp'},
              },
            },
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final image = tester
        .widgetList<DateasyRemoteImage>(find.byType(DateasyRemoteImage))
        .firstWhere(
          (widget) => widget.imageUrl == 'https://cdn.example.com/cover.jpg',
        );

    expect(
      DateasyRemoteImage.resolveVariantImageUrl(
        imageUrl: image.imageUrl,
        imageVariants: image.imageVariants,
        usage: DateasyImageUsage.card,
      ),
      'https://cdn.example.com/cover-card.webp',
    );
  });

  testWidgets('meetings list starts close to the AI suggestion card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _visualHarness(
        home: const MeetingsScreen(),
        meetings: const [
          BackendCardItem(
            id: 'meeting-1',
            title: 'Идем на стендап',
            subtitle: 'Brew Lab',
            imageUrl: 'https://cdn.example.com/cover.jpg',
            raw: {
              'going': 1,
              'capacity': 6,
              'participants': [
                {'avatarUrl': 'https://cdn.example.com/a.jpg'},
              ],
            },
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final aiBottom =
        tester.getBottomLeft(find.text('AI подберёт встречу под вечер')).dy;
    final cardTop = tester.getTopLeft(find.text('Идем на стендап')).dy;

    expect(cardTop - aiBottom, lessThan(180));
  });
}

Widget _visualHarness({
  Widget? home,
  GoRouter? router,
  List<BackendCardItem> homeEvents = const [],
  List<BackendCardItem> meetings = const [],
  List<BackendCardItem> communities = const [],
  BackendCardItem? meetingDetail,
  SubscriptionStateData subscription =
      const SubscriptionStateData(status: 'active'),
  int unreadNotifications = 0,
  AppMediaPrewarmService? prewarmService,
}) {
  final scope = ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (_) => const BackendUser(
          id: 'user-1',
          name: 'Сергей',
          onboardingComplete: true,
          city: 'Москва',
        ),
      ),
      tokenWalletProvider.overrideWith(
        (_) async => const TokenWalletData(balance: 0),
      ),
      matchesProvider.overrideWith(
        (_) => Stream.value(const BackendPage<BackendCardItem>(items: [])),
      ),
      postersProvider.overrideWith(
        (_) async => const BackendPage<BackendCardItem>(items: []),
      ),
      subscriptionProvider.overrideWith((_) async => subscription),
      communitiesProvider.overrideWith(
        (_) => Stream.value(BackendPage(items: communities)),
      ),
      communitiesQueryProvider.overrideWith(
        (_, __) => Stream.value(BackendPage(items: communities)),
      ),
      homeEventsQueryProvider.overrideWith(
        (_, __) => Stream.value(BackendPage(items: homeEvents)),
      ),
      meetingsQueryProvider.overrideWith(
        (_, __) => Stream.value(BackendPage(items: meetings)),
      ),
      meetingDetailProvider.overrideWith(
        (_, __) => Stream.value(
          meetingDetail ??
              const BackendCardItem(
                id: 'fallback',
                title: 'Fallback',
              ),
        ),
      ),
      notificationUnreadCountProvider.overrideWith(
        (_) async => unreadNotifications,
      ),
      if (prewarmService != null)
        appMediaPrewarmServiceProvider.overrideWithValue(prewarmService),
    ],
    child: router == null
        ? MaterialApp(
            theme: DateasyTheme.theme,
            home: home,
          )
        : MaterialApp.router(
            theme: DateasyTheme.theme,
            routerConfig: router,
          ),
  );
  return scope;
}
