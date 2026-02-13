import 'package:flutter/foundation.dart';

@immutable
class StudyTask {
  final String id;
  final String sessionId;
  final String text;
  final DateTime createdAt;

  const StudyTask({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.createdAt,
  });

  static String buildId({
    required String sessionId,
    required int index,
    required String text,
  }) {
    final normalized = text.trim().toLowerCase();
    return '$sessionId-$index-${normalized.hashCode}';
  }
}
