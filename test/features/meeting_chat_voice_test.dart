import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/device/app_voice_recorder_service.dart';
import 'package:mobile2/app/core/local_cache/app_local_database.dart';
import 'package:mobile2/app/core/local_cache/chat_local_store.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/device/app_attachment_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/app/core/network/chat_socket_client.dart';
import 'package:mobile2/features/chats/presentation/chat_voice_playback_controller.dart';
import 'package:mobile2/features/chats/presentation/meeting_chat_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_keyboard_dismiss.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

void main() {
  testWidgets('voice attachments do not render the audio file name as text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_VoiceChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('dateasy-voice-1779186240895879.m4a'), findsNothing);
    expect(find.text('0:03'), findsOneWidget);
  });

  testWidgets('image attachments open fullscreen preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_ImageChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DateasyRemoteImage &&
            widget.imageUrl == 'https://cdn.test/photo-1.jpg',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('voice attachments start from signed URL without waiting cache',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final engine = _FakeVoiceEngine();
    final signedPaths = <String>[];
    final cacheCompleter = Completer<String>();
    final attachmentService = AppAttachmentService(
      fetchSignedUrl: (path) async {
        signedPaths.add(path);
        return SignedMediaUrl(
          url: 'https://cdn.test/voice-1.m4a',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
      },
      fetchFile: (_, __) async {},
      cacheFile: (_, __) => cacheCompleter.future,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_VoiceChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
          appAttachmentServiceProvider.overrideWithValue(attachmentService),
          chatVoicePlaybackEngineFactoryProvider
              .overrideWithValue(() => engine),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('0:03'));
    await tester.pump(const Duration(milliseconds: 20));

    expect(signedPaths, ['/media/voice-1/download-url']);
    expect(engine.loadedUrls, ['https://cdn.test/voice-1.m4a']);
    expect(engine.loadedFilePaths, isEmpty);
  });

  testWidgets('text message appears immediately without local cache',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final transport = _HangingChatTransport();
    addTearDown(transport.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_VoiceChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
          initialAuthTokensProvider.overrideWithValue(
            const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(id: 'user-1', name: 'Вы'),
          ),
          chatSocketTransportFactoryProvider.overrideWithValue(
            (_) => transport,
          ),
          chatMediaUploadQueueProvider.overrideWithValue(null),
          chatSocketTransportFactoryProvider.overrideWithValue(
            (_) => _AckChatTransport(),
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Привет',
    );
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('Отправляется'), findsOneWidget);
    await transport.close();
    await tester.pump();
  });

  test('voice send writes optimistic message without local cache', () async {
    final tempDir = await Directory.systemTemp.createTemp('voice-send-test');
    final voiceFile = File('${tempDir.path}/voice.m4a');
    await voiceFile.writeAsString('voice');
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWithValue(
          _HangingUploadChatRepository(),
        ),
        appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        initialAuthTokensProvider.overrideWithValue(
          const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
        ),
        currentUserProvider.overrideWith(
          (_) => const BackendUser(id: 'user-1', name: 'Вы'),
        ),
        chatMediaUploadQueueProvider.overrideWithValue(null),
        chatSocketTransportFactoryProvider.overrideWithValue(
          (_) => _AckChatTransport(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final optimisticSubscription = container.listen(
      chatOptimisticMessagesProvider('coffee'),
      (_, __) {},
    );
    addTearDown(optimisticSubscription.close);

    final sendFuture = container.read(chatMessageSenderProvider).sendAttachment(
      chatId: 'coffee',
      filePath: voiceFile.path,
      fileName: 'voice.m4a',
      mimeType: 'audio/mp4',
      kind: 'chat_voice',
      durationMs: 3000,
      waveform: const [0.2, 0.6, 0.4],
    );
    unawaited(sendFuture);
    await Future<void>.delayed(Duration.zero);

    final messages = container.read(chatOptimisticMessagesProvider('coffee'));
    expect(messages, hasLength(1));
    expect(messages.single.raw['status'], 'uploading');
    expect(
      (messages.single.raw['attachments'] as List).single,
      containsPair('localPath', voiceFile.path),
    );
    await sendFuture;
  });

  testWidgets('text composer keeps keyboard focus after send', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final transport = _HangingChatTransport();
    addTearDown(transport.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_VoiceChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
          initialAuthTokensProvider.overrideWithValue(
            const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(id: 'user-1', name: 'Вы'),
          ),
          chatSocketTransportFactoryProvider.overrideWithValue(
            (_) => transport,
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const DateasyKeyboardDismiss(
            child: MeetingChatScreen(meetingId: 'coffee'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Привет');
    await tester.pump();
    final focusedBeforeSend = FocusManager.instance.primaryFocus;

    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump(const Duration(milliseconds: 50));

    expect(focusedBeforeSend, isNotNull);
    expect(FocusManager.instance.primaryFocus, same(focusedBeforeSend));
    await transport.close();
    await tester.pump();
  });

  testWidgets('local text message appears immediately while socket hangs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    final store = ChatLocalStore(database);
    final transport = _HangingChatTransport();
    addTearDown(() async {
      await transport.close();
      await database.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_EmptyChatRepository()),
          chatLocalStoreProvider.overrideWithValue(store),
          initialAuthTokensProvider.overrideWithValue(
            const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(id: 'user-1', name: 'Вы'),
          ),
          chatSocketTransportFactoryProvider.overrideWithValue(
            (_) => transport,
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Привет сразу');
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump();

    expect(find.text('Привет сразу'), findsOneWidget);
    expect(find.text('Отправляется'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('failed text bubble retries with the same client message id',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    final store = ChatLocalStore(database);
    addTearDown(database.close);
    await store.upsertMessages(
      userId: 'user-1',
      chatId: 'coffee',
      messages: [
        {
          'id': 'mobile2-fixed-id',
          'chatId': 'coffee',
          'text': 'Не дошло',
          'clientMessageId': 'mobile2-fixed-id',
          'sender': {'displayName': 'Вы'},
          'createdAt': DateTime(2026, 5, 19, 17, 24).toIso8601String(),
          'pending': true,
          'mine': true,
          'status': 'failed',
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_EmptyChatRepository()),
          chatLocalStoreProvider.overrideWithValue(store),
          initialAuthTokensProvider.overrideWithValue(
            const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(id: 'user-1', name: 'Вы'),
          ),
          chatRealtimeProvider('coffee').overrideWith((_) => null),
          chatMediaUploadQueueProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не дошло'), findsOneWidget);
    expect(find.text('Не отправлено · повторить'), findsOneWidget);

    await tester.tap(find.text('Не отправлено · повторить'));
    await tester.pump(const Duration(milliseconds: 50));

    final commands = await store.pendingCommands(userId: 'user-1');
    expect(commands, hasLength(1));
    expect(commands.single['type'], 'message.send');
    expect((commands.single['payload'] as Map)['clientMessageId'],
        'mobile2-fixed-id');
    expect(find.text('Отправляется'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('holding mic starts live recording state', (tester) async {
    final database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    final store = ChatLocalStore(database);
    final recorder = _FakeRecorderService();
    addTearDown(() async {
      await database.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_EmptyChatRepository()),
          chatLocalStoreProvider.overrideWithValue(store),
          appVoiceRecorderServiceProvider.overrideWithValue(recorder),
          initialAuthTokensProvider.overrideWithValue(
            const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(id: 'user-1', name: 'Вы'),
          ),
          chatRealtimeProvider('coffee').overrideWith((_) => null),
          chatMediaUploadQueueProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final mic = find.byKey(const ValueKey('chat_voice_send_button'));
    final gesture = await tester.startGesture(tester.getCenter(mic));
    await tester.pump(const Duration(milliseconds: 120));

    expect(recorder.started, true);
    expect(find.text('Идет запись'), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    await gesture.cancel();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('long press message opens reply actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_ActionChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Свое сообщение'));
    await tester.pumpAndSettle();

    expect(find.text('Ответить'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Сообщение Лии'));
    await tester.pumpAndSettle();

    expect(find.text('Ответить'), findsOneWidget);
    expect(find.text('Удалить'), findsNothing);
  });

  testWidgets('swipe left starts reply draft', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_ActionChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Сообщение Лии'), const Offset(-140, 0));
    await tester.pumpAndSettle();

    expect(find.text('Ответ Лия'), findsOneWidget);
    expect(find.text('Сообщение Лии'), findsWidgets);
  });

  testWidgets('reply send keeps target message id in outbox', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    final store = ChatLocalStore(database);
    addTearDown(database.close);
    await store.upsertMessages(
      userId: 'user-1',
      chatId: 'coffee',
      messages: [
        {
          'id': 'm-lia',
          'chatId': 'coffee',
          'text': 'Сообщение Лии',
          'senderId': 'u-lia',
          'senderName': 'Лия',
          'createdAt': DateTime(2026, 5, 19, 17, 20).toIso8601String(),
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_EmptyChatRepository()),
          chatLocalStoreProvider.overrideWithValue(store),
          initialAuthTokensProvider.overrideWithValue(
            const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(id: 'user-1', name: 'Вы'),
          ),
          chatRealtimeProvider('coffee').overrideWith((_) => null),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Сообщение Лии'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ответить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ответ');
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump();

    final commands = await store.pendingCommands(userId: 'user-1');
    final send = commands.singleWhere((item) => item['type'] == 'message.send');
    expect((send['payload'] as Map)['replyToMessageId'], 'm-lia');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('delete own message removes it locally and sends delete command',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    final store = ChatLocalStore(database);
    addTearDown(database.close);
    await store.upsertMessages(
      userId: 'user-1',
      chatId: 'coffee',
      messages: [
        {
          'id': 'm-own',
          'chatId': 'coffee',
          'text': 'Удаляемое сообщение',
          'senderId': 'user-1',
          'senderName': 'Вы',
          'mine': true,
          'createdAt': DateTime(2026, 5, 19, 17, 22).toIso8601String(),
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_EmptyChatRepository()),
          chatLocalStoreProvider.overrideWithValue(store),
          initialAuthTokensProvider.overrideWithValue(
            const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
          ),
          currentUserProvider.overrideWith(
            (_) => const BackendUser(id: 'user-1', name: 'Вы'),
          ),
          chatRealtimeProvider('coffee').overrideWith((_) => null),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Удаляемое сообщение'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удаляемое сообщение'), findsNothing);
    final commands = await store.pendingCommands(userId: 'user-1');
    final delete =
        commands.singleWhere((item) => item['type'] == 'message.delete');
    expect((delete['payload'] as Map)['messageId'], 'm-own');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _VoiceChatRepository extends BackendRepository {
  _VoiceChatRepository() : super(Dio());

  @override
  Future<BackendPage<BackendChatSummary>> fetchMeetupChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(
      items: [
        BackendChatSummary(
          id: 'coffee',
          title: 'Speciality coffee tasting',
          kind: 'meetup',
          raw: {
            'id': 'coffee',
            'title': 'Speciality coffee tasting',
            'kind': 'meetup',
            'eventId': 'coffee',
            'status': 'Сегодня',
            'time': '19:30',
            'contextLine': 'Brew Lab, Патрики',
            'memberProfiles': [
              {'userId': 'u-lia', 'name': 'Лия', 'online': true},
              {'userId': 'user-1', 'name': 'Вы', 'online': true},
            ],
          },
        ),
      ],
    );
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchPersonalChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendChatMessage(
          id: 'voice-message-1',
          chatId: chatId,
          text: '',
          senderId: 'user-1',
          senderName: 'Вы',
          createdAt: DateTime(2026, 5, 19, 17, 24),
          raw: {
            'mine': true,
            'attachments': [
              {
                'id': 'voice-1',
                'kind': 'chat_voice',
                'fileName': 'dateasy-voice-1779186240895879.m4a',
                'mimeType': 'audio/mp4',
                'durationMs': 3000,
                'waveform': [0.18, 0.46, 0.82, 0.35],
                'url': '/media/voice-1',
                'downloadUrlPath': '/media/voice-1/download-url',
              },
            ],
          },
        ),
      ],
    );
  }
}

class _ImageChatRepository extends _VoiceChatRepository {
  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendChatMessage(
          id: 'image-message-1',
          chatId: chatId,
          text: '',
          senderId: 'user-1',
          senderName: 'Вы',
          createdAt: DateTime(2026, 5, 19, 17, 24),
          raw: {
            'mine': true,
            'attachments': [
              {
                'id': 'image-1',
                'kind': 'image',
                'fileName': 'photo-1.jpg',
                'mimeType': 'image/jpeg',
                'downloadUrl': 'https://cdn.test/photo-1.jpg',
              },
            ],
          },
        ),
      ],
    );
  }
}

class _EmptyChatRepository extends _VoiceChatRepository {
  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }
}

class _HangingUploadChatRepository extends _EmptyChatRepository {
  @override
  Future<Map<String, Object?>> uploadChatAttachmentFile({
    required String chatId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String kind = 'chat_attachment',
    int? durationMs,
    List<double> waveform = const [],
    CancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return {
      'assetId': 'voice-asset-1',
      'status': 'ready',
    };
  }
}

class _ActionChatRepository extends _VoiceChatRepository {
  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendChatMessage(
          id: 'm-lia',
          chatId: chatId,
          text: 'Сообщение Лии',
          senderId: 'u-lia',
          senderName: 'Лия',
          createdAt: DateTime(2026, 5, 19, 17, 20),
        ),
        BackendChatMessage(
          id: 'm-own',
          chatId: chatId,
          text: 'Свое сообщение',
          senderId: 'user-1',
          senderName: 'Вы',
          createdAt: DateTime(2026, 5, 19, 17, 22),
          raw: const {'mine': true},
        ),
      ],
    );
  }
}

class _FakeVoiceEngine implements ChatVoicePlaybackEngine {
  final loadedUrls = <String>[];
  final loadedFilePaths = <String>[];

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _stateController = StreamController<ChatVoiceEngineState>.broadcast();

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<ChatVoiceEngineState> get playbackStateStream =>
      _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _stateController.close();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    _stateController.add(
      const ChatVoiceEngineState(
        playing: true,
        processingState: ProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setUrl(String url) async {
    loadedUrls.add(url);
  }

  @override
  Future<void> setFilePath(String path) async {
    loadedFilePaths.add(path);
  }

  @override
  Future<void> stop() async {}
}

class _HangingChatTransport implements ChatSocketTransport {
  final _controller = StreamController<Object?>.broadcast();
  var _closed = false;

  @override
  Stream<Object?> get stream => _controller.stream;

  @override
  void send(String data) {
    if (data.contains('session.authenticate')) {
      _controller.add({'type': 'session.authenticated'});
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _controller.close();
  }
}

class _AckChatTransport implements ChatSocketTransport {
  final _controller = StreamController<Object?>.broadcast();
  var _closed = false;

  @override
  Stream<Object?> get stream => _controller.stream;

  @override
  void send(String data) {
    final decoded = jsonDecode(data);
    if (decoded is! Map) {
      return;
    }
    final type = decoded['type']?.toString();
    final payload = decoded['payload'];
    if (type == 'session.authenticate') {
      _controller.add({'type': 'session.authenticated'});
      return;
    }
    if (type == 'message.send' && payload is Map) {
      _controller.add({
        'type': 'message.created',
        'payload': {
          'chatId': payload['chatId'],
          'clientMessageId': payload['clientMessageId'],
        },
      });
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _controller.close();
  }
}

class _FakeRecorderService implements AppVoiceRecorderService {
  final _amplitudeController = StreamController<double>.broadcast();
  RecordedVoiceDraft? voice;
  var started = false;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<void> cancel() async {
    started = false;
  }

  @override
  Future<void> dispose() async {
    await _amplitudeController.close();
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {
    started = true;
    _amplitudeController.add(0.25);
    _amplitudeController.add(0.75);
  }

  @override
  Future<RecordedVoiceDraft> stop() async {
    started = false;
    return voice!;
  }
}
