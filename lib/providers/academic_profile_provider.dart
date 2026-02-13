import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

class AcademicProfile {
  final String university;
  final String fieldOfStudy;
  final String degreeLevel;
  final String yearTerm;
  final String studyGoals;

  const AcademicProfile({
    this.university = '',
    this.fieldOfStudy = '',
    this.degreeLevel = '',
    this.yearTerm = '',
    this.studyGoals = '',
  });

  bool get isComplete =>
      university.trim().isNotEmpty &&
      fieldOfStudy.trim().isNotEmpty &&
      degreeLevel.trim().isNotEmpty &&
      yearTerm.trim().isNotEmpty;

  AcademicProfile copyWith({
    String? university,
    String? fieldOfStudy,
    String? degreeLevel,
    String? yearTerm,
    String? studyGoals,
  }) {
    return AcademicProfile(
      university: university ?? this.university,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      degreeLevel: degreeLevel ?? this.degreeLevel,
      yearTerm: yearTerm ?? this.yearTerm,
      studyGoals: studyGoals ?? this.studyGoals,
    );
  }

  Map<String, dynamic> toJson() => {
        'university': university,
        'fieldOfStudy': fieldOfStudy,
        'degreeLevel': degreeLevel,
        'yearTerm': yearTerm,
        'studyGoals': studyGoals,
      };

  factory AcademicProfile.fromJson(Map<String, dynamic> json) {
    return AcademicProfile(
      university: json['university'] as String? ?? '',
      fieldOfStudy: json['fieldOfStudy'] as String? ?? '',
      degreeLevel: json['degreeLevel'] as String? ?? '',
      yearTerm: json['yearTerm'] as String? ?? '',
      studyGoals: json['studyGoals'] as String? ?? '',
    );
  }
}

final academicProfileProvider =
    StateNotifierProvider<AcademicProfileController, AcademicProfile>(
  (ref) => AcademicProfileController(ref),
);

class AcademicProfileController extends StateNotifier<AcademicProfile> {
  static const _legacyStorageKey = 'academic_profile_v1';
  static const _ownerKey = 'academic_profile_owner_uid';

  AcademicProfileController(this.ref) : super(const AcademicProfile()) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      } else if (prev?.isSignedIn == true && next.isSignedIn == false) {
        state = const AcademicProfile();
      }
    });
    _bind();
  }

  final Ref ref;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String _storageKeyFor(String uid) => 'academic_profile_v1_$uid';

  DocumentReference<Map<String, dynamic>> _docFor(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('academic');
  }

  void _bind() {
    _sub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null || uid.isEmpty) {
      state = const AcademicProfile();
      return;
    }
    _sub = _docFor(uid).snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      state = AcademicProfile.fromJson(data);
    });
    unawaited(_migrateFromPrefs(uid));
  }

  Future<void> _migrateFromPrefs(String uid) async {
    final doc = await _docFor(uid).get();
    if (doc.exists && (doc.data() ?? {}).isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKeyFor(uid));
    String? legacy;
    if (raw == null || raw.isEmpty) {
      legacy = prefs.getString(_legacyStorageKey);
    }
    final ownerUid = prefs.getString(_ownerKey);
    final useLegacy = legacy != null &&
        legacy.isNotEmpty &&
        (ownerUid == null || ownerUid == uid);

    if (raw == null || raw.isEmpty) {
      if (!useLegacy) return;
    }
    final source = (raw == null || raw.isEmpty) ? legacy : raw;
    if (source == null || source.isEmpty) return;
    try {
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      await _docFor(uid).set(decoded, SetOptions(merge: true));
      await prefs.remove(_legacyStorageKey);
      await prefs.remove(_storageKeyFor(uid));
    } catch (_) {
      // ignore corrupted storage
    }
  }

  void updateProfile(AcademicProfile next) {
    state = next;
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    _docFor(uid).set(next.toJson(), SetOptions(merge: true));
  }

  Future<void> reset() async {
    state = const AcademicProfile();
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await _docFor(uid).delete();
  }
}
