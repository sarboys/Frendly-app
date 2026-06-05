import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

const _voiceRecordBitRate = 64000;
const _voiceRecordSampleRate = 32000;
const _voiceRecordChannels = 1;

RecordConfig buildVoiceRecordConfig() {
  return const RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: _voiceRecordBitRate,
    sampleRate: _voiceRecordSampleRate,
    numChannels: _voiceRecordChannels,
    iosConfig: IosRecordConfig(),
  );
}

final appVoiceRecorderServiceProvider =
    Provider<AppVoiceRecorderService>((ref) {
  final service = NativeAppVoiceRecorderService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

class RecordedVoiceDraft {
  const RecordedVoiceDraft({
    required this.path,
    required this.fileName,
    required this.durationMs,
    required this.waveform,
  });

  final String path;
  final String fileName;
  final int durationMs;
  final List<double> waveform;
}

abstract class AppVoiceRecorderService {
  Stream<double> get amplitudeStream;

  Future<bool> hasPermission();

  Future<void> start();

  Future<RecordedVoiceDraft> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class NativeAppVoiceRecorderService implements AppVoiceRecorderService {
  NativeAppVoiceRecorderService({
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  static const _amplitudeInterval = Duration(milliseconds: 80);

  AudioRecorder _recorder;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final List<double> _amplitudeSamples = <double>[];
  String? _currentPath;
  DateTime? _startedAt;
  Directory? _currentDirectory;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  @override
  Future<void> start() async {
    await _stopAmplitudeSubscription();
    _amplitudeSamples.clear();

    final tempDir = await Directory.systemTemp.createTemp('dateasy-voice');
    final fileName =
        'dateasy-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
    final path = '${tempDir.path}/$fileName';

    await _recorder.ios?.manageAudioSession(true);
    try {
      await _recorder.start(buildVoiceRecordConfig(), path: path);
    } catch (_) {
      await _recreateRecorder();
      await _recorder.ios?.manageAudioSession(true);
      await _recorder.start(buildVoiceRecordConfig(), path: path);
    }

    _currentPath = path;
    _currentDirectory = tempDir;
    _startedAt = DateTime.now();
    _amplitudeSubscription =
        _recorder.onAmplitudeChanged(_amplitudeInterval).listen((amplitude) {
      final normalized = _normalizeAmplitude(amplitude.current);
      _amplitudeSamples.add(normalized);
      if (_amplitudeSamples.length > 1800) {
        _amplitudeSamples.removeRange(0, _amplitudeSamples.length - 1800);
      }
      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(normalized);
      }
    });
  }

  @override
  Future<RecordedVoiceDraft> stop() async {
    final path = await _recorder.stop() ?? _currentPath;
    await _stopAmplitudeSubscription();
    if (path == null || path.isEmpty) {
      throw StateError('voice_recording_path_missing');
    }

    final startedAt = _startedAt;
    final durationMs = startedAt == null
        ? 1
        : DateTime.now()
            .difference(startedAt)
            .inMilliseconds
            .clamp(1, 180000)
            .toInt();
    final waveform = _recordWaveformFromSamples(_amplitudeSamples, durationMs);
    _amplitudeSamples.clear();
    _currentPath = null;
    _currentDirectory = null;
    _startedAt = null;

    return RecordedVoiceDraft(
      path: path,
      fileName: path.replaceAll('\\', '/').split('/').last,
      durationMs: durationMs,
      waveform: waveform,
    );
  }

  @override
  Future<void> cancel() async {
    await _stopAmplitudeSubscription();
    try {
      await _recorder.cancel();
    } catch (_) {}
    _amplitudeSamples.clear();
    _currentPath = null;
    final directory = _currentDirectory;
    _currentDirectory = null;
    _startedAt = null;
    await _deleteDirectory(directory);
  }

  @override
  Future<void> dispose() async {
    await _stopAmplitudeSubscription();
    await _amplitudeController.close();
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  Future<void> _recreateRecorder() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
    _recorder = AudioRecorder();
  }

  Future<void> _stopAmplitudeSubscription() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  Future<void> _deleteDirectory(Directory? directory) async {
    if (directory == null) {
      return;
    }
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  }
}

double _normalizeAmplitude(double currentDbfs) {
  if (!currentDbfs.isFinite) {
    return 0.08;
  }
  final clamped = currentDbfs.clamp(-50.0, 0.0).toDouble();
  final normalized = (clamped + 50.0) / 50.0;
  return math.pow(normalized, 1.6).toDouble().clamp(0.08, 1.0);
}

List<double> _recordWaveformFromSamples(List<double> samples, int durationMs) {
  if (samples.isEmpty) {
    return _fallbackWaveform(durationMs);
  }

  final targetBars = math.max(24, math.min(48, durationMs ~/ 350));
  final samplesPerBar = math.max(1, (samples.length / targetBars).ceil());
  final bars = <double>[];
  for (var index = 0; index < samples.length; index += samplesPerBar) {
    final end = math.min(index + samplesPerBar, samples.length);
    var peak = 0.08;
    for (var sampleIndex = index; sampleIndex < end; sampleIndex += 1) {
      peak = math.max(peak, samples[sampleIndex]);
    }
    bars.add(peak.clamp(0.08, 1.0));
  }

  return bars.isEmpty ? _fallbackWaveform(durationMs) : bars;
}

List<double> _fallbackWaveform(int durationMs) {
  final bars = math.max(24, math.min(40, durationMs ~/ 450));
  return List<double>.generate(
    bars,
    (index) => 0.22 + ((index % 5) * 0.12),
    growable: false,
  );
}
