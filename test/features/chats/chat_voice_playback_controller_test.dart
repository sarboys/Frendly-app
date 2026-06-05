import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mobile2/features/chats/presentation/chat_voice_playback_controller.dart';

void main() {
  test('starts only one voice playback per chat', () async {
    final engine = _FakeVoiceEngine();
    final controller = ChatVoicePlaybackController(engine: engine);
    addTearDown(controller.dispose);

    await controller.toggle(
      const ChatVoicePlaybackRequest(
        playbackId: 'voice-1',
        url: 'https://cdn.test/voice-1.m4a',
        durationMs: 1200,
      ),
    );
    await controller.toggle(
      const ChatVoicePlaybackRequest(
        playbackId: 'voice-2',
        url: 'https://cdn.test/voice-2.m4a',
        durationMs: 900,
      ),
    );

    expect(engine.loadedUrls, [
      'https://cdn.test/voice-1.m4a',
      'https://cdn.test/voice-2.m4a',
    ]);
    expect(engine.stopCalls, 1);
    expect(engine.playCalls, 2);
    expect(controller.state.activePlaybackId, 'voice-2');
    expect(controller.state.isPlaying, true);
  });

  test('toggles active voice playback to paused', () async {
    final engine = _FakeVoiceEngine();
    final controller = ChatVoicePlaybackController(engine: engine);
    addTearDown(controller.dispose);
    const request = ChatVoicePlaybackRequest(
      playbackId: 'voice-1',
      url: 'https://cdn.test/voice-1.m4a',
      durationMs: 1200,
    );

    await controller.toggle(request);
    await controller.toggle(request);

    expect(engine.pauseCalls, 1);
    expect(controller.state.activePlaybackId, 'voice-1');
    expect(controller.state.isPlaying, false);
  });

  test('retries active voice playback after load error', () async {
    final engine = _FakeVoiceEngine()..failNextSetUrl = true;
    final controller = ChatVoicePlaybackController(engine: engine);
    addTearDown(controller.dispose);
    const request = ChatVoicePlaybackRequest(
      playbackId: 'voice-1',
      url: 'https://cdn.test/voice-1.m4a',
      durationMs: 1200,
    );

    await controller.toggle(request);
    await controller.toggle(request);

    expect(engine.loadedUrls, [
      'https://cdn.test/voice-1.m4a',
      'https://cdn.test/voice-1.m4a',
    ]);
    expect(engine.playCalls, 1);
    expect(controller.state.hasError, false);
    expect(controller.state.isPlaying, true);
  });

  test('loads local voice file before remote url', () async {
    final tempDir = await Directory.systemTemp.createTemp('voice-local-test');
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}/voice.m4a');
    await file.writeAsString('voice');
    final engine = _FakeVoiceEngine();
    final controller = ChatVoicePlaybackController(engine: engine);
    addTearDown(controller.dispose);

    await controller.toggle(
      ChatVoicePlaybackRequest(
        playbackId: 'voice-local',
        localPath: file.path,
        url: 'https://cdn.test/voice.m4a',
        durationMs: 1200,
      ),
    );

    expect(engine.loadedFilePaths, [file.path]);
    expect(engine.loadedUrls, isEmpty);
    expect(controller.state.isPlaying, true);
  });

  test('loads cached remote voice file before signed url', () async {
    final engine = _FakeVoiceEngine();
    final controller = ChatVoicePlaybackController(engine: engine);
    addTearDown(controller.dispose);

    await controller.toggle(
      ChatVoicePlaybackRequest(
        playbackId: 'voice-remote',
        durationMs: 1200,
        resolveRemoteFilePath: () async => '/local/cache/voice.m4a',
        resolveRemoteUrl: () async => 'https://cdn.test/voice.m4a?token=1',
      ),
    );

    expect(engine.loadedFilePaths, ['/local/cache/voice.m4a']);
    expect(engine.loadedUrls, isEmpty);
    expect(controller.state.isPlaying, true);
  });

  test('falls back to signed url when remote voice cache fails', () async {
    final engine = _FakeVoiceEngine();
    final controller = ChatVoicePlaybackController(engine: engine);
    addTearDown(controller.dispose);

    await controller.toggle(
      ChatVoicePlaybackRequest(
        playbackId: 'voice-fallback',
        durationMs: 1200,
        resolveRemoteFilePath: () async => throw StateError('cache failed'),
        resolveRemoteUrl: () async => 'https://cdn.test/voice.m4a?token=1',
      ),
    );

    expect(engine.loadedFilePaths, isEmpty);
    expect(engine.loadedUrls, ['https://cdn.test/voice.m4a?token=1']);
    expect(controller.state.isPlaying, true);
  });

  test('pauses completed playback before rewinding to the start', () async {
    final engine = _FakeVoiceEngine();
    final controller = ChatVoicePlaybackController(engine: engine);
    addTearDown(controller.dispose);

    await controller.toggle(
      const ChatVoicePlaybackRequest(
        playbackId: 'voice-1',
        url: 'https://cdn.test/voice-1.m4a',
        durationMs: 1200,
      ),
    );
    engine.completeWhilePlaying();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isPlaying, false);
    expect(engine.completedActions, ['pause', 'seek:0']);
  });
}

class _FakeVoiceEngine implements ChatVoicePlaybackEngine {
  final loadedUrls = <String>[];
  final loadedFilePaths = <String>[];
  var failNextSetUrl = false;
  var playCalls = 0;
  var pauseCalls = 0;
  var stopCalls = 0;
  var disposeCalls = 0;
  final completedActions = <String>[];
  var _completed = false;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _stateController = StreamController<ChatVoiceEngineState>.broadcast();

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<ChatVoiceEngineState> get playbackStateStream =>
      _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _positionController.close();
    await _durationController.close();
    await _stateController.close();
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    if (_completed) {
      completedActions.add('pause');
    }
  }

  @override
  Future<void> play() async {
    playCalls++;
    _stateController.add(
      const ChatVoiceEngineState(
        playing: true,
        processingState: ProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    if (_completed) {
      completedActions.add('seek:${position.inMilliseconds}');
    }
  }

  @override
  Future<void> setUrl(String url) async {
    loadedUrls.add(url);
    if (failNextSetUrl) {
      failNextSetUrl = false;
      throw StateError('load failed');
    }
  }

  @override
  Future<void> setFilePath(String path) async {
    loadedFilePaths.add(path);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void completeWhilePlaying() {
    _completed = true;
    _stateController.add(
      const ChatVoiceEngineState(
        playing: true,
        processingState: ProcessingState.completed,
      ),
    );
  }
}
