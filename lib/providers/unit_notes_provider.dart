import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

class DatedItem {
  final String text;
  final DateTime? date;
  final String? notes;
  final String? priority;

  const DatedItem({
    required this.text,
    this.date,
    this.notes,
    this.priority,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'date': date?.toIso8601String(),
        'notes': notes,
        'priority': priority,
      };

  factory DatedItem.fromJson(Map<String, dynamic> json) {
    return DatedItem(
      text: json['text'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
      notes: json['notes'] as String?,
      priority: json['priority'] as String?,
    );
  }
}

class UnitNotes {
  final List<String> highlights;
  final List<DatedItem> exams;
  final List<DatedItem> assignments;

  const UnitNotes({
    this.highlights = const [],
    this.exams = const [],
    this.assignments = const [],
  });

  Map<String, dynamic> toJson() => {
        'highlights': highlights,
        'exams': exams.map((e) => e.toJson()).toList(),
        'assignments': assignments.map((a) => a.toJson()).toList(),
      };

  factory UnitNotes.fromJson(Map<String, dynamic> json) {
    final rawExams = (json['exams'] as List<dynamic>? ?? const []);
    final rawAssignments =
        (json['assignments'] as List<dynamic>? ?? const []);
    return UnitNotes(
      highlights:
          (json['highlights'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      exams: rawExams
          .map((e) => DatedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      assignments: rawAssignments
          .map((e) => DatedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

final unitNotesProvider =
    StateNotifierProvider<UnitNotesController, Map<String, UnitNotes>>(
  (ref) => UnitNotesController(ref),
);

class UnitNotesController extends StateNotifier<Map<String, UnitNotes>> {
  UnitNotesController(this.ref) : super(const {}) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      }
    });
    _bind();
  }

  final Ref ref;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  UnitNotes _notes(String unitId) => state[unitId] ?? const UnitNotes();

  void _bind() {
    _sub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      state = const {};
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('unit_notes')
        .snapshots()
        .listen((snap) {
      final next = <String, UnitNotes>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        next[doc.id] = UnitNotes.fromJson(data);
      }
      state = next;
    });
  }

  Future<void> _setNotes(String unitId, UnitNotes notes) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('unit_notes')
        .doc(unitId)
        .set(notes.toJson(), SetOptions(merge: true));
  }

  Future<void> clearAll() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('unit_notes');
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    state = const {};
  }

  void addHighlight(String unitId, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final notes = _notes(unitId);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: [...notes.highlights, t],
        exams: notes.exams,
        assignments: notes.assignments,
      ),
    ));
  }

  void addHighlights(String unitId, List<String> texts) {
    final cleaned = texts
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return;
    final notes = _notes(unitId);
    final next = {
      ...notes.highlights,
      ...cleaned,
    }.toList();
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: next,
        exams: notes.exams,
        assignments: notes.assignments,
      ),
    ));
  }

  void removeHighlight(String unitId, int index) {
    final notes = _notes(unitId);
    final next = [...notes.highlights]..removeAt(index);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: next,
        exams: notes.exams,
        assignments: notes.assignments,
      ),
    ));
  }

  void removeHighlightByValue(String unitId, String value) {
    final notes = _notes(unitId);
    final next = [...notes.highlights]..remove(value);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: next,
        exams: notes.exams,
        assignments: notes.assignments,
      ),
    ));
  }

  void updateHighlightByValue(
    String unitId,
    String oldValue,
    String newValue,
  ) {
    final t = newValue.trim();
    if (t.isEmpty) return;
    final notes = _notes(unitId);
    final next = [
      for (final h in notes.highlights)
        if (h == oldValue) t else h,
    ];
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: next,
        exams: notes.exams,
        assignments: notes.assignments,
      ),
    ));
  }

  void addExam(String unitId, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final notes = _notes(unitId);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: [...notes.exams, DatedItem(text: t)],
        assignments: notes.assignments,
      ),
    ));
  }

  void addExamWithDate(
    String unitId,
    String text,
    DateTime? date, {
    String? note,
    String? priority,
  }) {
    final t = text.trim();
    if (t.isEmpty) return;
    final notes = _notes(unitId);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: [
          ...notes.exams,
          DatedItem(text: t, date: date, notes: note, priority: priority),
        ],
        assignments: notes.assignments,
      ),
    ));
  }

  void removeExam(String unitId, int index) {
    final notes = _notes(unitId);
    final next = [...notes.exams]..removeAt(index);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: next,
        assignments: notes.assignments,
      ),
    ));
  }

  void removeExamByValue(String unitId, DatedItem item) {
    final notes = _notes(unitId);
    final next = [...notes.exams]
      ..removeWhere((e) => e.text == item.text && e.date == item.date);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: next,
        assignments: notes.assignments,
      ),
    ));
  }

  void updateExamByValue(String unitId, DatedItem oldItem, DatedItem nextItem) {
    final notes = _notes(unitId);
    final next = [
      for (final e in notes.exams)
        if (e.text == oldItem.text && e.date == oldItem.date)
          nextItem
        else
          e,
    ];
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: next,
        assignments: notes.assignments,
      ),
    ));
  }

  void addAssignment(String unitId, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final notes = _notes(unitId);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: notes.exams,
        assignments: [...notes.assignments, DatedItem(text: t)],
      ),
    ));
  }

  void addAssignmentWithDate(
    String unitId,
    String text,
    DateTime? date, {
    String? note,
    String? priority,
  }) {
    final t = text.trim();
    if (t.isEmpty) return;
    final notes = _notes(unitId);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: notes.exams,
        assignments: [
          ...notes.assignments,
          DatedItem(text: t, date: date, notes: note, priority: priority),
        ],
      ),
    ));
  }

  void removeAssignment(String unitId, int index) {
    final notes = _notes(unitId);
    final next = [...notes.assignments]..removeAt(index);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: notes.exams,
        assignments: next,
      ),
    ));
  }

  void removeAssignmentByValue(String unitId, DatedItem item) {
    final notes = _notes(unitId);
    final next = [...notes.assignments]
      ..removeWhere((e) => e.text == item.text && e.date == item.date);
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: notes.exams,
        assignments: next,
      ),
    ));
  }

  void updateAssignmentByValue(
    String unitId,
    DatedItem oldItem,
    DatedItem nextItem,
  ) {
    final notes = _notes(unitId);
    final next = [
      for (final a in notes.assignments)
        if (a.text == oldItem.text && a.date == oldItem.date)
          nextItem
        else
          a,
    ];
    unawaited(_setNotes(
      unitId,
      UnitNotes(
        highlights: notes.highlights,
        exams: notes.exams,
        assignments: next,
      ),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
