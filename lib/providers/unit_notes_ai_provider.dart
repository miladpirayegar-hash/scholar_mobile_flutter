import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

final unitNotesAiProvider =
    StateNotifierProvider<UnitNotesAiController, Map<String, Set<String>>>(
  (ref) => UnitNotesAiController(ref),
);

class UnitNotesAiController extends StateNotifier<Map<String, Set<String>>> {
  UnitNotesAiController(this.ref) : super(const {}) {
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
        .collection('unit_notes_ai')
        .snapshots()
        .listen((snap) {
      final next = <String, Set<String>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final raw = data['dismissed'] as List<dynamic>? ?? const [];
        next[doc.id] = raw.map((e) => e.toString()).toSet();
      }
      state = next;
    });
  }

  Set<String> _set(String unitId) => state[unitId] ?? const {};

  void dismiss(String unitId, String key) {
    final next = {..._set(unitId), key};
    state = {
      ...state,
      unitId: next,
    };
    unawaited(_persist(unitId, next));
  }

  Future<void> _persist(String unitId, Set<String> dismissed) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('unit_notes_ai')
        .doc(unitId)
        .set({'dismissed': dismissed.toList()});
  }
}
