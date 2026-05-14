import 'package:big_break_mobile/app/core/device/app_attachment_service.dart';
import 'package:big_break_mobile/app/core/device/app_media_picker_service.dart';
import 'package:big_break_mobile/app/core/device/app_permission_service.dart';
import 'package:big_break_mobile/app/core/device/app_voice_recorder_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_providers.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_screen.dart';
import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/features/communities/presentation/community_widgets.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/widgets/bb_chat_attachment_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_composer.dart';
import 'package:big_break_mobile/shared/widgets/bb_message_actions_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' show Point;

class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    required this.communityId,
    super.key,
  });

  final String communityId;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  MessageReplyPreview? _replyTo;
  Message? _editingMessage;
  String? _markedReadChatId;

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
    BbComposerAttachmentAction action,
    String chatId,
  ) async {
    switch (action) {
      case BbComposerAttachmentAction.camera:
        await _takePhoto(chatId);
        return;
      case BbComposerAttachmentAction.photo:
        await _pickPhoto(chatId);
        return;
      case BbComposerAttachmentAction.file:
        await _pickFile(chatId);
        return;
      case BbComposerAttachmentAction.location:
        await _shareCurrentLocation(chatId);
        return;
    }
  }

  Future<void> _takePhoto(String chatId) async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final mediaPicker = ref.read(appMediaPickerServiceProvider);
    final chatController = ref.read(chatThreadProvider(chatId).notifier);
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

    await chatController.sendAttachment(
      file,
      replyTo: replyTo,
    );
    if (!mounted) {
      return;
    }
    _clearReplyIfUnchanged(replyTo);
  }

  Future<void> _pickPhoto(String chatId) async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final mediaPicker = ref.read(appMediaPickerServiceProvider);
    final chatController = ref.read(chatThreadProvider(chatId).notifier);
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

  Future<void> _pickFile(String chatId) async {
    final chatController = ref.read(chatThreadProvider(chatId).notifier);
    final replyTo = _replyTo;
    final result = await FilePicker.platform.pickFiles(withData: false);
    final files = result?.files;
    if (!mounted || files == null || files.isEmpty) {
      return;
    }

    try {
      await chatController.sendAttachment(
        files.first,
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

  Future<void> _shareCurrentLocation(String chatId) async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final mapService = ref.read(yandexMapServiceProvider);
    final chatController = ref.read(chatThreadProvider(chatId).notifier);
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

  Future<void> _handleSendText(String chatId, String text) async {
    final editingMessage = _editingMessage;
    final controller = ref.read(chatThreadProvider(chatId).notifier);
    if (editingMessage != null) {
      await controller.editMessage(editingMessage, text);
      _clearEditing();
      return;
    }

    await controller.sendMessage(
      text,
      replyTo: _replyTo,
    );
    _refreshCommunityChatPreview();
    _clearReply();
  }

  void _refreshCommunityChatPreview() {
    ref.invalidate(communityProvider(widget.communityId));
    ref.invalidate(communitiesProvider);
    ref.invalidate(communitiesFeedProvider);
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

  Future<void> _handleMessageLongPress(String chatId, Message message) async {
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
        final chatController = ref.read(chatThreadProvider(chatId).notifier);
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

  void _markReadOnce(String chatId) {
    if (_markedReadChatId == chatId) {
      return;
    }

    _markedReadChatId = chatId;
    final chatController = ref.read(chatThreadProvider(chatId).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      chatController.markRead();
    });
  }

  void _leaveChat() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    try {
      context.goRoute(AppRoute.communities);
    } catch (_) {}
  }

  void _showSnackBar(String message) {
    if (!mounted || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final communityAsync = ref.watch(communityProvider(widget.communityId));

    return communityAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      ),
      error: (_, __) => const CommunityMissingState(),
      data: (community) {
        if (community == null) {
          return const CommunityMissingState();
        }

        final chatId = community.chatId;
        _markReadOnce(chatId);
        final messagesAsync = ref.watch(chatThreadProvider(chatId));

        return ChatThreadScreen(
          header: CommunityBackHeader(
            title: community.name,
            subtitle: 'Чат сообщества',
            onBack: _leaveChat,
          ),
          messagesAsync: messagesAsync,
          onLoadOlderMessages: () =>
              ref.read(chatThreadProvider(chatId).notifier).loadOlderMessages(),
          onMessageReply: (message) {
            setState(() {
              _replyTo = _toReplyPreview(message);
              _editingMessage = null;
            });
          },
          onMessageLongPress: (message) =>
              _handleMessageLongPress(chatId, message),
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
          composer: BbComposer(
            hintText: 'Сообщение в клуб',
            onSend: (text) => _handleSendText(chatId, text),
            onAttachmentActionSelected: (action) =>
                _handleAttachmentAction(action, chatId),
            onSendVoice: (voice) {
              final replyTo = _replyTo;
              return ref
                  .read(chatThreadProvider(chatId).notifier)
                  .sendVoiceMessage(
                    voice,
                    replyTo: replyTo,
                  )
                  .then((_) {
                _refreshCommunityChatPreview();
                _clearReplyIfUnchanged(replyTo);
              });
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
    );
  }
}
