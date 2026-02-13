import 'dart:convert';

enum UploadStatus {
  pending,
  uploading,
  failed,
}

class PendingUpload {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final UploadStatus status;
  final String? errorMessage;

  const PendingUpload({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.status,
    this.errorMessage,
  });

  PendingUpload copyWith({
    UploadStatus? status,
    String? errorMessage,
  }) {
    return PendingUpload(
      id: id,
      filePath: filePath,
      createdAt: createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'errorMessage': errorMessage,
      };

  factory PendingUpload.fromJson(Map<String, dynamic> json) {
    return PendingUpload(
      id: json['id'],
      filePath: json['filePath'],
      createdAt: DateTime.parse(json['createdAt']),
      status: UploadStatus.values
          .firstWhere((e) => e.name == json['status']),
      errorMessage: json['errorMessage'],
    );
  }

  static String encodeList(List<PendingUpload> uploads) =>
      jsonEncode(uploads.map((e) => e.toJson()).toList());

  static List<PendingUpload> decodeList(String raw) =>
      (jsonDecode(raw) as List)
          .map((e) => PendingUpload.fromJson(e))
          .toList();
}
