import 'dart:async';
import 'dart:typed_data';

import 'package:big_break_mobile/app/core/device/app_attachment_service.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/chat_cache_serializers.dart';
import 'package:big_break_mobile/app/core/local_cache/chat_local_store.dart';
import 'package:big_break_mobile/app/core/network/chat_socket_client.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/features/chats/presentation/chats_providers.dart';
import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/models/recorded_voice_draft.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatThreadProvider = StateNotifierProvider.autoDispose
    .family<ChatThreadController, AsyncValue<List<Message>>, String>(
  (ref, chatId) => ChatThreadController(ref, chatId),
);

class ChatThreadController extends StateNotifier<AsyncValue<List<Message>>> {
  ChatThreadController(this.ref, this.chatId)
      : super(const AsyncValue.data(<Message>[])) {
    ref.onDispose(() {
      _messagesCancelToken?.cancel('chat_thread_disposed');
      _markReadTimer?.cancel();
      unawaited(_subscription?.cancel());
      _socket?.unsubscribe(chatId);
    });
    _init();
  }

  final Ref ref;
  final String chatId;
  ChatSocketClient? _socket;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _markReadTimer;
  CancelToken? _messagesCancelToken;
  String? _lastMarkedReadMessageId;
  String? _olderMessagesCursor;
  bool _loadingOlderMessages = false;

