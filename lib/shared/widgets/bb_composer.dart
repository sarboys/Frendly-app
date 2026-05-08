import 'dart:async';
import 'dart:math' as math;
import 'package:big_break_mobile/app/core/device/app_voice_recorder_service.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/models/recorded_voice_draft.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

enum BbComposerAttachmentAction {
  photo,
  file,
  location,
}

class MessageEditDraft {
  const MessageEditDraft({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;
}

class BbComposer extends StatefulWidget {
  const BbComposer({
    required this.onSend,
    super.key,
    this.hintText = 'Сообщение',
    this.enabled = true,
    this.onAttachmentActionSelected,
    this.onSendVoice,
    this.onRequestMicrophonePermission,
    this.voiceRecorderService,
    this.replyTo,
    this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
  });

  final Future<void> Function(String text) onSend;
  final String hintText;
  final bool enabled;
  final Future<void> Function(BbComposerAttachmentAction action)?
      onAttachmentActionSelected;
  final Future<void> Function(RecordedVoiceDraft voice)? onSendVoice;
  final Future<bool> Function()? onRequestMicrophonePermission;
  final AppVoiceRecorderService? voiceRecorderService;
  final MessageReplyPreview? replyTo;
  final VoidCallback? onCancelReply;
  final MessageEditDraft? editingMessage;
  final VoidCallback? onCancelEdit;

  @override
  State<BbComposer> createState() => _BbComposerState();
}

class _BbComposerState extends State<BbComposer> {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _attachmentButtonKey = GlobalKey();
  bool _sending = false;
  bool _voiceProcessing = false;
  bool _recording = false;
  Duration _recordingDuration = Duration.zero;
  final List<double> _recordingWaveform = <double>[];
  Timer? _recordingTimer;
  StreamSubscription<double>? _recordingLevelSubscription;
  DateTime? _recordingStartedAt;
  AppVoiceRecorderService? _ownedVoiceRecorderService;

  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _isEditing => widget.editingMessage != null;
  bool get _canRecordVoice => widget.onSendVoice != null && !_isEditing;

  AppVoiceRecorderService get _voiceRecorderService {
    return widget.voiceRecorderService ??
        (_ownedVoiceRecorderService ??= NativeAppVoiceRecorderService());
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    if (widget.editingMessage != null) {
      _replaceInputText(widget.editingMessage!.text);
    }
  }

  @override
  void didUpdateWidget(covariant BbComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editing = widget.editingMessage;
    final oldEditing = oldWidget.editingMessage;
    if (editing != null && editing.id != oldEditing?.id) {
      _replaceInputText(editing.text);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _inputFocusNode.canRequestFocus) {
          _inputFocusNode.requestFocus();
        }
      });
      return;
    }

    if (editing == null && oldEditing != null) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _recordingTimer?.cancel();
    _recordingLevelSubscription?.cancel();
    _ownedVoiceRecorderService?.dispose();
    _inputFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _replaceInputText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _submit() async {
    if (!widget.enabled || _sending) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    final onSend = widget.onSend;
    try {
      await onSend(text);
      if (!mounted) {
        return;
      }
      _controller.clear();
      if (mounted && _inputFocusNode.canRequestFocus) {
        _inputFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    if (!widget.enabled ||
        _sending ||
        _voiceProcessing ||
        _recording ||
        !_canRecordVoice) {
      return;
    }

    final permissionGranted =
        await widget.onRequestMicrophonePermission?.call() ?? true;
    if (!mounted) {
      return;
    }
    if (!permissionGranted) {
      return;
    }

    await _dismissKeyboard();
    if (!mounted) {
      return;
    }

    try {
      await _voiceRecorderService.start();
      if (!mounted) {
        await _voiceRecorderService.cancel();
        return;
      }
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Не получилось начать запись'),
          ),
        );
      }
      return;
    }

    _recordingTimer?.cancel();
    _recordingLevelSubscription?.cancel();
    _recordingStartedAt = DateTime.now();

