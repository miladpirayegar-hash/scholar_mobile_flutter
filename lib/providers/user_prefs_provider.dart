import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_prefs.dart';
import 'auth_provider.dart';

class UserPrefs {
  final bool notificationsEnabled;
  final String preferredMic;
  final String recordingQuality;
  final bool aiProcessingConsent;
  final bool needsOutlineUpload;
  final bool hasUploadedOutline;
  final bool didShowGetStarted;
  final bool hasRecordedSession;
  final String sessionsSort;
  final bool hideContent;
  final bool hasAccount;

  const UserPrefs({
    this.notificationsEnabled = true,
    this.preferredMic = 'Default - Microphone (HD Pro Webcam C920)',
    this.recordingQuality = 'Lossless',
    this.aiProcessingConsent = false,
    this.needsOutlineUpload = false,
    this.hasUploadedOutline = false,
    this.didShowGetStarted = false,
    this.hasRecordedSession = false,
    this.sessionsSort = 'newest',
    this.hideContent = true,
    this.hasAccount = false,
  });

  UserPrefs copyWith({
    bool? notificationsEnabled,
    String? preferredMic,
    String? recordingQuality,
    bool? aiProcessingConsent,
    bool? needsOutlineUpload,
    bool? hasUploadedOutline,
    bool? didShowGetStarted,
    bool? hasRecordedSession,
    String? sessionsSort,
    bool? hideContent,
    bool? hasAccount,
  }) {
    return UserPrefs(
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      preferredMic: preferredMic ?? this.preferredMic,
      recordingQuality: recordingQuality ?? this.recordingQuality,
      aiProcessingConsent: aiProcessingConsent ?? this.aiProcessingConsent,
      needsOutlineUpload: needsOutlineUpload ?? this.needsOutlineUpload,
      hasUploadedOutline: hasUploadedOutline ?? this.hasUploadedOutline,
      didShowGetStarted: didShowGetStarted ?? this.didShowGetStarted,
      hasRecordedSession: hasRecordedSession ?? this.hasRecordedSession,
      sessionsSort: sessionsSort ?? this.sessionsSort,
      hideContent: hideContent ?? this.hideContent,
      hasAccount: hasAccount ?? this.hasAccount,
    );
  }

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': notificationsEnabled,
        'preferredMic': preferredMic,
        'recordingQuality': recordingQuality,
        'aiProcessingConsent': aiProcessingConsent,
        'needsOutlineUpload': needsOutlineUpload,
        'hasUploadedOutline': hasUploadedOutline,
        'didShowGetStarted': didShowGetStarted,
        'hasRecordedSession': hasRecordedSession,
        'sessionsSort': sessionsSort,
        'hideContent': hideContent,
        'hasAccount': hasAccount,
      };

  factory UserPrefs.fromJson(Map<String, dynamic> json) {
    return UserPrefs(
      notificationsEnabled:
          json['notificationsEnabled'] as bool? ?? true,
      preferredMic:
          json['preferredMic'] as String? ??
              'Default - Microphone (HD Pro Webcam C920)',
      recordingQuality:
          json['recordingQuality'] as String? ?? 'Lossless',
      aiProcessingConsent:
          json['aiProcessingConsent'] as bool? ?? false,
      needsOutlineUpload:
          json['needsOutlineUpload'] as bool? ?? false,
      hasUploadedOutline:
          json['hasUploadedOutline'] as bool? ?? false,
      didShowGetStarted:
          json['didShowGetStarted'] as bool? ?? false,
      hasRecordedSession:
          json['hasRecordedSession'] as bool? ?? false,
      sessionsSort: json['sessionsSort'] as String? ?? 'newest',
      hideContent: json['hideContent'] as bool? ?? true,
      hasAccount: json['hasAccount'] as bool? ?? false,
    );
  }
}

final userPrefsProvider =
    StateNotifierProvider<UserPrefsController, UserPrefs>(
  (ref) => UserPrefsController(ref),
);

class UserPrefsController extends StateNotifier<UserPrefs> {
  UserPrefsController(this.ref) : super(const UserPrefs()) {
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
        .collection('prefs')
        .doc('app');
  }

