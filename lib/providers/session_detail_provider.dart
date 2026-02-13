import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session.dart';
import '../services/api/api_providers.dart';

final sessionDetailProvider =
    StreamProvider.family<Session, String>((ref, sessionId) async* {
  final api = ref.read(apiServiceProvider);

  yield await api.fetchSessionById(sessionId);

  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    yield await api.fetchSessionById(sessionId);
  }
});
