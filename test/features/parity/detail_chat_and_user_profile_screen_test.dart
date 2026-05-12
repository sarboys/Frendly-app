import 'dart:async';
import 'dart:io';

import 'package:big_break_mobile/app/core/device/app_attachment_service.dart';
import 'package:big_break_mobile/app/core/network/chat_socket_client.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/meetup_chat/presentation/meetup_chat_screen.dart';
import 'package:big_break_mobile/features/personal_chat/presentation/personal_chat_screen.dart';
import 'package:big_break_mobile/features/user_profile/presentation/user_profile_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/bb_chat_bubble.dart';
import 'package:big_break_mobile/shared/widgets/bb_social_actions.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/mock_data.dart';
import '../../test_overrides.dart';

class _FakeChatBackendRepository extends BackendRepository {
  _FakeChatBackendRepository({
    required super.ref,
    required super.dio,
    this.messagesByChat = const {},
    this.onCreateDirectChat,
  });

  final Map<String, List<Message>> messagesByChat;
  final String Function(String userId)? onCreateDirectChat;

  @override
  Future<PaginatedResponse<Message>> fetchMessages(
    String chatId, {
    String? cursor,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    final items = messagesByChat[chatId] ??
        (chatId == 'p1' ? mockPersonalMessages : mockMeetupMessages);
    return PaginatedResponse(items: items, nextCursor: null);
  }

  @override
  Future<void> markChatRead(String chatId, String messageId) async {}

  @override
  Future<String> createOrGetDirectChat(String userId) async {
    return onCreateDirectChat?.call(userId) ?? 'personal-$userId';
  }
}

class _FakeChatSocketClient extends ChatSocketClient {
  _FakeChatSocketClient()
      : _events = const Stream<Map<String, dynamic>>.empty(),
        super(accessTokenProvider: _token);

  final Stream<Map<String, dynamic>> _events;
  final sentTexts = <String>[];

  static Future<String> _token() async => 'token';

  @override
  Stream<Map<String, dynamic>> get events => _events;

  @override
  Future<void> connect() async {}

  @override
  void subscribe(String chatId) {}

  @override
  void unsubscribe(String chatId) {}

  @override
  void requestSync({required String chatId, String? sinceEventId}) {}

  @override
  Future<void> sendMessage({
    required String chatId,
    required String text,
    required String clientMessageId,
    List<String> attachmentIds = const [],
    String? replyToMessageId,
  }) async {
    sentTexts.add(text);
  }

  @override
  Future<void> dispose() async {}
}

class _SpyAttachmentService implements AppAttachmentService {
  var openCalls = 0;
  var saveCalls = 0;

  @override
  Future<File?> getLocalFileIfAvailable(MessageAttachment attachment) async {
    return null;
  }

  @override
  Future<String?> getDownloadUrl(MessageAttachment attachment) async {
    return attachment.url;
  }

  @override
  Future<File> getCachedFile(MessageAttachment attachment) async {
    throw UnimplementedError();
  }

  @override
  Future<void> openAttachment(MessageAttachment attachment) async {
    openCalls += 1;
  }

  @override
  Future<String> saveAttachmentToDevice(MessageAttachment attachment) async {
    saveCalls += 1;
    return '/tmp/${attachment.fileName}';
  }

  @override
  Future<void> clearPrivateCache() async {}

  @override
  Future<void> warmCache(MessageAttachment attachment) async {}
}

Widget _wrap(
  Widget child, {
  bool withChatOverrides = false,
  Map<String, List<Message>> messagesByChat = const {},
  String Function(String userId)? onCreateDirectChat,
  bool withPersonalChatRoute = false,
  List<Override> extraOverrides = const [],
}) {
  final scoped = ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      if (withChatOverrides)
        backendRepositoryProvider.overrideWith(
          (ref) => _FakeChatBackendRepository(
            ref: ref,
            dio: Dio(),
            messagesByChat: messagesByChat,
            onCreateDirectChat: onCreateDirectChat,
          ),
        ),
      if (withChatOverrides)
        chatSocketClientProvider.overrideWith((ref) => _FakeChatSocketClient()),
      ...extraOverrides,
    ],
    child: withPersonalChatRoute
        ? MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/test',
              routes: [
                GoRoute(
                  path: '/test',
                  builder: (context, state) => child,
                ),
                GoRoute(
                  path: AppRoute.personalChat.path,
                  name: AppRoute.personalChat.name,
                  builder: (context, state) => Text(
                    'personal ${state.pathParameters['chatId']}',
                    key: const Key('opened-personal-chat'),
                  ),
                ),
                GoRoute(
                  path: AppRoute.userProfile.path,
                  name: AppRoute.userProfile.name,
                  builder: (context, state) => Text(
                    'user ${state.pathParameters['userId']}',
                    key: const Key('opened-user-profile'),
                  ),
                ),
              ],
            ),
          )
        : MaterialApp(home: child),
  );
  return scoped;
}