    setState(() {
      _recording = true;
      _recordingDuration = Duration.zero;
      _recordingWaveform.clear();
    });

    _recordingLevelSubscription = _voiceRecorderService.amplitudeStream.listen((
      level,
    ) {
      if (!mounted || !_recording) {
        return;
      }
      setState(() {
        _recordingWaveform.add(level.clamp(0.0, 1.0));
        if (_recordingWaveform.length > 48) {
          _recordingWaveform.removeAt(0);
        }
      });
    });

    _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _recordingStartedAt == null) {
        return;
      }
      setState(() {
        _recordingDuration = DateTime.now().difference(_recordingStartedAt!);
      });
    });
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_recording) {
      return;
    }

    _recordingTimer?.cancel();
    _recordingLevelSubscription?.cancel();
    await _voiceRecorderService.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _recording = false;
      _recordingDuration = Duration.zero;
      _recordingWaveform.clear();
      _recordingStartedAt = null;
    });
  }

  Future<void> _sendVoiceRecording() async {
    if (!_recording ||
        widget.onSendVoice == null ||
        _sending ||
        _voiceProcessing) {
      return;
    }

    _recordingTimer?.cancel();
    _recordingLevelSubscription?.cancel();

    setState(() {
      _voiceProcessing = true;
    });

    RecordedVoiceDraft? draft;
    try {
      final voice = await _voiceRecorderService.stop();
      final waveform = voice.waveform.isNotEmpty
          ? voice.waveform
          : List<double>.from(_recordingWaveform, growable: false);
      draft = voice.copyWith(waveform: waveform);

      if (!mounted) {
        return;
      }

      setState(() {
        _recording = false;
        _recordingDuration = Duration.zero;
        _recordingWaveform.clear();
        _recordingStartedAt = null;
        _voiceProcessing = false;
      });

      final onSendVoice = widget.onSendVoice;
      if (onSendVoice == null) {
        return;
      }
      unawaited(_dispatchVoiceDraft(draft, onSendVoice));
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Не получилось отправить голосовое'),
          ),
        );
        setState(() {
          _voiceProcessing = false;
        });
      }
    }
  }

  Future<void> _dispatchVoiceDraft(
    RecordedVoiceDraft draft,
    Future<void> Function(RecordedVoiceDraft voice) onSendVoice,
  ) async {
    try {
      await onSendVoice(draft);
    } catch (_) {
      if (!mounted || !context.mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Не получилось отправить голосовое'),
        ),
      );
    }
  }

  Future<void> _openAttachmentActions() async {
    if (!widget.enabled ||
        widget.onAttachmentActionSelected == null ||
        _recording) {
      return;
    }

    final onAttachmentActionSelected = widget.onAttachmentActionSelected;
    await _dismissKeyboard();
    if (!mounted) {
      return;
    }

    final colors = AppColors.of(context);
    final useV5 = colors.background == AppColors.lightTheme.background;
    final buttonBox =
        _attachmentButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (buttonBox == null || overlayBox is! RenderBox) {
      return;
    }
    final offset = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy - 156,
      overlayBox.size.width - offset.dx - buttonBox.size.width,
      overlayBox.size.height - offset.dy,
    );

    final menuItemHeight = useV5 ? 40.0 : kMinInteractiveDimension;
    final action = await showMenu<BbComposerAttachmentAction>(
      context: context,
      position: position,
      color: useV5 ? BbV5Colors.paperHi : colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: useV5 ? BbV5Colors.hair : colors.border,
        ),
      ),
      items: [
        PopupMenuItem(
          value: BbComposerAttachmentAction.photo,
          height: menuItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const _AttachmentMenuItem(
            icon: Icons.image_outlined,
            label: 'Фото',
          ),
        ),
        PopupMenuItem(
          value: BbComposerAttachmentAction.file,
          height: menuItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const _AttachmentMenuItem(
            icon: Icons.attach_file_rounded,
            label: 'Файл',
          ),
        ),
        PopupMenuItem(
          value: BbComposerAttachmentAction.location,
          height: menuItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const _AttachmentMenuItem(
            icon: Icons.place_outlined,
            label: 'Геолокация',
          ),
        ),
      ],
    );
    if (action == null) {
      return;
    }
    if (!mounted || !context.mounted || onAttachmentActionSelected == null) {
      return;
    }
    await onAttachmentActionSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final useV5 = colors.background == AppColors.lightTheme.background;
    final composerPadding = useV5
        ? const EdgeInsets.fromLTRB(20, 10, 20, 20)
        : const EdgeInsets.fromLTRB(12, 8, 12, 12);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: useV5 ? null : colors.background,
        gradient: useV5
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  BbV5Colors.paper.withValues(alpha: 0),
                  BbV5Colors.paper.withValues(alpha: 0.96),
                  BbV5Colors.paper,
                ],
                stops: const [0, 0.35, 1],
              )
            : null,
        border: useV5
            ? null
            : Border(
                top: BorderSide(
                  color: colors.border.withValues(alpha: 0.6),
                ),
              ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: composerPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.editingMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EditComposerPreview(
                    editingMessage: widget.editingMessage!,
                    onCancel: widget.onCancelEdit,
                  ),
                )
              else if (widget.replyTo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReplyComposerPreview(
                    replyTo: widget.replyTo!,
                    onCancel: widget.onCancelReply,
                  ),
                ),
              _recording
                  ? _RecordingComposerRow(
                      duration: _recordingDuration,
                      waveform: _recordingWaveform,
                      onCancel: _voiceProcessing ? null : _cancelVoiceRecording,
                      onSend: _voiceProcessing ? null : _sendVoiceRecording,
                    )
                  : useV5
                      ? _buildV5ComposerRow()
                      : Row(
                          children: [
                            _CircleButton(
                              key: _attachmentButtonKey,
                              icon: Icons.add_rounded,
                              size: 44,
                              foreground:
                                  useV5 ? BbV5Colors.ink : colors.inkSoft,
                              background:
                                  useV5 ? BbV5Colors.paperHi : colors.muted,
                              onTap: widget.enabled && !_sending
                                  ? (_isEditing ? null : _openAttachmentActions)
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                decoration: BoxDecoration(
                                  color:
                                      useV5 ? BbV5Colors.paperHi : colors.card,
                                  borderRadius: AppRadii.pillBorder,
                                  border: useV5
                                      ? Border.all(color: BbV5Colors.hair)
                                      : null,
                                  boxShadow: useV5
                                      ? BbV5Shadows.pill
                                      : AppShadows.soft,
                                ),
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.md,
                                  right: 8,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _controller,
                                        focusNode: _inputFocusNode,
                                        enabled: widget.enabled && !_sending,
                                        minLines: 1,
                                        maxLines: 4,
                                        textInputAction: TextInputAction.send,
                                        onTapOutside: (_) {
                                          unawaited(_dismissKeyboard());
                                        },
                                        onSubmitted: (_) => _submit(),
                                        decoration: InputDecoration(
                                          hintText: widget.hintText,
                                          hintStyle:
                                              AppTextStyles.body.copyWith(
                                            color: useV5
                                                ? BbV5Colors.inkMute
                                                : colors.inkMute,
                                          ),
                                          border: InputBorder.none,
                                          isCollapsed: true,
                                        ),
                                        style: AppTextStyles.body.copyWith(
                                          color: useV5
                                              ? BbV5Colors.ink
                                              : colors.foreground,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            if (!_hasText && _canRecordVoice)
                              _CircleButton(
                                key: const Key('bb-composer-mic-button'),
                                icon: Icons.mic_rounded,
                                size: 44,
                                foreground: useV5
                                    ? BbV5Colors.paperHi
                                    : colors.primaryForeground,
                                background:
                                    useV5 ? BbV5Colors.accent : colors.primary,
                                onTap: widget.enabled && !_sending
                                    ? _startVoiceRecording
                                    : null,
                              )
                            else
                              _CircleButton(
                                key: const Key('bb-composer-send-button'),
                                icon: _sending
                                    ? Icons.more_horiz_rounded
                                    : Icons.send_rounded,
                                size: 44,
                                foreground: useV5
                                    ? BbV5Colors.paperHi
                                    : colors.primaryForeground,
                                background:
                                    useV5 ? BbV5Colors.accent : colors.primary,
                                onTap: widget.enabled ? _submit : null,
                              ),
                          ],
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dismissKeyboard() async {
    _inputFocusNode.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    } catch (_) {}
  }

  Widget _buildV5ComposerRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _CircleButton(
          key: _attachmentButtonKey,
          icon: Icons.add_rounded,
          size: 44,
          foreground: BbV5Colors.ink,
          background: BbV5Colors.paperHi,
          borderColor: BbV5Colors.hair,
          shadows: BbV5Shadows.pill,
          onTap: widget.enabled && !_sending
              ? (_isEditing ? null : _openAttachmentActions)
              : null,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Container(
            key: const Key('bb-composer-input-shell'),
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BbV5Colors.hair),
              boxShadow: BbV5Shadows.pill,
            ),
            padding: const EdgeInsets.only(left: 16, right: 6),
            alignment: Alignment.center,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocusNode,
                      enabled: widget.enabled && !_sending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onTapOutside: (_) {
                        unawaited(_dismissKeyboard());
                      },
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: AppTextStyles.body.copyWith(
                          color: BbV5Colors.inkMute,
                          fontSize: 13.5,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: AppTextStyles.body.copyWith(
                        color: BbV5Colors.ink,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                if (_hasText || !_canRecordVoice)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 4),
                    child: _CircleButton(
                      key: const Key('bb-composer-send-button'),
                      icon: _sending
                          ? Icons.more_horiz_rounded
                          : Icons.send_rounded,
                      size: 34,
                      iconSize: 16,
                      foreground: BbV5Colors.paperHi,
                      background: BbV5Colors.accent,
                      shadows: BbV5Shadows.ink,
                      onTap: widget.enabled ? _submit : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_canRecordVoice) ...[
          const SizedBox(width: AppSpacing.xs),
          _CircleButton(
            key: const Key('bb-composer-mic-button'),
            icon: Icons.mic_none_rounded,
            size: 44,
            iconSize: 18,
            foreground: BbV5Colors.ink,
            background: BbV5Colors.paperHi,
            borderColor: BbV5Colors.hair,
            shadows: BbV5Shadows.pill,
            onTap: widget.enabled && !_sending ? _startVoiceRecording : null,
          ),
        ],
      ],
    );
  }
}

