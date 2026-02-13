import 'dart:convert';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

final notificationReadProvider =
    StateNotifierProvider<NotificationReadController, Set<String>>(
  (ref) => NotificationReadController(ref),
);

class NotificationReadController extends StateNotifier<Set<String>> {
  static const _storageKey = 'notification_read_v1';

  NotificationReadController(this.ref) : super(const {}) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      }
    });
    _bind();
  }

  final Ref ref;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  DocumentReference<Map<String, dynamic>> _docFor(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('notification_read');
  }

  void _bind() {
    _sub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      state = const {};
      return;
    }
    _sub = _docFor(uid).snapshots().listen((snap) {
      final data = snap.data();
      final raw = data?['ids'];
      if (raw is List) {
        state = raw.map((e) => e.toString()).toSet();
      } else {
        state = const {};
      }
    });
    unawaited(_migrateFromPrefs(uid));
  }

  void markRead(String id) {
    if (state.contains(id)) return;
    final next = {...state, id};
    state = next;
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    _docFor(uid).set({'ids': next.toList()}, SetOptions(merge: true));
  }

  bool isRead(String id) => state.contains(id);

  Future<void> clearAll() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await _docFor(uid).delete();
    state = const {};
  }

  Future<void> _migrateFromPrefs(String uid) async {
    final doc = await _docFor(uid).get();
    if (doc.exists && (doc.data() ?? {}).isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final ids = decoded.map((e) => e.toString()).toList();
      await _docFor(uid).set({'ids': ids}, SetOptions(merge: true));
      await prefs.remove(_storageKey);
    } catch (_) {
      // ignore corrupted storage
    }
  }
}