Message _messageFromJson({
  required String id,
  required String chatId,
  required String text,
  required String createdAt,
  required String senderId,
  required String senderName,
  List<Map<String, dynamic>> attachments = const [],
}) {
  return Message.fromJson(
    {
      'id': id,
      'chatId': chatId,
      'clientMessageId': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': createdAt,
      'attachments': attachments,
    },
    currentUserId: 'user-me',
  );
}

void main() {
  testWidgets('meetup chat renders typing indicator for active meetup',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'mc1'),
        withChatOverrides: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.scrollUntilVisible(
      find.byKey(const Key('meetup-chat-typing-indicator')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
        find.byKey(const Key('meetup-chat-typing-indicator')), findsOneWidget);
  });

  testWidgets('meetup chat shows compact meetup capsule after scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'mc1'),
        withChatOverrides: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('meetup-chat-compact-capsule')), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.byKey(const Key('meetup-chat-compact-capsule')),
      findsOneWidget,
    );
    expect(find.text('Изм.'), findsOneWidget);
  });

  testWidgets('live evening meetup chat renders status and timeline pin',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'evening-chat-live'),
        withChatOverrides: true,
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'evening-chat-live',
                eventId: null,
                title: 'Теплый круг на Покровке',
                emoji: '✨',
                time: 'сегодня',
                lastMessage: 'Переходим к шагу',
                lastAuthor: 'Frendly',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Ты', 'Аня'],
                phase: MeetupPhase.live,
                currentStep: 2,
                totalSteps: 4,
                currentPlace: 'Brix Wine',
                routeId: 'r-cozy-circle',
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE · Шаг 2/4 · Brix Wine'), findsOneWidget);
    expect(find.byKey(const Key('meetup-chat-evening-pin')), findsOneWidget);
    expect(find.text('Открыть таймлайн'), findsOneWidget);
  });

  testWidgets('meetup chat renders paid ticket block from chat summary',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'chat-ticket'),
        withChatOverrides: true,
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'chat-ticket',
                eventId: 'e1',
                title: 'Кино под открытым небом',
                emoji: '🎬',
                time: '21:00',
                lastMessage: 'Берем билеты',
                lastAuthor: 'Маша',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Ты', 'Маша'],
                ticketUrl: 'https://tickets.example/show',
                ticketSourceKind: MeetupChatTicketSourceKind.affiche,
                ticketSourceId: 'affiche-1',
                ticketPriceFrom: 2500,
                ticketProvider: 'Ticketland',
                ticketVenue: 'Live Arena',
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Купить билет · от 2 500 ₽'), findsOneWidget);
    expect(find.text('Ticketland · Live Arena'), findsOneWidget);
    expect(find.byIcon(LucideIcons.ticket), findsWidgets);
  });

  testWidgets('soon evening meetup chat renders live start banner',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'evening-chat-soon'),
        withChatOverrides: true,
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'evening-chat-soon',
                eventId: null,
                title: 'Свидание Noir',
                emoji: '🎬',
                time: '20:00',
                lastMessage: 'Собираемся',
                lastAuthor: 'Frendly',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Ты', 'Аня'],
                phase: MeetupPhase.soon,
                startsInLabel: 'Через 45 мин',
                routeId: 'r-date-noir',
                hostUserId: 'user-me',
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Все на месте? Запусти live'), findsOneWidget);
    expect(
      find.text('Активирует таймлайн, чек-ины и перки для группы'),
      findsOneWidget,
    );
  });

  testWidgets('host evening meetup chat renders pending join requests',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'evening-chat-host'),
        withChatOverrides: true,
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'evening-chat-host',
                eventId: null,
                title: 'Теплый круг',
                emoji: '🍷',
                time: '20:00',
                lastMessage: 'Ждём гостей',
                lastAuthor: 'Frendly',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Ты', 'Аня'],
                phase: MeetupPhase.soon,
                routeId: 'r-cozy-circle',
                sessionId: 'session-host',
                hostUserId: 'user-me',
              ),
            ],
          ),
          eveningSessionProvider('session-host').overrideWith(
            (ref) async => _eveningDetailWithRequest(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заявки на вечер'), findsOneWidget);
    expect(find.text('Ира'), findsOneWidget);
    expect(find.text('Хочу присоединиться'), findsOneWidget);
    expect(find.text('Принять'), findsOneWidget);
    expect(find.text('Отклонить'), findsOneWidget);
  });

  testWidgets('host invite-only meetup chat renders copy invite link',
      (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>?)?['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'evening-chat-invite'),
        withChatOverrides: true,
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'evening-chat-invite',
                eventId: null,
                title: 'Закрытый круг',
                emoji: '🔒',
                time: '20:00',
                lastMessage: 'Ждём гостей',
                lastAuthor: 'Frendly',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Ты'],
                phase: MeetupPhase.soon,
                routeId: 'r-cozy-circle',
                sessionId: 'session-invite',
                hostUserId: 'user-me',
                privacy: EveningPrivacy.invite,
              ),
            ],
          ),
          eveningSessionProvider('session-invite').overrideWith(
            (ref) async => _eveningDetailWithInvite(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Инвайт-ссылка'), findsOneWidget);
    expect(
      find.text(
          'bigbreak://evening-preview/session-invite?inviteToken=secret-token'),
      findsOneWidget,
    );

    await tester.tap(find.text('Скопировать'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      copiedText,
      'bigbreak://evening-preview/session-invite?inviteToken=secret-token',
    );
    expect(find.text('Инвайт скопирован'), findsOneWidget);
  });

  testWidgets('soon evening meetup chat hides live start banner for guests',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'evening-chat-guest'),
        withChatOverrides: true,
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'evening-chat-guest',
                eventId: null,
                title: 'Свидание Noir',
                emoji: '🎬',
                time: '20:00',
                lastMessage: 'Собираемся',
                lastAuthor: 'Frendly',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Ты', 'Аня'],
                phase: MeetupPhase.soon,
                startsInLabel: 'Через 45 мин',
                routeId: 'r-date-noir',
                hostUserId: 'user-host',
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Все на месте? Запусти live'), findsNothing);
  });

  testWidgets(
      'soon evening meetup chat hides live start banner without host id',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'evening-chat-unknown-host'),
        withChatOverrides: true,
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'evening-chat-unknown-host',
                eventId: null,
                title: 'Свидание Noir',
                emoji: '🎬',
                time: '20:00',
                lastMessage: 'Собираемся',
                lastAuthor: 'Frendly',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Ты', 'Аня'],
                phase: MeetupPhase.soon,
                startsInLabel: 'Через 45 мин',
                routeId: 'r-date-noir',
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Все на месте? Запусти live'), findsNothing);
  });

  testWidgets('meetup chat members button opens participants sheet',
      (tester) async {
    String? requestedUserId;

    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'mc-members'),
        withChatOverrides: true,
        withPersonalChatRoute: true,
        onCreateDirectChat: (userId) {
          requestedUserId = userId;
          return 'p-sonya';
        },
        extraOverrides: [
          meetupChatsProvider.overrideWith(
            (ref) async => const [
              MeetupChat(
                id: 'mc-members',
                eventId: 'event-members',
                title: 'Вечерняя пробежка',
                emoji: '🏃',
                time: '20:00',
                lastMessage: 'Стартуем у входа',
                lastAuthor: 'Дима',
                lastTime: 'сейчас',
                unread: 0,
                members: ['Дима', 'Ты', 'Соня М', 'Олег'],
                memberProfiles: [
                  MeetupMember(
                    userId: 'user-dima',
                    name: 'Дима',
                    online: true,
                  ),
                  MeetupMember(
                    userId: 'user-me',
                    name: 'Сергей',
                    isCurrentUser: true,
                    online: true,
                  ),
                  MeetupMember(
                    userId: 'user-sonya',
                    name: 'Соня М',
                    social: ProfileSocialData(
                      followers: 5,
                      likes: 9,
                      superLikes: 1,
                      iFollow: true,
                      iLike: false,
                      iSuper: true,
                    ),
                  ),
                  MeetupMember(
                    userId: 'user-oleg',
                    name: 'Олег',
                  ),
                ],
                status: 'Сегодня',
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meetup-chat-members-button')));
    await tester.pumpAndSettle();

    expect(find.text('Участники'), findsOneWidget);
    expect(find.text('Вечерняя пробежка · 4'), findsOneWidget);
    expect(find.text('Найти участника'), findsOneWidget);
    expect(find.text('Пригласить друзей'), findsOneWidget);
    expect(find.text('Поделиться ссылкой на встречу'), findsOneWidget);
    expect(find.text('Дима'), findsWidgets);
    expect(find.text('Ты · ты'), findsOneWidget);
    expect(find.text('Соня М'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Олег'), findsOneWidget);
    expect(find.text('Организатор встречи'), findsOneWidget);
    expect(find.text('Участник'), findsWidgets);
    expect(
      find.text('Уважай других участников. Жалобы — в профиле.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('chat-member-message-user-sonya')));
    await tester.pumpAndSettle();

    expect(requestedUserId, 'user-sonya');
    expect(find.byKey(const Key('opened-personal-chat')), findsOneWidget);
  });

  testWidgets('personal chat does not render fake invite CTA or read receipt',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PersonalChatScreen(chatId: 'p1'),
        withChatOverrides: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Выбрать'), findsNothing);
    expect(find.textContaining('прочитано'), findsNothing);
  });

  testWidgets('incoming direct message author action opens public profile',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BbChatBubble(
              authorId: 'user-304f0edb-76db-439c-ae10-5b9a52f76da6',
              author: 'Пользователь 1111',
              text: 'stage50 incoming unread',
              time: '21:09',
              showAuthor: true,
              onAuthorAvatarTap: (userId) {
                context.pushRoute(
                  AppRoute.userProfile,
                  pathParameters: {'userId': userId},
                );
              },
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.userProfile.path,
          name: AppRoute.userProfile.name,
          builder: (context, state) => Text(
            'opened ${state.pathParameters['userId']}',
            key: const Key('opened-user-profile'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Пользователь 1111'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('opened-user-profile')), findsOneWidget);
    expect(
      find.text('opened user-304f0edb-76db-439c-ae10-5b9a52f76da6'),
      findsOneWidget,
    );
  });

  testWidgets('opening direct chat from profile keeps peer title',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/user/user-304f0edb-76db-439c-ae10-5b9a52f76da6',
      routes: [
        GoRoute(
          path: AppRoute.userProfile.path,
          name: AppRoute.userProfile.name,
          builder: (context, state) => UserProfileScreen(
            userId: state.pathParameters['userId']!,
          ),
        ),
        GoRoute(
          path: AppRoute.personalChat.path,
          name: AppRoute.personalChat.name,
          builder: (context, state) => PersonalChatScreen(
            chatId: state.pathParameters['chatId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          backendRepositoryProvider.overrideWith(
            (ref) => _FakeChatBackendRepository(
              ref: ref,
              dio: Dio(),
              messagesByChat: const {'direct-1111': []},
              onCreateDirectChat: (_) => 'direct-1111',
            ),
          ),
          chatSocketClientProvider.overrideWith(
            (ref) => _FakeChatSocketClient(),
          ),
          personalChatsProvider.overrideWith((ref) async => const []),
          personProfileProvider.overrideWith(
            (ref, userId) async => const ProfileData(
              id: 'user-304f0edb-76db-439c-ae10-5b9a52f76da6',
              displayName: 'Пользователь 1111',
              verified: true,
              online: true,
              age: 31,
              city: 'Москва',
              area: 'Центр',
              bio: '',
              vibe: 'Спокойно',
              rating: 0,
              meetupCount: 0,
              avatarUrl: null,
              interests: ['Кофе'],
              intent: ['Свидания'],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Написать'));
    await tester.pumpAndSettle();

    expect(find.text('Пользователь 1111'), findsOneWidget);
    expect(find.text('Личный чат'), findsNothing);
  });

  testWidgets('personal chat opens attachment action sheet from plus button',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PersonalChatScreen(chatId: 'p1'),
        withChatOverrides: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Прикрепить'));
    await tester.pumpAndSettle();

    expect(find.text('Что прикрепить'), findsOneWidget);
    expect(find.text('Фото'), findsOneWidget);
    expect(find.text('Файл'), findsOneWidget);
    expect(find.text('Геолокация'), findsOneWidget);
  });

  testWidgets('personal chat sends text through accessible send button',
      (tester) async {
    final socket = _FakeChatSocketClient();

    await tester.pumpWidget(
      _wrap(
        const PersonalChatScreen(chatId: 'p1'),
        withChatOverrides: true,
        extraOverrides: [
          chatSocketClientProvider.overrideWith((ref) => socket),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.bySemanticsLabel('Напиши или пригласи на встречу'),
      'qa retest text',
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Отправить сообщение'));
    await tester.pumpAndSettle();

    expect(socket.sentTexts, contains('qa retest text'));
  });

  testWidgets('meetup chat shows older messages above newer ones',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeetupChatScreen(chatId: 'mc-order'),
        withChatOverrides: true,
        messagesByChat: {
          'mc-order': [
            _messageFromJson(
              id: 'm-new',
              chatId: 'mc-order',
              text: 'Новый ответ',
              createdAt: '2026-04-20T21:09:00Z',
              senderId: 'u2',
              senderName: 'Аня К',
            ),
            _messageFromJson(
              id: 'm-old',
              chatId: 'mc-order',
              text: 'Старый ответ',
              createdAt: '2026-04-20T21:01:00Z',
              senderId: 'u1',
              senderName: 'Марк С',
            ),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    final olderOffset = tester.getTopLeft(find.text('Старый ответ'));
    final newerOffset = tester.getTopLeft(find.text('Новый ответ'));

    expect(olderOffset.dy, lessThan(newerOffset.dy));
  });

  testWidgets('personal chat tap on document saves it to device',
      (tester) async {
    final attachmentService = _SpyAttachmentService();

    await tester.pumpWidget(
      _wrap(
        const PersonalChatScreen(chatId: 'p-doc'),
        withChatOverrides: true,
        messagesByChat: {
          'p-doc': [
            _messageFromJson(
              id: 'doc-1',
              chatId: 'p-doc',
              text: 'contract.pdf',
              createdAt: '2026-04-20T21:09:00Z',
              senderId: 'u-doc',
              senderName: 'Аня К',
              attachments: const [
                {
                  'id': 'a-doc',
                  'kind': 'chat_attachment',
                  'status': 'ready',
                  'url': 'https://cdn.example.com/contract.pdf',
                  'mimeType': 'application/pdf',
                  'byteSize': 128,
                  'fileName': 'contract.pdf',
                },
              ],
            ),
          ],
        },
        extraOverrides: [
          appAttachmentServiceProvider.overrideWithValue(attachmentService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('contract.pdf'));
    await tester.pumpAndSettle();

    expect(attachmentService.saveCalls, 1);
    expect(attachmentService.openCalls, 0);
    expect(find.text('Файл сохранён на устройство'), findsOneWidget);
  });

  testWidgets('personal chat document download icon saves it to device',
      (tester) async {
    final attachmentService = _SpyAttachmentService();

    await tester.pumpWidget(
      _wrap(
        const PersonalChatScreen(chatId: 'p-doc'),
        withChatOverrides: true,
        messagesByChat: {
          'p-doc': [
            _messageFromJson(
              id: 'doc-1',
              chatId: 'p-doc',
              text: 'contract.zip',
              createdAt: '2026-04-20T21:09:00Z',
              senderId: 'user-me',
              senderName: 'Ты',
              attachments: const [
                {
                  'id': 'a-doc',
                  'kind': 'chat_attachment',
                  'status': 'ready',
                  'url': 'https://cdn.example.com/contract.zip',
                  'mimeType': 'application/zip',
                  'byteSize': 128,
                  'fileName': 'contract.zip',
                },
              ],
            ),
          ],
        },
        extraOverrides: [
          appAttachmentServiceProvider.overrideWithValue(attachmentService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Скачать contract.zip'));
    await tester.pumpAndSettle();

    expect(attachmentService.saveCalls, 1);
    expect(find.text('Файл сохранён на устройство'), findsOneWidget);
  });

  testWidgets('personal chat incoming text opens sender profile on tap',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PersonalChatScreen(chatId: 'p-profile'),
        withChatOverrides: true,
        withPersonalChatRoute: true,
        messagesByChat: {
          'p-profile': [
            _messageFromJson(
              id: 'incoming-1',
              chatId: 'p-profile',
              text: 'incoming hello',
              createdAt: '2026-04-20T21:09:00Z',
              senderId: 'user-anya',
              senderName: 'Аня К',
            ),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('incoming hello'));
    await tester.pumpAndSettle();

    expect(find.text('user user-anya'), findsOneWidget);
  });

  testWidgets('user profile renders common interests count', (tester) async {
    await tester.pumpWidget(
      _wrap(const UserProfileScreen(userId: 'user-anya')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('3 общих с тобой'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Вы вместе на встрече'), findsNothing);
    expect(find.text('3 общих с тобой'), findsOneWidget);
    expect(find.text('Позвать на встречу'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Позвать на встречу')).style?.fontWeight,
      FontWeight.w600,
    );
  });

  testWidgets('user profile keeps compact social actions without duplicate stats',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const UserProfileScreen(userId: 'user-anya')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подписчики'), findsNothing);
    expect(find.text('Лайков'), findsNothing);
    expect(find.text('Супер'), findsNothing);
    expect(find.text('Подписаться'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BbSocialActions),
        matching: find.byIcon(LucideIcons.heart),
      ),
      findsOneWidget,
    );
  });

  testWidgets('user profile bottom actions match front button styles',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const UserProfileScreen(userId: 'user-anya')),
    );
    await tester.pumpAndSettle();

    const states = <WidgetState>{};

    final inviteButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Позвать на встречу'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      inviteButton.style?.backgroundColor?.resolve(states),
      BbV5Colors.paperHi,
    );
    expect(
      inviteButton.style?.foregroundColor?.resolve(states),
      BbV5Colors.ink,
    );
    expect(
      inviteButton.style?.shape?.resolve(states),
      isA<StadiumBorder>(),
    );

    final messageButtonFinder = find.ancestor(
      of: find.text('Написать'),
      matching: find.byType(FilledButton),
    );
    expect(messageButtonFinder, findsOneWidget);

    final messageButton = tester.widget<FilledButton>(messageButtonFinder);
    expect(
      messageButton.style?.backgroundColor?.resolve(states),
      BbV5Colors.accent,
    );
    expect(
      messageButton.style?.foregroundColor?.resolve(states),
      BbV5Colors.paperHi,
    );
  });

  testWidgets(
      'user profile invite button label stays on one line on phone width',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(const UserProfileScreen(userId: 'user-anya')),
    );
    await tester.pumpAndSettle();

    final inviteLabel = find.text('Позвать на встречу');
    expect(inviteLabel, findsOneWidget);
    expect(tester.getSize(inviteLabel).height, lessThan(28));
  });
}

EveningSessionDetail _eveningDetailWithInvite() {
  return const EveningSessionDetail(
    id: 'session-invite',
    routeId: 'r-cozy-circle',
    chatId: 'evening-chat-invite',
    phase: EveningSessionPhase.scheduled,
    chatPhase: MeetupPhase.soon,
    privacy: EveningPrivacy.invite,
    title: 'Закрытый круг',
    vibe: 'Камерный вечер',
    emoji: '🔒',
    hostUserId: 'user-me',
    hostName: 'Ты',
    inviteToken: 'secret-token',
    participants: [
      EveningSessionParticipant(
        userId: 'user-me',
        name: 'Ты',
        role: 'host',
        status: 'joined',
      ),
    ],
    steps: [
      EveningSessionStep(
        id: 's1',
        time: '19:00',
        kind: 'bar',
        title: 'Аперитив',
        venue: 'Brix Wine',
        address: 'Покровка 12',
        emoji: '🍷',
      ),
    ],
  );
}

EveningSessionDetail _eveningDetailWithRequest() {
  return const EveningSessionDetail(
    id: 'session-host',
    routeId: 'r-cozy-circle',
    chatId: 'evening-chat-host',
    phase: EveningSessionPhase.scheduled,
    chatPhase: MeetupPhase.soon,
    privacy: EveningPrivacy.request,
    title: 'Теплый круг',
    vibe: 'Камерный вечер',
    emoji: '🍷',
    hostUserId: 'user-me',
    hostName: 'Ты',
    participants: [
      EveningSessionParticipant(
        userId: 'user-me',
        name: 'Ты',
        role: 'host',
        status: 'joined',
      ),
    ],
    steps: [
      EveningSessionStep(
        id: 's1',
        time: '19:00',
        kind: 'bar',
        title: 'Аперитив',
        venue: 'Brix Wine',
        address: 'Покровка 12',
        emoji: '🍷',
      ),
    ],
    pendingRequests: [
      EveningSessionJoinRequest(
        id: 'request-1',
        userId: 'user-ira',
        name: 'Ира',
        status: 'requested',
        note: 'Хочу присоединиться',
      ),
    ],
  );
}
