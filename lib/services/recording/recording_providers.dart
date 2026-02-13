import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'recording_service.dart';

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = RecordingService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
