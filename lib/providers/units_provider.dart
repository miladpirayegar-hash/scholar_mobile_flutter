import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/unit.dart';
import 'auth_provider.dart';

final unitsProvider =
    StateNotifierProvider<UnitsController, List<Unit>>(
  (ref) => UnitsController(ref),
);

class UnitsController extends StateNotifier<List<Unit>> {
  UnitsController(this.ref) : super(const []) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      }
    });
    _bind();
  }

  final Ref ref;
  final _uuid = const Uuid();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _bind() {
    _sub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      state = const [];
      return;
    }

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('units')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snap) {
      state = [
        for (final doc in snap.docs) _fromDoc(doc),
      ];
    });
  }

  Unit _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final createdAt = data['createdAt'];
    DateTime createdAtValue = DateTime.now();
    if (createdAt is Timestamp) {
      createdAtValue = createdAt.toDate();
    } else if (createdAt is String) {
      createdAtValue = DateTime.tryParse(createdAt) ?? DateTime.now();
    }
    return Unit(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      createdAt: createdAtValue,
    );
  }

  Unit createUnit(String title) {
    final t = title.trim();
    if (t.isEmpty) {
      return Unit(id: '', title: '', createdAt: DateTime.now());
    }
    final unit = Unit(
      id: _uuid.v4(),
      title: t,
      createdAt: DateTime.now(),
    );

    final uid = ref.read(authProvider).userId;
    if (uid == null) return unit;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('units')
        .doc(unit.id)
        .set({
      'title': unit.title,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return unit;
  }

  void updateUnitTitle({
    required String unitId,
    required String title,
  }) {
    final t = title.trim();
    if (t.isEmpty) return;
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('units')
        .doc(unitId)
        .update({'title': t});
  }

  void removeUnit(String unitId) {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(uid);
    userDoc.collection('units').doc(unitId).delete();
    userDoc.collection('unit_notes').doc(unitId).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
