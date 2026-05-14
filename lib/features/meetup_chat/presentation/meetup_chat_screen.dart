import 'package:big_break_mobile/app/core/device/app_attachment_service.dart';
import 'package:big_break_mobile/app/core/device/app_media_picker_service.dart';
import 'package:big_break_mobile/app/core/device/app_permission_service.dart';
import 'package:big_break_mobile/app/core/device/app_voice_recorder_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_screen.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/utils/event_time_labels.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_chat_attachment_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_composer.dart';
import 'package:big_break_mobile/shared/widgets/bb_message_actions_sheet.dart';
import 'package:big_break_mobile/shared/widgets/bb_pinned_meetup_card.dart';
import 'package:big_break_mobile/shared/widgets/bb_system_overlays.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' show Point;

class MeetupChatScreen extends ConsumerStatefulWidget {
  const MeetupChatScreen({
    required this.chatId,
    super.key,
  });

  final String chatId;

  @override
  ConsumerState<MeetupChatScreen> createState() => _MeetupChatScreenState();
}

class _MeetupChatScreenState extends ConsumerState<MeetupChatScreen> {
  MessageReplyPreview? _replyTo;
  Message? _editingMessage;
  final Set<String> _processingEveningRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    final chatController = ref.read(chatThreadProvider(widget.chatId).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      chatController.markRead();
    });
  }

  Future<void> _openAttachment(MessageAttachment attachment) async {
    if (attachment.mimeType.startsWith('image/')) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Builder(
                    builder: (context) {
                      final size = MediaQuery.sizeOf(context);
                      return BbChatAttachmentImage(
                        attachment: attachment,
                        width: size.width,
                        height: size.height,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.zero,
                        placeholderColor: Colors.black,
                        foregroundColor: Colors.white,
                        resolveLocalPath: _resolveAttachmentPath,
                        resolveRemoteUrl: _resolveAttachmentUrl,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 16,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (attachment.isLocation &&
        attachment.latitude != null &&
        attachment.longitude != null) {
      if (attachment.isExpired) {
        _showSnackBar('Трансляция окончена');
        return;
      }
      if (!mounted) {
        return;
      }
      await context.pushRoute(
        AppRoute.chatLocation,
        queryParameters: {
          'latitude': attachment.latitude!.toString(),
          'longitude': attachment.longitude!.toString(),
          'title': attachment.title ?? attachment.fileName,
          'subtitle': attachment.subtitle ?? '',
        },
      );
      return;
    }

    final attachmentService = ref.read(appAttachmentServiceProvider);
    try {
      await attachmentService.saveAttachmentToDevice(attachment);
      _showSnackBar('Файл сохранён на устройство');
    } catch (_) {
      _showSnackBar('Не получилось сохранить файл');
    }
  }

  Future<void> _openMemberDirectChat(MeetupMember member) async {
    final userId = member.userId;
    if (userId == null || member.isCurrentUser) {
      return;
    }

    try {
      final repository = ref.read(backendRepositoryProvider);
      final chatId = await repository.createOrGetDirectChat(userId);
      if (!mounted) {
        return;
      }
      context.pushRoute(
        AppRoute.personalChat,
        pathParameters: {'chatId': chatId},
      );
    } catch (_) {
      _showSnackBar('Не получилось открыть чат');
    }
  }

  Future<void> _downloadAttachment(MessageAttachment attachment) async {
    final attachmentService = ref.read(appAttachmentServiceProvider);
    try {
      await attachmentService.saveAttachmentToDevice(attachment);
      _showSnackBar('Файл сохранён на устройство');
    } catch (_) {
      _showSnackBar('Не получилось сохранить файл');
    }
  }

  Future<String?> _resolveVoicePath(MessageAttachment attachment) async {
    return _resolveAttachmentPath(attachment);
  }

  Future<String?> _resolveAttachmentPath(MessageAttachment attachment) async {
    final attachmentService = ref.read(appAttachmentServiceProvider);
    final file = await attachmentService.getLocalFileIfAvailable(attachment);
    if (file == null) {
      return null;
    }
    return file.path;
  }

  Future<String?> _resolveVoiceUrl(MessageAttachment attachment) {
    return _resolveAttachmentUrl(attachment);
  }

  Future<String?> _resolveAttachmentUrl(MessageAttachment attachment) {
    return ref.read(appAttachmentServiceProvider).getDownloadUrl(attachment);
  }

  Future<void> _handleAttachmentAction(
      BbComposerAttachmentAction action) async {
    switch (action) {
      case BbComposerAttachmentAction.camera:
        await _takePhoto();
        return;
      case BbComposerAttachmentAction.photo:
        await _pickPhoto();
        return;
      case BbComposerAttachmentAction.file:
        await _pickFile();
        return;
      case BbComposerAttachmentAction.location:
        await _shareCurrentLocation();
        return;
    }
  }

  Future<void> _takePhoto() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final mediaPicker = ref.read(appMediaPickerServiceProvider);
    final chatController = ref.read(chatThreadProvider(widget.chatId).notifier);
    final replyTo = _replyTo;
    final permitted = await permissionService.requestCamera();
    if (!mounted) {
      return;
    }
    if (!permitted) {
      _showSnackBar('Нет доступа к камере');
      return;
    }

    final file = await mediaPicker.pickFromCamera();
    if (!mounted || file == null) {
      return;
    }

    try {
      await chatController.sendAttachment(
        file,
        replyTo: replyTo,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar('Не получилось отправить файл');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    _clearReplyIfUnchanged(replyTo);
  }

  Future<void> _pickPhoto() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final mediaPicker = ref.read(appMediaPickerServiceProvider);
    final chatController = ref.read(chatThreadProvider(widget.chatId).notifier);
    final replyTo = _replyTo;
    final permitted = await permissionService.requestPhotos();
    if (!mounted) {
      return;
    }
    if (!permitted) {
      _showSnackBar('Нет доступа к фото');
      return;
    }

    final file = await mediaPicker.pickFromGallery();
    if (!mounted || file == null) {
      return;
    }

    await chatController.sendAttachment(
      file,
      replyTo: replyTo,
    );
    if (!mounted) {
      return;
    }
    _clearReplyIfUnchanged(replyTo);
  }

  Future<void> _pickFile() async {
    final chatController = ref.read(chatThreadProvider(widget.chatId).notifier);
    final replyTo = _replyTo;
    final result = await FilePicker.platform.pickFiles(withData: false);
    final file = result?.files.firstOrNull;
    if (!mounted || file == null) {
      return;
    }

    await chatController.sendAttachment(
      file,
      replyTo: replyTo,
    );
    if (!mounted) {
      return;
    }
    _clearReplyIfUnchanged(replyTo);
  }

  Future<void> _shareCurrentLocation() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final mapService = ref.read(yandexMapServiceProvider);
    final chatController = ref.read(chatThreadProvider(widget.chatId).notifier);
    final replyTo = _replyTo;
    final permissionGranted = await permissionService.requestLocation();
    if (!mounted) {
      return;
    }
    if (!permissionGranted) {
      _showSnackBar('Нет доступа к геопозиции');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }
      final point = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final resolved = await mapService.reverseGeocode(point);
      if (!mounted) {
        return;
      }
      final subtitle = resolved?.address ??
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      await chatController.sendCurrentLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        title: 'Ты здесь',
        subtitle: subtitle,
        replyTo: replyTo,
      );
      if (!mounted) {
        return;
      }
      _clearReplyIfUnchanged(replyTo);
    } catch (_) {
      _showSnackBar('Не получилось определить локацию');
    }
  }

  void _clearReplyIfUnchanged(MessageReplyPreview? expectedReply) {
    if (!mounted) {
      return;
    }
    if (expectedReply == null) {
      if (_replyTo != null) {
        return;
      }
    } else if (_replyTo?.id != expectedReply.id) {
      return;
    }
    setState(() {
      _replyTo = null;
    });
  }

  void _clearReply() {
    if (!mounted) {
      return;
    }
    setState(() {
      _replyTo = null;
    });
  }

  void _clearEditing() {
    if (!mounted) {
      return;
    }
    setState(() {
      _editingMessage = null;
    });
  }

  Future<void> _handleSendText(String text) async {
    final editingMessage = _editingMessage;
    final controller = ref.read(chatThreadProvider(widget.chatId).notifier);
    if (editingMessage != null) {
      await controller.editMessage(editingMessage, text);
      _clearEditing();
      return;
    }

    await controller.sendMessage(
      text,
      replyTo: _replyTo,
    );
    _clearReply();
  }

  MessageReplyPreview _toReplyPreview(Message message) {
    final hasVoice =
        message.attachments.any((attachment) => attachment.isVoice);
    final hasLocation =
        message.attachments.any((attachment) => attachment.isLocation);
    final previewText = hasVoice
        ? 'Голосовое сообщение'
        : hasLocation
            ? 'Локация'
            : message.text.trim().isNotEmpty
                ? message.text
                : message.attachments.isNotEmpty
                    ? 'Вложение'
                    : 'Сообщение';

    return MessageReplyPreview(
      id: message.id,
      authorId: message.authorId,
      author: message.author,
      text: previewText,
      isVoice: hasVoice,
      mine: message.mine,
    );
  }

  Future<void> _handleMessageLongPress(Message message) async {
    final action = await showBbMessageActionsSheet(
      context,
      message: message,
    );
    if (action == null || !mounted || !context.mounted) {
      return;
    }

    switch (action) {
      case BbMessageActionType.reply:
        setState(() {
          _replyTo = _toReplyPreview(message);
          _editingMessage = null;
        });
        return;
      case BbMessageActionType.copy:
        await Clipboard.setData(ClipboardData(text: message.text));
        if (!mounted || !context.mounted) {
          return;
        }
        _showSnackBar('Скопировано');
        return;
      case BbMessageActionType.edit:
        setState(() {
          _replyTo = null;
          _editingMessage = message;
        });
        return;
      case BbMessageActionType.delete:
        final chatController =
            ref.read(chatThreadProvider(widget.chatId).notifier);
        await chatController.deleteMessage(message);
        if (!mounted) {
          return;
        }
        if (_editingMessage?.id == message.id) {
          _clearEditing();
        }
        return;
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final granted = await permissionService.requestMicrophone();
    if (!mounted) {
      return false;
    }
    if (!granted) {
      _showSnackBar('Нет доступа к микрофону');
    }
    return granted;
  }

  void _showSnackBar(String message) {
    if (!mounted || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _statusLine(MeetupChat? chat) {
    if (chat == null) {
      return '';
    }

    switch (chat.phase) {
      case MeetupPhase.live:
        final step = chat.currentStep == null || chat.totalSteps == null
            ? 'LIVE'
            : 'LIVE · Шаг ${chat.currentStep}/${chat.totalSteps}';
        final place = chat.currentPlace;
        return place == null || place.isEmpty ? step : '$step · $place';
      case MeetupPhase.soon:
        return 'Скоро · ${chat.startsInLabel ?? chat.time}';
      case MeetupPhase.done:
        return 'Завершено';
      case MeetupPhase.upcoming:
        final total = chat.memberProfiles.isNotEmpty
            ? chat.memberProfiles.length
            : chat.members.length;
        final online =
            chat.memberProfiles.where((member) => member.online).length;
        if (total > 0) {
          return online > 0
              ? '$total участников · $online онлайн'
              : '$total участников';
        }
        final status = chat.status ?? '';
        return '${chat.members.length} участников · $status ${chat.time}'
            .trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final chat = ref.watch(meetupChatSummaryProvider(widget.chatId));
    final themeColors =
        baseTheme.extension<BigBreakThemeColors>() ?? AppColors.lightTheme;
    final messagesAsync = ref.watch(chatThreadProvider(widget.chatId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final isEveningHost = chat != null &&
        chat.sessionId != null &&
        chat.hostUserId != null &&
        chat.hostUserId == currentUserId;
    final eveningSessionAsync = isEveningHost
        ? ref.watch(eveningSessionProvider(chat.sessionId!))
        : null;
    final eventAsync = chat?.eventId == null
        ? null
        : ref.watch(eventDetailProvider(chat!.eventId!));

    return Theme(
      data: baseTheme.copyWith(extensions: [themeColors]),
      child: Builder(
        builder: (context) {
          final eveningPin = chat != null &&
                  chat.phase == MeetupPhase.live &&
                  chat.routeId != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _EveningPinnedStepCard(
                    chat: chat,
                    onTap: () => context.pushRoute(
                      AppRoute.eveningLive,
                      pathParameters: {'routeId': chat.routeId!},
                      queryParameters: {
                        'mode': eveningLaunchModeToJson(chat.mode),
                        if (chat.sessionId != null)
                          'sessionId': chat.sessionId!,
                      },
                    ),
                  ),
                )
              : null;
          final eveningStartBanner = chat != null &&
                  chat.routeId != null &&
                  chat.hostUserId == currentUserId &&
                  (chat.phase == MeetupPhase.soon ||
                      chat.phase == MeetupPhase.upcoming)
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _EveningStartLiveBanner(
                    onTap: () => _startEveningLive(chat),
                  ),
                )
              : null;
          final eventPin = chat != null && eventAsync != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: eventAsync.when(
                    data: (event) => BbPinnedMeetupCard(
                      chat: chat,
                      place: event.place,
                      distance: event.distance,
                      capacity: event.capacity,
                      going: event.going,
                      onEdit: event.isHost
                          ? () => _showV5EditMeetupSheet(event)
                          : null,
                      onRouteTap: chat.routeId == null
                          ? null
                          : () => context.pushRoute(
                                AppRoute.eveningPlan,
                                pathParameters: {'routeId': chat.routeId!},
                              ),
                      onTicketTap: _ticketAction(chat),
                      onTap: () => context.pushRoute(
                        AppRoute.eventDetail,
                        pathParameters: {'eventId': event.id},
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                )
              : null;
          final compactEventPin = chat != null && eventAsync != null
              ? eventAsync.when(
                  data: (event) => _V5MeetupCompactCapsule(
                    event: event,
                    onTap: () => context.pushRoute(
                      AppRoute.eventDetail,
                      pathParameters: {'eventId': event.id},
                    ),
                    onEdit: event.isHost
                        ? () => _showV5EditMeetupSheet(event)
                        : () => context.pushRoute(
                              AppRoute.eventDetail,
                              pathParameters: {'eventId': event.id},
                            ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                )
              : null;
          final eveningRequestsPanel = chat != null &&
                  eveningSessionAsync != null
              ? eveningSessionAsync.when(
                  data: (session) => session.pendingRequests.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: _EveningJoinRequestsPanel(
                            requests: session.pendingRequests,
                            busyIds: _processingEveningRequestIds,
                            onApprove: (request) => _handleEveningJoinRequest(
                              chat,
                              request,
                              approve: true,
                            ),
                            onReject: (request) => _handleEveningJoinRequest(
                              chat,
                              request,
                              approve: false,
                            ),
                          ),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                )
              : null;
          final eveningInvitePanel = chat != null && eveningSessionAsync != null
              ? eveningSessionAsync.when(
                  data: (session) {
                    final inviteLink = _eveningInviteLink(session);
                    if (session.privacy != EveningPrivacy.invite ||
                        inviteLink == null) {
                      return null;
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _EveningInviteLinkPanel(
                        inviteLink: inviteLink,
                        onCopy: () => _copyEveningInviteLink(session),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                )
              : null;
          final topItems = [
            if (eveningPin != null) eveningPin,
            if (eveningPin == null && eventPin != null) eventPin,
            if (eveningStartBanner != null) eveningStartBanner,
            if (eveningInvitePanel != null) eveningInvitePanel,
            if (eveningRequestsPanel != null) eveningRequestsPanel,
          ];
          return ChatThreadScreen(
            header: _V5MeetupChatHeader(
              chat: chat,
              subtitle: _statusLine(chat),
              onBack: () => context.pop(),
              onMembersTap: chat == null ? null : () => _showMembersSheet(chat),
              onEditRoute: chat != null &&
                      chat.routeId != null &&
                      chat.phase != MeetupPhase.done &&
                      isEveningHost
                  ? () => context.pushRoute(
                        AppRoute.eveningEdit,
                        pathParameters: {'routeId': chat.routeId!},
                        queryParameters: {'chatId': chat.id},
                      )
                  : null,
            ),
            topContent: topItems.isEmpty
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: topItems,
                  ),
            compactTopContent: compactEventPin,
            scrollTopContent: true,
            headerCoversTopSafeArea: true,
            messagesAsync: messagesAsync,
            onLoadOlderMessages: () => ref
                .read(chatThreadProvider(widget.chatId).notifier)
                .loadOlderMessages(),
            onMessageReply: (message) {
              setState(() {
                _replyTo = _toReplyPreview(message);
                _editingMessage = null;
              });
            },
            onMessageLongPress: _handleMessageLongPress,
            onAttachmentTap: _openAttachment,
            onAttachmentDownloadTap: _downloadAttachment,
            onImageResolvePath: _resolveAttachmentPath,
            onImageResolveRemoteUrl: _resolveAttachmentUrl,
            onVoiceResolvePath: _resolveVoicePath,
            onVoiceResolveRemoteUrl: _resolveVoiceUrl,
            onAuthorAvatarTap: (userId) {
              context.pushRoute(
                AppRoute.userProfile,
                pathParameters: {'userId': userId},
              );
            },
            trailingStatus: (chat?.typing ?? false)
                ? (messages) =>
                    _TypingIndicator(name: chat?.lastAuthor ?? 'Кто-то')
                : null,
            composer: BbComposer(
              hintText: 'Сообщение…',
              onSend: _handleSendText,
              onAttachmentActionSelected: _handleAttachmentAction,
              onSendVoice: (voice) {
                final replyTo = _replyTo;
                return ref
                    .read(chatThreadProvider(widget.chatId).notifier)
                    .sendVoiceMessage(
                      voice,
                      replyTo: replyTo,
                    )
                    .then((_) => _clearReplyIfUnchanged(replyTo));
              },
              onRequestMicrophonePermission: _requestMicrophonePermission,
              voiceRecorderService: ref.read(appVoiceRecorderServiceProvider),
              replyTo: _replyTo,
              onCancelReply: _clearReply,
              editingMessage: _editingMessage == null
                  ? null
                  : MessageEditDraft(
                      id: _editingMessage!.id,
                      text: _editingMessage!.text,
                    ),
              onCancelEdit: _clearEditing,
            ),
          );
        },
      ),
    );
  }

  void _showMembersSheet(MeetupChat chat) {
    showChatMembersSheet(
      context,
      title: chat.title,
      members: chat.members,
      memberProfiles: chat.memberProfiles,
      hostUserId: chat.hostUserId,
      hostName:
          chat.hostName ?? (chat.members.isEmpty ? null : chat.members.first),
      onOpenProfile: (member) {
        final userId = member.userId;
        if (userId == null || member.isCurrentUser) {
          return;
        }
        context.pushRoute(
          AppRoute.userProfile,
          pathParameters: {'userId': userId},
        );
      },
      onMessage: _openMemberDirectChat,
    );
  }

  Future<void> _showV5EditMeetupSheet(EventDetail event) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: BbV5Colors.ink.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _V5EditMeetupDialog(
          event: event,
          onClose: () => Navigator.of(context).pop(),
          onOpenFull: () {
            Navigator.of(context).pop();
            this.context.pushRoute(
              AppRoute.createMeetup,
              queryParameters: {'editEventId': event.id},
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  VoidCallback? _ticketAction(MeetupChat chat) {
    final ticketUrl = chat.ticketUrl?.trim();
    if (ticketUrl == null || ticketUrl.isEmpty) {
      return null;
    }
    return () => _openTicketUrl(ticketUrl);
  }

  Future<void> _openTicketUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar('Не получилось открыть сайт с билетами');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || !context.mounted || opened) {
      return;
    }
    _showSnackBar('Не получилось открыть сайт с билетами');
  }

  Future<void> _startEveningLive(MeetupChat chat) async {
    final sessionId = chat.sessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      final repository = ref.read(backendRepositoryProvider);
      final container = ProviderScope.containerOf(context, listen: false);
      try {
        await repository.startEveningSession(sessionId);
        if (!mounted) {
          return;
        }
        container.invalidate(eveningSessionProvider(sessionId));
        container.invalidate(eveningSessionsProvider);
        container.invalidate(meetupChatsProvider);
      } catch (_) {
        _showSnackBar('Не получилось запустить live');
        return;
      }
    }
    if (!mounted || chat.routeId == null) {
      return;
    }
    await context.pushRoute(
      AppRoute.eveningLive,
      pathParameters: {'routeId': chat.routeId!},
      queryParameters: {
        'mode': eveningLaunchModeToJson(chat.mode),
        if (chat.sessionId != null) 'sessionId': chat.sessionId!,
      },
    );
  }

  String? _eveningInviteLink(EveningSessionDetail session) {
    final token = session.inviteToken?.trim();
    if (token == null || token.isEmpty) {
      return null;
    }
    final sessionId = Uri.encodeComponent(session.id);
    final inviteToken = Uri.encodeQueryComponent(token);
    return 'bigbreak://evening-preview/$sessionId?inviteToken=$inviteToken';
  }

  Future<void> _copyEveningInviteLink(EveningSessionDetail session) async {
    final inviteLink = _eveningInviteLink(session);
    if (inviteLink == null) {
      _showSnackBar('Инвайт недоступен');
      return;
    }
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (!mounted) {
      return;
    }
    _showSnackBar('Инвайт скопирован');
  }

  Future<void> _handleEveningJoinRequest(
    MeetupChat chat,
    EveningSessionJoinRequest request, {
    required bool approve,
  }) async {
    final sessionId = chat.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    if (_processingEveningRequestIds.contains(request.id)) {
      return;
    }

    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _processingEveningRequestIds.add(request.id);
    });
    try {
      if (approve) {
        await repository.approveEveningJoinRequest(sessionId, request.id);
      } else {
        await repository.rejectEveningJoinRequest(sessionId, request.id);
      }
      if (!mounted) {
        return;
      }
      container.invalidate(eveningSessionProvider(sessionId));
      container.invalidate(eveningSessionsProvider);
      container.invalidate(meetupChatsProvider);
    } catch (_) {
      _showSnackBar(
        approve ? 'Не получилось принять заявку' : 'Не получилось отклонить',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingEveningRequestIds.remove(request.id);
        });
      }
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _V5MeetupCompactCapsule extends StatelessWidget {
  const _V5MeetupCompactCapsule({
    required this.event,
    required this.onTap,
    required this.onEdit,
  });

  final EventDetail event;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('meetup-chat-compact-capsule'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.nav,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BbV5Colors.accent,
                  shape: BoxShape.circle,
                  boxShadow: BbV5Shadows.pill,
                ),
                child: Text(
                  event.emoji,
                  style: const TextStyle(fontSize: 16, height: 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: 0,
                        color: BbV5Colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.time} · ${event.going}/${event.capacity} идут',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: BbV5Colors.inkMute,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BbV5PillButton(
                label: 'Изм.',
                height: 32,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5MeetupChatHeader extends StatelessWidget {
  const _V5MeetupChatHeader({
    required this.chat,
    required this.subtitle,
    required this.onBack,
    required this.onMembersTap,
    required this.onEditRoute,
  });

  final MeetupChat? chat;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onMembersTap;
  final VoidCallback? onEditRoute;

  @override
  Widget build(BuildContext context) {
    final title =
        chat?.title.trim().isNotEmpty == true ? chat!.title : 'Чат встречи';
    final initials = _chatInitials(title);
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BbV5Colors.paperHi.withValues(alpha: 0.94),
            BbV5Colors.paper.withValues(alpha: 0.8),
            BbV5Colors.paper.withValues(alpha: 0),
          ],
        ),
      ),
      child: Row(
        children: [
          BbV5IconButton(
            icon: LucideIcons.arrow_left,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
          GestureDetector(
            key: const Key('meetup-chat-members-button'),
            onTap: onMembersTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BbV5Colors.paperHi,
                    shape: BoxShape.circle,
                    border: Border.all(color: BbV5Colors.hair),
                    boxShadow: BbV5Shadows.pill,
                  ),
                  child: Text(
                    initials,
                    style: AppTextStyles.body.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      letterSpacing: 0.52,
                      fontWeight: FontWeight.w600,
                      color: BbV5Colors.ink,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: BbV5Colors.terra,
                      shape: BoxShape.circle,
                      border: Border.all(color: BbV5Colors.paperHi, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5DisplayStyle(fontSize: 14, height: 1.25),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const _V5OnlineDot(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          letterSpacing: 0,
                          color: BbV5Colors.inkMute,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (onEditRoute != null)
            BbV5IconButton(
              icon: LucideIcons.pencil,
              size: 44,
              iconSize: 16,
              onPressed: onEditRoute,
            )
          else
            BbV5IconButton(
              icon: LucideIcons.ellipsis,
              size: 44,
              iconSize: 18,
              onPressed: onMembersTap,
            ),
        ],
      ),
    );
  }
}

class _V5OnlineDot extends StatelessWidget {
  const _V5OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: BbV5Colors.brand,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _V5EditMeetupDialog extends StatefulWidget {
  const _V5EditMeetupDialog({
    required this.event,
    required this.onClose,
    required this.onOpenFull,
  });

  final EventDetail event;
  final VoidCallback onClose;
  final VoidCallback onOpenFull;

  @override
  State<_V5EditMeetupDialog> createState() => _V5EditMeetupDialogState();
}

class _V5EditMeetupDialogState extends State<_V5EditMeetupDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _placeController;
  late final TextEditingController _dateController;
  late final TextEditingController _capacityController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _placeController = TextEditingController(text: widget.event.place);
    final eventTime = widget.event.time.trim();
    final dayLabel = eventDayLabel(
      time: eventTime,
      startsAtIso: widget.event.startsAtIso,
    );
    _dateController = TextEditingController(
      text: eventDateTimeLabel(
        time: eventTime,
        status: dayLabel,
      ),
    );
    _capacityController = TextEditingController(
      text: widget.event.capacity <= 0 ? '8' : '${widget.event.capacity}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _dateController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final title = _titleController.text.trim();
    widget.onClose();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          title.isEmpty ? 'Встреча обновлена' : 'Встреча обновлена · $title',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: BbV5Card(
                padding: const EdgeInsets.all(20),
                radius: BbV5Radii.lg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: BbV5Kicker('Редактировать встречу'),
                        ),
                        TextButton.icon(
                          onPressed: widget.onOpenFull,
                          icon: const Icon(LucideIcons.external_link, size: 14),
                          label: const Text('В новом окне'),
                          style: TextButton.styleFrom(
                            foregroundColor: BbV5Colors.accent,
                            textStyle: AppTextStyles.caption.copyWith(
                              fontFamily: 'Sora',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _titleController.text.trim().isEmpty
                          ? widget.event.title
                          : _titleController.text.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: bbV5DisplayStyle(fontSize: 20, height: 1.1),
                    ),
                    const SizedBox(height: 16),
                    _V5EditTextField(
                      label: 'Название',
                      controller: _titleController,
                    ),
                    const SizedBox(height: 12),
                    _V5EditTextField(
                      label: 'Место',
                      controller: _placeController,
                    ),
                    const SizedBox(height: 12),
                    _V5EditTextField(
                      label: 'Дата и время',
                      controller: _dateController,
                    ),
                    const SizedBox(height: 12),
                    _V5EditTextField(
                      label: 'Мест',
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: BbV5PillButton(
                            label: 'Отмена',
                            onPressed: widget.onClose,
                            height: 48,
                            fontSize: 13,
                            expanded: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BbV5PillButton(
                            label: 'Сохранить',
                            dark: true,
                            onPressed: _saveAndClose,
                            height: 48,
                            fontSize: 13,
                            expanded: true,
                          ),
                        ),
                      ],
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

class _V5EditTextField extends StatelessWidget {
  const _V5EditTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontFamily: 'Sora',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 1.68,
            color: BbV5Colors.inkMute,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: BbV5Colors.paper,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BbV5Radii.pill),
                borderSide: const BorderSide(color: BbV5Colors.hair),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BbV5Radii.pill),
                borderSide: const BorderSide(color: BbV5Colors.accent),
              ),
            ),
            style: AppTextStyles.body.copyWith(
              color: BbV5Colors.ink,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}

String _chatInitials(String title) {
  final words = title
      .replaceAll('·', ' ')
      .split(RegExp(r'\s+'))
      .where((item) => item.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (words.isEmpty) {
    return 'BB';
  }
  return words.map((item) => item.substring(0, 1)).join().toUpperCase();
}

class _EveningStartLiveBanner extends StatelessWidget {
  const _EveningStartLiveBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.foreground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.background.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.play,
                  color: colors.background,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Все на месте? Запусти live',
                      style: AppTextStyles.itemTitle.copyWith(
                        color: colors.background,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Активирует таймлайн, чек-ины и перки для группы',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.background.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                LucideIcons.sparkles,
                size: 16,
                color: colors.background.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EveningInviteLinkPanel extends StatelessWidget {
  const _EveningInviteLinkPanel({
    required this.inviteLink,
    required this.onCopy,
  });

  final String inviteLink;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      key: const ValueKey('meetup-chat-evening-invite'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.link,
              color: colors.foreground,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Инвайт-ссылка',
                  style: AppTextStyles.itemTitle.copyWith(
                    color: colors.foreground,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  inviteLink,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('Скопировать'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EveningJoinRequestsPanel extends StatelessWidget {
  const _EveningJoinRequestsPanel({
    required this.requests,
    required this.busyIds,
    required this.onApprove,
    required this.onReject,
  });

  final List<EveningSessionJoinRequest> requests;
  final Set<String> busyIds;
  final ValueChanged<EveningSessionJoinRequest> onApprove;
  final ValueChanged<EveningSessionJoinRequest> onReject;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final visibleRequests = requests.take(3).toList(growable: false);
    return Container(
      key: const ValueKey('meetup-chat-evening-requests'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.warmStart,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.user_check,
                  size: 16,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Заявки на вечер',
                  style: AppTextStyles.itemTitle.copyWith(
                    color: colors.foreground,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${requests.length}',
                style: AppTextStyles.caption.copyWith(
                  color: colors.inkMute,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final request in visibleRequests) ...[
            _EveningJoinRequestTile(
              request: request,
              busy: busyIds.contains(request.id),
              onApprove: () => onApprove(request),
              onReject: () => onReject(request),
            ),
            if (request != visibleRequests.last)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _EveningJoinRequestTile extends StatelessWidget {
  const _EveningJoinRequestTile({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final EveningSessionJoinRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BbAvatar(name: request.name, size: BbAvatarSize.sm),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  request.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
          if ((request.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: colors.inkSoft),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: Text(busy ? '...' : 'Отклонить'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  child: Text(busy ? '...' : 'Принять'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EveningPinnedStepCard extends StatelessWidget {
  const _EveningPinnedStepCard({
    required this.chat,
    required this.onTap,
  });

  final MeetupChat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final step = chat.currentStep == null || chat.totalSteps == null
        ? 'Live'
        : 'Шаг ${chat.currentStep}/${chat.totalSteps}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('meetup-chat-evening-pin'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.map_pin,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          step,
                          style: AppTextStyles.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.currentPlace ?? chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    Text(
                      'Открыть таймлайн',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevron_right,
                color: colors.inkSoft,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: '$name печатает',
      child: Row(
        key: const Key('meetup-chat-typing-indicator'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          BbAvatar(
            name: name,
            size: BbAvatarSize.sm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.bubbleThem,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _TypingDots(color: colors.inkMute),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({
    required this.color,
  });

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _opacities;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacities = [0, 120, 240].map(_buildOpacity).toList(growable: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypingDot(opacity: _opacities[0], color: widget.color),
        const SizedBox(width: 4),
        _TypingDot(opacity: _opacities[1], color: widget.color),
        const SizedBox(width: 4),
        _TypingDot(opacity: _opacities[2], color: widget.color),
      ],
    );
  }

  Animation<double> _buildOpacity(int delay) {
    final start = (delay / 900).clamp(0, 1).toDouble();
    return Tween<double>(begin: 0.35, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start,
          1,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({
    required this.opacity,
    required this.color,
  });

  final Animation<double> opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
