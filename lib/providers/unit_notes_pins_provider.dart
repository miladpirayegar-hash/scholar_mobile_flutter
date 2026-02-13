import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'unit_notes_provider.dart';

class UnitNotesPins {
  final Set<String> highlights;
  final Set<String> exams;
  final Set<String> assignments;

  const UnitNotesPins({
    this.highlights = const {},
    this.exams = const {},
    this.assignments = const {},
  });
}

final unitNotesPinsProvider =
    StateNotifierProvider<UnitNotesPinsController, Map<String, UnitNotesPins>>(
  (ref) => UnitNotesPinsController(ref),
);

class UnitNotesPinsController extends StateNotifier<Map<String, UnitNotesPins>> {
  UnitNotesPinsController(this.ref) : super(const {}) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      }
    });
    _bind();
  }

  final Ref ref;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

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
        .collection('unit_notes_pins')
        .snapshots()
        .listen((snap) {
      final next = <String, UnitNotesPins>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        next[doc.id] = UnitNotesPins(
          highlights: (data['highlights'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toSet(),
          exams: (data['exams'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toSet(),
          assignments:
              (data['assignments'] as List<dynamic>? ?? const [])
                  .map((e) => e.toString())
                  .toSet(),
        );
      }
      state = next;
    });
  }

  UnitNotesPins _pins(String unitId) => state[unitId] ?? const UnitNotesPins();

  void toggleHighlight(String unitId, String text) {
    final current = _pins(unitId);
    final next = {...current.highlights};
    if (!next.remove(text)) {
      next.add(text);
    }
    final updated = UnitNotesPins(
      highlights: next,
      exams: current.exams,
      assignments: current.assignments,
    );
    state = {...state, unitId: updated};
    unawaited(_persist(unitId, updated));
  }

  void toggleExam(String unitId, DatedItem item) {
    _toggleDated(
      unitId: unitId,
      item: item,
      getSet: (p) => p.exams,
      build: (p, next) => UnitNotesPins(
        highlights: p.highlights,
        exams: next,
        assignments: p.assignments,
      ),
    );
  }

  void toggleAssignment(String unitId, DatedItem item) {
    _toggleDated(
      unitId: unitId,
      item: item,
      getSet: (p) => p.assignments,
      build: (p, next) => UnitNotesPins(
        highlights: p.highlights,
        exams: p.exams,
        assignments: next,
      ),
    );
  }

  void _toggleDated({
    required String unitId,
    required DatedItem item,
    required Set<String> Function(UnitNotesPins) getSet,
    required UnitNotesPins Function(UnitNotesPins, Set<String>) build,
  }) {
    final current = _pins(unitId);
    final key = _datedKey(item);
    final next = {...getSet(current)};
    if (!next.remove(key)) {
      next.add(key);
    }
    state = {
      ...state,
      unitId: build(current, next),
    };
    unawaited(_persist(unitId, state[unitId]!));
  }

  static String datedKey(DatedItem item) => _datedKey(item);

  static String _datedKey(DatedItem item) =>
      '${item.text}::${item.date?.toIso8601String() ?? ''}';

  Future<void> _persist(String unitId, UnitNotesPins pins) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('unit_notes_pins')
        .doc(unitId)
        .set({
      'highlights': pins.highlights.toList(),
      'exams': pins.exams.toList(),
      'assignments': pins.assignments.toList(),
    });
  }
}
