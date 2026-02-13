import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/pending_upload.dart';
import 'auth_provider.dart';

final uploadQueueProvider =
    StateNotifierProvider<UploadQueueController, List<PendingUpload>>(
  (ref) => UploadQueueController(ref),
);

class UploadQueueController extends StateNotifier<List<PendingUpload>> {
  static const _storageKey = 'pending_uploads';
  final _uuid = const Uuid();

  UploadQueueController(this.ref) : super(const []) {
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
        .collection('upload_queue')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snap) {
      state = [
        for (final doc in snap.docs)
          PendingUpload.fromJson({
            ...doc.data(),
            'id': doc.id,
          }),
      ];
    });
    unawaited(_migrateFromPrefs(uid));
  }

  /// Called after recording completes
  Future<void> enqueue(String filePath) async {
    final upload = PendingUpload(
      id: _uuid.v4(),
      filePath: filePath,
      createdAt: DateTime.now(),
      status: UploadStatus.pending,
    );

    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('upload_queue')
        .doc(upload.id)
        .set(upload.toJson());
  }

  Future<void> markUploading(String id) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('upload_queue')
        .doc(id)
        .update({'status': UploadStatus.uploading.name});
  }

  Future<void> markFailed(String id, String error) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('upload_queue')
        .doc(id)
        .update({
      'status': UploadStatus.failed.name,
      'errorMessage': error,
    });
  }

  Future<void> remove(String id) async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('upload_queue')
        .doc(id)
        .delete();
  }

  Future<void> clearAll() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('upload_queue');
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
        .collection('upload_queue');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final items = PendingUpload.decodeList(raw);
      for (final upload in items) {
        await col.doc(upload.id).set(upload.toJson());
      }
      await prefs.remove(_storageKey);
    } catch (_) {
      // ignore corrupted storage
    }
  }
}
