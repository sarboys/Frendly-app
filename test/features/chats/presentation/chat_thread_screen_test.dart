import 'dart:io';

import 'package:big_break_mobile/features/chats/presentation/chat_thread_screen.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat thread does not keep a GlobalKey per message', () {
    final source = File(
      'lib/features/chats/presentation/chat_thread_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Map<String, GlobalKey>')));
    expect(source, isNot(contains('_messageKeys')));
  });

  test('meetup chat scrolls the large pinned card with thread content', () {
    final source = File(
      'lib/features/meetup_chat/presentation/meetup_chat_screen.dart',
    ).readAsStringSync();

    expect(source, contains('scrollTopContent: true'));
  });

  test('meetup chat lets the header cover the top safe area', () {
    final source = File(
      'lib/features/meetup_chat/presentation/meetup_chat_screen.dart',
    ).readAsStringSync();

    expect(source, contains('headerCoversTopSafeArea: true'));
  });

  testWidgets('chat scrolls to bottom after sending my message',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: _ChatHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('test-send-message')));
    await tester.pumpAndSettle();

    expect(find.text('Новое сообщение'), findsOneWidget);
  });

  testWidgets(
      'chat keeps latest incoming message visible when already at bottom',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: _ChatHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('test-add-incoming-message')));
    await tester.pumpAndSettle();

    final incoming = find.text('Новое входящее');
    expect(incoming, findsOneWidget);
    expect(tester.getBottomLeft(incoming).dy, lessThan(560));
  });

  testWidgets('tap on reply quote scrolls to original message', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _ChatHarness(
            initialMessages: [
              _message(
                id: 'original',
                text: 'Оригинал сообщения',
                mine: false,
              ),
              for (var index = 0; index < 32; index++)
                _message(
                  id: 'filler-$index',
                  text: 'Промежуточное $index',
                  mine: index.isEven,
                ),
              _message(
                id: 'reply',
                text: 'Ответ на старое',
                mine: true,
                replyTo: const MessageReplyPreview(
                  id: 'original',
                  author: 'Аня',
                  text: 'Оригинал сообщения',
                  isVoice: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Ответ на старое'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bb-chat-reply-quote-other')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-message-original')), findsOneWidget);
  });

  testWidgets('tap on incoming avatar reports author id', (tester) async {
    String? tappedUserId;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _ChatHarness(
            initialMessages: [
              _message(
                id: 'incoming',
                text: 'Привет',
                mine: false,
                showAvatar: true,
                authorAvatarUrl: 'https://cdn.example.com/anya.jpg',
              ),
            ],
            onAuthorAvatarTap: (userId) {
              tappedUserId = userId;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = tester.widget<BbAvatar>(find.byType(BbAvatar));
    expect(avatar.imageUrl, 'https://cdn.example.com/anya.jpg');

    await tester.tap(find.byType(BbAvatar));
    expect(tappedUserId, 'user-anya');
  });

  testWidgets('chat asks to load older messages near top after user scroll',
      (tester) async {
    var loadOlderCalls = 0;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _ChatHarness(
            onLoadOlderMessages: () async {
              loadOlderCalls += 1;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < 8 && loadOlderCalls == 0; index += 1) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 700));
      await tester.pumpAndSettle();
    }

    expect(loadOlderCalls, 1);
  });

  testWidgets('system messages render as centered pills', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _ChatHarness(
            initialMessages: [
              _message(
                id: 'system-1',
                text: 'Вечер начался',
                mine: false,
                isSystem: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('chat-system-message-system-1')), findsOneWidget);
    expect(find.byType(BbAvatar), findsNothing);
  });
}

class _ChatHarness extends StatefulWidget {
  const _ChatHarness({
    this.initialMessages,
    this.onAuthorAvatarTap,
    this.onLoadOlderMessages,
  });

  final List<Message>? initialMessages;
  final void Function(String userId)? onAuthorAvatarTap;
  final Future<void> Function()? onLoadOlderMessages;

  @override
  State<_ChatHarness> createState() => _ChatHarnessState();
}

class _ChatHarnessState extends State<_ChatHarness> {
  late List<Message> _messages = widget.initialMessages ?? _defaultMessages();

  @override
  Widget build(BuildContext context) {
    return ChatThreadScreen(
      header: const SizedBox(height: 48),
      messagesAsync: AsyncValue.data(_messages),
      composer: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              key: const Key('test-send-message'),
              onPressed: () {
                setState(() {
                  _messages = [
                    ..._messages,
                    _message(
                      id: 'new-message',
                      text: 'Новое сообщение',
                      mine: true,
                    ),
                  ];
                });
              },
              child: const Text('send'),
            ),
            TextButton(
              key: const Key('test-add-incoming-message'),
              onPressed: () {
                setState(() {
                  _messages = [
                    ..._messages,
                    _message(
                      id: 'new-incoming-message',
                      text: 'Новое входящее',
                      mine: false,
                    ),
                  ];
                });
              },
              child: const Text('incoming'),
            ),
          ],
        ),
      ),
      onMessageReply: (_) {},
      onMessageLongPress: (_) async {},
      onAttachmentTap: (_) async {},
      onAttachmentDownloadTap: (_) async {},
      onVoiceResolvePath: (_) async => null,
      onVoiceResolveRemoteUrl: (_) async => null,
      onAuthorAvatarTap: widget.onAuthorAvatarTap,
      onLoadOlderMessages: widget.onLoadOlderMessages,
    );
  }

  List<Message> _defaultMessages() {
    return [
      for (var index = 0; index < 36; index++)
        _message(
          id: 'message-$index',
          text: 'Сообщение $index',
          mine: index.isEven,
        ),
    ];
  }
}

Message _message({
  required String id,
  required String text,
  required bool mine,
  MessageReplyPreview? replyTo,
  bool showAvatar = false,
  String? authorAvatarUrl,
  bool isSystem = false,
}) {
  return Message(
    id: id,
    chatId: 'chat-test',
    clientMessageId: id,
    authorId: mine ? 'user-me' : 'user-anya',
    author: mine ? 'Ты' : 'Аня',
    text: text,
    time: '12:33',
    mine: mine,
    attachments: const [],
    replyTo: replyTo,
    showAvatar: showAvatar,
    authorAvatarUrl: authorAvatarUrl,
    isSystem: isSystem,
  );
}
