import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/device/app_voice_recorder_service.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/chats/presentation/chat_voice_playback_controller.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_map_choice_sheet.dart';
import 'package:mobile2/shared/widgets/dateasy_media_viewer.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class MeetingChatScreen extends ConsumerStatefulWidget {
  const MeetingChatScreen({super.key, required this.meetingId});

  final String meetingId;

  @override
  ConsumerState<MeetingChatScreen> createState() => _MeetingChatScreenState();
}

class _MeetingChatScreenState extends ConsumerState<MeetingChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _messagesScrollController = ScrollController();
  bool _attachOpen = false;
  _SheetKind? _sheet;
  bool _sending = false;
  bool _attaching = false;
  bool _recording = false;
  bool _voicePointerDown = false;
  bool _voicePointerEnded = false;
  AppVoiceRecorderService? _activeVoiceRecorder;
  Duration _recordingDuration = Duration.zero;
  List<double> _recordingWaveform = const [];
  Timer? _recordingTimer;
  StreamSubscription<double>? _recordingAmplitudeSubscription;
  bool _didScrollToInitialMessagesEnd = false;
  bool _initialMessagesScrollScheduled = false;
  bool _didRefreshListsAfterOpen = false;
  _ReplyDraft? _replyingTo;
  BackendChatMessage? _messageActionTarget;
  final Map<String, GlobalKey> _messageItemKeys = {};

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messagesScrollController.addListener(_loadOlderMessagesNearTop);
  }

  @override
  void dispose() {
    _controller.dispose();
    _composerFocusNode.dispose();
    _messagesScrollController
      ..removeListener(_loadOlderMessagesNearTop)
      ..dispose();
    _recordingTimer?.cancel();
    unawaited(_recordingAmplitudeSubscription?.cancel());
    if (_recording) {
      unawaited(_activeVoiceRecorder?.cancel() ?? Future<void>.value());
    }
    super.dispose();
  }

  void _loadOlderMessagesNearTop() {
    if (!_messagesScrollController.hasClients) {
      return;
    }
    final position = _messagesScrollController.position;
    if (position.pixels > 120) {
      return;
    }
    unawaited(
      ref
          .read(chatHistoryPaginationProvider(widget.meetingId).notifier)
          .loadNextPage(),
    );
  }

  void _scheduleInitialScrollToLatest(List<BackendChatMessage> messages) {
    if (_didScrollToInitialMessagesEnd ||
        _initialMessagesScrollScheduled ||
        messages.isEmpty) {
      return;
    }
    _initialMessagesScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialMessagesScrollScheduled = false;
      if (!mounted || !_messagesScrollController.hasClients) {
        return;
      }
      final position = _messagesScrollController.position;
      if (position.maxScrollExtent <= 0) {
        return;
      }
      _messagesScrollController.jumpTo(position.maxScrollExtent);
      _didScrollToInitialMessagesEnd = true;
    });
  }

  @override
  void didUpdateWidget(covariant MeetingChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meetingId != widget.meetingId) {
      _didScrollToInitialMessagesEnd = false;
      _initialMessagesScrollScheduled = false;
      _didRefreshListsAfterOpen = false;
      _replyingTo = null;
      _messageActionTarget = null;
      _messageItemKeys.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatRealtimeProvider(widget.meetingId));
    final summary =
        ref.watch(chatSummaryProvider(widget.meetingId)).valueOrNull;
    final composerHint = summary?.kind == 'community'
        ? 'Сообщение в чат'
        : 'Сообщение в чат встречи';
    return DateasyPhoneFrame(
      child: Stack(
        children: [
          Column(
            children: [
              _Header(
                meetingId: widget.meetingId,
                onPeople: () => setState(() => _sheet = _SheetKind.people),
                onMenu: () => setState(() => _sheet = _SheetKind.menu),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final messages =
                        ref.watch(chatMessagesProvider(widget.meetingId));
                    final optimisticMessages = ref.watch(
                      chatOptimisticMessagesProvider(widget.meetingId),
                    );
                    final pagination = ref
                        .watch(chatHistoryPaginationProvider(widget.meetingId));
                    return messages.when(
                      data: (items) {
                        _refreshChatListsAfterOpen(summary);
                        final visibleItems =
                            _mergeOptimisticMessages(items, optimisticMessages);
                        _pruneMessageKeys(visibleItems);
                        if (visibleItems.isEmpty) {
                          return const Center(
                            child: _SystemMessage(text: 'Сообщений пока нет'),
                          );
                        }
                        final paginationController = ref.read(
                          chatHistoryPaginationProvider(widget.meetingId)
                              .notifier,
                        );
                        _scheduleInitialScrollToLatest(visibleItems);
                        return ListView.separated(
                          controller: _messagesScrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                          itemCount: visibleItems.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _OlderMessagesButton(
                                state: pagination,
                                onTap: () =>
                                    paginationController.loadNextPage(),
                              );
                            }
                            final message = visibleItems[index - 1];
                            final stableKey = _messageStableKey(message);
                            final itemKey = _messageItemKeys.putIfAbsent(
                              stableKey,
                              GlobalKey.new,
                            );
                            _messageItemKeys[message.id] = itemKey;
                            return _MessageBubble.fromBackend(
                              message,
                              key: itemKey,
                              onRetry: _retryMessage,
                              onReply: () => _startReply(message),
                              onLongPress: () => _showMessageActions(message),
                              onQuoteTap: _scrollToMessage,
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: _SystemMessage(text: 'Загружаю сообщения'),
                      ),
                      error: (_, __) => const Center(
                        child: _SystemMessage(text: 'Чат недоступен'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          _Composer(
            controller: _controller,
            focusNode: _composerFocusNode,
            attachOpen: _attachOpen,
            hasText: _hasText,
            sending: _sending || _attaching,
            recording: _recording,
            recordingDuration: _recordingDuration,
            recordingWaveform: _recordingWaveform,
            replyDraft: _replyingTo,
            hintText: composerHint,
            onChanged: () => setState(() {}),
            onAttach: () => setState(() => _attachOpen = !_attachOpen),
            onCancelReply: () => setState(() => _replyingTo = null),
            onPickPhoto: _pickPhotoAttachment,
            onShareLocation: _shareLocationAttachment,
            onVoiceTap: _handleVoiceTap,
            onVoicePressStart: _handleVoicePressStart,
            onVoicePressEnd: _handleVoicePressEnd,
            onVoicePressCancel: _handleVoicePressCancel,
            onSend: _sendMessage,
          ),
          if (_messageActionTarget != null)
            _MessageActionOverlay(
              message: _messageActionTarget!,
              onClose: () => setState(() => _messageActionTarget = null),
              onReply: () {
                final message = _messageActionTarget;
                if (message == null) {
                  return;
                }
                setState(() => _messageActionTarget = null);
                _startReply(message);
              },
              onDelete: _deleteMessage,
            ),
          if (_sheet != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _sheet = null),
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
            ),
          if (_sheet == _SheetKind.people)
            _PeopleSheet(
              chatId: widget.meetingId,
              onClose: () => setState(() => _sheet = null),
            ),
          if (_sheet == _SheetKind.menu)
            _MenuSheet(
              chatId: widget.meetingId,
              onPeople: () => setState(() => _sheet = _SheetKind.people),
              onClose: () => setState(() => _sheet = null),
            ),
        ],
      ),
    );
  }

  void _pruneMessageKeys(List<BackendChatMessage> messages) {
    final activeKeys = messages.map(_messageStableKey).toSet();
    _messageItemKeys.removeWhere((key, _) => !activeKeys.contains(key));
  }

  void _startReply(BackendChatMessage message) {
    if (_isSystemMessage(message)) {
      return;
    }
    setState(() {
      _replyingTo = _ReplyDraft.fromMessage(message);
      _attachOpen = false;
    });
    _composerFocusNode.requestFocus();
  }

  void _showMessageActions(BackendChatMessage message) {
    if (_isSystemMessage(message)) {
      return;
    }
    setState(() => _messageActionTarget = message);
  }

  Future<void> _deleteMessage(BackendChatMessage message) async {
    setState(() => _messageActionTarget = null);
    try {
      await ref.read(chatMessageSenderProvider).deleteMessage(
            chatId: widget.meetingId,
            messageId: message.id,
            clientMessageId: message.clientMessageId,
            pending: message.pending,
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showChatSnack(context, 'Не удалось удалить сообщение');
    }
  }

  Future<void> _scrollToMessage(String messageId) async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      final key = _messageItemKeys[messageId];
      final itemContext = key?.currentContext;
      if (itemContext != null && itemContext.mounted) {
        await Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.28,
        );
        return;
      }
      final pagination =
          ref.read(chatHistoryPaginationProvider(widget.meetingId));
      if (!pagination.hasNextPage || pagination.loading) {
        break;
      }
      await ref
          .read(chatHistoryPaginationProvider(widget.meetingId).notifier)
          .loadNextPage();
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) {
        return;
      }
    }
    if (mounted) {
      _showChatSnack(context, 'Сообщение выше в истории');
    }
  }

  void _sendMessage() {
    final text = _controller.text;
    if (_sending || text.trim().isEmpty) {
      return;
    }
    final chatId = widget.meetingId;
    final sender = ref.read(chatMessageSenderProvider);
    final session = ref.read(chatRealtimeProvider(chatId));
    final replyTo = _replyingTo?.toPayload();
    setState(() {
      _sending = false;
      _controller.clear();
      _replyingTo = null;
    });
    _composerFocusNode.requestFocus();
    unawaited(
      sender
          .sendText(
        chatId: chatId,
        text: text,
        replyTo: replyTo,
      )
          .then((_) {
        if (!mounted) {
          return;
        }
        _scheduleScrollToLatestMessage();
        unawaited(session?.flushOutbox() ?? Future<void>.value());
        _refreshChatAfterSend();
      }).catchError((Object _) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить сообщение'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: DateasyColors.surface2,
          ),
        );
      }),
    );
  }

  void _retryMessage(String clientMessageId) {
    unawaited(
      ref
          .read(chatMessageSenderProvider)
          .retryMessage(
            chatId: widget.meetingId,
            clientMessageId: clientMessageId,
          )
          .then((_) {
        if (mounted) {
          _scheduleScrollToLatestMessage();
        }
      }).catchError((Object _) {
        if (mounted) {
          _showChatSnack(context, 'Не удалось повторить отправку');
        }
      }),
    );
  }

  Future<void> _pickPhotoAttachment() async {
    if (_attaching) {
      return;
    }
    setState(() => _attaching = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) {
        return;
      }
      await ref.read(chatMessageSenderProvider).sendAttachment(
            chatId: widget.meetingId,
            filePath: picked.path,
            fileName: picked.name,
            mimeType: _guessMimeType(picked.name, picked.mimeType),
            replyTo: _replyingTo?.toPayload(),
          );
      if (!mounted) {
        return;
      }
      _scheduleScrollToLatestMessage();
      unawaited(
        ref.read(chatRealtimeProvider(widget.meetingId))?.flushOutbox() ??
            Future<void>.value(),
      );
      _refreshChatAfterSend();
      setState(() {
        _attachOpen = false;
        _replyingTo = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showChatSnack(context, 'Не удалось отправить фото');
    } finally {
      if (mounted) {
        setState(() => _attaching = false);
      }
    }
  }

  Future<void> _shareLocationAttachment() async {
    if (_attaching) {
      return;
    }
    setState(() => _attaching = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showChatSnack(context, 'Геолокация выключена');
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showChatSnack(context, 'Нет доступа к геолокации');
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final label = await _reverseLocationLabel(
        position.latitude,
        position.longitude,
      );
      await ref.read(chatMessageSenderProvider).sendLocation(
            chatId: widget.meetingId,
            latitude: position.latitude,
            longitude: position.longitude,
            label: label,
            replyTo: _replyingTo?.toPayload(),
          );
      if (!mounted) {
        return;
      }
      _scheduleScrollToLatestMessage();
      unawaited(
        ref.read(chatRealtimeProvider(widget.meetingId))?.flushOutbox() ??
            Future<void>.value(),
      );
      _refreshChatAfterSend();
      setState(() {
        _attachOpen = false;
        _replyingTo = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showChatSnack(context, 'Не удалось отправить локацию');
    } finally {
      if (mounted) {
        setState(() => _attaching = false);
      }
    }
  }

  Future<String?> _reverseLocationLabel(
    double latitude,
    double longitude,
  ) async {
    try {
      final places = await geo.placemarkFromCoordinates(latitude, longitude);
      final first = places.firstOrNull;
      if (first == null) {
        return null;
      }
      return [
        first.name,
        first.street,
        first.locality,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleVoicePressStart() async {
    if (_sending || _attaching) {
      return;
    }
    _voicePointerDown = true;
    _voicePointerEnded = false;
    if (_recording) {
      await _stopVoiceRecording();
      return;
    }
    await _startVoiceRecording();
    if (!_voicePointerDown && _recording) {
      await _stopVoiceRecording();
    }
  }

  Future<void> _handleVoiceTap() async {
    if (_voicePointerEnded) {
      _voicePointerEnded = false;
      return;
    }
    if (_recording) {
      await _handleVoicePressEnd();
      return;
    }
    if (_sending || _attaching) {
      return;
    }
    _voicePointerDown = true;
    await _startVoiceRecording();
    _voicePointerDown = false;
    if (_recording) {
      await _stopVoiceRecording();
    }
  }

  Future<void> _handleVoicePressEnd() async {
    _voicePointerDown = false;
    _voicePointerEnded = true;
    if (!_recording) {
      return;
    }
    await _stopVoiceRecording();
  }

  Future<void> _handleVoicePressCancel() async {
    _voicePointerDown = false;
    if (!_recording) {
      return;
    }
    await _cancelVoiceRecording();
  }

  Future<void> _startVoiceRecording() async {
    final recorder = ref.read(appVoiceRecorderServiceProvider);
    _activeVoiceRecorder = recorder;
    final allowed = await recorder.hasPermission();
    if (!allowed) {
      if (!mounted) {
        return;
      }
      _showChatSnack(context, 'Нет доступа к микрофону');
      return;
    }
    try {
      await recorder.start();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showChatSnack(context, 'Не получилось начать запись');
      return;
    }
    if (!mounted) {
      await recorder.cancel();
      return;
    }
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = recorder.amplitudeStream.listen((value) {
      if (!mounted) {
        return;
      }
      final next = [..._recordingWaveform, value.clamp(0.08, 1.0).toDouble()];
      if (next.length > 32) {
        next.removeRange(0, next.length - 32);
      }
      setState(() => _recordingWaveform = next);
    });
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recordingDuration += const Duration(milliseconds: 200);
      });
    });
    setState(() {
      _recording = true;
      _recordingDuration = Duration.zero;
      _recordingWaveform = const [];
      _attachOpen = false;
    });
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    setState(() => _attaching = true);
    try {
      final voice = await ref.read(appVoiceRecorderServiceProvider).stop();
      _activeVoiceRecorder = null;
      if (!mounted) {
        return;
      }
      setState(() => _recording = false);
      if (voice.durationMs < 500) {
        _showChatSnack(context, 'Голосовое слишком короткое');
        return;
      }
      final chatId = widget.meetingId;
      final sender = ref.read(chatMessageSenderProvider);
      final session = ref.read(chatRealtimeProvider(chatId));
      final replyTo = _replyingTo?.toPayload();
      setState(() => _attaching = false);
      unawaited(
        sender
            .sendAttachment(
          chatId: chatId,
          filePath: voice.path,
          fileName: voice.fileName,
          mimeType: 'audio/mp4',
          kind: 'chat_voice',
          durationMs: voice.durationMs,
          waveform: voice.waveform,
          replyTo: replyTo,
        )
            .then((_) {
          if (mounted) {
            setState(() => _replyingTo = null);
            _scheduleScrollToLatestMessage();
            unawaited(session?.flushOutbox() ?? Future<void>.value());
            _refreshChatAfterSend();
          }
        }).catchError((Object _) {
          if (mounted) {
            _showChatSnack(context, 'Не удалось отправить голосовое');
          }
        }),
      );
    } catch (_) {
      if (_recording) {
        await (_activeVoiceRecorder?.cancel() ?? Future<void>.value());
        _activeVoiceRecorder = null;
      }
      if (!mounted) {
        return;
      }
      _showChatSnack(context, 'Не удалось отправить голосовое');
    } finally {
      if (mounted) {
        setState(() {
          _attaching = false;
          _recording = false;
          _recordingDuration = Duration.zero;
          _recordingWaveform = const [];
        });
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    await (_activeVoiceRecorder?.cancel() ?? Future<void>.value());
    _activeVoiceRecorder = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _recording = false;
      _recordingDuration = Duration.zero;
      _recordingWaveform = const [];
    });
  }

  void _refreshChatAfterSend() {
    if (ref.read(chatLocalStoreProvider) != null) {
      return;
    }
    ref.invalidate(chatMessagesProvider(widget.meetingId));
  }

  void _refreshChatListsAfterOpen(BackendChatSummary? summary) {
    if (_didRefreshListsAfterOpen || summary != null) {
      return;
    }
    _didRefreshListsAfterOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(chatListProvider);
      ref.invalidate(chatsProvider);
      ref.invalidate(chatSummaryProvider(widget.meetingId));
    });
  }

  void _scheduleScrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) {
        return;
      }
      final position = _messagesScrollController.position;
      _messagesScrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.meetingId,
    required this.onPeople,
    required this.onMenu,
  });

  final String meetingId;
  final VoidCallback onPeople;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(chatSummaryProvider(meetingId)).valueOrNull;
    final meta = _ChatHeaderData.fromSummary(summary, fallbackId: meetingId);
    return _GlassPanel(
      borderRadius: 0,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      borderAlpha: 0.05,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                _GlassIconButton(
                  icon: LucideIcons.arrowLeft,
                  onTap: () => context.go(meta.backRoute),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final route = meta.primaryProfileRoute;
                      if (route == null) {
                        onPeople();
                      } else {
                        context.push(route);
                      }
                    },
                    child: Row(
                      children: [
                        _HeaderAvatars(participants: meta.participants),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                meta.peopleLine,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: DateasyColors.lime,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _GlassIconButton(
                  icon: LucideIcons.ellipsis,
                  onTap: onMenu,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push(meta.detailsRoute),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: meta.isCommunity
                  ? _CommunityContextLink(meta: meta)
                  : _MeetingContextLink(meta: meta),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingContextLink extends StatelessWidget {
  const _MeetingContextLink({required this.meta});

  final _ChatHeaderData meta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ContextIcon(
          icon: meta.isDirect
              ? LucideIcons.messageCircle
              : LucideIcons.calendarHeart,
        ),
        const SizedBox(width: 10),
        const Icon(
          LucideIcons.clock,
          size: 12,
          color: DateasyColors.muted,
        ),
        const SizedBox(width: 4),
        Text(
          meta.timeLine,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
                fontSize: 12,
              ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted.withValues(alpha: 0.45),
                ),
          ),
        ),
        const Icon(
          LucideIcons.mapPin,
          size: 12,
          color: DateasyColors.lime,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            meta.contextLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        _ContextAction(label: meta.actionLabel),
      ],
    );
  }
}

