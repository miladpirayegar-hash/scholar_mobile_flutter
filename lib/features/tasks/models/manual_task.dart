// lib/features/tasks/models/manual_task.dart
import 'dart:convert';

class ManualTask {
  final String id;
  final String? sessionId;
  final String text;
  final DateTime createdAt;

  const ManualTask({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.createdAt,
  });

  ManualTask copyWith({
    String? text,
    String? sessionId,
  }) {
    return ManualTask(
      id: id,
      sessionId: sessionId ?? this.sessionId,
      text: text ?? this.text,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ManualTask.fromJson(Map<String, dynamic> json) {
    return ManualTask(
      id: (json['id'] ?? '').toString(),
      sessionId: json['sessionId']?.toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  static String encodeList(List<ManualTask> tasks) =>
      jsonEncode(tasks.map((e) => e.toJson()).toList());

  static List<ManualTask> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ManualTask.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
