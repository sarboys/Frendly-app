import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/chats/presentation/chats_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

void main() {
  test('chats prewarm uses only the first ten preview images', () {
    final chats = List.generate(
      12,
      (index) => BackendChatSummary(
        id: 'chat-$index',
        title: 'Chat $index',
        imageUrl: 'https://cdn.test/chat-$index.jpg',
      ),
    );

    expect(chatPrewarmImageUrls(chats).toList(growable: false), [
      'https://cdn.test/chat-0.jpg',
      'https://cdn.test/chat-1.jpg',
      'https://cdn.test/chat-2.jpg',
      'https://cdn.test/chat-3.jpg',
      'https://cdn.test/chat-4.jpg',
      'https://cdn.test/chat-5.jpg',
      'https://cdn.test/chat-6.jpg',
      'https://cdn.test/chat-7.jpg',
      'https://cdn.test/chat-8.jpg',
      'https://cdn.test/chat-9.jpg',
    ]);
  });

  testWidgets('chats screen builds chat rows lazily', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final chats = List.generate(
      80,
      (index) => BackendChatSummary(
        id: 'chat-$index',
        title: 'Chat $index',
        subtitle: 'Message $index',
        raw: {
          'id': 'chat-$index',
          'title': 'Chat $index',
          'lastMessage': 'Message $index',
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenWalletProvider.overrideWith(
            (ref) async => const TokenWalletData(balance: 0),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          ownProfileProvider.overrideWith(
            (ref) async => const BackendCardItem(id: 'me', title: 'Me'),
          ),
          matchesProvider.overrideWith(
            (ref) => Stream.value(
              const BackendPage<BackendCardItem>(items: []),
            ),
          ),
          chatListRealtimeProvider(ChatListKind.all).overrideWith(
            (ref) => null,
          ),
          chatListProvider(ChatListKind.all).overrideWith(
            (ref) => Stream.value(BackendPage(items: chats)),
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const ChatsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Chat 0'), findsOneWidget);
    expect(find.text('Chat 79'), findsNothing);
  });

  testWidgets('chats screen renders backend chat preview metadata',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const chats = [
      BackendChatSummary(
        id: 'chat-1',
        title: 'Лия',
        subtitle: 'Окей, тогда в 19:30 у Brew Lab',
        unreadCount: 2,
        kind: 'personal',
        imageUrl: '/media/lia',
        raw: {
          'id': 'chat-1',
          'title': 'Лия',
          'lastMessage': 'Окей, тогда в 19:30 у Brew Lab',
          'lastTime': 'только что',
          'kind': 'personal',
          'fromMeetup': 'Speciality coffee',
        },
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenWalletProvider.overrideWith(
            (ref) async => const TokenWalletData(balance: 0),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          ownProfileProvider.overrideWith(
            (ref) async => const BackendCardItem(id: 'me', title: 'Me'),
          ),
          matchesProvider.overrideWith(
            (ref) => Stream.value(
              const BackendPage<BackendCardItem>(items: []),
            ),
          ),
          chatListRealtimeProvider(ChatListKind.all).overrideWith(
            (ref) => null,
          ),
          chatListProvider(ChatListKind.all).overrideWith(
            (ref) => Stream.value(const BackendPage(items: chats)),
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const ChatsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Лия'), findsOneWidget);
    expect(find.text('только что'), findsOneWidget);
    expect(find.text('SPECIALITY COFFEE'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('chats screen labels community chats as community',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const chats = [
      BackendChatSummary(
        id: 'community-chat-1',
        title: 'Паддл',
        kind: 'community',
        imageUrl: '/media/community',
        raw: {
          'id': 'community-chat-1',
          'title': 'Паддл',
          'kind': 'community',
          'communityId': 'community-1',
        },
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenWalletProvider.overrideWith(
            (ref) async => const TokenWalletData(balance: 0),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          ownProfileProvider.overrideWith(
            (ref) async => const BackendCardItem(id: 'me', title: 'Me'),
          ),
          matchesProvider.overrideWith(
            (ref) => Stream.value(
              const BackendPage<BackendCardItem>(items: []),
            ),
          ),
          chatListRealtimeProvider(ChatListKind.all).overrideWith(
            (ref) => null,
          ),
          chatListProvider(ChatListKind.all).overrideWith(
            (ref) => Stream.value(const BackendPage(items: chats)),
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const ChatsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Паддл'), findsOneWidget);
    expect(find.text('СООБЩЕСТВО'), findsOneWidget);
    expect(find.text('ВСТРЕЧА'), findsNothing);
  });

  testWidgets('chats screen exposes archive filter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenWalletProvider.overrideWith(
            (ref) async => const TokenWalletData(balance: 0),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          ownProfileProvider.overrideWith(
            (ref) async => const BackendCardItem(id: 'me', title: 'Me'),
          ),
          matchesProvider.overrideWith(
            (ref) => Stream.value(
              const BackendPage<BackendCardItem>(items: []),
            ),
          ),
          chatListRealtimeProvider(ChatListKind.all).overrideWith(
            (ref) => null,
          ),
          chatListProvider(ChatListKind.all).overrideWith(
            (ref) => Stream.value(
              const BackendPage<BackendChatSummary>(items: []),
            ),
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const ChatsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Архив'), findsOneWidget);
  });

  test('chat list puts new empty chats above older message chats', () async {
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWithValue(
          _FakeChatRepository(
            meetupChats: const BackendPage(
              items: [
                BackendChatSummary(
                  id: 'message-old',
                  title: 'Старый чат с сообщением',
                  raw: {
                    'id': 'message-old',
                    'title': 'Старый чат с сообщением',
                    'kind': 'meetup',
                    'lastMessageId': 'message-1',
                    'lastMessage': 'Привет',
                    'lastMessageAt': '2026-05-01T10:00:00.000Z',
                    'updatedAt': '2026-05-01T10:00:00.000Z',
                  },
                ),
                BackendChatSummary(
                  id: 'empty-new',
                  title: 'Новый пустой чат',
                  raw: {
                    'id': 'empty-new',
                    'title': 'Новый пустой чат',
                    'kind': 'meetup',
                    'lastMessageAt': null,
                    'updatedAt': '2026-05-02T10:00:00.000Z',
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final page =
        await container.read(chatListProvider(ChatListKind.all).future);

    expect(page.items.map((item) => item.id), ['empty-new', 'message-old']);
  });

  test('chat list moves done meetup chats into archive', () async {
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWithValue(
          _FakeChatRepository(
            meetupChats: const BackendPage(
              items: [
                BackendChatSummary(
                  id: 'active-meetup',
                  title: 'Активная встреча',
                  raw: {
                    'id': 'active-meetup',
                    'title': 'Активная встреча',
                    'kind': 'meetup',
                    'phase': 'upcoming',
                    'updatedAt': '2026-05-02T10:00:00.000Z',
                  },
                ),
                BackendChatSummary(
                  id: 'done-meetup',
                  title: 'Прошедшая встреча',
                  raw: {
                    'id': 'done-meetup',
                    'title': 'Прошедшая встреча',
                    'kind': 'meetup',
                    'phase': 'done',
                    'updatedAt': '2026-05-03T10:00:00.000Z',
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final active =
        await container.read(chatListProvider(ChatListKind.all).future);
    final archive =
        await container.read(chatListProvider(ChatListKind.archive).future);

    expect(active.items.map((item) => item.id), ['active-meetup']);
    expect(archive.items.map((item) => item.id), ['done-meetup']);
  });

  testWidgets('chats screen renders meeting and personal preview images',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const chats = [
      BackendChatSummary(
        id: 'meetup-1',
        title: 'Кофе на Патриках',
        subtitle: 'До встречи',
        kind: 'meetup',
        raw: {
          'id': 'meetup-1',
          'title': 'Кофе на Патриках',
          'kind': 'meetup',
          'coverImageUrl': 'https://cdn.example.com/meeting-cover.jpg',
        },
      ),
      BackendChatSummary(
        id: 'personal-1',
        title: 'Лия',
        subtitle: 'Я уже рядом',
        kind: 'personal',
        raw: {
          'id': 'personal-1',
          'title': 'Лия',
          'kind': 'personal',
          'memberProfiles': [
            {
              'userId': 'u-lia',
              'name': 'Лия',
              'avatarUrl': 'https://cdn.example.com/lia-avatar.jpg',
            },
          ],
        },
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenWalletProvider.overrideWith(
            (ref) async => const TokenWalletData(balance: 0),
          ),
          notificationUnreadCountProvider.overrideWith((ref) async => 0),
          ownProfileProvider.overrideWith(
            (ref) async => const BackendCardItem(id: 'me', title: 'Me'),
          ),
          matchesProvider.overrideWith(
            (ref) => Stream.value(
              const BackendPage<BackendCardItem>(items: []),
            ),
          ),
          chatListRealtimeProvider(ChatListKind.all).overrideWith(
            (ref) => null,
          ),
          chatListProvider(ChatListKind.all).overrideWith(
            (ref) => Stream.value(const BackendPage(items: chats)),
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const ChatsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final imageUrls = tester
        .widgetList<DateasyRemoteImage>(find.byType(DateasyRemoteImage))
        .map((widget) => widget.imageUrl)
        .toSet();

    expect(imageUrls, contains('https://cdn.example.com/meeting-cover.jpg'));
    expect(imageUrls, contains('https://cdn.example.com/lia-avatar.jpg'));
  });
}

class _FakeChatRepository extends BackendRepository {
  _FakeChatRepository({
    required this.meetupChats,
  }) : super(Dio());

  final BackendPage<BackendChatSummary> meetupChats;

  @override
  Future<BackendPage<BackendChatSummary>> fetchMeetupChats({
    CancelToken? cancelToken,
  }) async {
    return meetupChats;
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchPersonalChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchCommunityChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }
}