  Future<void> _init() async {
    PaginatedResponse<Message>? result;
    String? storedSyncCursor;
    var renderedLocalMessages = false;
    final authBootstrap = ref.read(authBootstrapProvider.future);
    try {
      await authBootstrap;
      if (!mounted) {
        return;
      }
      final localStore = ref.read(chatLocalStoreProvider);
      final userScope = ref.read(appCacheUserScopeProvider);
      final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
      if (localStore != null) {
        final localSnapshot = await _readLocalSnapshot(
          localStore,
          userScope: userScope,
        );
        storedSyncCursor = localSnapshot.syncCursor;
        final cachedMessages = localSnapshot.messagesJson;
        if (!mounted) {
          return;
        }
        if (cachedMessages.isNotEmpty) {
          final messages = cachedMessages
              .map(
                (json) => messageFromCacheJson(
                  json,
                  currentUserId: currentUserId,
                ),
              )
              .toList(growable: false);
          renderedLocalMessages = true;
          state = AsyncValue.data(_decorateMessages(messages));
          _warmRecentAttachments(messages);
        }
      }
      try {
        result = await _fetchMessages(limit: 20);
        if (!mounted) {
          return;
        }
        _olderMessagesCursor = result.nextCursor;
        state = AsyncValue.data(_decorateMessages(result.items));
        await _replaceLocalMessages(result.items);
        final lastEventId = result.lastEventId;
        if (lastEventId != null) {
          await _rememberLocalSyncCursor(lastEventId);
        }
        _warmRecentAttachments(result.items);
        _scheduleMarkRead();
      } catch (_) {
        if (!mounted) {
          return;
        }
        if (!renderedLocalMessages) {
          state = const AsyncValue.data(<Message>[]);
        }
      }

      final socket = ref.read(chatSocketClientProvider);
      _socket = socket;
      try {
        await socket.connect();
        if (!mounted) {
          return;
        }
        _subscription = socket.events.listen(_handleEvent);
        socket.subscribe(chatId);
        socket.requestSync(
          chatId: chatId,
          sinceEventId: storedSyncCursor ?? result?.lastEventId,
        );
      } catch (_) {}
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> sendMessage(
    String text, {
    MessageReplyPreview? replyTo,
  }) async {
    if (text.trim().isEmpty) {
      return;
    }

    final now = DateTime.now();
    final clientMessageId = 'mobile-${now.microsecondsSinceEpoch}';
    final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
    final normalized = text.trim();

    _upsertMessage(
      Message(
        id: 'local-$clientMessageId',
        chatId: chatId,
        clientMessageId: clientMessageId,
        authorId: currentUserId,
        author: 'Ты',
        text: normalized,
        time: _formatLocalTime(now),
        createdAt: now,
        mine: true,
        isPending: true,
        replyTo: replyTo,
        attachments: const [],
      ),
    );

    final socket = ref.read(chatSocketClientProvider);
    try {
      await socket.sendMessage(
        chatId: chatId,
        text: normalized,
        clientMessageId: clientMessageId,
        replyToMessageId: replyTo?.id,
      );
    } catch (_) {
      if (mounted) {
        _removeLocalMessage(clientMessageId);
      }
      rethrow;
    }
  }

  void addLocalSystemMessage(String text) {
    final now = DateTime.now();
    final clientMessageId = 'system-${now.microsecondsSinceEpoch}';
    final message = Message(
      id: 'local-$clientMessageId',
      chatId: chatId,
      clientMessageId: clientMessageId,
      authorId: 'system',
      author: 'system',
      text: text.trim(),
      time: _formatLocalTime(now),
      createdAt: now,
      attachments: const [],
      isSystem: true,
    );
    _upsertMessage(message);
    _refreshChatSummaryProviders(message);
  }

  Future<void> loadOlderMessages() async {
    final cursor = _olderMessagesCursor;
    if (cursor == null || _loadingOlderMessages) {
      return;
    }

    _loadingOlderMessages = true;
    try {
      final result = await _fetchMessages(
        limit: 20,
        cursor: cursor,
      );
      if (!mounted) {
        return;
      }

      _olderMessagesCursor = result.nextCursor;
      var merged = state.valueOrNull ?? const <Message>[];
      for (final message in result.items) {
        merged = _mergeMessageIntoSortedList(merged, message).messages;
      }
      state = AsyncValue.data(_decorateSortedMessages(merged));
      await _persistCurrentMessages();
      _warmRecentAttachments(result.items);
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      _loadingOlderMessages = false;
    }
  }

  Future<void> editMessage(Message message, String text) async {
    final normalized = text.trim();
    if (!message.mine ||
        message.isPending ||
        message.id.startsWith('local-') ||
        normalized.isEmpty ||
        normalized == message.text.trim()) {
      return;
    }

    final previous = state.valueOrNull;
    final socket = ref.read(chatSocketClientProvider);
    _upsertMessage(message.copyWith(text: normalized));

    try {
      await socket.editMessage(
        chatId: chatId,
        messageId: message.id,
        text: normalized,
      );
    } catch (_) {
      if (mounted && previous != null) {
        state = AsyncValue.data(previous);
      }
      rethrow;
    }
  }

  Future<void> deleteMessage(Message message) async {
    if (!message.mine || message.isPending || message.id.startsWith('local-')) {
      return;
    }

    final previous = state.valueOrNull;
    final previousMeetupChats = ref.read(meetupChatsLocalStateProvider);
    final previousPersonalChats = ref.read(personalChatsLocalStateProvider);
    final meetupChatsNotifier =
        ref.read(meetupChatsLocalStateProvider.notifier);
    final personalChatsNotifier =
        ref.read(personalChatsLocalStateProvider.notifier);
    final socket = ref.read(chatSocketClientProvider);
    final summary = _summaryAfterDelete(message.id);
    _removeMessageById(message.id);
    if (summary.affectsSummary) {
      _patchChatSummaryAfterDelete(summary.replacement);
    }

    try {
      await socket.deleteMessage(
        chatId: chatId,
        messageId: message.id,
      );
    } catch (_) {
      if (!mounted) {
        rethrow;
      }
      if (previous != null) {
        state = AsyncValue.data(previous);
      }
      meetupChatsNotifier.state = previousMeetupChats;
      personalChatsNotifier.state = previousPersonalChats;
      rethrow;
    }
  }

  Future<void> sendAttachment(
    PlatformFile file, {
    MessageReplyPreview? replyTo,
  }) async {
    final now = DateTime.now();
    final clientMessageId = 'mobile-file-${now.microsecondsSinceEpoch}';
    final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
    final repository = ref.read(backendRepositoryProvider);
    final socket = ref.read(chatSocketClientProvider);
    final localBytes = _localBytesForMessage(file);

    _upsertMessage(
      Message(
        id: 'local-$clientMessageId',
        chatId: chatId,
        clientMessageId: clientMessageId,
        authorId: currentUserId,
        author: 'Ты',
        text: file.name,
        time: _formatLocalTime(now),
        createdAt: now,
        mine: true,
        isPending: true,
        replyTo: replyTo,
        attachments: [
          MessageAttachment(
            id: 'local-attachment-$clientMessageId',
            kind: 'chat_attachment',
            status: 'uploading',
            url: null,
            mimeType: _mimeTypeForFile(file),
            byteSize: file.size,
            fileName: file.name,
            localBytes: localBytes,
            localPath: file.path,
          ),
        ],
      ),
    );

    try {
      final assetId =
          await repository.uploadChatAttachment(file, chatId: chatId);
      await socket.sendMessage(
        chatId: chatId,
        text: file.name,
        clientMessageId: clientMessageId,
        attachmentIds: [assetId],
        replyToMessageId: replyTo?.id,
      );
      if (!mounted) {
        return;
      }
      _markLocalAttachmentReady(
        clientMessageId,
        localBytes: localBytes,
        localPath: file.path,
        durationMs: null,
        waveform: null,
      );
    } catch (_) {
      if (mounted) {
        _removeLocalMessage(clientMessageId);
      }
      rethrow;
    }
  }

  Future<void> sendVoiceMessage(
    RecordedVoiceDraft voice, {
    MessageReplyPreview? replyTo,
  }) async {
    final now = DateTime.now();
    final clientMessageId = 'mobile-voice-${now.microsecondsSinceEpoch}';
    final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
    final durationMs = voice.duration.inMilliseconds;
    final repository = ref.read(backendRepositoryProvider);
    final socket = ref.read(chatSocketClientProvider);

    _upsertMessage(
      Message(
        id: 'local-$clientMessageId',
        chatId: chatId,
        clientMessageId: clientMessageId,
        authorId: currentUserId,
        author: 'Ты',
        text: '',
        time: _formatLocalTime(now),
        createdAt: now,
        mine: true,
        isPending: true,
        replyTo: replyTo,
        attachments: [
          MessageAttachment(
            id: 'local-voice-$clientMessageId',
            kind: 'chat_voice',
            status: 'uploading',
            url: null,
            mimeType: _mimeTypeForFile(voice.file),
            byteSize: voice.file.size,
            fileName: voice.file.name,
            localPath: voice.file.path,
            durationMs: durationMs,
            waveform: voice.waveform,
          ),
        ],
      ),
    );

    try {
      final assetId = await repository.uploadChatVoice(
        voice.file,
        chatId: chatId,
        durationMs: durationMs,
        waveform: voice.waveform,
      );
      await socket.sendMessage(
        chatId: chatId,
        text: '',
        clientMessageId: clientMessageId,
        attachmentIds: [assetId],
        replyToMessageId: replyTo?.id,
      );
      if (!mounted) {
        return;
      }
      _markLocalAttachmentReady(
        clientMessageId,
        localBytes: null,
        localPath: voice.file.path,
        durationMs: durationMs,
        waveform: voice.waveform,
      );
    } catch (_) {
      if (mounted) {
        _removeLocalMessage(clientMessageId);
      }
      rethrow;
    }
  }

  Future<void> sendCurrentLocation({
    required double latitude,
    required double longitude,
    required String title,
    required String subtitle,
    MessageReplyPreview? replyTo,
  }) async {
    final now = DateTime.now();
    final clientMessageId = 'mobile-location-${now.microsecondsSinceEpoch}';
    final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
    final payload = encodeLocationMessagePayload(
      latitude: latitude,
      longitude: longitude,
      title: title,
      subtitle: subtitle,
    );

    _upsertMessage(
      Message(
        id: 'local-$clientMessageId',
        chatId: chatId,
        clientMessageId: clientMessageId,
        authorId: currentUserId,
        author: 'Ты',
        text: '',
        time: _formatLocalTime(now),
        createdAt: now,
        mine: true,
        isPending: true,
        replyTo: replyTo,
        attachments: [
          MessageAttachment(
            id: 'local-location-$clientMessageId',
            kind: 'chat_location',
            status: 'ready',
            url: null,
            mimeType: 'application/vnd.bigbreak.location',
            byteSize: 0,
            fileName: title,
            title: title,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            expiresAt: now.add(const Duration(minutes: 5)),
          ),
        ],
      ),
    );

    final socket = ref.read(chatSocketClientProvider);
    try {
      await socket.sendMessage(
        chatId: chatId,
        text: payload,
        clientMessageId: clientMessageId,
        replyToMessageId: replyTo?.id,
      );
    } catch (_) {
      if (mounted) {
        _removeLocalMessage(clientMessageId);
      }
      rethrow;
    }
  }

  Future<void> markRead() async {
    final messages = state.valueOrNull;
    if (messages == null || messages.isEmpty) {
      return;
    }

    final messageId =
        _latestUnreadSummaryMessageId() ?? _latestIncomingMessageId(messages);
    if (messageId == null) {
      return;
    }

    if (_lastMarkedReadMessageId == messageId) {
      return;
    }

    _lastMarkedReadMessageId = messageId;
    _sendReadReceipt(messageId);
    _clearChatSummaryUnread();
  }

  void _sendReadReceipt(String messageId) {
    ref.read(chatSocketClientProvider).markRead(
          chatId: chatId,
          messageId: messageId,
        );
    unawaited(
      ref
          .read(backendRepositoryProvider)
          .markChatRead(chatId, messageId)
          .catchError(
            (_) {},
          ),
    );
  }

  void _handleEvent(Map<String, dynamic> envelope) {
    final type = envelope['type'] as String?;
    final payload = envelope['payload'];

    if (type == 'message.created' &&
        payload is Map<String, dynamic> &&
        payload['chatId'] == chatId) {
      final eventId = payload['eventId'] as String?;
      if (eventId != null) {
        ref.read(chatSocketClientProvider).rememberSyncCursor(
              chatId: chatId,
              eventId: eventId,
            );
        unawaited(_rememberLocalSyncCursor(eventId));
      }
      final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
      final nextMessage =
          Message.fromJson(payload, currentUserId: currentUserId);
      _upsertMessage(nextMessage);
      _warmRecentAttachments([nextMessage]);
      _scheduleMarkRead();
      _refreshChatSummaryProviders(nextMessage);
      return;
    }

    if (type == 'message.updated' &&
        payload is Map<String, dynamic> &&
        payload['chatId'] == chatId) {
      final eventId = payload['eventId'] as String?;
      if (eventId != null) {
        ref.read(chatSocketClientProvider).rememberSyncCursor(
              chatId: chatId,
              eventId: eventId,
            );
        unawaited(_rememberLocalSyncCursor(eventId));
      }
      final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
      final nextMessage =
          Message.fromJson(payload, currentUserId: currentUserId);
      final wasLast = _isLastMessage(nextMessage.id);
      _upsertMessage(nextMessage);
      _warmRecentAttachments([nextMessage]);
      if (wasLast) {
        _refreshChatSummaryProviders(nextMessage);
      }
      return;
    }

    if (type == 'message.deleted' &&
        payload is Map<String, dynamic> &&
        payload['chatId'] == chatId) {
      final eventId = payload['eventId'] as String?;
      if (eventId != null) {
        ref.read(chatSocketClientProvider).rememberSyncCursor(
              chatId: chatId,
              eventId: eventId,
            );
        unawaited(_rememberLocalSyncCursor(eventId));
      }
      final messageId =
          payload['messageId'] as String? ?? payload['id'] as String?;
      if (messageId != null) {
        final summary = _summaryAfterDelete(messageId);
        _removeMessageById(messageId);
        if (summary.affectsSummary) {
          _patchChatSummaryAfterDelete(summary.replacement);
        }
      }
      return;
    }

    if (type == 'sync.snapshot' &&
        payload is Map<String, dynamic> &&
        payload['chatId'] == chatId) {
      if (payload['reset'] == true) {
        unawaited(_reloadAfterSyncReset());
        return;
      }

      final socket = ref.read(chatSocketClientProvider);
      final events =
          ((payload['events'] as List?) ?? const []).whereType<Map>();
      final nextEventId = payload['nextEventId'] as String?;
      final lastEventId = nextEventId ?? _lastEventIdFrom(events);
      if (lastEventId != null) {
        socket.rememberSyncCursor(
          chatId: chatId,
          eventId: lastEventId,
        );
        unawaited(_rememberLocalSyncCursor(lastEventId));
      }

      if (payload['hasMore'] == true && lastEventId != null) {
        socket.requestSync(
          chatId: chatId,
          sinceEventId: lastEventId,
        );
      }

      if (events.isEmpty) {
        return;
      }

      final currentUserId = ref.read(currentUserIdProvider) ?? 'user-me';
      var merged = state.valueOrNull ?? const <Message>[];
      final synced = <Message>[];
      var changed = false;
      for (final item in events) {
        final itemType = item['type'];
        final itemPayload = item['payload'];
        if ((itemType == 'message.created' || itemType == 'message.updated') &&
            itemPayload is Map) {
          final incoming = Message.fromJson(
            Map<String, dynamic>.from(itemPayload),
            currentUserId: currentUserId,
          );
          synced.add(incoming);
          merged = _mergeMessageIntoSortedList(merged, incoming).messages;
          changed = true;
          continue;
        }

        if (itemType == 'message.deleted' && itemPayload is Map) {
          final messageId = itemPayload['messageId'] as String? ??
              itemPayload['id'] as String?;
          if (messageId != null) {
            merged = _removeMessageFromList(merged, messageId);
            changed = true;
          }
        }
      }

      if (!changed) {
        return;
      }
      state = AsyncValue.data(_decorateSortedMessages(merged));
      unawaited(_persistCurrentMessages());
      _warmRecentAttachments(synced);
      _scheduleMarkRead();
    }
  }

  Future<void> _reloadAfterSyncReset() async {
    final socket = ref.read(chatSocketClientProvider);
    final result = await _fetchMessages(limit: 20);
    if (!mounted) {
      return;
    }

    state = AsyncValue.data(_decorateMessages(result.items));
    _olderMessagesCursor = result.nextCursor;
    await _replaceLocalMessages(result.items);
    _warmRecentAttachments(result.items);

    final lastEventId = result.lastEventId;
    if (lastEventId != null) {
      socket.rememberSyncCursor(
        chatId: chatId,
        eventId: lastEventId,
      );
      await _rememberLocalSyncCursor(lastEventId);
      socket.requestSync(
        chatId: chatId,
        sinceEventId: lastEventId,
      );
    }

    _scheduleMarkRead();
  }

  Future<PaginatedResponse<Message>> _fetchMessages({
    required int limit,
    String? cursor,
  }) async {
    _messagesCancelToken?.cancel('chat_thread_fetch_replaced');
    final cancelToken = CancelToken();
    _messagesCancelToken = cancelToken;
    final repository = ref.read(backendRepositoryProvider);
    try {
      return await repository.fetchMessages(
        chatId,
        cursor: cursor,
        limit: limit,
        cancelToken: cancelToken,
      );
    } finally {
      if (identical(_messagesCancelToken, cancelToken)) {
        _messagesCancelToken = null;
      }
    }
  }

  String? _lastEventIdFrom(Iterable<Map<dynamic, dynamic>> events) {
    String? lastEventId;
    for (final event in events) {
      lastEventId = event['id'] as String?;
    }
    return lastEventId;
  }

  void _warmRecentAttachments(Iterable<Message> messages) {
    final service = ref.read(appAttachmentServiceProvider);
    final readyRemoteAttachments = messages
        .expand((message) => message.attachments)
        .where(
          (attachment) =>
              attachment.status == 'ready' &&
              attachment.url != null &&
              (attachment.localPath == null || attachment.localPath!.isEmpty),
        );
    final voiceAttachments = readyRemoteAttachments
        .where((attachment) => attachment.isVoice)
        .take(3);
    final imageAttachments = readyRemoteAttachments
        .where((attachment) => attachment.mimeType.startsWith('image/'))
        .take(4);

    for (final attachment in [...voiceAttachments, ...imageAttachments]) {
      unawaited(service.warmCache(attachment));
    }
  }

  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(markRead());
    });
  }

  void _refreshChatSummaryProviders(Message message) {
    final preview = _buildMessagePreview(message);
    final meetupChats = ref.read(meetupChatsProvider).valueOrNull ?? const [];
    if (meetupChats.any((chat) => chat.id == chatId)) {
      ref.read(meetupChatsLocalStateProvider.notifier).state =
          upsertMeetupChatSummary(
        meetupChats,
        chatId: chatId,
        lastMessage: preview,
        lastAuthor: message.author,
        lastTime: message.time,
        unread: 0,
        lastMessageId: message.id,
      );
      return;
    }

    final personalChats =
        ref.read(personalChatsProvider).valueOrNull ?? const [];
    if (personalChats.any((chat) => chat.id == chatId)) {
      ref.read(personalChatsLocalStateProvider.notifier).state =
          upsertPersonalChatSummary(
        personalChats,
        chatId: chatId,
        lastMessage: preview,
        lastTime: message.time,
        unread: 0,
        lastMessageId: message.id,
      );
      return;
    }

    clearChatListLocalStateForRefetch(ref);
    ref.invalidate(meetupChatsProvider);
    ref.invalidate(personalChatsProvider);
  }

  ({bool affectsSummary, Message? replacement}) _summaryAfterDelete(
    String messageId,
  ) {
    final messages = state.valueOrNull;
    if (messages == null || messages.isEmpty) {
      return (affectsSummary: false, replacement: null);
    }

    final index = messages.indexWhere((item) => item.id == messageId);
    if (index == -1 || index != messages.length - 1) {
      return (affectsSummary: false, replacement: null);
    }

    return (
      affectsSummary: true,
      replacement: index == 0 ? null : messages[index - 1],
    );
  }

  void _patchChatSummaryAfterDelete(Message? replacement) {
    final lastMessage =
        replacement == null ? '' : _buildMessagePreview(replacement);
    final lastAuthor = replacement?.author ?? '';
    final lastTime = replacement?.time ?? '';

    final localMeetupChats = ref.read(meetupChatsLocalStateProvider);
    final meetupChats =
        localMeetupChats ?? ref.read(meetupChatsProvider).valueOrNull;
    if (meetupChats != null && meetupChats.any((chat) => chat.id == chatId)) {
      ref.read(meetupChatsLocalStateProvider.notifier).state = meetupChats
          .map(
            (chat) => chat.id == chatId
                ? chat.copyWith(
                    lastMessage: lastMessage,
                    lastAuthor: lastAuthor,
                    lastTime: lastTime,
                    unread: 0,
                    typing: false,
                  )
                : chat,
          )
          .toList(growable: false);
      return;
    }

    final localPersonalChats = ref.read(personalChatsLocalStateProvider);
    final personalChats =
        localPersonalChats ?? ref.read(personalChatsProvider).valueOrNull;
    if (personalChats != null &&
        personalChats.any((chat) => chat.id == chatId)) {
      ref.read(personalChatsLocalStateProvider.notifier).state = personalChats
          .map(
            (chat) => chat.id == chatId
                ? chat.copyWith(
                    lastMessage: lastMessage,
                    lastTime: lastTime,
                    unread: 0,
                  )
                : chat,
          )
          .toList(growable: false);
    }
  }

  String _buildMessagePreview(Message message) {
    final text = message.text.trim();
    if (text.isNotEmpty) {
      return text;
    }

    if (message.attachments.any((attachment) => attachment.isVoice)) {
      return 'Голосовое сообщение';
    }

    if (message.attachments.any((attachment) => attachment.isLocation)) {
      return 'Локация';
    }

    if (message.attachments.isNotEmpty) {
      return 'Вложение';
    }

    return '';
  }

  void _upsertMessage(Message message) {
    final current = state.valueOrNull ?? const <Message>[];
    final result = _mergeMessageIntoSortedList(current, message);
    state = AsyncValue.data(
      _decorateMessagesAround(result.messages, result.changedIndices),
    );
    unawaited(_persistCurrentMessages());
  }

  _MessageMergeResult _mergeMessageIntoSortedList(
    List<Message> current,
    Message incoming,
  ) {
    final next = [...current];
    final indexById = next.indexWhere((item) => item.id == incoming.id);
    if (indexById != -1) {
      final merged = _mergeMessageVersions(next[indexById], incoming);
      next.removeAt(indexById);
      final changedIndex = _insertMessageInOrder(next, merged);
      return _MessageMergeResult(next, [indexById, changedIndex]);
    }

    final indexByClientMessageId = next.indexWhere(
      (item) => item.clientMessageId == incoming.clientMessageId,
    );
    if (indexByClientMessageId != -1) {
      final merged =
          _mergeMessageVersions(next[indexByClientMessageId], incoming);
      next.removeAt(indexByClientMessageId);
      final changedIndex = _insertMessageInOrder(next, merged);
      return _MessageMergeResult(
        next,
        [indexByClientMessageId, changedIndex],
      );
    }

    final changedIndex = _insertMessageInOrder(next, incoming);
    return _MessageMergeResult(next, [changedIndex]);
  }

  void _removeLocalMessage(String clientMessageId) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final removedIndex = current.indexWhere(
      (item) => item.clientMessageId == clientMessageId,
    );
    if (removedIndex == -1) {
      return;
    }

    final next = [...current]..removeAt(removedIndex);
    state = AsyncValue.data(_decorateMessagesAround(next, [removedIndex]));
    unawaited(_persistCurrentMessages());
  }

  void _removeMessageById(String messageId) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final removedIndex = current.indexWhere((item) => item.id == messageId);
    if (removedIndex == -1) {
      return;
    }

    final next = _removeMessageFromList(current, messageId);
    state = AsyncValue.data(_decorateMessagesAround(next, [removedIndex]));
    unawaited(_persistCurrentMessages());
  }

  Future<void> _replaceLocalMessages(List<Message> messages) async {
    final localStore = ref.read(chatLocalStoreProvider);
    if (localStore == null) {
      return;
    }
    try {
      await localStore.replaceRecentMessages(
        userScope: ref.read(appCacheUserScopeProvider),
        chatId: chatId,
        messagesJson: messages.map(messageToCacheJson).toList(growable: false),
      );
    } catch (_) {
      _disableLocalCacheAfterFailure();
    }
  }

  Future<void> _persistCurrentMessages() async {
    final messages = state.valueOrNull;
    if (messages == null) {
      return;
    }
    await _replaceLocalMessages(messages);
  }

  Future<void> _rememberLocalSyncCursor(String? eventId) async {
    final localStore = ref.read(chatLocalStoreProvider);
    if (localStore == null) {
      return;
    }
    try {
      await localStore.setSyncCursor(
        userScope: ref.read(appCacheUserScopeProvider),
        chatId: chatId,
        cursor: eventId,
      );
    } catch (_) {
      _disableLocalCacheAfterFailure();
    }
  }

  Future<({String? syncCursor, List<Map<String, dynamic>> messagesJson})>
      _readLocalSnapshot(
    ChatLocalStore localStore, {
    required AppCacheUserScope userScope,
  }) async {
    try {
      final syncCursor = await localStore.readSyncCursor(
        userScope: userScope,
        chatId: chatId,
      );
      final messagesJson = await localStore.readRecentMessages(
        userScope: userScope,
        chatId: chatId,
      );
      return (syncCursor: syncCursor, messagesJson: messagesJson);
    } catch (_) {
      _disableLocalCacheAfterFailure();
      return (
        syncCursor: null,
        messagesJson: const <Map<String, dynamic>>[],
      );
    }
  }

  void _disableLocalCacheAfterFailure() {
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      try {
        ref.read(appLocalCacheRuntimeDisabledProvider.notifier).state = true;
      } catch (_) {}
    });
  }

  List<Message> _removeMessageFromList(List<Message> messages, String id) {
    final index = messages.indexWhere((item) => item.id == id);
    if (index == -1) {
      return messages;
    }

    final next = [...messages]..removeAt(index);
    return next;
  }

  bool _isLastMessage(String messageId) {
    final messages = state.valueOrNull;
    return messages != null &&
        messages.isNotEmpty &&
        messages.last.id == messageId;
  }

  String? _latestUnreadSummaryMessageId() {
    final localMeetupChats = ref.read(meetupChatsLocalStateProvider);
    final meetupChats =
        localMeetupChats ?? ref.read(meetupChatsProvider).valueOrNull;
    if (meetupChats != null) {
      for (final chat in meetupChats) {
        if (chat.id == chatId &&
            chat.unread > 0 &&
            chat.lastMessageId != null) {
          return chat.lastMessageId;
        }
      }
    }

    final localPersonalChats = ref.read(personalChatsLocalStateProvider);
    final personalChats =
        localPersonalChats ?? ref.read(personalChatsProvider).valueOrNull;
    if (personalChats != null) {
      for (final chat in personalChats) {
        if (chat.id == chatId &&
            chat.unread > 0 &&
            chat.lastMessageId != null) {
          return chat.lastMessageId;
        }
      }
    }

    return null;
  }

  String? _latestIncomingMessageId(List<Message> messages) {
    for (final message in messages.reversed) {
      if (message.id.startsWith('local-') || message.mine || message.isSystem) {
        continue;
      }
      return message.id;
    }
    return null;
  }

  void _clearChatSummaryUnread() {
    final localMeetupChats = ref.read(meetupChatsLocalStateProvider);
    final meetupChats =
        localMeetupChats ?? ref.read(meetupChatsProvider).valueOrNull;
    if (meetupChats != null && meetupChats.any((chat) => chat.id == chatId)) {
      ref.read(meetupChatsLocalStateProvider.notifier).state =
          setMeetupChatUnread(meetupChats, chatId: chatId, unread: 0);
      return;
    }

    final localPersonalChats = ref.read(personalChatsLocalStateProvider);
    final personalChats =
        localPersonalChats ?? ref.read(personalChatsProvider).valueOrNull;
    if (personalChats != null &&
        personalChats.any((chat) => chat.id == chatId)) {
      ref.read(personalChatsLocalStateProvider.notifier).state =
          setPersonalChatUnread(personalChats, chatId: chatId, unread: 0);
      return;
    }

    final localCommunityChats = ref.read(communityChatsLocalStateProvider);
    final communityChats =
        localCommunityChats ?? ref.read(communitiesProvider).valueOrNull;
    if (communityChats != null &&
        communityChats.any((community) => community.chatId == chatId)) {
      ref.read(communityChatsLocalStateProvider.notifier).state = communityChats
          .map(
            (community) => community.chatId == chatId
                ? community.copyWith(unread: 0)
                : community,
          )
          .toList(growable: false);
    }
  }

  void _markLocalAttachmentReady(
    String clientMessageId, {
    required Uint8List? localBytes,
    required String? localPath,
    required int? durationMs,
    required List<double>? waveform,
  }) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final index = current.indexWhere(
      (message) => message.clientMessageId == clientMessageId,
    );
    if (index == -1) {
      return;
    }

    final updated = [...current];
    final message = updated[index];
    updated[index] = message.copyWith(
      attachments: message.attachments
          .map(
            (attachment) => attachment.copyWith(
              status: 'ready',
              localBytes: localBytes,
              localPath: localPath,
              durationMs: durationMs,
              waveform: waveform,
            ),
          )
          .toList(growable: false),
    );

    state = AsyncValue.data(updated);
  }

  List<Message> _decorateMessages(List<Message> messages) {
    return _decorateSortedMessages(_sortMessages(messages));
  }

  List<Message> _decorateSortedMessages(List<Message> sorted) {
    final decorated = <Message>[];

    for (var index = 0; index < sorted.length; index++) {
      final current = sorted[index];
      final previous = index > 0 ? sorted[index - 1] : null;
      final next = index == sorted.length - 1 ? null : sorted[index + 1];
      final showAuthor = !current.isSystem &&
          !current.mine &&
          (previous == null ||
              previous.isSystem ||
              previous.authorId != current.authorId);
      final showAvatar = !current.isSystem &&
          !current.mine &&
          (index == sorted.length - 1 ||
              next!.isSystem ||
              next.authorId != current.authorId ||
              next.mine);

      decorated.add(
        current.copyWith(
          showAuthor: showAuthor,
          showAvatar: showAvatar,
        ),
      );
    }

    return decorated;
  }

  List<Message> _decorateMessagesAround(
    List<Message> messages,
    Iterable<int> indexes,
  ) {
    if (messages.isEmpty) {
      return messages;
    }

    final next = [...messages];
    final indexesToDecorate = <int>{};
    for (final index in indexes) {
      final start = (index - 1).clamp(0, next.length - 1);
      final end = (index + 1).clamp(0, next.length - 1);
      for (var i = start; i <= end; i += 1) {
        indexesToDecorate.add(i);
      }
    }

    for (final index in indexesToDecorate) {
      next[index] = _decorateMessageAt(next, index);
    }
    return next;
  }

  Message _decorateMessageAt(List<Message> messages, int index) {
    final current = messages[index];
    final previous = index > 0 ? messages[index - 1] : null;
    final next = index == messages.length - 1 ? null : messages[index + 1];
    final showAuthor = !current.isSystem &&
        !current.mine &&
        (previous == null ||
            previous.isSystem ||
            previous.authorId != current.authorId);
    final showAvatar = !current.isSystem &&
        !current.mine &&
        (index == messages.length - 1 ||
            next!.isSystem ||
            next.authorId != current.authorId ||
            next.mine);

    return current.copyWith(
      showAuthor: showAuthor,
      showAvatar: showAvatar,
    );
  }

  Message _mergeMessageVersions(Message existing, Message incoming) {
    final mergedAttachments =
        _mergeAttachments(existing.attachments, incoming.attachments);
    final effectiveCreatedAt = incoming.createdAt ?? existing.createdAt;
    final keepLocalMineFlag =
        existing.mine && existing.clientMessageId == incoming.clientMessageId;

    return incoming.copyWith(
      createdAt: effectiveCreatedAt,
      time: effectiveCreatedAt == null
          ? incoming.time
          : _formatLocalTime(effectiveCreatedAt),
      mine: keepLocalMineFlag ? true : incoming.mine,
      attachments: mergedAttachments,
      replyTo: incoming.replyTo ?? existing.replyTo,
      isPending: incoming.isPending &&
          mergedAttachments.every((attachment) => attachment.status != 'ready'),
    );
  }

  List<MessageAttachment> _mergeAttachments(
    List<MessageAttachment> existing,
    List<MessageAttachment> incoming,
  ) {
    if (incoming.isEmpty) {
      return existing;
    }

    return incoming.asMap().entries.map((entry) {
      final incomingAttachment = entry.value;
      final existingAttachment = _findMatchingAttachment(
        existing,
        incomingAttachment,
        fallbackIndex: entry.key,
        expectedLength: incoming.length,
      );
      if (existingAttachment == null) {
        return incomingAttachment;
      }
      return _mergeAttachment(existingAttachment, incomingAttachment);
    }).toList(growable: false);
  }

  MessageAttachment? _findMatchingAttachment(
    List<MessageAttachment> existing,
    MessageAttachment incoming, {
    required int fallbackIndex,
    required int expectedLength,
  }) {
    for (final attachment in existing) {
      if (attachment.id == incoming.id) {
        return attachment;
      }
      if (attachment.fileName == incoming.fileName &&
          attachment.mimeType == incoming.mimeType) {
        return attachment;
      }
    }

    if (existing.length == expectedLength &&
        fallbackIndex >= 0 &&
        fallbackIndex < existing.length) {
      return existing[fallbackIndex];
    }

    return null;
  }

  MessageAttachment _mergeAttachment(
    MessageAttachment existing,
    MessageAttachment incoming,
  ) {
    final shouldKeepLocalReadyState =
        (existing.localBytes != null || existing.localPath != null) &&
            incoming.url == null;

    return incoming.copyWith(
      status: shouldKeepLocalReadyState ? 'ready' : incoming.status,
      url: incoming.url ?? existing.url,
      downloadUrlPath: incoming.downloadUrlPath ?? existing.downloadUrlPath,
      localBytes: incoming.localBytes ?? existing.localBytes,
      localPath: incoming.localPath ?? existing.localPath,
      title: incoming.title ?? existing.title,
      subtitle: incoming.subtitle ?? existing.subtitle,
      latitude: incoming.latitude ?? existing.latitude,
      longitude: incoming.longitude ?? existing.longitude,
      expiresAt: incoming.expiresAt ?? existing.expiresAt,
      durationMs: incoming.durationMs ?? existing.durationMs,
      waveform: incoming.waveform ?? existing.waveform,
    );
  }

  List<Message> _sortMessages(List<Message> messages) {
    final indexed = messages.asMap().entries.toList(growable: false);
    indexed.sort((left, right) {
      final leftCreatedAt = left.value.createdAt;
      final rightCreatedAt = right.value.createdAt;
      if (leftCreatedAt == null || rightCreatedAt == null) {
        return left.key.compareTo(right.key);
      }
      final createdAtComparison = leftCreatedAt.compareTo(rightCreatedAt);
      if (createdAtComparison != 0) {
        return createdAtComparison;
      }
      return left.key.compareTo(right.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  int _insertMessageInOrder(List<Message> messages, Message message) {
    final index = _orderedInsertIndex(messages, message);
    messages.insert(index, message);
    return index;
  }

  int _orderedInsertIndex(List<Message> messages, Message message) {
    var low = 0;
    var high = messages.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_comesBeforeOrSame(messages[middle], message)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  bool _comesBeforeOrSame(Message left, Message right) {
    final leftCreatedAt = left.createdAt;
    final rightCreatedAt = right.createdAt;
    if (leftCreatedAt == null || rightCreatedAt == null) {
      return true;
    }
    return leftCreatedAt.compareTo(rightCreatedAt) <= 0;
  }

  String _formatLocalTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _mimeTypeForFile(PlatformFile file) {
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return 'application/octet-stream';
  }

  Uint8List? _localBytesForMessage(PlatformFile file) {
    return file.bytes;
  }
}

class _MessageMergeResult {
  const _MessageMergeResult(this.messages, this.changedIndices);

  final List<Message> messages;
  final List<int> changedIndices;
}
