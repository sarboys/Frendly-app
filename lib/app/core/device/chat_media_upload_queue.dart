import 'dart:io';

import 'package:mobile2/app/core/local_cache/chat_local_store.dart';
import 'package:mobile2/shared/data/backend_repository.dart';

class ChatMediaUploadQueue {
  ChatMediaUploadQueue({
    required ChatLocalStore store,
    required BackendRepository repository,
    DateTime Function()? now,
  })  : _store = store,
        _repository = repository,
        _now = now ?? DateTime.now;

  final ChatLocalStore _store;
  final BackendRepository _repository;
  final DateTime Function() _now;
  final Set<String> _activeUploads = <String>{};

  static const _maxAttempts = 5;
  static const _retryDelays = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  Future<void> processForChats({
    required String userId,
    Iterable<String>? chatIds,
  }) async {
    final uploads = await _store.pendingMediaUploads(
      userId: userId,
      chatIds: chatIds,
    );
    for (final upload in uploads) {
      await _processOne(upload);
    }
  }

  Future<void> _processOne(PendingMediaUploadRecord upload) async {
    final activeKey = '${upload.userId}:${upload.uploadId}';
    if (!_activeUploads.add(activeKey)) {
      return;
    }
    try {
      if (upload.status == 'failed') {
        return;
      }
      if (_waitingForRetry(upload)) {
        return;
      }
      final existingAssetId = upload.assetId;
      if (upload.status == 'uploaded' &&
          existingAssetId != null &&
          existingAssetId.isNotEmpty) {
        await _queueSendCommand(upload, existingAssetId);
        await _store.deletePendingMediaUpload(
          userId: upload.userId,
          uploadId: upload.uploadId,
        );
        return;
      }

      final file = File(upload.localPath);
      if (!await file.exists()) {
        await _markUploadFailed(upload, 'local_file_missing');
        return;
      }

      try {
        final uploaded = await _repository.uploadChatAttachmentFile(
          chatId: upload.chatId,
          filePath: upload.localPath,
          fileName: upload.fileName,
          mimeType: upload.mimeType,
          kind: upload.kind,
          durationMs: upload.durationMs,
          waveform: upload.waveform,
        );
        final assetId = uploaded['assetId']?.toString();
        if (assetId == null || assetId.isEmpty) {
          await _markUploadRetry(upload, 'asset_id_missing');
          return;
        }
        await _store.markPendingMediaUploadUploaded(
          userId: upload.userId,
          uploadId: upload.uploadId,
          assetId: assetId,
        );
        final replyTo = await _replyToForUpload(upload);
        await _store.upsertMessages(
          userId: upload.userId,
          chatId: upload.chatId,
          messages: [
            _messageForUpload(
              upload,
              attachment: _readyAttachment(upload, uploaded, assetId),
              replyTo: replyTo,
            ),
          ],
        );
        await _queueSendCommand(upload, assetId, replyTo: replyTo);
        await _store.deletePendingMediaUpload(
          userId: upload.userId,
          uploadId: upload.uploadId,
        );
      } catch (error) {
        await _markUploadRetry(upload, error.toString());
      }
    } finally {
      _activeUploads.remove(activeKey);
    }
  }

  Future<void> _queueSendCommand(
    PendingMediaUploadRecord upload,
    String assetId, {
    Map<String, Object?>? replyTo,
  }) async {
    replyTo ??= await _replyToForUpload(upload);
    final replyToMessageId = replyTo?['id']?.toString();
    return _store.enqueuePendingCommand(
      userId: upload.userId,
      commandId: upload.clientMessageId,
      dedupeKey: 'message.send:${upload.chatId}:${upload.clientMessageId}',
      payload: {
        'type': 'message.send',
        'payload': {
          'chatId': upload.chatId,
          'text': '',
          'clientMessageId': upload.clientMessageId,
          'attachmentIds': [assetId],
          if (replyToMessageId != null && replyToMessageId.isNotEmpty)
            'replyToMessageId': replyToMessageId,
        },
      },
    );
  }

