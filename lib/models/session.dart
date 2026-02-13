import 'session_insights.dart';

class Session {
  final String id;
  final String title;
  final DateTime? createdAt;
  final int durationSec;
  final String status;
  final String? eventId;

  // Detail data
  final String? transcript;
  final List<dynamic>? transcriptSegments;

  // Raw insights payload from backend
  final Map<String, dynamic>? insights;

  Session({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.durationSec,
    required this.status,
    required this.eventId,
    this.transcript,
    this.transcriptSegments,
    this.insights,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: (json['id'] as String),
      title: (json['title'] ?? '') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      durationSec: (json['durationSec'] ?? 0) as int,
      status: (json['status'] ?? 'processing') as String,
      eventId: json['eventId'] as String?,

      transcript: json['transcript'] as String?,
      transcriptSegments: json['transcriptSegments'] as List<dynamic>?,
      insights: json['insights'] as Map<String, dynamic>?,
    );
  }

  // -----------------------------
  // Parsed insights (UI-friendly)
  // -----------------------------
  SessionInsights? get parsedInsights {
    if (insights == null) return null;
    return SessionInsights.fromJson(insights!);
  }

  // -----------------------------
  // Convenience helpers
  // -----------------------------
  bool get isReady => status.toLowerCase() == 'ready';

  bool get hasTranscript => transcript != null && transcript!.trim().isNotEmpty;

  bool get hasInsights => insights != null && insights!.isNotEmpty;
}