class _CommunityContextLink extends StatelessWidget {
  const _CommunityContextLink({required this.meta});

  final _ChatHeaderData meta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _ContextIcon(icon: LucideIcons.users),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            meta.contextLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        _ContextAction(label: meta.actionLabel),
      ],
    );
  }
}

class _ContextIcon extends StatelessWidget {
  const _ContextIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: dateasyLimeGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 14,
        color: DateasyColors.backgroundDeep,
      ),
    );
  }
}

class _ContextAction extends StatelessWidget {
  const _ContextAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: DateasyColors.foreground,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.background,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _HeaderAvatars extends StatelessWidget {
  const _HeaderAvatars({required this.participants});

  final List<_Participant> participants;

  @override
  Widget build(BuildContext context) {
    final visible = participants.take(3).toList();

    return SizedBox(
      width: 66,
      height: 36,
      child: Stack(
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 15,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: DateasyColors.background, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: DateasyRemoteImage(
                  imageUrl: visible[index].imageUrl,
                  usage: DateasyImageUsage.avatar,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatHeaderData {
  const _ChatHeaderData({
    required this.title,
    required this.peopleLine,
    required this.timeLine,
    required this.contextLine,
    required this.actionLabel,
    required this.backRoute,
    required this.detailsRoute,
    this.primaryProfileRoute,
    required this.participants,
    required this.isDirect,
    required this.isCommunity,
  });

  final String title;
  final String peopleLine;
  final String timeLine;
  final String contextLine;
  final String actionLabel;
  final String backRoute;
  final String detailsRoute;
  final String? primaryProfileRoute;
  final List<_Participant> participants;
  final bool isDirect;
  final bool isCommunity;

  factory _ChatHeaderData.fromSummary(
    BackendChatSummary? summary, {
    required String fallbackId,
  }) {
    if (summary == null) {
      return const _ChatHeaderData(
        title: 'Чат',
        peopleLine: 'Данные чата обновляются',
        timeLine: 'Обновляю данные',
        contextLine: 'Сообщения доступны локально',
        actionLabel: 'Чат',
        backRoute: '/chats',
        detailsRoute: '/chats',
        participants: [
          _Participant(
            name: 'Чат',
            userId: null,
            imageUrl: null,
            role: 'Участник',
            online: false,
          ),
        ],
        isDirect: false,
        isCommunity: false,
      );
    }

    final raw = summary.raw;
    final peerUserId = _stringOrNull(raw['peerUserId']);
    final eventId = _stringOrNull(raw['eventId']);
    final communityId = _stringOrNull(raw['communityId']);
    final isCommunity = summary.kind == 'community' || communityId != null;
    final isDirect = peerUserId != null || summary.kind == 'personal';
    final participants = _participantsFromSummary(summary, isDirect: isDirect);
    final onlineCount = participants.where((item) => item.online).length;
    if (isCommunity) {
      final membersCount = _intOrNull(raw['membersCount'] ?? raw['members']);
      final total = membersCount ?? participants.length;
      return _ChatHeaderData(
        title: summary.title.isEmpty ? 'Сообщество' : summary.title,
        peopleLine: '$onlineCount онлайн · $total участников',
        timeLine: 'Сообщество',
        contextLine: 'Открыть группу',
        actionLabel: 'Сообщество',
        backRoute: '/chats',
        detailsRoute: communityId == null
            ? '/chats'
            : '/communities/${Uri.encodeComponent(communityId)}',
        participants: participants,
        isDirect: false,
        isCommunity: true,
      );
    }

    final peopleLine = isDirect
        ? (onlineCount > 0 ? 'онлайн' : 'личный чат')
        : '$onlineCount онлайн · ${participants.length} участников';
    final status = _stringOrNull(raw['status']);
    final time = _stringOrNull(raw['time'] ?? raw['lastTime']);
    final timeLine = [status, time]
        .where((item) => item != null && item.isNotEmpty)
        .join(' · ');
    final fromMeetup = _stringOrNull(raw['fromMeetup']);
    final meetingContextLine = _stringOrNull(
      raw['contextLine'] ??
          raw['venueLine'] ??
          raw['locationName'] ??
          raw['placeName'],
    );

    return _ChatHeaderData(
      title: summary.title.isEmpty ? 'Чат' : summary.title,
      peopleLine: peopleLine,
      timeLine:
          timeLine.isEmpty ? (isDirect ? 'Личный чат' : 'Встреча') : timeLine,
      contextLine: isDirect
          ? (fromMeetup == null ? 'Личный чат' : 'После встречи: $fromMeetup')
          : (meetingContextLine ?? 'Детали встречи'),
      actionLabel: isDirect ? 'Профиль' : 'Встреча',
      backRoute: '/chats',
      detailsRoute: isDirect
          ? (peerUserId == null ? '/chats' : '/u/$peerUserId')
          : (eventId == null ? '/chats' : '/meetings/$eventId'),
      primaryProfileRoute: isDirect && peerUserId != null
          ? '/u/${Uri.encodeComponent(peerUserId)}'
          : null,
      participants: participants,
      isDirect: isDirect,
      isCommunity: false,
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: DateasyColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
                fontSize: 11,
              ),
        ),
      ),
    );
  }
}

class _OlderMessagesButton extends StatelessWidget {
  const _OlderMessagesButton({
    required this.state,
    required this.onTap,
  });

  final ChatHistoryPaginationState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!state.hasNextPage && !state.error) {
      return const SizedBox.shrink();
    }
    return Center(
      child: GestureDetector(
        onTap: state.loading ? () {} : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: DateasyColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.loading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                state.error
                    ? 'Повторить загрузку'
                    : state.loading
                        ? 'Загружаю'
                        : 'Ранее',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: state.error
                          ? DateasyColors.pink
                          : DateasyColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageActionOverlay extends StatelessWidget {
  const _MessageActionOverlay({
    required this.message,
    required this.onClose,
    required this.onReply,
    required this.onDelete,
  });

  final BackendChatMessage message;
  final VoidCallback onClose;
  final VoidCallback onReply;
  final ValueChanged<BackendChatMessage> onDelete;

  @override
  Widget build(BuildContext context) {
    final mine = message.raw['mine'] == true;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.18),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.96, end: 1),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 190,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: DateasyColors.surface2.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 32,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MessageActionRow(
                      icon: LucideIcons.reply,
                      label: 'Ответить',
                      onTap: onReply,
                    ),
                    if (mine)
                      _MessageActionRow(
                        icon: LucideIcons.trash2,
                        label: 'Удалить',
                        danger: true,
                        onTap: () => onDelete(message),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageActionRow extends StatelessWidget {
  const _MessageActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? DateasyColors.pink : DateasyColors.foreground;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.chatId,
    required this.text,
    required this.time,
    this.system = false,
    this.mine = false,
    this.name,
    this.image,
    this.profileRoute,
    this.attachments = const [],
    this.location,
    this.replyTo,
    this.status = _MessageSendStatus.sent,
    this.clientMessageId,
    this.onRetry,
    this.onReply,
    this.onLongPress,
    this.onQuoteTap,
  });

  final String chatId;
  final String text;
  final String time;
  final bool system;
  final bool mine;
  final String? name;
  final String? image;
  final String? profileRoute;
  final List<_ChatAttachmentPreview> attachments;
  final _ChatLocationPreview? location;
  final _ReplyDraft? replyTo;
  final _MessageSendStatus status;
  final String? clientMessageId;
  final ValueChanged<String>? onRetry;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onQuoteTap;

  factory _MessageBubble.fromBackend(
    BackendChatMessage message, {
    Key? key,
    ValueChanged<String>? onRetry,
    VoidCallback? onReply,
    VoidCallback? onLongPress,
    ValueChanged<String>? onQuoteTap,
  }) {
    final attachments = _attachmentPreviews(message.raw['attachments']);
    final location = _ChatLocationPreview.fromRaw(message.raw['location']);
    final system = _isSystemMessage(message);
    final senderId = message.senderId;
    final senderRoute = system ||
            senderId == null ||
            senderId.isEmpty ||
            message.raw['mine'] == true
        ? null
        : '/u/${Uri.encodeComponent(senderId)}';
    return _MessageBubble(
      key: key,
      chatId: message.chatId,
      name: message.senderName ?? 'Участник',
      image: message.senderAvatarUrl,
      profileRoute: senderRoute,
      text: chatMessageBubbleText(
        messageText: message.text,
        nonVoiceAttachmentLabels: attachments
            .where((attachment) => !attachment.isVoice)
            .map((attachment) => attachment.label)
            .toList(growable: false),
      ),
      time: _formatTime(message.createdAt),
      system: system,
      mine: message.raw['mine'] == true,
      attachments: attachments,
      location: location,
      replyTo: _ReplyDraft.fromRaw(message.raw['replyTo']),
      status: _messageSendStatus(message, attachments),
      clientMessageId: message.clientMessageId,
      onRetry: onRetry,
      onReply: onReply,
      onLongPress: onLongPress,
      onQuoteTap: onQuoteTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (system) {
      return _SystemMessage(text: text);
    }

    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.78;
    final hasText = text.trim().isNotEmpty;
    final hasLocation = location != null;
    if (mine) {
      return _SwipeReplyGesture(
        onReply: onReply,
        onLongPress: onLongPress,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              alignment: Alignment.bottomRight,
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasText || replyTo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            gradient: dateasyLimeGradient,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x55BEFF67),
                                blurRadius: 24,
                                spreadRadius: -12,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (replyTo != null) ...[
                                _ReplyQuote(
                                  reply: replyTo!,
                                  mine: true,
                                  onTap: onQuoteTap,
                                ),
                                if (hasText) const SizedBox(height: 7),
                              ],
                              if (hasText)
                                Text(
                                  text,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: DateasyColors.backgroundDeep,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      if (attachments.isNotEmpty) ...[
                        if (hasText || hasLocation) const SizedBox(height: 6),
                        for (final attachment in attachments)
                          _AttachmentPreviewPill(
                            chatId: chatId,
                            attachment: attachment,
                          ),
                      ],
                      if (hasLocation) ...[
                        if (hasText) const SizedBox(height: 6),
                        _ChatLocationCard(location: location!),
                      ],
                      const SizedBox(height: 4),
                      _MessageMeta(
                        time: time,
                        status: status,
                        clientMessageId: clientMessageId,
                        onRetry: onRetry,
                        alignEnd: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipOval(
          child: SizedBox(
            width: 28,
            height: 28,
            child: DateasyRemoteImage(
              imageUrl: image,
              usage: DateasyImageUsage.avatar,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 4),
                if (hasText || replyTo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: DateasyColors.glass,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyTo != null) ...[
                          _ReplyQuote(
                            reply: replyTo!,
                            mine: false,
                            onTap: onQuoteTap,
                          ),
                          if (hasText) const SizedBox(height: 7),
                        ],
                        if (hasText)
                          Text(
                            text,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                if (attachments.isNotEmpty) ...[
                  if (hasText || hasLocation) const SizedBox(height: 6),
                  for (final attachment in attachments)
                    _AttachmentPreviewPill(
                      chatId: chatId,
                      attachment: attachment,
                    ),
                ],
                if (hasLocation) ...[
                  if (hasText) const SizedBox(height: 6),
                  _ChatLocationCard(location: location!),
                ],
                const SizedBox(height: 4),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final route = profileRoute;
    if (route == null) {
      return _SwipeReplyGesture(
        onReply: onReply,
        onLongPress: onLongPress,
        child: content,
      );
    }
    return _SwipeReplyGesture(
      onReply: onReply,
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(route),
        child: content,
      ),
    );
  }
}

class _SwipeReplyGesture extends StatefulWidget {
  const _SwipeReplyGesture({
    required this.child,
    this.onReply,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;

  @override
  State<_SwipeReplyGesture> createState() => _SwipeReplyGestureState();
}

class _SwipeReplyGestureState extends State<_SwipeReplyGesture> {
  double _dragOffset = 0;
  bool _replied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: widget.onLongPress,
      onHorizontalDragStart: (_) {
        _dragOffset = 0;
        _replied = false;
      },
      onHorizontalDragUpdate: (details) {
        if (_replied) {
          return;
        }
        _dragOffset += details.primaryDelta ?? 0;
        if (_dragOffset <= -48) {
          _replied = true;
          widget.onReply?.call();
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (!_replied && velocity < -120) {
          _replied = true;
          widget.onReply?.call();
        }
      },
      child: widget.child,
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.reply,
    required this.mine,
    required this.onTap,
  });

  final _ReplyDraft reply;
  final bool mine;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        mine ? DateasyColors.backgroundDeep : DateasyColors.foreground;
    final muted = mine
        ? DateasyColors.backgroundDeep.withValues(alpha: 0.68)
        : DateasyColors.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap?.call(reply.id),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.fromLTRB(8, 6, 9, 6),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withValues(alpha: 0.22)
              : DateasyColors.background.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: mine ? DateasyColors.backgroundDeep : DateasyColors.lime,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reply.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              reply.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyDraft {
  const _ReplyDraft({
    required this.id,
    required this.author,
    required this.preview,
    this.authorId,
    this.isVoice = false,
  });

  final String id;
  final String author;
  final String preview;
  final String? authorId;
  final bool isVoice;

  factory _ReplyDraft.fromMessage(BackendChatMessage message) {
    final attachments = _attachmentPreviews(message.raw['attachments']);
    final isVoice = attachments.any((attachment) => attachment.isVoice);
    final fallbackPreview = attachments.isEmpty
        ? 'Сообщение'
        : isVoice
            ? 'Голосовое'
            : attachments.first.isImage
                ? 'Фото'
                : attachments.first.label;
    final preview =
        message.text.trim().isEmpty ? fallbackPreview : message.text.trim();
    return _ReplyDraft(
      id: message.id,
      authorId: message.senderId,
      author: message.raw['mine'] == true
          ? 'Вы'
          : (message.senderName ?? 'Участник'),
      preview: preview,
      isVoice: isVoice,
    );
  }

  static _ReplyDraft? fromRaw(Object? value) {
    if (value is! Map) {
      return null;
    }
    final id = _stringOrNull(value['id']);
    if (id == null) {
      return null;
    }
    return _ReplyDraft(
      id: id,
      authorId: _stringOrNull(value['authorId']),
      author: _stringOrNull(value['author']) ?? 'Участник',
      preview: _stringOrNull(value['text']) ??
          (value['isVoice'] == true ? 'Голосовое' : 'Сообщение'),
      isVoice: value['isVoice'] == true,
    );
  }

  Map<String, Object?> toPayload() {
    return {
      'id': id,
      'author': author,
      'text': preview,
      'isVoice': isVoice,
      if (authorId != null) 'authorId': authorId,
    };
  }
}

String chatMessageBubbleText({
  required String messageText,
  required List<String> nonVoiceAttachmentLabels,
}) {
  return messageText;
}

String _messageStableKey(BackendChatMessage message) {
  final clientMessageId = message.clientMessageId;
  if (clientMessageId != null && clientMessageId.isNotEmpty) {
    return clientMessageId;
  }
  return message.id;
}

List<BackendChatMessage> _mergeOptimisticMessages(
  List<BackendChatMessage> serverMessages,
  List<BackendChatMessage> optimisticMessages,
) {
  if (optimisticMessages.isEmpty) {
    return serverMessages;
  }
  final serverKeys = serverMessages.expand((message) {
    return [
      message.id,
      if (message.clientMessageId != null &&
          message.clientMessageId!.isNotEmpty)
        message.clientMessageId!,
    ];
  }).toSet();
  final pending = optimisticMessages
      .where((message) => !serverKeys.contains(message.id))
      .where(
        (message) =>
            message.clientMessageId == null ||
            !serverKeys.contains(message.clientMessageId),
      )
      .toList(growable: false);
  if (pending.isEmpty) {
    return serverMessages;
  }
  return [...serverMessages, ...pending]..sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null || bDate == null) {
        return 0;
      }
      return aDate.compareTo(bDate);
    });
}

class _AttachmentPreviewPill extends ConsumerStatefulWidget {
  const _AttachmentPreviewPill({
    required this.chatId,
    required this.attachment,
  });

  final String chatId;
  final _ChatAttachmentPreview attachment;

  @override
  ConsumerState<_AttachmentPreviewPill> createState() =>
      _AttachmentPreviewPillState();
}

class _AttachmentPreviewPillState
    extends ConsumerState<_AttachmentPreviewPill> {
  _ChatAttachmentPreview get attachment => widget.attachment;

  @override
  Widget build(BuildContext context) {
    final directUrl = attachment.directUrl;
    final localPath = attachment.localPath;
    final localFile = localPath == null ? null : File(localPath);
    final hasLocalFile = localFile != null && localFile.existsSync();
    final signedUrl = attachment.isVoice || attachment.signedUrlPath == null
        ? null
        : ref.watch(signedMediaUrlProvider(attachment.signedUrlPath!));
    final fullscreenSignedUrlPath =
        attachment.fullscreenSignedUrlPath ?? attachment.signedUrlPath;
    final fullscreenSignedUrl =
        attachment.isVoice || fullscreenSignedUrlPath == null
            ? null
            : ref.watch(signedMediaUrlProvider(fullscreenSignedUrlPath));
    final resolvedUrl = signedUrl?.maybeWhen(
          data: (url) => url,
          orElse: () => null,
        ) ??
        directUrl;
    final fullscreenUrl = fullscreenSignedUrl?.maybeWhen(
          data: (url) => url,
          orElse: () => null,
        ) ??
        attachment.fullscreenDirectUrl ??
        resolvedUrl;
    final voicePlayback = attachment.isVoice
        ? ref.watch(
            chatVoicePlaybackControllerProvider(widget.chatId).select(
              (state) => _VoicePlaybackViewState.fromController(
                state,
                playbackId: attachment.playbackId,
              ),
            ),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachment.isImage)
          GestureDetector(
            onTap: hasLocalFile || fullscreenUrl != null
                ? () => _openImage(
                      localPath: hasLocalFile ? localFile.path : null,
                      imageUrl: fullscreenUrl,
                      signedUrlPath: fullscreenSignedUrlPath,
                    )
                : null,
            child: Container(
              width: 220,
              height: 148,
              margin: const EdgeInsets.only(bottom: 6),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: DateasyColors.background.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: hasLocalFile
                  ? Image.file(localFile, fit: BoxFit.cover)
                  : resolvedUrl == null
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : DateasyRemoteImage(
                          imageUrl: resolvedUrl,
                          usage: DateasyImageUsage.card,
                        ),
            ),
          ),
        if (attachment.isVoice)
          _VoiceAttachmentPill(
            attachment: attachment,
            loading: voicePlayback?.loading ?? false,
            playing: voicePlayback?.playing ?? false,
            urlReady: hasLocalFile ||
                directUrl != null ||
                attachment.signedUrlPath != null,
            onTap: _toggleVoice,
          )
        else if (chatAttachmentShouldRenderFilePill(
          isImage: attachment.isImage,
          isVoice: attachment.isVoice,
        ))
          _FileAttachmentPill(attachment: attachment),
      ],
    );
  }

  void _openImage({
    required String? localPath,
    required String? imageUrl,
    required String? signedUrlPath,
  }) {
    showDateasyMediaViewer(
      context,
      items: [
        DateasyMediaItem(
          localPath: localPath,
          imageUrl: imageUrl,
          cacheKey: signedUrlPath == null
              ? null
              : DateasyRemoteImage.privateCacheKeyFor(
                  signedUrlPath,
                  DateasyImageUsage.fullscreen,
                ),
          cacheManager: signedUrlPath == null
              ? null
              : dateasyPrivateAttachmentCacheManager,
        ),
      ],
    );
  }

  Future<void> _toggleVoice() async {
    if (!attachment.isVoice) {
      return;
    }
    final signedPath = attachment.signedUrlPath;
    if (signedPath != null) {
      unawaited(ref.read(appAttachmentServiceProvider).warmCache([signedPath]));
    }
    await ref
        .read(chatVoicePlaybackControllerProvider(widget.chatId).notifier)
        .toggle(
          ChatVoicePlaybackRequest(
            playbackId: attachment.playbackId,
            localPath: attachment.localPath,
            url: attachment.directUrl,
            durationMs: attachment.durationMs ?? 0,
            resolveRemoteFilePath: null,
            resolveRemoteUrl: attachment.signedUrlPath == null
                ? null
                : () => ref
                    .read(appAttachmentServiceProvider)
                    .resolveSignedUrl(attachment.signedUrlPath!),
          ),
        );
  }
}

bool chatAttachmentShouldRenderFilePill({
  required bool isImage,
  required bool isVoice,
}) {
  return !isImage && !isVoice;
}

class _FileAttachmentPill extends StatelessWidget {
  const _FileAttachmentPill({required this.attachment});

  final _ChatAttachmentPreview attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: DateasyColors.background.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            attachment.icon,
            size: 14,
            color: DateasyColors.lime,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatLocationCard extends StatelessWidget {
  const _ChatLocationCard({required this.location});

  final _ChatLocationPreview location;

  @override
  Widget build(BuildContext context) {
    final active = chatLocationIsActive(
      expiresAt: location.expiresAt,
      now: DateTime.now(),
    );
    return GestureDetector(
      onTap: active ? () => _showLocationOpenSheet(context, location) : null,
      child: Opacity(
        opacity: active ? 1 : 0.58,
        child: Container(
          width: 220,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DateasyColors.background.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? DateasyColors.lime.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: active ? dateasyLimeGradient : null,
                  color: active ? null : DateasyColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LucideIcons.mapPin,
                  size: 18,
                  color: active
                      ? DateasyColors.backgroundDeep
                      : DateasyColors.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.label ?? 'Локация',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active ? 'Активна 15 минут' : 'Локация не активна',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationOpenSheet(
    BuildContext context,
    _ChatLocationPreview location,
  ) {
    showDateasyMapChoiceSheet(
      context,
      latitude: location.latitude,
      longitude: location.longitude,
      label: location.label,
    );
  }
}

class _VoiceAttachmentPill extends StatelessWidget {
  const _VoiceAttachmentPill({
    required this.attachment,
    required this.loading,
    required this.playing,
    required this.urlReady,
    required this.onTap,
  });

  final _ChatAttachmentPreview attachment;
  final bool loading;
  final bool playing;
  final bool urlReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: urlReady ? onTap : () {},
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: DateasyColors.background.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: dateasyLimeGradient,
              ),
              child: loading || !urlReady
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      playing ? LucideIcons.pause : LucideIcons.play,
                      size: 15,
                      color: DateasyColors.backgroundDeep,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VoiceWaveform(waveform: attachment.waveform),
            ),
            const SizedBox(width: 10),
            Text(
              _durationLabel(attachment.durationMs),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePlaybackViewState {
  const _VoicePlaybackViewState({
    required this.playing,
    required this.loading,
  });

  final bool playing;
  final bool loading;

  factory _VoicePlaybackViewState.fromController(
    ChatVoicePlaybackState state, {
    required String playbackId,
  }) {
    final active = state.activePlaybackId == playbackId;
    return _VoicePlaybackViewState(
      playing: active && state.isPlaying,
      loading: active && state.isLoading,
    );
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.time,
    required this.status,
    required this.clientMessageId,
    required this.onRetry,
    required this.alignEnd,
  });

  final String time;
  final _MessageSendStatus status;
  final String? clientMessageId;
  final ValueChanged<String>? onRetry;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (status) {
      _MessageSendStatus.pending => 'Отправляется',
      _MessageSendStatus.uploading => 'Загружается',
      _MessageSendStatus.failed => 'Не отправлено · повторить',
      _MessageSendStatus.sent => null,
    };
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: status == _MessageSendStatus.failed
              ? DateasyColors.pink
              : DateasyColors.muted,
          fontSize: 10,
          fontWeight: status == _MessageSendStatus.sent
              ? FontWeight.w400
              : FontWeight.w600,
        );
    final label = statusLabel == null ? time : '$time · $statusLabel';
    final statusOnly = statusLabel ?? time;
    if (status == _MessageSendStatus.failed &&
        clientMessageId != null &&
        clientMessageId!.isNotEmpty &&
        onRetry != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onRetry!(clientMessageId!),
        child: Text(
          statusOnly,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: style,
        ),
      );
    }
    return Text(
      status == _MessageSendStatus.sent ? label : statusOnly,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: style,
    );
  }
}

enum _MessageSendStatus {
  sent,
  pending,
  uploading,
  failed,
}

_MessageSendStatus _messageSendStatus(
  BackendChatMessage message,
  List<_ChatAttachmentPreview> attachments,
) {
  final rawStatus = message.raw['status']?.toString();
  if (rawStatus == 'failed' ||
      attachments.any((attachment) => attachment.status == 'failed')) {
    return _MessageSendStatus.failed;
  }
  if (rawStatus == 'uploading' ||
      attachments.any((attachment) => attachment.status == 'uploading')) {
    return _MessageSendStatus.uploading;
  }
  if (message.pending || rawStatus == 'pending') {
    return _MessageSendStatus.pending;
  }
  return _MessageSendStatus.sent;
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.waveform});

  final List<double> waveform;

  @override
  Widget build(BuildContext context) {
    final bars = waveform.isEmpty ? _fallbackWaveform(2400) : waveform;
    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final value in bars.take(28)) ...[
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  heightFactor: value.clamp(0.12, 1),
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: DateasyColors.lime.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

class _ChatAttachmentPreview {
  const _ChatAttachmentPreview({
    required this.playbackId,
    required this.label,
    required this.icon,
    required this.isImage,
    required this.isVoice,
    required this.durationMs,
    required this.waveform,
    required this.status,
    this.localPath,
    this.directUrl,
    this.signedUrlPath,
    this.fullscreenDirectUrl,
    this.fullscreenSignedUrlPath,
  });

  final String playbackId;
  final String label;
  final IconData icon;
  final bool isImage;
  final bool isVoice;
  final int? durationMs;
  final List<double> waveform;
  final String? status;
  final String? localPath;
  final String? directUrl;
  final String? signedUrlPath;
  final String? fullscreenDirectUrl;
  final String? fullscreenSignedUrlPath;
}

class _ChatLocationPreview {
  const _ChatLocationPreview({
    required this.latitude,
    required this.longitude,
    required this.expiresAt,
    this.label,
  });

  final double latitude;
  final double longitude;
  final DateTime expiresAt;
  final String? label;

  static _ChatLocationPreview? fromRaw(Object? value) {
    final raw = _map(value);
    final latitude = _doubleOrNull(raw['latitude']);
    final longitude = _doubleOrNull(raw['longitude']);
    final expiresAt = DateTime.tryParse(raw['expiresAt']?.toString() ?? '');
    if (latitude == null || longitude == null || expiresAt == null) {
      return null;
    }
    return _ChatLocationPreview(
      latitude: latitude,
      longitude: longitude,
      expiresAt: expiresAt,
      label: _stringOrNull(raw['label']),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.attachOpen,
    required this.hasText,
    required this.sending,
    required this.recording,
    required this.recordingDuration,
    required this.recordingWaveform,
    required this.replyDraft,
    required this.hintText,
    required this.onChanged,
    required this.onAttach,
    required this.onCancelReply,
    required this.onPickPhoto,
    required this.onShareLocation,
    required this.onVoiceTap,
    required this.onVoicePressStart,
    required this.onVoicePressEnd,
    required this.onVoicePressCancel,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool attachOpen;
  final bool hasText;
  final bool sending;
  final bool recording;
  final Duration recordingDuration;
  final List<double> recordingWaveform;
  final _ReplyDraft? replyDraft;
  final String hintText;
  final VoidCallback onChanged;
  final VoidCallback onAttach;
  final VoidCallback onCancelReply;
  final VoidCallback onPickPhoto;
  final VoidCallback onShareLocation;
  final VoidCallback onVoiceTap;
  final VoidCallback onVoicePressStart;
  final VoidCallback onVoicePressEnd;
  final VoidCallback onVoicePressCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachOpen)
              _AttachmentPopup(
                disabled: sending,
                onPickPhoto: onPickPhoto,
                onShareLocation: onShareLocation,
              ),
            if (recording)
              _RecordingPanel(
                duration: recordingDuration,
                waveform: recordingWaveform,
              ),
            if (replyDraft != null)
              _ReplyComposerPreview(
                reply: replyDraft!,
                onCancel: onCancelReply,
              ),
            _GlassPanel(
              borderRadius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onAttach,
                    child: AnimatedRotation(
                      turns: attachOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: attachOpen ? dateasyLimeGradient : null,
                          color: attachOpen ? null : DateasyColors.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.plus,
                          color: attachOpen
                              ? DateasyColors.backgroundDeep
                              : DateasyColors.foreground,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (_) => onChanged(),
                      minLines: 1,
                      maxLines: 3,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hintText,
                        hintStyle:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: DateasyColors.muted,
                                ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      controller.text = '${controller.text} 🔥';
                      onChanged();
                    },
                    child: const _RoundComposerButton(icon: LucideIcons.smile),
                  ),
                  const SizedBox(width: 8),
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown:
                        sending || hasText ? null : (_) => onVoicePressStart(),
                    onPointerUp:
                        sending || hasText ? null : (_) => onVoicePressEnd(),
                    onPointerCancel:
                        sending || hasText ? null : (_) => onVoicePressCancel(),
                    child: GestureDetector(
                      onTap: sending
                          ? null
                          : hasText
                              ? onSend
                              : onVoiceTap,
                      child: Container(
                        key: const ValueKey('chat_voice_send_button'),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: recording
                              ? dateasyPinkGradient
                              : dateasyLimeGradient,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55BEFF67),
                              blurRadius: 20,
                              spreadRadius: -8,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: sending
                            ? const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Icon(
                                hasText
                                    ? LucideIcons.send
                                    : recording
                                        ? LucideIcons.square
                                        : LucideIcons.mic,
                                color: recording
                                    ? DateasyColors.foreground
                                    : DateasyColors.backgroundDeep,
                                size: 16,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposerPreview extends StatelessWidget {
  const _ReplyComposerPreview({
    required this.reply,
    required this.onCancel,
  });

  final _ReplyDraft reply;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _GlassPanel(
        borderRadius: 18,
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: DateasyColors.lime,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ответ ${reply.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(LucideIcons.x, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({
    required this.duration,
    required this.waveform,
  });

  final Duration duration;
  final List<double> waveform;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DateasyColors.surface2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DateasyColors.pink.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: DateasyColors.pink,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Идет запись',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _VoiceWaveform(waveform: waveform),
          ),
          const SizedBox(width: 10),
          Text(
            _durationLabel(duration.inMilliseconds),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPopup extends StatelessWidget {
  const _AttachmentPopup({
    required this.disabled,
    required this.onPickPhoto,
    required this.onShareLocation,
  });

  final bool disabled;
  final VoidCallback onPickPhoto;
  final VoidCallback onShareLocation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _AttachmentItem(
                icon: LucideIcons.image,
                label: 'Фото/видео',
                gradient: dateasyLimeGradient,
                onTap: disabled ? null : onPickPhoto,
              ),
            ),
            Expanded(
              child: _AttachmentItem(
                icon: LucideIcons.mapPinned,
                label: 'Локация',
                gradient: dateasyPinkGradient,
                foreground: DateasyColors.foreground,
                onTap: disabled ? null : onShareLocation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  const _AttachmentItem({
    required this.icon,
    required this.label,
    this.gradient,
    this.foreground = DateasyColors.backgroundDeep,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Gradient? gradient;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = gradient != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                color: active ? null : DateasyColors.glass,
                borderRadius: BorderRadius.circular(16),
                border: active
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(
                icon,
                size: 20,
                color: active ? foreground : DateasyColors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundComposerButton extends StatelessWidget {
  const _RoundComposerButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: DateasyColors.surface2,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20),
    );
  }
}

class _PeopleSheet extends ConsumerWidget {
  const _PeopleSheet({
    required this.chatId,
    required this.onClose,
  });

  final String chatId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(chatSummaryProvider(chatId)).valueOrNull;
    final meta = _ChatHeaderData.fromSummary(summary, fallbackId: chatId);
    return _BottomSheetFrame(
      onClose: onClose,
      title: 'Участники',
      subtitle: meta.peopleLine,
      child: Column(
        children: [
          for (final person in meta.participants)
            _ParticipantRow(
              person: person,
              onTap: () {
                final route = person.profileRoute;
                if (route == null) {
                  return;
                }
                context.push(route);
              },
            ),
        ],
      ),
    );
  }
}

class _MenuSheet extends ConsumerWidget {
  const _MenuSheet({
    required this.chatId,
    required this.onPeople,
    required this.onClose,
  });

  final String chatId;
  final VoidCallback onPeople;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BottomSheetFrame(
      onClose: onClose,
      title: 'Меню чата',
      child: Column(
        children: [
          _MenuRow(
            icon: LucideIcons.users,
            label: 'Участники',
            onTap: onPeople,
          ),
          _MenuRow(
            icon: LucideIcons.logOut,
            label: 'Покинуть чат',
            danger: true,
            onTap: () async {
              try {
                await ref.read(chatActionsProvider).deleteChat(chatId);
                if (!context.mounted) {
                  return;
                }
                context.go('/chats');
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                _showChatSnack(context, 'Не удалось покинуть чат');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({
    required this.onClose,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final VoidCallback onClose;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 460),
          decoration: const BoxDecoration(
            color: DateasyColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: DateasyColors.border)),
            boxShadow: [
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 40,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: DateasyColors.muted,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _GlassIconButton(icon: LucideIcons.x, onTap: onClose),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  children: [child],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.person, required this.onTap});

  final _Participant person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: DateasyRemoteImage(
                      imageUrl: person.imageUrl,
                      usage: DateasyImageUsage.avatar,
                    ),
                  ),
                ),
                if (person.online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: DateasyColors.lime,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: DateasyColors.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '${person.role}${person.online ? ' · онлайн' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            if (person.role == 'Хост')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: dateasyLimeGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Хост'.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.backgroundDeep,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? DateasyColors.pink : DateasyColors.foreground;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _GlassPanel(
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, size: 16, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
    this.borderAlpha = 0.1,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: borderAlpha)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Participant {
  const _Participant({
    required this.name,
    required this.userId,
    required this.imageUrl,
    required this.role,
    required this.online,
    this.isCurrentUser = false,
  });

  final String name;
  final String? userId;
  final String? imageUrl;
  final String role;
  final bool online;
  final bool isCurrentUser;

  String? get profileRoute {
    if (isCurrentUser) {
      return '/profile';
    }
    final id = userId;
    if (id == null || id.isEmpty) {
      return null;
    }
    return '/u/${Uri.encodeComponent(id)}';
  }
}

List<_Participant> _participantsFromSummary(
  BackendChatSummary summary, {
  required bool isDirect,
}) {
  final profiles = _listOfMaps(summary.raw['memberProfiles']);
  if (profiles.isNotEmpty) {
    return profiles
        .map(
          (profile) => _Participant(
            userId: _stringOrNull(profile['userId'] ?? profile['id']),
            name: _stringOrNull(profile['name']) ?? 'Участник',
            imageUrl: _stringOrNull(
              profile['avatarUrl'] ??
                  profile['imageUrl'] ??
                  profile['photoUrl'],
            ),
            role: profile['isCurrentUser'] == true ? 'Вы' : 'Участник',
            online: profile['online'] == true,
            isCurrentUser: profile['isCurrentUser'] == true,
          ),
        )
        .toList(growable: false);
  }

  final names = _listOfStrings(summary.raw['members']);
  if (names.isNotEmpty) {
    return names
        .map(
          (name) => _Participant(
            userId: null,
            name: name,
            imageUrl: null,
            role: 'Участник',
            online: false,
          ),
        )
        .toList(growable: false);
  }

  return [
    _Participant(
      userId: _stringOrNull(summary.raw['peerUserId']),
      name: summary.title.isEmpty
          ? (isDirect ? 'Собеседник' : 'Чат')
          : summary.title,
      imageUrl: summary.imageUrl,
      role: isDirect ? 'Собеседник' : 'Участник',
      online: summary.raw['online'] == true,
    ),
  ];
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList(growable: false);
}

List<String> _listOfStrings(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<_ChatAttachmentPreview> _attachmentPreviews(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map((raw) {
    final item = raw.map((key, value) => MapEntry('$key', value));
    final mimeType = item['mimeType']?.toString() ?? '';
    final fileName = item['fileName']?.toString() ?? '';
    final kind = item['kind']?.toString() ?? '';
    final isVoice = kind == 'chat_voice';
    final isImage = mimeType.startsWith('image/') ||
        kind == 'image' ||
        kind == 'chat_attachment' && _looksLikeImage(fileName);
    final variants = _map(item['variants']);
    final cardVariant = _map(variants['card']);
    final fullscreenVariant = _map(
      variants['fullscreen'] ?? variants['hero'] ?? variants['card'],
    );
    final signedUrlPath = _stringOrNull(
      cardVariant['downloadUrlPath'] ?? item['downloadUrlPath'],
    );
    final fullscreenSignedUrlPath = _stringOrNull(
      fullscreenVariant['downloadUrlPath'] ??
          cardVariant['downloadUrlPath'] ??
          item['downloadUrlPath'],
    );
    final localPath = _stringOrNull(item['localPath']);
    final directUrl = _directAttachmentUrl(
      url: cardVariant['url'] ?? item['url'],
      downloadUrl: cardVariant['downloadUrl'] ?? item['downloadUrl'],
      signedUrlPath: signedUrlPath,
    );
    final fullscreenDirectUrl = _directAttachmentUrl(
      url: fullscreenVariant['url'] ?? cardVariant['url'] ?? item['url'],
      downloadUrl: fullscreenVariant['downloadUrl'] ??
          cardVariant['downloadUrl'] ??
          item['downloadUrl'],
      signedUrlPath: fullscreenSignedUrlPath,
    );
    final id = _stringOrNull(item['id'] ?? item['assetId']);
    return _ChatAttachmentPreview(
      playbackId: id ??
          signedUrlPath ??
          directUrl ??
          (fileName.isNotEmpty ? fileName : 'attachment-${item.hashCode}'),
      label: fileName.isNotEmpty
          ? fileName
          : isVoice
              ? 'Голосовое'
              : isImage
                  ? 'Изображение'
                  : 'Вложение',
      icon: isVoice
          ? LucideIcons.audioLines
          : isImage
              ? LucideIcons.image
              : LucideIcons.fileText,
      isImage: isImage,
      isVoice: isVoice,
      durationMs: _intOrNull(item['durationMs']),
      waveform: _listOfDoubles(item['waveform']),
      status: _stringOrNull(item['status']),
      localPath: localPath,
      directUrl: directUrl,
      signedUrlPath: signedUrlPath,
      fullscreenDirectUrl: fullscreenDirectUrl,
      fullscreenSignedUrlPath: fullscreenSignedUrlPath,
    );
  }).toList(growable: false);
}

String? _directAttachmentUrl({
  required Object? url,
  required Object? downloadUrl,
  required String? signedUrlPath,
}) {
  final directDownloadUrl = _stringOrNull(downloadUrl);
  if (directDownloadUrl != null) {
    return directDownloadUrl;
  }
  if (signedUrlPath != null) {
    return null;
  }
  return _stringOrNull(url);
}

List<double> _listOfDoubles(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => double.tryParse(item?.toString() ?? '') ?? 0)
      .where((item) => item > 0)
      .map((item) => item.clamp(0, 1).toDouble())
      .toList(growable: false);
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleOrNull(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

bool chatLocationIsActive({
  required DateTime expiresAt,
  required DateTime now,
}) {
  return now.isBefore(expiresAt);
}

bool _looksLikeImage(String fileName) {
  final lower = fileName.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif');
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const {};
}

String _guessMimeType(String fileName, String? provided) {
  if (provided != null && provided.isNotEmpty) {
    return provided;
  }
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (lower.endsWith('.zip')) {
    return 'application/zip';
  }
  if (lower.endsWith('.txt')) {
    return 'text/plain';
  }
  return 'application/octet-stream';
}

bool _isSystemMessage(BackendChatMessage message) {
  final kind = _stringOrNull(message.raw['kind']);
  return kind == 'system' ||
      message.raw['systemKind'] != null ||
      (message.senderId == null && message.senderName == 'Frendly');
}

List<double> _fallbackWaveform(int durationMs) {
  final bars = durationMs < 3000 ? 24 : 28;
  return List<double>.filled(bars, 0.18);
}

String _durationLabel(int? durationMs) {
  final totalSeconds = ((durationMs ?? 0) / 1000).ceil();
  if (totalSeconds <= 0) {
    return '0:01';
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

void _showChatSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: DateasyColors.surface2,
    ),
  );
}

enum _SheetKind { people, menu }

String _formatTime(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
