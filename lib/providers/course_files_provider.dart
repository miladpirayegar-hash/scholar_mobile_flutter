import 'dart:convert';

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

class CourseFileUploadStatus {
  final String id;
  final double progress; // 0..1
  final bool isUploading;
  final String? error;

  const CourseFileUploadStatus({
    required this.id,
    this.progress = 0,
    this.isUploading = false,
    this.error,
  });

  CourseFileUploadStatus copyWith({
    double? progress,
    bool? isUploading,
    String? error,
  }) {
    return CourseFileUploadStatus(
      id: id,
      progress: progress ?? this.progress,
      isUploading: isUploading ?? this.isUploading,
      error: error,
    );
  }
}

final courseFileUploadStatusProvider = StateNotifierProvider<
    CourseFileUploadStatusController, Map<String, CourseFileUploadStatus>>(
  (ref) => CourseFileUploadStatusController(),
);

class CourseFileUploadStatusController
    extends StateNotifier<Map<String, CourseFileUploadStatus>> {
  CourseFileUploadStatusController() : super(const {});

  void start(String id) {
    state = {
      ...state,
      id: CourseFileUploadStatus(id: id, isUploading: true, progress: 0),
    };
  }

  void progress(String id, double value) {
    state = {
      ...state,
      id: (state[id] ??
              CourseFileUploadStatus(id: id, isUploading: true))
          .copyWith(progress: value, isUploading: true),
    };
  }

  void success(String id) {
    state = {
      ...state,
      id: CourseFileUploadStatus(id: id, isUploading: false, progress: 1),
    };
  }

  void error(String id, String message) {
    state = {
      ...state,
      id: CourseFileUploadStatus(
        id: id,
        isUploading: false,
        progress: 0,
        error: message,
      ),
    };
  }

  void clear(String id) {
    final next = {...state};
    next.remove(id);
    state = next;
  }
}

class CourseFile {
  final String id;
  final String name;
  final String path;
  final String storagePath;
  final int sizeBytes;
  final DateTime addedAt;

