import 'dart:math' as math;

import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_voice_playback_controller.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BbVoiceMessage extends ConsumerWidget {
  const BbVoiceMessage({
    required this.chatId,
    required this.playbackId,
    required this.attachmentId,
    required this.durationMs,
    required this.waveform,
    super.key,
    this.url,
    this.localPath,
    this.isMine = false,
    this.resolveLocalPath,
    this.resolveRemoteUrl,
  });

  final String chatId;
  final String playbackId;
  final String attachmentId;
  final String? url;
  final String? localPath;
  final int durationMs;
  final List<double> waveform;
  final bool isMine;
  final Future<String?> Function()? resolveLocalPath;
  final Future<String?> Function()? resolveRemoteUrl;

  List<double> _fallbackWaveform() {
    const seed = <double>[
      0.30,
      0.55,
      0.40,
      0.70,
      0.50,
      0.85,
      0.60,
      0.45,
      0.75,
      0.90,
      0.55,
      0.35,
      0.60,
      0.80,
      0.50,
      0.40,
      0.65,
      0.50,
      0.75,
      0.40,
      0.55,
      0.70,
      0.50,
      0.30,
      0.50,
      0.65,
      0.45,
      0.60,
      0.35,
      0.50,
    ];
    final bars = math.max(24, math.min(30, durationMs ~/ 500));
    return List<double>.generate(
      bars,
      (index) => seed[index % seed.length],
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(
      chatVoicePlaybackControllerProvider(chatId).select(
        (state) => _VoiceMessagePlaybackState.fromState(
          state,
          playbackId: playbackId,
        ),
      ),
    );
    final isActive = playbackState.isActive;
    final colors = AppColors.of(context);
    final useV5 = colors.background == AppColors.lightTheme.background;
    final foreground = useV5
        ? (isMine ? BbV5Colors.paperHi : BbV5Colors.ink)
        : (isMine ? colors.bubbleMeForeground : colors.bubbleThemForeground);
    final muted = useV5
        ? (isMine
            ? BbV5Colors.paperHi.withValues(alpha: 0.4)
            : BbV5Colors.ink.withValues(alpha: 0.3))
        : (isMine
            ? colors.bubbleMeForeground.withValues(alpha: 0.4)
            : colors.inkSoft.withValues(alpha: 0.3));
    final playBackground = useV5
        ? (isMine
            ? BbV5Colors.paperHi.withValues(alpha: 0.15)
            : BbV5Colors.paper)
        : foreground.withValues(alpha: isMine ? 0.18 : 0.1);
    final playBorder =
        useV5 && !isMine ? Border.all(color: BbV5Colors.hair) : null;
    final duration = isActive && playbackState.duration > Duration.zero
        ? playbackState.duration
        : Duration(milliseconds: durationMs);
    final position = playbackState.position;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final remaining = isActive ? duration - position : duration;
    final isPlaying = playbackState.isPlaying;
    final isLoading = playbackState.isLoading && !playbackState.isPlaying;
    final hasError = playbackState.hasError;
    final bars = waveform.isNotEmpty ? waveform : _fallbackWaveform();

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.hasBoundedWidth ? constraints.maxWidth : 184.0;
          final waveformWidth = useV5
              ? math.min(138.0, math.max(60.0, maxWidth - 90.0))
              : math.max(60.0, maxWidth - 110.0);

          return Row(
            key: const Key('bb-chat-voice-message'),
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: playBackground,
                  shape: BoxShape.circle,
                  border: playBorder,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ref
                        .read(chatVoicePlaybackControllerProvider(chatId)
                            .notifier)
                        .toggle(
                          ChatVoicePlaybackRequest(
                            playbackId: playbackId,
                            attachmentId: attachmentId,
                            url: url,
                            localPath: localPath,
                            durationMs: durationMs,
                            resolveLocalPath: resolveLocalPath,
                            resolveRemoteUrl: resolveRemoteUrl,
                          ),
                        ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  foreground,
                                ),
                              ),
                            )
                          : Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : (hasError
                                      ? Icons.refresh_rounded
                                      : Icons.play_arrow_rounded),
                              color: foreground,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                key: const Key('bb-chat-voice-waveform'),
                width: waveformWidth,
                height: 28,
                child: ClipRect(
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      bars: bars,
                      progress: progress,
                      activeColor: foreground,
                      inactiveColor: muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  _formatDuration(remaining),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: useV5 ? 'Sora' : null,
                    fontSize: useV5 ? 10.5 : null,
                    height: useV5 ? 1.1 : null,
                    color: isMine
                        ? foreground.withValues(alpha: 0.8)
                        : (useV5 ? BbV5Colors.inkSoft : colors.inkSoft),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

@immutable
class _VoiceMessagePlaybackState {
  const _VoiceMessagePlaybackState._({
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.hasError,
    required this.position,
    required this.duration,
  });

  const _VoiceMessagePlaybackState.inactive()
      : this._(
          isActive: false,
          isPlaying: false,
          isLoading: false,
          hasError: false,
          position: Duration.zero,
          duration: Duration.zero,
        );

  factory _VoiceMessagePlaybackState.fromState(
    ChatVoicePlaybackState state, {
    required String playbackId,
  }) {
    if (state.activePlaybackId != playbackId) {
      return const _VoiceMessagePlaybackState.inactive();
    }

    return _VoiceMessagePlaybackState._(
      isActive: true,
      isPlaying: state.isPlaying,
      isLoading: state.isLoading,
      hasError: state.hasError,
      position: state.position,
      duration: state.duration,
    );
  }

  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final bool hasError;
  final Duration position;
  final Duration duration;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _VoiceMessagePlaybackState &&
            other.isActive == isActive &&
            other.isPlaying == isPlaying &&
            other.isLoading == isLoading &&
            other.hasError == hasError &&
            other.position == position &&
            other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(
        isActive,
        isPlaying,
        isLoading,
        hasError,
        position,
        duration,
      );
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) {
      return;
    }

    const barWidth = 2.5;
    const gap = 3.0;
    final maxBars = math.max(
      1,
      ((size.width + gap) / (barWidth + gap)).floor(),
    );
    final visibleBars = _fitBars(bars, maxBars);
    final count = visibleBars.length;
    final paint = Paint()..strokeCap = StrokeCap.round;

    var x = 0.0;
    for (var index = 0; index < count; index++) {
      if (x + barWidth > size.width + 0.5) {
        break;
      }

      final factor = visibleBars[index].clamp(0.0, 1.0);
      final barHeight = math.max(15.0, factor * size.height);
      final active = (index + 1) / count <= progress;
      paint
        ..color = active ? activeColor : inactiveColor
        ..strokeWidth = barWidth;

      final top = (size.height - barHeight) / 2;
      final bottom = top + barHeight;
      final centerX = x + (barWidth / 2);
      canvas.drawLine(
        Offset(centerX, top),
        Offset(centerX, bottom),
        paint,
      );

      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        !listEquals(oldDelegate.bars, bars);
  }

  List<double> _fitBars(List<double> source, int maxBars) {
    if (source.length <= maxBars) {
      return source;
    }
    if (maxBars <= 1) {
      return <double>[source.last];
    }

    return List<double>.generate(maxBars, (index) {
      final start = (index * source.length / maxBars).floor();
      final end = math.max(
        start + 1,
        ((index + 1) * source.length / maxBars).ceil(),
      );
      return source
          .sublist(start, math.min(end, source.length))
          .reduce(math.max);
    }, growable: false);
  }
}

String _formatDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final minutes = safe.inMinutes;
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
