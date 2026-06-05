import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mobile2/app/core/local_cache/app_local_database.dart';

class ChatLocalStore {
  ChatLocalStore(this._database);

  final AppLocalDatabase _database;

  Stream<List<Map<String, Object?>>> watchSummaries({
    required String userId,
    required String kind,
  }) {
    return (_database.select(_database.chatSummaries)
          ..where(
              (table) => table.userId.equals(userId) & table.kind.equals(kind))
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]))
        .watch()
        .map((rows) => rows.map((row) => _decode(row.jsonValue)).toList());
  }

  Stream<Map<String, Object?>?> watchSummary({
    required String userId,
    required String chatId,
  }) {
    return (_database.select(_database.chatSummaries)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.chatId.equals(chatId),
          )
          ..limit(1))
        .watch()
        .map((rows) => rows.isEmpty ? null : _decode(rows.first.jsonValue));
  }

  Future<void> replaceSummaries({
    required String userId,
    required String kind,
    required List<Map<String, Object?>> summaries,
  }) async {
    await _database.transaction(() async {
      await (_database.delete(_database.chatSummaries)
            ..where(
              (table) => table.userId.equals(userId) & table.kind.equals(kind),
            ))
          .go();
      for (final summary in summaries) {
        await _upsertSummary(userId: userId, kind: kind, summary: summary);
      }
    });
  }

  Future<void> markSummaryRead({
    required String userId,
    required String chatId,
  }) async {
    await patchSummary(
      userId: userId,
      chatId: chatId,
      patch: (summary) => {
        ...summary,
        'unreadCount': 0,
        'unread': 0,
      },
    );
  }

  Future<void> setSummaryPinned({
    required String userId,
    required String chatId,
    required bool isPinned,
  }) async {
    await patchSummary(
      userId: userId,
      chatId: chatId,
      patch: (summary) => {
        ...summary,
        'isPinned': isPinned,
      },
    );
  }

  Future<void> patchSummary({
    required String userId,
    required String chatId,
    required Map<String, Object?> Function(Map<String, Object?> summary) patch,
  }) async {
    final rows = await (_database.select(_database.chatSummaries)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.chatId.equals(chatId),
          ))
        .get();
    for (final row in rows) {
      final json = _decode(row.jsonValue);
      await _upsertSummary(
        userId: row.userId,
        kind: row.kind,
        chatId: row.chatId,
        summary: patch(json),
      );
    }
  }

  Future<void> deleteChat({
    required String userId,
    required String chatId,
  }) async {
    await _database.transaction(() async {
      await (_database.delete(_database.chatSummaries)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.chatId.equals(chatId),
            ))
          .go();
      await (_database.delete(_database.chatMessages)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.chatId.equals(chatId),
            ))
          .go();
      await (_database.delete(_database.syncCursors)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.scope.equals('chat:$chatId'),
            ))
          .go();
      await (_database.delete(_database.pendingCommands)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.dedupeKey.like('%:$chatId:%'),
            ))
          .go();
      await (_database.delete(_database.pendingMediaUploads)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.chatId.equals(chatId),
            ))
          .go();
    });
  }

  Future<List<Map<String, Object?>>> readSummariesForChat({
    required String userId,
    required String chatId,
  }) async {
    final rows = await (_database.select(_database.chatSummaries)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.chatId.equals(chatId),
          ))
        .get();
    return rows
        .map((row) => <String, Object?>{
              'kind': row.kind,
              'summary': _decode(row.jsonValue),
            })
        .toList(growable: false);
  }

  Future<void> restoreSummaries({
    required String userId,
    required List<Map<String, Object?>> rows,
  }) async {
    for (final row in rows) {
      final kind = row['kind']?.toString();
      final summary = row['summary'];
      if (kind == null || summary is! Map<String, Object?>) {
        continue;
      }
      await _upsertSummary(userId: userId, kind: kind, summary: summary);
    }
  }

  Future<void> _upsertSummary({
    required String userId,
    required String kind,
    required Map<String, Object?> summary,
    String? chatId,
  }) async {
    final resolvedChatId =
        chatId ?? summary['id']?.toString() ?? summary['chatId']?.toString();
    if (resolvedChatId == null || resolvedChatId.isEmpty) {
      return;
    }
    await _database.into(_database.chatSummaries).insertOnConflictUpdate(
          ChatSummariesCompanion(
            userId: Value(userId),
            kind: Value(kind),
            chatId: Value(resolvedChatId),
            jsonValue: Value(jsonEncode(summary)),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Stream<List<Map<String, Object?>>> watchRecentMessages({
    required String userId,
    required String chatId,
  }) {
    return (_database.select(_database.chatMessages)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.chatId.equals(chatId),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .watch()
        .map((rows) => rows.map((row) => _decode(row.jsonValue)).toList());
  }

  Future<List<Map<String, Object?>>> readRecentMessages({
    required String userId,
    required String chatId,
    int? limit,
  }) async {
    final query = _database.select(_database.chatMessages)
      ..where(
        (table) => table.userId.equals(userId) & table.chatId.equals(chatId),
      )
      ..orderBy([
        (table) => limit == null
            ? OrderingTerm.asc(table.createdAt)
            : OrderingTerm.desc(table.createdAt),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    final rows = await query.get();
    final orderedRows = limit == null ? rows : rows.reversed;
    return orderedRows
        .map((row) => _decode(row.jsonValue))
        .toList(growable: false);
  }

  Future<void> upsertMessages({
    required String userId,
    required String chatId,
    required List<Map<String, Object?>> messages,
  }) async {
    for (final message in messages) {
      final messageId =
          message['id']?.toString() ?? message['messageId']?.toString();
      final clientMessageId = message['clientMessageId']?.toString();
      final localKey = messageId ?? clientMessageId;
      if (localKey == null || localKey.isEmpty) {
        continue;
      }
      final previousMessages = clientMessageId == null
          ? const <Map<String, Object?>>[]
          : await _messagesByClientMessageId(
              userId: userId,
              chatId: chatId,
              clientMessageId: clientMessageId,
            );
      final mergedMessage = _mergeLocalAttachmentFields(
        message,
        previousMessages,
      );
      if (clientMessageId != null && messageId != null) {
        await (_database.delete(_database.chatMessages)
              ..where(
                (table) =>
                    table.userId.equals(userId) &
                    table.chatId.equals(chatId) &
                    table.clientMessageId.equals(clientMessageId),
              ))
            .go();
      }
      await _database.into(_database.chatMessages).insertOnConflictUpdate(
            ChatMessagesCompanion(
              userId: Value(userId),
              chatId: Value(chatId),
              localKey: Value(localKey),
              messageId: Value(messageId),
              clientMessageId: Value(clientMessageId),
              jsonValue: Value(jsonEncode(mergedMessage)),
              createdAt:
                  Value(_date(mergedMessage['createdAt']) ?? DateTime.now()),
            ),
          );
    }
  }

  Future<List<Map<String, Object?>>> _messagesByClientMessageId({
    required String userId,
    required String chatId,
    required String clientMessageId,
  }) async {
    final rows = await (_database.select(_database.chatMessages)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.chatId.equals(chatId) &
                table.clientMessageId.equals(clientMessageId),
          ))
        .get();
    return rows.map((row) => _decode(row.jsonValue)).toList(growable: false);
  }

  Future<Map<String, Object?>?> readMessageByClientMessageId({
    required String userId,
    required String chatId,
    required String clientMessageId,
  }) async {
    final rows = await _messagesByClientMessageId(
      userId: userId,
      chatId: chatId,
      clientMessageId: clientMessageId,
    );
    return rows.isEmpty ? null : rows.last;
  }

  Future<void> deleteMessage({
    required String userId,
    required String chatId,
    required String messageId,
    String? clientMessageId,
  }) async {
    final trimmedMessageId = messageId.trim();
    final trimmedClientMessageId = clientMessageId?.trim();
    await (_database.delete(_database.chatMessages)
          ..where(
            (table) {
              final base =
                  table.userId.equals(userId) & table.chatId.equals(chatId);
              final byMessage = trimmedMessageId.isEmpty
                  ? const Constant(false)
                  : table.messageId.equals(trimmedMessageId) |
                      table.localKey.equals(trimmedMessageId);
              final byClient = trimmedClientMessageId == null ||
                      trimmedClientMessageId.isEmpty
                  ? const Constant(false)
                  : table.clientMessageId.equals(trimmedClientMessageId) |
                      table.localKey.equals(trimmedClientMessageId);
              return base & (byMessage | byClient);
            },
          ))
        .go();
  }

  Future<void> patchMessageByClientMessageId({
    required String userId,
    required String chatId,
    required String clientMessageId,
    required Map<String, Object?> Function(Map<String, Object?> message) patch,
  }) async {
    final rows = await (_database.select(_database.chatMessages)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.chatId.equals(chatId) &
                table.clientMessageId.equals(clientMessageId),
          ))
        .get();
    for (final row in rows) {
      final message = patch(_decode(row.jsonValue));
      await _database.into(_database.chatMessages).insertOnConflictUpdate(
            ChatMessagesCompanion(
              userId: Value(row.userId),
              chatId: Value(row.chatId),
              localKey: Value(row.localKey),
              messageId: Value(row.messageId),
              clientMessageId: Value(row.clientMessageId),
              jsonValue: Value(jsonEncode(message)),
              createdAt: Value(_date(message['createdAt']) ?? row.createdAt),
            ),
          );
    }
  }

  Map<String, Object?> _mergeLocalAttachmentFields(
    Map<String, Object?> incoming,
    List<Map<String, Object?>> previousMessages,
  ) {
    if (previousMessages.isEmpty || incoming['attachments'] is! List) {
      return incoming;
    }
    final incomingAttachments = (incoming['attachments'] as List)
        .whereType<Map>()
        .map(_mapWithStringKeys)
        .toList(growable: false);
    if (incomingAttachments.isEmpty) {
      return incoming;
    }
    final previousAttachments = <Map<String, Object?>>[];
    for (final message in previousMessages) {
      final attachments = message['attachments'];
      if (attachments is! List) {
        continue;
      }
      for (final attachment in attachments.whereType<Map>()) {
        previousAttachments.add(_mapWithStringKeys(attachment));
      }
    }
    if (previousAttachments.isEmpty) {
      return incoming;
    }

    final mergedAttachments = incomingAttachments.map((attachment) {
      final previous = _matchingPreviousAttachment(
        attachment,
        previousAttachments,
      );
      final previousLocalPath = previous?['localPath']?.toString();
      if (previousLocalPath == null ||
          previousLocalPath.isEmpty ||
          (attachment['localPath']?.toString().isNotEmpty ?? false)) {
        return attachment;
      }
      return {
        ...attachment,
        'localPath': previousLocalPath,
      };
    }).toList(growable: false);

    return {
      ...incoming,
      'attachments': mergedAttachments,
    };
  }

  Map<String, Object?>? _matchingPreviousAttachment(
    Map<String, Object?> incoming,
    List<Map<String, Object?>> previousAttachments,
  ) {
    final incomingId = incoming['id']?.toString();
    if (incomingId != null && incomingId.isNotEmpty) {
      for (final previous in previousAttachments) {
        if (previous['id']?.toString() == incomingId) {
          return previous;
        }
      }
    }
    final fileName = incoming['fileName']?.toString();
    final mimeType = incoming['mimeType']?.toString();
    final kind = incoming['kind']?.toString();
    for (final previous in previousAttachments) {
      if (fileName != null &&
          fileName.isNotEmpty &&
          previous['fileName']?.toString() == fileName &&
          previous['mimeType']?.toString() == mimeType &&
          previous['kind']?.toString() == kind) {
        return previous;
      }
    }
    return null;
  }

  Map<String, Object?> _mapWithStringKeys(Map source) {
    final converted = <String, Object?>{};
    for (final entry in source.entries) {
      converted['${entry.key}'] = entry.value;
    }
    return converted;
  }

  Future<void> clearMessages({
    required String userId,
    required String chatId,
  }) async {
    await (_database.delete(_database.chatMessages)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.chatId.equals(chatId),
          ))
        .go();
  }

  Future<void> setSyncCursor({
    required String userId,
    required String chatId,
    required String cursor,
  }) async {
    await _database.into(_database.syncCursors).insertOnConflictUpdate(
          SyncCursorsCompanion(
            userId: Value(userId),
            scope: Value('chat:$chatId'),
            cursor: Value(cursor),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<String?> getSyncCursor({
    required String userId,
    required String chatId,
  }) async {
    final row = await (_database.select(_database.syncCursors)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.scope.equals('chat:$chatId'),
          ))
        .getSingleOrNull();
    return row?.cursor;
  }

  Future<void> enqueuePendingCommand({
    required String userId,
    required String commandId,
    required String dedupeKey,
    required Map<String, Object?> payload,
  }) async {
    await _database.into(_database.pendingCommands).insertOnConflictUpdate(
          PendingCommandsCompanion(
            userId: Value(userId),
            commandId: Value(commandId),
            dedupeKey: Value(dedupeKey),
            jsonValue: Value(jsonEncode(payload)),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  Future<List<Map<String, Object?>>> pendingCommands({
    required String userId,
  }) async {
    final rows = await (_database.select(_database.pendingCommands)
          ..where((table) => table.userId.equals(userId))
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .get();
    return rows.map((row) => _decode(row.jsonValue)).toList(growable: false);
  }

  Future<void> deletePendingCommand({
    required String userId,
    required String commandId,
  }) async {
    await (_database.delete(_database.pendingCommands)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.commandId.equals(commandId),
          ))
        .go();
  }

  Future<void> enqueuePendingMediaUpload({
    required String userId,
    required String uploadId,
    required String chatId,
    required String clientMessageId,
    required String localPath,
    required String fileName,
    required String mimeType,
    required String kind,
    int? durationMs,
    List<double> waveform = const [],
  }) async {
    final now = DateTime.now();
    await _database.into(_database.pendingMediaUploads).insertOnConflictUpdate(
          PendingMediaUploadsCompanion(
            userId: Value(userId),
            uploadId: Value(uploadId),
            chatId: Value(chatId),
            clientMessageId: Value(clientMessageId),
            localPath: Value(localPath),
            fileName: Value(fileName),
            mimeType: Value(mimeType),
            kind: Value(kind),
            durationMs: Value(durationMs),
            waveformJson: Value(jsonEncode(waveform)),
            status: const Value('pending'),
            attempts: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<List<PendingMediaUploadRecord>> pendingMediaUploads({
    required String userId,
    Iterable<String>? chatIds,
  }) async {
    final normalizedChatIds = chatIds
        ?.map((chatId) => chatId.trim())
        .where((chatId) => chatId.isNotEmpty)
        .toSet();
    final query = _database.select(_database.pendingMediaUploads)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    if (normalizedChatIds != null && normalizedChatIds.isNotEmpty) {
      query.where((table) => table.chatId.isIn(normalizedChatIds));
    }
    final rows = await query.get();
    return rows.map(PendingMediaUploadRecord.fromRow).toList(growable: false);
  }

  Future<void> markPendingMediaUploadUploaded({
    required String userId,
    required String uploadId,
    required String assetId,
  }) async {
    await (_database.update(_database.pendingMediaUploads)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.uploadId.equals(uploadId),
          ))
        .write(
      PendingMediaUploadsCompanion(
        assetId: Value(assetId),
        status: const Value('uploaded'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markPendingMediaUploadRetry({
    required String userId,
    required String uploadId,
    required int attempts,
    required String error,
    DateTime? updatedAt,
  }) async {
    await (_database.update(_database.pendingMediaUploads)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.uploadId.equals(uploadId),
          ))
        .write(
      PendingMediaUploadsCompanion(
        status: const Value('pending'),
        attempts: Value(attempts),
        lastError: Value(error),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> markPendingMediaUploadFailed({
    required String userId,
    required String uploadId,
    required String error,
  }) async {
    await (_database.update(_database.pendingMediaUploads)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.uploadId.equals(uploadId),
          ))
        .write(
      PendingMediaUploadsCompanion(
        status: const Value('failed'),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> retryPendingMediaUpload({
    required String userId,
    required String uploadId,
  }) async {
    await markPendingMediaUploadRetry(
      userId: userId,
      uploadId: uploadId,
      attempts: 0,
      error: 'manual_retry',
      updatedAt: DateTime.now(),
    );
  }

  Future<void> deletePendingMediaUpload({
    required String userId,
    required String uploadId,
  }) async {
    await (_database.delete(_database.pendingMediaUploads)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.uploadId.equals(uploadId),
          ))
        .go();
  }

  Future<void> clearUser(String userId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.chatSummaries)
            ..where((table) => table.userId.equals(userId)))
          .go();
      await (_database.delete(_database.chatMessages)
            ..where((table) => table.userId.equals(userId)))
          .go();
      await (_database.delete(_database.syncCursors)
            ..where((table) => table.userId.equals(userId)))
          .go();
      await (_database.delete(_database.pendingCommands)
            ..where((table) => table.userId.equals(userId)))
          .go();
      await (_database.delete(_database.pendingMediaUploads)
            ..where((table) => table.userId.equals(userId)))
          .go();
    });
  }

  Map<String, Object?> _decode(String source) {
    final value = jsonDecode(source);
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return const {};
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

class PendingMediaUploadRecord {
  const PendingMediaUploadRecord({
    required this.userId,
    required this.uploadId,
    required this.chatId,
    required this.clientMessageId,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.kind,
    required this.waveform,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.durationMs,
    this.objectKey,
    this.assetId,
    this.lastError,
  });

  final String userId;
  final String uploadId;
  final String chatId;
  final String clientMessageId;
  final String localPath;
  final String fileName;
  final String mimeType;
  final String kind;
  final int? durationMs;
  final List<double> waveform;
  final String? objectKey;
  final String? assetId;
  final String status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  static PendingMediaUploadRecord fromRow(PendingMediaUpload row) {
    return PendingMediaUploadRecord(
      userId: row.userId,
      uploadId: row.uploadId,
      chatId: row.chatId,
      clientMessageId: row.clientMessageId,
      localPath: row.localPath,
      fileName: row.fileName,
      mimeType: row.mimeType,
      kind: row.kind,
      durationMs: row.durationMs,
      waveform: _decodeWaveform(row.waveformJson),
      objectKey: row.objectKey,
      assetId: row.assetId,
      status: row.status,
      attempts: row.attempts,
      lastError: row.lastError,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static List<double> _decodeWaveform(String source) {
    final value = jsonDecode(source);
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item is num ? item.toDouble() : double.tryParse('$item'))
        .whereType<double>()
        .toList(growable: false);
  }
}