  const CourseFile({
    required this.id,
    required this.name,
    required this.path,
    required this.storagePath,
    required this.sizeBytes,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'storagePath': storagePath,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
      };

  factory CourseFile.fromJson(Map<String, dynamic> json) {
    final rawAddedAt = json['addedAt'];
    DateTime addedAtValue = DateTime.now();
    if (rawAddedAt is Timestamp) {
      addedAtValue = rawAddedAt.toDate();
    } else if (rawAddedAt is String) {
      addedAtValue = DateTime.tryParse(rawAddedAt) ?? DateTime.now();
    }
    return CourseFile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'File',
      path: json['path'] as String? ?? '',
      storagePath: json['storagePath'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      addedAt: addedAtValue,
    );
  }
}

final courseFilesProvider =
    StateNotifierProvider<CourseFilesController, Map<String, List<CourseFile>>>(
  (ref) => CourseFilesController(ref),
);

class CourseFilesController
    extends StateNotifier<Map<String, List<CourseFile>>> {
  static const _storageKey = 'course_files_v1';
  static const bool _forceLocalOnly = true;

  CourseFilesController(this.ref) : super(const {}) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      }
    });
    _bind();
  }

  final Ref ref;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Map<String, List<CourseFile>> _localCache = const {};

  static const int maxFileSizeBytes = 15 * 1024 * 1024; // 15 MB
  static const List<String> allowedExtensions = [
    '.pdf',
    '.docx',
    '.txt',
    '.md',
    '.ppt',
    '.pptx',
  ];

  bool isSupportedFile(String name) {
    final lower = name.toLowerCase();
    return allowedExtensions.any(lower.endsWith);
  }

  void _bind() {
    _sub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      state = const {};
      return;
    }
    unawaited(_loadLocalCache());
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('course_files')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .listen((snap) {
      final next = <String, List<CourseFile>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final unitId = data['unitId'] as String? ?? '';
        if (unitId.isEmpty) continue;
        final file = CourseFile.fromJson({
          ...data,
          'id': doc.id,
        });
        final existing = next[unitId] ?? const <CourseFile>[];
        next[unitId] = [file, ...existing];
      }
      state = _mergeWithLocal(next);
    });
    if (!kIsWeb) {
      unawaited(_migrateFromPrefs(uid));
    }
  }

  Future<void> clearAll() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('course_files');
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    state = const {};
  }

  Future<void> addFile(String unitId, CourseFile file) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    if (_forceLocalOnly || kIsWeb) {
      _saveLocal(unitId, file);
      ref.read(courseFileUploadStatusProvider.notifier).success(file.id);
      return;
    }
    await _uploadAndSave(uid, unitId, file);
  }

  void removeFile(String unitId, String id) {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    if (_removeLocal(unitId, id)) return;
    unawaited(_deleteRemote(uid, id));
  }

  Future<void> _uploadAndSave(
    String uid,
    String unitId,
    CourseFile file,
  ) async {
    if (file.path.isEmpty) return;
    if (!File(file.path).existsSync()) {
      ref
          .read(courseFileUploadStatusProvider.notifier)
          .error(file.id, 'File not found on device.');
      return;
    }
    if (!isSupportedFile(file.name)) {
      ref
          .read(courseFileUploadStatusProvider.notifier)
          .error(file.id, 'Unsupported file type.');
      return;
    }
    final size = File(file.path).lengthSync();
    if (size > maxFileSizeBytes) {
      ref
          .read(courseFileUploadStatusProvider.notifier)
          .error(file.id, 'File too large. Max 15 MB.');
      return;
    }
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'users/$uid/course_files/$unitId/${file.id}_$safeName';
    final storageRef = FirebaseStorage.instance.ref(storagePath);
    ref.read(courseFileUploadStatusProvider.notifier).start(file.id);
    try {
      final task = storageRef.putFile(File(file.path));
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes == 0) return;
        ref
            .read(courseFileUploadStatusProvider.notifier)
            .progress(file.id, snap.bytesTransferred / snap.totalBytes);
      });
      await task;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('course_files')
          .doc(file.id)
          .set({
        'name': file.name,
        'storagePath': storagePath,
        'unitId': unitId,
        'sizeBytes': size,
        'addedAt': FieldValue.serverTimestamp(),
      });
      ref.read(courseFileUploadStatusProvider.notifier).success(file.id);
    } on FirebaseException catch (e) {
      if (_shouldFallbackLocal(e)) {
        _saveLocal(unitId, file);
        ref
            .read(courseFileUploadStatusProvider.notifier)
            .error(
              file.id,
              'Saved locally only (Storage disabled).',
            );
        return;
      }
      final message = e.code == 'canceled' || e.code == 'cancelled'
          ? 'Upload cancelled. Check your connection and try again.'
          : (e.message?.isNotEmpty == true
              ? e.message!
              : 'Upload failed. Tap retry.');
      ref
          .read(courseFileUploadStatusProvider.notifier)
          .error(file.id, message);
    } catch (_) {
      ref
          .read(courseFileUploadStatusProvider.notifier)
          .error(file.id, 'Upload failed. Tap retry.');
    }
  }

  Future<void> _deleteRemote(String uid, String id) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('course_files')
        .doc(id)
        .get();
    final data = doc.data();
    final storagePath = data?['storagePath'] as String?;
    await doc.reference.delete();
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (_) {
        // ignore missing storage object
      }
    }
  }

  Future<void> _migrateFromPrefs(String uid) async {
    if (kIsWeb) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('course_files');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    var allUploaded = true;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final unitId = entry.key;
        final items = (entry.value as List<dynamic>? ?? const [])
            .map((e) => CourseFile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        for (final file in items) {
          if (file.path.isEmpty || !File(file.path).existsSync()) {
            allUploaded = false;
            continue;
          }
          final safeName =
              file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final storagePath =
              'users/$uid/course_files/$unitId/${file.id}_$safeName';
          try {
            await FirebaseStorage.instance
                .ref(storagePath)
                .putFile(File(file.path));
            await col.doc(file.id).set({
              'name': file.name,
              'storagePath': storagePath,
              'unitId': unitId,
              'sizeBytes': File(file.path).lengthSync(),
              'addedAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {
            allUploaded = false;
          }
        }
      }
      if (allUploaded) {
        await prefs.remove(_storageKey);
      }
    } catch (_) {
      // ignore corrupted storage
    }
  }

  Future<void> _loadLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _localCache = const {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final next = <String, List<CourseFile>>{};
      for (final entry in decoded.entries) {
        final unitId = entry.key;
        final items = (entry.value as List<dynamic>? ?? const [])
            .map((e) => CourseFile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (items.isNotEmpty) next[unitId] = items;
      }
      _localCache = next;
      state = _mergeWithLocal(state);
    } catch (_) {
      _localCache = const {};
    }
  }

  Map<String, List<CourseFile>> _mergeWithLocal(
    Map<String, List<CourseFile>> remote,
  ) {
    if (_localCache.isEmpty) return remote;
    final merged = <String, List<CourseFile>>{...remote};
    for (final entry in _localCache.entries) {
      final unitId = entry.key;
      final existing = merged[unitId] ?? const <CourseFile>[];
      final ids = existing.map((e) => e.id).toSet();
      final combined = [
        ...entry.value.where((e) => !ids.contains(e.id)),
        ...existing,
      ];
      merged[unitId] = combined;
    }
    return merged;
  }

  Future<void> _persistLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final entry in _localCache.entries) {
      data[entry.key] = entry.value.map((e) => e.toJson()).toList();
    }
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  void _saveLocal(String unitId, CourseFile file) {
    final existing = _localCache[unitId] ?? const <CourseFile>[];
    _localCache = {
      ..._localCache,
      unitId: [file, ...existing],
    };
    state = _mergeWithLocal(state);
    unawaited(_persistLocalCache());
  }

  bool _removeLocal(String unitId, String id) {
    final items = _localCache[unitId];
    if (items == null || items.isEmpty) return false;
    final next = items.where((e) => e.id != id).toList();
    _localCache = {..._localCache, unitId: next};
    final nextState = <String, List<CourseFile>>{
      ...state,
      unitId: (state[unitId] ?? const <CourseFile>[])
          .where((e) => e.id != id)
          .toList(),
    };
    if ((nextState[unitId] ?? const <CourseFile>[]).isEmpty) {
      nextState.remove(unitId);
    }
    state = _mergeWithLocal(nextState);
    unawaited(_persistLocalCache());
    return true;
  }

  bool _shouldFallbackLocal(FirebaseException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();
    if (code.contains('unauthorized') ||
        code.contains('unauthenticated') ||
        code.contains('failed-precondition') ||
        code.contains('unknown')) {
      return true;
    }
    if (message.contains('billing') || message.contains('upgrade')) {
      return true;
    }
    return false;
  }
}
