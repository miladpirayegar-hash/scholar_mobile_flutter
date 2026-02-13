import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../services/api/api_providers.dart';
import '../../services/api/api_service.dart';
import '../../providers/sessions_provider.dart';
import '../../models/session.dart';

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, void>(
  SessionController.new,
);

class SessionController extends AsyncNotifier<void> {
  late final ApiService _api;

  @override
  Future<void> build() async {
    _api = ref.read(apiServiceProvider);
  }

  Future<void> uploadRecordingAndRefresh({
    required String audioPath,
    required String eventId, // kept for future backend support
    required DateTime recordedAt,
  }) async {
    state = const AsyncLoading();

    try {
      final audioBytes = await _readAudioBytes(audioPath);
      debugPrint(
        '[record] upload begin path="$audioPath" bytes=${audioBytes?.length ?? 0}',
      );
      // Backend currently ignores course context
      final uploadedSessionId = await _api.uploadSessionAudio(
        audioPath: kIsWeb ? null : audioPath,
        audioBytes: audioBytes,
        eventId: eventId,
      );
      debugPrint('[record] upload success id=$uploadedSessionId');
      await ref
          .read(sessionsProvider.notifier)
          .registerOwnedSession(uploadedSessionId);

      await ref.read(sessionsProvider.notifier).refresh();
      final latest =
          _assignSessionByIdToUnit(uploadedSessionId, eventId);
      if (latest != null) {
        await _pollForInsights(
          sessionId: uploadedSessionId,
          recordedAt: recordedAt,
        );
      } else {
        await _pollForUploadedSessionAndAssign(
          uploadedSessionId: uploadedSessionId,
          eventId: eventId,
          recordedAt: recordedAt,
        );
      }

      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('[record] upload failed: $e');
      debugPrint('$st');
      state = AsyncError(e, st);
    }
  }

  Future<Uint8List?> _readAudioBytes(String audioPath) async {
    if (audioPath.isEmpty) return null;
    if (!kIsWeb) return null;
    final uri = Uri.tryParse(audioPath);
    if (uri == null) return null;
    try {
      final response = await http.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Fall back to path upload mode if possible.
    }
    return null;
  }

  Session? _assignSessionByIdToUnit(String sessionId, String unitId) {
    final sessions = ref.read(sessionsProvider);
    final match = sessions.where((s) => s.id == sessionId).toList();
    if (match.isEmpty) return null;
    final session = match.first;
    ref.read(sessionsProvider.notifier).assignSessionToUnit(
          sessionId: session.id,
          unitId: unitId,
        );
    return session;
  }

  Future<void> _pollForUploadedSessionAndAssign({
    required String uploadedSessionId,
    required String eventId,
    required DateTime recordedAt,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 6));
      await ref.read(sessionsProvider.notifier).refresh();
      final assigned = _assignSessionByIdToUnit(uploadedSessionId, eventId);
      if (assigned != null) {
        await _pollForInsights(
          sessionId: uploadedSessionId,
          recordedAt: recordedAt,
        );
        return;
      }
    }
  }

  Future<void> _pollForInsights({
    required String sessionId,
    required DateTime recordedAt,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 6));
      await ref.read(sessionsProvider.notifier).refresh();
      final sessions = ref.read(sessionsProvider);
      final match = sessions.where((s) => s.id == sessionId).toList();
      if (match.isEmpty) continue;
      final session = match.first;
      if (session.isReady && session.hasInsights) {
        return;
      }
      final created =
          session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (created.isBefore(recordedAt.subtract(const Duration(minutes: 10)))) {
        return;
      }
    }
  }
}
