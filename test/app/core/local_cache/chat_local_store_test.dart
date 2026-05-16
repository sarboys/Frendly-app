import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_database.dart';
import 'package:big_break_mobile/app/core/local_cache/chat_local_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalDatabase db;
  late ChatLocalStore store;
  final user = AppCacheUserScope.user('user-a');

  setUp(() {
    db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    store = ChatLocalStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('stores summaries by kind and reads newest first', () async {
    await store.upsertSummary(
      userScope: user,
      kind: ChatSummaryKind.meetup,
      chatId: 'chat-old',
      summaryJson: {'id': 'chat-old', 'title': 'Old'},
      updatedAt: DateTime.utc(2026, 5, 14, 10),
    );
    await store.upsertSummary(
      userScope: user,
      kind: ChatSummaryKind.meetup,
      chatId: 'chat-new',
      summaryJson: {'id': 'chat-new', 'title': 'New'},
      updatedAt: DateTime.utc(2026, 5, 14, 11),
    );

    final summaries = await store.readSummaries(
      userScope: user,
      kind: ChatSummaryKind.meetup,
    );

    expect(summaries.map((item) => item['id']), ['chat-new', 'chat-old']);
  });

  test('replaceSummariesForKind removes summaries missing from fresh list',
      () async {
    await store.upsertSummary(
      userScope: user,
      kind: ChatSummaryKind.meetup,
      chatId: 'chat-stale',
      summaryJson: {'id': 'chat-stale', 'title': 'Stale'},
      updatedAt: DateTime.utc(2026, 5, 14, 10),
    );
    await store.replaceSummariesForKind(
      userScope: user,
      kind: ChatSummaryKind.meetup,
      summaries: [
        ChatSummaryCachePayload(
          chatId: 'chat-fresh',
          summaryJson: {'id': 'chat-fresh', 'title': 'Fresh'},
          updatedAt: DateTime.utc(2026, 5, 14, 11),
        ),
      ],
    );

    final meetupSummaries = await store.readSummaries(
      userScope: user,
      kind: ChatSummaryKind.meetup,
    );

    expect(meetupSummaries.map((item) => item['id']), ['chat-fresh']);
  });

  test('merges messages by message id and client message id', () async {
    await store.upsertMessages(
      userScope: user,
      chatId: 'chat-1',
      messagesJson: [
        {
          'id': 'local-1',
          'chatId': 'chat-1',
          'clientMessageId': 'client-1',
          'text': 'pending',
          'createdAt': '2026-05-14T10:00:00.000Z',
          'isPending': true,
        },
      ],
    );
    await store.upsertMessages(
      userScope: user,
      chatId: 'chat-1',
      messagesJson: [
        {
          'id': 'server-1',
          'chatId': 'chat-1',
          'clientMessageId': 'client-1',
          'text': 'sent',
          'createdAt': '2026-05-14T10:00:01.000Z',
        },
        {
          'id': 'server-2',
          'chatId': 'chat-1',
          'clientMessageId': 'client-2',
          'text': 'next',
          'createdAt': '2026-05-14T10:00:02.000Z',
        },
      ],
    );

    final messages = await store.readRecentMessages(
      userScope: user,
      chatId: 'chat-1',
    );

    expect(messages.map((item) => item['id']), ['server-1', 'server-2']);
    expect(messages.first['text'], 'sent');
  });

  test('patches summaries and stores sync cursor', () async {
    await store.upsertSummary(
      userScope: user,
      kind: ChatSummaryKind.personal,
      chatId: 'chat-1',
      summaryJson: {
        'id': 'chat-1',
        'unread': 3,
        'typing': false,
      },
      updatedAt: DateTime.utc(2026, 5, 14, 10),
    );

    await store.patchSummary(
      userScope: user,
      chatId: 'chat-1',
      patch: (summary) => {
        ...summary,
        'unread': 0,
        'typing': true,
      },
    );
    await store.setSyncCursor(
      userScope: user,
      chatId: 'chat-1',
      cursor: 'event-42',
    );

    final summaries = await store.readSummaries(
      userScope: user,
      kind: ChatSummaryKind.personal,
    );

    expect(summaries.single['unread'], 0);
    expect(summaries.single['typing'], isTrue);
    expect(
      await store.readSyncCursor(userScope: user, chatId: 'chat-1'),
      'event-42',
    );
  });

  test('replaceRecentMessages resets the local window for a chat', () async {
    await store.upsertMessages(
      userScope: user,
      chatId: 'chat-1',
      messagesJson: [
        {
          'id': 'old',
          'chatId': 'chat-1',
          'createdAt': '2026-05-14T10:00:00.000Z',
        },
      ],
    );

    await store.replaceRecentMessages(
      userScope: user,
      chatId: 'chat-1',
      messagesJson: [
        {
          'id': 'new',
          'chatId': 'chat-1',
          'createdAt': '2026-05-14T10:01:00.000Z',
        },
      ],
    );

    final messages = await store.readRecentMessages(
      userScope: user,
      chatId: 'chat-1',
    );

    expect(messages.map((item) => item['id']), ['new']);
  });
}
