import 'dart:convert';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

class DeckCard {
  final String id;
  final String sessionId;
  final String question;
  final String answer;
  final DateTime createdAt;

  const DeckCard({
    required this.id,
    required this.sessionId,
    required this.question,
    required this.answer,
    required this.createdAt,
  });

  factory DeckCard.fromJson(Map<String, dynamic> json) {
    return DeckCard(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'question': question,
        'answer': answer,
        'createdAt': createdAt.toIso8601String(),
      };
}

final flashcardDeckProvider =
    StateNotifierProvider<FlashcardDeckController, List<DeckCard>>(
  (ref) => FlashcardDeckController(ref),
);

class FlashcardDeckController extends StateNotifier<List<DeckCard>> {
  static const _storageKey = 'flashcard_deck_v1';

  FlashcardDeckController(this.ref) : super(const []) {
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
        .collection('flashcards')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      state = [
        for (final doc in snap.docs)
          DeckCard.fromJson({
            ...doc.data(),
            'id': doc.id,
          }),
      ];
    });
    unawaited(_migrateFromPrefs(uid));
  }

  bool contains(String id) => state.any((c) => c.id == id);

  void add(DeckCard card) {
    if (contains(card.id)) return;
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('flashcards')
        .doc(card.id)
        .set(card.toJson());
  }

  void remove(String id) {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('flashcards')
        .doc(id)
        .delete();
  }

  Future<void> clearAll() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('flashcards');
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    state = const [];
  }

  Future<void> _migrateFromPrefs(String uid) async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('flashcards');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final e in decoded) {
        final card = DeckCard.fromJson(
          Map<String, dynamic>.from(e as Map),
        );
        await col.doc(card.id).set(card.toJson());
      }
      await prefs.remove(_storageKey);
    } catch (_) {
      // ignore corrupted storage
    }
  }
}
