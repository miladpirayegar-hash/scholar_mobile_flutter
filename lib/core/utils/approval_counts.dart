import '../../models/session.dart';
import '../../providers/unit_notes_provider.dart';
import '../../providers/outline_pending_provider.dart';

class ApprovalCounts {
  final int highlights;
  final int exams;
  final int assignments;

  const ApprovalCounts({
    required this.highlights,
    required this.exams,
    required this.assignments,
  });

  int get total => highlights + exams + assignments;
}

ApprovalCounts computeApprovalCounts({
  required List<Session> sessions,
  required Map<String, UnitNotes> unitNotes,
  required Map<String, Set<String>> dismissedByUnit,
  required Map<String, OutlinePending> pendingByUnit,
}) {
  var highlights = 0;
  var exams = 0;
  var assignments = 0;

  for (final entry in pendingByUnit.entries) {
    exams += entry.value.exams.length;
    assignments += entry.value.assignments.length;
  }

  final sessionsByUnit = <String, List<Session>>{};
  for (final s in sessions) {
    final unitId =
        (s.eventId == null || s.eventId!.isEmpty) ? 'general' : s.eventId!;
    sessionsByUnit.putIfAbsent(unitId, () => []).add(s);
  }

  for (final entry in sessionsByUnit.entries) {
    final unitId = entry.key;
    final notes = unitNotes[unitId] ?? const UnitNotes();
    final dismissed = dismissedByUnit[unitId] ?? const <String>{};

    final suggestions = <_Suggestion>[];
    for (final s in entry.value) {
      final insights = s.insights;
      if (insights == null || insights.isEmpty) continue;
      suggestions.addAll(
        _parseSuggestionList(
          insights['highlights'] ?? insights['subjectHighlights'],
          _SuggestionType.highlight,
        ),
      );
      suggestions.addAll(
        _parseSuggestionList(
          insights['exams'] ?? insights['upcomingExams'],
          _SuggestionType.exam,
        ),
      );
      suggestions.addAll(
        _parseSuggestionList(
          insights['assignments'],
          _SuggestionType.assignment,
        ),
      );
    }

    final seen = <String>{};
    for (final s in suggestions) {
      final key = s.key;
      if (!seen.add(key)) continue;
      if (dismissed.contains(key)) continue;
      if (s.text.isEmpty) continue;
      switch (s.type) {
        case _SuggestionType.highlight:
          if (notes.highlights.contains(s.text)) continue;
          highlights += 1;
          break;
        case _SuggestionType.exam:
          if (_containsDated(notes.exams, s)) continue;
          exams += 1;
          break;
        case _SuggestionType.assignment:
          if (_containsDated(notes.assignments, s)) continue;
          assignments += 1;
          break;
      }
    }
  }

  return ApprovalCounts(
    highlights: highlights,
    exams: exams,
    assignments: assignments,
  );
}

bool _containsDated(List<DatedItem> items, _Suggestion s) {
  return items.any((e) => e.text == s.text && e.date == s.date);
}

enum _SuggestionType { highlight, exam, assignment }

class _Suggestion {
  final _SuggestionType type;
  final String text;
  final DateTime? date;

  const _Suggestion({
    required this.type,
    required this.text,
    this.date,
  });

  String get key => '${type.name}::$text::${date?.toIso8601String() ?? ''}';
}

List<_Suggestion> _parseSuggestionList(
  dynamic value,
  _SuggestionType type,
) {
  if (value is! List) return const [];
  return value
      .map((e) {
        if (e is String) {
          return _Suggestion(type: type, text: e.trim());
        }
        if (e is Map<String, dynamic>) {
          final rawText = e['text'] ?? e['title'] ?? e['name'];
          final rawDate = e['date'] ?? e['dueDate'];
          return _Suggestion(
            type: type,
            text: (rawText ?? '').toString().trim(),
            date: _parseDate(rawDate),
          );
        }
        return null;
      })
      .whereType<_Suggestion>()
      .where((s) => s.text.isNotEmpty)
      .toList();
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
