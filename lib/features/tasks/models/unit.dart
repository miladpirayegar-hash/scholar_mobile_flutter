// lib/models/unit.dart
class Unit {
  final String id;
  final String title;
  final DateTime createdAt;

  const Unit({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  Unit copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
  }) {
    return Unit(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled') as String,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
