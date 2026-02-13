// lib/providers/tasks_providers.dart
// FINAL, SELF-CONTAINED, COMPILABLE
// - Defines StudyTask
// - Imports ManualTask from correct path
// - No missing URIs
// - No undefined symbols
// - Compatible with sessionsProvider = StateNotifierProvider<List<Session>>

import 'dart:convert';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';
import '../features/tasks/models/manual_task.dart';
import 'sessions_provider.dart';
import 'session_overrides_provider.dart';
import 'auth_provider.dart';

/// -------------------------------
/// StudyTask (AI-generated tasks)
/// -------------------------------
class StudyTask {
  final String id;
  final String sessionId;
  final String text;
  final DateTime createdAt;

  const StudyTask({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.createdAt,
  });

  static String buildId({
    required String sessionId,
    required int index,
    required String text,
  }) {
    return '$sessionId::$index::${text.hashCode}';
  }
}

/// ----------------------------------------------------
/// Tasks provider (AI + manual tasks merged)
/// ----------------------------------------------------
final tasksProvider = Provider<List<dynamic>>((ref) {
  final List<Session> sessions = ref.watch(sessionsProvider);
  final overrides = ref.watch(sessionOverridesProvider);
  final List<ManualTask> manual = ref.watch(manualTasksProvider);

  final List<dynamic> tasks = [];

  // AI-generated tasks from session insights
  for (final session in sessions) {
    final override = overrides[session.id];
    final List<String> actionItemsOverride =
        override?.actionItems ?? const [];

    final insights = session.insights;
    if (actionItemsOverride.isEmpty) {
      if (insights is! Map<String, dynamic>) continue;
    }

    final rawItems = actionItemsOverride.isNotEmpty
        ? actionItemsOverride
        : insights?['actionItems'];
    final actionItems = (rawItems is List)
        ? rawItems
            .map((e) {
              if (e is String) return e;
              if (e is Map<String, dynamic>) {
                final text = e['text'];
                if (text is String) return text;
              }
              return '';
            })
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    for (var i = 0; i < actionItems.length; i++) {
      final text = actionItems[i].trim();
      if (text.isEmpty) continue;

      tasks.add(
        StudyTask(
          id: StudyTask.buildId(
            sessionId: session.id,
            index: i,
            text: text,
          ),
          sessionId: session.id,
          text: text,
          createdAt: session.createdAt ?? DateTime.now(),
        ),
      );
    }
  }

  // Manual tasks
  tasks.addAll(manual);

  // Sort newest first
  tasks.sort((a, b) {
    final DateTime da = a.createdAt as DateTime;
    final DateTime db = b.createdAt as DateTime;
    return db.compareTo(da);
  });

  return tasks;
});

/// ----------------------------------------------------
/// Manual tasks provider
/// ----------------------------------------------------
final manualTasksProvider =
    StateNotifierProvider<ManualTasksController, List<ManualTask>>(
  (ref) => ManualTasksController(ref),
);

class ManualTasksController extends StateNotifier<List<ManualTask>> {
  static const _storageKey = 'manual_tasks_v1';

  ManualTasksController(this.ref) : super(const []) {
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
      state = const [];
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('manual_tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      state = [
        for (final doc in snap.docs)
          ManualTask.fromJson({
            ...doc.data(),
            'id': doc.id,
          }),
      ];
    });
    unawaited(_migrateFromPrefs(uid));
  }

  Future<void> clearAll() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('manual_tasks');
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    state = const [];
  }

  ManualTask addWithReturn({
    required String text,
    String? sessionId,
  }) {
    final t = text.trim();
    if (t.isEmpty) {
      return ManualTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: sessionId,
        text: '',
        createdAt: DateTime.now(),
      );
    }

    final task = ManualTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: sessionId,
      text: t,
      createdAt: DateTime.now(),
    );

    final uid = ref.read(authProvider).userId;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('manual_tasks')
          .doc(task.id)
          .set(task.toJson());
    }
    return task;
  }

  void add({
    required String text,
    String? sessionId,
  }) {
    addWithReturn(text: text, sessionId: sessionId);
  }

  void update({
    required String id,
    required String text,
    String? sessionId,
  }) {
    final t = text.trim();
    if (t.isEmpty) return;

    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('manual_tasks')
        .doc(id)
        .update({
      'text': t,
      'sessionId': sessionId,
    });
  }

  void remove(String id) {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('manual_tasks')
        .doc(id)
        .delete();
  }

  Future<void> _migrateFromPrefs(String uid) async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('manual_tasks');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final e in decoded) {
        final task = ManualTask.fromJson(
          Map<String, dynamic>.from(e as Map),
        );
        await col.doc(task.id).set(task.toJson());
      }
      await prefs.remove(_storageKey);
    } catch (_) {
      // ignore corrupted storage
    }
  }
}

/// ----------------------------------------------------
/// Completion state
/// ----------------------------------------------------
final completedTasksProvider =
    StateNotifierProvider<CompletedTasksController, Set<String>>(
  (ref) => CompletedTasksController(ref),
);

class CompletedTasksController extends StateNotifier<Set<String>> {
  CompletedTasksController(this.ref) : super(const {}) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      }
    });
    _bind();
  }

  final Ref ref;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  static const _storageKeyPrefix = 'completed_tasks_v1_';
  final Map<String, bool> _pending = {};

  DocumentReference<Map<String, dynamic>> _docFor(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('completed_tasks');
  }

  void _bind() {
    _sub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      _loadFromPrefs('anon');
      return;
    }
    _loadFromPrefs(uid);
    _sub = _docFor(uid).snapshots().listen((snap) {
      final data = snap.data();
      final raw = data?['ids'];
      if (raw is List) {
        final rawSet = raw.map((e) => e.toString()).toSet();
        final toClear = <String>[];
        _pending.forEach((id, desired) {
          final matches = desired ? rawSet.contains(id) : !rawSet.contains(id);
          if (matches) toClear.add(id);
        });
        for (final id in toClear) {
          _pending.remove(id);
        }
        final merged = Set<String>.from(rawSet);
        _pending.forEach((id, desired) {
          if (desired) {
            merged.add(id);
          } else {
            merged.remove(id);
          }
        });
        state = merged;
        _saveToPrefs(uid, state);
      }
    });
  }

  bool isCompleted(String taskId) => state.contains(taskId);

  void clearAll() {
    final uid = ref.read(authProvider).userId;
    if (uid != null) {
      _docFor(uid).delete();
      _clearPrefs(uid);
    } else {
      _clearPrefs('anon');
    }
    state = const {};
  }

  void toggle(String taskId) {
    final next = Set<String>.from(state);
    final bool desired;
    if (next.contains(taskId)) {
      next.remove(taskId);
      desired = false;
    } else {
      next.add(taskId);
      desired = true;
    }
    _pending[taskId] = desired;
    state = next;
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      _saveToPrefs('anon', next);
      return;
    }
    _saveToPrefs(uid, next);
    _docFor(uid).set({'ids': next.toList()}, SetOptions(merge: true));
  }

  Future<void> _loadFromPrefs(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storageKeyPrefix$key');
    if (raw == null || raw.isEmpty) {
      state = const {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded.map((e) => e.toString()).toSet();
    } catch (_) {
      state = const {};
    }
  }

  Future<void> _saveToPrefs(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_storageKeyPrefix$key',
      jsonEncode(ids.toList()),
    );
  }

  Future<void> _clearPrefs(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_storageKeyPrefix$key');
  }
}
