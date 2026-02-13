import 'dart:convert';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

class TaskMeta {
  final bool pinned;
  final String priority; // low | med | high
  final DateTime? dueDate;
  final String? overrideText;
  final String? notes;

  const TaskMeta({
    this.pinned = false,
    this.priority = 'med',
    this.dueDate,
    this.overrideText,
    this.notes,
  });

  TaskMeta copyWith({
    bool? pinned,
    String? priority,
    DateTime? dueDate,
    String? overrideText,
    String? notes,
  }) {
    return TaskMeta(
      pinned: pinned ?? this.pinned,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      overrideText: overrideText ?? this.overrideText,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'pinned': pinned,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
        'overrideText': overrideText,
        'notes': notes,
      };

  factory TaskMeta.fromJson(Map<String, dynamic> json) {
    return TaskMeta(
      pinned: json['pinned'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'med',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      overrideText: json['overrideText'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

final taskMetaProvider =
    StateNotifierProvider<TaskMetaController, Map<String, TaskMeta>>(
  (ref) => TaskMetaController(ref),
);

class TaskMetaController extends StateNotifier<Map<String, TaskMeta>> {
  static const _storageKey = 'task_meta_v1';

  TaskMetaController(this.ref) : super(const {}) {
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
        .collection('task_meta')
        .snapshots()
        .listen((snap) {
      final next = <String, TaskMeta>{};
      for (final doc in snap.docs) {
        next[doc.id] = TaskMeta.fromJson(doc.data());
      }
      state = next;
    });
    unawaited(_migrateFromPrefs(uid));
  }

  TaskMeta metaFor(String id) => state[id] ?? const TaskMeta();

  void setMeta(String id, TaskMeta meta) {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('task_meta')
        .doc(id)
        .set(meta.toJson());
  }

  void togglePin(String id) {
    final current = metaFor(id);
    setMeta(id, current.copyWith(pinned: !current.pinned));
  }

  Future<void> clearAll() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('task_meta');
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    state = const {};
  }

  Future<void> _migrateFromPrefs(String uid) async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('task_meta');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          await col.doc(entry.key).set(value);
        } else if (value is Map) {
          await col.doc(entry.key)
              .set(Map<String, dynamic>.from(value));
        }
      }
      await prefs.remove(_storageKey);
    } catch (_) {
      // ignore corrupted storage
    }
  }
}
