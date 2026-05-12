import 'package:big_break_mobile/app/core/device/app_attachment_service.dart';
import 'package:big_break_mobile/app/core/device/app_media_picker_service.dart';
import 'package:big_break_mobile/app/core/device/app_permission_service.dart';
import 'package:big_break_mobile/app/core/device/app_voice_recorder_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_screen.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_chat_attachment_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_composer.dart';
import 'package:big_break_mobile/shared/widgets/bb_message_actions_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' show Point;

class PersonalChatScreen extends ConsumerStatefulWidget {
  const PersonalChatScreen({
    required this.chatId,
    super.key,
  });

  final String chatId;

  @override
  ConsumerState<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

class _PersonalChatScreenState extends ConsumerState<PersonalChatScreen> {
  MessageReplyPreview? _replyTo;
  Message? _editingMessage;

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
      _showSnackBar('Сохраняем файл...');
      await attachmentService.saveAttachmentToDevice(attachment);
      _showSnackBar('Файл сохранён на устройство');
    } catch (_) {
      _showSnackBar('Не получилось сохранить файл');
    }
  }

  Future<void> _downloadAttachment(MessageAttachment attachment) async {
    final attachmentService = ref.read(appAttachmentServiceProvider);
    try {
      _showSnackBar('Сохраняем файл...');
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chat = ref.watch(personalChatSummaryProvider(widget.chatId));
    final messagesAsync = ref.watch(chatThreadProvider(widget.chatId));
    final subscription = ref.watch(subscriptionStateProvider).valueOrNull;
    final hasPremiumDating =
        subscription?.status == 'trial' || subscription?.status == 'active';
    final showDateInviteCta = hasPremiumDating &&
        (chat?.peerUserId?.isNotEmpty ?? false) &&
        chat?.fromMeetup == null;

    return ChatThreadScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.border.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(LucideIcons.chevron_left),
                ),
                BbAvatar(
                  name: chat?.name ?? 'Личный чат',
                  size: BbAvatarSize.md,
                  online: chat?.online ?? false,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat?.name ?? 'Личный чат',
                        style: AppTextStyles.itemTitle.copyWith(
                          fontSize: 14,
                          height: 1.25,
                          letterSpacing: -0.28,
                        ),
                      ),
                      Text(
                        (chat?.online ?? false) ? 'в сети' : 'был недавно',
                        style: AppTextStyles.meta.copyWith(
                          color: colors.online,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      topContent: showDateInviteCta
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: InkWell(
                onTap: () => context.pushRoute(
                  AppRoute.createMeetup,
                  queryParameters: {
                    'mode': 'dating',
                    'inviteeUserId': chat!.peerUserId!,
                    'sourceChatId': chat.id,
                  },
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.heart,
                          size: 18,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Позвать на свидание',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Откроется отдельный date flow с приватными настройками.',
                              style: AppTextStyles.meta.copyWith(
                                color: colors.inkMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevron_right,
                        size: 18,
                        color: colors.inkMute,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
      messagesAsync: messagesAsync,
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
      trailingStatus: (_) => const SizedBox.shrink(),
      composer: BbComposer(
        hintText: 'Напиши или пригласи на встречу',
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
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
