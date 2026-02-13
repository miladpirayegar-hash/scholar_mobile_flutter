import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_insights.dart';
import 'auth_provider.dart';

class SessionOverride {
  final String? transcript;
  final String? summary;
  final List<String>? keyConcepts;
  final List<String>? actionItems;
  final List<Flashcard>? flashcards;

  const SessionOverride({
    this.transcript,
    this.summary,
    this.keyConcepts,
    this.actionItems,
    this.flashcards,
  });

  bool get hasAny =>
      transcript != null ||
      summary != null ||
      keyConcepts != null ||
      actionItems != null ||
      flashcards != null;
}

final sessionOverridesProvider =
    StateNotifierProvider<SessionOverridesController, Map<String, SessionOverride>>(
  (ref) => SessionOverridesController(ref),
);

class SessionOverridesController
    extends StateNotifier<Map<String, SessionOverride>> {
  SessionOverridesController(this.ref) : super(const {}) {
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
        .collection('session_overrides')
        .snapshots()
        .listen((snap) {
      final next = <String, SessionOverride>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        next[doc.id] = _fromJson(data);
      }
      state = next;
    });
  }

  void setTranscript(String sessionId, String transcript) {
    final current = state[sessionId];
    final next = SessionOverride(
      transcript: transcript,
      summary: current?.summary,
      keyConcepts: current?.keyConcepts,
      actionItems: current?.actionItems,
      flashcards: current?.flashcards,
    );
    state = {...state, sessionId: next};
    _persist(sessionId, next);
  }

  void setInsights({
    required String sessionId,
    String? summary,
    List<String>? keyConcepts,
    List<String>? actionItems,
    List<Flashcard>? flashcards,
  }) {
    final current = state[sessionId];
    final next = SessionOverride(
      transcript: current?.transcript,
      summary: summary ?? current?.summary,
      keyConcepts: keyConcepts ?? current?.keyConcepts,
      actionItems: actionItems ?? current?.actionItems,
      flashcards: flashcards ?? current?.flashcards,
    );
    state = {...state, sessionId: next};
    _persist(sessionId, next);
  }

  void clear(String sessionId) {
    final next = {...state};
    next.remove(sessionId);
    state = next;
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('session_overrides')
        .doc(sessionId)
        .delete();
  }

  void clearAll() {
    state = const {};
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('session_overrides')
        .get()
        .then((snap) async {
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    });
  }

  void _persist(String sessionId, SessionOverride override) {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('session_overrides')
        .doc(sessionId)
        .set(_toJson(override), SetOptions(merge: true));
  }

  Map<String, dynamic> _toJson(SessionOverride override) => {
        'transcript': override.transcript,
        'summary': override.summary,
        'keyConcepts': override.keyConcepts,
        'actionItems': override.actionItems,
        'flashcards': override.flashcards
            ?.map((f) => {'question': f.question, 'answer': f.answer})
            .toList(),
      };

  SessionOverride _fromJson(Map<String, dynamic> json) {
    final rawFlashcards = json['flashcards'] as List<dynamic>? ?? const [];
    return SessionOverride(
      transcript: json['transcript'] as String?,
      summary: json['summary'] as String?,
      keyConcepts:
          (json['keyConcepts'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      actionItems:
          (json['actionItems'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      flashcards: rawFlashcards
          .map((e) => Flashcard.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}
