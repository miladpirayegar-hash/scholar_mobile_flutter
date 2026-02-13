import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/user_prefs_provider.dart';

class RecordingService {
  RecordingService(this.ref);

  final Ref ref;
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  Future<String> startRecording() async {
    final config = await _configForQuality();
    if (kIsWeb) {
      const webPath = 'session_web.m4a';
      await _recorder.start(config, path: webPath);
      return webPath;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/session_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(config, path: path);

    return path;
  }

  Future<String?> stopRecording() async {
    return _recorder.stop();
  }

  Future<void> pauseRecording() async {
    await _recorder.pause();
  }

  Future<void> resumeRecording() async {
    await _recorder.resume();
  }

  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    return _recorder.onAmplitudeChanged(interval);
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  Future<RecordConfig> _configForQuality() async {
    final quality = ref.read(userPrefsProvider).recordingQuality;

    switch (quality) {
      case 'Data Saver':
        return const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        );
      case 'Balanced':
        return const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );
      case 'Lossless':
      default:
        return const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 256000,
          sampleRate: 48000,
        );
    }
  }
}
