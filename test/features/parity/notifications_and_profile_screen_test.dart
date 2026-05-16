import 'package:big_break_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:big_break_mobile/features/user_profile/presentation/user_profile_screen.dart';
import 'package:big_break_mobile/features/profile/presentation/profile_screen.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/notification_item.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_overrides.dart';

class _FakeNotificationsRepository extends BackendRepository {
  _FakeNotificationsRepository({
    required super.ref,
    required super.dio,
    this.onMarkAllRead,
    this.onAcceptInvite,
  });

  int markAllReadCalls = 0;
  int acceptInviteCalls = 0;
  int declineInviteCalls = 0;
  String? acceptedEventId;
  String? acceptedRequestId;
  final VoidCallback? onMarkAllRead;
  final void Function(String eventId, String requestId)? onAcceptInvite;

  @override
  Future<void> markAllNotificationsRead() async {
    markAllReadCalls += 1;
    onMarkAllRead?.call();
  }

  @override
  Future<void> acceptInvite(String eventId, String requestId) async {
    acceptInviteCalls += 1;
    acceptedEventId = eventId;
    acceptedRequestId = requestId;
    onAcceptInvite?.call(eventId, requestId);
  }

  @override
  Future<void> declineInvite(String eventId, String requestId) async {
    declineInviteCalls += 1;
  }
}

class _ProfilePrewarmCall {
  const _ProfilePrewarmCall({
    required this.urls,
    required this.usageProfile,
    required this.limit,
    required this.concurrency,
  });

  final List<String?> urls;
  final BbImageUsageProfile usageProfile;
  final int limit;
  final int concurrency;
}

class _FakeMediaPrewarmService extends AppMediaPrewarmService {
  final calls = <_ProfilePrewarmCall>[];

  @override
  Future<void> warmProfileImages(
    Iterable<String?> urls, {
    required BbImageUsageProfile usageProfile,
    int limit = 4,
    int concurrency = 2,
  }) async {
    calls.add(
      _ProfilePrewarmCall(
        urls: urls.toList(growable: false),
        usageProfile: usageProfile,
        limit: limit,
        concurrency: concurrency,
      ),
    );
  }
}

class _FakeSocialRepository extends BackendRepository {
  _FakeSocialRepository({required super.ref}) : super(dio: Dio());

  @override
  Future<ProfileSocialData> setProfileFollow(
    String userId, {
    required bool follow,
  }) async {
    return ProfileSocialData(
      followers: follow ? 249 : 248,
      likes: 1340,
      superLikes: 32,
      iFollow: follow,
      iLike: false,
      iSuper: false,
    );
  }
}

Widget _wrap(
  Widget child, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      ...extraOverrides,
    ],
    child: MaterialApp(home: child),
  );
}

