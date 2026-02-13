import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecordingStatus {
  final bool isRecording;
  final bool isPaused;
  final String? unitId;
  final String? unitTitle;
  final String? audioPath;
  final DateTime? startedAt;
  final int elapsedSeconds;

  const RecordingStatus({
    this.isRecording = false,
    this.isPaused = false,
    this.unitId,
    this.unitTitle,
    this.audioPath,
    this.startedAt,
    this.elapsedSeconds = 0,
  });

  int currentElapsedSeconds() {
    if (!isRecording) return 0;
    if (isPaused || startedAt == null) return elapsedSeconds;
    return elapsedSeconds + DateTime.now().difference(startedAt!).inSeconds;
  }

  RecordingStatus copyWith({
    bool? isRecording,
    bool? isPaused,
    String? unitId,
    String? unitTitle,
    String? audioPath,
    DateTime? startedAt,
    int? elapsedSeconds,
  }) {
    return RecordingStatus(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      unitId: unitId ?? this.unitId,
      unitTitle: unitTitle ?? this.unitTitle,
      audioPath: audioPath ?? this.audioPath,
      startedAt: startedAt ?? this.startedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

final recordingStatusProvider =
    StateNotifierProvider<RecordingStatusController, RecordingStatus>(
  (ref) => RecordingStatusController(),
);

class RecordingStatusController extends StateNotifier<RecordingStatus> {
  RecordingStatusController() : super(const RecordingStatus());

  void start({
    required String unitId,
    required String unitTitle,
    required String audioPath,
  }) {
    state = RecordingStatus(
      isRecording: true,
      isPaused: false,
      unitId: unitId,
      unitTitle: unitTitle,
      audioPath: audioPath,
      startedAt: DateTime.now(),
      elapsedSeconds: 0,
    );
  }

  void pause() {
    if (!state.isRecording || state.isPaused) return;
    state = state.copyWith(
      isPaused: true,
      elapsedSeconds: state.currentElapsedSeconds(),
      startedAt: null,
    );
  }

  void resume() {
    if (!state.isRecording || !state.isPaused) return;
    state = state.copyWith(
      isPaused: false,
      startedAt: DateTime.now(),
    );
  }

  void stop() {
    state = const RecordingStatus();
  }
}
