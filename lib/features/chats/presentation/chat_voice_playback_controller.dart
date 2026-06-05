import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final chatVoicePlaybackEngineFactoryProvider =
    Provider<ChatVoicePlaybackEngine Function()>((ref) {
  return () => JustAudioChatVoicePlaybackEngine();
});

final chatVoicePlaybackControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatVoicePlaybackController, ChatVoicePlaybackState, String>((
  ref,
  chatId,
) {
  return ChatVoicePlaybackController(
    engine: ref.read(chatVoicePlaybackEngineFactoryProvider)(),
  );
});

class ChatVoicePlaybackRequest {
  const ChatVoicePlaybackRequest({
    required this.playbackId,
    required this.durationMs,
    this.localPath,
    this.url,
    this.resolveRemoteFilePath,
    this.resolveRemoteUrl,
  });

  final String playbackId;
  final String? localPath;
  final String? url;
  final int durationMs;
  final Future<String?> Function()? resolveRemoteFilePath;
  final Future<String?> Function()? resolveRemoteUrl;
}

class ChatVoicePlaybackState {
  const ChatVoicePlaybackState({
    this.activePlaybackId,
    this.isPlaying = false,
    this.isLoading = false,
    this.hasError = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
  });

  final String? activePlaybackId;
  final bool isPlaying;
  final bool isLoading;
  final bool hasError;
  final Duration duration;
  final Duration position;

  ChatVoicePlaybackState copyWith({
    String? activePlaybackId,
    bool? isPlaying,
    bool? isLoading,
    bool? hasError,
    Duration? duration,
    Duration? position,
  }) {
    return ChatVoicePlaybackState(
      activePlaybackId: activePlaybackId ?? this.activePlaybackId,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      duration: duration ?? this.duration,
      position: position ?? this.position,
    );
  }
}

class ChatVoicePlaybackController
    extends StateNotifier<ChatVoicePlaybackState> {
  ChatVoicePlaybackController({
    required ChatVoicePlaybackEngine engine,
  })  : _engine = engine,
        super(const ChatVoicePlaybackState()) {
    _positionSubscription = _engine.positionStream.listen(_handlePosition);
    _durationSubscription = _engine.durationStream.listen(_handleDuration);
    _playbackStateSubscription =
        _engine.playbackStateStream.listen(_handlePlaybackState);
  }

  final ChatVoicePlaybackEngine _engine;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<ChatVoiceEngineState>? _playbackStateSubscription;
  String? _loadedPlaybackId;
  var _generation = 0;

  Future<void> toggle(ChatVoicePlaybackRequest request) async {
    final isSamePlayback = state.activePlaybackId == request.playbackId;
    if (isSamePlayback) {
      if (state.isLoading) {
        return;
      }
      if (state.hasError) {
        _loadedPlaybackId = null;
        await _loadAndPlay(request);
        return;
      }
      if (state.isPlaying) {
        await _engine.pause();
        if (!mounted) {
          return;
        }
        state = state.copyWith(isPlaying: false, isLoading: false);
        return;
      }
      await _engine.play();
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isPlaying: true,
        isLoading: false,
        hasError: false,
      );
      return;
    }

    await _loadAndPlay(request);
  }

  Future<void> _loadAndPlay(ChatVoicePlaybackRequest request) async {
    final generation = ++_generation;
    if (state.activePlaybackId != null) {
      await _engine.stop();
      if (!_isCurrentGeneration(generation)) {
        return;
      }
    }

    state = ChatVoicePlaybackState(
      activePlaybackId: request.playbackId,
      isLoading: true,
      duration: Duration(milliseconds: request.durationMs),
    );

    try {
      if (_loadedPlaybackId != request.playbackId) {
        final loaded = await _loadSource(request);
        if (!_isCurrentGeneration(generation)) {
          return;
        }
        if (!loaded) {
          throw StateError('voice_source_missing');
        }
        _loadedPlaybackId = request.playbackId;
      }
      await _engine.play();
      if (!_isCurrentGeneration(generation)) {
        return;
      }
      state = state.copyWith(
        isPlaying: true,
        isLoading: false,
        hasError: false,
      );
    } catch (_) {
      if (!_isCurrentGeneration(generation)) {
        return;
      }
      _loadedPlaybackId = null;
      state = state.copyWith(
        isPlaying: false,
        isLoading: false,
        hasError: true,
      );
    }
  }

  Future<bool> _loadSource(ChatVoicePlaybackRequest request) async {
    final localPath = request.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      try {
        if (await File(localPath).exists()) {
          await _engine.setFilePath(localPath);
          return true;
        }
      } catch (_) {}
    }
    final direct = request.url;
    if (direct != null && direct.isNotEmpty) {
      await _engine.setUrl(direct);
      return true;
    }
    try {
      final cachedPath = await request.resolveRemoteFilePath?.call();
      if (cachedPath != null && cachedPath.isNotEmpty) {
        await _engine.setFilePath(cachedPath);
        return true;
      }
    } catch (_) {}
    final resolved = await request.resolveRemoteUrl?.call();
    if (resolved == null || resolved.isEmpty) {
      return false;
    }
    await _engine.setUrl(resolved);
    return true;
  }

  void _handlePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  void _handleDuration(Duration? duration) {
    if (duration == null || duration <= Duration.zero) {
      return;
    }
    state = state.copyWith(duration: duration);
  }

  void _handlePlaybackState(ChatVoiceEngineState playbackState) {
    if (state.activePlaybackId == null) {
      return;
    }
    if (playbackState.processingState == ProcessingState.completed) {
      state = state.copyWith(
        isPlaying: false,
        isLoading: false,
        position: Duration.zero,
      );
      unawaited(_rewindCompletedPlayback());
      return;
    }
    state = state.copyWith(
      isPlaying: playbackState.playing,
      isLoading: !playbackState.playing &&
          (playbackState.processingState == ProcessingState.loading ||
              playbackState.processingState == ProcessingState.buffering),
      hasError: false,
    );
  }

  bool _isCurrentGeneration(int generation) => generation == _generation;

  Future<void> _rewindCompletedPlayback() async {
    await _engine.pause();
    await _engine.seek(Duration.zero);
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_playbackStateSubscription?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }
}

class ChatVoiceEngineState {
  const ChatVoiceEngineState({
    required this.playing,
    required this.processingState,
  });

  final bool playing;
  final ProcessingState processingState;
}

abstract class ChatVoicePlaybackEngine {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<ChatVoiceEngineState> get playbackStateStream;

  Future<void> setUrl(String url);
  Future<void> setFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioChatVoicePlaybackEngine implements ChatVoicePlaybackEngine {
  JustAudioChatVoicePlaybackEngine() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<ChatVoiceEngineState> get playbackStateStream =>
      _player.playerStateStream.map(
        (state) => ChatVoiceEngineState(
          playing: state.playing,
          processingState: state.processingState,
        ),
      );

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> stop() => _player.stop();
}