class _ReplyComposerPreview extends StatelessWidget {
  const _ReplyComposerPreview({
    required this.replyTo,
    required this.onCancel,
  });

  final MessageReplyPreview replyTo;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: colors.primary,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ответ ${replyTo.author}',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyTo.isVoice ? 'Голосовое сообщение' : replyTo.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: Icon(
              Icons.close_rounded,
              color: colors.inkSoft,
            ),
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _EditComposerPreview extends StatelessWidget {
  const _EditComposerPreview({
    required this.editingMessage,
    required this.onCancel,
  });

  final MessageEditDraft editingMessage;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: colors.primary,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Редактирование',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  editingMessage.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: Icon(
              Icons.close_rounded,
              color: colors.inkSoft,
            ),
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _RecordingComposerRow extends StatelessWidget {
  const _RecordingComposerRow({
    required this.duration,
    required this.waveform,
    required this.onCancel,
    required this.onSend,
  });

  final Duration duration;
  final List<double> waveform;
  final VoidCallback? onCancel;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final useV5 = colors.background == AppColors.lightTheme.background;
    final danger = useV5 ? BbV5Colors.terra : colors.destructive;
    final surface = useV5 ? BbV5Colors.paperHi : colors.card;
    final foreground = useV5 ? BbV5Colors.ink : colors.foreground;
    final muted = useV5 ? BbV5Colors.inkMute : colors.inkMute;
    final border = useV5 ? BbV5Colors.hair : colors.border;
    final sendColor = useV5 ? BbV5Colors.accent : colors.primary;
    final sendForeground =
        useV5 ? BbV5Colors.paperHi : colors.primaryForeground;

    return Row(
      children: [
        _CircleButton(
          key: const Key('bb-composer-voice-cancel'),
          icon: LucideIcons.trash_2,
          size: 44,
          iconSize: 18,
          foreground: danger,
          background: useV5 ? BbV5Colors.paperHi : colors.muted,
          borderColor: useV5 ? BbV5Colors.hair : null,
          shadows: useV5 ? BbV5Shadows.pill : null,
          onTap: onCancel,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Container(
            key: const Key('bb-composer-voice-recording-pill'),
            height: 44,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(BbV5Radii.pill),
              boxShadow: useV5 ? BbV5Shadows.pill : AppShadows.soft,
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 1),
                Text(
                  _formatDuration(duration),
                  maxLines: 1,
                  style: AppTextStyles.bodySoft.copyWith(
                    fontFamily: useV5 ? 'Sora' : null,
                    color: foreground,
                    fontSize: useV5 ? 12 : 13,
                    height: useV5 ? 1.1 : null,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _RecordingWaveform(
                    waveform: waveform,
                    color: foreground.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.lock,
                  size: 12,
                  color: muted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'запись',
                      maxLines: 1,
                      style: AppTextStyles.caption.copyWith(
                        color: muted,
                        fontSize: useV5 ? 10.5 : null,
                        height: useV5 ? 1.1 : null,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CircleButton(
          key: const Key('bb-composer-voice-send'),
          icon: LucideIcons.send,
          size: 44,
          iconSize: 18,
          foreground: sendForeground,
          background: sendColor,
          shadows: useV5 ? BbV5Shadows.ink : null,
          onTap: onSend,
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes;
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _RecordingWaveform extends StatelessWidget {
  const _RecordingWaveform({
    required this.waveform,
    required this.color,
  });

  final List<double> waveform;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const barWidth = 2.4;
        const barHorizontalPadding = 1.0;
        const slotWidth = barWidth + (barHorizontalPadding * 2);
        final maxBars = constraints.maxWidth < slotWidth
            ? 0
            : math.max(1, constraints.maxWidth ~/ slotWidth);
        if (maxBars == 0) {
          return const SizedBox.shrink();
        }
        final source = waveform.isEmpty
            ? List<double>.filled(maxBars, 0.38, growable: false)
            : waveform;
        final visibleBars = source.length > maxBars
            ? source.sublist(source.length - maxBars)
            : source;

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: visibleBars
              .map(
                (value) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: barWidth,
                    height: 4 + (value.clamp(0.0, 1.0) * 14),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _AttachmentMenuItem extends StatelessWidget {
  const _AttachmentMenuItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final useV5 = colors.background == AppColors.lightTheme.background;
    final foreground = useV5 ? BbV5Colors.ink : colors.foreground;
    final iconColor = useV5 ? BbV5Colors.inkSoft : colors.primary;

    return Row(
      children: [
        Icon(icon, size: useV5 ? 16 : 18, color: iconColor),
        SizedBox(width: useV5 ? 12 : 10),
        Text(
          label,
          style: AppTextStyles.meta.copyWith(
            color: foreground,
            fontSize: useV5 ? 13 : null,
            fontWeight: useV5 ? FontWeight.w500 : FontWeight.w600,
            height: useV5 ? 1.1 : null,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    required this.size,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.iconSize = 20,
    this.borderColor,
    this.shadows,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: shadows,
      ),
      child: Material(
        color: background,
        shape: CircleBorder(
          side: BorderSide(color: borderColor ?? Colors.transparent),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}