  Future<void> _markUploadRetry(
    PendingMediaUploadRecord upload,
    String error,
  ) async {
    final attempts = upload.attempts + 1;
    if (attempts >= _maxAttempts) {
      await _markUploadFailed(upload, error);
      return;
    }
    await _store.markPendingMediaUploadRetry(
      userId: upload.userId,
      uploadId: upload.uploadId,
      attempts: attempts,
      error: error,
      updatedAt: _now(),
    );
  }

  bool _waitingForRetry(PendingMediaUploadRecord upload) {
    if (upload.attempts <= 0) {
      return false;
    }
    final delay = _retryDelay(upload.attempts);
    return upload.updatedAt.add(delay).isAfter(_now());
  }

  Duration _retryDelay(int attempts) {
    final index = attempts - 1;
    if (index < 0) {
      return Duration.zero;
    }
    if (index >= _retryDelays.length) {
      return _retryDelays.last;
    }
    return _retryDelays[index];
  }

  Future<void> _markUploadFailed(
    PendingMediaUploadRecord upload,
    String error,
  ) async {
    await _store.markPendingMediaUploadFailed(
      userId: upload.userId,
      uploadId: upload.uploadId,
      error: error,
    );
    final replyTo = await _replyToForUpload(upload);
    await _store.upsertMessages(
      userId: upload.userId,
      chatId: upload.chatId,
      messages: [
        _messageForUpload(
          upload,
          attachment: _uploadingAttachment(upload, status: 'failed'),
          replyTo: replyTo,
        ),
      ],
    );
  }

  Map<String, Object?> _messageForUpload(
    PendingMediaUploadRecord upload, {
    required Map<String, Object?> attachment,
    Map<String, Object?>? replyTo,
  }) {
    final attachmentStatus = attachment['status']?.toString();
    return {
      'id': upload.clientMessageId,
      'chatId': upload.chatId,
      'text': '',
      'clientMessageId': upload.clientMessageId,
      'createdAt': upload.createdAt.toIso8601String(),
      'pending': true,
      'mine': true,
      if (replyTo != null) 'replyTo': replyTo,
      if (attachmentStatus != null && attachmentStatus.isNotEmpty)
        'status': attachmentStatus,
      'attachments': [attachment],
    };
  }

  Future<Map<String, Object?>?> _replyToForUpload(
    PendingMediaUploadRecord upload,
  ) async {
    final message = await _store.readMessageByClientMessageId(
      userId: upload.userId,
      chatId: upload.chatId,
      clientMessageId: upload.clientMessageId,
    );
    final replyTo = message?['replyTo'];
    if (replyTo is! Map) {
      return null;
    }
    return replyTo.map((key, value) => MapEntry('$key', value));
  }

  Map<String, Object?> _uploadingAttachment(
    PendingMediaUploadRecord upload, {
    String status = 'uploading',
  }) {
    return {
      'id': 'local-${upload.uploadId}',
      'kind': upload.kind,
      'status': status,
      'fileName': upload.fileName,
      'mimeType': upload.mimeType,
      'localPath': upload.localPath,
      if (upload.durationMs != null) 'durationMs': upload.durationMs,
      if (upload.waveform.isNotEmpty) 'waveform': upload.waveform,
    };
  }

  Map<String, Object?> _readyAttachment(
    PendingMediaUploadRecord upload,
    Map<String, Object?> uploaded,
    String assetId,
  ) {
    final url = uploaded['url']?.toString();
    return {
      'id': assetId,
      'kind': upload.kind,
      'status': uploaded['status']?.toString() ?? 'ready',
      'fileName': upload.fileName,
      'mimeType': upload.mimeType,
      'localPath': upload.localPath,
      'url': url == null || url.isEmpty ? '/media/$assetId' : url,
      'downloadUrlPath': '/media/$assetId/download-url',
      if (upload.durationMs != null) 'durationMs': upload.durationMs,
      if (upload.waveform.isNotEmpty) 'waveform': upload.waveform,
    };
  }
}
