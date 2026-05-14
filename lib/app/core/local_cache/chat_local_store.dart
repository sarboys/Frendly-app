import 'dart:convert';

import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_database.dart';
import 'package:drift/drift.dart';

enum ChatSummaryKind {
  meetup('meetup'),
  personal('personal'),
  community('community');

  const ChatSummaryKind(this.value);

  final String value;
}

class ChatLocalStore {
  ChatLocalStore(
    this._database, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppLocalDatabase _database;
  final DateTime Function() _now;

  Future<void> upsertSummary({
    required AppCacheUserScope userScope,
    required ChatSummaryKind kind,
    required String chatId,
    required Map<String, dynamic> summaryJson,
    required DateTime updatedAt,
  }) async {
    await _database.into(_database.chatSummaries).insertOnConflictUpdate(
          ChatSummariesCompanion.insert(
            userId: userScope.storageId,
            chatId: chatId,
            chatKind: kind.value,
            summaryJson: jsonEncode(summaryJson),
            updatedAt: updatedAt,
            fetchedAt: _now(),
          ),
        );
  }

  Future<List<Map<String, dynamic>>> readSummaries({
    required AppCacheUserScope userScope,
    ChatSummaryKind? kind,
  }) async {
    final query = _database.select(_database.chatSummaries)
      ..where((table) => table.userId.equals(userScope.storageId))
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAt),
        (table) => OrderingTerm.asc(table.chatId),
      ]);
    if (kind != null) {
      query.where((table) => table.chatKind.equals(kind.value));
    }

    final rows = await query.get();
    return rows
        .map((row) => Map<String, dynamic>.from(jsonDecode(row.summaryJson)))
        .toList(growable: false);
  }

  Future<void> patchSummary({
    required AppCacheUserScope userScope,
    required String chatId,
    required Map<String, dynamic> Function(Map<String, dynamic> summary) patch,
  }) async {
    final row = await (_database.select(_database.chatSummaries)
          ..where(
            (table) =>
                table.userId.equals(userScope.storageId) &
                table.chatId.equals(chatId),
          ))
        .getSingleOrNull();
    if (row == null) {
      return;
    }

    final current = Map<String, dynamic>.from(jsonDecode(row.summaryJson));
    final next = patch(current);
    await (_database.update(_database.chatSummaries)
          ..where(
            (table) =>
                table.userId.equals(userScope.storageId) &
                table.chatId.equals(chatId),
          ))
        .write(
      ChatSummariesCompanion(
        summaryJson: Value(jsonEncode(next)),
        updatedAt: Value(_now()),
      ),
    );
  }

  Future<void> upsertMessages({
    required AppCacheUserScope userScope,
    required String chatId,
    required List<Map<String, dynamic>> messagesJson,
  }) async {
    await _database.transaction(() async {
      for (final message in messagesJson) {
        await _upsertMessage(
          userScope: userScope,
          chatId: chatId,
          messageJson: message,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> readRecentMessages({
    required AppCacheUserScope userScope,
    required String chatId,
    int? limit,
  }) async {
    final query = _database.select(_database.chatMessages)
      ..where(
        (table) =>
            table.userId.equals(userScope.storageId) &
            table.chatId.equals(chatId),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.createdAt),
        (table) => OrderingTerm.asc(table.messageId),
      ]);
    if (limit != null) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows
        .map((row) => Map<String, dynamic>.from(jsonDecode(row.messageJson)))
        .toList(growable: false);
  }

  Future<void> replaceRecentMessages({
    required AppCacheUserScope userScope,
    required String chatId,
    required List<Map<String, dynamic>> messagesJson,
  }) async {
    await _database.transaction(() async {
      await (_database.delete(_database.chatMessages)
            ..where(
              (table) =>
                  table.userId.equals(userScope.storageId) &
                  table.chatId.equals(chatId),
            ))
          .go();
      for (final message in messagesJson) {
        await _upsertMessage(
          userScope: userScope,
          chatId: chatId,
          messageJson: message,
        );
      }
    });
  }

  Future<void> setSyncCursor({
    required AppCacheUserScope userScope,
    required String chatId,
    required String? cursor,
  }) async {
    if (cursor == null || cursor.isEmpty) {
      await (_database.delete(_database.syncCursors)
            ..where(
              (table) =>
                  table.userId.equals(userScope.storageId) &
                  table.chatId.equals(chatId),
            ))
          .go();
      return;
    }

    await _database.into(_database.syncCursors).insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            userId: userScope.storageId,
            chatId: chatId,
            cursor: cursor,
            updatedAt: _now(),
          ),
        );
  }

  Future<String?> readSyncCursor({
    required AppCacheUserScope userScope,
    required String chatId,
  }) async {
    final row = await (_database.select(_database.syncCursors)
          ..where(
            (table) =>
                table.userId.equals(userScope.storageId) &
                table.chatId.equals(chatId),
          ))
        .getSingleOrNull();
    return row?.cursor;
  }

  Future<void> _upsertMessage({
    required AppCacheUserScope userScope,
    required String chatId,
    required Map<String, dynamic> messageJson,
  }) async {
    final messageId = messageJson['id'] as String?;
    if (messageId == null || messageId.isEmpty) {
      return;
    }
    final clientMessageId = messageJson['clientMessageId'] as String?;
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      await (_database.delete(_database.chatMessages)
            ..where(
              (table) =>
                  table.userId.equals(userScope.storageId) &
                  table.chatId.equals(chatId) &
                  table.clientMessageId.equals(clientMessageId) &
                  table.messageId.equals(messageId).not(),
            ))
          .go();
    }

    await _database.into(_database.chatMessages).insertOnConflictUpdate(
          ChatMessagesCompanion.insert(
            userId: userScope.storageId,
            chatId: chatId,
            messageId: messageId,
            clientMessageId: Value(clientMessageId),
            messageJson: jsonEncode(messageJson),
            createdAt: _parseCreatedAt(messageJson['createdAt']),
            fetchedAt: _now(),
          ),
        );
  }

  DateTime _parseCreatedAt(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? _now();
    }
    return _now();
  }
}
