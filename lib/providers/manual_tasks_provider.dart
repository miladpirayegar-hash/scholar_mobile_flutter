// lib/features/tasks/models/manual_task.dart
// REQUIRED MODEL — fixes all ManualTask-related errors

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ManualTask.fromJson(Map<String, dynamic> json) {
    return ManualTask(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String?,
      text: json['text'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String) ??
          DateTime.now(),
    );
  }
}