Widget _wrapNotificationsRouter({
  required List<Override> extraOverrides,
  required ValueChanged<String> onOpenedEvent,
}) {
  final router = GoRouter(
    initialLocation: AppRoute.notifications.path,
    routes: [
      GoRoute(
        path: AppRoute.notifications.path,
        name: AppRoute.notifications.name,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoute.eventDetail.path,
        name: AppRoute.eventDetail.name,
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          onOpenedEvent(eventId);
          return Scaffold(body: Text('event:$eventId'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      ...extraOverrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('super like notification opens dating on the sender profile', () {
    final location = notificationDestinationLocation(
      NotificationItem(
        id: 'n-super-like',
        kind: 'like',
        title: 'Суперлайк',
        body: 'Никита поставил суперлайк',
        payload: {
          'source': 'dating',
          'action': 'super_like',
          'userId': 'user-nikita',
          'userName': 'Никита',
        },
        readAt: null,
        createdAt: DateTime(2026, 5, 12),
      ),
    );

    expect(location, '${AppRoute.dating.path}?profileId=user-nikita');
  });

  test('plain dating like notification has no person destination', () {
    final location = notificationDestinationLocation(
      NotificationItem(
        id: 'n-like',
        kind: 'like',
        title: 'Новый лайк',
        body: 'лайкнул тебя в дейтинге',
        payload: {
          'source': 'dating',
          'action': 'like',
        },
        readAt: null,
        createdAt: DateTime(2026, 5, 12),
      ),
    );

    expect(location, isNull);
  });

  testWidgets(
    'notifications screen groups by day and shows relative time',
    (tester) async {
      final now = DateTime.now();
      final notifications = [
        NotificationItem(
          id: 'n1',
          kind: 'event_invite',
          title: 'Приглашение',
          body: 'позвала тебя на «Винный вечер на крыше» сегодня в 20:00',
          payload: const {
            'eventId': 'e1',
            'personName': 'Аня К',
          },
          readAt: null,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        NotificationItem(
          id: 'n-chat',
          kind: 'message',
          title: 'Сообщение',
          body: 'Марк С: Я уже у входа',
          payload: const {
            'chatId': 'mc1',
          },
          readAt: null,
          createdAt: now.subtract(const Duration(minutes: 12)),
        ),
        NotificationItem(
          id: 'n2',
          kind: 'like',
          title: 'Лайк',
          body: 'отметила вас как интересного человека',
          payload: const {
            'personName': 'Лиза П',
          },
          readAt: DateTime(now.year, now.month, now.day - 1, 10, 0),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          const NotificationsScreen(),
          extraOverrides: [
            notificationsProvider.overrideWith((ref) async => notifications),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Активность'), findsOneWidget);
      expect(find.text('Все'), findsWidgets);
      expect(find.text('Приглашения'), findsOneWidget);
      expect(find.text('Чаты'), findsOneWidget);
      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('Раньше'), findsOneWidget);
      expect(find.textContaining('Аня К'), findsOneWidget);
      expect(find.textContaining('Марк С'), findsOneWidget);
      expect(find.text('5 мин'), findsOneWidget);
      expect(find.text('вчера'), findsOneWidget);
      expect(find.text('Принять'), findsOneWidget);
      expect(find.text('Отказаться'), findsOneWidget);

      await tester.tap(find.text('Чаты'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Марк С'), findsOneWidget);
      expect(find.textContaining('Аня К'), findsNothing);
    },
  );

  testWidgets('profile screen renders short first name in header card',
      (tester) async {
    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Аккаунт'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-header-sos')), findsOneWidget);
    expect(find.text('Frendly Tokens'), findsNothing);
    expect(find.text('Frendly+'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Верификация'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Уведомления'), findsNothing);
    expect(find.text('0'), findsWidgets);
    expect(find.text('1 240'), findsNothing);
    expect(find.text('Подписчиков'), findsNothing);
    expect(find.text('Лайков'), findsNothing);
    expect(find.text('Подписаться'), findsNothing);
    expect(find.text('Рейтинг'), findsNothing);
    expect(find.text('Встреч'), findsNothing);
    expect(find.text('Никита, 28'), findsOneWidget);
    expect(find.text('Никита М, 28'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('встреч за 3 мес'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Frendly After Dark'), findsNothing);
    expect(find.text('История'), findsOneWidget);
  });

  testWidgets('profile screen shows only city when area is empty',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ProfileScreen(),
        extraOverrides: [
          profileProvider.overrideWith(
            (ref) async => const ProfileData(
              id: 'user-me',
              displayName: 'Никита М',
              verified: true,
              frendlyPlus: true,
              online: true,
              age: 28,
              city: 'Москва',
              area: null,
              bio: 'bio',
              vibe: 'Спокойно',
              rating: 4.8,
              meetupCount: 12,
              avatarUrl: null,
              interests: ['Кофе'],
              intent: ['Друзья'],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Москва'), findsOneWidget);
    expect(find.byTooltip('Профиль верифицирован'), findsOneWidget);
    expect(find.byTooltip('Подписка Frendly+'), findsOneWidget);
    expect(find.textContaining('Чистые пруды'), findsNothing);
  });

  testWidgets('profile metric tiles do not overflow on narrow screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(exception, isNull);
  });

  testWidgets('profile hero uses large swipeable photos and even metrics',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ProfileScreen(),
        extraOverrides: [
          profileProvider.overrideWith(
            (ref) async => const ProfileData(
              id: 'user-me',
              displayName: 'Никита М',
              verified: true,
              online: true,
              age: 28,
              city: 'Москва',
              area: 'Чистые пруды',
              bio: 'bio',
              vibe: 'Спокойно',
              rating: 4.8,
              meetupCount: 12,
              avatarUrl: 'https://cdn.example.com/profile-1.jpg',
              photos: [
                ProfilePhoto(
                  id: 'photo-1',
                  url: 'https://cdn.example.com/profile-1.jpg',
                  order: 0,
                ),
                ProfilePhoto(
                  id: 'photo-2',
                  url: 'https://cdn.example.com/profile-2.jpg',
                  order: 1,
                ),
              ],
              interests: ['Кофе'],
              intent: ['Друзья'],
              social: ProfileSocialData(
                followers: 248,
                likes: 1340,
                superLikes: 32,
                iFollow: false,
                iLike: false,
                iSuper: false,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-photo-gallery-pageview')),
      findsOneWidget,
    );
    expect(find.text('1/2'), findsOneWidget);

    for (final label in ['Подписчиков', 'Лайков', 'Рейтинг', 'Встреч']) {
      expect(find.text(label), findsNothing);
    }

    final statKeys = [
      'profile-stat-followers',
      'profile-stat-likes',
      'profile-stat-rating',
      'profile-stat-meetups',
    ];
    final centers = [
      for (final key in statKeys)
        tester.getCenter(find.byKey(ValueKey(key))).dx,
    ];
    final gaps = [
      centers[1] - centers[0],
      centers[2] - centers[1],
      centers[3] - centers[2],
    ];

    expect((gaps[0] - gaps[1]).abs(), lessThan(1));
    expect((gaps[1] - gaps[2]).abs(), lessThan(1));
  });

  testWidgets('profile screen prewarms hero photos before gallery paint',
      (tester) async {
    final prewarmService = _FakeMediaPrewarmService();

    await tester.pumpWidget(
      _wrap(
        const ProfileScreen(),
        extraOverrides: [
          appMediaPrewarmServiceProvider.overrideWithValue(prewarmService),
          profileProvider.overrideWith(
            (ref) async => const ProfileData(
              id: 'user-me',
              displayName: 'Никита М',
              verified: true,
              online: true,
              age: 28,
              city: 'Москва',
              area: 'Чистые пруды',
              bio: 'bio',
              vibe: 'Спокойно',
              rating: 4.8,
              meetupCount: 12,
              avatarUrl: 'https://cdn.example.com/profile-1.jpg',
              photos: [
                ProfilePhoto(
                  id: 'photo-1',
                  url: 'https://cdn.example.com/profile-1.jpg',
                  order: 0,
                ),
                ProfilePhoto(
                  id: 'photo-2',
                  url: 'https://cdn.example.com/profile-2.jpg',
                  order: 1,
                ),
              ],
              interests: ['Кофе'],
              intent: ['Друзья'],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(prewarmService.calls, isNotEmpty);
    final call = prewarmService.calls.first;
    expect(call.urls, [
      'https://cdn.example.com/profile-1.jpg',
      'https://cdn.example.com/profile-2.jpg',
    ]);
    expect(call.usageProfile, BbImageUsageProfile.hero);
    expect(call.limit, 3);
    expect(call.concurrency, 2);
  });

  testWidgets('read all clears unread indicator in notifications', (
    tester,
  ) async {
    late _FakeNotificationsRepository fakeRepository;
    var notifications = [
      NotificationItem(
        id: 'n1',
        kind: 'message',
        title: 'Новое сообщение',
        body: 'Аня К: Тогда до восьми у входа?',
        payload: const {'chatId': 'p1'},
        readAt: null,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        const NotificationsScreen(),
        extraOverrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => fakeRepository = _FakeNotificationsRepository(
              ref: ref,
              dio: Dio(),
              onMarkAllRead: () {
                notifications = notifications
                    .map(
                      (item) => item.copyWith(
                        readAt: item.readAt ?? DateTime.now(),
                      ),
                    )
                    .toList(growable: false);
              },
            ),
          ),
          notificationsProvider.overrideWith((ref) async => notifications),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-unread-dot-n1')),
      findsOneWidget,
    );

    await tester.tap(find.text('Всё'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-unread-dot-n1')),
      findsNothing,
    );
    expect(fakeRepository.markAllReadCalls, 1);
  });

  testWidgets('accept invite opens event detail after backend accepts', (
    tester,
  ) async {
    late _FakeNotificationsRepository fakeRepository;
    String? openedEventId;
    var notifications = [
      NotificationItem(
        id: 'n-invite',
        kind: 'event_invite',
        title: 'Приглашение',
        body: 'приглашает тебя на встречу',
        payload: const {
          'invite': true,
          'eventId': 'event-accepted',
          'requestId': 'request-accepted',
        },
        readAt: null,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      _wrapNotificationsRouter(
        onOpenedEvent: (eventId) => openedEventId = eventId,
        extraOverrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => fakeRepository = _FakeNotificationsRepository(
              ref: ref,
              dio: Dio(),
              onAcceptInvite: (eventId, requestId) {
                notifications = const [];
              },
            ),
          ),
          notificationsProvider.overrideWith((ref) async => notifications),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Принять'), findsOneWidget);
    expect(find.text('Отказаться'), findsOneWidget);

    await tester.tap(find.text('Принять'));
    await tester.pumpAndSettle();

    expect(fakeRepository.acceptInviteCalls, 1);
    expect(fakeRepository.acceptedEventId, 'event-accepted');
    expect(fakeRepository.acceptedRequestId, 'request-accepted');
    expect(openedEventId, 'event-accepted');
    expect(find.text('event:event-accepted'), findsOneWidget);
  });

  testWidgets('user profile more button opens moderation actions', (
    tester,
  ) async {
    await tester
        .pumpWidget(_wrap(const UserProfileScreen(userId: 'user-anya')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Пожаловаться'), findsOneWidget);
    expect(find.text('Заблокировать'), findsOneWidget);
  });

  testWidgets('public user profile uses v5 surface', (tester) async {
    await tester
        .pumpWidget(_wrap(const UserProfileScreen(userId: 'user-anya')));
    await tester.pumpAndSettle();

    expect(find.byType(BbV5Scaffold), findsOneWidget);
    expect(find.text('Профиль'), findsWidgets);
  });

  testWidgets('public user profile uses main profile sections', (tester) async {
    await tester
        .pumpWidget(_wrap(const UserProfileScreen(userId: 'user-anya')));
    await tester.pumpAndSettle();

    expect(find.text('Аня К, 27'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('История'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('История'), findsOneWidget);
    expect(find.text('Позвать на встречу'), findsOneWidget);
    expect(find.text('Написать'), findsOneWidget);
  });

  testWidgets('public user profile updates social stats optimistically',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrap(
        const UserProfileScreen(userId: 'user-anya'),
        extraOverrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _FakeSocialRepository(ref: ref),
          ),
          personProfileProvider.overrideWith(
            (ref, userId) async => const ProfileData(
              id: 'user-anya',
              displayName: 'Аня К',
              verified: true,
              online: true,
              age: 27,
              city: 'Москва',
              area: 'Чистые пруды',
              bio: 'Люблю камерные вечера и хорошие бары.',
              vibe: 'Спокойно',
              rating: 4.9,
              meetupCount: 23,
              avatarUrl: null,
              interests: ['Кофе'],
              intent: ['Свидания'],
              social: ProfileSocialData(
                followers: 248,
                likes: 1340,
                superLikes: 32,
                iFollow: false,
                iLike: false,
                iSuper: false,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-stat-followers')),
        matching: find.text('248'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Подписаться'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подписаться'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-stat-followers')),
        matching: find.text('249'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-stat-followers')),
        matching: find.text('248'),
      ),
      findsNothing,
    );
    expect(find.text('Подписан'), findsOneWidget);
  });

  testWidgets('public route for current user hides social actions and CTAs',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UserProfileScreen(userId: 'user-me'),
        extraOverrides: [
          currentUserIdProvider.overrideWith((ref) => 'user-me'),
          personProfileProvider.overrideWith(
            (ref, userId) async => const ProfileData(
              id: 'user-me',
              displayName: 'Никита М',
              verified: true,
              online: true,
              age: 28,
              city: 'Москва',
              area: 'Чистые пруды',
              bio: 'bio',
              vibe: 'Спокойно',
              rating: 4.8,
              meetupCount: 12,
              avatarUrl: null,
              interests: ['Кофе'],
              intent: ['Друзья'],
              social: ProfileSocialData(
                followers: 12,
                likes: 5,
                superLikes: 1,
                iFollow: false,
                iLike: false,
                iSuper: false,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подписчики'), findsNothing);
    expect(find.text('Подписаться'), findsNothing);
    expect(find.text('Позвать на встречу'), findsNothing);
    expect(find.text('Написать'), findsNothing);
    expect(find.text('Изменить'), findsOneWidget);
  });

  testWidgets('public user profile ignores stale body for another user',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const UserProfileScreen(userId: 'user-boris'),
        extraOverrides: [
          personProfileProvider.overrideWith(
            (ref, userId) async => const ProfileData(
              id: 'user-anya',
              displayName: 'Аня К',
              verified: true,
              online: true,
              age: 27,
              city: 'Москва',
              area: 'Чистые пруды',
              bio: 'Старое тело профиля',
              vibe: 'Спокойно',
              rating: 4.9,
              meetupCount: 23,
              avatarUrl: null,
              interests: ['Кофе'],
              intent: ['Друзья'],
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Аня К'), findsNothing);
    expect(find.text('Старое тело профиля'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
