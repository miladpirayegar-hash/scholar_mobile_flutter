// lib/providers/sessions_provider.dart
// ✅ YES — this is the ONLY sessions provider you should have.
// Delete any other sessionsProvider definitions.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/api/api_providers.dart';
import 'auth_provider.dart';
import 'user_prefs_provider.dart';

class SessionsNotifier extends StateNotifier<List<Session>> {
  SessionsNotifier(this.ref) : super(const []) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        state = const <Session>[];
        _unitMap = const {};
        _bindUnitMap();
        if (next.userId != null) {
          _load();
        }
      }
    });
    _load();
  }

  final Ref ref;
  static const _unitMapKey = 'session_unit_map_v1';
  static const _ownedKey = 'owned_sessions_v1';
  Map<String, String> _unitMap = const {};
  Set<String> _ownedIds = const {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _unitMapSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _ownedSub;

  Future<void> _load() async {
    await _loadUnitMap();
    final api = ref.read(apiServiceProvider);
    final sessions = await api.fetchSessions();
    state = _filterOwned(_applyUnitMap(sessions));
  }

  Future<void> refresh() async {
    final api = ref.read(apiServiceProvider);
    final sessions = await api.fetchSessions();
    state = _filterOwned(_applyUnitMap(sessions));
  }

  void addLocalSession(Session session) {
    state = [session, ...state];
  }

  void updateSession(Session updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
  }

  void updateSessionTitle({
    required String sessionId,
    required String title,
  }) {
    final t = title.trim();
    if (t.isEmpty) return;
    state = [
      for (final s in state)
        if (s.id == sessionId)
          Session(
            id: s.id,
            title: t,
            createdAt: s.createdAt,
            durationSec: s.durationSec,
            status: s.status,
            eventId: s.eventId,
            transcript: s.transcript,
            transcriptSegments: s.transcriptSegments,
            insights: s.insights,
          )
        else
          s,
    ];
  }

  void removeSession(String sessionId) {
    if (_unitMap.containsKey(sessionId)) {
      final next = {..._unitMap};
      next.remove(sessionId);
      _unitMap = next;
      _persistUnitMap();
    }
    if (_ownedIds.contains(sessionId)) {
      final nextOwned = {..._ownedIds};
      nextOwned.remove(sessionId);
      _ownedIds = nextOwned;
      _persistOwnedIds();
    }
    state = state.where((s) => s.id != sessionId).toList();
  }

  void unassignUnit(String unitId) {
    state = [
      for (final s in state)
        if (s.eventId == unitId)
          Session(
            id: s.id,
            title: s.title,
            createdAt: s.createdAt,
            durationSec: s.durationSec,
            status: s.status,
            eventId: null,
            transcript: s.transcript,
            transcriptSegments: s.transcriptSegments,
            insights: s.insights,
          )
        else
          s,
    ];
    final next = <String, String>{};
    _unitMap.forEach((key, value) {
      if (value != unitId) next[key] = value;
    });
    _unitMap = next;
    _persistUnitMap();
  }

  void assignSessionToUnit({
    required String sessionId,
    required String unitId,
  }) {
    _unitMap = {..._unitMap, sessionId: unitId};
    _persistUnitMap();
    state = [
      for (final s in state)
        if (s.id == sessionId)
          Session(
            id: s.id,
            title: s.title,
            createdAt: s.createdAt,
            durationSec: s.durationSec,
            status: s.status,
            eventId: unitId,
            transcript: s.transcript,
            transcriptSegments: s.transcriptSegments,
            insights: s.insights,
          )
        else
          s,
    ];
  }

  Future<void> clearLocalCache() async {
    _unitMap = const {};
    await _persistUnitMap();
    await ref
        .read(userPrefsProvider.notifier)
        .setHasRecordedSession(false);
    state = const <Session>[];
  }

  Future<void> _loadUnitMap() async {
    _bindUnitMap();
  }

  Future<void> _persistUnitMap() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc(_unitMapKey)
        .set({'map': _unitMap}, SetOptions(merge: true));
  }

  void _bindUnitMap() {
    _unitMapSub?.cancel();
    _ownedSub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      _unitMap = const {};
      _ownedIds = const {};
      return;
    }
    _unitMapSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc(_unitMapKey)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      final raw = data?['map'];
      if (raw is Map) {
        _unitMap = raw.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      } else {
        _unitMap = const {};
      }
      if (_unitMap.isNotEmpty) {
        _ownedIds = {..._ownedIds, ..._unitMap.keys};
        _persistOwnedIds();
      }
      state = _applyUnitMap(state);
    });
    _ownedSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc(_ownedKey)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      final raw = data?['ids'];
      if (raw is List) {
        _ownedIds = raw.map((e) => e.toString()).toSet();
      } else {
        _ownedIds = const {};
      }
      state = _filterOwned(state);
    });
  }

  List<Session> _applyUnitMap(List<Session> sessions) {
    if (_unitMap.isEmpty) return sessions;
    return [
      for (final s in sessions)
        _unitMap.containsKey(s.id)
            ? Session(
                id: s.id,
                title: s.title,
                createdAt: s.createdAt,
                durationSec: s.durationSec,
                status: s.status,
                eventId: _unitMap[s.id],
                transcript: s.transcript,
                transcriptSegments: s.transcriptSegments,
                insights: s.insights,
              )
            : s,
    ];
  }

  List<Session> _filterOwned(List<Session> sessions) {
    if (_ownedIds.isEmpty) return const <Session>[];
    return sessions.where((s) => _ownedIds.contains(s.id)).toList();
  }

  Future<void> _persistOwnedIds() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc(_ownedKey)
        .set({'ids': _ownedIds.toList()}, SetOptions(merge: true));
  }

  Future<void> registerOwnedSession(String sessionId) async {
    if (_ownedIds.contains(sessionId)) return;
    _ownedIds = {..._ownedIds, sessionId};
    await _persistOwnedIds();
    state = _filterOwned(state);
  }

  @override
  void dispose() {
    _unitMapSub?.cancel();
    _ownedSub?.cancel();
    super.dispose();
  }
}

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, List<Session>>(
  (ref) => SessionsNotifier(ref),
);