  void _bind() {
    _sub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      state = const UserPrefs();
      return;
    }
    _sub = _docFor(uid).snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      state = UserPrefs.fromJson(data);
    });
    unawaited(_migrateFromPrefs(uid));
  }

  Future<void> _migrateFromPrefs(String uid) async {
    final doc = await _docFor(uid).get();
    if (doc.exists && (doc.data() ?? {}).isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final migrated = <String, dynamic>{};

    final notificationsEnabled =
        prefs.getBool(AppPrefs.notificationsEnabled);
    if (notificationsEnabled != null) {
      migrated['notificationsEnabled'] = notificationsEnabled;
      await prefs.remove(AppPrefs.notificationsEnabled);
    }

    final preferredMic = prefs.getString(AppPrefs.preferredMic);
    if (preferredMic != null) {
      migrated['preferredMic'] = preferredMic;
      await prefs.remove(AppPrefs.preferredMic);
    }

    final recordingQuality = prefs.getString(AppPrefs.recordingQuality);
    if (recordingQuality != null) {
      migrated['recordingQuality'] = recordingQuality;
      await prefs.remove(AppPrefs.recordingQuality);
    }

    final aiConsent = prefs.getBool(AppPrefs.aiProcessingConsent);
    if (aiConsent != null) {
      migrated['aiProcessingConsent'] = aiConsent;
      await prefs.remove(AppPrefs.aiProcessingConsent);
    }

    final hasAccount = prefs.getBool(AppPrefs.hasAccount);
    if (hasAccount != null) {
      migrated['hasAccount'] = hasAccount;
      await prefs.remove(AppPrefs.hasAccount);
    }

    final hasRecorded = prefs.getBool(AppPrefs.hasRecordedSession);
    if (hasRecorded != null) {
      migrated['hasRecordedSession'] = hasRecorded;
      await prefs.remove(AppPrefs.hasRecordedSession);
    }

    final needsOutline = prefs.getBool('needs_outline_upload_v1');
    if (needsOutline != null) {
      migrated['needsOutlineUpload'] = needsOutline;
      await prefs.remove('needs_outline_upload_v1');
    }

    final hasUploaded = prefs.getBool('has_uploaded_outline_v1');
    if (hasUploaded != null) {
      migrated['hasUploadedOutline'] = hasUploaded;
      await prefs.remove('has_uploaded_outline_v1');
    }

    final didShow = prefs.getBool('did_show_get_started_v1');
    if (didShow != null) {
      migrated['didShowGetStarted'] = didShow;
      await prefs.remove('did_show_get_started_v1');
    }

    final sessionsSort = prefs.getString('sessions_sort_v1');
    if (sessionsSort != null) {
      migrated['sessionsSort'] = sessionsSort;
      await prefs.remove('sessions_sort_v1');
    }

    final hideContent = prefs.getBool('content_visibility_v3');
    if (hideContent != null) {
      migrated['hideContent'] = hideContent;
      await prefs.remove('content_visibility_v3');
    }

    if (migrated.isEmpty) return;
    await _docFor(uid).set(migrated, SetOptions(merge: true));
  }

  Future<void> _update(Map<String, dynamic> data) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await _docFor(uid).set(data, SetOptions(merge: true));
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _update({'notificationsEnabled': value});
  }

  Future<void> setPreferredMic(String value) async {
    state = state.copyWith(preferredMic: value);
    await _update({'preferredMic': value});
  }

  Future<void> setRecordingQuality(String value) async {
    state = state.copyWith(recordingQuality: value);
    await _update({'recordingQuality': value});
  }

  Future<void> setAiConsent(bool value) async {
    state = state.copyWith(aiProcessingConsent: value);
    await _update({'aiProcessingConsent': value});
  }

  Future<void> setNeedsOutlineUpload(bool value) async {
    state = state.copyWith(needsOutlineUpload: value);
    await _update({'needsOutlineUpload': value});
  }

  Future<void> setHasUploadedOutline(bool value) async {
    state = state.copyWith(hasUploadedOutline: value);
    await _update({'hasUploadedOutline': value});
  }

  Future<void> setDidShowGetStarted(bool value) async {
    state = state.copyWith(didShowGetStarted: value);
    await _update({'didShowGetStarted': value});
  }

  Future<void> setHasRecordedSession(bool value) async {
    state = state.copyWith(hasRecordedSession: value);
    await _update({'hasRecordedSession': value});
  }

  Future<void> setSessionsSort(String value) async {
    state = state.copyWith(sessionsSort: value);
    await _update({'sessionsSort': value});
  }

  Future<void> setHideContent(bool value) async {
    state = state.copyWith(hideContent: value);
    await _update({'hideContent': value});
  }

  Future<void> setHasAccount(bool value) async {
    state = state.copyWith(hasAccount: value);
    await _update({'hasAccount': value});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
