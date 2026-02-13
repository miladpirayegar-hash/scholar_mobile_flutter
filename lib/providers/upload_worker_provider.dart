import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/pending_upload.dart';
import '../config/api_config.dart';
import 'upload_queue_provider.dart';

/// Upload worker that retries pending / failed uploads.
/// Ensures only ONE upload runs at a time.
final uploadWorkerProvider =
    Provider<UploadWorkerController>((ref) {
  final controller = UploadWorkerController(ref);
  controller.start();
  return controller;
});

class UploadWorkerController {
  final Ref ref;
  bool _isRunning = false;
  bool _isUploading = false;

  UploadWorkerController(this.ref);

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    ref.listen<List<PendingUpload>>(
      uploadQueueProvider,
      (_, _) => _processQueue(),
      fireImmediately: true,
    );
  }

  Future<void> _processQueue() async {
    if (_isUploading || kIsWeb) return;

    final queue = ref.read(uploadQueueProvider);

    // Find the first pending or failed upload
    final candidates = queue.where(
      (u) =>
          u.status == UploadStatus.pending ||
          u.status == UploadStatus.failed,
    );

    if (candidates.isEmpty) return;

    await _upload(candidates.first);
  }

  Future<void> _upload(PendingUpload upload) async {
    final queueController =
        ref.read(uploadQueueProvider.notifier);

    _isUploading = true;

    try {
      await queueController.markUploading(upload.id);

      final file = File(upload.filePath);
      if (!file.existsSync()) {
        throw Exception('File not found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/sessions'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          file.path,
          contentType: MediaType('audio', 'm4a'),
        ),
      );

      final response = await request.send();

      if (response.statusCode != 201) {
        throw Exception(
          'Upload failed (${response.statusCode})',
        );
      }

      // Success. remove from queue
      await queueController.remove(upload.id);
    } catch (e) {
      await queueController.markFailed(
        upload.id,
        e.toString(),
      );
    } finally {
      _isUploading = false;
    }
  }
}

