import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'unit_notes_provider.dart';

class OutlinePending {
  final List<DatedItem> exams;
  final List<DatedItem> assignments;

  const OutlinePending({
    this.exams = const [],
    this.assignments = const [],
  });
}

final outlinePendingProvider =
    StateNotifierProvider<OutlinePendingController, Map<String, OutlinePending>>(
  (ref) => OutlinePendingController(ref),
);

class OutlinePendingController
    extends StateNotifier<Map<String, OutlinePending>> {
  OutlinePendingController(this.ref) : super(const {}) {
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
        .collection('outline_pending')
        .snapshots()
        .listen((snap) {
      final next = <String, OutlinePending>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final exams = (data['exams'] as List<dynamic>? ?? const [])
            .map((e) => DatedItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final assignments =
            (data['assignments'] as List<dynamic>? ?? const [])
                .map((e) =>
                    DatedItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
        next[doc.id] = OutlinePending(
          exams: exams,
          assignments: assignments,
        );
      }
      state = next;
    });
  }

  OutlinePending _get(String unitId) => state[unitId] ?? const OutlinePending();

  Future<void> _set(String unitId, OutlinePending next) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('outline_pending')
        .doc(unitId)
        .set({
      'exams': next.exams.map((e) => e.toJson()).toList(),
      'assignments': next.assignments.map((e) => e.toJson()).toList(),
    });
  }

  void addPending({
    required String unitId,
    List<DatedItem> exams = const [],
    List<DatedItem> assignments = const [],
  }) {
    final current = _get(unitId);
    final next = OutlinePending(
      exams: [...current.exams, ...exams],
      assignments: [...current.assignments, ...assignments],
    );
    state = {...state, unitId: next};
    unawaited(_set(unitId, next));
  }

  void removePendingExam(String unitId, DatedItem item) {
    final current = _get(unitId);
    final next = [...current.exams]
      ..removeWhere((e) => e.text == item.text && e.date == item.date);
    final updated = OutlinePending(
      exams: next,
      assignments: current.assignments,
    );
    state = {...state, unitId: updated};
    unawaited(_set(unitId, updated));
  }

  void updatePendingExam(String unitId, DatedItem oldItem, DatedItem nextItem) {
    final current = _get(unitId);
    final next = [
      for (final e in current.exams)
        if (e.text == oldItem.text && e.date == oldItem.date)
          nextItem
        else
          e,
    ];
    final updated = OutlinePending(
      exams: next,
      assignments: current.assignments,
    );
    state = {...state, unitId: updated};
    unawaited(_set(unitId, updated));
  }

  void removePendingAssignment(String unitId, DatedItem item) {
    final current = _get(unitId);
    final next = [...current.assignments]
      ..removeWhere((e) => e.text == item.text && e.date == item.date);
    final updated = OutlinePending(
      exams: current.exams,
      assignments: next,
    );
    state = {...state, unitId: updated};
    unawaited(_set(unitId, updated));
  }

  void updatePendingAssignment(
    String unitId,
    DatedItem oldItem,
    DatedItem nextItem,
  ) {
    final current = _get(unitId);
    final next = [
      for (final a in current.assignments)
        if (a.text == oldItem.text && a.date == oldItem.date)
          nextItem
        else
          a,
    ];
    final updated = OutlinePending(
      exams: current.exams,
      assignments: next,
    );
    state = {...state, unitId: updated};
    unawaited(_set(unitId, updated));
  }

  void clearAll() {
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      state = const {};
      return;
    }
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('outline_pending')
        .get()
        .then((snap) async {
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    });
    state = const {};
  }
}
